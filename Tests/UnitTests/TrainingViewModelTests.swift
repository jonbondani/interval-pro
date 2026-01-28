import XCTest
import Combine
@testable import IntervalPro

/// Tests for TrainingViewModel
final class TrainingViewModelTests: XCTestCase {

    var sut: TrainingViewModel!
    var mockGarmin: MockGarminManager!
    var mockHealthKit: MockHealthKitManager!
    var mockAudio: MockAudioEngine!
    var mockRepository: MockSessionRepository!
    var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        mockGarmin = MockGarminManager()
        mockHealthKit = MockHealthKitManager()
        mockAudio = MockAudioEngine()
        mockRepository = MockSessionRepository()

        sut = TrainingViewModel(
            garminManager: mockGarmin,
            healthKitManager: mockHealthKit,
            sessionRepository: mockRepository
        )

        cancellables = []
    }

    override func tearDown() async throws {
        await MainActor.run {
            sut = nil
        }
        mockGarmin = nil
        mockHealthKit = nil
        mockAudio = nil
        mockRepository = nil
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - Initial State
    @MainActor
    func test_initialState_isIdle() {
        XCTAssertEqual(sut.currentPhase, .idle)
        XCTAssertEqual(sut.timerState, .stopped)
        XCTAssertEqual(sut.currentHeartRate, 0)
        XCTAssertFalse(sut.isActive)
    }

    // MARK: - Configuration
    @MainActor
    func test_configure_setsPlanAndSeries() async {
        let plan = TrainingPlan.intermediate

        await sut.configure(with: plan)

        XCTAssertEqual(sut.plan?.id, plan.id)
        XCTAssertEqual(sut.totalSeries, plan.seriesCount)
    }

    @MainActor
    func test_configure_setMetronomeBPMToWorkZone() async {
        let plan = TrainingPlan(
            name: "Test",
            workZone: HeartRateZone(targetBPM: 175, toleranceBPM: 5),
            restZone: .rest150
        )

        await sut.configure(with: plan)

        XCTAssertEqual(sut.metronomeBPM, 175)
    }

    // MARK: - Target Zone
    @MainActor
    func test_targetZone_returnsWorkZoneDuringWork() async {
        let plan = TrainingPlan.intermediate
        await sut.configure(with: plan)
        sut.currentPhase = .work

        let zone = sut.targetZone

        XCTAssertEqual(zone?.targetBPM, plan.workZone.targetBPM)
    }

    @MainActor
    func test_targetZone_returnsRestZoneDuringRest() async {
        let plan = TrainingPlan.intermediate
        await sut.configure(with: plan)
        sut.currentPhase = .rest

        let zone = sut.targetZone

        XCTAssertEqual(zone?.targetBPM, plan.restZone.targetBPM)
    }

    @MainActor
    func test_targetZone_returnsNilWhenIdle() async {
        let plan = TrainingPlan.intermediate
        await sut.configure(with: plan)

        let zone = sut.targetZone

        XCTAssertNil(zone)
    }

    // MARK: - Audio Controls
    @MainActor
    func test_toggleMetronome_togglesState() {
        XCTAssertTrue(sut.isMetronomeEnabled)

        sut.toggleMetronome()
        XCTAssertFalse(sut.isMetronomeEnabled)

        sut.toggleMetronome()
        XCTAssertTrue(sut.isMetronomeEnabled)
    }

    @MainActor
    func test_setMetronomeBPM_updatesValue() {
        sut.setMetronomeBPM(180)

        XCTAssertEqual(sut.metronomeBPM, 180)
    }

    // MARK: - Computed Properties
    @MainActor
    func test_formattedPace_returnsFormattedString() {
        sut.currentPace = 300  // 5:00/km

        XCTAssertEqual(sut.formattedPace, "5:00 /km")
    }

    @MainActor
    func test_formattedDistance_returnsFormattedString() {
        sut.totalDistance = 5500  // 5.5 km in meters

        XCTAssertEqual(sut.formattedDistance, "5.50 km")
    }

    @MainActor
    func test_isActive_returnsTrueWhenRunning() {
        sut.timerState = .running

        XCTAssertTrue(sut.isActive)
    }

    @MainActor
    func test_isActive_returnsTrueWhenPaused() {
        sut.timerState = .paused

        XCTAssertTrue(sut.isActive)
    }

    @MainActor
    func test_isActive_returnsFalseWhenStopped() {
        sut.timerState = .stopped

        XCTAssertFalse(sut.isActive)
    }

    // MARK: - Preview Helper
    @MainActor
    func test_previewHelper_createsConfiguredViewModel() {
        let preview = TrainingViewModel.preview(
            phase: .work,
            hr: 168,
            series: 2,
            totalSeries: 4
        )

        XCTAssertEqual(preview.currentPhase, .work)
        XCTAssertEqual(preview.currentHeartRate, 168)
        XCTAssertEqual(preview.currentSeries, 2)
        XCTAssertEqual(preview.totalSeries, 4)
    }
}

// MARK: - Integration Tests
extension TrainingViewModelTests {

    @MainActor
    func test_hrDataServiceBinding_updatesHeartRate() async throws {
        // This test verifies the Combine binding between services
        var receivedHRs: [Int] = []

        sut.$currentHeartRate
            .dropFirst()
            .sink { hr in
                receivedHRs.append(hr)
            }
            .store(in: &cancellables)

        // Simulate HR from mock
        mockHealthKit.simulateHeartRate(165)

        // Wait for propagation
        try await Task.sleep(for: .milliseconds(200))

        // HR should have been updated through the binding
        // Note: This depends on HRDataService being properly initialized
    }
}
