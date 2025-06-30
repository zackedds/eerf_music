//
//  AudioPlayerView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI
import AVKit

struct AudioPlayerView: View {
    let song: Song                 // ← was DownloadedSong
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
                    player?.seek(to: CMTime(seconds: currentTime,
                                            preferredTimescale: 1_000))
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
                    Image(systemName: isPlaying
                          ? "pause.circle.fill"
                          : "play.circle.fill")
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
        .onAppear { setupPlayer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: – Private helpers
    private func setupPlayer() {
        guard let player else { return }

        if let dur = player.currentItem?.duration.seconds, !dur.isNaN {
            duration = dur
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            currentTime = player.currentTime().seconds
            isPlaying   = player.timeControlStatus == .playing

            if duration == 0,
               let newDur = player.currentItem?.duration.seconds,
               !newDur.isNaN {
                duration = newDur
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
        guard let player else { return }
        let newTime = min(currentTime + 15, duration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1_000))
    }

    private func skipBackward() {
        guard let player else { return }
        let newTime = max(currentTime - 15, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1_000))
    }

    private func formatTime(_ s: Double) -> String {
        let m = Int(s) / 60
        let s = Int(s) % 60
        return String(format: "%d:%02d", m, s)
    }
}

//#Preview {
//    AudioPlayerView()
//}
