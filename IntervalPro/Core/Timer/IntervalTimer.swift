import Foundation
import Combine
import QuartzCore

/// High-precision interval timer engine with state machine
/// Manages work/rest phases, series tracking, and timing
@MainActor
final class IntervalTimer: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentPhase: IntervalPhase = .idle
    @Published private(set) var timerState: TimerState = .stopped
    @Published private(set) var currentSeries: Int = 0
    @Published private(set) var totalSeries: Int = 0
    @Published private(set) var currentBlock: Int = 0      // Current block within series (1-based)
    @Published private(set) var totalBlocks: Int = 1       // Total blocks per series
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var phaseElapsedTime: TimeInterval = 0
    @Published private(set) var phaseRemainingTime: TimeInterval = 0
    @Published private(set) var totalElapsedTime: TimeInterval = 0
    @Published private(set) var currentTargetZone: HeartRateZone?

    // MARK: - Configuration
    private var plan: TrainingPlan?
    private var currentPhaseDuration: TimeInterval = 0

    // MARK: - Timer
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var pausedTime: CFTimeInterval = 0

    // MARK: - Callbacks
    var onPhaseChange: ((IntervalPhase, IntervalPhase) -> Void)?
    var onSeriesComplete: ((Int) -> Void)?
    var onWorkoutComplete: (() -> Void)?
    var onTick: ((TimeInterval) -> Void)?
    var onTimeWarning: ((Int) -> Void)?   // Seconds remaining (fixed countdowns)
    var onMilestone: ((MilestoneKind) -> Void)?  // Equal-division phase milestones

    // MARK: - Time Warning Thresholds
    private let timeWarnings: Set<Int> = [30, 10, 5, 3, 2, 1]
    private var announcedWarnings: Set<Int> = []

    // MARK: - Phase Milestones (computed per phase)
    private var dynamicMilestones: [(remaining: Int, kind: MilestoneKind)] = []
    private var announcedMilestones: Set<Int> = []

    // MARK: - Computed Properties
    var isRunning: Bool {
        timerState == .running
    }

    var isPaused: Bool {
        timerState == .paused
    }

    var progress: Double {
        guard currentPhaseDuration > 0 else { return 0 }
        return min(phaseElapsedTime / currentPhaseDuration, 1.0)
    }

    var seriesProgress: Double {
        guard totalSeries > 0 else { return 0 }
        return Double(currentSeries) / Double(totalSeries)
    }

    var formattedPhaseRemaining: String {
        phaseRemainingTime.formattedMinutesSeconds
    }

    var formattedTotalElapsed: String {
        totalElapsedTime.formattedHoursMinutesSeconds
    }

    // MARK: - Init
    init() {
        Log.training.debug("IntervalTimer initialized")
    }

    /*deinit {
        stopDisplayLink()
    }*/

    // MARK: - Configuration
    func configure(with plan: TrainingPlan) {
        self.plan = plan
        self.totalSeries = plan.seriesCount
        self.totalBlocks = plan.blocksPerSeries
        self.currentSeries = 0
        self.currentBlock = 0

        reset()

        Log.training.info("Timer configured: \(plan.name), \(plan.seriesCount) series, \(plan.blocksPerSeries) blocks/series")
    }

    // MARK: - Control
    func start() {
        guard let plan = plan else {
            Log.training.error("Cannot start: no plan configured")
            return
        }

        guard timerState == .stopped else {
            Log.training.warning("Timer already running or paused")
            return
        }

        timerState = .running

        // Determine starting phase
        if let warmupDuration = plan.warmupDuration, warmupDuration > 0 {
            currentTargetZone = plan.warmupZone ?? plan.restZone
            transitionTo(phase: .warmup, duration: warmupDuration)
        } else {
            currentSeries = 1
            currentBlock = 1
            startWorkPhase()
        }

        startDisplayLink()

        Log.training.info("Timer started")
    }

    func pause() {
        guard timerState == .running else { return }

        timerState = .paused
        pausedTime = CACurrentMediaTime()
        stopDisplayLink()

        Log.training.debug("Timer paused at \(self.phaseElapsedTime.formattedMinutesSeconds)")
    }

    func resume() {
        guard timerState == .paused else { return }

        timerState = .running

        // Adjust lastUpdateTime to account for pause duration
        let pauseDuration = CACurrentMediaTime() - pausedTime
        lastUpdateTime += pauseDuration

        startDisplayLink()

        Log.training.debug("Timer resumed")
    }

    func stop() {
        timerState = .stopped
        stopDisplayLink()

        Log.training.info("Timer stopped")
    }

    func reset() {
        stop()

        currentPhase = .idle
        currentSeries = 0
        currentBlock = 0
        currentTargetZone = nil
        elapsedTime = 0
        phaseElapsedTime = 0
        phaseRemainingTime = plan?.warmupDuration ?? plan?.workDuration ?? 0
        totalElapsedTime = 0
        currentPhaseDuration = 0
        announcedWarnings.removeAll()
        dynamicMilestones = []
        announcedMilestones = []

        Log.training.debug("Timer reset")
    }

    // MARK: - Display Link
    private func startDisplayLink() {
        stopDisplayLink()

        lastUpdateTime = CACurrentMediaTime()

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        let currentTime = CACurrentMediaTime()
        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard timerState == .running else { return }

        // Update times
        phaseElapsedTime += delta
        totalElapsedTime += delta

        // Calculate remaining
        phaseRemainingTime = max(0, currentPhaseDuration - phaseElapsedTime)

        // Check time warnings
        checkTimeWarnings()

        // Notify tick
        onTick?(phaseRemainingTime)

        // Check phase completion
        if phaseElapsedTime >= currentPhaseDuration {
            handlePhaseComplete()
        }
    }

    // MARK: - Phase Management
    private func transitionTo(phase: IntervalPhase, duration: TimeInterval) {
        let previousPhase = currentPhase

        currentPhase = phase
        currentPhaseDuration = duration
        phaseElapsedTime = 0
        phaseRemainingTime = duration
        announcedWarnings.removeAll()
        computeMilestones(for: duration)

        onPhaseChange?(previousPhase, phase)

        Log.training.info("Phase: \(previousPhase.rawValue) → \(phase.rawValue), duration: \(duration.formattedMinutesSeconds)")
    }

    /// Divides the phase duration into 3 equal parts and registers milestone announcements.
    /// Skips milestones that fall within 3s of existing fixed countdowns to avoid overlap.
    private func computeMilestones(for duration: TimeInterval) {
        dynamicMilestones = []
        announcedMilestones = []
        guard duration >= 60 else { return }

        let third = duration / 3

        // 1/3 elapsed: 2/3 remaining
        let twoThirdsRem = Int((2 * third).rounded())
        if !timeWarnings.contains(twoThirdsRem) {
            dynamicMilestones.append((remaining: twoThirdsRem, kind: .firstThird(remaining: 2 * third)))
        }

        // 2/3 elapsed: last third begins
        let oneThirdRem = Int(third.rounded())
        if !timeWarnings.contains(oneThirdRem) {
            dynamicMilestones.append((remaining: oneThirdRem, kind: .lastThird(remaining: third)))
        }

        // Halfway through last third (D/6 remaining)
        let halfLastRem = Int((third / 2).rounded())
        if halfLastRem > 12, !timeWarnings.contains(halfLastRem), halfLastRem != oneThirdRem {
            dynamicMilestones.append((remaining: halfLastRem, kind: .halfLastThird(remaining: third / 2)))
        }
    }

    private func handlePhaseComplete() {
        guard let plan = plan else { return }

        switch currentPhase {
        case .idle:
            // Should not happen
            break

        case .warmup:
            // Warmup complete, start first work interval
            currentSeries = 1
            currentBlock = 1
            startWorkPhase()

        case .work:
            // Work complete, transition to rest
            startRestPhase()

        case .rest:
            // Rest complete, check if more blocks in this series
            if plan.isProgressive, let blocks = plan.workBlocks, currentBlock < blocks.count {
                // More blocks in this series
                currentBlock += 1
                startWorkPhase()
            } else {
                // All blocks in series complete
                onSeriesComplete?(currentSeries)

                if currentSeries < totalSeries {
                    // Start next series
                    currentSeries += 1
                    currentBlock = 1
                    startWorkPhase()
                } else {
                    // All series complete
                    if let cooldownDuration = plan.cooldownDuration, cooldownDuration > 0 {
                        currentTargetZone = plan.cooldownZone ?? plan.restZone
                        transitionTo(phase: .cooldown, duration: cooldownDuration)
                    } else {
                        completeWorkout()
                    }
                }
            }

        case .cooldown:
            // Cooldown complete, workout finished
            completeWorkout()

        case .complete:
            // Already complete
            break
        }
    }

    private func startWorkPhase() {
        guard let plan = plan else { return }

        let workDuration: TimeInterval
        let workZone: HeartRateZone

        if plan.isProgressive, let blocks = plan.workBlocks, currentBlock > 0, currentBlock <= blocks.count {
            let block = blocks[currentBlock - 1]
            workDuration = block.workDuration
            workZone = block.workZone
        } else {
            workDuration = plan.workDuration
            workZone = plan.workZone
        }

        currentTargetZone = workZone
        transitionTo(phase: .work, duration: workDuration)
    }

    private func startRestPhase() {
        guard let plan = plan else { return }

        let restDuration: TimeInterval
        let restZone: HeartRateZone

        if plan.isProgressive, let blocks = plan.workBlocks, currentBlock > 0, currentBlock <= blocks.count {
            let block = blocks[currentBlock - 1]
            restDuration = block.restDuration
            restZone = block.restZone
        } else {
            restDuration = plan.restDuration
            restZone = plan.restZone
        }

        currentTargetZone = restZone
        transitionTo(phase: .rest, duration: restDuration)
    }

    private func completeWorkout() {
        currentPhase = .complete
        timerState = .stopped
        stopDisplayLink()

        onWorkoutComplete?()

        Log.training.info("Workout complete! Total time: \(self.totalElapsedTime.formattedHoursMinutesSeconds)")
    }

    // MARK: - Time Warnings
    private func checkTimeWarnings() {
        let secondsRemaining = Int(phaseRemainingTime)

        for warning in timeWarnings {
            if secondsRemaining == warning && !announcedWarnings.contains(warning) {
                announcedWarnings.insert(warning)
                onTimeWarning?(warning)
            }
        }

        for milestone in dynamicMilestones {
            if secondsRemaining == milestone.remaining && !announcedMilestones.contains(milestone.remaining) {
                announcedMilestones.insert(milestone.remaining)
                onMilestone?(milestone.kind)
            }
        }
    }

    // MARK: - Skip Functions
    func skipToNextPhase() {
        guard timerState == .running || timerState == .paused else { return }

        // Force phase completion
        phaseElapsedTime = currentPhaseDuration
        handlePhaseComplete()

        Log.training.debug("Skipped to next phase")
    }

    func skipWarmup() {
        guard currentPhase == .warmup else { return }
        skipToNextPhase()
    }

    func skipCooldown() {
        guard currentPhase == .cooldown else { return }
        completeWorkout()
    }

    // MARK: - Time Adjustments
    func addTime(_ seconds: TimeInterval) {
        currentPhaseDuration += seconds
        phaseRemainingTime += seconds

        Log.training.debug("Added \(seconds)s to current phase")
    }

    func subtractTime(_ seconds: TimeInterval) {
        let newDuration = max(0, currentPhaseDuration - seconds)
        currentPhaseDuration = newDuration
        phaseRemainingTime = max(0, phaseRemainingTime - seconds)

        Log.training.debug("Subtracted \(seconds)s from current phase")
    }
}

// MARK: - Milestone Kind
enum MilestoneKind {
    case firstThird(remaining: TimeInterval)    // 1/3 elapsed, 2/3 remaining
    case lastThird(remaining: TimeInterval)     // 2/3 elapsed, last third begins
    case halfLastThird(remaining: TimeInterval) // halfway through last third
}

// MARK: - Interval Timer State Snapshot
struct IntervalTimerState: Equatable {
    let phase: IntervalPhase
    let timerState: TimerState
    let currentSeries: Int
    let totalSeries: Int
    let phaseElapsedTime: TimeInterval
    let phaseRemainingTime: TimeInterval
    let totalElapsedTime: TimeInterval
    let progress: Double
}

extension IntervalTimer {
    var stateSnapshot: IntervalTimerState {
        IntervalTimerState(
            phase: currentPhase,
            timerState: timerState,
            currentSeries: currentSeries,
            totalSeries: totalSeries,
            phaseElapsedTime: phaseElapsedTime,
            phaseRemainingTime: phaseRemainingTime,
            totalElapsedTime: totalElapsedTime,
            progress: progress
        )
    }
}
