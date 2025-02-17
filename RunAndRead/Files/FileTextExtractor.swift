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

struct BookFile: Codable {
    let title: String
    let author: String
    let content: [String]
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
                case "epub":
                    book = try extractTextFromEPUB(fileURL)
                case "txt":
                    let text = try String(contentsOf: fileURL, encoding: .utf8)
                    book = BookFile(title: "", author: "", content: [text])
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
                content: extractContent(document: document)
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
                content: content
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
                content: content
        )
    }
}

//struct BookFile: Codable {
//    let title: String
//    let author: String
//    let content: [String]
//}
//
//class FileTextExtractor {
//    
//    static func extractText(from fileURL: URL) -> AnyPublisher<BookFile, Error> {
//        return Future { promise in
//            do {
//                var book: BookFile
//                switch fileURL.pathExtension.lowercased() {
//                case "epub":
//                    book = try extractTextFromEPUB(fileURL)
//                case "txt":
//                    let text = try String(contentsOf: fileURL, encoding: .utf8)
//                    book = BookFile(title: "", author: "", content: [text])
//                default:
//                    throw NSError(domain: "Unsupported file format", code: 0, userInfo: nil)
//                }
//                DispatchQueue.main.async { promise(.success(book)) }
//            } catch {
//                DispatchQueue.main.async { promise(.failure(error)) }
//            }
//        }
//        .eraseToAnyPublisher()
//    }
//    
//    static func extractContent(document: EPUBDocument?) -> [String] {
//        guard let document = document else {
//            print("Unable to find the EPUB file.")
//            return []
//        }
//        guard let bundle = Bundle(path: document.contentDirectory.path()) else {
//            print("EPUB unresolved.")
//            return []
//        }
//        let contentFiles = document.spine.items.compactMap { item in
//            if let manifestItem = document.manifest.items.first(where: { (_, value) in item.idref == value.id }) {
//                return bundle.bundleURL.appendingPathComponent(manifestItem.value.path)
//            } else {
//                return nil
//            }
//        }
//        
//        let strippedSections: [String] = [
//            "title",
//            "section",
//            "cover",
//            "colophon",
//            "imprint",
//            "endnote",
//            "copyright"
//        ]
//        
//        return contentFiles
//            .filter { url in
//                let lastPathComponent = url.deletingPathExtension().lastPathComponent.lowercased()
//                for strippedSection in strippedSections {
//                    if lastPathComponent.contains(strippedSection) {
//                        return false
//                    }
//                }
//                return true
//            }
//            .flatMap { url in
//                do {
//                    return try SwiftSoup
//                        .parse(String(contentsOf: url, encoding: .utf8))
//                        .select("p,h1,h2,h3,h4,h5,h6,pre")
//                        .compactMap { try $0.text().trimmingCharacters(in: .whitespacesAndNewlines) }
//                        .filter { !$0.isEmpty }
//                } catch {
//                    print("XML File not loaded")
//                    return []
//                }
//            }
//    }
//
//    // Extract text from EPUB
//    static func extractTextFromEPUB(_ fileURL: URL) throws -> (BookFile) {
//        let brokenURL = fileURL.absoluteString.contains(" ") || fileURL.absoluteString.contains("%20")
//        if !brokenURL {
//            let document = EPUBDocument(url: fileURL)
//            if let d = document {
//                // Extract the text content
//                let author: String = d.author ?? ""
//                let title: String = d.title ?? ""
//                let extracted = extractContent(document: d)
//                return BookFile(title: title, author: author, content: extracted)
//            } else {
//                return BookFile(title: "Unknown", author: "Unknown", content: ["Error #235, broken epub document"])
//            }
//        } else {
//            return BookFile(title: "Unknown", author: "Unknown", content: ["Error #236,\n \(fileURL.lastPathComponent) \n\n Spaces in File Name, please go to the epub file remove the all spaces in the file name and try to open again!"])
//        }
//    }
//}


//import PDFKit
//import AEXML
//import ZIPFoundation
//    // Extract text from PDF
//    private static func extractTextFromPDF(_ fileURL: URL) throws -> String {
//        guard let pdf = PDFDocument(url: fileURL) else { throw NSError(domain: "Invalid PDF", code: 1) }
//        var extractedText = ""
//        for i in 0..<pdf.pageCount {
//            if let page = pdf.page(at: i), let text = page.string {
//                extractedText.append(text + "\n")
//            }
//        }
//        return extractedText
//    }
//
//
//    // Extract text from MOBI / AZW3
//    private static func extractTextFromMobi(_ fileURL: URL) throws -> String {
//        let archive = try Archive(url: fileURL, accessMode: .read)
//        var extractedText = ""
//        let tempDirectory = FileManager.default.temporaryDirectory
//
//        for entry in archive {
//            if entry.path.hasSuffix(".html") {
//                let tempFileURL = tempDirectory.appendingPathComponent(entry.path)
//                try archive.extract(entry, to: tempFileURL)
//                let data = try Data(contentsOf: tempFileURL)
//
//                if let text = String(data: data, encoding: .utf8) {
//                    extractedText.append(text + "\n")
//                    nprint("append")
//                }
//                try FileManager.default.removeItem(at: tempFileURL) // Clean up
//            }
//        }
//        return extractedText
//    }

//import Combine
//import PDFKit
//import AEXML
//import ZIPFoundation
//
//class FileTextExtractor {
//    static func extractText(from fileURL: URL) -> AnyPublisher<String, Error> {
//        return Future<String, Error> { promise in
//            DispatchQueue.global(qos: .userInitiated).async {
//                do {
//                    if !fileURL.startAccessingSecurityScopedResource() {
//                        if let resolvedURL = NSURLComponents(url: fileURL, resolvingAgainstBaseURL: true)?.url {
//                            let text: String
//                            switch fileURL.pathExtension.lowercased() {
//                            case "pdf":
//                                text = try extractTextFromPDF(resolvedURL)
//                            case "epub":
//                                text = try extractTextFromEPUB(resolvedURL)
//                            case "mobi", "azw3":
//                                text = try extractTextFromMobi(resolvedURL)
//                            case "txt":
//                                    text = try String(contentsOf: resolvedURL, encoding: .utf8)
//                            default:
//                                throw NSError(domain: "Unsupported file format", code: 0, userInfo: nil)
//                            }
//                            
//                            fileURL.stopAccessingSecurityScopedResource()
//                                DispatchQueue.main.async {
//                                    promise(.success(text))
//                                    
//                                }
//                        }
//                    
//                    }
//                    fileURL.stopAccessingSecurityScopedResource()
//                } catch {
//                    fileURL.stopAccessingSecurityScopedResource()
//                    promise(.failure(error))
//                }
//            }
//        }
//        .eraseToAnyPublisher()
//    }
//
//    // Extract text from PDF
//    private static func extractTextFromPDF(_ fileURL: URL) throws -> String {
//        guard let pdf = PDFDocument(url: fileURL) else { throw NSError(domain: "Invalid PDF", code: 1) }
//        var extractedText = ""
//        for i in 0..<pdf.pageCount {
//            if let page = pdf.page(at: i), let text = page.string {
//                extractedText.append(text + "\n")
//            }
//        }
//        return extractedText
//    }
//
//    // Extract text from EPUB
//    private static func extractTextFromEPUB(_ fileURL: URL) throws -> String {
//        let archive = try Archive(url: fileURL, accessMode: .read)
//        var extractedText = ""
//        let tempDirectory = FileManager.default.temporaryDirectory
//        
//        for entry in archive {
//            if entry.path.hasSuffix(".xhtml") || entry.path.hasSuffix(".html") {
//                let tempFileURL = tempDirectory.appendingPathComponent(entry.path)
//                try archive.extract(entry, to: tempFileURL)
//                let data = try Data(contentsOf: tempFileURL)
//                
//                if let xmlString = String(data: data, encoding: .utf8) {
//                    let xml = try AEXMLDocument(xml: xmlString)
//                    extractedText.append(xml.root.string + "\n")
//                }
//                try FileManager.default.removeItem(at: tempFileURL) // Clean up
//            }
//        }
//        return extractedText
//    }
//
//    // Extract text from MOBI / AZW3
//    private static func extractTextFromMobi(_ fileURL: URL) throws -> String {
//        let archive = try Archive(url: fileURL, accessMode: .read)
//        var extractedText = ""
//        let tempDirectory = FileManager.default.temporaryDirectory
//        
//        for entry in archive {
//            if entry.path.hasSuffix(".html") {
//                let tempFileURL = tempDirectory.appendingPathComponent(entry.path)
//                try archive.extract(entry, to: tempFileURL)
//                let data = try Data(contentsOf: tempFileURL)
//                
//                if let text = String(data: data, encoding: .utf8) {
//                    extractedText.append(text + "\n")
//                }
//                try FileManager.default.removeItem(at: tempFileURL) // Clean up
//            }
//        }
//        return extractedText
//    }
//}


//    static func extractText(from fileURL: URL, progress: @escaping (Double) -> Void) -> AnyPublisher<(BookFile), Error> {
//        return Future<(BookFile), Error> { promise in
//            DispatchQueue.global(qos: .userInitiated).async {
//                do {
//                    // Read file contents directly without copying
//                    var book: BookFile
//                    switch fileURL.pathExtension.lowercased() {
////                    case "pdf":
////                        text = try extractTextFromPDF(fileURL)
//                    case "epub":
//                        book = try extractTextFromEPUB(fileURL)
//                        nprint("extractedText2.title=>\(book.title)")
////                    case "mobi", "azw3":
////                        text = try extractTextFromMobi(fileURL)
//                    case "txt":
//                        var text = try String(contentsOf: fileURL, encoding: .utf8)
//                        book = BookFile(title: "",author: "",content: text)
//                    default:
//                        throw NSError(domain: "Unsupported file format", code: 0, userInfo: nil)
//                    }
//
//                    DispatchQueue.main.async {
//                        progress(1.0)
////                        nprint("extractedText2.title=>\(title)")
////                        nprint("extractedText2.author=>\(author)")
//                        promise(.success(book))
//                    }
//                } catch {
//                    DispatchQueue.main.async {
//                        promise(.failure(error))
//                    }
//                }
//            }
//        }
//        .eraseToAnyPublisher()
//    }
