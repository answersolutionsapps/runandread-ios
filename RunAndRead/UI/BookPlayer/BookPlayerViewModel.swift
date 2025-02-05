//
//  BookPlayerViewModel.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import SwiftUI
import AVFoundation

class BookPlayerViewModel: ObservableObject {
    @Binding var path: NavigationPath
    @Published var currentTime: Float = 0
    @Published var currentDuration: Float = 0
    @Published var currentDurationString: String = "00:00"
    @Published var currentTimeString: String = "00:00"
    @Published var currentFrame: [String] = ["Test 123", "Test 345", "Test 567"]
    @Published var currentWordIndexInFrame = 0

    private var bookManager: BookManager
    private var player: TextToSpeechPlayer

    init(path: Binding<NavigationPath>, bookManager: BookManager, player: TextToSpeechPlayer) {
        self.bookManager = bookManager
        self.player = player
        _path = path
    }

    func setupBook() {
        bookManager.loadCurrentBook {
            if let b = self.bookManager.currentBook {
                DispatchQueue.main.async {
                    self.player.setup(
                            currentBook: b,
                            onSetUp: { _, progress, currentWord, frame, indexInFrame in
                                self.currentDuration = Float(self.player.totalWords)
                                self.currentDurationString = self.player.totalTimeString
                                self.currentFrame = frame
                                self.currentTimeString = progress
                                self.currentWordIndexInFrame = indexInFrame
                                self.currentTime = Float(currentWord)
                                self.bookManager.updateLastPosition(for: b.id, newPosition: currentWord)
                            },
                            progressCallback: { progress, currentWord, frame, indexInFrame in
                                DispatchQueue.main.async {
                                    self.currentFrame = frame
                                    self.currentTimeString = progress
                                    self.currentWordIndexInFrame = indexInFrame
                                    self.currentTime = Float(currentWord)
                                    self.bookManager.updateLastPosition(for: b.id, newPosition: currentWord)
                                }
                            },
                            onAddBookmarkCallback: {
                                self.bookManager.addABookmark()
                            }
                    )
                    self.currentFrame = []
                    self.currentWordIndexInFrame = -1
                }
            }
        }
    }

    @MainActor func stopPlayer() {
        self.player.stop()
        self.bookManager.persist { _ in

        }
    }

    func onGoToLibrary() {
        self.currentFrame = []
        self.currentWordIndexInFrame = 0
        self.bookManager.persist { _ in
            DispatchQueue.main.async {
                self.bookManager.deleteCurrentBook {
                    self.path.removeLast()
                    self.path.append(AppScreen.home)
                }
            }
        }
    }

    func onEditAction() {
        path.append(AppScreen.newBook)
    }

    @MainActor func updatePosition(book: Book) {
        self.bookManager.updateLastPosition(for: book.id, newPosition: Int(currentTime))
        self.player.onPrepareForPlayFromNewPosition()
        self.player.defineCurrentWordIndex(value: Int(currentTime)) { label in
            self.currentTimeString = label
        }
    }

    func addBookmark() {
        self.bookManager.addABookmark()
    }
    
    @MainActor func isInitializing() -> Bool {
        return !player.isNotUndefined()
    }

    @MainActor func currentBook() -> Book? {
        if player.isNotUndefined() {
            return bookManager.currentBook
        } else {
            return nil
        }
    }

    //----Player

    @MainActor func onPlayPause() {
        player.playPause()
    }

    @MainActor func onRewind() {
        player.rewind()
    }

    @MainActor func onFastForward() {
        player.fastForward()
    }

    @MainActor func playButtonIconName() -> String {
        return player.isPlaying() ? "pause.circle.fill" : "play.circle.fill"
    }

    @MainActor func isPlaying() -> Bool {
        return player.isPlaying()
    }

    @MainActor func textForBookmark(bookmark: Bookmark, book: Book) -> String {
        return player.textForBookmark(bookmark: bookmark, book: book) ?? "Loading.."
    }

    @MainActor func onBookmarkSelect(bookmark: Bookmark) {
        self.player.onPrepareForPlayFromNewPosition()
        self.player.defineCurrentWordIndex(value: Int(bookmark.position))
        self.player.updateProgress()
        self.player.playPause()
    }
}

