//
//  BookSettingsViewModel.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import AVFoundation
import SwiftUI
import RunAnywhere

class BookSettingsViewModel: ObservableObject {
    @Binding var path: NavigationPath
    @Published var title: String = ""
    @Published var author: String = ""
    @Published var textPreview: String = "..."
    @Published var contextText: [String] = []
    @Published var contextParts: [TextPart] = []
    @Published var isPresentingConfirm: Bool = false
    @Published var selectedLanguage: Locale = Locale.current
    @Published var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
    @Published var defaultVoiceRate: Float = 0.5
    @Published var selectedPart: Int = 0
    @Published var showLanguagePicker: Bool = false
    @Published var showVoicePicker: Bool = false
    @Published var selectedTTSEngine: TTSEngineType = .system
    @Published var showRunAnywhereVoicePicker: Bool = false
    @Published var selectedRunAnywhereVoiceId: String = "vits-piper-en_US-lessac-medium"
    @Published var selectedRunAnywhereVoiceName: String = "Piper TTS (US English - Medium)"
    
    func getDefaultVoiceRate() -> Float {
        if (bookManager.currentBook is AudioBook) {
            return defaultVoiceRate
        } else {
            return defaultVoiceRate.playbackRateToSpeed()
        }
    }
    
    func onRateChanges(value: Float) {
        if (bookManager.currentBook is AudioBook) {
            defaultVoiceRate = value
        } else {
            defaultVoiceRate = value.speedToPlaybackRate()
        }
    }
    
    func invalidBook() -> Bool {
        if (title.isEmpty || author.isEmpty ) {
            return true
        }
        
        if (bookManager.currentBook is Book && contextText.isEmpty) {
            return true
        }
        
        return false
    }
    
    private func voiceRateDefault() -> Float {
        if (bookManager.currentBook is AudioBook) {
            return 1.0
        } else {
            return 0.5
        }
    }
    
    func onSelectVoice(voice: AVSpeechSynthesisVoice) {
        selectedVoice = voice
        if let voiceRate = bookManager.currentBook?.voiceRate {
            if (bookManager.currentBook is AudioBook) {
                defaultVoiceRate = voiceRate
            } else {
                defaultVoiceRate = voiceRate.speedToPlaybackRate()
            }
        } else {
            defaultVoiceRate = voiceRateDefault()
        }
    }
    
    func onSelectLanguage(language: Locale) {
        selectedLanguage = language
        if let voiceRate = bookManager.currentBook?.voiceRate {
            if (bookManager.currentBook is AudioBook) {
                defaultVoiceRate = voiceRate
            } else {
                defaultVoiceRate = voiceRate.speedToPlaybackRate()
            }
        } else {
            defaultVoiceRate = voiceRateDefault()
        }
        
        var availableVoices: [AVSpeechSynthesisVoice] {
            let all = AVSpeechSynthesisVoice.speechVoices().filter {
                if let voice_lang = $0.language.split(separator: "-").first {
                    return selectedLanguage.identifier.hasPrefix(voice_lang)
                }
                return false
            }
            
            return all.sorted { v1, v2 in
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
        if availableVoices.isEmpty == false, let firstVoice = availableVoices.first {
            selectedVoice = firstVoice
        }
    }
    
    @MainActor func onShowLanguagePicker(){
        showLanguagePicker = true
    }
    
    @MainActor func onShowVoicePicker(){
        showVoicePicker = true
    }

    @MainActor func onShowRunAnywhereVoicePicker(){
        showRunAnywhereVoicePicker = true
    }

    func onSelectRunAnywhereVoice(voiceId: String, voiceName: String) {
        selectedRunAnywhereVoiceId = voiceId
        selectedRunAnywhereVoiceName = voiceName
    }

    private var bookManager: BookManager
    private var simplePlayer: SimpleTTSPlayer
    private var audioPlayer: AVAudioPlayer?

    init(path: Binding<NavigationPath>, bookManager: BookManager, simplePlayer: SimpleTTSPlayer) {
        self.bookManager = bookManager
        self.simplePlayer = simplePlayer
        _path = path
        loadSelectedVoice()
    }

    func loadSelectedVoice() {
        if let book =  bookManager.currentBook as? Book {
            selectedVoice = book.voice
            selectedTTSEngine = book.ttsEngine
            if let voiceId = book.runAnywhereVoiceId {
                selectedRunAnywhereVoiceId = voiceId
                // Try to get the voice name from the model ID
                selectedRunAnywhereVoiceName = getVoiceNameForId(voiceId)
            }
        }
        if let voiceRate = bookManager.currentBook?.voiceRate {
            if (bookManager.currentBook is AudioBook) {
                defaultVoiceRate = voiceRate
            } else {
                defaultVoiceRate = voiceRate.speedToPlaybackRate()
            }
        } else {
            defaultVoiceRate = voiceRateDefault()
        }
        if let language = bookManager.currentBook?.language {
            selectedLanguage = language
        }
    }

    private func getVoiceNameForId(_ voiceId: String) -> String {
        // Map voice IDs to names
        switch voiceId {
        case "vits-piper-en_US-lessac-medium":
            return "Piper TTS (US English - Medium)"
        case "vits-piper-en_GB-alba-medium":
            return "Piper TTS (British English)"
        default:
            return voiceId
        }
    }
    
    func isAudioBook() -> Bool {
        return (bookManager.currentBook is AudioBook || bookManager.audioPath?.hasSuffix(".mp3") == true)
    }
    
    func audioBookVoice() -> String {
        return (bookManager.currentBook as? AudioBook)?.voice ?? "Unknown"
    }
    
    func audioBookModel() -> String {
        return (bookManager.currentBook as? AudioBook)?.model ?? "Unknown"
    }
    
    func audioBookSource() -> String {
        return (bookManager.currentBook as? AudioBook)?.book_source ?? "Unknown"
    }
    
    func audioBookLanguage() -> String {
        if let locale = (bookManager.currentBook as? AudioBook)?.language {
            return "\(locale.localizedString(forIdentifier: locale.identifier) ?? "Unknown")"
        }
        return "Unknown"
    }

    func saveBook() {
        audioPlayer?.stop()
        let safeIndex = min(selectedPart, contextText.count)
        if let book = bookManager.currentBook as? Book {
            book.title = title
            book.author = author
            book.language = selectedLanguage
            book.voice = selectedVoice
            book.voiceRate = defaultVoiceRate.playbackRateToSpeed()
            book.text = Array(contextText.suffix(from: safeIndex))
            book.ttsEngine = selectedTTSEngine
            book.runAnywhereVoiceId = selectedTTSEngine == .runAnywhereAI ? selectedRunAnywhereVoiceId : nil

            bookManager.saveBookToLibrary(book: book) { result in
                switch result {
                case .success(let fileURL):
                    print("Book saved successfully at: \(fileURL.path)")
                    self.path.append(AppScreen.player)
                case .failure(let error):
                    print("Failed to save book: \(error.localizedDescription)")
                }
            }
        } else if let book = bookManager.currentBook as? AudioBook {
            book.title = title
            book.author = author
//            book.language = selectedLanguage
            book.voiceRate = defaultVoiceRate

            bookManager.saveAudioBookToLibrary(book: book) { result in
                switch result {
                case .success(let fileURL):
                    print("Book saved successfully at: \(fileURL.path)")
                    self.path.append(AppScreen.player)
                case .failure(let error):
                    print("Failed to save book: \(error.localizedDescription)")
                }
            }
        } else {
            if let fileURL = bookManager.audioPath {
                //TODO: This part is not implemented, opened audiobook opens in player
                let book = AudioBook(
                    title: title,
                    author: author,
                    language: selectedLanguage,
                    voiceRate: defaultVoiceRate,
                    parts: bookManager.plainTextPartData,
                    audioFilePath:fileURL,
                    voice: "",
                    model: "",
                    book_source: ""
                )
                
                bookManager.saveAudioBookToLibrary(book: book) { result in
                    switch result {
                    case .success(let fileURL):
                        print("Book saved successfully at: \(fileURL.path)")
                        self.bookManager.saveCurrentBook(book: book) {
                            self.path.append(AppScreen.player)
                        }
                    case .failure(let error):
                        print("Failed to save book: \(error.localizedDescription)")
                    }
                }
            } else {
                let book = Book(
                        title: title,
                        author: author,
                        language: selectedLanguage,
                        voiceIdentifier: selectedVoice.identifier,
                        voiceRate: defaultVoiceRate.playbackRateToSpeed(),
                        text: Array(contextText.suffix(from: safeIndex).map {
                            "\($0). "
                        }),
                        lastPosition: 0,
                        bookmarks: [],
                        ttsEngine: selectedTTSEngine,
                        runAnywhereVoiceId: selectedTTSEngine == .runAnywhereAI ? selectedRunAnywhereVoiceId : nil
                )

                bookManager.saveBookToLibrary(book: book) { result in
                    switch result {
                    case .success(let fileURL):
                        print("Book saved successfully at: \(fileURL.path)")
                        self.bookManager.saveCurrentBook(book: book) {
                            self.path.append(AppScreen.player)
                        }
                    case .failure(let error):
                        print("Failed to save book: \(error.localizedDescription)")
                    }
                }
            }
            
        }
    }

    func loadBookData(isPreview: Bool = false) {
        if isPreview {
            bookManager.currentBook = Book(title: "This text has been narrated by the Run and Read app! We hope you enjoyed listening!", author: "Author", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 0, bookmarks: [])
            textPreview = ""
            contextText = ["With this approach, you can now have selectable text in your view without allowing the user to modify the content. The text will be fully selectable, and users will be able to copy it to the clipboard by selecting and using the standard copy commands.", "Lorem ipsum2", "Lorem ipsum3"]
        }
        if let book = bookManager.currentBook as? Book {
            textPreview = currentPart(parts: book.text)
            contextText = book.text
            title = book.title
            author = book.author
        } else if let book = bookManager.currentBook as? AudioBook {
            title = book.title
            author = book.author
            contextParts = bookManager.plainTextPartData
            textPreview = currentTextPart(parts: bookManager.plainTextPartData)
        } else {
            title = bookManager.titleData
            author = bookManager.authorData
            
            if let fileURL = bookManager.audioPath {
                contextParts = bookManager.plainTextPartData
                textPreview = currentTextPart(parts: bookManager.plainTextPartData)
            } else {
                textPreview = currentPart(parts: bookManager.plainTextData)
                contextText = bookManager.plainTextData
            }
        }
    }
    
    private func currentTextPart(parts: [TextPart]) -> String {
        if parts.isEmpty {
            return ""
        }
        let safeIndex = min(selectedPart, contextParts.count)
        return parts[safeIndex].text
    }

    private func currentPart(parts: [String]) -> String {
        if parts.isEmpty {
            return ""
        }
        let safeIndex = min(selectedPart, contextText.count)
        return parts[safeIndex]
    }

    func onPageChanged(newPageIndex: Int) {
        if newPageIndex < contextText.count {
            textPreview = contextText[newPageIndex]
        }
    }

    func languageString() -> String {
        return selectedLanguage.localizedString(forLanguageCode: selectedLanguage.identifier) ?? "Unknown"
    }

    func onCancel() {
        audioPlayer?.stop()
        path.removeLast()
    }

    //----- Player

    func onPlayPauseText() {
        // Handle RunAnywhere AI TTS test
        if selectedTTSEngine == .runAnywhereAI {
            Task {
                await playTestWithRunAnywhereAI()
            }
            return
        }

        if let book =  bookManager.currentBook as? AudioBook, let path = book.pathToAudio() {
            if audioPlayer?.isPlaying == true {
                audioPlayer?.stop()
            } else {
                    do {
                        if (audioPlayer == nil){
                            audioPlayer = try AVAudioPlayer(contentsOf: path)
                        }
                        audioPlayer?.enableRate = true
                        audioPlayer?.prepareToPlay()
//                        nprint("audioPlayer?.rate=>\(audioPlayer?.rate)")
//                        nprint("audioPlayer?.defaultVoiceRate=>\(defaultVoiceRate)")
//                        nprint("audioPlayer?.book.voiceRate)=>\(book.voiceRate)")
                        audioPlayer?.rate = Float(defaultVoiceRate)
                        audioPlayer?.play()
                    } catch {
                        print("Error playing file \(path.absoluteString): \(error.localizedDescription)")
                    }
            }
        } else if let path =  bookManager.audioPath{
            if audioPlayer?.isPlaying == true {
                audioPlayer?.stop()
            } else {
                    do {
                        if (audioPlayer == nil){
                            let fileManager = FileManager.default
                            
                            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                                    let audioFileURL = documentsDirectory.appendingPathComponent(path)
                                    if fileManager.fileExists(atPath: audioFileURL.path), let url = URL(string: path) {
                                        audioPlayer = try AVAudioPlayer(contentsOf: url)
                                    }
                                }
                        }
                        audioPlayer?.enableRate = true
                        audioPlayer?.prepareToPlay()
                        audioPlayer?.rate = Float(defaultVoiceRate)
                        audioPlayer?.play()
                    } catch {
                        print("Error playing file \(path): \(error.localizedDescription)")
                    }
            }
        } else {
            let text = textPreview.substringTwoSentences()
            let r = defaultVoiceRate
            simplePlayer.startTextToSpeech(text: text, voice: selectedVoice, rate: r)
        }
    }
    
    func onPlayPauseText2(rate: Float = 0.5) {
        let text = textPreview.substringTwoSentences()
        simplePlayer.startTextToSpeech(text: text, voice: selectedVoice, rate: rate)
    }

    private func playTestWithRunAnywhereAI() async {
        let text = textPreview.substringTwoSentences()

        do {
            // Check if model is loaded
            if await RunAnywhere.currentTTSVoiceId != selectedRunAnywhereVoiceId {
                // Need to load the selected model
                let availableModels = try await RunAnywhere.availableModels()
                if let model = availableModels.first(where: { $0.id == selectedRunAnywhereVoiceId }) {
                    // Check if model needs to be downloaded
                    if model.localPath == nil {
                        print("Model not downloaded, cannot test")
                        return
                    }

                    // Load the model
                    try await RunAnywhere.loadTTSModel(selectedRunAnywhereVoiceId)
                }
            }

            // Speak the text with selected rate
            let options = TTSOptions(
                rate: Float(defaultVoiceRate),
                pitch: 1.0
            )
            _ = try await RunAnywhere.speak(text, options: options)
        } catch {
            print("Failed to test RunAnywhere AI voice: \(error.localizedDescription)")
        }
    }

    //---Delete
    func isDeleteVisible() -> Bool {
        return !isPresentingConfirm && bookManager.currentBook != nil
    }

    func onDeleteBook() {
        if let book = bookManager.currentBook as? Book {
            bookManager.deleteBookFromLibrary(book: book) { result in
                switch result {
                case .success:
                    print("✅ Book deleted successfully.")
                    // Remove the book from the UI list
                    self.bookManager.library.removeAll {
                        $0.id == book.id
                    }
                    self.bookManager.deleteCurrentBook {
                        self.path.removeLast(self.path.count)
                        self.path.append(AppScreen.home)
                    }
                case .failure(let error):
                    print("❌ Failed to delete book: \(error.localizedDescription)")
                }
            }
        } else if let book = bookManager.currentBook as? AudioBook {
            bookManager.deleteAudioBookFromLibrary(book: book) { result in
                switch result {
                case .success:
                    print("✅ Audio Book deleted successfully.")
                    // Remove the book from the UI list
                    self.bookManager.library.removeAll {
                        $0.id == book.id
                    }
                    self.bookManager.deleteCurrentBook {
                        self.path.removeLast(self.path.count)
                        self.path.append(AppScreen.home)
                    }
                case .failure(let error):
                    print("❌ Failed to delete Audio book: \(error.localizedDescription)")
                }
            }
        }
    }
}
