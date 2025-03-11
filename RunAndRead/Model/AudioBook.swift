//
//  AudioBook.swift
//  RunAndRead
//
//  Created by Serge Nes on 3/8/25.
//

import Foundation

import AVFoundation

extension AudioBook {
    func pathToAudio() -> URL? {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let audioFileURL = documentsDirectory.appendingPathComponent(self.audioFilePath)
                if fileManager.fileExists(atPath: audioFileURL.path) {
                    return audioFileURL
                } else {
                   return nil
                }
            }
        return nil
    }
    

    func calculate(completed: @escaping () -> Void) {
        self.isCalculating = true
        
        DispatchQueue.global(qos: .background).async {
            guard let audioFileURL = self.pathToAudio() else {
                nprint("❌ File not found at \(self.audioFilePath)")
                DispatchQueue.main.async {
                    self.isCalculating = false
                    completed()
                }
                return
            }

            nprint("✅ File exists at reconstructed path")

            let audioAsset = AVURLAsset(url: audioFileURL)

            // ✅ Use Task to handle async duration loading
            Task {
                do {
                    let duration = try await audioAsset.load(.duration)
                    let totalDuration = Double(CMTimeGetSeconds(duration)) / Double(self.voiceRate)
                    let elapsedSeconds = Double(self.lastPosition) / Double(self.voiceRate) // `lastPosition` represents seconds played

                    await MainActor.run {
                        self.progressTime = elapsedSeconds.formatSecondsToHMS()
                        self.totalTime = totalDuration.formatSecondsToHMS()
                        self.isCompleted = Int(elapsedSeconds) >= Int(totalDuration)
                        self.isCalculating = false

                        nprint("✅ elapsedSeconds => \(elapsedSeconds)")
                        nprint("✅ duration => \(totalDuration)")

                        completed()
                    }
                } catch {
                    nprint("❌ Error loading audio duration: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isCalculating = false
                        completed()
                    }
                }
            }
        }
    }
}


class AudioBook: RunAndReadBook {
    var id: String
    var title: String
    var author: String
    var language: Locale
    var voiceRate: Float
    var lastPosition: Int // Seconds in an audiobook
    var created: Date
    var bookmarks: [Bookmark]
    
    var parts: [TextPart]
    var audioFilePath: String
    
    var voice: String
    var model: String
    var book_source: String

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        language: Locale,
        voiceRate: Float,
        lastPosition: Int = 0,
        created: Date = Date(),
        bookmarks: [Bookmark] = [],
        parts: [TextPart],
        audioFilePath: String,
        voice: String,
        model: String,
        book_source: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.language = language
        self.voiceRate = voiceRate
        self.lastPosition = lastPosition
        self.created = created
        self.bookmarks = bookmarks
        self.parts = parts
        self.audioFilePath = audioFilePath
        self.voice = voice
        self.model = model
        self.book_source = book_source
    }
    
    func playerType() -> BookPlayerType {
        return .audio
    }

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case id, title, author, language, voiceRate, lastPosition, created, bookmarks, parts, audioFilePath, voice, model, book_source
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        let languageIdentifier = try container.decode(String.self, forKey: .language)
        language = Locale(identifier: languageIdentifier)
        voiceRate = try container.decode(Float.self, forKey: .voiceRate)
        lastPosition = try container.decode(Int.self, forKey: .lastPosition)
        created = try container.decode(Date.self, forKey: .created)
        bookmarks = try container.decode([Bookmark].self, forKey: .bookmarks)
        parts = try container.decode([TextPart].self, forKey: .parts)
        audioFilePath = try container.decode(String.self, forKey: .audioFilePath)
        
        voice = try container.decode(String.self, forKey: .voice)
        model = try container.decode(String.self, forKey: .model)
        book_source = try container.decode(String.self, forKey: .book_source)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(language.identifier, forKey: .language)
        try container.encode(voiceRate, forKey: .voiceRate)
        try container.encode(lastPosition, forKey: .lastPosition)
        try container.encode(created, forKey: .created)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encode(parts, forKey: .parts)
        try container.encode(audioFilePath, forKey: .audioFilePath)
        
        try container.encode(voice, forKey: .voice)
        try container.encode(model, forKey: .model)
        try container.encode(book_source, forKey: .book_source)
    }

    static func == (lhs: AudioBook, rhs: AudioBook) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    
    // MARK: - Computed Properties
    @Published var isCompleted: Bool = false
    @Published var totalTime: String = "00:00"
    @Published var progressTime: String = "00:00"
    @Published var isCalculating: Bool = true
}
