//
//  TextToSpeechPlayer+BookPlayer.swift
//  RunAndRead
//
//  Conformance of TextToSpeechPlayer to BookPlayer abstraction.
//  Created by Serge Nes on 12/12/25.
//

import Foundation

extension TextToSpeechPlayer: BookPlayer {
    func definePosition(value: Int, updateLabel: ((String) -> Void)?) {
        onPrepareForPlayFromNewPosition()
        defineCurrentWordIndex(value: value, updateLabel: updateLabel)
    }

    func generateBookmarks(for book: RunAndReadBook) {
        if let b = book as? Book {
            generateBookmarks(book: b)
        }
    }
}
