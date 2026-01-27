import XCTest
@testable import IntervalPro

/// Tests for TrainingPlan
final class TrainingPlanTests: XCTestCase {

    // MARK: - Initialization
    func test_init_createsWithDefaultValues() {
        let plan = TrainingPlan(
            name: "Test Plan",
            workZone: .work170,
            restZone: .rest150
        )

        XCTAssertEqual(plan.name, "Test Plan")
        XCTAssertEqual(plan.workDuration, 180)  // 3 min default
        XCTAssertEqual(plan.restDuration, 180)  // 3 min default
        XCTAssertEqual(plan.seriesCount, 4)
        XCTAssertEqual(plan.warmupDuration, 300)  // 5 min
        XCTAssertEqual(plan.cooldownDuration, 300)  // 5 min
        XCTAssertFalse(plan.isDefault)
    }

    func test_init_createsWithCustomValues() {
        let plan = TrainingPlan(
            name: "Custom",
            workZone: HeartRateZone(targetBPM: 180, toleranceBPM: 3),
            restZone: HeartRateZone(targetBPM: 140, toleranceBPM: 8),
            workDuration: 120,
            restDuration: 90,
            seriesCount: 6,
            warmupDuration: nil,
            cooldownDuration: nil
        )

        XCTAssertEqual(plan.workDuration, 120)
        XCTAssertEqual(plan.restDuration, 90)
        XCTAssertEqual(plan.seriesCount, 6)
        XCTAssertNil(plan.warmupDuration)
        XCTAssertNil(plan.cooldownDuration)
    }

    // MARK: - Total Duration
    func test_totalDuration_calculatesCorrectlyWithWarmupAndCooldown() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 180,  // 3 min
            restDuration: 180,  // 3 min
            seriesCount: 4,
            warmupDuration: 300,  // 5 min
            cooldownDuration: 300  // 5 min
        )

        // 5 + (4 * (3 + 3)) + 5 = 5 + 24 + 5 = 34 min = 2040 sec
        XCTAssertEqual(plan.totalDuration, 2040)
    }

    func test_totalDuration_calculatesCorrectlyWithoutWarmupAndCooldown() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            workDuration: 180,
            restDuration: 180,
            seriesCount: 4,
            warmupDuration: nil,
            cooldownDuration: nil
        )

        // 4 * (3 + 3) = 24 min = 1440 sec
        XCTAssertEqual(plan.totalDuration, 1440)
    }

    func test_totalDurationFormatted_returnsCorrectString() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            seriesCount: 4
        )

        XCTAssertEqual(plan.totalDurationFormatted, "34 min")
    }

    // MARK: - Estimated Calories
    func test_estimatedCalories_returnsReasonableValue() {
        let plan = TrainingPlan(
            name: "Test",
            workZone: .work170,
            restZone: .rest150,
            seriesCount: 4
        )

        // Should be reasonable for a 34 min workout
        XCTAssertGreaterThan(plan.estimatedCalories, 200)
        XCTAssertLessThan(plan.estimatedCalories, 600)
    }

    // MARK: - Default Templates
    func test_defaultTemplates_hasThreeTemplates() {
        XCTAssertEqual(TrainingPlan.defaultTemplates.count, 3)
    }

    func test_beginnerTemplate_hasLowerIntensity() {
        let beginner = TrainingPlan.beginner

        XCTAssertEqual(beginner.workZone.targetBPM, 160)
        XCTAssertEqual(beginner.seriesCount, 3)
        XCTAssertTrue(beginner.isDefault)
    }

    func test_intermediateTemplate_hasStandardIntensity() {
        let intermediate = TrainingPlan.intermediate

        XCTAssertEqual(intermediate.workZone.targetBPM, 170)
        XCTAssertEqual(intermediate.seriesCount, 4)
        XCTAssertTrue(intermediate.isDefault)
    }

    func test_advancedTemplate_hasHighIntensity() {
        let advanced = TrainingPlan.advanced

        XCTAssertEqual(advanced.workZone.targetBPM, 180)
        XCTAssertEqual(advanced.seriesCount, 6)
        XCTAssertTrue(advanced.isDefault)
    }

    // MARK: - Equatable
    func test_equatable_plansWithSameIdAreEqual() {
        let id = UUID()
        let plan1 = TrainingPlan(id: id, name: "A", workZone: .work170, restZone: .rest150)
        let plan2 = TrainingPlan(id: id, name: "A", workZone: .work170, restZone: .rest150)

        XCTAssertEqual(plan1, plan2)
    }

    // MARK: - Codable
    func test_codable_encodesAndDecodesCorrectly() throws {
        let plan = TrainingPlan(
            name: "Codable Test",
            workZone: .work170,
            restZone: .rest150,
            seriesCount: 5
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TrainingPlan.self, from: data)

        XCTAssertEqual(plan.id, decoded.id)
        XCTAssertEqual(plan.name, decoded.name)
        XCTAssertEqual(plan.seriesCount, decoded.seriesCount)
    }
}
