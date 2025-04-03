//
//  AudioBookPlayer.swift
//  RunAndRead
//
//  Created by Serge Nes on 3/9/25.
//

import AVFoundation
import Combine
import SwiftUI
import MediaPlayer


extension AudioBookPlayer {

    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Enable Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }

        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.fastForward()
            return .success
        }

        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.rewind()
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
        nowPlayingInfo[MPMediaItemPropertySkipCount] = TextToSpeechPlayer.SkipCountSeconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalTime

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func updateProgressNowPlayingInfo(progressValue: TimeInterval) {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progressValue

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


@MainActor
class AudioBookPlayer: NSObject, AVAudioPlayerDelegate, ObservableObject, Sendable {
    private var audioPlayer: AVAudioPlayer?
    private var defaultLanguage = Locale.current
    var speed: Float = 1.0
    @Published private var elapsedSeconds: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    @Published var totalTimeString: String = "00:00"// In seconds
    @Published var totalDuration: Int = 0 // In seconds
    @Published var state: PlayerState = .undefined
    var parts: [TextPart] = []
    
    @Published var currentFrame: [String] = []
    @Published var currentWordIndexInFrame = 0

    private var progressCallback: ((String, TimeInterval, [String], Int) -> Void)? // Callback for progress updates
    private var onAddBookmarkCallback: (() -> Void)? // Callback for progress updates

    private var author: String = ""
    private var title: String = ""
    private var artwork: MPMediaItemArtwork? = nil
    
    private var timer: Timer?
    
    func getCurrentText(for elapsedSeconds: TimeInterval) -> (text: String, currentStartTime: Int, nextStartTime: Int?) {
        let elapsedMilliseconds = Int(elapsedSeconds * 1000) // Convert to ms

        guard !parts.isEmpty else {
            return ("", 0, nil) // Return empty if no parts exist
        }

        // Find the current `TextPart` where `start_time_ms` is ≤ elapsedMilliseconds
        for (index, part) in parts.enumerated().reversed() where part.start_time_ms <= elapsedMilliseconds {
            let nextStartTime = (index + 1) < parts.count ? parts[index + 1].start_time_ms : nil
            return (part.text, part.start_time_ms, nextStartTime)
        }

        return ("", 0, nil) // Default return if nothing matches
    }

    override init() {
        super.init()
        if let albumCoverImage = UIImage(named: "albumCover") {
            artwork = MPMediaItemArtwork(boundsSize: albumCoverImage.size) { size in
                return albumCoverImage
            }
        }
    }

    func setup(
            currentBook: AudioBook?,
            onSetUp: @escaping (Bool, String, TimeInterval, String, TimeInterval, [String], Int) -> Void,
            progressCallback: ((String, TimeInterval, [String], Int) -> Void)?,
            onAddBookmarkCallback: (() -> Void)?
    ) {
        if let book = currentBook, let file = book.pathToAudio() {

            self.progressCallback = nil
            self.progressCallback = progressCallback
            self.onAddBookmarkCallback = nil
            self.onAddBookmarkCallback = onAddBookmarkCallback

            self.defaultLanguage = book.language
            self.speed = book.voiceRate
            self.author = book.author
            self.title = book.title
            self.parts = book.parts
            self.elapsedSeconds = TimeInterval(book.lastPosition)
            
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: file)
                audioPlayer?.delegate = self
                audioPlayer?.enableRate = true
                audioPlayer?.prepareToPlay()
//                nprint("audioPlayer?.rate=>\(audioPlayer?.rate)")
                audioPlayer?.rate = Float(speed)
//                nprint("speed=>\(speed)")
                
            } catch {
                print("Error playing file \(file.lastPathComponent): \(error.localizedDescription)")
            }
            guard let player = audioPlayer else { return }
            let newTime = min(Double(self.elapsedSeconds), player.duration)
            player.currentTime = newTime
            totalTime = player.duration
            
            let (currentText, currentStartTime, nextStartTime) = getCurrentText(for: self.elapsedSeconds)
            
            currentFrame = currentText.components(separatedBy: .whitespacesAndNewlines)
            let wordIndex = getCurrentWordIndex(for: elapsedSeconds, words: self.currentFrame, currentStartTime: currentStartTime, nextStartTime: Int(nextStartTime ?? (currentStartTime + 30_000)))
            
            book.calculate {
                onSetUp(true,
                        book.totalTime,//player.duration.formatSecondsToHMS(),
                        player.duration,
                        book.progressTime,//.formatSecondsToHMS(),
                        player.currentTime,
                             self.currentFrame, wordIndex
                )
            }
            state = .idle
        }
        tearDownRemoteTransportControls()
        setupRemoteTransportControls()
    }
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.endTheBook()
        }
    }


    func isNotUndefined() -> Bool {
        return state != .undefined
    }
    
    private func startProgressTimer() {
        stopProgressTimer() // Ensure no duplicate timers
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                self.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        audioPlayer?.stop()
        state = .idle
        progressCallback = nil
        onAddBookmarkCallback = nil
        stopProgressTimer()
        tearDownRemoteTransportControls()
    }

    func endTheBook() {
        state = .idle
        audioPlayer?.stop()
        stopProgressTimer()
    }

    func defineElapsedTime(value: Int, updateLabel: ((String) -> Void)? = nil) {
        guard let player = audioPlayer else { return }
        elapsedSeconds = TimeInterval(value)
        let newTime = min(Double(self.elapsedSeconds), player.duration)
        player.currentTime = newTime
        updateLabel?(Double(elapsedSeconds).formatSecondsToHMS())
    }

    func playPause() {
        if state == .playing {
            state = .pause
            audioPlayer?.stop()
            stopProgressTimer()
        } else {
            do {
                try configureAudioSession()
                audioPlayer?.play()
                state = .playing
                startProgressTimer()
            } catch {
                nprint("Error configuring audio session: \(error.localizedDescription)")
            }
        }
        updateNowPlayingInfo()
    }

    func isPlaying() -> Bool {
        return state == .playing
    }

    func fastForward() {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + 30, player.duration)
        player.currentTime = newTime
        self.elapsedSeconds = player.currentTime
        print("⏩ Fast forwarded to: \(newTime.formatSecondsToHMS())")
        updateProgress()
    }

    func rewind() {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - 30, 0)
        player.currentTime = newTime
        print("⏪ Rewound to: \(newTime.formatSecondsToHMS())")
        self.elapsedSeconds = player.currentTime
        updateProgress(force:true)
    }
    
    func getProgress() -> Double {
        guard let player = audioPlayer else { return 0 }
        return player.currentTime / player.duration
    }

    func getElapsedTime() -> String {
        return audioPlayer?.currentTime.formatSecondsToHMS() ?? "00:00:00"
    }

    func getTotalDuration() -> String {
        return audioPlayer?.duration.formatSecondsToHMS() ?? "00:00:00"
    }
    
    func getCurrentBookmarkText(for elapsedSeconds: TimeInterval, currentText: String, currentStartTime: Int, nextStartTime: Int) -> String {
        // Convert start time difference to seconds
        let durationBetweenParts = TimeInterval(nextStartTime - currentStartTime) / 1000.0

        // Split text into words
        let words = currentText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Ensure words are not empty to prevent division by zero
        guard !words.isEmpty else { return "" }

        // Approximate seconds per word
        let secondsPerWord = durationBetweenParts / Double(words.count)

        // Calculate relative elapsed time within the current segment
        let relativeTimeInSegment = elapsedSeconds - (TimeInterval(currentStartTime) / 1000.0)

        // Compute the word index, ensuring it's within bounds
        let wordIndex = min(max(Int(relativeTimeInSegment / secondsPerWord), 0), words.count - 1)
        
        let startIndex = max(wordIndex - TextToSpeechPlayer.BookmarkOffcet, 0)
        let endIndex = min(startIndex + TextToSpeechPlayer.BookmarkTextLength, words.count - 1)

        return words[startIndex...endIndex].joined(separator: " ")
    }


    func generateBookmarks(book: AudioBook) {
        for i in book.bookmarks.indices {
            nprint("bookmarks: \(i)")
            if book.bookmarks[i].text.isEmpty {
                let bookmarkTimeStampSeconds = TimeInterval(book.bookmarks[i].position)
                let (currentText, currentStartTime, nextStartTime) = self.getCurrentText(for: bookmarkTimeStampSeconds)
                let title = getCurrentBookmarkText(for: bookmarkTimeStampSeconds, currentText: currentText, currentStartTime: currentStartTime, nextStartTime: nextStartTime ?? currentStartTime + 30000)
                book.bookmarks[i].text = "\(bookmarkTimeStampSeconds.formatSecondsToHMS()) | \(title)"
            }
        }
    }

    var nextPartStartTime: TimeInterval = 0
    var currentStartTime: Int = 0
    
    func getCurrentWordIndex(for elapsedSeconds: TimeInterval, words: [String], currentStartTime: Int, nextStartTime: Int) -> Int {
        // Convert start time difference to seconds
        let durationBetweenParts = TimeInterval(nextStartTime - currentStartTime) / 1000.0

        // Ensure words are not empty to prevent division by zero
        guard !words.isEmpty else { return 0 }

        // Approximate seconds per word
        let secondsPerWord = durationBetweenParts / Double(words.count)

        // Calculate relative elapsed time within the current segment
        let relativeTimeInSegment = elapsedSeconds - (TimeInterval(currentStartTime) / 1000.0)

        // Compute the word index, ensuring it's within bounds
        let wordIndex = min(max(Int(relativeTimeInSegment / secondsPerWord), 0), words.count - 1)

        return wordIndex
    }


    @MainActor func updateProgress(force: Bool = false) {
        guard let player = audioPlayer else { return }

        self.elapsedSeconds = max(self.elapsedSeconds, player.currentTime)
        
//        nprint("elapsedSeconds: \(elapsedSeconds)")
//        nprint("currentTime: \(player.currentTime)")
//        nprint("self.nextPartStartTime: \(self.nextPartStartTime)")

        if force || self.elapsedSeconds >= self.nextPartStartTime {
            let (currentText, currentStartTime, nextStartTime) = self.getCurrentText(for: self.elapsedSeconds)
            self.currentFrame = currentText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            self.currentStartTime = currentStartTime
            self.nextPartStartTime = TimeInterval(nextStartTime ?? (currentStartTime + 30_000)) / 1000

            self.currentFrame = currentText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        }
        let wordIndex = getCurrentWordIndex(for: elapsedSeconds, words: self.currentFrame, currentStartTime: currentStartTime, nextStartTime: Int(nextPartStartTime * 1000))
        
        let elapsedSecondsLocal = Double(self.elapsedSeconds) / Double(player.rate)

        
        self.progressCallback?(
            elapsedSecondsLocal.formatSecondsToHMS(),
            self.elapsedSeconds,
            self.currentFrame,
            wordIndex
        )

        self.updateProgressNowPlayingInfo(progressValue: elapsedSecondsLocal)
    }



  

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            nprint("Error setting up audio session: \(error)")
            return
        }
    }

}


