import Foundation
import SwiftUI

/// Heart rate zone configuration
/// Per CLAUDE.md: NEVER hardcode BPM values, always use this struct
struct HeartRateZone: Codable, Equatable, Hashable {
    let targetBPM: Int
    let toleranceBPM: Int

    // MARK: - Computed Properties
    var minBPM: Int { targetBPM - toleranceBPM }
    var maxBPM: Int { targetBPM + toleranceBPM }

    var range: ClosedRange<Int> {
        minBPM...maxBPM
    }

    // MARK: - Init
    init(targetBPM: Int, toleranceBPM: Int = 5) {
        self.targetBPM = targetBPM
        self.toleranceBPM = toleranceBPM
    }

    // MARK: - Zone Checking
    /// Check if a heart rate value is within this zone
    func contains(_ bpm: Int) -> Bool {
        range.contains(bpm)
    }

    /// Check if heart rate is below the zone
    func isBelow(_ bpm: Int) -> Bool {
        bpm < minBPM
    }

    /// Check if heart rate is above the zone
    func isAbove(_ bpm: Int) -> Bool {
        bpm > maxBPM
    }

    /// Get the deviation from target (positive = above, negative = below)
    func deviation(from bpm: Int) -> Int {
        bpm - targetBPM
    }

    /// Get the zone status for a given heart rate
    func status(for bpm: Int) -> ZoneStatus {
        if contains(bpm) {
            return .inZone
        } else if isBelow(bpm) {
            return .belowZone(by: minBPM - bpm)
        } else {
            return .aboveZone(by: bpm - maxBPM)
        }
    }
}

// MARK: - Zone Status
enum ZoneStatus: Equatable {
    case inZone
    case belowZone(by: Int)
    case aboveZone(by: Int)

    var isInZone: Bool {
        if case .inZone = self { return true }
        return false
    }

    var color: Color {
        switch self {
        case .inZone:
            return .green
        case .belowZone:
            return .blue
        case .aboveZone:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .inZone:
            return "checkmark.circle.fill"
        case .belowZone:
            return "arrow.up.circle.fill"
        case .aboveZone:
            return "arrow.down.circle.fill"
        }
    }

    var instruction: String {
        switch self {
        case .inZone:
            return "En zona"
        case .belowZone(let diff):
            return "Sube intensidad (+\(diff) bpm)"
        case .aboveZone(let diff):
            return "Baja intensidad (-\(diff) bpm)"
        }
    }
}

// MARK: - Preset Zones
extension HeartRateZone {
    /// Common preset zones based on PRD specifications
    static let work160 = HeartRateZone(targetBPM: 160, toleranceBPM: 5)
    static let work170 = HeartRateZone(targetBPM: 170, toleranceBPM: 5)
    static let work180 = HeartRateZone(targetBPM: 180, toleranceBPM: 5)
    static let rest150 = HeartRateZone(targetBPM: 150, toleranceBPM: 10)

    static let workPresets: [HeartRateZone] = [work160, work170, work180]
}
