//
//  BookSettingsViewModel.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import AVFoundation
import SwiftUI

class BookSettingsViewModel: ObservableObject {
    @Binding var path: NavigationPath
    @Published var title: String = ""
    @Published var author: String = ""
    @Published var textPreview: String = "..."
    @Published var contextText: [String] = []
    @Published var isPresentingConfirm: Bool = false
    @Published var selectedLanguage: Locale = Locale.current
    @Published var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
    @Published var defaultVoiceRate: Float = 0.5
    @Published var selectedPart: Int = 0
    @Published var showLanguagePicker: Bool = false
    @Published var showVoicePicker: Bool = false
    
    func onSelectVoice(voice: AVSpeechSynthesisVoice) {
        selectedVoice = voice
        if let voiceRate = bookManager.currentBook?.voiceRate {
            defaultVoiceRate = voiceRate.speedToplaybackRate()
        } else {
            defaultVoiceRate = 0.5
        }
    }
    
    func onSelectLanguage(language: Locale) {
        selectedLanguage = language
        if let voiceRate = bookManager.currentBook?.voiceRate {
            defaultVoiceRate = voiceRate.speedToplaybackRate()
        } else {
            defaultVoiceRate = 0.5
        }
        
        var availableVoices: [AVSpeechSynthesisVoice] {
            return AVSpeechSynthesisVoice.speechVoices().filter {
                if let voice_lang = $0.language.split(separator: "-").first {
                    if selectedLanguage.identifier.hasPrefix(voice_lang) {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
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

    private var bookManager: BookManager
    private var simplePlayer: SimpleTTSPlayer

    init(path: Binding<NavigationPath>, bookManager: BookManager, simplePlayer: SimpleTTSPlayer) {
        self.bookManager = bookManager
        self.simplePlayer = simplePlayer
        _path = path
        loadSelectedVoice()
    }

    func loadSelectedVoice() {
        if let language = bookManager.currentBook?.language {
            selectedLanguage = language
        }

        if let voice = bookManager.currentBook?.voice {
            selectedVoice = voice
        } else {
            selectedVoice = AVSpeechSynthesisVoice(language: selectedLanguage.identifier) ?? AVSpeechSynthesisVoice()
        }

        if let voiceRate = bookManager.currentBook?.voiceRate {
            defaultVoiceRate = voiceRate.speedToplaybackRate()
        }
    }

    func saveBook() {
        let safeIndex = min(selectedPart, contextText.count)
        if let book = bookManager.currentBook {
            book.title = title
            book.author = author
            book.language = selectedLanguage
            book.voice = selectedVoice
            book.voiceRate = defaultVoiceRate.playbackRateToSpeed()
            book.text = Array(contextText.suffix(from: safeIndex))

            bookManager.saveBookToLibrary(book: book) { result in
                switch result {
                case .success(let fileURL):
                    print("Book saved successfully at: \(fileURL.path)")
                    self.path.append(AppScreen.player)
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
                    bookmarks: []
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

    func loadBookData(isPreview: Bool = false) {
        if isPreview {
            bookManager.currentBook = Book(title: "This text has been narrated by the Run and Read app! We hope you enjoyed listening!", author: "Author", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 0, bookmarks: [])
            textPreview = ""
            contextText = ["With this approach, you can now have selectable text in your view without allowing the user to modify the content. The text will be fully selectable, and users will be able to copy it to the clipboard by selecting and using the standard copy commands.", "Lorem ipsum2", "Lorem ipsum3"]
        }
        if let book = bookManager.currentBook {
            textPreview = currentPart(parts: book.text)
            contextText = book.text
            title = book.title
            author = book.author
        } else {
            title = bookManager.titleData
            author = bookManager.authorData
            textPreview = currentPart(parts: bookManager.plainTextData)
            contextText = bookManager.plainTextData
        }
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
        path.removeLast()
    }

    //----- Player

    func onPlayPauseText() {
        let text = textPreview.substringTwoSentences()
        let r = defaultVoiceRate
        simplePlayer.startTextToSpeech(text: text, voice: selectedVoice, rate: r)
    }
    
    func onPlayPauseText2(rate: Float = 0.5) {
        let text = textPreview.substringTwoSentences()
        simplePlayer.startTextToSpeech(text: text, voice: selectedVoice, rate: rate)
    }

    //---Delete
    func isDeleteVisible() -> Bool {
        return !isPresentingConfirm && bookManager.currentBook != nil
    }

    func onDeleteBook() {
        if let book = bookManager.currentBook {
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
        }
    }
}
