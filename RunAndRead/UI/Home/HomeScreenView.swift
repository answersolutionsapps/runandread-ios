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
            .plainText,                  // .txt
            .pdf,                        // .pdf
            UTType(filenameExtension: "epub")! // .epub (eBooks)
//            UTType(filenameExtension: "mobi")!, // .mobi (eBooks)
//            UTType(filenameExtension: "azw3")!  // .azw3 (Kindle eBooks)
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

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
    @EnvironmentObject var bookManager: BookManager
    @Environment(\.scenePhase) private var scenePhase
    @Binding var path: NavigationPath
    @State private var showFilePicker = false
    @State private var searchText = ""
    
    var filteredBooks: [Book] {
        dataSource().filter {
               searchText.isEmpty ||
               $0.title.localizedCaseInsensitiveContains(searchText) ||
               $0.author.localizedCaseInsensitiveContains(searchText)
           }
       }
    
    func dataSource() -> [Book] {
        return bookManager.library.isEmpty ? bookManager.libraryDefault : bookManager.library
    }
        
    var body: some View {
        ZStack {
            VStack {
                SearchBar(text: $searchText)
                if dataSource().isEmpty {
                    emptyLibraryView
                } else {
                    List{
                        ForEach(filteredBooks, id: \.id) { item in
                            BookItemView(
                                item: item,
                                onSelect: {
                                    bookManager.saveCurrentBook(book: item) {
                                        DispatchQueue.main.async {
                                            path.append(AppScreen.player)
                                        }
                                    }
                                }
                            ).onAppear(perform: {
//                                if !item.isCalculated {
                                    item.calculate { }
//                                }
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
            if bookManager.inProgress {
                CustomActivityIndicator()
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { fileURL in
                    bookManager.loadText(from: fileURL) { bookFile in
                        guard let bookFile = bookFile else {
                            return
                        }
                        
                        bookManager.plainTextData =  bookFile.content
                        bookManager.plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
                        
                        bookManager.titleData = bookFile.title
                        bookManager.authorData = bookFile.author

                        DispatchQueue.main.async {
                            print("loadText.title => \(bookFile.title)")
                            print("loadText.author => \(bookFile.author)")

                            self.path.append(AppScreen.newBook)
                        }
                    }
            }
        }
        .onChange(of: scenePhase) { newPhase in
                       switch newPhase {
                       case .active:
                           print("App is active (foreground)")
                           if let url = bookManager.openedFilePath {
                               bookManager.loadText(from: url) { bookFile in
                                   bookManager.openedFilePath?.stopAccessingSecurityScopedResource()
                                   bookManager.openedFilePath = nil
                                   guard let bookFile = bookFile else {
                                       return
                                   }
                                   
                                   bookManager.plainTextData =  bookFile.content
                                   bookManager.plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
                                   
                                   bookManager.titleData = bookFile.title
                                   bookManager.authorData = bookFile.author

                                   DispatchQueue.main.async {
                                       print("loadText.title => \(bookFile.title)")
                                       print("loadText.author => \(bookFile.author)")
                                       self.path.append(AppScreen.newBook)
                                   }
                               }
                           }
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
                bookManager.loadBooks()
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
            Button(action: { showFilePicker = true }) {
                Label("From File", systemImage: "doc")
            }
//            Button(action: pasteFromClipboardWebLink) {
//                Label("From Web", systemImage: "network")
//            }
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
        self.path.append(AppScreen.about)
    }
    
    private func pasteFromClipboard() {
            if let text = UIPasteboard.general.string {
                bookManager.plainTextData = [text, "Narrated by Run and Read!"]
                path.append(AppScreen.newBook)
            } else {
                print("No text found in clipboard")
            }
        }
    
    private func pasteFromClipboardWebLink() {
            if let text = UIPasteboard.general.string, let url = URL(string: text) {
                bookManager.loadText2(from: url) { bookFile in
                    guard let bookFile = bookFile else {
                        return
                    }
                    
                    bookManager.plainTextData = bookFile.content
                    bookManager.plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
                    
                    bookManager.titleData = bookFile.title
                    bookManager.authorData = bookFile.author

                    DispatchQueue.main.async {
                        print("loadText.title => \(bookFile.title)")
                        print("loadText.author => \(bookFile.author)")

                        self.path.append(AppScreen.newBook)
                    }
                }
            } else {
                print("No web link found in clipboard")
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
    }
}

func returnBookManagerForPreview() -> BookManager {
    let book = Book(title: "This text has been narrated by the Run and Read app! We hope you enjoyed listening!", author: "Author", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 0, bookmarks: [])
    let book2 = Book(title: "Title 2", author: "Author 2", language: Locale.current, voiceIdentifier: AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier, voiceRate: 0.5, text: ["lorem ipsum..."], lastPosition: 1, bookmarks: [])
    let m = BookManager()
    m.currentBook = book
    m.currentBookId = book.id
    
    m.library = [book, book2, book, book, book, book]
    
    return m
}

#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
        
        HomeScreenView(path: path.projectedValue)
            .environmentObject(returnBookManagerForPreview())
            .environmentObject(TextToSpeechSimplePlayer())
    }
}
