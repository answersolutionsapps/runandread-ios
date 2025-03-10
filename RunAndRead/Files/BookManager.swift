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

    public var openedFilePath: URL? = nil

    init() {
        rootDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        currentBookIdPath = rootDirectory.appendingPathComponent("currentBookId.json")
        libraryFolderPath = rootDirectory.appendingPathComponent("library")
        audioLibraryFolderPath = rootDirectory.appendingPathComponent("audiobooks")

        if !fileManager.fileExists(atPath: libraryFolderPath.path) {
            try? fileManager.createDirectory(at: libraryFolderPath, withIntermediateDirectories: true, attributes: nil)
        }
        if !fileManager.fileExists(atPath: audioLibraryFolderPath.path) {
            try? fileManager.createDirectory(at: audioLibraryFolderPath, withIntermediateDirectories: true, attributes: nil)
        }
    }

    func saveCurrentBook(book: any RunAndReadBook, onSave: @escaping () -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            do {
                if let b = book as? Book {
                    let data = try JSONEncoder().encode(book.id)
                    try data.write(to: self.currentBookIdPath)
                    DispatchQueue.main.async {
                        self.currentBookId = book.id
                        self.currentBook = book
                        onSave()
                        self.inProgress = false
                    }
                } else if let b = book as? AudioBook {
                    let data = try JSONEncoder().encode(b.id)
                    try data.write(to: self.currentBookIdPath)
                    DispatchQueue.main.async {
                        self.currentBookId = book.id
                        self.currentBook = book
                        onSave()
                        self.inProgress = false
                    }
                }
            } catch {
                print("Error saving current book ID: \(error)")
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
                    try fileManager.removeItem(at: currentBookIdPath)
                }
            } catch {
                print("Error deleting current book ID: \(error)")
            }
            DispatchQueue.main.async {
                self.currentBook = nil
                self.currentBookId = nil
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
                let data = try Data(contentsOf: self.currentBookIdPath)
                let bookId = try JSONDecoder().decode(String?.self, from: data)
                promise(.success(bookId))
            } catch {
                print("Error loading current book ID: \(error)")
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
                try data.write(to: bookFilePath)
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
    
    func saveAudioBookToLibrary(book: AudioBook, completion: @escaping (Result<URL, Error>) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            let bookFilePath = self.audioLibraryFolderPath.appendingPathComponent("\(book.id).json")
            do {
                let data = try JSONEncoder().encode(book)
                try data.write(to: bookFilePath)
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
                    try FileManager.default.removeItem(at: bookFilePath)
                }
                //TODO: remove audio file
                self.deleteCurrentBook {
                    DispatchQueue.main.async {
                        completion(.success(()))
                        self.inProgress = false
                    }
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
                    let data = try Data(contentsOf: bookFilePath1)
                    let decoder = JSONDecoder()
                    let book = try decoder.decode(Book.self, from: data)
                    promise(.success(book))
                } catch {
                    print("Error loading book: \(error)")
                    promise(.success(nil))
                }
            } else if self.fileManager.fileExists(atPath: bookFilePath2.path()) {
                do {
                    let data = try Data(contentsOf: bookFilePath2)
                    let decoder = JSONDecoder()
                    let book = try decoder.decode(AudioBook.self, from: data)
                    promise(.success(book))
                } catch {
                    print("Error loading book: \(error)")
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
                    let data = try Data(contentsOf: fileURL)
                    if let book = try? JSONDecoder().decode(Book.self, from: data) {
                        books.append(book)
                    }
                }
                for fileURL in file2URLs {
                    let data = try Data(contentsOf: fileURL)
                    if let book = try? JSONDecoder().decode(AudioBook.self, from: data) {
                        books.append(book)
                    }
                }
                promise(.success(books))
            } catch {
                print("Error loading library: \(error)")
                promise(.success([]))
            }
        }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
    }

    func addABookmark() {
        if let book = currentBook {
            book.bookmarks.insert(Bookmark(position: book.lastPosition), at: 0)
        }
    }

    func updateLastPosition(for bookId: String, newPosition: Int) {
        currentBook?.lastPosition = newPosition
        currentBook?.created = Date.now
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
                                let data = try Data(contentsOf: fileURL)
                                if let book = try? JSONDecoder().decode(Book.self, from: data) {
                                    let bookFilePath = self.libraryFolderPath.appendingPathComponent("\(book.id).json")
                                    do {
                                        let data = try JSONEncoder().encode(book)
                                        try data.write(to: bookFilePath)
                                    } catch {
                                        print("Error JSONEncoder file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                                    }
                                }
                            } catch {
                                print("Error reading file \(fileURL.lastPathComponent): \(error.localizedDescription)")
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
//        DispatchQueue.main.async {
//            self.inProgress = true
//        }
        DispatchQueue.global(qos: .background).async {
            FileTextExtractor.extractText(from: fileURL)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Error extracting text: \(error)")
                            onLoaded(nil, "Error extracting text: \(error)") // Pass nil to signal failure
//                            self.inProgress = false
                        }
                    }, receiveValue: { bookFile in
//                        TimeLogger.log("onFileSelected", message: "FileTextExtractor.onLoaded")
                        onLoaded(bookFile, nil)
//                        self.inProgress = false
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
//                        self.inProgress = false
                    }
                }, receiveValue: { bookFile in
                    onLoaded(bookFile, nil)
//                    self.inProgress = false
                })
                .store(in: &self.cancellables)
        }
    }
}
