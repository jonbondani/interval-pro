import CoreData
import Foundation
import Combine

/// Repository for training session persistence
/// Per CLAUDE.md: Use protocol abstraction for testability
protocol SessionRepositoryProtocol: AnyObject {
    func save(_ session: TrainingSession) async throws
    func fetch(id: UUID) async throws -> TrainingSession?
    func fetchRecent(limit: Int) async throws -> [TrainingSession]
    func fetchByPlan(planId: UUID) async throws -> [TrainingSession]
    func fetchBest(forPlanId: UUID) async throws -> TrainingSession?
    func fetchInDateRange(from: Date, to: Date) async throws -> [TrainingSession]
    func fetchBestPacesPerBlock(forPlanId: UUID) async throws -> [Int: Double]
    func migrateDefaultPlanIds() async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

@MainActor
final class SessionRepository: SessionRepositoryProtocol, ObservableObject {
    // MARK: - Dependencies
    private let coreDataStack: CoreDataStack

    // MARK: - Init
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - Save
    func save(_ session: TrainingSession) async throws {
        let context = coreDataStack.viewContext

        // Check if session already exists
        let fetchRequest = TrainingSessionEntity.fetchByID(session.id)
        let existingEntities = try context.fetch(fetchRequest)

        let entity: TrainingSessionEntity
        if let existing = existingEntities.first {
            entity = existing
        } else {
            entity = TrainingSessionEntity(context: context)
        }

        entity.update(from: session)
        try await coreDataStack.save()

        Log.persistence.debug("Session saved: \(session.id)")
    }

    // MARK: - Fetch
    func fetch(id: UUID) async throws -> TrainingSession? {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingSessionEntity.fetchByID(id)
        let entities = try context.fetch(fetchRequest)
        return entities.first?.toDomainModel()
    }

    func fetchRecent(limit: Int = 10) async throws -> [TrainingSession] {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingSessionEntity.fetchRecent(limit: limit)
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { $0.toDomainModel() }
    }

    func fetchByPlan(planId: UUID) async throws -> [TrainingSession] {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingSessionEntity.fetchByPlan(planId)
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { $0.toDomainModel() }
    }

    func fetchBest(forPlanId planId: UUID) async throws -> TrainingSession? {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingSessionEntity.fetchBestSession(forPlanId: planId)
        let entities = try context.fetch(fetchRequest)
        return entities.first?.toDomainModel()
    }

    func fetchInDateRange(from: Date, to: Date) async throws -> [TrainingSession] {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingSessionEntity.fetchSessionsInDateRange(from: from, to: to)
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { $0.toDomainModel() }
    }

    /// Scans ALL sessions for a plan and returns the best (lowest) pace per block index.
    /// Block index is 1-based. Handles both new data (blockNumber set) and old data (positional).
    func fetchBestPacesPerBlock(forPlanId planId: UUID) async throws -> [Int: Double] {
        let context = coreDataStack.viewContext
        let request = TrainingSessionEntity.fetchAllByPlan(planId)
        let entities = try context.fetch(request)
        var best: [Int: Double] = [:]
        for entity in entities {
            guard let data = entity.intervalsData,
                  let intervals = try? JSONDecoder().decode([IntervalRecord].self, from: data) else { continue }
            let workIntervals = intervals.filter { $0.phase == .work && $0.avgPace > 0 }
            guard !workIntervals.isEmpty else { continue }
            let hasBlockData = workIntervals.contains { $0.blockNumber > 1 || $0.targetCadence > 0 }
            if hasBlockData {
                for iv in workIntervals {
                    let k = iv.blockNumber
                    if let existing = best[k] { if iv.avgPace < existing { best[k] = iv.avgPace } }
                    else { best[k] = iv.avgPace }
                }
            } else {
                // Old data: all blockNumber=1, use position within each series as block index
                var seenSeries: [Int] = []
                for iv in workIntervals { if !seenSeries.contains(iv.seriesNumber) { seenSeries.append(iv.seriesNumber) } }
                let bySeries = Dictionary(grouping: workIntervals, by: \.seriesNumber)
                for seriesNum in seenSeries {
                    let seriesIntervals = bySeries[seriesNum] ?? []
                    for (idx, iv) in seriesIntervals.enumerated() {
                        let k = idx + 1
                        if let existing = best[k] { if iv.avgPace < existing { best[k] = iv.avgPace } }
                        else { best[k] = iv.avgPace }
                    }
                }
            }
        }
        return best
    }

    // MARK: - Migration
    /// Fixes sessions saved before stable plan UUIDs were introduced.
    /// Matches by planName → updates planId to the stable hardcoded value.
    func migrateDefaultPlanIds() async throws {
        let stableIds: [String: UUID] = [
            "Recomendado":    UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            "Principiante":   UUID(uuidString: "00000002-0000-0000-0000-000000000002")!,
            "Intermedio":     UUID(uuidString: "00000003-0000-0000-0000-000000000003")!,
            "Avanzado":       UUID(uuidString: "00000004-0000-0000-0000-000000000004")!,
            "Caminata 50min": UUID(uuidString: "00000005-0000-0000-0000-000000000005")!,
        ]
        let context = coreDataStack.viewContext
        let request = TrainingSessionEntity.fetchRequest()
        let entities = try context.fetch(request)
        var changed = false
        for entity in entities {
            guard let name = entity.planName,
                  let stableId = stableIds[name],
                  entity.planId != stableId else { continue }
            entity.planId = stableId
            changed = true
        }
        if changed {
            try await coreDataStack.save()
            Log.persistence.info("Migrated session planIds to stable UUIDs")
        }
    }

    // MARK: - Delete
    func delete(id: UUID) async throws {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingSessionEntity.fetchByID(id)
        let entities = try context.fetch(fetchRequest)

        if let entity = entities.first {
            context.delete(entity)
            try await coreDataStack.save()
            Log.persistence.debug("Session deleted: \(id)")
        }
    }

    func deleteAll() async throws {
        try await coreDataStack.deleteAllData()
    }
}

// MARK: - Mock for Testing
final class MockSessionRepository: SessionRepositoryProtocol {
    var sessions: [TrainingSession] = []

    func save(_ session: TrainingSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func fetch(id: UUID) async throws -> TrainingSession? {
        sessions.first { $0.id == id }
    }

    func fetchRecent(limit: Int) async throws -> [TrainingSession] {
        Array(sessions.sorted { $0.startDate > $1.startDate }.prefix(limit))
    }

    func fetchByPlan(planId: UUID) async throws -> [TrainingSession] {
        sessions.filter { $0.planId == planId }
    }

    func fetchBest(forPlanId planId: UUID) async throws -> TrainingSession? {
        sessions
            .filter { $0.planId == planId && $0.isCompleted }
            .max { $0.score < $1.score }
    }

    func fetchInDateRange(from: Date, to: Date) async throws -> [TrainingSession] {
        sessions.filter { $0.startDate >= from && $0.startDate <= to }
    }

    func delete(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
    }

    func migrateDefaultPlanIds() async throws { }

    func fetchBestPacesPerBlock(forPlanId planId: UUID) async throws -> [Int: Double] { [:] }

    func deleteAll() async throws {
        sessions.removeAll()
    }
}
