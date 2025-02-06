//
//  VoicePicker.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import SwiftUI
import AVFoundation

struct VoicePicker: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var viewModel: BookSettingsViewModel
//    var selectedLanguage: Locale

    var availableVoices: [AVSpeechSynthesisVoice] {
        print("selectedLanguage=\(viewModel.selectedLanguage.identifier)")
        return AVSpeechSynthesisVoice.speechVoices().filter {
            print("voice:\($0.name) voice_lang=\($0.identifier); lang=\($0.language)")
            if let voice_lang = $0.language.split(separator: "-").first {
                if viewModel.selectedLanguage.identifier.hasPrefix(voice_lang) {
                    print("voice:\($0.name) voice_prefix=\(voice_lang); lang=\($0.language)")
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }.sorted { v1, v2 in
            //sort, to see the english close to the top
            v1.name < v2.name
        }
    }
    
    func voiceString(voice: AVSpeechSynthesisVoice) -> String {
        let regionCode = voice.language
        return "\(voice.name) (\(regionCode))"
    }

    var body: some View {
        NavigationView {
            VStack {
//                Text("A voice that assistant will speak to you").font(.title)
                Text("Assistant Voice").font(.title2)
                    .multilineTextAlignment(.leading)
                List(availableVoices, id: \.identifier) { voice in
                    Button(action: {
                        viewModel.onSelectVoice(voice: voice)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(voiceString(voice: voice)).font(.title2)
                            Spacer()
                            if voice == viewModel.selectedVoice {
                                Image(systemName: "checkmark")
                            }
                        }
                    }.padding()
                }.listStyle(.plain)
            }
//            .navigationBarTitle("Assistant Voice", displayMode: .large)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
