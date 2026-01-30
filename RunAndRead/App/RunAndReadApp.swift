//
//  RunAndReadApp.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/21/25.
//

import SwiftUI
import StoreKit
import UIKit
import RunAnywhere
import ONNXRuntime
import os

func askForAppRating() {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        SKStoreReviewController.requestReview(in: windowScene)
    }
}

@main
struct RunAndReadApp: App {
    private let logger = Logger(subsystem: "com.runandread", category: "RunAndReadApp")
    private let bookManager = BookManager()
    private let simplePlayer = SimpleTTSPlayer()
    @State private var isSDKInitialized = false

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .accentColor(Color("AccentColor"))
                .environmentObject(bookManager)
                .environmentObject(simplePlayer)
                .onOpenURL(perform: handleOpenFile(_:))
                .task {
                    if !isSDKInitialized {
                        await initializeRunAnywhereSDK()
                        isSDKInitialized = true
                    }
                }
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

    private func initializeRunAnywhereSDK() async {
        do {
            logger.info("🎯 Initializing RunAnywhere SDK for TTS...")

            // Initialize SDK - in development mode, no API key needed
            #if DEBUG
            try RunAnywhere.initialize()
            logger.info("✅ SDK initialized in DEVELOPMENT mode")
            #else
            // For production, you may need to provide API key
            try RunAnywhere.initialize()
            logger.info("✅ SDK initialized in PRODUCTION mode")
            #endif

            // Register ONNX backend
            ONNX.register(priority: 100)
            logger.info("✅ ONNX backend registered")

            // Register TTS models
            await registerTTSModels()

            logger.info("✅ RunAnywhere SDK successfully initialized for TTS")
        } catch {
            logger.error("❌ Failed to initialize RunAnywhere SDK: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func registerTTSModels() async {
        logger.info("📦 Registering TTS models...")

        // Register Piper TTS models - US English
        if let piperUSURL = URL(string: "https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-models-v1/vits-piper-en_US-lessac-medium.tar.gz") {
            RunAnywhere.registerModel(
                id: "vits-piper-en_US-lessac-medium",
                name: "Piper TTS (US English - Medium)",
                url: piperUSURL,
                framework: .onnx,
                modality: .speechSynthesis,
                artifactType: .archive(.tarGz, structure: .nestedDirectory),
                memoryRequirement: 65_000_000
            )
            logger.info("✅ Registered Piper TTS US English model")
        }

        // Register Piper TTS models - British English
        if let piperGBURL = URL(string: "https://github.com/RunanywhereAI/sherpa-onnx/releases/download/runanywhere-models-v1/vits-piper-en_GB-alba-medium.tar.gz") {
            RunAnywhere.registerModel(
                id: "vits-piper-en_GB-alba-medium",
                name: "Piper TTS (British English)",
                url: piperGBURL,
                framework: .onnx,
                modality: .speechSynthesis,
                artifactType: .archive(.tarGz, structure: .nestedDirectory),
                memoryRequirement: 65_000_000
            )
            logger.info("✅ Registered Piper TTS British English model")
        }

        logger.info("🎉 All TTS models registered")
    }
}
