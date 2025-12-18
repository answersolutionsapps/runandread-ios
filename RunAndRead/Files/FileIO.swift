//
//  FileIO.swift
//  RunAndRead
//
//  Atomic writes and data-protected filesystem helpers with structured logging.
//
//  Created by Serge Nes on 12/17/25.
//

import Foundation

public enum FileIO {
    public enum Protection: Equatable {
        case none
        case complete
        case completeUnlessOpen
        case completeUntilFirstUserAuthentication

        var fileProtection: FileProtectionType? {
            switch self {
            case .none: return nil
            case .complete: return .complete
            case .completeUnlessOpen: return .completeUnlessOpen
            case .completeUntilFirstUserAuthentication: return .completeUntilFirstUserAuthentication
            }
        }
    }

    // MARK: - Directory
    @discardableResult
    public static func createDirectoryIfNeeded(at url: URL, protection: Protection = .completeUntilFirstUserAuthentication) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return true }
        do {
            var attrs: [FileAttributeKey: Any]? = nil
            if let p = protection.fileProtection {
                attrs = [.protectionKey: p]
            }
            try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: attrs)
            return true
        } catch {
            AppLogger.persistence.error("Failed to create directory at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Atomic write
    public static func writeAtomic(data: Data, to url: URL, protection: Protection = .completeUntilFirstUserAuthentication) throws {
        let dir = url.deletingLastPathComponent()
        _ = createDirectoryIfNeeded(at: dir, protection: protection)

        // Write to a temporary file in the same directory, then move atomically
        let tempURL = dir.appendingPathComponent(".tmp_\(UUID().uuidString)")
        do {
            try data.write(to: tempURL, options: .noFileProtection)
            // Apply protection attribute if requested
            if let p = protection.fileProtection {
                try FileManager.default.setAttributes([.protectionKey: p], ofItemAtPath: tempURL.path)
            }
            // Move to final destination (atomic within same volume)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            // Ensure temp gets cleaned up on failure
            try? FileManager.default.removeItem(at: tempURL)
            AppLogger.persistence.error("Atomic write failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Read
    public static func readData(at url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            AppLogger.persistence.error("Read failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Remove
    public static func removeItem(at url: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            AppLogger.persistence.error("Remove failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
