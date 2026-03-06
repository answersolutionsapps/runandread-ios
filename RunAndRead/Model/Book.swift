//
//  Book.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import Foundation
import AVFAudio

protocol RunAndReadBook: Identifiable, Codable, Hashable, ObservableObject {
    var id: String { get }
    var title: String { get }
    var author: String { get }
    var language: Locale { get set }
    var voiceRate: Float { get set }
    var lastPosition: Int { get set } // Position for resuming
    var created: Date { get set }
    var bookmarks: [Bookmark] { get set }
    
    func playerType() -> BookPlayerType
    func calculate(completed: @escaping ()->Void)
    
    // Computed Properties (Cannot use @Published here)
    var isCompleted: Bool { get }
    var totalTime: String { get }
    var progressTime: String { get }
    var isCalculating: Bool { get }
}

enum BookPlayerType: String, Codable {
    case tts
    case audio
}

struct TextPart: Codable {
    let start_time_ms: Int
    let end_time_ms: Int?
    let text: String
}

struct Bookmark: Codable  {
    let position: Int
    var text: String = ""
}


class Book: RunAndReadBook {
    static let SECONDS_PER_CHARACTER = 0.080
    
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }
    
    func playerType() -> BookPlayerType {
           return .tts
       }
    
    var id: String
    var title: String
    var author: String
    var language: Locale
    var voice: AVSpeechSynthesisVoice
    var voiceRate: Float
    var text: [String]
    var lastPosition: Int //index in the array of all words
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
        lastPosition: Int,
        created: Date = Date(),
        bookmarks: [Bookmark]
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.language = language
        let fallbackLangs = [language.identifier, "en-US", "en-GB", Locale.current.identifier]
        let fallbackVoice = fallbackLangs.compactMap { AVSpeechSynthesisVoice(language: $0) }.first
        self.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier ?? "") ??
                     fallbackVoice ??
                     AVSpeechSynthesisVoice.speechVoices().first ??
                     AVSpeechSynthesisVoice()
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
        let fallbackLangs = [languageIdentifier, "en-US", "en-GB", Locale.current.identifier]
        let fallbackVoice = fallbackLangs.compactMap { AVSpeechSynthesisVoice(language: $0) }.first
        voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier ?? "") ??
                fallbackVoice ??
                AVSpeechSynthesisVoice.speechVoices().first ??
                AVSpeechSynthesisVoice()
        
        voiceRate = try container.decode(Float.self, forKey: .voiceRate)
        text = try container.decode([String].self, forKey: .text)
        lastPosition = try container.decode(Int.self, forKey: .lastPosition)
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
        self.isCalculating = true
        DispatchQueue.global(qos: .background).async {
            let words: [String] = self.text.flatMap {
                $0.cleanedForTTS().components(separatedBy: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
            }
            
            let totalSeconds = (Double(words.joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.voiceRate)
            let elapsedSeconds = (Double(words.prefix(self.lastPosition).joined(separator: " ").count) * Book.SECONDS_PER_CHARACTER) / Double(self.voiceRate)
            
            
            DispatchQueue.main.async {
                self.progressTime = elapsedSeconds.formatSecondsToHMS()
                self.totalTime = totalSeconds.formatSecondsToHMS()
                self.isCompleted = self.lastPosition + 25 >= words.count
                self.isCalculating = false
                completed()
            }
        }
    }
    
    // MARK: - Computed Properties
    @Published var isCompleted: Bool = false
    @Published var totalTime: String = "00:00"
    @Published var progressTime: String = "00:00"
    @Published var isCalculating: Bool = true
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
