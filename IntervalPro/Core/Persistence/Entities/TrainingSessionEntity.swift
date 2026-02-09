import CoreData
import Foundation

/// Core Data entity for TrainingSession
@objc(TrainingSessionEntity)
public class TrainingSessionEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var planId: UUID?
    @NSManaged public var planName: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var totalDistance: Double
    @NSManaged public var avgHeartRate: Int16
    @NSManaged public var maxHeartRate: Int16
    @NSManaged public var minHeartRate: Int16
    @NSManaged public var timeInZone: Double
    @NSManaged public var score: Double
    @NSManaged public var totalSteps: Int32
    @NSManaged public var isWalkingWorkout: Bool
    @NSManaged public var intervalsData: Data?  // Encoded [IntervalRecord]
    @NSManaged public var plan: TrainingPlanEntity?
}

// MARK: - Domain Model Mapping
extension TrainingSessionEntity {
    func toDomainModel() -> TrainingSession? {
        guard let id = id,
              let planId = planId,
              let planName = planName,
              let startDate = startDate else {
            return nil
        }

        var intervals: [IntervalRecord] = []
        if let data = intervalsData {
            do {
                intervals = try JSONDecoder().decode([IntervalRecord].self, from: data)
            } catch {
                Log.persistence.error("Failed to decode intervals: \(error)")
            }
        }

        return TrainingSession(
            id: id,
            planId: planId,
            planName: planName,
            startDate: startDate,
            endDate: endDate,
            intervals: intervals,
            isCompleted: isCompleted,
            totalDistance: totalDistance,
            avgHeartRate: Int(avgHeartRate),
            maxHeartRate: Int(maxHeartRate),
            minHeartRate: Int(minHeartRate),
            timeInZone: timeInZone,
            score: score,
            totalSteps: Int(totalSteps),
            isWalkingWorkout: isWalkingWorkout
        )
    }

    func update(from session: TrainingSession) {
        self.id = session.id
        self.planId = session.planId
        self.planName = session.planName
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.isCompleted = session.isCompleted
        self.totalDistance = session.totalDistance
        self.avgHeartRate = Int16(session.avgHeartRate)
        self.maxHeartRate = Int16(session.maxHeartRate)
        self.minHeartRate = Int16(session.minHeartRate)
        self.timeInZone = session.timeInZone
        self.score = session.score
        self.totalSteps = Int32(session.totalSteps)
        self.isWalkingWorkout = session.isWalkingWorkout

        // Encode intervals
        do {
            self.intervalsData = try JSONEncoder().encode(session.intervals)
        } catch {
            Log.persistence.error("Failed to encode intervals: \(error)")
        }
    }
}

// MARK: - Fetch Requests
extension TrainingSessionEntity {
    static func fetchRequest() -> NSFetchRequest<TrainingSessionEntity> {
        NSFetchRequest<TrainingSessionEntity>(entityName: "TrainingSessionEntity")
    }

    static func fetchByID(_ id: UUID) -> NSFetchRequest<TrainingSessionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    static func fetchRecent(limit: Int = 10) -> NSFetchRequest<TrainingSessionEntity> {
        let request = fetchRequest()
        // Fetch all sessions (completed and partial) sorted by date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrainingSessionEntity.startDate, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }

    static func fetchByPlan(_ planId: UUID) -> NSFetchRequest<TrainingSessionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "planId == %@ AND isCompleted == YES", planId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrainingSessionEntity.startDate, ascending: false)
        ]
        return request
    }

    static func fetchBestSession(forPlanId planId: UUID) -> NSFetchRequest<TrainingSessionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "planId == %@ AND isCompleted == YES", planId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrainingSessionEntity.score, ascending: false)
        ]
        request.fetchLimit = 1
        return request
    }

    static func fetchSessionsInDateRange(from: Date, to: Date) -> NSFetchRequest<TrainingSessionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@ AND isCompleted == YES",
            from as CVarArg,
            to as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrainingSessionEntity.startDate, ascending: false)
        ]
        return request
    }
}
