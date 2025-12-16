//
//  AudioBookPlayer+BookPlayer.swift
//  RunAndRead
//
//  Conformance of AudioBookPlayer to BookPlayer abstraction.
//  Created by Serge Nes on 12/12/25.
//

import Foundation

extension AudioBookPlayer: BookPlayer {
    func definePosition(value: Int, updateLabel: ((String) -> Void)?) {
        defineElapsedTime(value: value, updateLabel: updateLabel)
    }

    @MainActor func updateProgress() {
        updateProgress(force: false)
    }

    func generateBookmarks(for book: RunAndReadBook) {
        if let b = book as? AudioBook {
            generateBookmarks(book: b)
        }
    }
}
