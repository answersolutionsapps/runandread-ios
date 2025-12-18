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

    private func loadCurrentBookId() -> AnyPublisher<String?, Never> {
        Future { promise in
            do {
                let data = try FileIO.readData(at: self.currentBookIdPath)
                let bookId = try JSONDecoder().decode(String?.self, from: data)
                promise(.success(bookId))
            } catch {
                AppLogger.persistence.error("Failed to load current book ID at \(self.currentBookIdPath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                promise(.success(nil))
            }
        }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
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

    private func loadBookFromLibrary(id: String) -> AnyPublisher<(any RunAndReadBook)?, Never> {
        Future { promise in
            let bookFilePath1 = self.libraryFolderPath.appendingPathComponent("\(id).json")
            let bookFilePath2 = self.audioLibraryFolderPath.appendingPathComponent("\(id).json")
            if self.fileManager.fileExists(atPath: bookFilePath1.path()) {
                do {
                    let data = try FileIO.readData(at: bookFilePath1)
                    let decoder = JSONDecoder()
                    let book = try decoder.decode(Book.self, from: data)
                    promise(.success(book))
                } catch {
                    AppLogger.persistence.error("Failed to load text book at \(bookFilePath1.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    promise(.success(nil))
                }
            } else if self.fileManager.fileExists(atPath: bookFilePath2.path()) {
                do {
                    let data = try FileIO.readData(at: bookFilePath2)
                    let decoder = JSONDecoder()
                    let book = try decoder.decode(AudioBook.self, from: data)
                    promise(.success(book))
                } catch {
                    AppLogger.persistence.error("Failed to load audio book at \(bookFilePath2.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    promise(.success(nil))
                }
            }
        }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
    }

    private func loadLibrary() -> AnyPublisher<[any RunAndReadBook], Never> {
        Future { promise in
            do {
                let file1URLs = try self.fileManager.contentsOfDirectory(at: self.libraryFolderPath, includingPropertiesForKeys: nil)
                let file2URLs = try self.fileManager.contentsOfDirectory(at: self.audioLibraryFolderPath, includingPropertiesForKeys: nil)
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
                promise(.success(books))
            } catch {
                AppLogger.persistence.error("Failed to enumerate library folders: \(error.localizedDescription, privacy: .public)")
                promise(.success([]))
            }
        }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
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

    private var cancellables = Set<AnyCancellable>()

    func loadBooks(onLoaded: @escaping () -> Void) {
        inProgress = true
        self.library.removeAll()
        DispatchQueue.global(qos: .background).async {
            self.loadLibrary()
                    .sink { books in
                        DispatchQueue.main.async {
                            self.library = books.sorted(by: { $0.created > $1.created })
                            if self.library.isEmpty {
                                self.loadDefaultLibrary(onLoaded: onLoaded)
                            } else {
                                self.inProgress = false
                                onLoaded()
                            }
                        }
                    }
                    .store(in: &self.cancellables)
        }
    }

    func loadDefaultLibrary(onLoaded: @escaping () -> Void) {
        self.libraryDefault.removeAll()
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default

            // Get the URL of the root resource folder in the app bundle
            if let folderURL = Bundle.main.resourceURL {
                do {
                    // List the contents of the folder
                    let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

                    // Process each file
                    for fileURL in contents {
                        if fileURL.pathExtension == "json" { // Filter for JSON files
                            do {
                                let data = try FileIO.readData(at: fileURL)
                                if let book = try? JSONDecoder().decode(Book.self, from: data) {
                                    let bookFilePath = self.libraryFolderPath.appendingPathComponent("\(book.id).json")
                                    do {
                                        let data = try JSONEncoder().encode(book)
                                        try FileIO.writeAtomic(data: data, to: bookFilePath)
                                    } catch {
                                        AppLogger.persistence.error("Failed to seed default book \(fileURL.lastPathComponent, privacy: .public) to \(bookFilePath.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                    }
                                }
                            } catch {
                                AppLogger.persistence.error("Failed to read bundled file \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                DispatchQueue.main.async {
                                    self.inProgress = false
                                }
                            }
                        }
                    }
                    self.loadLibrary()
                            .sink { books in
                                DispatchQueue.main.async {
                                    self.library = books.sorted(by: { $0.created > $1.created })
                                    self.inProgress = false
                                    onLoaded()
                                }
                            }
                            .store(in: &self.cancellables)
                } catch {
                    print("Error reading directory: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.inProgress = false
                    }
                }
            } else {
                print("Folder not found in the app bundle.")
                DispatchQueue.main.async {
                    self.inProgress = false
                }
            }
        }
    }


    func loadCurrentBook(onLoaded: @escaping () -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            self.loadCurrentBookId()
                    .sink { bookId in

                        if let testBookId = bookId {
                            self.loadBookFromLibrary(id: testBookId).sink { book in
                                        DispatchQueue.main.async {
                                            self.audioPath = nil
                                            self.currentBookId = bookId
                                            self.currentBook = book
                                            onLoaded()
                                            self.inProgress = false

                                        }
                                    }
                                    .store(in: &self.cancellables)
                        }
                    }
                    .store(in: &self.cancellables)
        }
    }

    func loadText(from fileURL: URL, onLoaded: @escaping (BookFile?, String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            FileTextExtractor.extractText(from: fileURL)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Error extracting text: \(error)")
                            onLoaded(nil, "Error extracting text: \(error)") // Pass nil to signal failure
                        }
                    }, receiveValue: { bookFile in
                        onLoaded(bookFile, nil)
                    })
                    .store(in: &self.cancellables)
        }
    }

    func loadText2(from fileURL: URL, onLoaded: @escaping (BookFile?, String?) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            FileTextExtractor.extractTextFromWeb(from: fileURL)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error extracting text: \(error)")
                        onLoaded(nil, "Error extracting text: \(error)") // Pass nil to signal failure
                    }
                }, receiveValue: { bookFile in
                    onLoaded(bookFile, nil)
                })
                .store(in: &self.cancellables)
        }
    }
}
