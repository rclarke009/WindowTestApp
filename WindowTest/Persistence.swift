//
//  Persistence.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample jobs for preview
        let sampleJob1 = Job(context: viewContext)
        sampleJob1.jobId = "E2025-05091"
        sampleJob1.clientName = "Smith"
        sampleJob1.addressLine1 = "408 2nd Ave NW"
        sampleJob1.city = "Largo"
        sampleJob1.state = "FL"
        sampleJob1.zip = "33770"
        sampleJob1.status = "Ready"
        sampleJob1.createdAt = Date()
        sampleJob1.updatedAt = Date()
        
        let sampleJob2 = Job(context: viewContext)
        sampleJob2.jobId = "E2025-05092"
        sampleJob2.clientName = "Johnson"
        sampleJob2.addressLine1 = "1121 Palm Dr"
        sampleJob2.city = "Clearwater"
        sampleJob2.state = "FL"
        sampleJob2.zip = "33755"
        sampleJob2.status = "In Progress"
        sampleJob2.createdAt = Date()
        sampleJob2.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WindowTest")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
