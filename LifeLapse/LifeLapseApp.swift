//
//  LifeLapseApp.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import SwiftUI
import SwiftData

@main
struct LifeLapseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Event.self])
        
        // Use CloudKitManager for robust container creation
        return CloudKitManager.createModelContainer(schema: schema)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
