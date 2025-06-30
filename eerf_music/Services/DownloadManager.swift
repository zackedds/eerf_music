//
//  DownloadManager.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import AVKit
import YouTubeKit

@MainActor
final class DownloadManager: ObservableObject {

    // MARK: – Published state the UI binds to
    @Published var activeDownloads: [DownloadProgress] = []
    @Published var downloadedSongs: [DownloadedSong] = []
    @Published var errorMessage: String?

    // MARK: – Singleton audio player shared across views
    @Published var player: AVPlayer?          // still optional

    // MARK: – Persistence key
    private let userDefaultsKey = "downloadedSongs"

    init() {
        loadSavedSongs()
        configureAudioSession()
    }

    // MARK: – Public API

    func startDownload(from urlString: String) {
        Task { await downloadSong(urlString) }
    }

    func play(_ song: DownloadedSong) {
        player?.pause()
        player = AVPlayer(url: song.fileURL)
        player?.play()
    }

    func delete(_ song: DownloadedSong) {
        do {
            try FileManager.default.removeItem(at: song.fileURL)
            downloadedSongs.removeAll { $0.id == song.id }
            saveSongs()
        } catch {
            errorMessage = "Failed to delete song: \(error.localizedDescription)"
        }
    }

    // MARK: – Private helpers

    private func downloadSong(_ urlString: String) async {
        // clear any old error
        errorMessage = nil

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        do {
            // 1) Extract streams & metadata
            let youtube = YouTube(url: url, methods: [.local, .remote])
            let streams = try await youtube.streams

            guard let audioStream = streams
                .filterAudioOnly()
                .filter({ $0.fileExtension == .m4a })
                .highestAudioBitrateStream() else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No suitable audio stream found"
                ])
            }

            guard let metadata = try await youtube.metadata else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get metadata"
                ])
            }

            // 2) Create progress tracker
            let downloadProgress = DownloadProgress(
                title: metadata.title,
                progress: 0.0,
                isCompleted: false,
                error: nil
            )
            activeDownloads.append(downloadProgress)

            // 3) Kick off URLSession download
            let downloadTask = URLSession.shared.downloadTask(with: audioStream.url) { localURL, response, error in
                Task { await self.handleDownloadCompletion(
                    localURL: localURL,
                    response: response,
                    error: error,
                    metadata: metadata,
                    downloadProgress: downloadProgress
                ) }
            }

            // 4) Observe progress
            let observation = downloadTask.progress.observe(\.fractionCompleted) { prog, _ in
                Task { @MainActor in
                    if let idx = self.activeDownloads.firstIndex(where: { $0.id == downloadProgress.id }) {
                        self.activeDownloads[idx].progress = prog.fractionCompleted
                    }
                }
            }

            downloadTask.resume()
            _ = observation  // keep it alive

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleDownloadCompletion(
        localURL: URL?,
        response: URLResponse?,
        error: Error?,
        metadata: YouTubeMetadata,
        downloadProgress: DownloadProgress
    ) async {
        do {
            // ensure we got a file
            guard let localURL = localURL else {
                throw error ?? NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Download failed"
                ])
            }

            let fileManager = FileManager.default
            let docs = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]

            // move it into place
            let fileName = "\(metadata.title).m4a"
                .replacingOccurrences(of: "/", with: "-")
            let destURL = docs.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: destURL)
            try fileManager.moveItem(at: localURL, to: destURL)

            // 1) Use AVURLAsset instead of deprecated AVAsset(url:)
            let asset = AVURLAsset(url: destURL)
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)

            if seconds > 0 {
                // half-length trim
                let half = seconds / 2
                let tempURL = docs.appendingPathComponent("temp_\(fileName)")
                
                guard let exporter = AVAssetExportSession(
                    asset: asset,
                    presetName: AVAssetExportPresetAppleM4A
                ) else {
                    print("Failed to create exporter")
                    return
                }
                
                exporter.outputURL = tempURL
                exporter.outputFileType = .m4a
                exporter.timeRange = CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: half, preferredTimescale: 1000)
                )
                
                try? fileManager.removeItem(at: tempURL)
                
                if #available(iOS 18, *) {
                    // 2) Use the new async export(to:as:) API and rely on throws
                    do {
                        try await exporter.export(to: tempURL, as: .m4a)
                        // replace original only on success
                        try fileManager.removeItem(at: destURL)
                        try fileManager.moveItem(at: tempURL, to: destURL)
                    } catch {
                        print("Trim export failed: \(error.localizedDescription)")
                        // fallback to original file
                    }
                } else {
                    // 3) Fallback for iOS 17 and below
                    exporter.exportAsynchronously {
                        switch exporter.status {
                        case .completed:
                            try? fileManager.removeItem(at: destURL)
                            try? fileManager.moveItem(at: tempURL, to: destURL)
                        case .failed, .cancelled:
                            if let err = exporter.error {
                                print("Trim export failed: \(err.localizedDescription)")
                            }
                        default:
                            break
                        }
                    }
                }
            }

            // record file size & build model
            let attrs = try fileManager.attributesOfItem(atPath: destURL.path)
            let size = attrs[.size] as? Int
            let newSong = DownloadedSong(
                id: UUID(),
                title: metadata.title,
                fileURL: destURL,
                fileSize: size
            )

            // update lists
            downloadedSongs.append(newSong)
            activeDownloads.removeAll { $0.id == downloadProgress.id }
            saveSongs()

        } catch {
            // mark the download row errored
            if let idx = activeDownloads.firstIndex(where: { $0.id == downloadProgress.id }) {
                activeDownloads[idx].error = error.localizedDescription
            }
        }
    }

    private func saveSongs() {
        if let data = try? JSONEncoder().encode(downloadedSongs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadSavedSongs() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([DownloadedSong].self, from: data)
        else { return }

        // filter out missing files
        downloadedSongs = decoded.filter {
            FileManager.default.fileExists(atPath: $0.fileURL.path)
        }
        if downloadedSongs.count != decoded.count {
            saveSongs()
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
}
