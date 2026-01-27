import XCTest
import Combine
@testable import IntervalPro

/// Tests for HealthKitManager using MockHealthKitManager
final class HealthKitManagerTests: XCTestCase {

    var sut: MockHealthKitManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        sut = await MockHealthKitManager()
        cancellables = []
    }

    override func tearDown() async throws {
        sut = nil
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - Authorization Tests
    @MainActor
    func test_initialState_isNotAuthorized() {
        XCTAssertFalse(sut.isAuthorized)
    }

    @MainActor
    func test_requestAuthorization_setsAuthorizedTrue() async throws {
        try await sut.requestAuthorization()

        XCTAssertTrue(sut.isAuthorized)
    }

    // MARK: - Heart Rate Monitoring Tests
    @MainActor
    func test_startHeartRateMonitoring_requiresAuthorization() async {
        do {
            try await sut.startHeartRateMonitoring()
            XCTFail("Should throw when not authorized")
        } catch {
            XCTAssertTrue(error is HealthKitError)
        }
    }

    @MainActor
    func test_startHeartRateMonitoring_succeeds_whenAuthorized() async throws {
        try await sut.requestAuthorization()
        try await sut.startHeartRateMonitoring()

        // Should not throw
    }

    @MainActor
    func test_heartRatePublisher_emitsSimulatedValues() async throws {
        var receivedBPM: [Int] = []

        sut.heartRatePublisher
            .prefix(3)  // Take first 3 values
            .sink { bpm in
                receivedBPM.append(bpm)
            }
            .store(in: &cancellables)

        try await sut.requestAuthorization()

        sut.simulateHeartRate(160)
        sut.simulateHeartRate(165)
        sut.simulateHeartRate(170)

        XCTAssertEqual(receivedBPM, [160, 165, 170])
    }

    // MARK: - Workout Tests
    @MainActor
    func test_startWorkout_throwsWhenAlreadyStarted() async throws {
        try await sut.requestAuthorization()
        try await sut.startWorkout(activityType: .running)

        do {
            try await sut.startWorkout(activityType: .running)
            XCTFail("Should throw when workout already started")
        } catch {
            XCTAssertEqual(error as? HealthKitError, .workoutAlreadyStarted)
        }
    }

    @MainActor
    func test_endWorkout_throwsWhenNotStarted() async throws {
        do {
            _ = try await sut.endWorkout()
            XCTFail("Should throw when no workout started")
        } catch {
            XCTAssertEqual(error as? HealthKitError, .workoutNotStarted)
        }
    }

    @MainActor
    func test_pauseResumeWorkout_throwsWhenNotStarted() async throws {
        do {
            try await sut.pauseWorkout()
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? HealthKitError, .workoutNotStarted)
        }

        do {
            try await sut.resumeWorkout()
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? HealthKitError, .workoutNotStarted)
        }
    }

    @MainActor
    func test_workoutLifecycle_completesSuccessfully() async throws {
        try await sut.requestAuthorization()
        try await sut.startWorkout(activityType: .running)
        try await sut.pauseWorkout()
        try await sut.resumeWorkout()
        _ = try await sut.endWorkout()

        // Should complete without errors
    }

    // MARK: - Query Tests
    @MainActor
    func test_fetchHeartRateSamples_returnsMockData() async throws {
        let from = Date().addingTimeInterval(-3600)
        let to = Date()

        let samples = try await sut.fetchHeartRateSamples(from: from, to: to)

        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.allSatisfy { $0.source == .healthKit })
    }

    @MainActor
    func test_fetchRecentWorkouts_returnsEmptyArray() async throws {
        let workouts = try await sut.fetchRecentWorkouts(limit: 10)

        // Mock returns empty
        XCTAssertTrue(workouts.isEmpty)
    }
}

// MARK: - HealthKitError Tests
final class HealthKitErrorTests: XCTestCase {

    func test_errorDescription_returnsLocalizedMessage() {
        XCTAssertNotNil(HealthKitError.notAvailable.errorDescription)
        XCTAssertNotNil(HealthKitError.authorizationDenied.errorDescription)
        XCTAssertNotNil(HealthKitError.authorizationFailed.errorDescription)
        XCTAssertNotNil(HealthKitError.queryFailed.errorDescription)
        XCTAssertNotNil(HealthKitError.workoutNotStarted.errorDescription)
        XCTAssertNotNil(HealthKitError.workoutAlreadyStarted.errorDescription)
    }
}

// MARK: - HealthKitAuthorizationStatus Tests
final class HealthKitAuthorizationStatusTests: XCTestCase {

    func test_displayText_returnsLocalizedString() {
        XCTAssertEqual(HealthKitAuthorizationStatus.notDetermined.displayText, "No configurado")
        XCTAssertEqual(HealthKitAuthorizationStatus.authorized.displayText, "Autorizado")
        XCTAssertEqual(HealthKitAuthorizationStatus.denied.displayText, "Denegado")
        XCTAssertEqual(HealthKitAuthorizationStatus.partiallyAuthorized.displayText, "Parcialmente autorizado")
    }
}
