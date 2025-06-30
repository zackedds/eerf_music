//
//  DownloadedSong.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import Foundation
import SwiftData

@Model
final class Song {
    //  SwiftData automatically provides `id` if you omit it,
    //  but we keep UUID so we can reuse existing logic.
    @Attribute(.unique) var id: UUID
    var title: String
    var fileName: String          // store only the file name
    var fileSize: Int?
    var dateAdded: Date           // for sorting

    init(title: String, fileName: String, fileSize: Int?) {
        self.id = UUID()
        self.title = title
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = Date()
    }

    // Computed convenience URL
    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
