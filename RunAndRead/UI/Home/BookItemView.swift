//
//  BookItemView.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/30/25.
//

import SwiftUI
import AVFAudio
import Combine

struct BookItemView: View {
    @ObservedObject var item: Book
    let onSelect: () -> Void
    
    @State private var isPressed = false // Track pressed state
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(item.isCompleted ? Color.accentColor : Color.clear)
             .frame(width: 10)
             .padding(.leading, 0)
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                Text(item.author)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
                Divider()
                if item.isCalculating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle()).padding(.leading, 8)
                } else {
                    if item.isCompleted {
                        Group {
                            Text("Finished")
                                .fontWeight(.bold) +
                            Text(" | \(item.language.localizedString(forIdentifier: item.language.identifier) ?? "Unknown")")
                        }
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .padding(.vertical, 2)
                        
                    } else {
                        Text("\(item.progressTime) of \(item.totalTime) | \(item.language.localizedString(forIdentifier: item.language.identifier) ?? "Unknown")")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                            .padding(.vertical, 2)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(UIConfig.surfaceColor)
        .scaleEffect(isPressed ? 0.95 : 1) // Subtle scaling effect
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed) // Smooth animation
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isPressed = false
                        }
                        onSelect()
                    }
                }
    }
}

#Preview {
    BookItemView(
        item:
        Book(
            title: "Staying Relevant in an era AI Advancements: A 2025 and Beyond Playbook for Software Engineers",
            author: "Author",
            language: Locale.current,
            voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier,
            voiceRate: 0.5, text: ["lorem ipsum..."],
            lastPosition: 0, bookmarks: []
        ),
        onSelect: { print("Book selected") }
    ).padding()
}
