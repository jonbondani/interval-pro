import CoreData
import Foundation
import Combine

/// Repository for training plan persistence
protocol PlanRepositoryProtocol: AnyObject {
    func save(_ plan: TrainingPlan) async throws
    func fetch(id: UUID) async throws -> TrainingPlan?
    func fetchAll() async throws -> [TrainingPlan]
    func fetchCustomPlans() async throws -> [TrainingPlan]
    func delete(id: UUID) async throws
    func seedDefaultPlans() async throws
}

@MainActor
final class PlanRepository: PlanRepositoryProtocol, ObservableObject {
    // MARK: - Dependencies
    private let coreDataStack: CoreDataStack

    // MARK: - Constants
    private let maxCustomPlans = 10  // Free tier limit

    // MARK: - Init
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - Save
    func save(_ plan: TrainingPlan) async throws {
        // Check custom plan limit (free tier)
        if !plan.isDefault {
            let customPlans = try await fetchCustomPlans()
            if customPlans.count >= maxCustomPlans && !customPlans.contains(where: { $0.id == plan.id }) {
                throw PlanRepositoryError.maxPlansReached
            }
        }

        let context = coreDataStack.viewContext
        let fetchRequest = TrainingPlanEntity.fetchByID(plan.id)
        let existingEntities = try context.fetch(fetchRequest)

        let entity: TrainingPlanEntity
        if let existing = existingEntities.first {
            entity = existing
        } else {
            entity = TrainingPlanEntity(context: context)
        }

        entity.update(from: plan)
        try await coreDataStack.save()

        Log.persistence.debug("Plan saved: \(plan.name)")
    }

    // MARK: - Fetch
    func fetch(id: UUID) async throws -> TrainingPlan? {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingPlanEntity.fetchByID(id)
        let entities = try context.fetch(fetchRequest)
        return entities.first?.toDomainModel()
    }

    func fetchAll() async throws -> [TrainingPlan] {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingPlanEntity.fetchAllSorted()
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { $0.toDomainModel() }
    }

    func fetchCustomPlans() async throws -> [TrainingPlan] {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingPlanEntity.fetchCustomPlans()
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { $0.toDomainModel() }
    }

    // MARK: - Delete
    func delete(id: UUID) async throws {
        let context = coreDataStack.viewContext
        let fetchRequest = TrainingPlanEntity.fetchByID(id)
        let entities = try context.fetch(fetchRequest)

        if let entity = entities.first {
            // Don't allow deleting default plans
            guard !entity.isDefault else {
                throw PlanRepositoryError.cannotDeleteDefaultPlan
            }

            context.delete(entity)
            try await coreDataStack.save()
            Log.persistence.debug("Plan deleted: \(id)")
        }
    }

    // MARK: - Seed Default Plans
    func seedDefaultPlans() async throws {
        let existingPlans = try await fetchAll()

        // Only seed if no default plans exist
        let hasDefaults = existingPlans.contains { $0.isDefault }
        guard !hasDefaults else { return }

        for template in TrainingPlan.defaultTemplates {
            try await save(template)
        }

        Log.persistence.info("Default training plans seeded")
    }
}

// MARK: - Errors
enum PlanRepositoryError: LocalizedError {
    case maxPlansReached
    case cannotDeleteDefaultPlan

    var errorDescription: String? {
        switch self {
        case .maxPlansReached:
            return "Has alcanzado el límite de planes personalizados. Actualiza a Premium para planes ilimitados."
        case .cannotDeleteDefaultPlan:
            return "No puedes eliminar los planes predeterminados."
        }
    }
}

// MARK: - Mock for Testing
final class MockPlanRepository: PlanRepositoryProtocol {
    var plans: [TrainingPlan] = TrainingPlan.defaultTemplates

    func save(_ plan: TrainingPlan) async throws {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
    }

    func fetch(id: UUID) async throws -> TrainingPlan? {
        plans.first { $0.id == id }
    }

    func fetchAll() async throws -> [TrainingPlan] {
        plans.sorted { ($0.isDefault ? 0 : 1) < ($1.isDefault ? 0 : 1) }
    }

    func fetchCustomPlans() async throws -> [TrainingPlan] {
        plans.filter { !$0.isDefault }
    }

    func delete(id: UUID) async throws {
        plans.removeAll { $0.id == id }
    }

    func seedDefaultPlans() async throws {
        // Already seeded in init
    }
}
