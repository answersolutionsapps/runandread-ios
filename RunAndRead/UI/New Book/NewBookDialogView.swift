//
//  NewBookDialogView.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import SwiftUI
import AVFoundation


struct HorizontalPageListView: View {
    @Binding var selectedPage: Int
    let totalPages: Int
    let onPageChanged: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(0..<totalPages, id: \.self) { pageIndex in
                        Button(action: {
                            selectedPage = pageIndex
                            onPageChanged(pageIndex)
                        }) {
                            Text("\(pageIndex + 1)")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(selectedPage == pageIndex ? UIConfig.primaryColor : Color.gray)
                                .foregroundColor(.white)
//                                .clipShape(Circle())
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    // Detect the first visible item when the view appears
                    let firstVisibleItem = calculateFirstVisibleItem(in: geometry)
                    selectedPage = firstVisibleItem
                    onPageChanged(firstVisibleItem)
                }
                .onChange(of: geometry.frame(in: .global).origin.x) { _ in
                    let firstVisibleItem = calculateFirstVisibleItem(in: geometry)
                    selectedPage = firstVisibleItem
                    onPageChanged(firstVisibleItem)
                }
            }
        }
        .frame(height: 60)
    }
    
    private func calculateFirstVisibleItem(in geometry: GeometryProxy) -> Int {
        let offset = geometry.frame(in: .global).origin.x
        let itemWidth = 50.0 // button width + spacing (if any)
        let firstVisibleIndex = Int(offset / itemWidth)
        return max(0, firstVisibleIndex)
    }
}


struct TextModifier: ViewModifier {
    private let font: UIFont
    private let color: Color
    private let multilineTextAlignment: TextAlignment
    
    init(font: UIFont, color: Color = .black, multilineTextAlignment: TextAlignment = .center) {
        self.font = font
        self.color = color
        self.multilineTextAlignment = multilineTextAlignment
    }
    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .font(.custom(font.fontName, size: font.pointSize))
            .foregroundColor(color)
            .multilineTextAlignment(multilineTextAlignment)
            .lineLimit(nil)
    }
}

struct ButtonModifier: ViewModifier {
    private let font: UIFont
    private let color: Color
    private let textColor: Color
    private let width: CGFloat?
    private let height: CGFloat?
    
    init(font: UIFont,
         color: Color,
         textColor: Color = .white,
         width: CGFloat? = nil,
         height: CGFloat? = nil) {
        self.font = font
        self.color = color
        self.textColor = textColor
        self.width = width
        self.height = height
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(TextModifier(font: font, color: textColor))
            .padding()
            .frame(width: width, height: height)
            .background(color)
            .cornerRadius(0)
    }
}

struct LongButtonView: View {
    let title: String
    var backgroundColor: Color = UIConfig.primaryColor
    var textColor: Color = .white
    
    var body: some View {
        Text(title)
        .modifier(ButtonModifier(font: UIConfig.buttonFont2,
                                         color: backgroundColor,
                                         textColor: textColor,
                                         width: UIConfig.actionButtonWidth,
                                         height: UIConfig.actionButtonHeight))
    }
}



struct NewBookDialogView: View {
    @EnvironmentObject var bookManager: BookManager
    @EnvironmentObject var simplePlayer: TextToSpeechSimplePlayer
    @Binding var path: NavigationPath

    @StateObject private var viewModel: NewBookDialogViewModel
    @State private var pinCodeText: String = ""
    @FocusState private var textIsFocused: Bool

    init(path: Binding<NavigationPath>, bookManager: BookManager, simplePlayer: TextToSpeechSimplePlayer) {
        _viewModel = StateObject(wrappedValue: NewBookDialogViewModel(bookManager: bookManager, simplePlayer: simplePlayer))
        _path = path
    }

    var body: some View {
        ZStack {
            Group { // sticky header
                
            }
            Group {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Title")
                            .font(.headline)
                        TextField("Enter title", text: $viewModel.title)
                            .textFieldStyle(DefaultTextFieldStyle())
                            .font(.title2)
                            .padding(.bottom, 10)

                        Text("Author")
                            .font(.headline)
                        TextField("Enter author", text: $viewModel.author)
                            .textFieldStyle(DefaultTextFieldStyle())
                            .font(.title2)
                        
                        Divider()

                        Text("Language")
                            .font(.headline)
                        Button(action: {
                            viewModel.showLanguagePicker = true
                        }) {
                            Text(viewModel.languageString())
                                .font(.body)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }

                        Divider()
                        HStack {
                            Text("Naration Voice")
                                .font(.headline)
                            ImageButtonView(
                                imageName: "play.circle.fill",
                                imageColor: .accentColor,
                                action: {
                                    let text = viewModel.textPreview.substringTwoSentences()
                                    simplePlayer.startTextToSpeech(text: text, voice: viewModel.selectedVoice, rate: viewModel.defaultVoiceRate)
                                }
                            )
                                                }
                        VStack(alignment: .center) {
                            SpeechSpeedSelector(defaultSpeed: viewModel.defaultVoiceRate.playbackRateToSpeed()) { newSpeed in
                                    print("Selected speed: \(newSpeed)")
                                    viewModel.defaultVoiceRate = newSpeed.speedToplaybackRate()
                            }
                        }.frame(maxWidth: .infinity)

                        Button(action: {
                            viewModel.showVoicePicker = true
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
                            VoicePicker(selectedVoice: $viewModel.selectedVoice, selectedLanguage: viewModel.defaultLanguage)
                        }

                        Divider()

                        VStack {
                            Text("Text Preview")
                                .font(.headline)
                            HorizontalPageListView(selectedPage: $viewModel.selectedPart, totalPages: viewModel.contextText.count) { newPageIndex in
                                viewModel.onPageChanged(newPageIndex: newPageIndex)
                            }
                            Text("Read from page: \(viewModel.selectedPart + 1)")
                            Divider()
                            TextEditor(text: $viewModel.textPreview)
                                    .font(.body)
                                    .frame(height: 350)  // Adjust frame as needed
                                    .disabled(false)
                                    .focused($textIsFocused)
                                    .scrollDisabled(false)

                            Spacer()
                        }
//                        .frame(maxWidth: .infinity, minHeight: 450)
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
                         .padding()
                        Divider()

                        if !viewModel.isPresentingConfirm && bookManager.currentBook != nil {
                            VStack(alignment: .center, spacing: UIConfig.normalSpace) {
                                Button(action: {
                                    viewModel.isPresentingConfirm.toggle()
                                }, label: {
                                    LongButtonView(title: "Delete Book", backgroundColor: .red).padding(.top, UIConfig.smallSpace)
                                })
                                Text("Delete this book from the library").font(.caption).fontWeight(.light).foregroundColor(.red)
                            }.font(.subheadline).frame(maxWidth: .infinity, maxHeight: 150)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding()
                }
            }

//            if bookManager.inProgress {
//                CustomActivityIndicator()
//            }
        }
                .textFieldAlert(
                            isPresented: $viewModel.isPresentingConfirm,
                            title: "Are you sure?",
                            message: "You cannot undo this action!",
                            text: "",
                            placeholder: "Input word delete",
                            action: { newText in
                                pinCodeText = newText ?? ""
                                if pinCodeText.lowercased() == "delete", let book = bookManager.currentBook {
                                    bookManager.deleteBookFromLibrary(book: book) { result in
                                        switch result {
                                        case .success:
                                            print("✅ Book deleted successfully.")
                                                // Remove the book from the UI list
                                                bookManager.library.removeAll { $0.id == book.id }
                                                bookManager.deleteCurrentBook {
                                                    path.removeLast(path.count)
                                                    path.append(AppScreen.home)
                                                }
                                        case .failure(let error):
                                            print("❌ Failed to delete book: \(error.localizedDescription)")
                                        }
                                    }
        
        
                                }
                            }
                        )
        .onAppear {
            viewModel.loadBookData()
            if isPreview {
                bookManager.currentBook = Book(title: "This text has been narrated by the Run and Read app! We hope you enjoyed listening!", author: "Author", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 0, bookmarks: [])
                viewModel.textPreview = ""
                viewModel.contextText = ["With this approach, you can now have selectable text in your view without allowing the user to modify the content. The text will be fully selectable, and users will be able to copy it to the clipboard by selecting and using the standard copy commands.", "Lorem ipsum2", "Lorem ipsum3"]
            }
        }
                .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            HStack {
                                Spacer()
                                Text("Book Settings").font(.title2)
                                Spacer()
                            }
                            .tint(UIConfig.backgroundColor)
                        }
                    }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading:
                Button(action: {
                    path.removeLast()
                }, label: {
                    Text("Cancel").font(UIConfig.buttonFont)
                }),
            trailing: Button(action: {
                viewModel.saveBook()
                path.append(AppScreen.player)
            }, label: {
                Text("Save").font(UIConfig.buttonFont)
            })
        )
        .sheet(isPresented: $viewModel.showLanguagePicker) {
            LanguagePicker(selectedLanguage: $viewModel.selectedLanguage)
        }
    }
}

#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
        NewBookDialogView(path: path.projectedValue, bookManager: BookManager(), simplePlayer: TextToSpeechSimplePlayer())
    }
    .environmentObject(BookManager())
    .environmentObject(TextToSpeechSimplePlayer())
}


//struct NewBookDialogView: View {
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
//        NewBookDialogView(path: path.projectedValue)
//    }
//    .environmentObject(BookManager())
//    .environmentObject(TextToSpeechSimplePlayer())
//    
//}
