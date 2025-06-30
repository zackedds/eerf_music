//
//  ContentView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import SwiftData    // only needed for Preview

struct ContentView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var selectedSong: Song?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // URL + Download button
                DownloaderView()

                // In-flight downloads + library
                LibraryView(showingPlayer: $selectedSong)

                // Mini player
                if let song = selectedSong {
                    AudioPlayerView(
                        song: song,
                        player: $manager.player
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Music Downloader")
        }
    }
}

#Preview {
    // In-memory SwiftData store for previews
    let container = try! ModelContainer(for: Song.self)
    ContentView()
        .modelContainer(container)
        .environmentObject(DownloadManager(context: container.mainContext))
}
