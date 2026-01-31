import Foundation
import SwiftUI

/// Cadence zone configuration (steps per minute / SPM)
/// IMPORTANT: targetBPM = cadencia objetivo (pasos por minuto), NO frecuencia cardíaca
/// La cadencia de carrera típica es 150-190 SPM
/// Per CLAUDE.md: NEVER hardcode values, always use this struct
struct HeartRateZone: Codable, Equatable, Hashable {
    /// Target cadence in steps per minute (SPM)
    /// Typical running cadence: 150-190 SPM
    let targetBPM: Int
    let toleranceBPM: Int

    // MARK: - Computed Properties
    var minBPM: Int { targetBPM - toleranceBPM }
    var maxBPM: Int { targetBPM + toleranceBPM }

    var range: ClosedRange<Int> {
        minBPM...maxBPM
    }

    /// Alias for clarity - target cadence in SPM
    var targetCadence: Int { targetBPM }
    var minCadence: Int { minBPM }
    var maxCadence: Int { maxBPM }

    // MARK: - Init
    init(targetBPM: Int, toleranceBPM: Int = 5) {
        self.targetBPM = targetBPM
        self.toleranceBPM = toleranceBPM
    }

    // MARK: - Zone Checking
    /// Check if a cadence value is within this zone
    func contains(_ cadence: Int) -> Bool {
        range.contains(cadence)
    }

    /// Check if cadence is below the zone
    func isBelow(_ cadence: Int) -> Bool {
        cadence < minBPM
    }

    /// Check if cadence is above the zone
    func isAbove(_ cadence: Int) -> Bool {
        cadence > maxBPM
    }

    /// Get the deviation from target (positive = above, negative = below)
    func deviation(from cadence: Int) -> Int {
        cadence - targetBPM
    }

    /// Get the zone status for a given cadence
    func status(for cadence: Int) -> ZoneStatus {
        if contains(cadence) {
            return .inZone
        } else if isBelow(cadence) {
            return .belowZone(by: minBPM - cadence)
        } else {
            return .aboveZone(by: cadence - maxBPM)
        }
    }
}

// MARK: - Zone Status
enum ZoneStatus: Equatable, CustomStringConvertible {
    case inZone
    case belowZone(by: Int)
    case aboveZone(by: Int)

    var isInZone: Bool {
        if case .inZone = self { return true }
        return false
    }

    var description: String {
        switch self {
        case .inZone:
            return "inZone"
        case .belowZone(let diff):
            return "belowZone(\(diff))"
        case .aboveZone(let diff):
            return "aboveZone(\(diff))"
        }
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
            return "Cadencia OK"
        case .belowZone(let diff):
            return "Más rápido (+\(diff) spm)"
        case .aboveZone(let diff):
            return "Más lento (-\(diff) spm)"
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
