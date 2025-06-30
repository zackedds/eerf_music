//
//  DownloaderView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI

struct DownloaderView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var youtubeURL = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter YouTube URL", text: $youtubeURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button {
                manager.startDownload(from: youtubeURL)
                youtubeURL = ""
            } label: {
                // instead of `manager.errorMessage == nil ? … : …`
                if manager.errorMessage == nil {
                    Text("Download")
                        .bold()
                } else {
                    ProgressView()
                }
            }
            .disabled(youtubeURL.isEmpty)
            .buttonStyle(.borderedProminent)

            if let error = manager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    DownloaderView()
        .environmentObject(DownloadManager())
}
