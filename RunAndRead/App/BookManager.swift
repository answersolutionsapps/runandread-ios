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

    @Published var library: [Book] = []
    @Published var libraryDefault: [Book] = []
    @Published var currentBookId: String?
    @Published var inProgress = false
    @Published var currentBook: Book?
    
    @Published var plainTextData: [String] = []
    @Published var authorData: String = ""
    @Published var titleData: String = ""
    
    public var openedFilePath: URL? = nil
    
    init() {
        rootDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        currentBookIdPath = rootDirectory.appendingPathComponent("currentBookId.json")
        libraryFolderPath = rootDirectory.appendingPathComponent("library")
        
        if !fileManager.fileExists(atPath: libraryFolderPath.path) {
            try? fileManager.createDirectory(at: libraryFolderPath, withIntermediateDirectories: true, attributes: nil)
        }
    }

    func saveCurrentBook(book: Book, onSave: @escaping () -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(book.id)
                try data.write(to: self.currentBookIdPath)
                DispatchQueue.main.async {
                    self.currentBookId = book.id
                    self.currentBook = book
                    onSave()
                    self.inProgress = false
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
    
    func deleteBookFromLibrary(book: Book, completion: @escaping (Result<Void, Error>) -> Void) {
        inProgress = true
        DispatchQueue.global(qos: .background).async {
            let bookFilePath = self.libraryFolderPath.appendingPathComponent("\(book.id).json")
            do {
                if FileManager.default.fileExists(atPath: bookFilePath.path) {
                    try FileManager.default.removeItem(at: bookFilePath)
                }
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

    
    private func loadBookFromLibrary(id: String) -> AnyPublisher<Book?, Never> {
        Future { promise in
            let bookFilePath = self.libraryFolderPath.appendingPathComponent("\(id).json")
            do {
                let data = try Data(contentsOf: bookFilePath)
                let decoder = JSONDecoder()
                let book = try decoder.decode(Book.self, from: data)
                    promise(.success(book))
                } catch {
                    print("Error loading book: \(error)")
                    promise(.success(nil))
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        }
    
    private func loadLibrary() -> AnyPublisher<[Book], Never> {
        Future { promise in
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(at: self.libraryFolderPath, includingPropertiesForKeys: nil)
                var books: [Book] = []
                
                for fileURL in fileURLs {
                    let data = try Data(contentsOf: fileURL)
                    if let book = try? JSONDecoder().decode(Book.self, from: data) {
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
            book.bookmarks.append(Bookmark(voiceRate: book.voiceRate, position: book.lastPosition))
        }
    }
    
    func updateLastPosition(for bookId: String, newPosition: Int) {
        currentBook?.lastPosition = newPosition
    }
    
//    func updateLastPositionWith(elapsedTime: Float) {
//        if let book = currentBook {
//            book.lastPosition = Int(elapsedTime)//book.approximateLastPosition(from: elapsedTime)
//        }
//    }
    
    func persist(completion: @escaping (Result<URL, Error>) -> Void) {
        if let b = currentBook {
            saveBookToLibrary(book: b, completion: completion)
        }
    }
    
    func updateBookMetadata(for bookId: String, title: String, author: String, language: Locale, voice: AVSpeechSynthesisVoice, voiceRate: Float, onSave: @escaping () -> Void) {
        guard let index = library.firstIndex(where: { $0.id == bookId }) else { return }
        library[index].title = title
        library[index].author = author
        library[index].language = language
        library[index].voice = voice
        library[index].voiceRate = voiceRate
        saveBookToLibrary(book: library[index]) { _ in onSave() }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadBooks() {
        inProgress = true
        self.library.removeAll()
        DispatchQueue.global(qos: .background).async {
            self.loadLibrary()
                .sink { books in
                    DispatchQueue.main.async {
                        self.library = books.sorted(by: { $0.created > $1.created })
                        if self.library.isEmpty {
                            self.loadDefaultLibrary()
                        } else {
                            self.inProgress = false
                        }
                    }
                }
                .store(in: &self.cancellables)
        }
        
    }
    
    func loadDefaultLibrary() {
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
    
    func loadText(from fileURL: URL, onLoaded: @escaping (BookFile?) -> Void) {
        inProgress = true
        FileTextExtractor.extractText(from: fileURL)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
               if case .failure(let error) = completion {
                  print("Error extracting text: \(error)")
                   onLoaded(nil) // Pass nil to signal failure
                   self.inProgress = false
               }
            }, receiveValue: { bookFile in
               onLoaded(bookFile)
                self.inProgress = false
            }).store(in: &cancellables)
    }
    
    func loadText2(from fileURL: URL, onLoaded: @escaping (BookFile?) -> Void) {
        inProgress = true
        FileTextExtractor.extractTextFromWeb(from: fileURL)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
               if case .failure(let error) = completion {
                  print("Error extracting text: \(error)")
                   onLoaded(nil) // Pass nil to signal failure
                   self.inProgress = false
               }
            }, receiveValue: { bookFile in
               onLoaded(bookFile)
                self.inProgress = false
            }).store(in: &cancellables)
    }
}
