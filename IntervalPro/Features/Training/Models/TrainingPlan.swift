import Foundation

/// A single work block with its own zone and rest period
/// Supports progressive training with different intensities
struct WorkBlock: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var workZone: HeartRateZone
    var workDuration: TimeInterval  // seconds
    var restZone: HeartRateZone
    var restDuration: TimeInterval  // seconds

    init(
        workZone: HeartRateZone,
        workDuration: TimeInterval = 180,
        restZone: HeartRateZone = HeartRateZone(targetBPM: 150, toleranceBPM: 10),
        restDuration: TimeInterval = 180
    ) {
        self.workZone = workZone
        self.workDuration = workDuration
        self.restZone = restZone
        self.restDuration = restDuration
    }

    var totalDuration: TimeInterval {
        workDuration + restDuration
    }
}

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
    var warmupZone: HeartRateZone?
    var cooldownDuration: TimeInterval?
    var cooldownZone: HeartRateZone?
    var createdAt: Date
    var isDefault: Bool

    /// Optional array of work blocks for progressive training
    /// If set, overrides single workZone/restZone
    var workBlocks: [WorkBlock]?

    /// Whether this plan uses progressive blocks
    var isProgressive: Bool {
        workBlocks != nil && !(workBlocks?.isEmpty ?? true)
    }

    /// Number of blocks per series (1 for simple plans, N for progressive)
    var blocksPerSeries: Int {
        workBlocks?.count ?? 1
    }

    // MARK: - Computed Properties
    var totalDuration: TimeInterval {
        let warmup = warmupDuration ?? 0
        let cooldown = cooldownDuration ?? 0

        let intervalsDuration: TimeInterval
        if let blocks = workBlocks, !blocks.isEmpty {
            // Progressive: sum all blocks per series
            let blocksDuration = blocks.reduce(0) { $0 + $1.totalDuration }
            intervalsDuration = TimeInterval(seriesCount) * blocksDuration
        } else {
            // Simple: single work/rest per series
            intervalsDuration = TimeInterval(seriesCount) * (workDuration + restDuration)
        }

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

    // MARK: - Init (Simple plan)
    init(
        id: UUID = UUID(),
        name: String,
        workZone: HeartRateZone,
        restZone: HeartRateZone,
        workDuration: TimeInterval = 180,  // 3 minutes default
        restDuration: TimeInterval = 180,  // 3 minutes default
        seriesCount: Int = 4,
        warmupDuration: TimeInterval? = 300,  // 5 minutes
        warmupZone: HeartRateZone? = nil,
        cooldownDuration: TimeInterval? = 300,  // 5 minutes
        cooldownZone: HeartRateZone? = nil,
        createdAt: Date = Date(),
        isDefault: Bool = false,
        workBlocks: [WorkBlock]? = nil
    ) {
        self.id = id
        self.name = name
        self.workZone = workZone
        self.restZone = restZone
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.seriesCount = seriesCount
        self.warmupDuration = warmupDuration
        self.warmupZone = warmupZone
        self.cooldownDuration = cooldownDuration
        self.cooldownZone = cooldownZone
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.workBlocks = workBlocks
    }

    // MARK: - Init (Progressive plan with blocks)
    init(
        id: UUID = UUID(),
        name: String,
        workBlocks: [WorkBlock],
        seriesCount: Int,
        warmupDuration: TimeInterval? = 300,
        warmupZone: HeartRateZone? = nil,
        cooldownDuration: TimeInterval? = 300,
        cooldownZone: HeartRateZone? = nil,
        createdAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.workBlocks = workBlocks
        self.seriesCount = seriesCount
        self.warmupDuration = warmupDuration
        self.warmupZone = warmupZone
        self.cooldownDuration = cooldownDuration
        self.cooldownZone = cooldownZone
        self.createdAt = createdAt
        self.isDefault = isDefault

        // Use first block as default work/rest zones for compatibility
        self.workZone = workBlocks.first?.workZone ?? HeartRateZone(targetBPM: 170, toleranceBPM: 5)
        self.restZone = workBlocks.first?.restZone ?? HeartRateZone(targetBPM: 150, toleranceBPM: 10)
        self.workDuration = workBlocks.first?.workDuration ?? 180
        self.restDuration = workBlocks.first?.restDuration ?? 180
    }
}

// MARK: - Default Templates
extension TrainingPlan {
    /// Rest zone used across all plans
    private static let standardRestZone = HeartRateZone(targetBPM: 150, toleranceBPM: 10)

    /// Recommended progressive pyramid workout
    /// 5 min warmup @ 150 BPM
    /// 2 series of: 3min@160 + rest, 3min@170 + rest, 3min@180 + rest
    /// 5 min cooldown @ 150 BPM
    static let recommended = TrainingPlan(
        name: "Recomendado",
        workBlocks: [
            WorkBlock(
                workZone: HeartRateZone(targetBPM: 160, toleranceBPM: 5),
                workDuration: 180,  // 3 min
                restZone: standardRestZone,
                restDuration: 180   // 3 min
            ),
            WorkBlock(
                workZone: HeartRateZone(targetBPM: 170, toleranceBPM: 5),
                workDuration: 180,  // 3 min
                restZone: standardRestZone,
                restDuration: 180   // 3 min
            ),
            WorkBlock(
                workZone: HeartRateZone(targetBPM: 180, toleranceBPM: 5),
                workDuration: 180,  // 3 min
                restZone: standardRestZone,
                restDuration: 180   // 3 min
            )
        ],
        seriesCount: 2,
        warmupDuration: 300,     // 5 min
        warmupZone: standardRestZone,
        cooldownDuration: 300,   // 5 min
        cooldownZone: standardRestZone,
        isDefault: true
    )

    /// Beginner template: Lower intensity, longer rest
    static let beginner = TrainingPlan(
        name: "Principiante",
        workZone: HeartRateZone(targetBPM: 160, toleranceBPM: 8),
        restZone: HeartRateZone(targetBPM: 140, toleranceBPM: 10),
        workDuration: 120,  // 2 min
        restDuration: 180,  // 3 min
        seriesCount: 3,
        warmupDuration: 300,
        warmupZone: HeartRateZone(targetBPM: 140, toleranceBPM: 10),
        cooldownDuration: 300,
        cooldownZone: HeartRateZone(targetBPM: 140, toleranceBPM: 10),
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
        warmupZone: standardRestZone,
        cooldownDuration: 300,
        cooldownZone: standardRestZone,
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
        warmupZone: standardRestZone,
        cooldownDuration: 300,
        cooldownZone: standardRestZone,
        isDefault: true
    )

    static let defaultTemplates: [TrainingPlan] = [recommended, beginner, intermediate, advanced]
}
