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

    func deleteAll() async throws {
        sessions.removeAll()
    }
}
