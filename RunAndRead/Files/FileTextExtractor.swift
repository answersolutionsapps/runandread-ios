//
//  FileTextExtractor.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/29/25.
//

import Combine
import Foundation
import EPUBKit
import SwiftSoup
import PDFKit
import ZIPFoundation

struct AudioBookFileJson: Codable {
    let title: String
    let author: String
    let text: [TextPart]
    
    let language: String
    let rate: Float
    let voice: String
    let model: String
    let book_source: String
}


struct BookFile: Codable {
    let title: String
    let author: String
    let content: [String]
    let audioPath: String
    let text: [TextPart]
    
    let language: String
    let rate: Float
    let voice: String
    let model: String
    let book_source: String
}

enum ExtractionError: Error {
    case invalidFileName
    case zipExtractionFailed
    case missingFiles
    case invalidJSON
    case fileCopyFailed
}

class FileTextExtractor {

    static func extractTextFromWeb(from fileURL: URL) -> AnyPublisher<BookFile, Error> {
        Future { promise in
            do {
                let book: BookFile = try extractTextFromHTML(url: fileURL)
                promise(.success(book))
            } catch {
                promise(.failure(error))
            }
        }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
    }

    static func extractText(from fileURL: URL) -> AnyPublisher<BookFile, Error> {
        Future { promise in
            do {
                var book: BookFile
                switch fileURL.pathExtension.lowercased() {
                case "randr":
                    book = try extractAudioBookFromRANDR(fileURL)
                case "epub":
                    book = try extractTextFromEPUB(fileURL)
                case "txt":
                    let text = try String(contentsOf: fileURL, encoding: .utf8)
                    book = BookFile(
                        title: "",
                        author: "",
                        content: [text],
                        audioPath: "",
                        text: [],
                        language: "en_US",
                        rate: 1.0,
                        voice: "Unknown",
                        model: "Unknown",
                        book_source: "Unknown"
                    )
                case "pdf":
                    book = try extractTextFromPDF(fileURL)
                default:
                    throw NSError(domain: "Unsupported file format", code: 0, userInfo: nil)
                }
                promise(.success(book))
            } catch {
                promise(.failure(error))
            }
        }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
    }
    
    static func extractAudioBookFromRANDR(_ fileURL: URL) throws -> BookFile {
        guard !fileURL.absoluteString.contains(" ") else {
            throw NSError(domain: "FileError", code: 236, userInfo: [NSLocalizedDescriptionKey: "Spaces in file name"])
        }

        let fileName = fileURL.lastPathComponent
        let fileNameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
        let rootDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let extractionDirectory = rootDirectory.appendingPathComponent("temp_extracted_\(fileNameWithoutExtension)")
        
        let fileManager = FileManager.default
        
        // Ensure clean extraction directory
        if fileManager.fileExists(atPath: extractionDirectory.path) {
            do {
                try fileManager.removeItem(at: extractionDirectory)
            } catch {
                throw NSError(domain: "FileError", code: 237, userInfo: [NSLocalizedDescriptionKey: "Failed to remove existing extraction directory: \(error)"])
            }
        }

        do {
            try fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: fileURL, to: extractionDirectory)
        } catch {
            throw ExtractionError.zipExtractionFailed
        }

        let extractedFiles = try fileManager.contentsOfDirectory(at: extractionDirectory.appendingPathComponent(fileName), includingPropertiesForKeys: nil)

        guard let bookJSONURL = extractedFiles.first(where: { $0.lastPathComponent == "book.json" }),
              let audioFileURL = extractedFiles.first(where: { $0.lastPathComponent == "audio.mp3" }) else {
            try? fileManager.removeItem(at: extractionDirectory)
            throw ExtractionError.missingFiles
        }

        let jsonData = try Data(contentsOf: bookJSONURL)
        var book: AudioBookFileJson? = nil
        do {
            book = try JSONDecoder().decode(AudioBookFileJson.self, from: jsonData)

            // Use book.title, book.text, etc.
        } catch {
            try? fileManager.removeItem(at: extractionDirectory)
            print(error)
            throw ExtractionError.invalidJSON
        }
//        let decoder = JSONDecoder()
//        
//        let parsedBook: [String: Any]
//        do {
//            parsedBook = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
//        } catch {
//            try? fileManager.removeItem(at: extractionDirectory)
//            throw ExtractionError.invalidJSON
//        }

//        guard let title = parsedBook["title"] as? String,
//              let author = parsedBook["author"] as? String,
//              let language = parsedBook["language"] as? String,
//              let rate = parsedBook["rate"] as? Float,
//              let voice = parsedBook["voice"] as? String,
//              let model = parsedBook["model"] as? String,
//              let book_source = parsedBook["book_source"] as? String,
//              guard let textPartsArray = parsedBook["text"] as? [[String: Any]] else {
//            try? fileManager.removeItem(at: extractionDirectory)
//            throw ExtractionError.invalidJSON
//        }
//        let textParts: [TextPart] = textPartsArray.compactMap { dict in
//            guard let start_time_ms = dict["start_time_ms"] as? Int,
//                  let text = dict["text"] as? String else {
//                return nil
//            }
//            return TextPart(start_time_ms: start_time_ms, text: text)
//        }

        let audioDestination = rootDirectory.appendingPathComponent("audio/\(fileNameWithoutExtension)/")
        let finalAudioPath = audioDestination.appendingPathComponent("audio.mp3")

        do {
            try fileManager.createDirectory(at: audioDestination, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: finalAudioPath.path) {
                try fileManager.removeItem(at: finalAudioPath)
            }
            try fileManager.moveItem(at: audioFileURL, to: finalAudioPath)
        } catch {
            try? fileManager.removeItem(at: extractionDirectory)
            throw ExtractionError.fileCopyFailed
        }

        // Clean up extraction directory
        do {
            try fileManager.removeItem(at: extractionDirectory)
        } catch {
            throw NSError(domain: "FileError", code: 238, userInfo: [NSLocalizedDescriptionKey: "Failed to remove extraction directory: \(error)"])
        }

        return BookFile(
            title: book!.title,
            author: book!.author,
            content: [],
            audioPath: "audio/\(fileNameWithoutExtension)/audio.mp3",
            text: book!.text,
            language: book!.language,
            rate: book!.rate,
            voice: book!.voice,
            model: book!.model,
            book_source: book!.book_source
        )
    }

    
//    static func extractAudioBookFromRANDR(_ fileURL: URL) throws -> BookFile {
//        guard !fileURL.absoluteString.contains(" ") else {
//            throw NSError(domain: "FileError", code: 236, userInfo: [NSLocalizedDescriptionKey: "Spaces in file name"])
//        }
//        let fileName = fileURL.lastPathComponent
//        let fileNameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
//        let rootDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let extractionDirectory = rootDirectory.appendingPathComponent("temp_extracted_\(fileNameWithoutExtension)")
//        // Create extraction directory if needed
//        try? FileManager.default.removeItem(at: extractionDirectory)
//        try? FileManager.default.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
//        // Extract the zip file
//        // Extract ZIP archive (RANDR file)
//            do {
//                
//                try FileManager.default.unzipItem(at: fileURL, to: extractionDirectory)
//                print("✅ Extraction complete: \(extractionDirectory.absoluteString)")
//            } catch {
//                print("❌ ZIP extraction error: \(error)")
//                throw ExtractionError.zipExtractionFailed
//            }
//        // Locate the extracted files
//        // temp_extracted_pg2680/
//        //  |--pg2680.randr
//        //        |--book.json
//        //        |--audio.mp3
//        let extractedFiles = try FileManager.default.contentsOfDirectory(at: extractionDirectory.appendingPathComponent(fileName), includingPropertiesForKeys: nil)
//        guard let bookJSONURL = extractedFiles.first(where: { $0.lastPathComponent == "book.json" }),
//              let audioFileURL = extractedFiles.first(where: { $0.lastPathComponent == "audio.mp3" }) else {
//            
//            do {
//                try FileManager.default.removeItem(at: extractionDirectory)
//            } catch {
//            }
//            
//            throw ExtractionError.missingFiles
//        }
//
//        // Read and parse the book.json
//        let jsonData = try Data(contentsOf: bookJSONURL)
//        let decoder = JSONDecoder()
//        let parsedBook: [String: Any]
//        
//        do {
//            parsedBook = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
//        } catch {
//            do {
//                try FileManager.default.removeItem(at: extractionDirectory)
//            } catch {
//            }
//            throw ExtractionError.invalidJSON
//        }
//
//        // Extract book properties
//        guard let title = parsedBook["title"] as? String,
//              let author = parsedBook["author"] as? String,
//              let language = parsedBook["language"] as? String,
//              let rate = parsedBook["rate"] as? Float,
//              let voice = parsedBook["voice"] as? String,
//              let model = parsedBook["model"] as? String,
//              let book_source = parsedBook["book_source"] as? String,
//              let textPartsArray = parsedBook["text"] as? [[String: Any]] else {
//            do {
//                try FileManager.default.removeItem(at: extractionDirectory)
//            } catch {
//            }
//            throw ExtractionError.invalidJSON
//        }
//
//        let textParts: [TextPart] = textPartsArray.compactMap { dict in
//            guard let start_time_ms = dict["start_time_ms"] as? Int,
//                  let text = dict["text"] as? String else { return nil }
//            return TextPart(start_time_ms: start_time_ms, text: text)
//        }
//
//        // Move audio file to a permanent location
//        let audioPath = "audio/\(fileNameWithoutExtension)/audio.mp3"
//        let audioDestination = rootDirectory.appendingPathComponent("audio/\(fileNameWithoutExtension)/")
//        try FileManager.default.createDirectory(at: audioDestination, withIntermediateDirectories: true)
//        let finalAudioPath = audioDestination.appendingPathComponent("audio.mp3")
//        do {
//            try FileManager.default.removeItem(at: finalAudioPath)
//        } catch {
//        }
//        do {
//            try FileManager.default.moveItem(at: audioFileURL, to: finalAudioPath)
//        } catch {
//            throw ExtractionError.fileCopyFailed
//        }
//
//        // Clean up extraction directory
//        try? FileManager.default.removeItem(at: extractionDirectory)
//
//        // Return extracted book file info
//        return BookFile(
//            title: title,
//            author: author,
//            content: [],
//            audioPath: audioPath,
//            text: textParts,
//            language: language,
//            rate: rate,
//            voice: voice,
//            model: model,
//            book_source: book_source
//        )
//    }

    static func extractContent(document: EPUBDocument?) -> [String] {
        guard let document = document else {
            print("Unable to find the EPUB file.")
            return []
        }
        guard let bundle = Bundle(path: document.contentDirectory.path()) else {
            print("EPUB unresolved.")
            return []
        }
        let contentFiles = document.spine.items.compactMap { item in
            if let manifestItem = document.manifest.items.first(where: { (_, value) in item.idref == value.id }) {
                return bundle.bundleURL.appendingPathComponent(manifestItem.value.path)
            } else {
                return nil
            }
        }

        let strippedSections: [String] = [
            "title", "section", "cover", "colophon", "imprint", "endnote", "copyright"
        ]
//        TimeLogger.log("onFileSelected", message: "extractContent1")
        return contentFiles
                .filter { url in
                    let lastPathComponent = url.deletingPathExtension().lastPathComponent.lowercased()
                    return !strippedSections.contains(where: lastPathComponent.contains)
                }
                .flatMap { url in
                    do {
                        return try SwiftSoup
                                .parse(String(contentsOf: url, encoding: .utf8))
                                .select("p,h1,h2,h3,h4,h5,h6,pre")
                                .compactMap {
                                    try $0.text().trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                                .filter {
                                    !$0.isEmpty
                                }
                    } catch {
                        print("XML File not loaded")
                        return []
                    }
                }
    }

    static func extractTextFromEPUB(_ fileURL: URL) throws -> BookFile {
//        TimeLogger.log("onFileSelected", message: "extractTextFromEPUB")
        guard !fileURL.absoluteString.contains(" ") else {
            throw NSError(domain: "FileError", code: 236, userInfo: [NSLocalizedDescriptionKey: "Spaces in file name"])
        }

        guard let document = EPUBDocument(url: fileURL) else {
            throw NSError(domain: "EPUBError", code: 235, userInfo: [NSLocalizedDescriptionKey: "Broken EPUB document"])
        }
//        TimeLogger.log("onFileSelected", message: "BookFile")
        let book = BookFile(
                title: document.title ?? "Unknown",
                author: document.author ?? "Unknown",
                content: extractContent(document: document),
                audioPath: "",
                text: [],
                language: "en_US",
                rate: 1.0,
                voice: "Unknown",
                model: "Unknown",
                book_source: "Unknown"
        )
        let fileManager = FileManager.default
        let tempFolderURL = document.directory
//        TimeLogger.log("onFileSelected", message: "extractContent2")
        do {
            // Try to delete the folder
            try fileManager.removeItem(at: tempFolderURL)
//            print("Delete the temporary folder: \(tempFolderURL)")
        } catch {
            // Handle any errors that might occur during deletion
            print("Failed to delete the temporary folder: \(error)")
        }

        return book

    }

    static func extractTextFromPDF(_ fileURL: URL) throws -> BookFile {
//        TimeLogger.log("onFileSelected", message: "extractTextFromPDF1")
        guard let document = PDFDocument(url: fileURL) else {
            throw NSError(domain: "PDFError", code: 237, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF document"])
        }
//        TimeLogger.log("onFileSelected", message: "extractTextFromPDF2")
        var content = [String]()
        let pageCount = document.pageCount
        for pageIndex in 0..<pageCount {
            if let page = document.page(at: pageIndex) {
                let pageText = page.string ?? ""
                content.append(pageText)
//                TimeLogger.log("onFileSelected", message: "content.append(pageText)")
            }
        }
//        TimeLogger.log("onFileSelected", message: "extractTextFromPDF3")
        let title = document.documentAttributes?[AnyHashable("Title")] as? String ?? "Unknown"
        let author = document.documentAttributes?[AnyHashable("Author")] as? String ?? "Unknown"


        return BookFile(
                title: title,
                author: author,
                content: content, audioPath: "", text: [],
                language: "en_US",
                rate: 1.0,
                voice: "Unknown",
                model: "Unknown",
                book_source: "Unknown"
        )
    }

    static func extractTextFromHTML(url: URL) throws -> BookFile {
        let semaphore = DispatchSemaphore(value: 0)
        var content = [String]()
        var title = "Unknown"
        var author = "Unknown"

        // Download the HTML content from the URL
        URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("Failed to download HTML: \(error.localizedDescription)")
                        semaphore.signal()
                        return
                    }

                    guard let data = data else {
                        print("No data received from the URL.")
                        semaphore.signal()
                        return
                    }

                    // Log the raw data for debugging purposes
                    print("Raw HTML Data (first 100 bytes): \(data.prefix(100))")

                    // Try to decode the content with UTF-8 first
                    var htmlContent: String
                    if let decodedHTML = String(data: data, encoding: .utf8) {
                        htmlContent = decodedHTML
                        print("Successfully decoded using UTF-8 encoding.")
                    } else {
                        // If UTF-8 decoding fails, try using the response's suggested encoding
//                if let encoding = (response as? HTTPURLResponse)?.textEncodingName,
//                   let suggestedEncoding = String.Encoding(ianaCharsetName: encoding) {
//                    htmlContent = String(data: data, encoding: suggestedEncoding) ?? ""
//                    print("Decoded using encoding from response: \(encoding)")
//                } else {
                        // Default to a few common encodings if nothing is found
                        htmlContent = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                        print("Tried UTF-8 and ISO-8859-1 encoding.")
//                }
                    }

                    if htmlContent.isEmpty {
                        print("Failed to decode HTML content.")
                        semaphore.signal()
                        return
                    }


                    do {
                        // Use SwiftSoup to parse the HTML content
                        let document = try SwiftSoup.parse(htmlContent)
                        title = try document.title()
                        author = try document.select("meta[name=author]").attr("content")

                        // Extract text from the page
                        content = try document
                                .select("p,h1,h2,h3,h4,h5,h6,pre")
                                .compactMap {
                                    try? $0.text().trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                                .filter {
                                    !$0.isEmpty
                                }
                    } catch {
                        print("Failed to parse HTML: \(error.localizedDescription)")
                    }
                    semaphore.signal()
                }
                .resume()

        // Wait for the data task to finish
        semaphore.wait()

        return BookFile(
                title: title,
                author: author,
                content: content,
                audioPath: "",
                text: [],
                language: "en_US",
                rate: 1.0,
                voice: "Unknown",
                model: "Unknown",
                book_source: "Unknown"
        )
    }
}
