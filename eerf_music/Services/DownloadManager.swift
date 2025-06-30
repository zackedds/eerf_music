//
//  DownloadManager.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import AVKit
import YouTubeKit
import SwiftData          // ← NEW

@MainActor
final class DownloadManager: ObservableObject {
    // MARK: – Published state
    @Published var activeDownloads: [DownloadProgress] = []
    @Published var errorMessage: String?

    // Shared audio player
    @Published var player: AVPlayer?

    // MARK: – SwiftData
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        configureAudioSession()
    }

    // MARK: – Public API ------------------------------------------------

    func startDownload(from urlString: String) {
        Task { await downloadSong(urlString) }
    }

    func play(_ song: Song) {
        player?.pause()
        player = AVPlayer(url: song.fileURL)
        player?.play()
    }

    func delete(_ song: Song) {
        do {
            try FileManager.default.removeItem(at: song.fileURL)
            context.delete(song)                       // SwiftData delete
        } catch {
            errorMessage = "Failed to delete song: \(error.localizedDescription)"
        }
    }

    // MARK: – Private helpers ------------------------------------------

    private func downloadSong(_ urlString: String) async {
        errorMessage = nil

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        do {
            // 1) Extract streams & metadata
            let yt = YouTube(url: url, methods: [.local, .remote])
            let streams = try await yt.streams

            guard let audioStream = streams
                    .filterAudioOnly()
                    .filter({ $0.fileExtension == .m4a })
                    .highestAudioBitrateStream()
            else {
                throw NSError(domain: "", code: -1,
                              userInfo: [NSLocalizedDescriptionKey:
                                         "No suitable audio stream found"])
            }

            guard let metadata = try await yt.metadata else {
                throw NSError(domain: "", code: -1,
                              userInfo: [NSLocalizedDescriptionKey:
                                         "Failed to get metadata"])
            }

            // 2) Track progress in UI
            let progressRow = DownloadProgress(
                title: metadata.title,
                progress: 0,
                isCompleted: false,
                error: nil)
            activeDownloads.append(progressRow)

            // 3) Download
            let task = URLSession.shared.downloadTask(with: audioStream.url) {
                localURL, _, err in
                Task { await self.handleDownloadCompletion(
                    localURL: localURL,
                    error: err,
                    metadata: metadata,
                    progressRow: progressRow)
                }
            }

            let obs = task.progress.observe(\.fractionCompleted) { prog, _ in
                Task { @MainActor in
                    if let idx = self.activeDownloads
                        .firstIndex(where: { $0.id == progressRow.id }) {
                        self.activeDownloads[idx].progress = prog.fractionCompleted
                    }
                }
            }

            task.resume()
            _ = obs      // keep observation alive

        } catch { errorMessage = error.localizedDescription }
    }

    private func handleDownloadCompletion(
        localURL: URL?,
        error: Error?,
        metadata: YouTubeMetadata,
        progressRow: DownloadProgress
    ) async {
        do {
            guard let localURL else {
                throw error ?? NSError(domain: "", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey:
                                                  "Download failed"])
            }

            let fm  = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "\(metadata.title).m4a"
                            .replacingOccurrences(of: "/", with: "-")
            let destURL  = docs.appendingPathComponent(fileName)
            try? fm.removeItem(at: destURL)
            try fm.moveItem(at: localURL, to: destURL)

            // Trim (same logic as before, using AVURLAsset + new exporter API)
            let asset = AVURLAsset(url: destURL)
            let dur   = try await asset.load(.duration)
            let secs  = CMTimeGetSeconds(dur)

            if secs > 0 {
                let half    = secs / 2
                let tempURL = docs.appendingPathComponent("temp_\(fileName)")
                guard let exporter = AVAssetExportSession(
                        asset: asset,
                        presetName: AVAssetExportPresetAppleM4A) else {
                    print("Exporter create fail"); throw NSError()
                }
                exporter.outputURL      = tempURL
                exporter.outputFileType = .m4a
                exporter.timeRange = CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: half, preferredTimescale: 1000))

                try? fm.removeItem(at: tempURL)

                if #available(iOS 18, *) {
                    try? await exporter.export(to: tempURL, as: .m4a)
                    try? fm.removeItem(at: destURL)
                    try? fm.moveItem(at: tempURL, to: destURL)
                } else {
                    exporter.exportAsynchronously {
                        if exporter.status == .completed {
                            try? fm.removeItem(at: destURL)
                            try? fm.moveItem(at: tempURL, to: destURL)
                        }
                    }
                }
            }

            // Build SwiftData entity & save
            let attrs  = try fm.attributesOfItem(atPath: destURL.path)
            let sz     = attrs[.size] as? Int
            let song   = Song(title: metadata.title,
                              fileName: fileName,
                              fileSize: sz)
            context.insert(song)

            // Remove row from active list
            activeDownloads.removeAll { $0.id == progressRow.id }

        } catch {
            if let idx = activeDownloads
                .firstIndex(where: { $0.id == progressRow.id }) {
                activeDownloads[idx].error = error.localizedDescription
            }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio session error: \(error)") }
    }
}
