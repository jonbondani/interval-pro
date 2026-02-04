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

    /// Target pace in seconds per kilometer (optional)
    /// e.g., 330 = 5:30/km, 300 = 5:00/km
    var targetPace: Double?
    var paceTolerance: Double  // seconds tolerance (e.g., 15 = ±15 sec/km)

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

    /// Pace range if target pace is set
    var paceRange: ClosedRange<Double>? {
        guard let target = targetPace else { return nil }
        return (target - paceTolerance)...(target + paceTolerance)
    }

    // MARK: - Init
    init(targetBPM: Int, toleranceBPM: Int = 5, targetPace: Double? = nil, paceTolerance: Double = 15) {
        self.targetBPM = targetBPM
        self.toleranceBPM = toleranceBPM
        self.targetPace = targetPace
        self.paceTolerance = paceTolerance
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

    // MARK: - Pace Checking

    /// Check if pace is within target range
    func paceInRange(_ pace: Double) -> Bool {
        guard let range = paceRange else { return true }  // No target = always ok
        return range.contains(pace)
    }

    /// Check if pace is too slow (higher number = slower)
    func paceIsTooSlow(_ pace: Double) -> Bool {
        guard let target = targetPace else { return false }
        return pace > target + paceTolerance
    }

    /// Check if pace is too fast (lower number = faster)
    func paceIsTooFast(_ pace: Double) -> Bool {
        guard let target = targetPace else { return false }
        return pace < target - paceTolerance
    }

    /// Get pace status
    func paceStatus(for pace: Double) -> PaceStatus {
        guard let target = targetPace else { return .noTarget }

        if paceInRange(pace) {
            return .onPace
        } else if paceIsTooSlow(pace) {
            return .tooSlow(by: pace - (target + paceTolerance))
        } else {
            return .tooFast(by: (target - paceTolerance) - pace)
        }
    }

    /// Get combined coaching status considering both cadence and pace
    func coachingStatus(cadence: Int, pace: Double, recordPace: Double? = nil) -> CoachingStatus {
        let cadenceStatus = status(for: cadence)
        let paceStatus = paceStatus(for: pace)

        return CoachingStatus(
            cadenceStatus: cadenceStatus,
            paceStatus: paceStatus,
            currentPace: pace,
            targetPace: targetPace,
            recordPace: recordPace
        )
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

// MARK: - Pace Status
enum PaceStatus: Equatable, CustomStringConvertible {
    case noTarget           // No target pace configured
    case onPace             // Within tolerance
    case tooSlow(by: Double)  // Seconds slower than target
    case tooFast(by: Double)  // Seconds faster than target

    var isOnPace: Bool {
        switch self {
        case .onPace, .noTarget: return true
        default: return false
        }
    }

    var description: String {
        switch self {
        case .noTarget:
            return "noTarget"
        case .onPace:
            return "onPace"
        case .tooSlow(let diff):
            return "tooSlow(\(Int(diff))s)"
        case .tooFast(let diff):
            return "tooFast(\(Int(diff))s)"
        }
    }

    var color: Color {
        switch self {
        case .noTarget, .onPace:
            return .green
        case .tooSlow:
            return .orange
        case .tooFast:
            return .blue
        }
    }
}

// MARK: - Combined Coaching Status
/// Unified coaching status that combines cadence and pace analysis
struct CoachingStatus: Equatable {
    let cadenceStatus: ZoneStatus
    let paceStatus: PaceStatus
    let currentPace: Double
    let targetPace: Double?
    let recordPace: Double?

    /// Overall status: are we performing well?
    var isPerformingWell: Bool {
        cadenceStatus.isInZone && paceStatus.isOnPace
    }

    /// Are we beating the record pace?
    var isBetterThanRecord: Bool {
        guard let record = recordPace, currentPace > 0 else { return false }
        return currentPace < record - 5  // At least 5 sec/km faster
    }

    /// Primary coaching instruction based on combined analysis
    var primaryInstruction: CoachingInstruction {
        // Priority 1: Check if way off on cadence
        if case .belowZone(let diff) = cadenceStatus, diff > 15 {
            return .speedUpCadence(diff)
        }
        if case .aboveZone(let diff) = cadenceStatus, diff > 15 {
            return .slowDownCadence(diff)
        }

        // Priority 2: Check pace
        if case .tooSlow(let diff) = paceStatus, diff > 10 {
            return .speedUpPace(diff)
        }
        if case .tooFast(let diff) = paceStatus, diff > 10 {
            return .slowDownPace(diff)
        }

        // Priority 3: Minor cadence adjustments
        if case .belowZone(let diff) = cadenceStatus {
            return .speedUpCadence(diff)
        }
        if case .aboveZone(let diff) = cadenceStatus {
            return .slowDownCadence(diff)
        }

        // Priority 4: Minor pace adjustments
        if case .tooSlow(let diff) = paceStatus {
            return .speedUpPace(diff)
        }
        if case .tooFast(let diff) = paceStatus {
            return .slowDownPace(diff)
        }

        // All good - check if beating record
        if isBetterThanRecord {
            return .recordPace
        }

        return .maintainPace
    }

    var color: Color {
        if isPerformingWell {
            return isBetterThanRecord ? .yellow : .green
        }
        if case .belowZone = cadenceStatus { return .blue }
        if case .aboveZone = cadenceStatus { return .red }
        if case .tooSlow = paceStatus { return .orange }
        if case .tooFast = paceStatus { return .blue }
        return .secondary
    }
}

// MARK: - Coaching Instructions
enum CoachingInstruction: Equatable {
    case maintainPace
    case speedUpCadence(Int)      // SPM difference
    case slowDownCadence(Int)
    case speedUpPace(Double)      // Seconds/km difference
    case slowDownPace(Double)
    case recordPace               // Beating personal record

    /// Spanish voice message for this instruction
    var voiceMessage: String {
        switch self {
        case .maintainPace:
            return "Mantén el ritmo"
        case .speedUpCadence(let diff):
            if diff > 10 {
                return "Acelera. Sube la cadencia"
            }
            return "Un poco más rápido"
        case .slowDownCadence(let diff):
            if diff > 10 {
                return "Baja el ritmo. Cadencia demasiado alta"
            }
            return "Baja un poco la cadencia"
        case .speedUpPace(let diff):
            if diff > 20 {
                return "Acelera. Ritmo demasiado lento"
            }
            return "Sube el ritmo"
        case .slowDownPace(let diff):
            if diff > 20 {
                return "Frena un poco. Vas muy rápido"
            }
            return "Baja un poco el ritmo"
        case .recordPace:
            return "¡Ritmo récord! Sigue así"
        }
    }

    /// Short UI text
    var shortText: String {
        switch self {
        case .maintainPace:
            return "Mantén"
        case .speedUpCadence:
            return "↑ Cadencia"
        case .slowDownCadence:
            return "↓ Cadencia"
        case .speedUpPace:
            return "↑ Ritmo"
        case .slowDownPace:
            return "↓ Ritmo"
        case .recordPace:
            return "🏆 Récord"
        }
    }

    var icon: String {
        switch self {
        case .maintainPace:
            return "checkmark.circle.fill"
        case .speedUpCadence, .speedUpPace:
            return "arrow.up.circle.fill"
        case .slowDownCadence, .slowDownPace:
            return "arrow.down.circle.fill"
        case .recordPace:
            return "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .maintainPace:
            return .green
        case .speedUpCadence, .speedUpPace:
            return .orange
        case .slowDownCadence, .slowDownPace:
            return .blue
        case .recordPace:
            return .yellow
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
