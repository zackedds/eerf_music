//
//  DownloadRowView.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftUI

import SwiftUI

struct DownloadRowView: View {
    let progress: DownloadProgress

    var body: some View {
        VStack(alignment: .leading) {
            Text(progress.title).lineLimit(1)

            if let error = progress.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                ProgressView(value: progress.progress)
                Text("\(Int(progress.progress * 100)) %")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

//#Preview {
//    DownloadRowView()
//}
