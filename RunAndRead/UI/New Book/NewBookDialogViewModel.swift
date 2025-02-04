//
//  NewBookDialogViewModel.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import AVFoundation
import SwiftUI

class NewBookDialogViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var author: String = ""
    @Published var textPreview: String = "..."
    @Published var contextText: [String] = []
    @Published var isPresentingConfirm: Bool = false
    @Published var defaultLanguage: Locale = Locale.current
    @Published var selectedLanguage: Locale = Locale.current
    @Published var selectedVoice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice()
    @Published var defaultVoiceRate: Float = 0.5
    @Published var selectedPart: Int = 0
    @Published var showLanguagePicker: Bool = false
    @Published var showVoicePicker: Bool = false

    private var bookManager: BookManager
    private var simplePlayer: TextToSpeechSimplePlayer

    init(bookManager: BookManager, simplePlayer: TextToSpeechSimplePlayer) {
        self.bookManager = bookManager
        self.simplePlayer = simplePlayer
        loadSelectedVoice()
    }

    func loadSelectedVoice() {
        if let language = bookManager.currentBook?.language {
            defaultLanguage = language
        }

        if let voice = bookManager.currentBook?.voice {
            selectedVoice = voice
        } else {
            selectedVoice = AVSpeechSynthesisVoice(language: defaultLanguage.identifier) ?? AVSpeechSynthesisVoice()
        }

        if let voiceRate = bookManager.currentBook?.voiceRate {
            defaultVoiceRate = voiceRate
        }

        selectedLanguage = defaultLanguage
    }

    func saveBook() {
        let safeIndex = min(selectedPart, contextText.count)
        if let book = bookManager.currentBook {
            book.title = title
            book.author = author
            book.language = selectedLanguage
            book.voice = selectedVoice
            book.voiceRate = defaultVoiceRate
            book.text = Array(contextText.suffix(from: safeIndex))

            bookManager.saveBookToLibrary(book: book) { result in
                switch result {
                case .success(let fileURL):
                    print("Book saved successfully at: \(fileURL.path)")
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
                voiceRate: defaultVoiceRate,
                text: Array(contextText.suffix(from: safeIndex).map { "\($0). " }),
                lastPosition: 0,
                bookmarks: []
            )

            bookManager.saveBookToLibrary(book: book) { result in
                switch result {
                case .success(let fileURL):
                    print("Book saved successfully at: \(fileURL.path)")
                    self.bookManager.saveCurrentBook(book: book) {
                        
                    }
                case .failure(let error):
                    print("Failed to save book: \(error.localizedDescription)")
                }
            }
        }
    }

    func loadBookData() {
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
        if parts.isEmpty { return "" }
        let safeIndex = min(selectedPart, contextText.count)
        return parts[safeIndex]
    }

    func onPageChanged(newPageIndex: Int) {
        if newPageIndex < contextText.count {
            textPreview = contextText[newPageIndex]
        }
    }

    func languageString() -> String {
        return defaultLanguage.localizedString(forLanguageCode: defaultLanguage.identifier) ?? "Unknown"
    }
}
