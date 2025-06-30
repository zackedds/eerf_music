//
//  LibraryView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var manager: DownloadManager
    @Binding var showingPlayer: DownloadedSong?   // ContentView binds this

    var body: some View {
        List {
            // Active downloads first
            Section("Downloads") {
                ForEach(manager.activeDownloads) { DownloadRowView(progress: $0) }
            }

            // Completed items
            Section("Library") {
                ForEach(manager.downloadedSongs) { song in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(song.title).font(.headline)

                        HStack {
                            Button { manager.play(song); showingPlayer = song } label: {
                                Label("Play", systemImage: "play.circle.fill")
                            }
                            Button { share(song) } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Spacer()
                            if let size = song.fileSize {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { manager.delete(song) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { manager.play(song); showingPlayer = song }
                }
            }
        }
    }

    private func share(_ song: DownloadedSong) {
        // unchanged body of shareSong(...) but scoped locally
    }
}

//#Preview {
//    LibraryView()
//}
