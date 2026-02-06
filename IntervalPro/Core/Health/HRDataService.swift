import Foundation
import Combine

/// Unified data service that merges Garmin and HealthKit streams
/// Tracks: Heart Rate (FC), Cadence (SPM), Pace, Speed
/// Zone tracking is based on CADENCE (not heart rate)
/// Per CLAUDE.md: Prioritize Garmin when available, fallback to HealthKit
@MainActor
final class HRDataService: ObservableObject {
    // MARK: - Singleton
    static let shared = HRDataService()

    // MARK: - Published State - Heart Rate (FC - just for display)
    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var currentSource: DataSource = .healthKit
    @Published private(set) var isReceivingData: Bool = false

    // MARK: - Published State - Running Metrics
    @Published private(set) var currentPace: Double = 0  // sec/km
    @Published private(set) var currentSpeed: Double = 0  // km/h
    @Published private(set) var currentCadence: Int = 0   // steps per minute (SPM)
    @Published private(set) var totalDistance: Double = 0  // meters

    // MARK: - Zone Tracking (based on CADENCE, not heart rate)
    @Published private(set) var currentZoneStatus: ZoneStatus = .inZone
    @Published private(set) var timeInZone: TimeInterval = 0

    // MARK: - Dependencies
    private let garminManager: GarminManaging
    private let healthKitManager: HealthKitManaging
    private let pedometerService: PedometerService

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lastHRTimestamp = Date()
    private var dataTimeoutTask: Task<Void, Never>?
    private var zoneTrackingTimer: Timer?
    private var targetZone: HeartRateZone?

    // MARK: - Constants
    private let dataTimeoutSeconds: TimeInterval = 5.0
    private let outlierFilterWindow = 5
    private var recentHRValues: [Int] = []

    // MARK: - Simulation Mode (for testing without Garmin)
    @Published var isSimulationMode: Bool = false
    private var simulationTask: Task<Void, Never>?
    private var simulatedTargetHR: Int = 140

    // MARK: - Subjects
    private let heartRateSubject = PassthroughSubject<HRSample, Never>()

    // MARK: - Public Publisher
    var heartRatePublisher: AnyPublisher<HRSample, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    // MARK: - Init
    init(garminManager: GarminManaging? = nil, healthKitManager: HealthKitManaging? = nil,
         pedometerService: PedometerService? = nil) {
        self.garminManager = garminManager ?? GarminManager.shared
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        self.pedometerService = pedometerService ?? PedometerService.shared

        setupSubscriptions()
        setupFallbackNotification()
    }
    

    // MARK: - Setup
    private func setupSubscriptions() {
        // Subscribe to Garmin HR - higher priority
        garminManager.heartRatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bpm in
                self?.processHeartRate(bpm, source: .garmin)
            }
            .store(in: &cancellables)

        // Subscribe to HealthKit HR - fallback
        healthKitManager.heartRatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bpm in
                self?.processHeartRate(bpm, source: .healthKit)
            }
            .store(in: &cancellables)

        // Subscribe to Garmin pace/speed/cadence
        garminManager.pacePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pace in
                self?.currentPace = pace
            }
            .store(in: &cancellables)

        garminManager.speedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speed in
                self?.currentSpeed = speed
            }
            .store(in: &cancellables)

        garminManager.cadencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence in
                self?.processCadence(cadence, source: .garmin)
            }
            .store(in: &cancellables)

        // Subscribe to iPhone pedometer cadence (primary source for cadence)
        pedometerService.cadencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence in
                self?.processCadence(cadence, source: .pedometer)
            }
            .store(in: &cancellables)

        // Subscribe to iPhone pedometer pace (fallback when no Garmin)
        pedometerService.pacePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pace in
                guard let self = self else { return }
                // Only use pedometer pace if Garmin is not connected
                if !self.garminManager.isConnected {
                    self.currentPace = pace
                    self.currentSpeed = 3600.0 / pace  // Convert sec/km to km/h
                }
            }
            .store(in: &cancellables)

        // Subscribe to iPhone pedometer distance
        pedometerService.distancePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] distance in
                guard let self = self else { return }
                // Always update total distance from pedometer
                self.totalDistance = distance
            }
            .store(in: &cancellables)

        // Monitor Garmin connection state
        garminManager.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleGarminConnectionChange(state)
            }
            .store(in: &cancellables)
    }

    private func setupFallbackNotification() {
        NotificationCenter.default.publisher(for: .garminFallbackActivated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.activateHealthKitFallback()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Processing
    private func processHeartRate(_ bpm: Int, source: DataSource) {
        // Source prioritization: Garmin > HealthKit
        // If Garmin is connected and we receive HealthKit data, ignore it
        if source == .healthKit && garminManager.isConnected {
            return
        }

        // Outlier filtering
        guard isValidHeartRate(bpm) else {
            Log.health.warning("HR outlier filtered: \(bpm) from \(source.rawValue)")
            return
        }

        // Apply smoothing
        let smoothedBPM = applySmoothing(bpm)

        // Update state - HR is just for display, NOT for zone tracking
        currentHeartRate = smoothedBPM
        currentSource = source
        isReceivingData = true
        lastHRTimestamp = Date()

        // NOTE: Zone tracking is based on CADENCE, not heart rate
        // See processCadence() for zone status updates

        // Publish sample
        let sample = HRSample(
            timestamp: Date(),
            bpm: smoothedBPM,
            source: source
        )
        heartRateSubject.send(sample)

        // Reset timeout
        resetDataTimeout()
    }

    private func isValidHeartRate(_ bpm: Int) -> Bool {
        // Basic range validation
        guard bpm >= 30 && bpm <= 250 else {
            return false
        }

        // Outlier detection using recent values
        guard recentHRValues.count >= 3 else {
            return true  // Not enough data for outlier detection
        }

        let recentAvg = recentHRValues.reduce(0, +) / recentHRValues.count

        // Allow up to 30 BPM deviation from recent average
        let maxDeviation = 30
        return abs(bpm - recentAvg) <= maxDeviation
    }

    private func applySmoothing(_ bpm: Int) -> Int {
        recentHRValues.append(bpm)

        // Keep only last N values
        if recentHRValues.count > outlierFilterWindow {
            recentHRValues.removeFirst()
        }

        // Simple moving average
        guard recentHRValues.count >= 2 else {
            return bpm
        }

        let sum = recentHRValues.reduce(0, +)
        return sum / recentHRValues.count
    }

    private func resetDataTimeout() {
        dataTimeoutTask?.cancel()
        dataTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(dataTimeoutSeconds))

            guard !Task.isCancelled else { return }

            isReceivingData = false
            Log.health.warning("HR data timeout - no data received for \(self.dataTimeoutSeconds)s")
        }
    }

    // MARK: - Cadence Processing (Zone Tracking)
    /// Process cadence data - THIS is what zone tracking uses
    /// Sources: Garmin (if available) or iPhone pedometer (primary)
    private func processCadence(_ cadence: Int, source: DataSource) {
        // Source prioritization: Garmin > Pedometer
        // If Garmin is connected and providing cadence, ignore pedometer
        if source == .pedometer && garminManager.isConnected && currentCadence > 0 {
            // Only ignore if we've recently received Garmin cadence
            return
        }

        // Validate cadence range (typical running: 140-200 SPM)
        guard cadence >= 100 && cadence <= 220 else {
            Log.health.warning("Cadence outlier filtered: \(cadence) from \(source.rawValue)")
            return
        }

        currentCadence = cadence

        // Update zone status based on CADENCE (not heart rate)
        if let zone = targetZone {
            currentZoneStatus = zone.status(for: cadence)
        }

        Log.health.debug("Cadence: \(cadence) SPM from \(source.rawValue), zone: \(self.currentZoneStatus)")
    }

    // MARK: - Garmin Connection Handling
    private func handleGarminConnectionChange(_ state: GarminConnectionState) {
        switch state {
        case .connected:
            Log.health.info("Garmin connected, using as primary HR source")
            currentSource = .garmin

        case .disconnected, .failed:
            Log.health.info("Garmin disconnected, falling back to HealthKit")
            activateHealthKitFallback()

        case .reconnecting:
            // Keep using last known source during reconnection
            break

        default:
            break
        }
    }

    private func activateHealthKitFallback() {
        currentSource = .healthKit

        Task {
            do {
                try await healthKitManager.startHeartRateMonitoring()
                Log.health.info("HealthKit fallback activated")
            } catch {
                Log.health.error("Failed to activate HealthKit fallback: \(error)")
            }
        }
    }

    // MARK: - Zone Tracking (Cadence-based)
    func startZoneTracking(targetZone: HeartRateZone) {
        self.targetZone = targetZone
        timeInZone = 0

        zoneTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateZoneTime()
            }
        }

        Log.health.info("Cadence zone tracking started: target \(targetZone.targetCadence) SPM")
    }

    func stopZoneTracking() {
        zoneTrackingTimer?.invalidate()
        zoneTrackingTimer = nil
        targetZone = nil

        Log.health.info("Zone tracking stopped. Time in zone: \(self.timeInZone.formattedMinutesSeconds)")
    }

    private func updateZoneTime() {
        guard targetZone != nil else { return }

        if currentZoneStatus.isInZone {
            timeInZone += 1
        }
    }

    func getTimeInZonePercentage(totalDuration: TimeInterval) -> Double {
        guard totalDuration > 0 else { return 0 }
        return (timeInZone / totalDuration) * 100
    }

    // MARK: - Control
    func start() async throws {
        // Try Garmin first
        if !garminManager.isConnected {
            await garminManager.startScanning()
        }

        // Start iPhone pedometer for cadence detection (primary cadence source)
        pedometerService.start()

        // Also start HealthKit as backup (non-blocking - may fail without paid dev account)
        do {
            try await healthKitManager.startHeartRateMonitoring()
        } catch {
            Log.health.warning("HealthKit HR monitoring failed (expected without paid account): \(error)")
            // Continue anyway - Garmin is the primary source
        }

        Log.health.info("HRDataService started")
    }

    func stop() {
        dataTimeoutTask?.cancel()
        stopZoneTracking()
        pedometerService.stop()
        healthKitManager.stopHeartRateMonitoring()
        recentHRValues.removeAll()

        isReceivingData = false

        Log.health.info("HRDataService stopped")
    }

    func reset() {
        currentHeartRate = 0
        currentPace = 0
        currentSpeed = 0
        currentCadence = 0
        totalDistance = 0
        timeInZone = 0
        recentHRValues.removeAll()
    }

    // MARK: - Simulation Mode

    /// Enable simulation mode for testing without real devices
    /// targetCadence = target cadence in SPM (steps per minute) for zone tracking
    func enableSimulation(targetHR: Int = 150) {
        isSimulationMode = true
        simulatedTargetHR = targetHR  // This is actually cadence target for zone tracking
        currentSource = .simulated
        isReceivingData = true

        simulationTask?.cancel()
        simulationTask = Task { @MainActor in
            Log.health.info("Simulation started - Cadence target: \(targetHR) SPM")

            var currentSimulatedCadence = 140  // Start from low cadence
            var currentSimulatedHR = 100  // Start from moderate HR

            while !Task.isCancelled && isSimulationMode {
                // Simulate gradual CADENCE changes toward target with some variance
                let cadenceDiff = simulatedTargetHR - currentSimulatedCadence
                let cadenceChange: Int
                if abs(cadenceDiff) > 10 {
                    cadenceChange = cadenceDiff > 0 ? Int.random(in: 2...5) : Int.random(in: -5 ... -2)
                } else {
                    cadenceChange = Int.random(in: -3...3)
                }
                currentSimulatedCadence = max(130, min(200, currentSimulatedCadence + cadenceChange))

                // Simulate HR separately (correlated with cadence somewhat)
                let hrChange = Int.random(in: -2...3)
                currentSimulatedHR = max(90, min(190, currentSimulatedHR + hrChange))

                // Process the simulated data
                processSimulatedData(cadence: currentSimulatedCadence, heartRate: currentSimulatedHR)

                // Update every 1 second
                try? await Task.sleep(for: .seconds(1))
            }

            Log.health.info("Simulation stopped")
        }
    }

    /// Update the target cadence for simulation (e.g., when phase changes)
    func updateSimulatedTarget(_ targetCadence: Int) {
        simulatedTargetHR = targetCadence
        Log.health.debug("Simulation cadence target updated to: \(targetCadence) SPM")
    }

    /// Disable simulation mode
    func disableSimulation() {
        isSimulationMode = false
        simulationTask?.cancel()
        simulationTask = nil
    }

    private func processSimulatedData(cadence: Int, heartRate: Int) {
        // Update cadence - THIS affects zone tracking
        currentCadence = cadence

        // Update heart rate - just for display
        currentHeartRate = heartRate
        isReceivingData = true

        // Simulate pace based on cadence (rough approximation)
        // Higher cadence = faster pace
        // Cadence 160 SPM ≈ 6:00/km (360 sec), 180 SPM ≈ 5:00/km (300 sec)
        // Formula: pace = 660 - (cadence * 2) -> gives reasonable running paces
        let simulatedPace = max(240, min(600, 660 - (cadence * 2)))
        currentPace = Double(simulatedPace)
        currentSpeed = 3600.0 / Double(simulatedPace)  // km/h from sec/km

        // Update zone status based on CADENCE (not heart rate)
        if let zone = targetZone {
            currentZoneStatus = zone.status(for: cadence)
        }

        // Publish HR sample for recording
        let sample = HRSample(
            timestamp: Date(),
            bpm: heartRate,
            source: .simulated
        )
        heartRateSubject.send(sample)
    }
}

// MARK: - HR Zone Calculator Service
final class HRZoneCalculator {
    /// Calculate which zone a heart rate falls into based on max HR
    static func calculateZone(
        bpm: Int,
        maxHR: Int
    ) -> HRZoneLevel {
        let percentage = Double(bpm) / Double(maxHR) * 100

        switch percentage {
        case 0..<50:
            return .zone1
        case 50..<60:
            return .zone2
        case 60..<70:
            return .zone3
        case 70..<80:
            return .zone4
        case 80..<90:
            return .zone5
        default:
            return .zone5Max
        }
    }

    /// Estimate max HR using age-based formula
    static func estimateMaxHR(age: Int) -> Int {
        // Tanaka formula: 208 - (0.7 × age)
        return 208 - Int(0.7 * Double(age))
    }
}

// MARK: - HR Zone Levels
enum HRZoneLevel: Int, CaseIterable {
    case zone1 = 1  // Recovery: 50-60%
    case zone2 = 2  // Aerobic: 60-70%
    case zone3 = 3  // Tempo: 70-80%
    case zone4 = 4  // Threshold: 80-90%
    case zone5 = 5  // VO2 Max: 90-100%
    case zone5Max = 6  // Max effort

    var name: String {
        switch self {
        case .zone1: return "Recuperación"
        case .zone2: return "Aeróbico"
        case .zone3: return "Tempo"
        case .zone4: return "Umbral"
        case .zone5: return "VO2 Max"
        case .zone5Max: return "Máximo"
        }
    }

    var percentageRange: ClosedRange<Int> {
        switch self {
        case .zone1: return 0...50
        case .zone2: return 50...60
        case .zone3: return 60...70
        case .zone4: return 70...80
        case .zone5: return 80...90
        case .zone5Max: return 90...100
        }
    }
}
