import Foundation
import Combine

/// Unified heart rate data service that merges Garmin and HealthKit streams
/// Per CLAUDE.md: Prioritize Garmin when available, fallback to HealthKit
@MainActor
final class HRDataService: ObservableObject {
    // MARK: - Singleton
    static let shared = HRDataService()

    // MARK: - Published State
    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var currentSource: DataSource = .healthKit
    @Published private(set) var isReceivingData: Bool = false
    @Published private(set) var currentPace: Double = 0  // sec/km
    @Published private(set) var currentSpeed: Double = 0  // km/h
    @Published private(set) var currentCadence: Int = 0

    // MARK: - Zone Tracking
    @Published private(set) var currentZoneStatus: ZoneStatus = .inZone
    @Published private(set) var timeInZone: TimeInterval = 0

    // MARK: - Dependencies
    private let garminManager: GarminManaging
    private let healthKitManager: HealthKitManaging

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
    // Unificamos todo en un solo init
    init(garminManager: GarminManaging? = nil, healthKitManager: HealthKitManaging? = nil) {
        // Si no nos pasan nada (es nil), usamos los Singletons compartidos.
        // Esto evita el warning de "Main Actor" en la declaración.
        self.garminManager = garminManager ?? GarminManager.shared
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        
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
                self?.currentCadence = cadence
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

        // Update state
        currentHeartRate = smoothedBPM
        currentSource = source
        isReceivingData = true
        lastHRTimestamp = Date()

        // Update zone status if tracking
        if let zone = targetZone {
            currentZoneStatus = zone.status(for: smoothedBPM)
        }

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

    // MARK: - Zone Tracking
    func startZoneTracking(targetZone: HeartRateZone) {
        self.targetZone = targetZone
        timeInZone = 0

        zoneTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateZoneTime()
            }
        }

        Log.health.info("Zone tracking started: target \(targetZone.targetBPM) BPM")
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

        // Also start HealthKit as backup
        try await healthKitManager.startHeartRateMonitoring()

        Log.health.info("HRDataService started")
    }

    func stop() {
        dataTimeoutTask?.cancel()
        stopZoneTracking()
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
        timeInZone = 0
        recentHRValues.removeAll()
    }

    // MARK: - Simulation Mode

    /// Enable simulation mode for testing without real HR devices
    func enableSimulation(targetHR: Int = 150) {
        isSimulationMode = true
        simulatedTargetHR = targetHR
        currentSource = .simulated
        isReceivingData = true

        simulationTask?.cancel()
        simulationTask = Task { @MainActor in
            Log.health.info("HR Simulation started with target: \(targetHR) BPM")

            var currentSimulatedHR = 80  // Start from resting HR

            while !Task.isCancelled && isSimulationMode {
                // Simulate gradual HR changes toward target with some variance
                let diff = simulatedTargetHR - currentSimulatedHR
                let change: Int
                if abs(diff) > 10 {
                    change = diff > 0 ? Int.random(in: 2...5) : Int.random(in: -5 ... -2)
                } else {
                    change = Int.random(in: -3...3)
                }
                currentSimulatedHR = max(60, min(200, currentSimulatedHR + change))

                // Process the simulated HR
                processSimulatedHeartRate(currentSimulatedHR)

                // Update every 1 second
                try? await Task.sleep(for: .seconds(1))
            }

            Log.health.info("HR Simulation stopped")
        }
    }

    /// Update the target HR for simulation (e.g., when phase changes)
    func updateSimulatedTarget(_ targetHR: Int) {
        simulatedTargetHR = targetHR
        Log.health.debug("Simulation target updated to: \(targetHR) BPM")
    }

    /// Disable simulation mode
    func disableSimulation() {
        isSimulationMode = false
        simulationTask?.cancel()
        simulationTask = nil
    }

    private func processSimulatedHeartRate(_ bpm: Int) {
        currentHeartRate = bpm
        isReceivingData = true

        // Update zone status if tracking
        if let zone = targetZone {
            currentZoneStatus = zone.status(for: bpm)
        }

        // Publish sample
        let sample = HRSample(
            timestamp: Date(),
            bpm: bpm,
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
