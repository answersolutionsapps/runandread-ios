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


//struct NewBookDialogView2: View {
//    @EnvironmentObject var bookManager: BookManager
//    @EnvironmentObject var simplePlayer: TextToSpeechSimplePlayer
//    @Binding var path: NavigationPath
//    @State private var defaultLanguage = Locale.current
//    @State private var selectedLanguage = Locale.current
//    
//    @State private var showLanguagePicker = false
//    
//    @State private var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
//    @State private var showVoicePicker = false
//    
//    @State private var defaultVoiceRate: Float = -1
//    @State private var selectedPart: Int = 0
//    
//    @State private var title: String = ""
//    @State private var author: String = ""
//    @State private var textpreview: String = "..."
//    @State private var contextText: [String] = []
//    
//    @State private var isPresentingConfirm: Bool = false
//    
//    private func languageString() -> String {
//        return defaultLanguage.localizedString(forLanguageCode: defaultLanguage.identifier) ?? "Unknown"
//    }
//    
//    private func currentPart(parts: [String]) -> String {
//        if parts.isEmpty {return ""}
//        let safeIndex = min(selectedPart, contextText.count)
//        return parts[safeIndex]
//    }
//    
//    private func loadSelectedVoice() {
//        if let language = bookManager.currentBook?.language {
//            defaultLanguage = language
//        } else {
//            defaultLanguage = Locale.current
//        }
//        if let voice = bookManager.currentBook?.voice {
//            selectedVoice = voice
//        } else {
//            selectedVoice = AVSpeechSynthesisVoice(language: defaultLanguage.identifier) ?? AVSpeechSynthesisVoice()
//        }
//        if let voiceRate = bookManager.currentBook?.voiceRate {
//            defaultVoiceRate = voiceRate.speedToplaybackRate()
//            nprint("loadSelectedVoice().voiceRate=>\(voiceRate).")
//        } else {
//            defaultVoiceRate = 0.5
//        }
//        selectedLanguage = defaultLanguage
//        
//        nprint("loadSelectedVoice().defaultLanguage=>\(defaultLanguage.identifier).")
//        nprint("loadSelectedVoice().selectedVoice=>\(selectedVoice.language); \(selectedVoice.name)")
//        nprint("loadSelectedVoice().defaultVoiceRate=>\(defaultVoiceRate).")
//        nprint("loadSelectedVoice().defaultVoiceRate=>\(defaultVoiceRate.playbackRateToSpeed()).")
//    }
//    
//    var body: some View {
//        ZStack {
//            Group { // sticky header
//            }
//            ScrollView(.vertical, showsIndicators: false) {
//                VStack(alignment: .leading, spacing: 16) {
//                    Group{
//                        Text("Title")
//                            .font(.headline)
//                        TextField("Enter title", text: $title)
//                            .textFieldStyle(DefaultTextFieldStyle())
//                            .font(.title2)
//                            .padding(.bottom, 10)
//                        
//                        Text("Author")
//                            .font(.headline)
//                        TextField("Enter author", text: $author)
//                            .textFieldStyle(DefaultTextFieldStyle())
//                            .font(.title2)
//                    }
//                    Divider()
//                    Group {
//                        Text("Language")
//                            .font(.headline)
//                        Button(action: {
//                            showLanguagePicker = true
//                        }) {
//                            Text(languageString())
//                                .font(.body)
//                                .padding()
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 5)
//                                        .stroke(Color.gray, lineWidth: 1) // 1 pixel border
//                                )
//                        }
//                        Divider()
//                        HStack {
//                            Text("Naration Voice")
//                                .font(.headline)
//                            ImageButtonView(
//                                imageName: "play.circle.fill",
//                                imageColor: .accentColor,
//                                action: {
//                                    let text = textpreview.substringUntilFifthSpace()
//                                    simplePlayer.startTextToSpeech(text: text, voice: selectedVoice, rate: defaultVoiceRate)
//                                }
//                            )
//                        }
//                        
//                        VStack(alignment: .center) {
//                            if defaultVoiceRate > 0 {//TODO: Create a ViewModel to manage the state
//                                SpeechSpeedSelector(defaultSpeed: defaultVoiceRate.playbackRateToSpeed()) { newSpeed in
//                                    print("Selected speed: \(newSpeed)")
//                                    defaultVoiceRate = newSpeed.speedToplaybackRate()
//                                }
//                            }
//                        }.frame(maxWidth: .infinity)
//                        Button(action: {
//                            showVoicePicker = true
//                        }, label: {
//                            
//                            Text(String(format: "\(selectedVoice.name) (%.2f)", defaultVoiceRate.playbackRateToSpeed()))
//                                .font(.body)
//                                .padding()
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 5)
//                                        .stroke(Color.gray, lineWidth: 1) // 1 pixel border
//                                )
//                        })
//                        .sheet(isPresented: $showVoicePicker) {
//                            VoicePicker(selectedVoice: $selectedVoice, selectedLanguage: defaultLanguage)
//                        }
//                    }
//                    Divider()
//                    VStack{
//                            Text("Text Preview")
//                                .font(.headline)
//                            HorizontalPageListView(selectedPage: $selectedPart, totalPages: contextText.count) { newPageIndex in
//                                if newPageIndex < contextText.count {
//                                    textpreview = contextText[newPageIndex]
//                                }
//                                
//                            }
//                        Text("Read from page: \(selectedPart + 1)")
//                        Divider()
//                        Text(textpreview)
//                            .font(.body)
//                        Spacer()
//                    }
//                    .frame(maxWidth: .infinity, minHeight: 450)
//                    Divider()
//                    if !isPresentingConfirm && bookManager.currentBook != nil {
//                            
//                        VStack(alignment: .center, spacing: UIConfig.normalSpace) {
//                            Button(action: {
//                                isPresentingConfirm.toggle()
//                            }, label: {
//                                LongButtonView(title: "Delete Book", backgroundColor: .red).padding(.top, UIConfig.smallSpace)
//                            })
//                            Text("Delete this book from the library").font(.caption).fontWeight(.light).foregroundColor(.red)
//                        }.font(.subheadline).frame(maxWidth: .infinity, maxHeight: 150)
//                    }
//                    Spacer()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
//                .padding()
//            }
//            if bookManager.inProgress {
//                CustomActivityIndicator()
//            }
//        }
//        .textFieldAlert(
//                    isPresented: $isPresentingConfirm,
//                    title: "Are you sure?",
//                    message: "You cannot undo this action!",
//                    text: "",
//                    placeholder: "Input word delete",
//                    action: { newText in
//                        pinCodeText = newText ?? ""
//                        if pinCodeText.lowercased() == "delete", let book = bookManager.currentBook {
//                            bookManager.deleteBookFromLibrary(book: book) { result in
//                                switch result {
//                                case .success:
//                                    print("✅ Book deleted successfully.")
//                                        // Remove the book from the UI list
//                                        bookManager.library.removeAll { $0.id == book.id }
//                                        bookManager.deleteCurrentBook {
//                                            path.removeLast(path.count)
//                                            path.append(AppScreen.home)
//                                        }
//                                case .failure(let error):
//                                    print("❌ Failed to delete book: \(error.localizedDescription)")
//                                }
//                            }
//                            
//                            
//                        }
//                    }
//                )
//        .sheet(isPresented: $showLanguagePicker) {
//            LanguagePicker(selectedLanguage: $selectedLanguage)
//        }
//        .onChange(of: selectedLanguage) { newLocale in
//            if defaultLanguage != newLocale {
//                defaultLanguage = newLocale
//                selectedVoice = AVSpeechSynthesisVoice(language: newLocale.identifier) ?? AVSpeechSynthesisVoice()
//            }
//        }
//        .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .principal) {
//                    HStack {
//                        Spacer()
//                        Text("New Book").font(.title2)
//                        Spacer()
//                    }
//                    .tint(UIConfig.backgroundColor)
//                }
//            }
//            .onAppear {
//                if !isPreview {
//                    if let book = bookManager.currentBook {
//                        textpreview = currentPart(parts: book.text)//.first ?? ""
//                        contextText = book.text
//                        title = book.title
//                        author = book.author
//                    } else {
//                        author = bookManager.authorData
//                        title = bookManager.titleData
//                        textpreview = currentPart(parts: bookManager.plainTextData)//.first ?? "No Context here!"
//                        contextText = bookManager.plainTextData
//                    }
//                    loadSelectedVoice()
//                } else {
//                    contextText = ["Each button is styled to be a square with a number inside, and we change the button color to blue when it's selected.", "This is used to calculate which page is the leftmost visible one by tracking the offset of the scroll view. The function calculateFirstVisibleItem calculates which page is visible based on the scroll position.", "", "", "", "", ""]
//                }
//            }
//            .navigationBarItems(
//                leading:
//                    Button(action: {
//                        // Open the AccountScreenView
//                        path.removeLast()
//                    }, label: {
//                        Text("Cancel").font(UIConfig.buttonFont)
//                    }),
//                trailing: Button(action: {
//                    let safeIndex = min(selectedPart, contextText.count)
//                    if let book = bookManager.currentBook {
//                        book.title = title
//                        book.author = author
//                        book.language = selectedLanguage
//                        book.voice = selectedVoice
//                        book.voiceRate = defaultVoiceRate.playbackRateToSpeed()
//                        
//                        if safeIndex > 0 {
//                            book.text = Array(contextText.suffix(from: safeIndex))
//                        }
//                        
//                        bookManager.saveBookToLibrary(book: book) { result in
//                            switch result {
//                            case .success(let fileURL):
//                                print("Book saved successfully at: \(fileURL.path)")
//                                path.append(AppScreen.player)
//                            case .failure(let error):
//                                print("Failed to save book: \(error.localizedDescription)")
//                            }
//                        }
//                    } else {
//                        let book = Book(
//                            title: title,
//                            author: author,
//                            language: selectedLanguage,
//                            voiceIdentifier: selectedVoice.identifier,
//                            voiceRate: defaultVoiceRate.playbackRateToSpeed(),
//                            text: Array(contextText.suffix(from: safeIndex).map { "\($0). " }),
//                            lastPosition: 0, bookmarks: [])
//                        
//                        bookManager.saveBookToLibrary(book: book) { result in
//                            switch result {
//                            case .success(let fileURL):
//                                print("Book saved successfully at: \(fileURL.path)")
//                                bookManager.saveCurrentBook(book: book) {
//                                    path.append(AppScreen.player)
//                                }
//                            case .failure(let error):
//                                print("Failed to save book: \(error.localizedDescription)")
//                            }
//                        }
//                    }
//                }, label: {
//                    Text("Save").font(UIConfig.buttonFont)
//                })
//            )
//            .navigationBarHidden(false)
//            .navigationBarBackButtonHidden(true)
//    }
//    
//    @State var pinCodeText: String = ""
//}
//
//#Preview {
//    NavigationView {
//        let path = State(initialValue: NavigationPath())
//        NewBookDialogView2(path: path.projectedValue)
//    }
//    .environmentObject(BookManager())
//    .environmentObject(TextToSpeechSimplePlayer())
//    
//}
//
