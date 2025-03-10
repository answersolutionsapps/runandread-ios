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
    private var audioPlayer: AudioBookPlayer
    
    init(path: Binding<NavigationPath>,
         bookManager: BookManager,
         player: TextToSpeechPlayer,
         audioPlayer: AudioBookPlayer
    ) {
        self.bookManager = bookManager
        self.player = player
        self.audioPlayer = audioPlayer
        _path = path
    }

    func setupBook() {
        bookManager.loadCurrentBook {
            if let b = self.bookManager.currentBook as? Book {
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
            } else if let b = self.bookManager.currentBook as? AudioBook {
                DispatchQueue.main.async {
                    self.audioPlayer.setup(
                        currentBook: b,
                        onSetUp: { _, durationString, duration, progress, elapsedTime, frame, indexInFrame in
                            self.currentDuration = Float(duration)
                            self.currentDurationString = durationString
                            self.currentFrame = frame
                            self.currentTimeString = progress
                            self.currentWordIndexInFrame = indexInFrame
                            self.currentTime = Float(elapsedTime)
                            self.bookManager.updateLastPosition(for: b.id, newPosition: Int(elapsedTime))
                        },
                        progressCallback: { progress, elapsedTime, frame, indexInFrame in
                            DispatchQueue.main.async {
                                self.currentFrame = frame
                                self.currentTimeString = progress
                                self.currentWordIndexInFrame = indexInFrame
                                self.currentTime = Float(elapsedTime)
                                self.bookManager.updateLastPosition(for: b.id, newPosition: Int(elapsedTime))
                            }
                        },
                        onAddBookmarkCallback: {
                            self.bookManager.addABookmark()
                        }
                    )
                }
            }
        }
    }
    
    @MainActor func setupForPreview() {
        player.setup(currentBook:  Book(title: "This text has been narrated by the Run and Read app! We hope you enjoyed listening!", author: "Author", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum...","Test", "Test", "This text has been narrated", "This text has been narrated"], lastPosition: 0, bookmarks: [Bookmark(position: 1),Bookmark(position: 2),Bookmark(position: 3),Bookmark(position: 4)]))
        
        { _, progress, currentWord, frame, indexInFrame in
            
        } progressCallback: { progress, currentWord, frame, indexInFrame in
            
        } onAddBookmarkCallback: {
            self.bookManager.addABookmark()
        }
        self.currentFrame = []
        self.currentWordIndexInFrame = -1
    }

    @MainActor func stopPlayer() {
        if self.bookManager.currentBook is Book {
            self.player.stop()
        } else {
            self.audioPlayer.stop()
        }
        
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

    @MainActor func updatePosition(book: any RunAndReadBook) {
        self.bookManager.updateLastPosition(for: book.id, newPosition: Int(currentTime))
        
        if self.bookManager.currentBook is Book {
            self.player.onPrepareForPlayFromNewPosition()
            self.player.defineCurrentWordIndex(value: Int(currentTime)) { label in
                self.currentTimeString = label
            }
        } else {
            self.audioPlayer.defineElapsedTime(value: Int(currentTime)) { label in
                self.currentTimeString = label
            }
        }
        
        
    }

    func addBookmark() {
        self.bookManager.addABookmark()
    }
    
    @MainActor func isInitializing() -> Bool {
        return !player.isNotUndefined()
    }

    @MainActor func currentBook() -> (any RunAndReadBook)? {
        if bookManager.currentBook is AudioBook && audioPlayer.isNotUndefined() {
            return bookManager.currentBook
        } else if player.isNotUndefined() {
            return bookManager.currentBook
        } else {
            return nil
        }
    }

    //----Player

    @MainActor func onPlayPause() {
        if self.bookManager.currentBook is Book{
            player.playPause()
        } else {
            audioPlayer.playPause()
        }
       
    }

    @MainActor func onRewind() {
        if self.bookManager.currentBook is Book {
            player.rewind()
        }else {
            audioPlayer.rewind()
        }
        
    }

    @MainActor func onFastForward() {
        if self.bookManager.currentBook is Book{
            player.fastForward()
        }else {
            audioPlayer.fastForward()
        }
    }

    @MainActor func playButtonIconName() -> String {
        if self.bookManager.currentBook is Book {
            return player.isPlaying() ? "pause.circle.fill" : "play.circle.fill"
        }else {
            return audioPlayer.isPlaying() ? "pause.circle.fill" : "play.circle.fill"
        }
    }

    @MainActor func isPlaying() -> Bool {
        if self.bookManager.currentBook is Book {
            return player.isPlaying()
        } else {
            return audioPlayer.isPlaying()
        }
    }
    
    @MainActor func generateBookmarks(book: any RunAndReadBook) {
        if let b = book as? Book {
            player.generateBookmarks(book: b)
        } else if let b = book as? AudioBook {
            audioPlayer.generateBookmarks(book: b)
        }
    }

    @MainActor func onBookmarkSelect(bookmark: Bookmark) {
        if self.bookManager.currentBook is Book {
            self.player.onPrepareForPlayFromNewPosition()
            self.player.defineCurrentWordIndex(value: Int(bookmark.position))
            self.player.updateProgress()
            self.player.playPause()
        }else {
            self.audioPlayer.defineElapsedTime(value: Int(bookmark.position))
            self.audioPlayer.updateProgress()
            self.audioPlayer.playPause()
        }
    }
}

