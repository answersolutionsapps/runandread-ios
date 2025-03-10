//
//  SplashScreenView.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/27/25.
//

import SwiftUI
import Foundation
import Combine

extension Bundle {

    var shortVersion: String {
        if let result = infoDictionary?["CFBundleShortVersionString"] as? String {
            return result
        } else {
            assert(false)
            return ""
        }
    }

    var buildVersion: String {
        if let result = infoDictionary?["CFBundleVersion"] as? String {
            return result
        } else {
            assert(false)
            return ""
        }
    }

    var fullVersion: String {
        return "\(shortVersion)(\(buildVersion))"
    }
}

enum AppScreen: Hashable {
    case home
    case newBook
    case player
    case about
}

struct SplashScreenView: View {
    @EnvironmentObject var bookManager: BookManager
    @EnvironmentObject var simplePlayer: SimpleTTSPlayer
    @EnvironmentObject var player: TextToSpeechPlayer
    @EnvironmentObject var audioBookPlayer: AudioBookPlayer
    @State private var path = NavigationPath()
    @State private var showSplash = true

    var body: some View {
        NavigationStack(path: $path) {
            if showSplash {
                splashContent
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showSplash = false
                                    if bookManager.currentBook == nil || bookManager.openedFilePath != nil {
                                        path.append(AppScreen.home)
                                    } else {
                                        path.append(AppScreen.player)
                                    }
                                }
                            }
                        }
            } else {
                ZStack {
                    Text("No screen available")
                            .foregroundColor(.gray)
                }
                        .navigationDestination(for: AppScreen.self) { screen in
                            switch screen {
                            case .home:
                                HomeScreenView(
                                        viewModel: HomeScreenViewModel(
                                                bookManager: bookManager,
                                                path: $path)
                                )
                            case .newBook:
                                BookSettingsView(
                                        viewModel: BookSettingsViewModel(
                                                path: $path,
                                                bookManager: bookManager,
                                                simplePlayer: simplePlayer)
                                )
                            case .player:
                                BookPlayerView(
                                        viewModel: BookPlayerViewModel(
                                                path: $path,
                                                bookManager: bookManager,
                                                player: player,
                                                audioPlayer: audioBookPlayer
                                        )
                                )
                            case .about:
                                AboutScreenView()
                            }
                        }
            }
        }
    }

    private var splashContent: some View {
        ZStack {
            Color(.surface)
                    .edgesIgnoringSafeArea(.all)

            VStack {

                Spacer()
                Text("Run & Read")
                        .font(.system(size: 60, design: .rounded))
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.top, 84)

                Text("Your Ultimate Text-to-Speech Player.")
                        .font(.system(size: 24, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)

                Text("Read with your ears while on the move!")
                        .font(.system(size: 24, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                Spacer()

                Text("\(Bundle.main.fullVersion)")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.primary)
            }
                    .task {
                        bookManager.loadCurrentBook {

                        }
                    }
                    .padding()
        }

    }
}

#Preview {
    SplashScreenView()
            .environmentObject(BookManager())
            .environmentObject(SimpleTTSPlayer())
}
