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

    /// Whether this is a walking workout (no intervals, single continuous session)
    var isWalkingWorkout: Bool {
        seriesCount == 1 && restDuration == 0 && warmupDuration == nil && cooldownDuration == nil
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
    /// Rest zone used across all plans (trote suave ~7:00/km)
    private static let standardRestZone = HeartRateZone(
        targetBPM: 150,
        toleranceBPM: 10,
        targetPace: 420,      // 7:00/km
        paceTolerance: 30
    )

    /// Warmup/cooldown zone (caminata rápida/trote muy suave ~8:00/km)
    private static let warmupZone = HeartRateZone(
        targetBPM: 140,
        toleranceBPM: 10,
        targetPace: 480,      // 8:00/km
        paceTolerance: 60
    )

    /// Recommended progressive pyramid workout
    /// Progresión: 6:00/km → 5:30/km → 5:00/km
    static let recommended = TrainingPlan(
        id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
        name: "Recomendado",
        workBlocks: [
            WorkBlock(
                workZone: HeartRateZone(
                    targetBPM: 160,
                    toleranceBPM: 5,
                    targetPace: 360,      // 6:00/km - ritmo cómodo
                    paceTolerance: 15
                ),
                workDuration: 180,
                restZone: standardRestZone,
                restDuration: 180
            ),
            WorkBlock(
                workZone: HeartRateZone(
                    targetBPM: 170,
                    toleranceBPM: 5,
                    targetPace: 330,      // 5:30/km - ritmo medio
                    paceTolerance: 15
                ),
                workDuration: 180,
                restZone: standardRestZone,
                restDuration: 180
            ),
            WorkBlock(
                workZone: HeartRateZone(
                    targetBPM: 180,
                    toleranceBPM: 5,
                    targetPace: 300,      // 5:00/km - ritmo rápido
                    paceTolerance: 15
                ),
                workDuration: 180,
                restZone: standardRestZone,
                restDuration: 180
            )
        ],
        seriesCount: 2,
        warmupDuration: 300,
        warmupZone: warmupZone,
        cooldownDuration: 300,
        cooldownZone: warmupZone,
        isDefault: true
    )

    /// Beginner template: Lower intensity, longer rest
    /// Ritmo objetivo: 6:30/km (suave)
    static let beginner = TrainingPlan(
        id: UUID(uuidString: "00000002-0000-0000-0000-000000000002")!,
        name: "Principiante",
        workZone: HeartRateZone(
            targetBPM: 160,
            toleranceBPM: 8,
            targetPace: 390,          // 6:30/km
            paceTolerance: 30         // ±30 seg tolerancia amplia
        ),
        restZone: HeartRateZone(
            targetBPM: 140,
            toleranceBPM: 10,
            targetPace: 480,          // 8:00/km (caminata/trote)
            paceTolerance: 60
        ),
        workDuration: 120,
        restDuration: 180,
        seriesCount: 3,
        warmupDuration: 300,
        warmupZone: warmupZone,
        cooldownDuration: 300,
        cooldownZone: warmupZone,
        isDefault: true
    )

    /// Intermediate template: Standard intensity
    /// Ritmo objetivo: 5:30/km
    static let intermediate = TrainingPlan(
        id: UUID(uuidString: "00000003-0000-0000-0000-000000000003")!,
        name: "Intermedio",
        workZone: HeartRateZone(
            targetBPM: 170,
            toleranceBPM: 5,
            targetPace: 330,          // 5:30/km
            paceTolerance: 15
        ),
        restZone: standardRestZone,
        workDuration: 180,
        restDuration: 180,
        seriesCount: 4,
        warmupDuration: 300,
        warmupZone: warmupZone,
        cooldownDuration: 300,
        cooldownZone: warmupZone,
        isDefault: true
    )

    /// Advanced template: High intensity, shorter rest
    /// Ritmo objetivo: 4:45/km (competición)
    static let advanced = TrainingPlan(
        id: UUID(uuidString: "00000004-0000-0000-0000-000000000004")!,
        name: "Avanzado",
        workZone: HeartRateZone(
            targetBPM: 180,
            toleranceBPM: 5,
            targetPace: 285,          // 4:45/km
            paceTolerance: 10         // Tolerancia estricta
        ),
        restZone: standardRestZone,
        workDuration: 180,
        restDuration: 120,
        seriesCount: 6,
        warmupDuration: 300,
        warmupZone: warmupZone,
        cooldownDuration: 300,
        cooldownZone: warmupZone,
        isDefault: true
    )

    /// Walking workout: 50 min steady pace
    /// Ritmo objetivo: 9:00-9:30/km (6.5-7 km/h)
    static let walking = TrainingPlan(
        id: UUID(uuidString: "00000005-0000-0000-0000-000000000005")!,
        name: "Caminata 50min",
        workZone: HeartRateZone(
            targetBPM: 115,           // Cadencia caminata: 110-120 SPM
            toleranceBPM: 10,
            targetPace: 545,          // ~9:05/km (6.6 km/h)
            paceTolerance: 25         // Permite 8:40 - 9:30/km
        ),
        restZone: HeartRateZone(      // No hay descanso, mismo ritmo
            targetBPM: 115,
            toleranceBPM: 10,
            targetPace: 545,
            paceTolerance: 25
        ),
        workDuration: 3000,           // 50 min = 3000 seg
        restDuration: 0,              // Sin descanso
        seriesCount: 1,               // Una sola serie continua
        warmupDuration: nil,          // Sin calentamiento
        warmupZone: nil,
        cooldownDuration: nil,        // Sin enfriamiento
        cooldownZone: nil,
        isDefault: true
    )

    static let defaultTemplates: [TrainingPlan] = [recommended, beginner, intermediate, advanced, walking]
}
