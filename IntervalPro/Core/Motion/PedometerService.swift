import Foundation
import CoreMotion
import Combine

/// Service for detecting cadence using iPhone's motion sensors
@MainActor
final class PedometerService: ObservableObject {
    // MARK: - Singleton
    static let shared = PedometerService()

    // MARK: - Published State
    @Published private(set) var currentCadence: Int = 0
    @Published private(set) var totalSteps: Int = 0
    @Published private(set) var distance: Double = 0  // meters
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isAvailable: Bool = false

    // MARK: - Publishers
    private let cadenceSubject = PassthroughSubject<Int, Never>()
    var cadencePublisher: AnyPublisher<Int, Never> {
        cadenceSubject.eraseToAnyPublisher()
    }

    private let distanceSubject = PassthroughSubject<Double, Never>()
    var distancePublisher: AnyPublisher<Double, Never> {
        distanceSubject.eraseToAnyPublisher()
    }

    private let paceSubject = PassthroughSubject<Double, Never>()
    var pacePublisher: AnyPublisher<Double, Never> {
        paceSubject.eraseToAnyPublisher()
    }

    // For pace calculation
    private var lastDistance: Double = 0
    private var lastDistanceTime: Date?

    // MARK: - Private
    private let pedometer = CMPedometer()
    private var startDate: Date?

    // MARK: - Init
    private init() {
        isAvailable = CMPedometer.isCadenceAvailable() && CMPedometer.isStepCountingAvailable()
        let available = isAvailable
        Log.health.info("PedometerService init - Cadence available: \(available)")
    }

    // MARK: - Control
    func start() {
        guard isAvailable else {
            Log.health.warning("Pedometer not available on this device")
            return
        }

        guard !isRunning else { return }

        startDate = Date()
        isRunning = true
        totalSteps = 0
        distance = 0
        currentCadence = 0
        lastDistance = 0
        lastDistanceTime = nil

        Log.health.info("Pedometer started")

        // Start live updates
        pedometer.startUpdates(from: startDate!) { [weak self] data, error in
            Task { @MainActor in
                self?.handlePedometerData(data, error: error)
            }
        }
    }

    func stop() {
        guard isRunning else { return }

        pedometer.stopUpdates()
        isRunning = false
        startDate = nil

        let steps = totalSteps
        Log.health.info("Pedometer stopped - Total steps: \(steps)")
    }

    // MARK: - Data Handling
    private func handlePedometerData(_ data: CMPedometerData?, error: Error?) {
        if let error = error {
            Log.health.error("Pedometer error: \(error.localizedDescription)")
            return
        }

        guard let data = data else { return }

        // Update steps
        totalSteps = data.numberOfSteps.intValue

        // Update distance if available
        if let dist = data.distance {
            let newDistance = dist.doubleValue
            distance = newDistance
            distanceSubject.send(newDistance)

            // Calculate pace (sec/km) based on distance change over time
            calculatePace(currentDistance: newDistance)
        }

        // Update cadence - CMPedometer provides currentCadence in steps/second
        if let cadence = data.currentCadence {
            // Convert from steps/second to steps/minute (SPM)
            let spm = Int(cadence.doubleValue * 60)

            // Validate range (walking: 80-120, jogging: 140-170, running: 170-200)
            if spm >= 60 && spm <= 220 {
                currentCadence = spm
                cadenceSubject.send(spm)
                let steps = totalSteps
                Log.health.debug("Cadence: \(spm) SPM, Steps: \(steps)")
            }
        }
    }

    /// Calculate pace in sec/km based on distance changes
    private func calculatePace(currentDistance: Double) {
        let now = Date()

        guard let lastTime = lastDistanceTime else {
            lastDistance = currentDistance
            lastDistanceTime = now
            return
        }

        let timeDelta = now.timeIntervalSince(lastTime)
        let distanceDelta = currentDistance - lastDistance

        // Need at least 5 seconds and 5 meters for meaningful pace
        guard timeDelta >= 5, distanceDelta >= 5 else { return }

        // Calculate pace: seconds per kilometer
        // pace = time / distance * 1000 (convert m to km)
        let paceSecPerKm = (timeDelta / distanceDelta) * 1000

        // Validate pace range (2:00/km to 15:00/km = 120 to 900 sec/km)
        if paceSecPerKm >= 120 && paceSecPerKm <= 900 {
            paceSubject.send(paceSecPerKm)
            Log.health.debug("Pace: \(Int(paceSecPerKm)) sec/km (\(paceSecPerKm.formattedPace))")
        }

        // Update last values
        lastDistance = currentDistance
        lastDistanceTime = now
    }

    // MARK: - Permissions
    static func requestPermission() async -> Bool {
        // CMPedometer doesn't require explicit permission request
        // It will prompt automatically when started
        // Check if step counting is available
        return CMPedometer.isStepCountingAvailable()
    }
}
