import Foundation

/// A training plan configuration for interval workouts
/// Per CLAUDE.md: HR zones must NEVER be hardcoded
struct TrainingPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var workZone: HeartRateZone
    var restZone: HeartRateZone
    var workDuration: TimeInterval  // seconds
    var restDuration: TimeInterval  // seconds
    var seriesCount: Int
    var warmupDuration: TimeInterval?
    var cooldownDuration: TimeInterval?
    var createdAt: Date
    var isDefault: Bool

    // MARK: - Computed Properties
    var totalDuration: TimeInterval {
        let intervalsDuration = TimeInterval(seriesCount) * (workDuration + restDuration)
        let warmup = warmupDuration ?? 0
        let cooldown = cooldownDuration ?? 0
        return warmup + intervalsDuration + cooldown
    }

    var totalDurationFormatted: String {
        let minutes = Int(totalDuration) / 60
        return "\(minutes) min"
    }

    var estimatedCalories: Int {
        // Rough estimate: ~10 cal/min at high intensity, ~6 at rest
        let workMinutes = Double(seriesCount) * workDuration / 60.0
        let restMinutes = Double(seriesCount) * restDuration / 60.0
        let warmupMinutes = (warmupDuration ?? 0) / 60.0
        let cooldownMinutes = (cooldownDuration ?? 0) / 60.0

        let workCalories = workMinutes * 12
        let restCalories = restMinutes * 6
        let warmupCalories = warmupMinutes * 5
        let cooldownCalories = cooldownMinutes * 4

        return Int(workCalories + restCalories + warmupCalories + cooldownCalories)
    }

    // MARK: - Init
    init(
        id: UUID = UUID(),
        name: String,
        workZone: HeartRateZone,
        restZone: HeartRateZone,
        workDuration: TimeInterval = 180,  // 3 minutes default
        restDuration: TimeInterval = 180,  // 3 minutes default
        seriesCount: Int = 4,
        warmupDuration: TimeInterval? = 300,  // 5 minutes
        cooldownDuration: TimeInterval? = 300,  // 5 minutes
        createdAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.workZone = workZone
        self.restZone = restZone
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.seriesCount = seriesCount
        self.warmupDuration = warmupDuration
        self.cooldownDuration = cooldownDuration
        self.createdAt = createdAt
        self.isDefault = isDefault
    }
}

// MARK: - Default Templates
extension TrainingPlan {
    /// Beginner template: Lower intensity, longer rest
    static let beginner = TrainingPlan(
        name: "Principiante",
        workZone: HeartRateZone(targetBPM: 160, toleranceBPM: 8),
        restZone: HeartRateZone(targetBPM: 140, toleranceBPM: 10),
        workDuration: 120,  // 2 min
        restDuration: 180,  // 3 min
        seriesCount: 3,
        warmupDuration: 300,
        cooldownDuration: 300,
        isDefault: true
    )

    /// Intermediate template: Standard intensity
    static let intermediate = TrainingPlan(
        name: "Intermedio",
        workZone: HeartRateZone(targetBPM: 170, toleranceBPM: 5),
        restZone: HeartRateZone(targetBPM: 150, toleranceBPM: 8),
        workDuration: 180,  // 3 min
        restDuration: 180,  // 3 min
        seriesCount: 4,
        warmupDuration: 300,
        cooldownDuration: 300,
        isDefault: true
    )

    /// Advanced template: High intensity, shorter rest
    static let advanced = TrainingPlan(
        name: "Avanzado",
        workZone: HeartRateZone(targetBPM: 180, toleranceBPM: 5),
        restZone: HeartRateZone(targetBPM: 150, toleranceBPM: 8),
        workDuration: 180,  // 3 min
        restDuration: 120,  // 2 min
        seriesCount: 6,
        warmupDuration: 300,
        cooldownDuration: 300,
        isDefault: true
    )

    static let defaultTemplates: [TrainingPlan] = [beginner, intermediate, advanced]
}
