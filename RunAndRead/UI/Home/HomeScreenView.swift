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
import MobileCoreServices


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
    var onError: (Error) -> Void // Add an error handler

    func makeCoordinator() -> Coordinator {
        nprint("makeCoordinator")
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        nprint("makeUIViewController")
        let supportedTypes: [UTType] = [
            .plainText,
            .pdf,
            UTType(filenameExtension: "epub")!
        ]
        var asCopy = true
        if ProcessInfo.processInfo.isMacCatalystApp {
            nprint("🏁 Running on macOS via Catalyst")
            asCopy = false
        }


        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: asCopy)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        nprint("updateUIViewController")
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
            nprint("Coordinator")
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onFileSelected(url) // Call the callback when a file is selected
            }
        }

        // Error handling
        func documentPicker(_ controller: UIDocumentPickerViewController, didFailWithError error: Error) {
            parent.onError(error) // Call the error handler when something goes wrong
        }

        // Optional: handle user cancellation if necessary
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle user cancellation (optional, for better UX)
            nprint("Document picker was cancelled")
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
            if viewModel.bookManager.inProgress {
                CustomActivityIndicator()
            }
        }
        .alert("Open File Error", isPresented: $viewModel.showErrorMessage, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
            Button("Share error with developer", role: .destructive) {
                let error = viewModel.errorMessage ?? "Unknown error"
                let messageToSend = """
                Run & Read - A Bug Report
                <br><br>
                ==Report Begins==========<br>
                Input here your feedback or the details of the issues you have.
                <br>==Report Ends============
                <br><br>
                Error: \(error)
                <br><br>
                OS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
                <br>
                Model: \(UIDevice.current.model)
                <br>
                App Version: \(Bundle.main.fullVersion)
                <br>
                """
                
                EmailService.shared.sendEmail(
                    subject: "Run & Read - Bug Report",
                    body: messageToSend,
                    to: "support@answersolutions.net"
                ) { (canSend, sent) in
                    if !sent {
                        print("Email not sent")
                    } else {
                        print("Email sent")
                    }
                    viewModel.errorMessage = nil
                }
            }
        } message: { error in
            Text(error)
        }
        .sheet(isPresented: $viewModel.showFilePicker) {
            DocumentPicker(onFileSelected: { fileURL in
                //TimeLogger.start("onFileSelected", message: "DocumentPicker")
                DispatchQueue.main.async {
                    self.viewModel.bookManager.inProgress = true
                    viewModel.showFilePicker = false
                    viewModel.onFileSelected(fileURL: fileURL)
                }
            }, onError: { error in
                nprint("Error: \(error.localizedDescription)")
            })
        }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        nprint("App is active (foreground)")
                        viewModel.onBackToForegraund()
                    case .inactive:
                        nprint("App is inactive")
                    case .background:
                        nprint("App is in the background")
                    @unknown default:
                        nprint("Unknown scene phase")
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
                .tint(.primary)
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
                .tint(.primary)
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
            nprint("No text found in clipboard")
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
