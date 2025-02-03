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
    private var currentFrame: [String] = []
    private var defaultLanguage = Locale.current
    private var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
    private var speed: Float = 0.5
    
    @Published var currentWordIndex = 0
    @Published var currentWordIndexInFrame = 0
    @Published var elapsedTime: Double = 0.0 // In seconds
    @Published var totalTime: Double = 0.0 // In seconds
    @Published var state: PlayerState = .idle

    private var progressCallback: ((Double, Int, [String], Int) -> Void)? // Callback for progress updates
    
    private var title: String = ""
    
    func loadSelectedVoice(currentBook: Book?) {
        if let language = currentBook?.language {
            defaultLanguage = language
        } else {
            defaultLanguage = Locale.current
        }
        if let voice = currentBook?.voice {
            selectedVoice = voice
        } else {
            selectedVoice = AVSpeechSynthesisVoice(language: defaultLanguage.identifier) ?? AVSpeechSynthesisVoice()
        }
        if let voiceRate = currentBook?.voiceRate {
            speed = voiceRate
        } else {
            speed = 1.0
        }
        
        if let t = currentBook?.title {
            title = t
        } else {
            title = "Unknown"
        }
        
        
        nprint("loadSelectedVoice().defaultLanguage=>\(defaultLanguage.identifier).")
        nprint("loadSelectedVoice().selectedVoice=>\(selectedVoice.language); \(selectedVoice.name)")
        
        // Approximate seconds per word based on speech rate
        totalTime = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(speed)
    }
    
    
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
            //TODO: implement
//            nprint("currentWordIndex: \(self?.currentWordIndex)")
            return .success
        }
    }
    
    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Run & Read"

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func setup(text: [String], progressCallback: ((Double, Int, [String], Int) -> Void)?) {
        state = .idle
        words.removeAll()
        words = text.flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
                             .filter { !$0.isEmpty }
//        words = text.components(separatedBy: .whitespacesAndNewlines)
//            .filter { !$0.isEmpty }
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.delegate = self
        
        // Approximate seconds per word based on speech rate
        totalTime = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(speed)
        
        self.progressCallback = nil
        self.progressCallback = progressCallback
        
//        nprint(text.substringUntilFifthSpace())
    }
    
    func stop() {
        state = .idle
        words.removeAll()
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
        self.progressCallback = nil
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
    
    func updateProgress() {
        elapsedTime = (Double(words[...currentWordIndex].joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(speed)
        
        progressCallback?(elapsedTime, currentWordIndex, currentFrame, currentWordIndexInFrame)
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
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if state != .idle {
            state = .idle
            if currentWordIndex < words.count - 1 {
                currentWordIndex += 1
                currentWordIndexInFrame += 1
                updateProgress()
                playPause()
            } else {
                
            }
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        
        if currentWordIndex < words.count - 1 {
            currentWordIndex += 1
            currentWordIndexInFrame += 1
            updateProgress()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        state = .pause
    }
}



class TextToSpeechSimplePlayer: NSObject, ObservableObject {
    var speechSynthesizer = AVSpeechSynthesizer()
    private var currentLocale: Locale? = nil
    private let audioEngine = AVAudioEngine()
    private var completionHandler: (Result<String, Error>) -> Void = {_ in }
    
    @Published var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
    @Published var voiceRate: Float = 0.5
    @Published var playingMessage = ""
    @Published var isRecording = false
    
    override init() {
        super.init()
        AVSpeechSynthesisVoice.speechVoices() // <--  fetch voice dependencies
    }


    
    func updateAudioTarget(selectedAudioTarget: AudioTarget) {
        // Add logic here to switch audio target
        switch selectedAudioTarget {
        case .speaker:
            speechSynthesizer.pauseSpeaking(at: .immediate)
            AudioSessionManager.chooseAudioSource(source: .speaker)
        case .headphones:
            speechSynthesizer.pauseSpeaking(at: .immediate)
            AudioSessionManager.chooseAudioSource(source: .headphones)
        }
    }
    
    func stopAndPlayMessage(message: String) {

       let utterance = AVSpeechUtterance(string: message)
       utterance.voice = selectedVoice
       utterance.rate = voiceRate
        speechSynthesizer.stopSpeaking(at: .immediate)
        do {
            try configureAudioSession(forPlayback: true)
        } catch {
            print("Error configuring audio session1: \(error.localizedDescription)")
        }
        speechSynthesizer.speak(utterance)
        playingMessage = message
    }
    
    func playNewMessage(message: String) {

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = selectedVoice
        utterance.rate = voiceRate
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        do {
            try configureAudioSession(forPlayback: true)
        } catch {
            print("Error configuring audio session1: \(error.localizedDescription)")
        }
        speechSynthesizer.speak(utterance)
        if speechSynthesizer.isPaused {
            nprint("playNewMessage(4)")
            speechSynthesizer.continueSpeaking()
        }
        playingMessage = message
    }
    
    func playStopMessage(message: String) {
        if playingMessage == message {
            if speechSynthesizer.isPaused {
                do {
                    try configureAudioSession(forPlayback: true)
                } catch {
                    print("Error configuring audio session1: \(error.localizedDescription)")
                }
                
                speechSynthesizer.continueSpeaking()
            } else if speechSynthesizer.isSpeaking {
                speechSynthesizer.pauseSpeaking(at: .word)
            } else {
                do {
                    try configureAudioSession(forPlayback: true)
                } catch {
                    print("Error configuring audio session2: \(error.localizedDescription)")
                }
                let utterance = AVSpeechUtterance(string: message)
                utterance.voice = selectedVoice
                utterance.rate = voiceRate
                speechSynthesizer.speak(utterance)
            }
        } else {
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = selectedVoice
            utterance.rate = voiceRate
            speechSynthesizer.stopSpeaking(at: .immediate)
            do {
                try configureAudioSession(forPlayback: true)
            } catch {
                print("Error configuring audio session3: \(error.localizedDescription)")
            }
            speechSynthesizer.speak(utterance)
            if speechSynthesizer.isPaused {
                speechSynthesizer.continueSpeaking()
            }
            playingMessage = message
        }
    }

    func startTextToSpeech(text: String, voice: AVSpeechSynthesisVoice, rate: Float) {

        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = voice
        speechUtterance.rate = rate

        do {
            speechSynthesizer.stopSpeaking(at: .immediate)
            try configureAudioSession(forPlayback: true)
            speechSynthesizer.speak(speechUtterance)
        } catch {
            print("Error configuring audio session: \(error.localizedDescription)")
        }
    }

    func stopTextToSpeech() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }



    private func configureAudioSession(forPlayback: Bool) throws {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(forPlayback ? .playback : .record, mode: forPlayback ? .default : .measurement, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error setting up audio session: \(error)")
            return
        }
    }
}
