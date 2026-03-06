//
//  BookManager.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import Foundation
import Combine
import AVFoundation
import AVFAudio

class BookManager: ObservableObject {
    private let fileManager = FileManager.default
    private let rootDirectory: URL
    private let currentBookIdPath: URL
    private let libraryFolderPath: URL
    private let audioLibraryFolderPath: URL

    @Published var library: [any RunAndReadBook] = []
    @Published var libraryDefault: [any RunAndReadBook] = []
    @Published var currentBookId: String?
    @Published var inProgress = false
    @Published var currentBook: (any RunAndReadBook)?

    @Published var plainTextData: [String] = []
    @Published var authorData: String = ""
    @Published var titleData: String = ""
    
    @Published var plainTextPartData: [TextPart] = []
    @Published var audioPath: String? = nil
    
    func defineTextBookFields(bookFile: BookFile) {
        audioPath = nil
        plainTextPartData = []
        plainTextData =  bookFile.content
        plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
        titleData = bookFile.title
        authorData = bookFile.author
    }
    
    func defineAudioBookFields(bookFile: BookFile) {
        plainTextPartData =  bookFile.text
        audioPath =  bookFile.audioPath
        plainTextData = []
        titleData = bookFile.title
        authorData = bookFile.author
    }

    public var openedFilePath: URL? = nil

    init() {
        rootDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        currentBookIdPath = rootDirectory.appendingPathComponent("currentBookId.json")
        libraryFolderPath = rootDirectory.appendingPathComponent("library")
        audioLibraryFolderPath = rootDirectory.appendingPathComponent("audiobooks")

        if !fileManager.fileExists(atPath: libraryFolderPath.path) {
            _ = FileIO.createDirectoryIfNeeded(at: libraryFolderPath)
        }
        if !fileManager.fileExists(atPath: audioLibraryFolderPath.path) {
            _ = FileIO.createDirectoryIfNeeded(at: audioLibraryFolderPath)
        }
    }

    func saveCurrentBook(book: any RunAndReadBook, onSave: @escaping () -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            do {
                if let b = book as? Book {
                    let data = try JSONEncoder().encode(book.id)
                    try FileIO.writeAtomic(data: data, to: self.currentBookIdPath)
                    DispatchQueue.main.async {
                        self.currentBookId = b.id
                        self.currentBook = b
                        onSave()
                        self.inProgress = false
                    }
                } else if let b = book as? AudioBook {
                    let data = try JSONEncoder().encode(b.id)
                    try FileIO.writeAtomic(data: data, to: self.currentBookIdPath)
                    DispatchQueue.main.async {
                        self.currentBookId = b.id
                        self.currentBook = b
                        onSave()
                        self.inProgress = false
                    }
                }
            } catch {
                AppLogger.persistence.error("Failed to save current book ID at \(self.currentBookIdPath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.inProgress = false
                }
            }
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.currentBook = nil
            self.currentBookId = nil
            self.plainTextData = []
            self.authorData = ""
            self.titleData = ""
        }
    }

    func deleteCurrentBook(onDelete: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.inProgress = true
        }
        DispatchQueue.global(qos: .background).async { [self] in
            do {
                if fileManager.fileExists(atPath: self.currentBookIdPath.path) {
                    try FileIO.removeItem(at: currentBookIdPath)
                }
            } catch {
                AppLogger.persistence.error("Failed to delete current book ID at \(self.currentBookIdPath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async {
                self.currentBook = nil
                self.currentBookId = nil
                self.audioPath = nil
                self.plainTextData = []
                self.authorData = ""
                self.titleData = ""
                onDelete()
                self.inProgress = false
            }
        }

    }

    // Issue 1 fix: converted from AnyPublisher (subscribed on background thread, data race on cancellables)
    // to async — runs on the cooperative thread pool, no Combine subscription needed.
    private func loadCurrentBookId() async -> String? {
        do {
            let data = try FileIO.readData(at: currentBookIdPath)
            return try JSONDecoder().decode(String?.self, from: data)
        } catch {
            AppLogger.persistence.error("Failed to load current book ID at \(self.currentBookIdPath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func saveBookToLibrary(book: Book, completion: @escaping (Result<URL, Error>) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            let bookFilePath = self.libraryFolderPath.appendingPathComponent("\(book.id).json")
            do {
                let data = try JSONEncoder().encode(book)
                try FileIO.writeAtomic(data: data, to: bookFilePath)
                DispatchQueue.main.async {
                    completion(.success(bookFilePath))
                    self.inProgress = false
                }
            } catch {
                AppLogger.persistence.error("Failed to save book to library at \(bookFilePath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                    self.inProgress = false
                }
            }
        }
    }
    
    func saveAudioBookToLibrary(book: AudioBook, completion: @escaping (Result<URL, Error>) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            let bookFilePath = self.audioLibraryFolderPath.appendingPathComponent("\(book.id).json")
            do {
                let data = try JSONEncoder().encode(book)
                try FileIO.writeAtomic(data: data, to: bookFilePath)
                DispatchQueue.main.async {
                    completion(.success(bookFilePath))
                    self.inProgress = false
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                    self.inProgress = false
                }
            }
        }
    }

    func deleteBookFromLibrary(book: any RunAndReadBook, completion: @escaping (Result<Void, Error>) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            let bookFilePath = if book.playerType() == .audio {
                 self.audioLibraryFolderPath.appendingPathComponent("\(book.id).json")
            } else {
                 self.libraryFolderPath.appendingPathComponent("\(book.id).json")
            }
            do {
                if FileManager.default.fileExists(atPath: bookFilePath.path) {
                    try FileIO.removeItem(at: bookFilePath)
                }
                //TODO: remove audio file
                self.deleteCurrentBook {
                    DispatchQueue.main.async {
                        completion(.success(()))
                        self.inProgress = false
                    }
                }
            } catch {
                AppLogger.persistence.error("Failed to delete book from library at \(bookFilePath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                    self.inProgress = false
                }
            }
        }
    }
    
    func deleteAudioBookFromLibrary(book: AudioBook, completion: @escaping (Result<Void, Error>) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let bookFilePath = self.audioLibraryFolderPath.appendingPathComponent("\(book.id).json")
            
            do {
                // Remove the JSON metadata file
                if fileManager.fileExists(atPath: bookFilePath.path) {
                    try FileIO.removeItem(at: bookFilePath)
                }
                
                // Remove the audio file
                if let audioFilePath = book.pathToAudio(), fileManager.fileExists(atPath: audioFilePath.path) {
                    try FileIO.removeItem(at: audioFilePath)
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                    self.inProgress = false
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                    self.inProgress = false
                }
            }
        }
    }

    // Issue 1 fix: converted from AnyPublisher to async.
    private func loadBookFromLibrary(id: String) async -> (any RunAndReadBook)? {
        let bookFilePath1 = libraryFolderPath.appendingPathComponent("\(id).json")
        let bookFilePath2 = audioLibraryFolderPath.appendingPathComponent("\(id).json")
        if fileManager.fileExists(atPath: bookFilePath1.path()) {
            do {
                let data = try FileIO.readData(at: bookFilePath1)
                return try JSONDecoder().decode(Book.self, from: data)
            } catch {
                AppLogger.persistence.error("Failed to load text book at \(bookFilePath1.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        } else if fileManager.fileExists(atPath: bookFilePath2.path()) {
            do {
                let data = try FileIO.readData(at: bookFilePath2)
                return try JSONDecoder().decode(AudioBook.self, from: data)
            } catch {
                AppLogger.persistence.error("Failed to load audio book at \(bookFilePath2.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        return nil
    }

    // Issue 1 fix: converted from AnyPublisher to async.
    private func loadLibrary() async -> [any RunAndReadBook] {
        do {
            let file1URLs = try fileManager.contentsOfDirectory(at: libraryFolderPath, includingPropertiesForKeys: nil)
            let file2URLs = try fileManager.contentsOfDirectory(at: audioLibraryFolderPath, includingPropertiesForKeys: nil)
            var books: [any RunAndReadBook] = []

            for fileURL in file1URLs {
                do {
                    let data = try FileIO.readData(at: fileURL)
                    if let book = try? JSONDecoder().decode(Book.self, from: data) {
                        books.append(book)
                    } else {
                        AppLogger.persistence.debug("Skipping unreadable text book at \(fileURL.lastPathComponent, privacy: .public)")
                    }
                } catch {
                    // readData logs already; continue
                }
            }
            for fileURL in file2URLs {
                do {
                    let data = try FileIO.readData(at: fileURL)
                    if let book = try? JSONDecoder().decode(AudioBook.self, from: data) {
                        books.append(book)
                    } else {
                        AppLogger.persistence.debug("Skipping unreadable audio book at \(fileURL.lastPathComponent, privacy: .public)")
                    }
                } catch {
                    // readData logs already; continue
                }
            }
            return books
        } catch {
            AppLogger.persistence.error("Failed to enumerate library folders: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func addABookmark() {
        if let book = self.currentBook {
            book.bookmarks.insert(Bookmark(position: book.lastPosition), at: 0)
        }
    }

    func updateLastPosition(for bookId: String, newPosition: Int) {
        self.currentBook?.lastPosition = newPosition
        self.currentBook?.created = Date.now
    }

    func persist(completion: @escaping (Result<URL, Error>) -> Void) {
        if let b = currentBook as? Book{
            saveBookToLibrary(book: b, completion: completion)
        } else if let b = currentBook as? AudioBook{
            saveAudioBookToLibrary(book: b, completion: completion)
        }
    }

    func updateBookMetadata(for bookId: String, title: String, author: String, language: Locale, voice: AVSpeechSynthesisVoice, voiceRate: Float, onSave: @escaping () -> Void) {
        guard let index = library.firstIndex(where: { $0.id == bookId }) else {
            return
        }
        
        if let book = library[index] as? Book { // Safely downcast to TextBook
            book.title = title
            book.author = author
            book.language = language
            book.voice = voice
            book.voiceRate = voiceRate
            
            saveBookToLibrary(book: book) { _ in
                onSave()
            }
        } else if let audioBook = library[index] as? AudioBook {
            audioBook.title = title
            audioBook.author = author
            audioBook.voiceRate = voiceRate
            saveAudioBookToLibrary(book: audioBook) { _ in
                onSave()
            }
        }
    }

    // Issue 1 fix: cancellables removed — all five methods below now use Task.detached
    // so nothing is ever stored in a shared Set from a background thread.

    func loadBooks(onLoaded: @escaping () -> Void) {
        inProgress = true
        library.removeAll()
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let books = await self.loadLibrary()
            await MainActor.run {
                self.library = books.sorted(by: { $0.created > $1.created })
                if self.library.isEmpty {
                    self.loadDefaultLibrary(onLoaded: onLoaded)
                } else {
                    self.inProgress = false
                    onLoaded()
                }
            }
        }
    }

    func loadDefaultLibrary(onLoaded: @escaping () -> Void) {
        libraryDefault.removeAll()
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let fileManager = FileManager.default

            guard let folderURL = Bundle.main.resourceURL else {
                AppLogger.persistence.error("Bundle resource URL not found")
                await MainActor.run { self.inProgress = false }
                return
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                for fileURL in contents {
                    if fileURL.pathExtension == "json" {
                        do {
                            let data = try FileIO.readData(at: fileURL)
                            if let book = try? JSONDecoder().decode(Book.self, from: data) {
                                let bookFilePath = self.libraryFolderPath.appendingPathComponent("\(book.id).json")
                                do {
                                    let bookData = try JSONEncoder().encode(book)
                                    try FileIO.writeAtomic(data: bookData, to: bookFilePath)
                                } catch {
                                    AppLogger.persistence.error("Failed to seed default book \(fileURL.lastPathComponent, privacy: .public) to \(bookFilePath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                }
                            }
                        } catch {
                            AppLogger.persistence.error("Failed to read bundled file \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            await MainActor.run { self.inProgress = false }
                        }
                    }
                }
                let books = await self.loadLibrary()
                await MainActor.run {
                    self.library = books.sorted(by: { $0.created > $1.created })
                    self.inProgress = false
                    onLoaded()
                }
            } catch {
                AppLogger.persistence.error("Failed to enumerate bundle directory: \(error.localizedDescription, privacy: .public)")
                await MainActor.run { self.inProgress = false }
            }
        }
    }

    // Issue 1 fix: no more nested Combine sinks from background thread.
    // Issue 2 fix: onLoaded() is now always called regardless of whether a saved book ID exists.
    func loadCurrentBook(onLoaded: @escaping () -> Void) {
        inProgress = true
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let bookId = await self.loadCurrentBookId()
            let book: (any RunAndReadBook)? = if let id = bookId {
                await self.loadBookFromLibrary(id: id)
            } else {
                nil
            }
            await MainActor.run {
                self.audioPath = nil
                self.currentBookId = bookId
                self.currentBook = book
                onLoaded()
                self.inProgress = false
            }
        }
    }

    func loadText(from fileURL: URL, onLoaded: @escaping (BookFile?, String?) -> Void) {
        Task.detached(priority: .userInitiated) {
            do {
                let bookFile = try await FileTextExtractor.extractText(from: fileURL)
                await MainActor.run { onLoaded(bookFile, nil) }
            } catch {
                let message = "Error extracting text: \(error)"
                print(message)
                await MainActor.run { onLoaded(nil, message) }
            }
        }
    }

    func loadText2(from fileURL: URL, onLoaded: @escaping (BookFile?, String?) -> Void) {
        inProgress = true
        Task.detached(priority: .userInitiated) {
            do {
                let bookFile = try await FileTextExtractor.extractTextFromWeb(from: fileURL)
                await MainActor.run { onLoaded(bookFile, nil) }
            } catch {
                let message = "Error extracting text: \(error)"
                print(message)
                await MainActor.run { onLoaded(nil, message) }
            }
        }
    }
}
