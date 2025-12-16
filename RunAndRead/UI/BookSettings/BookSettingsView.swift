//
//  BookSettingsView.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import SwiftUI
import AVFoundation


struct BookSettingsView: View {
    @StateObject var viewModel: BookSettingsViewModel
    @State private var pinCodeText: String = ""
    @FocusState private var textIsFocused: Bool

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Title")
                        .font(.headline)
                    
                    HStack {
                        TextField("Enter title", text: $viewModel.title)
                            .textFieldStyle(DefaultTextFieldStyle())
                            .font(.title2)
                            .padding(.bottom, 10)
                        
                        if !viewModel.title.isEmpty {
                            Button(action: {
                                viewModel.title = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }.padding(.trailing, 8)
                        }
                    }
                    
                    Text("Author")
                        .font(.headline)
                    HStack {
                        TextField("Enter author", text: $viewModel.author)
                            .textFieldStyle(DefaultTextFieldStyle())
                            .font(.title2)
                        
                        if !viewModel.author.isEmpty {
                            Button(action: {
                                viewModel.author = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }.padding(.trailing, 8)
                        }
                    }
                    if (!viewModel.isAudioBook()) {
                        Divider()
                        Text("Language")
                            .font(.headline)
                        Button(action: {
                            viewModel.onShowLanguagePicker()
                        }) {
                            Text(viewModel.languageString())
                                .font(.body)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    } else {
                        Divider()
                        Text("Language")
                            .font(.headline)
                        Text(viewModel.audioBookLanguage())
                    }
                    Divider()
                    HStack {
                        Text("Naration Voice")
                            .font(.headline)
                        ImageButtonView(
                            imageName: "play.circle.fill",
                            imageColor: .accentColor,
                            action: {
                                viewModel.onPlayPauseText()
                            }
                        )
                    }
                    VStack(alignment: .center) {
                        SpeechSpeedSelector(defaultSpeed: viewModel.getDefaultVoiceRate()) { newSpeed in
                            print("Selected speed: \(newSpeed)")
                            
                            viewModel.onRateChanges(value: newSpeed)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if (!viewModel.isAudioBook()) {
                        Button(action: {
                            viewModel.onShowVoicePicker()
                        }, label: {
                            Text(String(format: "\(viewModel.selectedVoice.name) (%.2f)", viewModel.defaultVoiceRate.playbackRateToSpeed()))
                                .font(.body)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        })
                        .sheet(isPresented: $viewModel.showVoicePicker) {
                            VoicePicker(viewModel: viewModel)
                        }
                    } else {
                        Text("Voice Name:\n\(viewModel.audioBookVoice())")
                            .font(.headline)
                        Text("Model Name:\n\(viewModel.audioBookModel())")
                            .font(.headline)
                    }
                    Divider()
                    if (!viewModel.isAudioBook()) {
                    VStack {
                        Text("Pick First Page to Read")
                            .font(.headline)
                        HorizontalPageListView(selectedPage: $viewModel.selectedPart, totalPages: viewModel.contextText.count) { newPageIndex in
                            viewModel.onPageChanged(newPageIndex: newPageIndex)
                        }
                        Text("Start Reading From Page: \(viewModel.selectedPart + 1)")
                        Divider()
                        TextEditor(text: $viewModel.textPreview)
                            .font(.body)
                            .frame(height: 350)  // Adjust frame as needed
                            .disabled(false)
                            .focused($textIsFocused)
                            .scrollDisabled(false)
                        
                        Spacer()
                    }
                    .toolbar {
                        // Keyboard toolbar with Cancel button
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()  // Push the button to the right
                            Button("Cancel") {
                                // Dismiss the keyboard by unfocusing
                                textIsFocused = false
                            }
                        }
                    }
                    } else {
                        Text("Book source:\n\(viewModel.audioBookSource())")
                            .font(.headline)
                        Spacer()
                            .frame(height: 400)
                    }
                    Divider()
                    if viewModel.isDeleteVisible() {
                        VStack(alignment: .center, spacing: UIConfig.normalSpace) {
                            Button(action: {
                                viewModel.isPresentingConfirm.toggle()
                            }, label: {
                                LongButtonView(title: "Delete Book", backgroundColor: .red).padding(.top, UIConfig.smallSpace)
                            })
                            Text("Delete this book from the library")
                                .font(.caption)
                                .fontWeight(.light)
                                .foregroundColor(.red)
                        }
                                .font(.subheadline).frame(maxWidth: .infinity, maxHeight: 150)
                    }
                }
                        .padding()
            }
                    .textFieldAlert(
                            isPresented: $viewModel.isPresentingConfirm,
                            title: "Are you sure?",
                            message: "You cannot undo this action!",
                            text: "",
                            placeholder: "Input word delete",
                            action: { newText in
                                pinCodeText = newText ?? ""
                                if pinCodeText.lowercased() == "delete" {
                                    viewModel.onDeleteBook()
                                }
                            }
                    )
                    .onAppear {
                        viewModel.loadBookData(isPreview: isPreview)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            HStack {
                                Spacer()
                                Text("Book Settings").font(.title2)
                                Spacer()
                            }
                            .tint(.background)
                        }
                    }
                    .navigationBarBackButtonHidden(true)
                    .navigationBarItems(
                            leading:
                            Button(action: {
                                viewModel.onCancel()
                            }, label: {
                                Text("Cancel").font(UIConfig.buttonFont)
                            }),
                            trailing: Button(action: {
                                viewModel.saveBook()

                            }, label: {
                                Text("Save").font(UIConfig.buttonFont)
                            }).disabled(viewModel.invalidBook())
                    )
                    .sheet(isPresented: $viewModel.showLanguagePicker) {
                        LanguagePicker(viewModel: viewModel)
                    }
        }
    }
}

#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
        BookSettingsView(
                viewModel: BookSettingsViewModel(
                        path: path.projectedValue,
                        bookManager: BookManager(),
                        simplePlayer: SimpleTTSPlayer())).accentColor(Color("AccentColor")).preferredColorScheme(.dark)
    }
}
