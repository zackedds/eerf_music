//
//  Song.swift
//  eerf_music
//
//  Created by Zack Edds on 6/29/25.
//

import SwiftData
import Foundation

@Model
final class Song {
  @Attribute(.unique) var id: UUID
  var title: String
  var fileName: String     // just the filename, not full URL
  var fileSize: Int?
  var dateAdded: Date

  init(
    title: String,
    fileName: String,
    fileSize: Int?
  ) {
    self.id = UUID()
    self.title = title
    self.fileName = fileName
    self.fileSize = fileSize
    self.dateAdded = Date()
  }

  // computed helper to get the actual URL on disk
  var fileURL: URL {
    FileManager
      .default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(fileName)
  }
}
