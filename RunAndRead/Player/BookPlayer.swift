//
//  BookPlayer.swift
//  RunAndRead
//
//  Created by Serge Nes on 12/12/25.
//

import Foundation

protocol BookPlayer {
    // Core transport controls
    func playPause()
    func rewind()
    func fastForward()
    func isPlaying() -> Bool
    func stop()

    // Progress/position
    func definePosition(value: Int, updateLabel: ((String) -> Void)?)
    func updateProgress()

    // Bookmarks and metadata helpers
    func generateBookmarks(for book: any RunAndReadBook)
}

extension BookPlayer {
    // Provide safe defaults for optional features on specific implementations
    func definePosition(value: Int) {
        definePosition(value: value, updateLabel: nil)
    }
    func generateBookmarks(for book: any RunAndReadBook) { /* no-op by default */ }
}
