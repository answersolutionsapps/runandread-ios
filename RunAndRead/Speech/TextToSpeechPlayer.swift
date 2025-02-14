import AVFoundation
import Combine
import SwiftUI
import MediaPlayer

enum PlayerState: String, CaseIterable {
    case undefined = "Undefined"
    case idle = "Idle"
    case playing = "Playing"
    case pause = "Pause"
}

extension TextToSpeechPlayer {

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
        nowPlayingInfo[MPMediaItemPropertySkipCount] = 30
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalTime
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func updateProgressNowPlayingInfo() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
            
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = indexToElapsedSeconds()
            
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

@MainActor
class TextToSpeechPlayer: NSObject, ObservableObject, Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var words: [String] = []
    private var defaultLanguage = Locale.current
    private var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
    var speed: Float = 0.5

    @Published var currentFrame: [String] = []
    @Published private var currentWordIndex = 0
    @Published var currentWordIndexInFrame = 0
    @Published var totalTime: TimeInterval = 0
    @Published var totalTimeString: String = "00:00"// In seconds
    @Published var totalWords: Int = 0 // In seconds
    @Published var state: PlayerState = .undefined

    private var progressCallback: ((String, Int, [String], Int) -> Void)? // Callback for progress updates
    private var onAddBookmarkCallback: (() -> Void)? // Callback for progress updates

    private var author: String = ""
    private var title: String = ""
    private var artwork : MPMediaItemArtwork? = nil

    override init() {
        super.init()
        AVSpeechSynthesisVoice.speechVoices() // <--  fetch voice dependencies
        if let albumCoverImage = UIImage(named: "albumCover") {
                    artwork = MPMediaItemArtwork(boundsSize: albumCoverImage.size) { size in
                        return albumCoverImage
                    }
                }
        setupRemoteTransportControls()
    }

    func setup(
            currentBook: Book?,
            onSetUp: (Bool, String, Int, [String], Int) -> Void,
            progressCallback: ((String, Int, [String], Int) -> Void)?,
            onAddBookmarkCallback: (() -> Void)?
    ) {
        if let book = currentBook {
            
            words.removeAll()
            words = book.text.flatMap {
                        $0.components(separatedBy: .whitespacesAndNewlines)
                    }
                    .filter {
                        !$0.isEmpty
                    }

            synthesizer.delegate = nil
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.delegate = self

            self.progressCallback = nil
            self.progressCallback = progressCallback
            self.onAddBookmarkCallback = nil
            self.onAddBookmarkCallback = onAddBookmarkCallback

            self.defaultLanguage = book.language
            self.selectedVoice = book.voice
            self.speed = book.voiceRate
            self.author = book.author
            self.title = book.title

//            nprint("loadSelectedVoice().defaultLanguage=>\(defaultLanguage.identifier).")
//            nprint("loadSelectedVoice().selectedVoice=>\(selectedVoice.language); \(selectedVoice.name)")

            defineCurrentWordIndex(value: book.lastPosition)

            // Approximate seconds per word based on speech rate
            self.totalTime = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(speed)
            self.totalWords = words.count
            self.totalTimeString = totalTime.formatSecondsToHMS()
//            nprint("book.lastPosition=>\(book.lastPosition)")
//            nprint("words.count=>\(words.count)")
//            nprint("book.lastPosition=>\(currentWordIndex)")

            onSetUp(true, indexToElapsedSeconds().formatSecondsToHMS(), currentWordIndex, currentFrame, currentWordIndexInFrame)
            state = .idle
        } else {
            nprint("setup.error currentBook is not defined.")
            onSetUp(false, indexToElapsedSeconds().formatSecondsToHMS(), currentWordIndex, currentFrame, currentWordIndexInFrame)
        }
    }
    
    func isNotUndefined() -> Bool {
        return state != .undefined && !words.isEmpty
    }

    func stop() {
        state = .idle
        words.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        currentFrame.removeAll()
        currentWordIndexInFrame = 0
        synthesizer.delegate = nil
        progressCallback = nil
        onAddBookmarkCallback = nil
    }

    func onPrepareForPlayFromNewPosition() {
        state = .idle
        synthesizer.stopSpeaking(at: .immediate)
        currentFrame.removeAll()
        currentWordIndexInFrame = 0
    }

    func playPause() {
        if state == .playing {
            synthesizer.pauseSpeaking(at: .immediate)
            state = .pause
            
        } else {
            do {
                try configureAudioSession()
                if state == .pause || synthesizer.isPaused {
                    synthesizer.continueSpeaking()
                } else {
                    let utterance = createUtterance(from: currentWordIndex)
                    synthesizer.speak(utterance)
                }
                state = .playing
            } catch {
                nprint("Error configuring audio session: \(error.localizedDescription)")
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
        synthesizer.stopSpeaking(at: .immediate)
        currentWordIndex = min(currentWordIndex + 60, words.count - 1) //about 30 secunds
        updateProgress()
        state = .idle
        playPause()
    }

    func rewind() {
        synthesizer.stopSpeaking(at: .immediate)
        currentWordIndex = max(currentWordIndex - 60, 0)//about 30 secunds
        updateProgress()
        state = .idle
        playPause()
    }

    private func createUtterance(from wordIndex: Int) -> AVSpeechUtterance {
        let remainingWords = Array(words[wordIndex...])
        currentFrame = Array(remainingWords.prefix(100))
        currentWordIndexInFrame = 0
        let utterance = AVSpeechUtterance(string: currentFrame.joined(separator: " "))
        utterance.rate = speed.speedToPlaybackRate()
        utterance.volume = 1.0
        utterance.voice = selectedVoice
        return utterance
    }


    func textForBookmark(bookmark: Bookmark, book: Book) -> String? {
        nprint("words: \(words.count)")
        if words.isEmpty {
            return nil
        }
        let startIndex = max(bookmark.position - 2, 0)
        let endIndex = min(startIndex + 10, words.count - 1)
        nprint("startIndex: \(startIndex)")
        nprint("endIndex: \(endIndex)")
        if endIndex <= words.count && words.count > 0 {
            return words[startIndex...endIndex].joined(separator: " ")
        } else {
            return nil
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

extension TextToSpeechPlayer: @preconcurrency AVSpeechSynthesizerDelegate {

    private func printInfo(place: Int) {
//        nprint("\(place). totallWordIndex => \(currentWordIndex) of \(words.count); frameIndex=> \(currentWordIndexInFrame) of \(currentFrame.count)")
//        if currentWordIndex < words.count - 1 && currentWordIndexInFrame < currentFrame.count - 1 {
//            nprint("\(place). \(state). totallWord => \(words[currentWordIndex]); frameWord=> \(currentFrame[currentWordIndexInFrame])")
//        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if currentWordIndex < words.count - 1 {
            currentWordIndex += 1
            state = .idle
            playPause()
            updateProgress()
            printInfo(place: 12)
        } else {
            state = .idle
            printInfo(place: 13)
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        if currentWordIndex < words.count - 1 {
            if currentWordIndexInFrame < currentFrame.count - 1 {
                currentWordIndex += 1
                currentWordIndexInFrame += 1
                updateProgress()
                printInfo(place: 21)
            }
        } else {
            printInfo(place: 23)
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        state = .pause
        updateNowPlayingInfo()
    }
}
