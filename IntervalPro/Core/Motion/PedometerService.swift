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
            distance = dist.doubleValue
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

    // MARK: - Permissions
    static func requestPermission() async -> Bool {
        // CMPedometer doesn't require explicit permission request
        // It will prompt automatically when started
        // Check if step counting is available
        return CMPedometer.isStepCountingAvailable()
    }
}
