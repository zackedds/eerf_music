//
//  ContentView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = DownloadManager()
    @State private var selectedSong: DownloadedSong?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DownloaderView()
                LibraryView(showingPlayer: $selectedSong)
                if let song = selectedSong {
                    AudioPlayerView(song: song, player: $manager.player)
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Music Downloader")
        }
        .environmentObject(manager)   // inject once
    }
}

#Preview {
    ContentView()
}
