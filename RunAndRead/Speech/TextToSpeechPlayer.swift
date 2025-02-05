import AVFoundation
import Combine
import SwiftUI
import MediaPlayer

enum PlayerState: String, CaseIterable {
    case idle = "Idle"
    case playing = "Playing"
    case pause = "Pause"
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
    @Published var totalTimeString: String = "00:00"// In seconds
    @Published var totalWords: Int = 0 // In seconds
    @Published var state: PlayerState = .idle

    private var progressCallback: ((String, Int, [String], Int) -> Void)? // Callback for progress updates
    private var onAddBookmarkCallback: (() -> Void)? // Callback for progress updates

    private var title: String = ""


    override init() {
        super.init()
        AVSpeechSynthesisVoice.speechVoices() // <--  fetch voice dependencies
        setupRemoteTransportControls()
    }

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
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Run & Read"

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func setup(
            currentBook: Book?,
            onSetUp: (Bool, String, Int, [String], Int) -> Void,
            progressCallback: ((String, Int, [String], Int) -> Void)?,
            onAddBookmarkCallback: (() -> Void)?
    ) {
        if let book = currentBook {
            state = .idle
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
            self.title = book.title

            nprint("loadSelectedVoice().defaultLanguage=>\(defaultLanguage.identifier).")
            nprint("loadSelectedVoice().selectedVoice=>\(selectedVoice.language); \(selectedVoice.name)")

            defineCurrentWordIndex(value: book.lastPosition)

            // Approximate seconds per word based on speech rate
            let totalTime = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(speed)
            self.totalWords = words.count
            self.totalTimeString = totalTime.formatSecondsToHMS()
            nprint("book.lastPosition=>\(book.lastPosition)")
            nprint("words.count=>\(words.count)")
            nprint("book.lastPosition=>\(currentWordIndex)")

            onSetUp(true, indexToElapsedSeconds(), currentWordIndex, currentFrame, currentWordIndexInFrame)
//            self.progressCallback!(indexToElapsedSeconds(), currentWordIndex, currentFrame, currentWordIndexInFrame)
        } else {
            nprint("setup.error currentBook is not defined.")
            onSetUp(false, indexToElapsedSeconds(), currentWordIndex, currentFrame, currentWordIndexInFrame)
        }
    }

    func stop() {
        state = .idle
        words.removeAll()
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
        progressCallback = nil
        onAddBookmarkCallback = nil
    }

    func pause() {
        state = .idle
        synthesizer.pauseSpeaking(at: .immediate)
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
            updateNowPlayingInfo()
        }
    }

    func isPlaying() -> Bool {
        return state == .playing
    }

    func defineCurrentWordIndex(value: Int, updateLabel: ((String) -> Void)? = nil) {
        currentWordIndex = min(value, words.count - 1)
        currentWordIndex = max(currentWordIndex, 0)
        updateLabel?(indexToElapsedSeconds())
    }

    func fastForward() {
        synthesizer.stopSpeaking(at: .immediate)
        currentWordIndex = min(currentWordIndex + 5, words.count - 1)
        updateProgress()
        state = .idle
        playPause()
    }

    func rewind() {
        synthesizer.stopSpeaking(at: .immediate)
        currentWordIndex = max(currentWordIndex - 5, 0)
        updateProgress()
        state = .idle
        playPause()
    }

    private func createUtterance(from wordIndex: Int) -> AVSpeechUtterance {
        let remainingWords = Array(words[wordIndex...])
        currentFrame = Array(remainingWords.prefix(100))
        currentWordIndexInFrame = 0
        let utterance = AVSpeechUtterance(string: currentFrame.joined(separator: " "))
        utterance.rate = speed.speedToplaybackRate()
        utterance.volume = 1.0
        utterance.voice = selectedVoice
        return utterance
    }


    func textForBookmark(bookmark: Bookmark, book: Book) -> String? {
        if words.isEmpty {
            return nil
        }
        let startIndex = max(bookmark.position - 2, 0)
        let endIndex = min(startIndex + 10, words.count - 1)

        if endIndex <= words.count && words.count > 0 {
            return words[startIndex...endIndex].joined(separator: " ")
        } else {
            return nil
        }
    }

    private func indexToElapsedSeconds() -> String {
        let elapsedSeconds = (Double(words.prefix(currentWordIndex).joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.speed)
        return elapsedSeconds.formatSecondsToHMS()
    }

    func updateProgress() {
        if currentWordIndex < words.count && currentWordIndex > -1 {
            progressCallback?(indexToElapsedSeconds(), currentWordIndex, currentFrame, currentWordIndexInFrame)
        }
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
        nprint("\(place). totallWordIndex => \(currentWordIndex) of \(words.count); frameIndex=> \(currentWordIndexInFrame) of \(currentFrame.count)")
        if currentWordIndex < words.count - 1 && currentWordIndexInFrame < currentFrame.count - 1 {
            nprint("\(place). \(state). totallWord => \(words[currentWordIndex]); frameWord=> \(currentFrame[currentWordIndexInFrame])")
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
//        printInfo(place: 10)
        if state != .idle {
            state = .idle
            if currentWordIndex < words.count - 1 {
                if currentWordIndexInFrame < currentFrame.count - 1 {
                    currentWordIndex += 1
                    currentWordIndexInFrame += 1
                    updateProgress()
                    playPause()
                    printInfo(place: 11)
                } else {
                    currentWordIndex += 1
                    let utterance = createUtterance(from: currentWordIndex)
                    synthesizer.speak(utterance)
                    updateProgress()
                    printInfo(place: 12)
                }
            } else {
                playPause()
                printInfo(place: 13)
            }
        } else if currentWordIndex < words.count - 1 && currentWordIndexInFrame >= currentFrame.count - 1 {
            currentWordIndex += 1
            let utterance = createUtterance(from: currentWordIndex)
            synthesizer.speak(utterance)
            updateProgress()
            printInfo(place: 14)
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
//        printInfo(place: 20)
        if currentWordIndex < words.count - 1 {
            if currentWordIndexInFrame < currentFrame.count - 1 {
                currentWordIndex += 1
                currentWordIndexInFrame += 1
                updateProgress()
                printInfo(place: 21)
            } else {
                currentWordIndex += 1
                let utterance = createUtterance(from: currentWordIndex)
                synthesizer.speak(utterance)
                updateProgress()
                printInfo(place: 22)
            }
        } else {
            playPause()
            printInfo(place: 23)
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        state = .pause
    }
}
