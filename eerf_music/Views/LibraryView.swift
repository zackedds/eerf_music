//
//  LibraryView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @EnvironmentObject private var manager: DownloadManager
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]
    @Binding var showingPlayer: Song?

    /// Expose only the binding; hide the `songs` query from callers
    init(showingPlayer: Binding<Song?>) {
        self._showingPlayer = showingPlayer
    }

    var body: some View {
        List {
            // --- Active downloads
            Section("Downloads") {
                ForEach(manager.activeDownloads) { progress in
                    DownloadRowView(progress: progress)
                }
            }

            // --- Completed songs
            Section("Library") {
                ForEach(songs) { song in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(song.title)
                            .font(.headline)

                        HStack {
                            Button {
                                manager.play(song)
                                showingPlayer = song
                            } label: {
                                Label("Play", systemImage: "play.circle.fill")
                            }

                            Button {
                                share(song)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }

                            Spacer()

                            if let size = song.fileSize {
                                Text(ByteCountFormatter
                                        .string(fromByteCount: Int64(size),
                                                countStyle: .file))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            manager.delete(song)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        manager.play(song)
                        showingPlayer = song
                    }
                }
            }
        }
    }

    private func share(_ song: Song) {
        let vc = UIActivityViewController(
            activityItems: [song.fileURL],
            applicationActivities: nil
        )
        if let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController
        {
            root.present(vc, animated: true)
        }
    }
}

// Optional preview helper
#Preview {
    let container = try! ModelContainer(for: Song.self)
    LibraryView(showingPlayer: .constant(nil))
        .modelContainer(container)
        .environmentObject(DownloadManager(context: container.mainContext))
}
