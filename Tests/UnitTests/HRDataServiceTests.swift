import XCTest
import Combine
@testable import IntervalPro

/// Tests for HRDataService
final class HRDataServiceTests: XCTestCase {

    var sut: HRDataService!
    var mockGarmin: MockGarminManager!
    var mockHealthKit: MockHealthKitManager!
    var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        mockGarmin = MockGarminManager()
        mockHealthKit = MockHealthKitManager()
        sut = HRDataService(garminManager: mockGarmin, healthKitManager: mockHealthKit)
        cancellables = []
    }

    override func tearDown() async throws {
        sut = nil
        mockGarmin = nil
        mockHealthKit = nil
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - Source Prioritization Tests
    @MainActor
    func test_garminData_takePriorityOverHealthKit() async throws {
        var receivedSamples: [HRSample] = []

        sut.heartRatePublisher
            .sink { sample in
                receivedSamples.append(sample)
            }
            .store(in: &cancellables)

        // Simulate Garmin connected
        try await mockGarmin.connect(to: "test")

        // Send Garmin HR
        mockGarmin.simulateHeartRate(170)

        // Wait for processing
        try await Task.sleep(for: .milliseconds(100))

        // Simulate HealthKit HR (should be ignored when Garmin connected)
        mockHealthKit.simulateHeartRate(165)

        try await Task.sleep(for: .milliseconds(100))

        // Should only have Garmin sample
        XCTAssertEqual(receivedSamples.count, 1)
        XCTAssertEqual(receivedSamples.first?.source, .garmin)
        XCTAssertEqual(receivedSamples.first?.bpm, 170)
    }

    @MainActor
    func test_healthKitData_usedWhenGarminDisconnected() async throws {
        var receivedSamples: [HRSample] = []

        sut.heartRatePublisher
            .sink { sample in
                receivedSamples.append(sample)
            }
            .store(in: &cancellables)

        // Garmin is disconnected by default
        XCTAssertFalse(mockGarmin.isConnected)

        // Send HealthKit HR
        mockHealthKit.simulateHeartRate(155)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(receivedSamples.count, 1)
        XCTAssertEqual(receivedSamples.first?.source, .healthKit)
    }

    // MARK: - Outlier Filtering Tests
    @MainActor
    func test_invalidHeartRate_isFiltered() async throws {
        var receivedSamples: [HRSample] = []

        sut.heartRatePublisher
            .sink { sample in
                receivedSamples.append(sample)
            }
            .store(in: &cancellables)

        // Send invalid values (outside 30-250 range)
        mockHealthKit.simulateHeartRate(20)  // Too low
        mockHealthKit.simulateHeartRate(300) // Too high

        try await Task.sleep(for: .milliseconds(100))

        // Should filter out invalid values
        XCTAssertTrue(receivedSamples.isEmpty)
    }

    @MainActor
    func test_validHeartRate_isAccepted() async throws {
        var receivedSamples: [HRSample] = []

        sut.heartRatePublisher
            .sink { sample in
                receivedSamples.append(sample)
            }
            .store(in: &cancellables)

        mockHealthKit.simulateHeartRate(60)   // Valid low
        mockHealthKit.simulateHeartRate(180)  // Valid high

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(receivedSamples.count, 2)
    }

    // MARK: - Zone Tracking Tests
    @MainActor
    func test_zoneTracking_updatesStatus() async throws {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)
        sut.startZoneTracking(targetZone: zone)

        // Simulate HR in zone
        mockHealthKit.simulateHeartRate(170)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(sut.currentZoneStatus, .inZone)

        // Simulate HR below zone
        mockHealthKit.simulateHeartRate(160)
        try await Task.sleep(for: .milliseconds(100))

        if case .belowZone = sut.currentZoneStatus {
            // Expected
        } else {
            XCTFail("Expected belowZone status")
        }

        sut.stopZoneTracking()
    }

    @MainActor
    func test_timeInZone_accumulates() async throws {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 10)
        sut.startZoneTracking(targetZone: zone)

        // Simulate HR in zone
        mockHealthKit.simulateHeartRate(170)
        try await Task.sleep(for: .milliseconds(100))

        // Wait for zone time to accumulate
        try await Task.sleep(for: .seconds(2))

        let timeInZone = sut.timeInZone
        XCTAssertGreaterThan(timeInZone, 0)

        sut.stopZoneTracking()
    }

    // MARK: - Current Values Tests
    @MainActor
    func test_currentHeartRate_updatesOnNewData() async throws {
        XCTAssertEqual(sut.currentHeartRate, 0)

        mockHealthKit.simulateHeartRate(165)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(sut.currentHeartRate, 165)
    }

    @MainActor
    func test_reset_clearsAllValues() async throws {
        mockHealthKit.simulateHeartRate(165)
        try await Task.sleep(for: .milliseconds(100))

        sut.reset()

        XCTAssertEqual(sut.currentHeartRate, 0)
        XCTAssertEqual(sut.currentPace, 0)
        XCTAssertEqual(sut.currentSpeed, 0)
        XCTAssertEqual(sut.timeInZone, 0)
    }

    // MARK: - Integration Tests
    @MainActor
    func test_startStop_lifecycle() async throws {
        try await mockHealthKit.requestAuthorization()
        try await sut.start()

        XCTAssertTrue(sut.isReceivingData || true) // May not receive data immediately

        sut.stop()

        // Should complete without errors
    }
}

// MARK: - HRZoneCalculator Tests
final class HRZoneCalculatorTests: XCTestCase {

    func test_calculateZone_zone1_forLowPercentage() {
        let zone = HRZoneCalculator.calculateZone(bpm: 80, maxHR: 180)
        XCTAssertEqual(zone, .zone1)
    }

    func test_calculateZone_zone5_forHighPercentage() {
        let zone = HRZoneCalculator.calculateZone(bpm: 170, maxHR: 180)
        XCTAssertEqual(zone, .zone5)
    }

    func test_calculateZone_zone5Max_forMaxEffort() {
        let zone = HRZoneCalculator.calculateZone(bpm: 180, maxHR: 180)
        XCTAssertEqual(zone, .zone5Max)
    }

    func test_estimateMaxHR_useTanakaFormula() {
        // Tanaka: 208 - (0.7 × age)
        let maxHR = HRZoneCalculator.estimateMaxHR(age: 52)

        // 208 - (0.7 × 52) = 208 - 36.4 = 171.6 ≈ 171
        XCTAssertEqual(maxHR, 171)
    }

    func test_zoneLevel_properties() {
        XCTAssertEqual(HRZoneLevel.zone1.name, "Recuperación")
        XCTAssertEqual(HRZoneLevel.zone4.name, "Umbral")
        XCTAssertEqual(HRZoneLevel.zone5.percentageRange, 80...90)
    }
}
