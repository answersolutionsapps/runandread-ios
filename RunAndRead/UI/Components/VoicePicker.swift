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
    @State var oldVoice: AVSpeechSynthesisVoice? = nil

    var availableVoices: [AVSpeechSynthesisVoice] {
        //print("selectedLanguage=\(viewModel.selectedLanguage.identifier)")
        return AVSpeechSynthesisVoice.speechVoices().filter {
            //print("voice:\($0.name) voice_lang=\($0.identifier); lang=\($0.language)")
            if let voice_lang = $0.language.split(separator: "-").first {
                if viewModel.selectedLanguage.identifier.hasPrefix(voice_lang) {
                    print("voice:\($0.name) voice_prefix=\(voice_lang); lang=\($0.language); quality=\($0.quality)")
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }.sorted { v1, v2 in
            func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
                if voice.quality == .premium {
                    return 1
                } else if voice.quality == .enhanced {
                    return 2
                } else {
                    return 3
                }
            }
            return rank(v1) < rank(v2)
        }
    }
    
    func voiceString(voice: AVSpeechSynthesisVoice) -> String {
        let regionCode = voice.language
        return "\(voice.name) (\(regionCode))"
    }

    var body: some View {
        NavigationView {
            VStack {
                List(availableVoices, id: \.identifier) { voice in
                        HStack {
                            Text(voiceString(voice: voice))
                                .foregroundColor(voice == viewModel.selectedVoice ? .surface: .accent)
                                .font(.title2)
                            Spacer()
                            ImageButtonView(
                                    imageName: "play.circle.fill",
                                    imageColor: voice == viewModel.selectedVoice ? .surface: .accent,
                                    action: {
                                        viewModel.onSelectVoice(voice: voice)
                                        viewModel.onPlayPauseText2()
                                    }
                            )
                        }
                        .listRowSpacing(0)
                        .listRowInsets(EdgeInsets(top:1, leading:16,bottom:1,trailing:8))
                        .listRowSeparator(.hidden)
                        .padding(12)
                        .background(voice == viewModel.selectedVoice ? .accent: .surface)
                }
                .listStyle(.plain)
            }
            .onAppear{
                self.oldVoice = viewModel.selectedVoice
            }
            .navigationBarTitle("Select Voice", displayMode: .large)
            .navigationBarItems(leading: Button("Cancel") {
                if let v = self.oldVoice {
                    viewModel.onSelectVoice(voice: v)
                    presentationMode.wrappedValue.dismiss()
                } else {
//                    error
                }
            }.font(UIConfig.buttonFont)
                                ,trailing: Button("Save") {
                presentationMode.wrappedValue.dismiss()
            }.font(UIConfig.buttonFont)
                .disabled(oldVoice == viewModel.selectedVoice)
            
            )
        }.accentColor(Color("AccentColor"))
    }
}


#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
        VoicePicker(
                viewModel: BookSettingsViewModel(
                        path: path.projectedValue,
                        bookManager: BookManager(),
                        simplePlayer: SimpleTTSPlayer()))
    }
}
