//
//  WindowTestApp.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI

@main
struct WindowTestApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
