//
//  RunAnywhereVoicePicker.swift
//  RunAndRead
//
//  Voice picker for RunAnywhere AI TTS models
//

import SwiftUI
import RunAnywhere

struct RunAnywhereVoicePicker: View {
    @ObservedObject var viewModel: BookSettingsViewModel
    @Environment(\.dismiss) var dismiss

    // Available TTS voices
    private let availableVoices: [(id: String, name: String)] = [
        ("vits-piper-en_US-lessac-medium", "Piper TTS (US English - Medium)"),
        ("vits-piper-en_GB-alba-medium", "Piper TTS (British English)")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(availableVoices, id: \.id) { voice in
                    Button(action: {
                        viewModel.onSelectRunAnywhereVoice(voiceId: voice.id, voiceName: voice.name)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(voice.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Text(voice.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if viewModel.selectedRunAnywhereVoiceId == voice.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
