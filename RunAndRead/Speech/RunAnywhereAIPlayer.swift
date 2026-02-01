//
//  RunAnywhereAIPlayer.swift
//  RunAndRead
//
//  Adapter for RunAnywhereAI SDK TTS playback
//

import Foundation
import RunAnywhere
import Combine
import SwiftUI
import MediaPlayer
import os

extension RunAnywhereAIPlayer {

    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Enable Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playPause()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playPause()
            }
            return .success
        }

        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.fastForward()
            }
            return .success
        }

        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.rewind()
            }
            return .success
        }

        commandCenter.bookmarkCommand.addTarget { [weak self] _ in
            self?.onAddBookmarkCallback?()
            return .success
        }
    }

    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = author
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        nowPlayingInfo[MPMediaItemPropertySkipCount] = RunAnywhereAIPlayer.SkipCountSeconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalTime

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func updateProgressNowPlayingInfo() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = indexToElapsedSeconds()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func tearDownRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.bookmarkCommand.removeTarget(nil)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension RunAnywhereAIPlayer {
    static let SkipCountSeconds: Int = 30
    static let SkipCountWords: Int = 60
    static let WordFrameSize: Int = 100
    static let BookmarkTextLength: Int = 30
    static let BookmarkOffcet: Int = 5
}

@MainActor
class RunAnywhereAIPlayer: NSObject, ObservableObject, Sendable {
    private let logger = Logger(subsystem: "com.runandread", category: "RunAnywhereAIPlayer")
    private let ttsViewModel = TTSViewModel()

    private var words: [String] = []
    private var defaultLanguage = Locale.current
    var speed: Float = 0.5

    @Published var currentFrame: [String] = []
    @Published private var currentWordIndex = 0
    @Published var currentWordIndexInFrame = 0
    @Published var totalTime: TimeInterval = 0
    @Published var totalTimeString: String = "00:00"
    @Published var totalWords: Int = 0
    @Published var state: PlayerState = .undefined

    private var progressCallback: ((String, Int, [String], Int) -> Void)?
    private var onAddBookmarkCallback: (() -> Void)?

    private var author: String = ""
    private var title: String = ""
    private var artwork: MPMediaItemArtwork? = nil

    private var cancellables = Set<AnyCancellable>()
    private var isInitialized = false
    private var progressTimer: Timer?
    private var frameStartTime: Date?

    override init() {
        super.init()
        if let albumCoverImage = UIImage(named: "albumCover") {
            artwork = MPMediaItemArtwork(boundsSize: albumCoverImage.size) { size in
                return albumCoverImage
            }
        }
    }

    func setup(
            currentBook: Book?,
            onSetUp: @escaping (Bool, String, Int, [String], Int) -> Void,
            progressCallback: ((String, Int, [String], Int) -> Void)?,
            onAddBookmarkCallback: (() -> Void)?
    ) {
        if let book = currentBook {
            stop()
            words = book.text.flatMap {
                        $0.cleanedForTTS().components(separatedBy: .whitespacesAndNewlines)
                    }
                    .filter {
                        !$0.isEmpty
                    }

            self.progressCallback = nil
            self.progressCallback = progressCallback
            self.onAddBookmarkCallback = nil
            self.onAddBookmarkCallback = onAddBookmarkCallback

            self.defaultLanguage = book.language
            self.speed = book.voiceRate
            self.author = book.author
            self.title = book.title

            defineCurrentWordIndex(value: book.lastPosition)

            // Approximate seconds per word based on speech rate
            self.totalTime = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(speed)
            self.totalWords = words.count
            self.totalTimeString = totalTime.formatSecondsToHMS()

            // Initialize TTS SDK and ensure model is downloaded and loaded
            Task {
                await ttsViewModel.initialize()

                // Use the selected voice from book, or default
                let modelId = book.runAnywhereVoiceId ?? "vits-piper-en_US-lessac-medium"

                // Load the selected TTS model if not already loaded
                if await RunAnywhere.currentTTSVoiceId != modelId {
                    logger.info("Loading TTS model: \(modelId)")
                    do {
                        // Check if model is downloaded
                        let availableModels = try await RunAnywhere.availableModels()
                        if let model = availableModels.first(where: { $0.id == modelId }) {
                            // Check if model needs to be downloaded (localPath is nil)
                            if model.localPath == nil {
                                logger.info("📥 Downloading TTS model: \(model.name)")

                                // Download the model
                                let progressStream = try await RunAnywhere.downloadModel(modelId)
                                for await progress in progressStream {
                                    if progress.stage == .completed {
                                        logger.info("✅ Model download completed")
                                        break
                                    }
                                    logger.info("Download progress: \(Int(progress.overallProgress * 100))%")
                                }
                            } else {
                                logger.info("✅ Model already downloaded")
                            }

                            // Now load the model
                            try await RunAnywhere.loadTTSModel(modelId)
                            logger.info("✅ TTS model loaded: \(modelId)")
                        }
                    } catch {
                        logger.error("❌ Failed to setup TTS model: \(error.localizedDescription)")
                    }
                }

                // Call onSetUp after model is loaded
                onSetUp(true, self.indexToElapsedSeconds().formatSecondsToHMS(), self.currentWordIndex, self.currentFrame, self.currentWordIndexInFrame)
            }

            state = .idle
        } else {
            logger.error("setup.error currentBook is not defined.")
            onSetUp(false, indexToElapsedSeconds().formatSecondsToHMS(), currentWordIndex, currentFrame, currentWordIndexInFrame)
        }
        tearDownRemoteTransportControls()
        setupRemoteTransportControls()
    }

    func isNotUndefined() -> Bool {
        return state != .undefined && !words.isEmpty
    }

    func stop() {
        state = .idle
        words.removeAll()
        currentFrame.removeAll()
        currentWordIndexInFrame = 0
        progressCallback = nil
        onAddBookmarkCallback = nil
        stopProgressTimer()

        Task {
            await ttsViewModel.stopSpeaking()
        }

        tearDownRemoteTransportControls()
    }

    func endTheBook() {
        state = .idle
        currentFrame.removeAll()
        currentWordIndexInFrame = 0
        stopProgressTimer()

        Task {
            await ttsViewModel.stopSpeaking()
        }

        updateNowPlayingInfo()
    }

    func onPrepareForPlayFromNewPosition() {
        state = .idle
        currentFrame.removeAll()
        currentWordIndexInFrame = 0
        stopProgressTimer()

        Task {
            await ttsViewModel.stopSpeaking()
        }
    }

    func playPause() {
        if state == .playing {
            Task {
                await ttsViewModel.stopSpeaking()
            }
            state = .pause
            stopProgressTimer()
        } else {
            state = .playing
            Task {
                await speakCurrentFrame()
            }
        }
        updateNowPlayingInfo()
    }

    func isPlaying() -> Bool {
        return state == .playing
    }

    func defineCurrentWordIndex(value: Int, updateLabel: ((String) -> Void)? = nil) {
        currentWordIndex = min(value, words.count - 1)
        currentWordIndex = max(currentWordIndex, 0)
        updateLabel?(indexToElapsedSeconds().formatSecondsToHMS())
    }

    func fastForward() {
        Task {
            await ttsViewModel.stopSpeaking()
        }
        currentWordIndex = min(currentWordIndex + RunAnywhereAIPlayer.SkipCountWords, words.count - 1)
        state = .idle
        stopProgressTimer()
        updateProgress()
    }

    func rewind() {
        Task {
            await ttsViewModel.stopSpeaking()
        }
        currentWordIndex = max(currentWordIndex - RunAnywhereAIPlayer.SkipCountWords, 0)
        state = .idle
        stopProgressTimer()
        updateProgress()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        frameStartTime = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateProgressDuringPlayback()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        frameStartTime = nil
    }

    private func updateProgressDuringPlayback() {
        guard state == .playing, !currentFrame.isEmpty, let startTime = frameStartTime else { return }

        let elapsedInFrame = Date().timeIntervalSince(startTime)

        // Calculate estimated duration for the entire frame
        let totalCharactersInFrame = Double(currentFrame.joined(separator: " ").count)
        let estimatedFrameDuration = (totalCharactersInFrame * Book.SECONDS_PER_CHARACTER) / Double(speed)

        // Calculate progress ratio and estimate word index
        let progressRatio = elapsedInFrame / estimatedFrameDuration
        let estimatedWordIndex = min(Int(progressRatio * Double(currentFrame.count)), currentFrame.count - 1)

        if estimatedWordIndex != currentWordIndexInFrame {
            currentWordIndexInFrame = estimatedWordIndex
            updateProgress()
        }
    }

    private func speakCurrentFrame() async {
        guard state == .playing else { return }

        let remainingWords = Array(words[currentWordIndex...])
        currentFrame = Array(remainingWords.prefix(RunAnywhereAIPlayer.WordFrameSize))
        currentWordIndexInFrame = 0
        let textToSpeak = currentFrame.joined(separator: " ")

        // Start progress timer to track word-by-word progress
        startProgressTimer()

        // Use the speed/rate from the book settings
        ttsViewModel.speechRate = Double(speed)
        await ttsViewModel.speak(text: textToSpeak)

        // Stop timer after frame completes
        stopProgressTimer()

        // After speaking completes, move to next frame
        if state == .playing && currentWordIndex < words.count - 1 {
            currentWordIndex += currentFrame.count
            if currentWordIndex < words.count {
                await speakCurrentFrame()
            } else {
                endTheBook()
            }
        }
    }

    func generateBookmarks(book: Book) {
        logger.info("words: \(self.words.count)")
        if words.isEmpty {
            return
        }

        for i in book.bookmarks.indices {
            logger.info("bookmarks: \(i)")
            if book.bookmarks[i].text.isEmpty {
                let startIndex = max(book.bookmarks[i].position - RunAnywhereAIPlayer.BookmarkOffcet, 0)
                let endIndex = min(startIndex + RunAnywhereAIPlayer.BookmarkTextLength, words.count - 1)

                logger.info("startIndex: \(startIndex)")
                logger.info("endIndex: \(endIndex)")

                if endIndex <= words.count && words.count > 0 {
                    let elapsedSeconds = (Double(words.prefix(startIndex).joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.speed)

                    book.bookmarks[i].text = "\(elapsedSeconds.formatSecondsToHMS()) | \(words[startIndex...endIndex].joined(separator: " "))"
                } else {
                    book.bookmarks[i].text = "Unable to generate bookmark"
                }
            }
        }
    }

    private func indexToElapsedSeconds() -> TimeInterval {
        let elapsedSeconds = (Double(words.prefix(currentWordIndex).joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.speed)
        return elapsedSeconds
    }

    func updateProgress() {
        if currentWordIndex < words.count && currentWordIndex > -1 {
            progressCallback?(indexToElapsedSeconds().formatSecondsToHMS(), currentWordIndex, currentFrame, currentWordIndexInFrame)
        }
        updateProgressNowPlayingInfo()
    }
}

// MARK: - BookPlayer Conformance
extension RunAnywhereAIPlayer: BookPlayer {
    func definePosition(value: Int, updateLabel: ((String) -> Void)?) {
        defineCurrentWordIndex(value: value, updateLabel: updateLabel)
    }

    func generateBookmarks(for book: any RunAndReadBook) {
        if let book = book as? Book {
            generateBookmarks(book: book)
        }
    }
}
