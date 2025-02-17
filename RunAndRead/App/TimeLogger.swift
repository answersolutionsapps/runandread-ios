//
//  Untitled.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/16/25.
//

import Foundation

struct TimeLogger {
    private static var startTimes: [String: Date] = [:]
    
    /// Starts the timer for a given identifier
    static func start(_ identifier: String, message: String) {
        DispatchQueue.main.async {
            startTimes[identifier] = Date()
            print("⏳ [\(identifier)] (\(message)) Started measuring time...")
        }
    }
    
    /// logs elapsed time without stopping
    static func log(_ identifier: String, message: String) {
        DispatchQueue.main.async {
            guard let startTime = startTimes[identifier] else {
                print("⚠️ [\(identifier)] Timer was never started.")
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ [\(identifier)] (\(message)) Logged in \(elapsed) seconds")
        }
    }
    
    /// Stops the timer and logs elapsed time
    static func stop(_ identifier: String, message: String) {
        DispatchQueue.main.async {
            guard let startTime = startTimes[identifier] else {
                print("⚠️ [\(identifier)] Timer was never started.")
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ [\(identifier)] (\(message)) Finished in \(elapsed) seconds")
            startTimes.removeValue(forKey: identifier) // Clean up
        }
    }
}
