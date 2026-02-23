import Foundation

/// A completed or in-progress training session
struct TrainingSession: Identifiable, Codable, Equatable {
    let id: UUID
    let planId: UUID
    let planName: String
    let startDate: Date
    var endDate: Date?
    var intervals: [IntervalRecord]
    var isCompleted: Bool
    var totalDistance: Double  // meters
    var avgHeartRate: Int
    var maxHeartRate: Int
    var minHeartRate: Int
    var timeInZone: TimeInterval  // seconds
    var score: Double  // 0-100
    var totalSteps: Int  // steps in this session
    var isWalkingWorkout: Bool  // true if this was a walking workout

    // MARK: - Computed Properties
    var duration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }

    var durationFormatted: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var distanceFormatted: String {
        let km = totalDistance / 1000
        return String(format: "%.2f km", km)
    }

    var avgPace: Double? {
        guard totalDistance > 0 else { return nil }
        // seconds per kilometer
        return duration / (totalDistance / 1000)
    }

    var avgPaceFormatted: String {
        guard let pace = avgPace else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var avgSpeed: Double? {
        guard totalDistance > 0 else { return nil }
        // km/h
        let hours = duration / 3600
        guard hours > 0 else { return nil }
        return (totalDistance / 1000) / hours
    }

    var avgSpeedFormatted: String {
        guard let speed = avgSpeed else { return "--" }
        return String(format: "%.1f km/h", speed)
    }

    var timeInZonePercentage: Double {
        guard duration > 0 else { return 0 }
        return (timeInZone / duration) * 100
    }

    var completedIntervals: Int {
        intervals.filter { $0.phase == .work }.count
    }

    var stepsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: totalSteps)) ?? "\(totalSteps)"
    }

    // MARK: - Init
    init(
        id: UUID = UUID(),
        planId: UUID,
        planName: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        intervals: [IntervalRecord] = [],
        isCompleted: Bool = false,
        totalDistance: Double = 0,
        avgHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        minHeartRate: Int = 0,
        timeInZone: TimeInterval = 0,
        score: Double = 0,
        totalSteps: Int = 0,
        isWalkingWorkout: Bool = false
    ) {
        self.id = id
        self.planId = planId
        self.planName = planName
        self.startDate = startDate
        self.endDate = endDate
        self.intervals = intervals
        self.isCompleted = isCompleted
        self.totalDistance = totalDistance
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.timeInZone = timeInZone
        self.score = score
        self.totalSteps = totalSteps
        self.isWalkingWorkout = isWalkingWorkout
    }
}

// MARK: - Interval Record
struct IntervalRecord: Identifiable, Equatable {
    let id: UUID
    let phase: IntervalPhase
    let seriesNumber: Int
    let blockNumber: Int    // Which block within a series (1-based). 1 for simple plans.
    let targetCadence: Int  // Target cadence (SPM) for this interval. 0 if unknown.
    let startTime: TimeInterval  // offset from session start
    let startDistance: Double    // totalDistance at interval start (meters)
    var duration: TimeInterval
    var avgHR: Int
    var maxHR: Int
    var minHR: Int
    var distance: Double  // meters
    var avgPace: Double  // seconds per km
    var timeInZone: TimeInterval
    var hrSamples: [HRSample]

    // MARK: - Computed
    var timeInZonePercentage: Double {
        guard duration > 0 else { return 0 }
        return (timeInZone / duration) * 100
    }

    var paceFormatted: String {
        guard avgPace > 0 else { return "--:--" }
        let minutes = Int(avgPace) / 60
        let seconds = Int(avgPace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var avgSpeed: Double {
        guard avgPace > 0 else { return 0 }
        return 3600.0 / avgPace  // km/h
    }

    var speedFormatted: String {
        guard avgSpeed > 0 else { return "--" }
        return String(format: "%.1f km/h", avgSpeed)
    }

    var distanceFormatted: String {
        guard distance > 0 else { return "--" }
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.2f km", distance / 1000)
    }

    // MARK: - Init
    init(
        id: UUID = UUID(),
        phase: IntervalPhase,
        seriesNumber: Int,
        blockNumber: Int = 1,
        targetCadence: Int = 0,
        startTime: TimeInterval,
        startDistance: Double = 0,
        duration: TimeInterval = 0,
        avgHR: Int = 0,
        maxHR: Int = 0,
        minHR: Int = 0,
        distance: Double = 0,
        avgPace: Double = 0,
        timeInZone: TimeInterval = 0,
        hrSamples: [HRSample] = []
    ) {
        self.id = id
        self.phase = phase
        self.seriesNumber = seriesNumber
        self.blockNumber = blockNumber
        self.targetCadence = targetCadence
        self.startTime = startTime
        self.startDistance = startDistance
        self.duration = duration
        self.avgHR = avgHR
        self.maxHR = maxHR
        self.minHR = minHR
        self.distance = distance
        self.avgPace = avgPace
        self.timeInZone = timeInZone
        self.hrSamples = hrSamples
    }
}

// MARK: - IntervalRecord Codable (custom for backwards compatibility)
extension IntervalRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, phase, seriesNumber, blockNumber, targetCadence
        case startTime, startDistance
        case duration, avgHR, maxHR, minHR, distance, avgPace, timeInZone, hrSamples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        phase = try c.decode(IntervalPhase.self, forKey: .phase)
        seriesNumber = try c.decode(Int.self, forKey: .seriesNumber)
        // New fields — default to safe values for old sessions that predate them
        blockNumber = (try? c.decode(Int.self, forKey: .blockNumber)) ?? 1
        targetCadence = (try? c.decode(Int.self, forKey: .targetCadence)) ?? 0
        startTime = try c.decode(TimeInterval.self, forKey: .startTime)
        startDistance = (try? c.decode(Double.self, forKey: .startDistance)) ?? 0
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        avgHR = try c.decode(Int.self, forKey: .avgHR)
        maxHR = try c.decode(Int.self, forKey: .maxHR)
        minHR = try c.decode(Int.self, forKey: .minHR)
        distance = try c.decode(Double.self, forKey: .distance)
        avgPace = try c.decode(Double.self, forKey: .avgPace)
        timeInZone = try c.decode(TimeInterval.self, forKey: .timeInZone)
        hrSamples = (try? c.decode([HRSample].self, forKey: .hrSamples)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(phase, forKey: .phase)
        try c.encode(seriesNumber, forKey: .seriesNumber)
        try c.encode(blockNumber, forKey: .blockNumber)
        try c.encode(targetCadence, forKey: .targetCadence)
        try c.encode(startTime, forKey: .startTime)
        try c.encode(startDistance, forKey: .startDistance)
        try c.encode(duration, forKey: .duration)
        try c.encode(avgHR, forKey: .avgHR)
        try c.encode(maxHR, forKey: .maxHR)
        try c.encode(minHR, forKey: .minHR)
        try c.encode(distance, forKey: .distance)
        try c.encode(avgPace, forKey: .avgPace)
        try c.encode(timeInZone, forKey: .timeInZone)
        try c.encode(hrSamples, forKey: .hrSamples)
    }
}
