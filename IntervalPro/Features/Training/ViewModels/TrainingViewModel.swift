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

    // MARK: - Published State - Heart Rate
    @Published var currentHeartRate: Int = 0
    @Published var zoneStatus: ZoneStatus = .inZone
    @Published var hrSource: DataSource = .healthKit
    @Published var timeInZone: TimeInterval = 0

    // MARK: - Published State - Metrics
    @Published var currentPace: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var totalDistance: Double = 0
    @Published var avgHeartRate: Int = 0

    // MARK: - Published State - Best Session Comparison
    @Published var bestSession: TrainingSession?
    @Published var deltaVsBest: TimeInterval = 0
    @Published var isAheadOfBest: Bool = false
    @Published var bestPace: Double = 0        // Best session avg pace (sec/km)
    @Published var paceVsBest: Double = 0      // Current pace - best pace (negative = faster)

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
    private let audioEngine: AudioEngineProtocol
    private let garminManager: GarminManaging
    private let healthKitManager: HealthKitManaging
    private let sessionRepository: SessionRepositoryProtocol
    private let musicController: UnifiedMusicController

    // MARK: - Session Tracking
    private var currentSession: TrainingSession?
    private var currentIntervalRecord: IntervalRecord?
    private var hrSamples: [HRSample] = []
    private var intervalRecords: [IntervalRecord] = []

    // MARK: - Stats
    private var hrSum: Int = 0
    private var hrCount: Int = 0
    private var maxHeartRate: Int = 0
    private var minHeartRate: Int = 999

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

    var formattedBestPace: String {
        bestPace > 0 ? bestPace.formattedPace : "--:--"
    }

    /// Returns pace difference formatted with +/- sign (negative is faster/better)
    var formattedPaceDelta: String {
        guard bestPace > 0, currentPace > 0 else { return "--:--" }

        let absDelta = abs(paceVsBest)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60

        if paceVsBest < -5 {
            // More than 5 seconds faster
            return String(format: "-%d:%02d", minutes, seconds)
        } else if paceVsBest > 5 {
            // More than 5 seconds slower
            return String(format: "+%d:%02d", minutes, seconds)
        } else {
            // Within 5 seconds - essentially on pace
            return "0:00"
        }
    }

    var isFasterThanBest: Bool {
        paceVsBest < -5  // At least 5 sec/km faster
    }

    var isSlowerThanBest: Bool {
        paceVsBest > 5  // At least 5 sec/km slower
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
        musicController: UnifiedMusicController? = nil
    ) {
        // Asignamos los valores aquí dentro (MainActor), donde es seguro instanciarlos
        self.intervalTimer = intervalTimer ?? IntervalTimer()
        self.hrDataService = hrDataService ?? HRDataService.shared
        self.audioEngine = audioEngine ?? MetronomeEngine.shared
        self.garminManager = garminManager ?? GarminManager.shared
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        self.sessionRepository = sessionRepository ?? SessionRepository()
        self.musicController = musicController ?? UnifiedMusicController.shared

        // El resto de tu código de inicialización se queda igual:
        self.setupBindings()
        self.setupTimerCallbacks()
    }

    // MARK: - Setup
    private func setupBindings() {
        // HR Data bindings
        hrDataService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.handleHeartRateUpdate(hr)
            }
            .store(in: &cancellables)

        hrDataService.$currentZoneStatus
            .assign(to: &$zoneStatus)

        hrDataService.$currentSource
            .assign(to: &$hrSource)

        hrDataService.$timeInZone
            .assign(to: &$timeInZone)

        hrDataService.$currentPace
            .assign(to: &$currentPace)

        hrDataService.$currentSpeed
            .assign(to: &$currentSpeed)

        // Timer state bindings
        intervalTimer.$currentPhase
            .assign(to: &$currentPhase)

        intervalTimer.$timerState
            .assign(to: &$timerState)

        intervalTimer.$currentSeries
            .assign(to: &$currentSeries)

        intervalTimer.$totalSeries
            .assign(to: &$totalSeries)

        intervalTimer.$currentBlock
            .assign(to: &$currentBlock)

        intervalTimer.$totalBlocks
            .assign(to: &$totalBlocks)

        intervalTimer.$phaseRemainingTime
            .assign(to: &$phaseRemainingTime)

        intervalTimer.$totalElapsedTime
            .assign(to: &$totalElapsedTime)

        // Progress calculation
        intervalTimer.$phaseRemainingTime
            .combineLatest(intervalTimer.$currentPhase)
            .map { [weak self] remaining, phase -> Double in
                guard let plan = self?.plan else { return 0 }
                let duration: TimeInterval
                switch phase {
                case .warmup:
                    duration = plan.warmupDuration ?? 0
                case .work:
                    duration = plan.workDuration
                case .rest:
                    duration = plan.restDuration
                case .cooldown:
                    duration = plan.cooldownDuration ?? 0
                default:
                    duration = 0
                }
                guard duration > 0 else { return 0 }
                return 1.0 - (remaining / duration)
            }
            .assign(to: &$phaseProgress)

        // Music controller bindings
        musicController.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.musicPlaybackState = state
            }
            .store(in: &cancellables)

        musicController.$nowPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.nowPlayingTrack = track
            }
            .store(in: &cancellables)

        musicController.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isMusicConnected = connected
            }
            .store(in: &cancellables)

        // Pace comparison with best session
        hrDataService.$currentPace
            .sink { [weak self] pace in
                self?.updatePaceComparison(currentPace: pace)
            }
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

        // Load best session for comparison
        bestSession = try? await sessionRepository.fetchBest(forPlanId: plan.id)

        // Detect and connect to music service
        await musicController.detectActiveService()

        Log.training.info("Training configured: \(plan.name)")
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

        // Start HR monitoring - use simulation if no real source available
        if !garminManager.isConnected {
            // Enable simulation mode for testing without Garmin
            // Start with warmup zone if available, otherwise first work zone
            let initialZone = plan.warmupZone ?? plan.workZone
            hrDataService.enableSimulation(targetHR: initialZone.targetBPM)
            Log.training.info("No Garmin connected - using simulated HR data")
        } else {
            try await hrDataService.start()
        }

        // Start zone tracking
        if let zone = targetZone {
            hrDataService.startZoneTracking(targetZone: zone)
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
        hrDataService.stop()
        hrDataService.disableSimulation()

        _ = try? await healthKitManager.endWorkout()

        // Save partial session
        await saveSession(completed: false)

        Log.training.info("Workout stopped")
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

        // Voice alert if out of zone for too long
        if case .belowZone(let diff) = zoneStatus, diff > 10 {
            Task {
                if isVoiceEnabled {
                    await audioEngine.announceZoneStatus(zoneStatus)
                }
            }
        } else if case .aboveZone(let diff) = zoneStatus, diff > 10 {
            Task {
                if isVoiceEnabled {
                    await audioEngine.announceZoneStatus(zoneStatus)
                }
            }
        }
    }

    // MARK: - Interval Recording
    private func startNewInterval(phase: IntervalPhase) {
        currentIntervalRecord = IntervalRecord(
            phase: phase,
            seriesNumber: currentSeries,
            startTime: totalElapsedTime
        )
    }

    private func finalizeCurrentInterval() {
        guard var record = currentIntervalRecord else { return }

        record.duration = totalElapsedTime - record.startTime
        record.hrSamples = hrSamples
        record.avgHR = hrSamples.isEmpty ? 0 : hrSamples.map(\.bpm).reduce(0, +) / hrSamples.count
        record.maxHR = hrSamples.map(\.bpm).max() ?? 0
        record.minHR = hrSamples.map(\.bpm).min() ?? 0
        record.timeInZone = timeInZone
        record.avgPace = currentPace

        intervalRecords.append(record)
        hrSamples = []

        currentIntervalRecord = nil
    }

    // MARK: - Session Saving
    private func saveSession(completed: Bool) async {
        finalizeCurrentInterval()

        guard var session = currentSession else { return }

        session.endDate = Date()
        session.isCompleted = completed
        session.intervals = intervalRecords
        session.totalDistance = totalDistance
        session.avgHeartRate = avgHeartRate
        session.maxHeartRate = maxHeartRate
        session.minHeartRate = minHeartRate == 999 ? 0 : minHeartRate
        session.timeInZone = timeInZone

        // Calculate score
        session.score = calculateScore(session)

        do {
            try await sessionRepository.save(session)
            self.currentSession = session
            Log.training.info("Session saved: score \(session.score)")
        } catch {
            Log.training.error("Failed to save session: \(error)")
        }
    }

    private func calculateScore(_ session: TrainingSession) -> Double {
        guard session.duration > 0, let plan = plan else { return 0 }

        // Scoring formula from PRD:
        // Score = (0.4 × TimeInZone%) + (0.3 × PaceScore) + (0.2 × CompletionRate) + (0.1 × DistanceScore)

        let timeInZonePercent = (session.timeInZone / session.duration) * 100
        let timeInZoneScore = min(timeInZonePercent, 100)

        let completionRate = Double(session.completedIntervals) / Double(plan.seriesCount) * 100

        // Pace score: lower is better, normalize to 0-100
        let paceScore: Double
        if let pace = session.avgPace, pace > 0 {
            // Assume 3:00/km is perfect (180 sec), 8:00/km is poor (480 sec)
            let normalizedPace = max(0, min(100, (480 - pace) / 3))
            paceScore = normalizedPace
        } else {
            paceScore = 50  // Neutral if no pace data
        }

        // Distance score based on expected distance for duration
        let expectedDistance = session.duration * 3.0  // ~3 m/s average running
        let distanceScore = min(100, (session.totalDistance / expectedDistance) * 100)

        let score = (0.4 * timeInZoneScore) +
                    (0.3 * paceScore) +
                    (0.2 * completionRate) +
                    (0.1 * distanceScore)

        return min(100, max(0, score))
    }

    // MARK: - Best Session Comparison
    private func updateBestSessionComparison() {
        guard let best = bestSession else {
            isAheadOfBest = true
            deltaVsBest = 0
            return
        }

        // Compare time in zone at this point
        let currentTimeInZonePercent = totalElapsedTime > 0 ?
            (timeInZone / totalElapsedTime) * 100 : 0

        let bestTimeInZonePercent = best.timeInZonePercentage

        deltaVsBest = currentTimeInZonePercent - bestTimeInZonePercent
        isAheadOfBest = deltaVsBest >= 0
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

    func setMetronomeBPM(_ bpm: Int) {
        metronomeBPM = bpm
        audioEngine.updateMetronomeBPM(bpm)
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
        let urlString: String
        switch musicController.activeService {
        case .appleMusic:
            urlString = "music://"
        case .spotify:
            urlString = "spotify://"
        case .none:
            urlString = "music://"  // Default to Apple Music
        }
        return URL(string: urlString)
    }

    // MARK: - Pace Comparison
    private func updatePaceComparison(currentPace: Double) {
        guard currentPace > 0 else {
            paceVsBest = 0
            return
        }

        // If we have a best session with pace data, compare
        if let best = bestSession, let bestAvgPace = best.avgPace, bestAvgPace > 0 {
            bestPace = bestAvgPace
            // Negative means current is faster (better)
            paceVsBest = currentPace - bestAvgPace
        } else {
            // No previous record, current becomes the baseline
            bestPace = 0
            paceVsBest = 0
        }
    }
}

// MARK: - Preview Helpers
extension TrainingViewModel {
    static func preview(
        phase: IntervalPhase = .work,
        hr: Int = 168,
        series: Int = 2,
        totalSeries: Int = 4,
        pace: Double = 330,  // 5:30/km
        bestPace: Double = 320  // 5:20/km
    ) -> TrainingViewModel {
        let vm = TrainingViewModel(
            garminManager: MockGarminManager(),
            healthKitManager: MockHealthKitManager(),
            sessionRepository: MockSessionRepository(),
            musicController: .shared
        )

        vm.currentPhase = phase
        vm.currentHeartRate = hr
        vm.currentSeries = series
        vm.totalSeries = totalSeries
        vm.phaseRemainingTime = 90
        vm.phaseProgress = 0.5
        vm.zoneStatus = .inZone
        vm.currentPace = pace
        vm.bestPace = bestPace
        vm.paceVsBest = pace - bestPace

        // Preview music state
        vm.nowPlayingTrack = MusicTrack(
            id: "preview",
            title: "Running Motivation",
            artist: "Workout Mix",
            duration: 210
        )
        vm.musicPlaybackState = .playing
        vm.isMusicConnected = true

        return vm
    }
}
