//
//  FileTextExtractor.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/29/25.
//

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

    // MARK: - Issue 3 fix: replaced DispatchSemaphore+dataTask with async URLSession.data(from:)
    static func extractTextFromWeb(from fileURL: URL) async throws -> BookFile {
        return try await extractTextFromHTML(url: fileURL)
    }

    // MARK: - Issue 3 fix: converted from AnyPublisher<BookFile,Error> to async throws
    static func extractText(from fileURL: URL) async throws -> BookFile {
        switch fileURL.pathExtension.lowercased() {
        case "randr":
            return try extractAudioBookFromRANDR(fileURL)
        case "epub":
            return try extractTextFromEPUB(fileURL)
        case "txt":
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return BookFile(
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
            return try extractTextFromPDF(fileURL)
        default:
            throw NSError(domain: "Unsupported file format", code: 0, userInfo: nil)
        }
    }

    // MARK: - Issue 6 fix: replaced var book: AudioBookFileJson? = nil + force-unwraps with let + do/catch
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
        // Issue 6: use let + do/catch so no force-unwrap is needed below
        let book: AudioBookFileJson
        do {
            book = try JSONDecoder().decode(AudioBookFileJson.self, from: jsonData)
        } catch {
            try? fileManager.removeItem(at: extractionDirectory)
            print(error)
            throw ExtractionError.invalidJSON
        }

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
            title: book.title,
            author: book.author,
            content: [],
            audioPath: "audio/\(fileNameWithoutExtension)/audio.mp3",
            text: book.text,
            language: book.language,
            rate: book.rate,
            voice: book.voice,
            model: book.model,
            book_source: book.book_source
        )
    }


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
        guard !fileURL.absoluteString.contains(" ") else {
            throw NSError(domain: "FileError", code: 236, userInfo: [NSLocalizedDescriptionKey: "Spaces in file name"])
        }

        guard let document = EPUBDocument(url: fileURL) else {
            throw NSError(domain: "EPUBError", code: 235, userInfo: [NSLocalizedDescriptionKey: "Broken EPUB document"])
        }
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
        do {
            try fileManager.removeItem(at: tempFolderURL)
        } catch {
            print("Failed to delete the temporary folder: \(error)")
        }

        return book
    }

    static func extractTextFromPDF(_ fileURL: URL) throws -> BookFile {
        guard let document = PDFDocument(url: fileURL) else {
            throw NSError(domain: "PDFError", code: 237, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF document"])
        }
        var content = [String]()
        let pageCount = document.pageCount
        for pageIndex in 0..<pageCount {
            if let page = document.page(at: pageIndex) {
                let pageText = page.string ?? ""
                content.append(pageText)
            }
        }
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

    // MARK: - Issue 3 fix: replaced DispatchSemaphore + dataTask with async URLSession.data(from:)
    static func extractTextFromHTML(url: URL) async throws -> BookFile {
        let (data, _) = try await URLSession.shared.data(from: url)

        let htmlContent: String
        if let decoded = String(data: data, encoding: .utf8) {
            htmlContent = decoded
        } else {
            htmlContent = String(data: data, encoding: .isoLatin1) ?? ""
        }

        if htmlContent.isEmpty {
            print("Failed to decode HTML content.")
            return BookFile(
                title: "Unknown", author: "Unknown", content: [],
                audioPath: "", text: [], language: "en_US",
                rate: 1.0, voice: "Unknown", model: "Unknown", book_source: "Unknown"
            )
        }

        var content = [String]()
        var title = "Unknown"
        var author = "Unknown"

        do {
            let document = try SwiftSoup.parse(htmlContent)
            let parsedTitle = try document.title()
            if !parsedTitle.isEmpty { title = parsedTitle }
            let parsedAuthor = try document.select("meta[name=author]").attr("content")
            if !parsedAuthor.isEmpty { author = parsedAuthor }
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
