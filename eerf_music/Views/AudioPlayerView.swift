//
//  AudioPlayerView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import AVKit

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

//#Preview {
//    AudioPlayerView()
//}
