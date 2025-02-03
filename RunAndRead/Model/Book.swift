//
//  Book.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import Foundation
import AVFAudio



struct Bookmark: Codable {
    let voiceRate: Float
    let position: Float
}

class Book: ObservableObject, Codable, Identifiable, Hashable {
    
    static let SECONDS_PER_CHARACTER = 0.080
    
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: String
    var title: String
    var author: String
    var language: Locale
    var voice: AVSpeechSynthesisVoice
    var voiceRate: Float
    var text: [String]
    var lastPosition: Float
    var created: Date
    var bookmarks: [Bookmark]

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        language: Locale,
        voiceIdentifier: String?,
        voiceRate: Float,
        text: [String],
        lastPosition: Float,
        created: Date = Date(),
        bookmarks: [Bookmark]
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.language = language
        self.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier ?? "") ??
                     AVSpeechSynthesisVoice(language: language.identifier) ??
                     AVSpeechSynthesisVoice(language: "en-US")!  // Safe fallback
        self.voiceRate = voiceRate
        self.text = text
        self.lastPosition = lastPosition
        self.created = created
        self.bookmarks = bookmarks
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, title, author, language, voiceIdentifier, voiceRate, text, lastPosition, created, bookmarks
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        
        let languageIdentifier = try container.decode(String.self, forKey: .language)
        language = Locale(identifier: languageIdentifier)
        
        let voiceIdentifier = try container.decodeIfPresent(String.self, forKey: .voiceIdentifier)
        voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier ?? "") ??
                AVSpeechSynthesisVoice(language: languageIdentifier) ??
                AVSpeechSynthesisVoice(language: "en-US")!  // Safe fallback
        
        voiceRate = try container.decode(Float.self, forKey: .voiceRate)
        text = try container.decode([String].self, forKey: .text)
        lastPosition = try container.decode(Float.self, forKey: .lastPosition)
        created = try container.decode(Date.self, forKey: .created)
        do {
            bookmarks = try container.decode([Bookmark].self, forKey: .bookmarks)
        } catch {
            bookmarks = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(language.identifier, forKey: .language)
        try container.encode(voice.identifier, forKey: .voiceIdentifier)
        try container.encode(voiceRate, forKey: .voiceRate)
        try container.encode(text, forKey: .text)
        try container.encode(lastPosition, forKey: .lastPosition)
        try container.encode(created, forKey: .created)
        try container.encode(bookmarks, forKey: .bookmarks)
    }
    
    func calculate(completed: @escaping ()->Void) {
        DispatchQueue.global(qos: .background).async {
            let words: [String] = self.text
                    .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            
            
            let totalSeconds = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.voiceRate)
            
            
            let elapsedSeconds = (Double(words.prefix(Int(self.lastPosition)).joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.voiceRate)
            
            
            DispatchQueue.main.async {
                completed()
                self.progressTime = elapsedSeconds.formatSecondsToHMS()
                self.totalTime = totalSeconds.formatSecondsToHMS()
                self.isCompleted = Int(self.lastPosition) + 1 >= words.count
            }
        }
    }
    
    // MARK: - Computed Properties
    @Published var isCompleted: Bool = false
    @Published var totalTime: String = "0:00"
    @Published var progressTime: String = "0:00"
    @Published var isCalculated = false
    
    func approximateLastPosition(from elapsedTime: Float) -> Double {
        let words: [String] = text
                .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        //TODO: check it/test it!!!
        let estimatedCharacters = Int((Double(elapsedTime) / (Book.SECONDS_PER_CHARACTER * Double(voiceRate))))
        
        // Find the approximate word index
        var characterCount = 0
        for (index, word) in words.enumerated() {
            characterCount += word.count + 1 // +1 for spaces
            if characterCount >= estimatedCharacters {
                return Double(index)
            }
        }
        return Double(words.count - 1) // Ensure we don't exceed the array bounds
    }
}

// MARK: - Time Formatting Extension
extension Double {
    func formatSecondsToHMS() -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
