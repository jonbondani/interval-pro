import XCTest
@testable import IntervalPro

/// Tests for HeartRateZone
/// Per CLAUDE.md: TDD with XCTest, min 80% coverage
final class HeartRateZoneTests: XCTestCase {

    // MARK: - Zone Creation
    func test_init_createsZoneWithCorrectValues() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertEqual(zone.targetBPM, 170)
        XCTAssertEqual(zone.toleranceBPM, 5)
        XCTAssertEqual(zone.minBPM, 165)
        XCTAssertEqual(zone.maxBPM, 175)
    }

    func test_init_defaultTolerance_isFive() {
        let zone = HeartRateZone(targetBPM: 160)

        XCTAssertEqual(zone.toleranceBPM, 5)
    }

    func test_range_returnsCorrectClosedRange() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 10)

        XCTAssertEqual(zone.range, 160...180)
    }

    // MARK: - Contains
    func test_contains_returnsTrueForValueInZone() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertTrue(zone.contains(170))
        XCTAssertTrue(zone.contains(165))
        XCTAssertTrue(zone.contains(175))
        XCTAssertTrue(zone.contains(168))
    }

    func test_contains_returnsFalseForValueOutsideZone() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertFalse(zone.contains(164))
        XCTAssertFalse(zone.contains(176))
        XCTAssertFalse(zone.contains(100))
        XCTAssertFalse(zone.contains(200))
    }

    // MARK: - Below/Above Zone
    func test_isBelow_returnsTrueWhenBelowMin() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertTrue(zone.isBelow(164))
        XCTAssertTrue(zone.isBelow(100))
        XCTAssertFalse(zone.isBelow(165))
        XCTAssertFalse(zone.isBelow(170))
    }

    func test_isAbove_returnsTrueWhenAboveMax() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertTrue(zone.isAbove(176))
        XCTAssertTrue(zone.isAbove(200))
        XCTAssertFalse(zone.isAbove(175))
        XCTAssertFalse(zone.isAbove(170))
    }

    // MARK: - Deviation
    func test_deviation_returnsCorrectValue() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertEqual(zone.deviation(from: 170), 0)
        XCTAssertEqual(zone.deviation(from: 180), 10)
        XCTAssertEqual(zone.deviation(from: 160), -10)
    }

    // MARK: - Zone Status
    func test_status_returnsInZone_whenValueInRange() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        let status = zone.status(for: 172)

        XCTAssertEqual(status, .inZone)
        XCTAssertTrue(status.isInZone)
    }

    func test_status_returnsBelowZone_whenValueBelow() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        let status = zone.status(for: 160)

        if case .belowZone(let diff) = status {
            XCTAssertEqual(diff, 5)  // 165 - 160 = 5
        } else {
            XCTFail("Expected belowZone status")
        }
        XCTAssertFalse(status.isInZone)
    }

    func test_status_returnsAboveZone_whenValueAbove() {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        let status = zone.status(for: 180)

        if case .aboveZone(let diff) = status {
            XCTAssertEqual(diff, 5)  // 180 - 175 = 5
        } else {
            XCTFail("Expected aboveZone status")
        }
        XCTAssertFalse(status.isInZone)
    }

    // MARK: - Presets
    func test_presets_haveCorrectValues() {
        XCTAssertEqual(HeartRateZone.work160.targetBPM, 160)
        XCTAssertEqual(HeartRateZone.work170.targetBPM, 170)
        XCTAssertEqual(HeartRateZone.work180.targetBPM, 180)
        XCTAssertEqual(HeartRateZone.rest150.targetBPM, 150)
    }

    // MARK: - Equatable
    func test_equatable_zonesAreEqualWithSameValues() {
        let zone1 = HeartRateZone(targetBPM: 170, toleranceBPM: 5)
        let zone2 = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        XCTAssertEqual(zone1, zone2)
    }

    func test_equatable_zonesAreDifferentWithDifferentValues() {
        let zone1 = HeartRateZone(targetBPM: 170, toleranceBPM: 5)
        let zone2 = HeartRateZone(targetBPM: 170, toleranceBPM: 10)

        XCTAssertNotEqual(zone1, zone2)
    }

    // MARK: - Codable
    func test_codable_encodesAndDecodesCorrectly() throws {
        let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)

        let data = try JSONEncoder().encode(zone)
        let decoded = try JSONDecoder().decode(HeartRateZone.self, from: data)

        XCTAssertEqual(zone, decoded)
    }
}
