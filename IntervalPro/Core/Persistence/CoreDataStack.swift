import CoreData
import Foundation

/// Core Data stack manager with encrypted persistence
/// Per CLAUDE.md: All sensitive data must be encrypted
@MainActor
final class CoreDataStack: ObservableObject {
    // MARK: - Singleton
    static let shared = CoreDataStack()

    // MARK: - Container
    let container: NSPersistentContainer

    // MARK: - Contexts
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Init
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "IntervalPro")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure encrypted storage
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("No persistent store description found")
            }

            // Enable encryption for sensitive health data
            description.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )

            // Enable automatic lightweight migration
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                Log.persistence.error("Failed to load Core Data: \(error), \(error.userInfo)")
                // In production, handle gracefully - don't crash
                #if DEBUG
                fatalError("Core Data load error: \(error)")
                #endif
            }
            self?.configureContexts()
        }
    }

    private func configureContexts() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Save
    func save() async throws {
        guard viewContext.hasChanges else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            viewContext.perform { [weak self] in
                do {
                    try self?.viewContext.save()
                    Log.persistence.debug("Core Data saved successfully")
                    continuation.resume()
                } catch {
                    Log.persistence.error("Core Data save error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveBackground(context: NSManagedObjectContext) async throws {
        guard context.hasChanges else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    try context.save()
                    Log.persistence.debug("Background context saved successfully")
                    continuation.resume()
                } catch {
                    Log.persistence.error("Background save error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Delete All Data (GDPR Compliance)
    func deleteAllData() async throws {
        let context = newBackgroundContext()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Delete all entities
                    let entityNames = ["TrainingPlanEntity", "TrainingSessionEntity", "IntervalRecordEntity"]

                    for entityName in entityNames {
                        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                        deleteRequest.resultType = .resultTypeObjectIDs

                        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                        if let objectIDs = result?.result as? [NSManagedObjectID] {
                            let changes = [NSDeletedObjectsKey: objectIDs]
                            NSManagedObjectContext.mergeChanges(
                                fromRemoteContextSave: changes,
                                into: [self.viewContext]
                            )
                        }
                    }

                    Log.persistence.info("All user data deleted successfully")
                    continuation.resume()
                } catch {
                    Log.persistence.error("Failed to delete all data: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Preview Support
extension CoreDataStack {
    static var preview: CoreDataStack {
        let stack = CoreDataStack(inMemory: true)
        // Add sample data for previews if needed
        return stack
    }
}
