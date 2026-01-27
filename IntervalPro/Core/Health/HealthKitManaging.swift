import Foundation
import Combine
import HealthKit

/// Protocol for HealthKit management
/// Per CLAUDE.md: All managers must have protocol abstraction for DI
protocol HealthKitManaging: AnyObject {
    // MARK: - Authorization
    var isAuthorized: Bool { get }
    func requestAuthorization() async throws

    // MARK: - Heart Rate
    var heartRatePublisher: AnyPublisher<Int, Never> { get }
    func startHeartRateMonitoring() async throws
    func stopHeartRateMonitoring()

    // MARK: - Workout
    func startWorkout(activityType: HKWorkoutActivityType) async throws
    func pauseWorkout() async throws
    func resumeWorkout() async throws
    func endWorkout() async throws -> HKWorkout?

    // MARK: - Queries
    func fetchHeartRateSamples(from: Date, to: Date) async throws -> [HRSample]
    func fetchRecentWorkouts(limit: Int) async throws -> [HKWorkout]
}

// MARK: - Authorization Status
enum HealthKitAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case partiallyAuthorized

    var displayText: String {
        switch self {
        case .notDetermined:
            return "No configurado"
        case .authorized:
            return "Autorizado"
        case .denied:
            return "Denegado"
        case .partiallyAuthorized:
            return "Parcialmente autorizado"
        }
    }
}

// MARK: - Errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case authorizationFailed
    case queryFailed
    case workoutNotStarted
    case workoutAlreadyStarted

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit no está disponible en este dispositivo."
        case .authorizationDenied:
            return "Acceso a HealthKit denegado. Actívalo en Ajustes > Salud."
        case .authorizationFailed:
            return "Error al solicitar permisos de HealthKit."
        case .queryFailed:
            return "Error al consultar datos de salud."
        case .workoutNotStarted:
            return "No hay entrenamiento activo."
        case .workoutAlreadyStarted:
            return "Ya hay un entrenamiento en curso."
        }
    }
}

// MARK: - Mock for Testing and Previews
@MainActor
final class MockHealthKitManager: HealthKitManaging {
    // MARK: - State
    var isAuthorized: Bool = false
    private var isMonitoring = false
    private var isWorkoutActive = false

    // MARK: - Subjects
    private let heartRateSubject = CurrentValueSubject<Int, Never>(0)
    private var heartRateTimer: Timer?

    // MARK: - Publishers
    var heartRatePublisher: AnyPublisher<Int, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    // MARK: - Mock Control
    func simulateHeartRate(_ bpm: Int) {
        heartRateSubject.send(bpm)
    }

    // MARK: - Authorization
    func requestAuthorization() async throws {
        try await Task.sleep(for: .milliseconds(500))
        isAuthorized = true
    }

    // MARK: - Heart Rate Monitoring
    func startHeartRateMonitoring() async throws {
        guard isAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        isMonitoring = true

        // Simulate heart rate updates for testing
        Task { @MainActor in
            while isMonitoring {
                let simulatedHR = Int.random(in: 120...180)
                heartRateSubject.send(simulatedHR)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopHeartRateMonitoring() {
        isMonitoring = false
    }

    // MARK: - Workout
    func startWorkout(activityType: HKWorkoutActivityType) async throws {
        guard !isWorkoutActive else {
            throw HealthKitError.workoutAlreadyStarted
        }
        isWorkoutActive = true
    }

    func pauseWorkout() async throws {
        guard isWorkoutActive else {
            throw HealthKitError.workoutNotStarted
        }
    }

    func resumeWorkout() async throws {
        guard isWorkoutActive else {
            throw HealthKitError.workoutNotStarted
        }
    }

    func endWorkout() async throws -> HKWorkout? {
        guard isWorkoutActive else {
            throw HealthKitError.workoutNotStarted
        }
        isWorkoutActive = false
        return nil  // Mock returns nil
    }

    // MARK: - Queries
    func fetchHeartRateSamples(from: Date, to: Date) async throws -> [HRSample] {
        // Return mock samples
        return [
            HRSample(timestamp: from, bpm: 145, source: .healthKit),
            HRSample(timestamp: from.addingTimeInterval(60), bpm: 155, source: .healthKit),
            HRSample(timestamp: from.addingTimeInterval(120), bpm: 165, source: .healthKit)
        ]
    }

    func fetchRecentWorkouts(limit: Int) async throws -> [HKWorkout] {
        return []  // Mock returns empty
    }
}
