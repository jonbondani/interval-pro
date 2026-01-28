import XCTest
import Combine
@testable import IntervalPro

/// Tests for IntervalTimer
final class IntervalTimerTests: XCTestCase {

    var sut: IntervalTimer!
    var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        sut = IntervalTimer()
        cancellables = []
    }

    override func tearDown() async throws {
        await MainActor.run {
            sut?.stop()
            sut = nil
        }
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - Initial State
    @MainActor
    func test_initialState_isIdleAndStopped() {
        XCTAssertEqual(sut.currentPhase, .idle)
        XCTAssertEqual(sut.timerState, .stopped)
        XCTAssertEqual(sut.currentSeries, 0)
        XCTAssertEqual(sut.totalElapsedTime, 0)
    }

    // MARK: - Configuration
    @MainActor
    func test_configure_setsCorrectValues() {
        let plan = TrainingPlan.intermediate

        sut.configure(with: plan)

        XCTAssertEqual(sut.totalSeries, plan.seriesCount)
        XCTAssertEqual(sut.currentSeries, 0)
        XCTAssertEqual(sut.currentPhase, .idle)
    }

    // MARK: - Start
    @MainActor
    func test_start_withoutPlan_doesNotStart() {
        sut.start()

        XCTAssertEqual(sut.timerState, .stopped)
        XCTAssertEqual(sut.currentPhase, .idle)
    }

    @MainActor
    func test_start_withWarmup_startsInWarmupPhase() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            warmupDuration: 60
        )

        sut.configure(with: plan)
        sut.start()

        XCTAssertEqual(sut.timerState, .running)
        XCTAssertEqual(sut.currentPhase, .warmup)
    }

    @MainActor
    func test_start_withoutWarmup_startsInWorkPhase() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            warmupDuration: nil
        )

        sut.configure(with: plan)
        sut.start()

        XCTAssertEqual(sut.timerState, .running)
        XCTAssertEqual(sut.currentPhase, .work)
        XCTAssertEqual(sut.currentSeries, 1)
    }

    // MARK: - Pause/Resume
    @MainActor
    func test_pause_changesStateToPaused() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)
        sut.start()

        sut.pause()

        XCTAssertEqual(sut.timerState, .paused)
    }

    @MainActor
    func test_resume_changesStateToRunning() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)
        sut.start()
        sut.pause()

        sut.resume()

        XCTAssertEqual(sut.timerState, .running)
    }

    @MainActor
    func test_pause_whenStopped_doesNothing() {
        sut.pause()

        XCTAssertEqual(sut.timerState, .stopped)
    }

    // MARK: - Stop
    @MainActor
    func test_stop_changesStateToStopped() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)
        sut.start()

        sut.stop()

        XCTAssertEqual(sut.timerState, .stopped)
    }

    // MARK: - Reset
    @MainActor
    func test_reset_clearsAllState() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)
        sut.start()

        sut.reset()

        XCTAssertEqual(sut.currentPhase, .idle)
        XCTAssertEqual(sut.timerState, .stopped)
        XCTAssertEqual(sut.currentSeries, 0)
        XCTAssertEqual(sut.totalElapsedTime, 0)
        XCTAssertEqual(sut.phaseElapsedTime, 0)
    }

    // MARK: - Phase Transitions
    @MainActor
    func test_phaseChangeCallback_isCalled() async throws {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 0.1,  // Very short for testing
            warmupDuration: nil
        )

        var phaseChanges: [(IntervalPhase, IntervalPhase)] = []
        sut.onPhaseChange = { old, new in
            phaseChanges.append((old, new))
        }

        sut.configure(with: plan)
        sut.start()

        // Wait for work phase to complete
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(phaseChanges.isEmpty)
        XCTAssertEqual(phaseChanges.first?.0, .idle)
        XCTAssertEqual(phaseChanges.first?.1, .work)
    }

    // MARK: - Series Complete Callback
    @MainActor
    func test_seriesCompleteCallback_isCalled() async throws {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 0.05,
            restDuration: 0.05,
            seriesCount: 2,
            warmupDuration: nil,
            cooldownDuration: nil
        )

        var completedSeries: [Int] = []
        sut.onSeriesComplete = { series in
            completedSeries.append(series)
        }

        sut.configure(with: plan)
        sut.start()

        // Wait for all series to complete
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(completedSeries, [1, 2])
    }

    // MARK: - Time Warnings
    @MainActor
    func test_timeWarningCallback_isCalledAtThresholds() async throws {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 3,  // 3 seconds to trigger warnings
            warmupDuration: nil
        )

        var warnings: [Int] = []
        sut.onTimeWarning = { seconds in
            warnings.append(seconds)
        }

        sut.configure(with: plan)
        sut.start()

        // Wait for warnings
        try await Task.sleep(for: .seconds(3.5))

        // Should have received warnings at 3, 2, 1
        XCTAssertTrue(warnings.contains(3))
        XCTAssertTrue(warnings.contains(2))
        XCTAssertTrue(warnings.contains(1))
    }

    // MARK: - Skip Functions
    @MainActor
    func test_skipToNextPhase_transitionsImmediately() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 180,
            warmupDuration: nil
        )

        sut.configure(with: plan)
        sut.start()
        XCTAssertEqual(sut.currentPhase, .work)

        sut.skipToNextPhase()

        XCTAssertEqual(sut.currentPhase, .rest)
    }

    // MARK: - Progress Calculation
    @MainActor
    func test_progress_calculatesCorrectly() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 100,
            warmupDuration: nil
        )

        sut.configure(with: plan)
        XCTAssertEqual(sut.progress, 0)

        // Progress is based on phaseElapsedTime / phaseDuration
        // Since timer hasn't started, progress should be 0
    }

    // MARK: - Computed Properties
    @MainActor
    func test_isRunning_returnsCorrectValue() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)

        XCTAssertFalse(sut.isRunning)

        sut.start()
        XCTAssertTrue(sut.isRunning)

        sut.pause()
        XCTAssertFalse(sut.isRunning)
    }

    @MainActor
    func test_isPaused_returnsCorrectValue() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)

        XCTAssertFalse(sut.isPaused)

        sut.start()
        XCTAssertFalse(sut.isPaused)

        sut.pause()
        XCTAssertTrue(sut.isPaused)
    }

    // MARK: - State Snapshot
    @MainActor
    func test_stateSnapshot_capturesCurrentState() {
        let plan = TrainingPlan.intermediate
        sut.configure(with: plan)
        sut.start()

        let snapshot = sut.stateSnapshot

        XCTAssertEqual(snapshot.phase, sut.currentPhase)
        XCTAssertEqual(snapshot.timerState, sut.timerState)
        XCTAssertEqual(snapshot.currentSeries, sut.currentSeries)
        XCTAssertEqual(snapshot.totalSeries, sut.totalSeries)
    }
}
