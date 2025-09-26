//
//  RunAndReadApp.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/21/25.
//

import SwiftUI
import StoreKit
import UIKit

func askForAppRating() {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        SKStoreReviewController.requestReview(in: windowScene)
    }
}

@main
struct RunAndReadApp: App {
    private let bookManager = BookManager()
    private let simplePlayer = SimpleTTSPlayer()
    private let textToSpeechPlayer = TextToSpeechPlayer()
    private let audioBookPlayer = AudioBookPlayer()

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .accentColor(Color("AccentColor"))
                .environmentObject(bookManager)
                .environmentObject(simplePlayer)
                .environmentObject(textToSpeechPlayer)
                .environmentObject(audioBookPlayer)
                .onOpenURL(perform: handleOpenFile(_:))
        }
    }

    private func handleOpenFile(_ url: URL) {
        print("App opened with file: \(url)")
        let needTo = url.startAccessingSecurityScopedResource()

        let resolvedURL = NSURLComponents(url: url, resolvingAgainstBaseURL: true)?.url
        if needTo {
            // Accessing security-scoped resource succeeded
            if let resolvedURL {
                bookManager.openedFilePath = resolvedURL
            }
        } else {
            if let resolvedURL {
                bookManager.openedFilePath = resolvedURL
            }
        }
    }
}
