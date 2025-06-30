//
//  eerf_musicApp.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import SwiftData

@main
struct eerf_musicApp: App {
    // 1) Build a container that knows about your Song model
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ Song.self ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // 2) Hold your DownloadManager as a StateObject
    @StateObject private var manager: DownloadManager

    init() {
        // 3) Grab the mainContext from the container
        let ctx = sharedModelContainer.mainContext
        // 4) Initialize your manager with that context
        _manager = StateObject(
            wrappedValue: DownloadManager(context: ctx)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 5) Inject both SwiftData and your manager
                .modelContainer(sharedModelContainer)
                .environmentObject(manager)
        }
    }
}
