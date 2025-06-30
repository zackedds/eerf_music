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
    // 1) Build a container that knows about Song
    private let container: ModelContainer = {
        let schema = Schema([Song.self])
        return try! ModelContainer(for: schema)          // crash-on-fail is fine here
    }()

    // 2) Create DownloadManager with the container’s main context
    @StateObject private var manager: DownloadManager

    init() {
        let ctx = container.mainContext
        _manager = StateObject(wrappedValue: DownloadManager(context: ctx))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)      // inject SwiftData
                .environmentObject(manager)     // inject manager
        }
    }
}
