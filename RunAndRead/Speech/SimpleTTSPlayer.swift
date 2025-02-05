//
//  SimpleTTSPlayer.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/5/25.
//

import AVFoundation

class SimpleTTSPlayer: NSObject, ObservableObject {
    var speechSynthesizer = AVSpeechSynthesizer()
    private var currentLocale: Locale? = nil
    private let audioEngine = AVAudioEngine()
    private var completionHandler: (Result<String, Error>) -> Void = { _ in
    }

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

        if speechSynthesizer.isSpeaking {
            stopTextToSpeech()
        } else {
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
