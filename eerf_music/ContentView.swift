//
//  ContentView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import AVKit
import YouTubeKit

struct DownloadProgress: Identifiable {
    let id = UUID()
    let title: String
    var progress: Double
    var isCompleted: Bool
    var error: String?
}

struct AudioPlayerView: View {
    let song: DownloadedSong
    @Binding var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text(song.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Progress Bar
            Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                if !editing {
                    player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1000))
                }
            }
            .padding(.horizontal)
            
            // Time Labels
            HStack {
                Text(formatTime(currentTime))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 40) {
                Button(action: skipBackward) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                
                Button(action: skipForward) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .padding()
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func setupPlayer() {
        guard let player = player else { return }
        
        // Get duration
        if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
            self.duration = duration
        }
        
        // Setup time observer
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            currentTime = player.currentTime().seconds
            isPlaying = player.timeControlStatus == .playing
            
            // Update duration if it wasn't available initially
            if duration == 0, let newDuration = player.currentItem?.duration.seconds, !newDuration.isNaN {
                duration = newDuration
            }
        }
    }
    
    private func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    private func skipForward() {
        guard let player = player else { return }
        let newTime = min(currentTime + 15, duration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1000))
    }
    
    private func skipBackward() {
        guard let player = player else { return }
        let newTime = max(currentTime - 15, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1000))
    }
    
    private func formatTime(_ timeInSeconds: Double) -> String {
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ContentView: View {
    @State private var youtubeURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadedSongs: [DownloadedSong] = []
    @State private var currentlyPlaying: AVPlayer?
    @State private var activeDownloads: [DownloadProgress] = []
    @State private var selectedSong: DownloadedSong?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter YouTube URL", text: $youtubeURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: downloadSong) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Download")
                            .bold()
                    }
                }
                .disabled(youtubeURL.isEmpty || isLoading)
                .buttonStyle(.borderedProminent)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Active Downloads
                ForEach(activeDownloads) { download in
                    VStack(alignment: .leading) {
                        Text(download.title)
                            .lineLimit(1)
                        
                        if let error = download.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        } else {
                            ProgressView(value: download.progress)
                                .progressViewStyle(.linear)
                            Text("\(Int(download.progress * 100))%")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Downloaded Songs
                List(downloadedSongs) { song in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(song.title)
                            .font(.headline)
                        
                        HStack {
                            Button(action: { playSong(song) }) {
                                Label("Play", systemImage: "play.circle.fill")
                            }
                            
                            Button(action: { shareSong(song) }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Spacer()
                            
                            if let size = song.fileSize {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playSong(song)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteSong(song)
                    } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                // Audio Player
                if let selectedSong = selectedSong {
                    AudioPlayerView(song: selectedSong, player: $currentlyPlaying)
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Music Downloader")
        }
        .onAppear {
            loadSavedSongs()
            
            // Setup audio session
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to set audio session category: \(error)")
            }
        }
    }
    
    private func downloadSong() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let url = URL(string: youtubeURL) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                
                // Create YouTube extractor with remote fallback
                let youtube = YouTube(url: url, methods: [.local, .remote])
                let streams = try await youtube.streams
                
                guard let audioStream = streams
                    .filterAudioOnly()
                    .filter({ $0.fileExtension == .m4a })
                    .highestAudioBitrateStream() else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No suitable audio stream found"])
                }
                
                guard let metadata = try await youtube.metadata else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get metadata"])
            }
                // Create download progress tracker
                let downloadProgress = DownloadProgress(
                    title: metadata.title,
                    progress: 0.0,
                    isCompleted: false
                )
                
                await MainActor.run {
                    activeDownloads.append(downloadProgress)
                    isLoading = false
                }
                
                // Create download task
                let downloadTask = URLSession.shared.downloadTask(with: audioStream.url) { localURL, response, error in
                    Task {
                        await handleDownloadCompletion(
                            localURL: localURL,
                            response: response,
                            error: error,
                            metadata: metadata,
                            downloadProgress: downloadProgress
                        )
                    }
                }
                
                // Observe download progress
                let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                    Task { @MainActor in
                        if let index = activeDownloads.firstIndex(where: { $0.id == downloadProgress.id }) {
                            activeDownloads[index].progress = progress.fractionCompleted
                        }
                    }
                }
                
                // Start download
                downloadTask.resume()
                
                // Keep observation alive
                _ = observation
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
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
            guard let localURL = localURL else {
                throw error ?? NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
            }
            
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "\(metadata.title).m4a".replacingOccurrences(of: "/", with: "-")
            let destURL = docs.appendingPathComponent(fileName)
            
            // Remove existing file if needed
            try? fileManager.removeItem(at: destURL)
            
            // First move the downloaded file to documents
            try fileManager.moveItem(at: localURL, to: destURL)
            
            // Get the actual duration using AVAsset
            let asset = AVAsset(url: destURL)
            let duration = try await asset.load(.duration)
            let durationInSeconds = CMTimeGetSeconds(duration)
            
            // If duration is valid, trim the file
            if durationInSeconds > 0 {
                let actualDuration = durationInSeconds / 2 // Since file is double length
                
                // Create a temporary URL for the trimmed file
                let tempURL = docs.appendingPathComponent("temp_\(fileName)")
                
                // Setup export session
                let timeRange = CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: actualDuration, preferredTimescale: 1000)
                )
                
                let exporter = AVAssetExportSession(
                    asset: asset,
                    presetName: AVAssetExportPresetAppleM4A
                )
                
                exporter?.outputURL = tempURL
                exporter?.outputFileType = .m4a
                exporter?.timeRange = timeRange
                
                // Export the trimmed file
                if let exporter = exporter {
                    try? fileManager.removeItem(at: tempURL)
                    await exporter.export()
                    
                    if exporter.status == .completed {
                        // Replace original file with trimmed version
                        try? fileManager.removeItem(at: destURL)
                        try fileManager.moveItem(at: tempURL, to: destURL)
                    } else if let error = exporter.error {
                        print("Export failed: \(error.localizedDescription)")
                        // Continue with original file if trim fails
                    }
                }
            }
            
            // Get final file size
            let attributes = try fileManager.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int
            
            let newSong = DownloadedSong(
                id: UUID(),
                title: metadata.title,
                fileURL: destURL,
                fileSize: fileSize
            )
            
            await MainActor.run {
                downloadedSongs.append(newSong)
                activeDownloads.removeAll { $0.id == downloadProgress.id }
                youtubeURL = ""
                saveSongs()
            }
            
        } catch {
            await MainActor.run {
                if let index = activeDownloads.firstIndex(where: { $0.id == downloadProgress.id }) {
                    activeDownloads[index].error = error.localizedDescription
                }
            }
        }
    }
    
    private func playSong(_ song: DownloadedSong) {
        currentlyPlaying?.pause()
        
        // Create new player
        let player = AVPlayer(url: song.fileURL)
        currentlyPlaying = player
        selectedSong = song
        player.play()
    }

    private func shareSong(_ song: DownloadedSong) {
        let activityVC = UIActivityViewController(
            activityItems: [song.fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func deleteSong(_ song: DownloadedSong) {
        do {
            try FileManager.default.removeItem(at: song.fileURL)
            downloadedSongs.removeAll { $0.id == song.id }
            saveSongs()
        } catch {
            errorMessage = "Failed to delete song: \(error.localizedDescription)"
        }
    }
    
    private func saveSongs() {
        if let encoded = try? JSONEncoder().encode(downloadedSongs) {
            UserDefaults.standard.set(encoded, forKey: "downloadedSongs")
        }
    }
    
    private func loadSavedSongs() {
        if let data = UserDefaults.standard.data(forKey: "downloadedSongs"),
           let decoded = try? JSONDecoder().decode([DownloadedSong].self, from: data) {
            // Filter out songs whose files no longer exist
            downloadedSongs = decoded.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
            // Save the filtered list back
            if downloadedSongs.count != decoded.count {
                saveSongs()
            }
        }
    }
}

struct DownloadedSong: Identifiable, Codable {
    let id: UUID
    let title: String
    let fileURL: URL
    let fileSize: Int?
}

#Preview {
    ContentView()
}
