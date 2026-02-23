import SwiftUI
import Combine
import HealthKit

/// Main ViewModel for active training sessions
/// Coordinates IntervalTimer, HRDataService, MetronomeEngine
@MainActor
final class TrainingViewModel: ObservableObject {
    // MARK: - Published State - Timer
    @Published var currentPhase: IntervalPhase = .idle
    @Published var timerState: TimerState = .stopped
    @Published var currentSeries: Int = 0
    @Published var totalSeries: Int = 0
    @Published var currentBlock: Int = 0
    @Published var totalBlocks: Int = 1
    @Published var phaseRemainingTime: TimeInterval = 0
    @Published var totalElapsedTime: TimeInterval = 0
    @Published var phaseProgress: Double = 0

    // MARK: - Published State - Heart Rate & Data Source
    @Published var currentHeartRate: Int = 0
    @Published var zoneStatus: ZoneStatus = .inZone
    @Published var hrSource: DataSource = .healthKit
    @Published var timeInZone: TimeInterval = 0
    @Published var isGarminConnected: Bool = false

    // MARK: - Published State - Metrics
    @Published var currentCadence: Int = 0   // SPM - steps per minute (zone tracking)
    @Published var currentPace: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var totalDistance: Double = 0
    @Published var avgHeartRate: Int = 0
    @Published var isSimulationMode: Bool = false
    @Published var sessionSteps: Int = 0     // Steps in this session (not accumulated)

    // MARK: - Published State - Audio Volume
    @Published var metronomeVolume: Float = 0.7
    @Published var voiceVolume: Float = 0.9

    // MARK: - Published State - Coaching (via CoachingService)
    @Published var coachingStatus: CoachingStatus?
    @Published var lastCoachingInstruction: CoachingInstruction = .maintainPace

    // MARK: - Published State - Best Session Comparison
    @Published var bestSession: TrainingSession?
    @Published var deltaVsBest: TimeInterval = 0
    @Published var isAheadOfBest: Bool = false
    @Published var bestPace: Double = 0        // Best session avg pace (sec/km)
    @Published var paceVsBest: Double = 0      // Current pace - best pace (negative = faster)

    // MARK: - Published State - Best Pace Per Block (across ALL sessions)
    /// Maps block index (1-based) → best (lowest) pace in sec/km across all historical sessions for this plan
    @Published var bestPacesPerBlock: [Int: Double] = [:]

    // MARK: - Published State - Same-Block Interval Comparison
    @Published var bestSameBlockPace: Double = 0       // Best pace from prev same-block intervals
    @Published var currentIntervalPaceVsBest: Double = 0  // Current - best (negative = faster)
    @Published var isAheadOfSameBlockBest: Bool = false

    // MARK: - Published State - Audio
    @Published var isMetronomeEnabled: Bool = true
    @Published var metronomeBPM: Int = 170
    @Published var isVoiceEnabled: Bool = true

    // MARK: - Published State - Music
    @Published var nowPlayingTrack: MusicTrack?
    @Published var musicPlaybackState: MusicPlaybackState = .stopped
    @Published var isMusicConnected: Bool = false

    // MARK: - Plan
    @Published var plan: TrainingPlan?

    // MARK: - Dependencies
    private let intervalTimer: IntervalTimer
    private let hrDataService: HRDataService
    let audioEngine: AudioEngineProtocol
    private let garminManager: GarminManaging
    private let healthKitManager: HealthKitManaging
    private let musicController: UnifiedMusicController
    private let coachingService: CoachingService

    // MARK: - Session Tracking (internal for extension access)
    var currentSession: TrainingSession?
    var currentIntervalRecord: IntervalRecord?
    var hrSamples: [HRSample] = []
    var intervalRecords: [IntervalRecord] = []

    // MARK: - Stats (internal for extension access)
    var hrSum: Int = 0
    var hrCount: Int = 0
    var maxHeartRate: Int = 0
    var minHeartRate: Int = 999

    // Internal access to session repository
    var sessionRepository: SessionRepositoryProtocol { _sessionRepository }
    private let _sessionRepository: SessionRepositoryProtocol

    // MARK: - Same-Block Announcement Tracking
    private var hasAnnouncedSameBlockImprovement = false

    // MARK: - Subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed
    var targetZone: HeartRateZone? {
        // Use timer's context-aware zone (handles progressive plans)
        intervalTimer.currentTargetZone
    }

    var formattedPace: String {
        currentPace.formattedPace
    }

    var formattedDistance: String {
        String(format: "%.2f km", totalDistance / 1000)
    }

    var isActive: Bool {
        timerState == .running || timerState == .paused
    }

    var isWalkingWorkout: Bool {
        plan?.isWalkingWorkout ?? false
    }

    var formattedSessionSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: sessionSteps)) ?? "\(sessionSteps)"
    }

    var formattedBestPace: String {
        bestPace > 0 ? bestPace.formattedPace : "--:--"
    }

    /// Returns pace difference formatted with +/- sign against effectiveBestPace (negative is faster/better)
    var formattedPaceDelta: String {
        guard effectiveBestPace > 0, currentPace > 0 else { return "--:--" }
        let delta = currentPace - effectiveBestPace
        let absDelta = abs(delta)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60
        if delta < -5 {
            return String(format: "-%d:%02d", minutes, seconds)
        } else if delta > 5 {
            return String(format: "+%d:%02d", minutes, seconds)
        } else {
            return "0:00"
        }
    }

    var isFasterThanBest: Bool {
        effectiveBestPace > 0 && currentPace > 0 && (currentPace - effectiveBestPace) < -5
    }

    var isSlowerThanBest: Bool {
        effectiveBestPace > 0 && currentPace > 0 && (currentPace - effectiveBestPace) > 5
    }

    var hasSameBlockComparison: Bool {
        bestSameBlockPace > 0 && currentPhase == .work
    }

    /// Effective record pace for the current block (best across ALL historical sessions).
    /// Falls back to overall best session avgPace when no per-block data available.
    var effectiveBestPace: Double {
        let blockKey = currentBlock > 0 ? currentBlock : 1
        let blockBest = bestPacesPerBlock[blockKey] ?? 0
        if blockBest > 0 { return blockBest }
        return bestPace
    }

    var formattedSameBlockBestPace: String {
        bestSameBlockPace > 0 ? bestSameBlockPace.formattedPace : "--:--"
    }

    var formattedSameBlockDelta: String {
        guard bestSameBlockPace > 0 else { return "--:--" }
        let absDelta = abs(currentIntervalPaceVsBest)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60
        let sign = currentIntervalPaceVsBest < 0 ? "-" : "+"
        return String(format: "%@%d:%02d", sign, minutes, seconds)
    }

    var activeService: MusicServiceType {
        musicController.activeService
    }

    // MARK: - Init
    init(
        intervalTimer: IntervalTimer? = nil,
        hrDataService: HRDataService? = nil,
        audioEngine: AudioEngineProtocol? = nil,
        garminManager: GarminManaging? = nil,
        healthKitManager: HealthKitManaging? = nil,
        sessionRepository: SessionRepositoryProtocol? = nil,
        musicController: UnifiedMusicController? = nil,
        coachingService: CoachingService? = nil
    ) {
        self.intervalTimer = intervalTimer ?? IntervalTimer()
        self.hrDataService = hrDataService ?? HRDataService.shared
        self.audioEngine = audioEngine ?? MetronomeEngine.shared
        self.garminManager = garminManager ?? GarminManager.shared
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        self._sessionRepository = sessionRepository ?? SessionRepository()
        self.musicController = musicController ?? UnifiedMusicController.shared
        self.coachingService = coachingService ?? CoachingService.shared

        // Configure coaching service with audio dependencies
        self.coachingService.configure(
            audioEngine: self.audioEngine,
            musicController: self.musicController
        )

        self.setupBindings()
        self.setupTimerCallbacks()
    }

    // MARK: - Setup
    private func setupBindings() {
        setupHRBindings()
        setupCoachingBindings()
        setupTimerBindings()
        setupMusicBindings()
    }

    private func setupHRBindings() {
        hrDataService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in self?.handleHeartRateUpdate(hr) }
            .store(in: &cancellables)

        hrDataService.$currentZoneStatus.assign(to: &$zoneStatus)
        hrDataService.$currentSource.assign(to: &$hrSource)
        hrDataService.$timeInZone.assign(to: &$timeInZone)
        hrDataService.$currentCadence.assign(to: &$currentCadence)
        hrDataService.$currentPace.assign(to: &$currentPace)
        hrDataService.$currentSpeed.assign(to: &$currentSpeed)
        hrDataService.$totalDistance.assign(to: &$totalDistance)
        hrDataService.$sessionSteps.assign(to: &$sessionSteps)
        hrDataService.$isSimulationMode.assign(to: &$isSimulationMode)

        garminManager.connectionStatePublisher
            .map { $0.isConnected }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in self?.isGarminConnected = connected }
            .store(in: &cancellables)

        hrDataService.$currentPace
            .sink { [weak self] pace in self?.updatePaceComparison(currentPace: pace) }
            .store(in: &cancellables)
    }

    private func setupCoachingBindings() {
        Publishers.CombineLatest(hrDataService.$currentCadence, hrDataService.$currentPace)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence, pace in
                guard let self = self,
                      self.timerState == .running,
                      self.currentPhase == .work || self.currentPhase == .rest else { return }
                self.coachingService.update(cadence: cadence, pace: pace)
            }
            .store(in: &cancellables)

        coachingService.$currentStatus.assign(to: &$coachingStatus)
        coachingService.$lastInstruction.assign(to: &$lastCoachingInstruction)
    }

    private func setupTimerBindings() {
        intervalTimer.$currentPhase.assign(to: &$currentPhase)
        intervalTimer.$timerState.assign(to: &$timerState)
        intervalTimer.$currentSeries.assign(to: &$currentSeries)
        intervalTimer.$totalSeries.assign(to: &$totalSeries)
        intervalTimer.$currentBlock.assign(to: &$currentBlock)
        intervalTimer.$totalBlocks.assign(to: &$totalBlocks)
        intervalTimer.$phaseRemainingTime.assign(to: &$phaseRemainingTime)
        intervalTimer.$totalElapsedTime.assign(to: &$totalElapsedTime)

        intervalTimer.$phaseRemainingTime
            .combineLatest(intervalTimer.$currentPhase)
            .map { [weak self] remaining, phase -> Double in
                guard let plan = self?.plan else { return 0 }
                let duration: TimeInterval
                switch phase {
                case .warmup: duration = plan.warmupDuration ?? 0
                case .work: duration = plan.workDuration
                case .rest: duration = plan.restDuration
                case .cooldown: duration = plan.cooldownDuration ?? 0
                default: duration = 0
                }
                guard duration > 0 else { return 0 }
                return 1.0 - (remaining / duration)
            }
            .assign(to: &$phaseProgress)
    }

    private func setupMusicBindings() {
        musicController.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.musicPlaybackState = state }
            .store(in: &cancellables)

        musicController.$nowPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in self?.nowPlayingTrack = track }
            .store(in: &cancellables)

        musicController.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in self?.isMusicConnected = connected }
            .store(in: &cancellables)
    }

    private func setupTimerCallbacks() {
        intervalTimer.onPhaseChange = { [weak self] oldPhase, newPhase in
            Task { @MainActor in
                await self?.handlePhaseChange(from: oldPhase, to: newPhase)
            }
        }

        intervalTimer.onSeriesComplete = { [weak self] series in
            Task { @MainActor in
                self?.handleSeriesComplete(series)
            }
        }

        intervalTimer.onWorkoutComplete = { [weak self] in
            Task { @MainActor in
                await self?.handleWorkoutComplete()
            }
        }

        intervalTimer.onTimeWarning = { [weak self] seconds in
            Task { @MainActor in
                await self?.handleTimeWarning(seconds)
            }
        }
    }

    // MARK: - Configuration
    func configure(with plan: TrainingPlan) async {
        self.plan = plan
        intervalTimer.configure(with: plan)
        metronomeBPM = plan.workZone.targetBPM

        // Load best session for time-in-zone comparison (session-level metric)
        bestSession = try? await sessionRepository.fetchBest(forPlanId: plan.id)

        // Load best pace per block across ALL sessions for this plan
        self.bestPacesPerBlock = (try? await sessionRepository.fetchBestPacesPerBlock(forPlanId: plan.id)) ?? [:]

        // Detect and connect to music service
        await musicController.detectActiveService()

        Log.training.info("Training configured: \(plan.name), bestPacesPerBlock: \(self.bestPacesPerBlock)")
    }

    // MARK: - Control
    func startWorkout() async throws {
        guard let plan = plan else {
            Log.training.error("Cannot start: no plan configured")
            return
        }

        // Initialize session
        currentSession = TrainingSession(
            planId: plan.id,
            planName: plan.name
        )

        // Reset stats
        hrSum = 0
        hrCount = 0
        maxHeartRate = 0
        minHeartRate = 999
        hrSamples = []
        intervalRecords = []
        totalDistance = 0

        // Try to connect to Garmin if not connected
        if !garminManager.isConnected {
            Log.training.info("Garmin not connected, attempting to scan...")
            await garminManager.startScanning()

            // Wait briefly for auto-connect to last device
            try? await Task.sleep(for: .seconds(2))
        }

        // Start data monitoring - prioritize real data sources
        if garminManager.isConnected {
            Log.training.info("Garmin connected - using Garmin data")
            try await hrDataService.start()
        } else if PedometerService.shared.isAvailable {
            // Use iPhone pedometer for cadence/distance/pace
            Log.training.info("Using iPhone sensors (pedometer + GPS)")
            try await hrDataService.start()
        } else {
            // No real data sources available - enable simulation
            let initialZone = plan.warmupZone ?? plan.workZone
            hrDataService.enableSimulation(targetHR: initialZone.targetCadence)
            Log.training.info("No sensors available - using simulated data (cadence target: \(initialZone.targetCadence) SPM)")
        }

        // Start zone tracking
        if let zone = targetZone {
            hrDataService.startZoneTracking(targetZone: zone)

            // Configure coaching service
            coachingService.setTargetZone(zone)
            coachingService.setRecordPace(bestSession?.avgPace)
            coachingService.isEnabled = isVoiceEnabled
            coachingService.setWorkoutRunning(true)
        }

        // Start HealthKit workout (non-blocking - may fail on simulator)
        do {
            try await healthKitManager.startWorkout(activityType: .running)
        } catch {
            Log.training.warning("HealthKit workout failed to start (expected on simulator): \(error)")
        }

        // Start audio
        if isMetronomeEnabled {
            try audioEngine.configureAudioSession()
            try audioEngine.startMetronome(
                bpm: metronomeBPM,
                volume: 0.7,
                soundType: .click
            )
        }

        // Start timer
        intervalTimer.start()

        // Send Garmin lap marker
        await garminManager.sendLapMarker()

        Log.training.info("Workout started")
    }

    func pauseWorkout() async {
        intervalTimer.pause()
        audioEngine.stopMetronome()

        try? await healthKitManager.pauseWorkout()

        Log.training.debug("Workout paused")
    }

    func resumeWorkout() async throws {
        intervalTimer.resume()

        if isMetronomeEnabled {
            try audioEngine.startMetronome(
                bpm: metronomeBPM,
                volume: 0.7,
                soundType: .click
            )
        }

        try await healthKitManager.resumeWorkout()

        Log.training.debug("Workout resumed")
    }

    func stopWorkout() async {
        intervalTimer.stop()
        audioEngine.stopMetronome()
        audioEngine.stopVoice()  // Stop any ongoing voice announcements
        hrDataService.stop()
        hrDataService.disableSimulation()
        coachingService.setWorkoutRunning(false)

        _ = try? await healthKitManager.endWorkout()

        // Save partial session
        await saveSession(completed: false)

        Log.training.info("Workout stopped")
    }

    func discardWorkout() async {
        intervalTimer.stop()
        audioEngine.stopMetronome()
        audioEngine.stopVoice()
        hrDataService.stop()
        hrDataService.disableSimulation()
        coachingService.setWorkoutRunning(false)

        _ = try? await healthKitManager.endWorkout()

        // Don't save - just discard
        currentSession = nil
        Log.training.info("Workout discarded (not saved)")
    }

    // MARK: - Event Handlers
    private func handlePhaseChange(from oldPhase: IntervalPhase, to newPhase: IntervalPhase) async {
        // Finalize previous interval record
        finalizeCurrentInterval()

        // Start new interval record
        startNewInterval(phase: newPhase)

        // Update zone tracking
        if let zone = targetZone {
            hrDataService.startZoneTracking(targetZone: zone)
            coachingService.setTargetZone(zone)

            // Update simulation target if in simulation mode
            if hrDataService.isSimulationMode {
                hrDataService.updateSimulatedTarget(zone.targetBPM)
            }
        }

        // Audio announcement with music ducking
        if isVoiceEnabled {
            // Duck music during announcement
            await musicController.duckForAnnouncement()

            await audioEngine.announcePhaseChange(newPhase)

            // Small delay to allow announcement to complete
            try? await Task.sleep(for: .milliseconds(500))

            // Restore music volume
            await musicController.restoreFromDuck()
        }

        // Update metronome BPM based on current target zone
        if let zone = targetZone {
            audioEngine.updateMetronomeBPM(zone.targetBPM)
        }

        // Garmin AutoLap
        await garminManager.sendLapMarker()

        // HealthKit lap event
        try? await healthKitManager.addLapEvent(at: Date())

        Log.training.info("Phase changed: \(oldPhase.rawValue) → \(newPhase.rawValue)")
    }

    private func handleSeriesComplete(_ series: Int) {
        Log.training.debug("Series \(series) complete")

        // Update comparison with best session
        updateBestSessionComparison()
    }

    private func handleWorkoutComplete() async {
        audioEngine.stopMetronome()
        hrDataService.stop()
        hrDataService.disableSimulation()

        if isVoiceEnabled {
            await audioEngine.announce("Entrenamiento completado. ¡Excelente trabajo!")
        }

        _ = try? await healthKitManager.endWorkout()

        // Save completed session
        await saveSession(completed: true)

        Log.training.info("Workout complete!")
    }

    private func handleTimeWarning(_ seconds: Int) async {
        if isVoiceEnabled {
            // Duck music during time warning announcement
            await musicController.duckForAnnouncement()

            await audioEngine.announceTimeWarning(secondsRemaining: seconds)

            // Small delay then restore
            try? await Task.sleep(for: .milliseconds(300))
            await musicController.restoreFromDuck()
        }
    }

    private func handleHeartRateUpdate(_ hr: Int) {
        currentHeartRate = hr

        guard hr > 0 else { return }

        // Update stats
        hrSum += hr
        hrCount += 1
        avgHeartRate = hrSum / hrCount
        maxHeartRate = max(maxHeartRate, hr)
        minHeartRate = min(minHeartRate, hr)

        // Store sample
        let sample = HRSample(bpm: hr, source: hrSource)
        hrSamples.append(sample)

        // Note: Coaching announcements are now handled by updateCoachingStatus()
        // which combines cadence AND pace, not just cadence
    }


    // MARK: - Audio Controls
    func toggleMetronome() {
        isMetronomeEnabled.toggle()

        if isMetronomeEnabled && timerState == .running {
            try? audioEngine.startMetronome(
                bpm: metronomeBPM,
                volume: 0.7,
                soundType: .click
            )
        } else {
            audioEngine.stopMetronome()
        }
    }

    func toggleVoice() {
        isVoiceEnabled.toggle()
        coachingService.isEnabled = isVoiceEnabled
        if !isVoiceEnabled {
            audioEngine.stopVoice()
        }
        let status = isVoiceEnabled ? "ON" : "OFF"
        Log.training.info("Voice announcements: \(status)")
    }

    func setMetronomeBPM(_ bpm: Int) {
        metronomeBPM = bpm
        audioEngine.updateMetronomeBPM(bpm)
    }

    func setMetronomeVolume(_ volume: Float) {
        metronomeVolume = volume
        audioEngine.updateMetronomeVolume(volume)
    }

    func setVoiceVolume(_ volume: Float) {
        voiceVolume = volume
        audioEngine.voiceVolume = volume
    }

    // MARK: - Music Controls
    func togglePlayPause() async {
        await musicController.togglePlayPause()
    }

    func skipToNextTrack() async {
        await musicController.skipToNext()
    }

    func skipToPreviousTrack() async {
        await musicController.skipToPrevious()
    }

    /// Returns the URL for the active music service app
    var musicAppURL: URL? {
        switch musicController.activeService {
        case .appleMusic: return URL(string: "music://")
        case .spotify: return URL(string: "spotify://")
        case .none: return URL(string: "music://")
        }
    }

    // MARK: - Interval Recording
    func startNewInterval(phase: IntervalPhase) {
        hasAnnouncedSameBlockImprovement = false
        currentIntervalRecord = IntervalRecord(
            phase: phase,
            seriesNumber: currentSeries,
            blockNumber: currentBlock,
            targetCadence: targetZone?.targetCadence ?? 0,
            startTime: totalElapsedTime,
            startDistance: totalDistance
        )
    }

    func finalizeCurrentInterval() {
        guard var record = currentIntervalRecord else { return }
        record.duration = totalElapsedTime - record.startTime
        record.distance = max(0, totalDistance - record.startDistance)
        record.hrSamples = hrSamples
        record.avgHR = hrSamples.isEmpty ? 0 : hrSamples.map(\.bpm).reduce(0, +) / hrSamples.count
        record.maxHR = hrSamples.map(\.bpm).max() ?? 0
        record.minHR = hrSamples.map(\.bpm).min() ?? 0
        record.timeInZone = timeInZone
        // Compute avg pace from distance/time when available; fall back to live pace
        if record.distance > 0 && record.duration > 0 {
            record.avgPace = record.duration / (record.distance / 1000)
        } else {
            record.avgPace = currentPace
        }
        intervalRecords.append(record)
        hrSamples = []
        currentIntervalRecord = nil

        // Update in-memory best pace for this block live during training
        if record.phase == .work, record.avgPace > 0 {
            let k = record.blockNumber > 0 ? record.blockNumber : 1
            if let existing = bestPacesPerBlock[k] {
                if record.avgPace < existing { bestPacesPerBlock[k] = record.avgPace }
            } else {
                bestPacesPerBlock[k] = record.avgPace
            }
        }
    }

    func saveSession(completed: Bool) async {
        finalizeCurrentInterval()
        guard var session = currentSession, totalElapsedTime >= 5 else { return }
        session.endDate = Date()
        session.isCompleted = completed
        session.intervals = intervalRecords
        session.totalDistance = totalDistance
        session.avgHeartRate = avgHeartRate
        session.maxHeartRate = maxHeartRate
        session.minHeartRate = minHeartRate == 999 ? 0 : minHeartRate
        session.timeInZone = timeInZone
        session.totalSteps = sessionSteps
        session.isWalkingWorkout = isWalkingWorkout
        session.score = calculateScore(session)
        do {
            try await sessionRepository.save(session)
            self.currentSession = session
            Log.training.info("Session saved: \(session.planName), score=\(session.score)")
        } catch { Log.training.error("Failed to save session: \(error)") }
    }

    private func calculateScore(_ session: TrainingSession) -> Double {
        guard session.duration > 0, let plan = plan else { return 0 }
        let tizPct = (session.timeInZone / session.duration) * 100
        let compRate = Double(session.completedIntervals) / Double(plan.seriesCount) * 100
        let paceScore = session.avgPace.map { max(0, min(100, (480 - $0) / 3)) } ?? 50
        let distScore = min(100, (session.totalDistance / (session.duration * 3.0)) * 100)
        return min(100, max(0, 0.4 * min(tizPct, 100) + 0.3 * paceScore + 0.2 * compRate + 0.1 * distScore))
    }

    func skipCurrentPhase() {
        guard currentPhase == .warmup || currentPhase == .cooldown else { return }
        if currentPhase == .warmup {
            intervalTimer.skipWarmup()
        } else {
            intervalTimer.skipCooldown()
        }
    }

    func updateBestSessionComparison() {
        guard let best = bestSession else { isAheadOfBest = true; deltaVsBest = 0; return }
        let currentPct = totalElapsedTime > 0 ? (timeInZone / totalElapsedTime) * 100 : 0
        deltaVsBest = currentPct - best.timeInZonePercentage
        isAheadOfBest = deltaVsBest >= 0
    }

    func updatePaceComparison(currentPace pace: Double) {
        guard pace > 0 else { paceVsBest = 0; return }
        if let best = bestSession, let bp = best.avgPace, bp > 0 { bestPace = bp; paceVsBest = pace - bp }
        else { bestPace = 0; paceVsBest = 0 }

        updateSameBlockComparison(currentPace: pace)
    }

    private func updateSameBlockComparison(currentPace pace: Double) {
        guard currentPhase == .work else {
            bestSameBlockPace = 0
            currentIntervalPaceVsBest = 0
            isAheadOfSameBlockBest = false
            return
        }

        // Find best pace from all completed work intervals of same block
        let sameBlockBest = intervalRecords
            .filter { $0.phase == .work && $0.blockNumber == currentBlock && $0.avgPace > 0 }
            .map(\.avgPace)
            .min()

        guard let best = sameBlockBest else {
            bestSameBlockPace = 0
            currentIntervalPaceVsBest = 0
            isAheadOfSameBlockBest = false
            return
        }

        bestSameBlockPace = best
        currentIntervalPaceVsBest = pace - best  // negative = faster than best

        let wasAhead = isAheadOfSameBlockBest
        isAheadOfSameBlockBest = currentIntervalPaceVsBest < -5  // 5+ sec/km faster

        // Announce once when improvement is first detected
        if isAheadOfSameBlockBest && !wasAhead && !hasAnnouncedSameBlockImprovement {
            hasAnnouncedSameBlockImprovement = true
            Task {
                await audioEngine.announce("¡Vas mejor que en la ronda anterior!")
            }
        }
    }
}

// MARK: - Preview Helpers
extension TrainingViewModel {
    static func preview(phase: IntervalPhase = .work, hr: Int = 145, cadence: Int = 170,
                        series: Int = 2, totalSeries: Int = 4, pace: Double = 330, bestPace: Double = 320) -> TrainingViewModel {
        let vm = TrainingViewModel(garminManager: MockGarminManager(), healthKitManager: MockHealthKitManager(),
                                   sessionRepository: MockSessionRepository(), musicController: .shared)
        vm.currentPhase = phase; vm.currentHeartRate = hr; vm.currentCadence = cadence
        vm.currentSeries = series; vm.totalSeries = totalSeries; vm.phaseRemainingTime = 90
        vm.phaseProgress = 0.5; vm.zoneStatus = .inZone; vm.currentPace = pace
        vm.bestPace = bestPace; vm.paceVsBest = pace - bestPace
        vm.nowPlayingTrack = MusicTrack(id: "preview", title: "Running Motivation", artist: "Workout Mix", duration: 210)
        vm.musicPlaybackState = .playing; vm.isMusicConnected = true
        return vm
    }
}

