//
//  DownloadProgress.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import Foundation

struct DownloadProgress: Identifiable {
    let id = UUID()
    let title: String
    var progress: Double          // 0…1
    var isCompleted: Bool
    var error: String?
}
