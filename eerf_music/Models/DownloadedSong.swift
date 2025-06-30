//
//  DownloadedSong.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import Foundation

struct DownloadedSong: Identifiable, Codable {
    let id: UUID
    let title: String
    let fileURL: URL
    let fileSize: Int?
}
