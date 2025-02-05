//
//  AudioSessionManager.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/2/25.
//

import Foundation
import AVFoundation

enum AudioTarget: String, CaseIterable {
    case speaker = "Speaker"
    case headphones = "Headphones"
}

class AudioSessionManager {
    static func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
        }
    }

    static func chooseAudioSource(source: AudioTarget) {
        nprint("chooseAudioSource(source)=>\(source)")
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions

        switch source {
        case .headphones:
            options = [.allowBluetooth, .allowBluetoothA2DP]
        default:
            options = [.defaultToSpeaker]
        }
        do {
            print("chooseAudioSource(1)=>")
            try session.setActive(false)
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            if source == .speaker {
                try session.overrideOutputAudioPort(.speaker)
            }
            print("chooseAudioSource(2)=>")
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("chooseAudioSource(3)=>")
        } catch {
            print("chooseAudioSource(4)=>")
            print("Error choosing audio source: \(error)")
        }
    }

    static func disableAVSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't disable.")
        }
    }
}
