//
//  HomeScreenView.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/27/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import AVFAudio

public extension View {
    var isPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onFileSelected: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .plainText, // .txt
            .pdf, // .pdf
            UTType(filenameExtension: "epub")! // .epub (eBooks)
//            UTType(filenameExtension: "mobi")!, // .mobi (eBooks)
//            UTType(filenameExtension: "azw3")!  // .azw3 (Kindle eBooks)
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onFileSelected(url) // Call the callback when a file is selected
            }
        }
    }
}

struct HomeScreenView: View {
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var textIsFocused: Bool
    @StateObject var viewModel: HomeScreenViewModel
    

    var body: some View {
        ZStack {
            VStack {
                SearchBar(text: $viewModel.searchText)
                        .focused($textIsFocused)
                        .toolbar {
                            // Keyboard toolbar with Cancel button
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()  // Push the button to the right
                                Button("Cancel") {
                                    // Dismiss the keyboard by unfocusing
                                    textIsFocused = false
                                }
                            }
                        }
                if viewModel.dataSource.isEmpty {
                    emptyLibraryView
                } else {
                    List {
                        ForEach(viewModel.filteredBooks, id: \.id) { item in
                            BookItemView(
                                    item: item,
                                    onSelect: {
                                        viewModel.onSelectBook(book: item)
                                    }
                            )
                                    .onAppear(perform: {
                                        item.calculate {
                                        }
                                    })
                                    .padding(.horizontal, 8)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 12))
                                    .background(Color.clear)
                        }
                    }
                            .listStyle(.plain)
                }
            }
        }
                .sheet(isPresented: $viewModel.showFilePicker) {
                    DocumentPicker { fileURL in
                        viewModel.onFileSelected(fileURL: fileURL)
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        print("App is active (foreground)")
                        viewModel.onBackToForegraund()
                    case .inactive:
                        print("App is inactive")
                    case .background:
                        print("App is in the background")
                    @unknown default:
                        print("Unknown scene phase")
                    }
                }
                .onAppear {
                    if !isPreview {
                        viewModel.loadBooks()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Eyes-Free Library").font(.title2)
                    }
                }
                .navigationBarItems(leading: aboutButton, trailing: addButton)
                .navigationBarHidden(false)
                .navigationBarBackButtonHidden(true)
    }

    private var emptyLibraryView: some View {
        VStack {
            Text("Hit the plus button to open your first book and enjoy eyes-free reading!")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.gray)
        }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
    }

    private var aboutButton: some View {
        Button(action: showAbout, label: {
            Image(systemName: "info.square")
                    .tint(UIConfig.primaryColor)
                    .imageScale(.large)
        })
    }

    private var addButton: some View {
        Menu {
            Button(action: {
                viewModel.onShowFilePicker()
            }) {
                Label("From File", systemImage: "doc")
            }
            Button(action: pasteFromClipboard) {
                Label("From Clipboard", systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "plus")
                    .tint(UIConfig.primaryColor)
                    .imageScale(.large)
        }
    }

    private func showAbout() {
        viewModel.onShowAbout()
    }

    private func pasteFromClipboard() {
        if let text = UIPasteboard.general.string {
            viewModel.onPasteFromClipboard(text: text)
        } else {
            print("No text found in clipboard")
        }
    }


}

// Search Bar Component
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        TextField("Search", text: $text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(0)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .overlay(
                    HStack {
                        Spacer() // Push the button to the right
                        if !text.isEmpty { // Show the clear button only if there's text
                            Button(action: {
                                text = "" // Clear the text when button is pressed
                            }) {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 24)
                        }
                    }
                )
    }
}

func returnBookManagerForPreview() -> BookManager {
    let book = Book(title: "This text has been narrated by the Run and Read app! We hope you enjoyed listening!", author: "Author", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 0, bookmarks: [Bookmark(voiceRate: 1, position: 1),Bookmark(voiceRate: 1, position: 2),Bookmark(voiceRate: 1, position: 3),Bookmark(voiceRate: 1, position: 4)])
    let book2 = Book(title: "Title 2", author: "Author 2", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 1, bookmarks: [Bookmark(voiceRate: 1, position: 1),Bookmark(voiceRate: 1, position: 2),Bookmark(voiceRate: 1, position: 3),Bookmark(voiceRate: 1, position: 4)])
    let m = BookManager()
    m.currentBook = book
    m.currentBookId = book.id

    m.library = [book, book2, book, book, book, book]

    return m
}

#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())

        HomeScreenView(viewModel: HomeScreenViewModel(
            bookManager: returnBookManagerForPreview(),
            path: path.projectedValue))
                .environmentObject(returnBookManagerForPreview())
                .environmentObject(SimpleTTSPlayer())
    }
}
