//
//  Logging.swift
//  RunAndRead
//
//  Centralized structured logging using os.Logger
//
//  Created by Serge Nes on 12/17/25.
//

import Foundation
import os

enum LogCategory: String {
    case persistence = "Persistence"
    case library = "Library"
    case audio = "Audio"
    case app = "App"
}

enum AppLogger {
    // Replace with your bundle identifier if desired
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.answersolutions.runandread"

    static let persistence = Logger(subsystem: subsystem, category: LogCategory.persistence.rawValue)
    static let library = Logger(subsystem: subsystem, category: LogCategory.library.rawValue)
    static let audio = Logger(subsystem: subsystem, category: LogCategory.audio.rawValue)
    static let app = Logger(subsystem: subsystem, category: LogCategory.app.rawValue)
}
