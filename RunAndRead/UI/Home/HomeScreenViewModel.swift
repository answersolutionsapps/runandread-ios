//
//  HomeScreenViewModel.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

class HomeScreenViewModel: ObservableObject {
    
    @Published var showFilePicker = false
    @Published var searchText = "" {
        didSet {
            updateFilteredBooks() // Recalculate filtered books when searchText changes
        }
    }
    @Published var filteredBooks: [Book] = []
    
    @Binding var path: NavigationPath
    private var bookManager: BookManager

    init(bookManager: BookManager, path: Binding<NavigationPath>) {
        self.bookManager = bookManager
        _path = path
    }
    
    var dataSource: [Book] {
        return bookManager.library.isEmpty ? bookManager.libraryDefault : bookManager.library
    }
    
    private func updateFilteredBooks() {
        filteredBooks = dataSource.filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadBooks() {
        self.bookManager.loadBooks() {
            self.updateFilteredBooks()
        }
    }
    
    

    func handleFileSelection(fileURL: URL) {
        bookManager.loadText(from: fileURL) { bookFile in
            guard let bookFile = bookFile else {
                return
            }
            
            self.bookManager.plainTextData = bookFile.content
            self.bookManager.plainTextData.append(". This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
            
            self.bookManager.titleData = bookFile.title
            self.bookManager.authorData = bookFile.author

            DispatchQueue.main.async {
                self.showFilePicker = false
            }
        }
    }

    func handleClipboard() {
        if let text = UIPasteboard.general.string {
            bookManager.plainTextData = [text, ". Narrated by Run and Read!"]
        }
    }
    
    func handleClipboardWebLink() {
        if let text = UIPasteboard.general.string, let url = URL(string: text) {
            bookManager.loadText2(from: url) { bookFile in
                guard let bookFile = bookFile else { return }
                
                self.bookManager.plainTextData = bookFile.content
                self.bookManager.plainTextData.append(". This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
                
                self.bookManager.titleData = bookFile.title
                self.bookManager.authorData = bookFile.author
            }
        }
    }
    
    func onSelectBook(book: Book) {
        bookManager.saveCurrentBook(book: book) {
            DispatchQueue.main.async {
                self.path.append(AppScreen.player)
            }
        }
    }
    
    func onFileSelected(fileURL: URL) {
        bookManager.loadText(from: fileURL) { bookFile in
            guard let bookFile = bookFile else {
                return
            }
            
            self.bookManager.plainTextData =  bookFile.content
            self.bookManager.plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
            
            self.bookManager.titleData = bookFile.title
            self.bookManager.authorData = bookFile.author

            DispatchQueue.main.async {
                print("loadText.title => \(bookFile.title)")
                print("loadText.author => \(bookFile.author)")

                self.path.append(AppScreen.newBook)
            }
        }
    }
    
    func onBackToForegraund() {
        if let url = bookManager.openedFilePath {
            bookManager.loadText(from: url) { bookFile in
                self.bookManager.openedFilePath?.stopAccessingSecurityScopedResource()
                self.bookManager.openedFilePath = nil
                guard let bookFile = bookFile else {
                    return
                }
                
                self.bookManager.plainTextData =  bookFile.content
                self.bookManager.plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
                self.bookManager.titleData = bookFile.title
                self.bookManager.authorData = bookFile.author

                DispatchQueue.main.async {
                    print("loadText.title => \(bookFile.title)")
                    print("loadText.author => \(bookFile.author)")
                    self.path.append(AppScreen.newBook)
                }
            }
        }
    }
    
    func onPasteFromClipboard(text: String) {
        bookManager.plainTextData = [text, "Narrated by Run and Read!"]
        path.append(AppScreen.newBook)
    }
    
    func onShowAbout() {
        self.path.append(AppScreen.about)
    }
    
    func isLoading() -> Bool {
        return bookManager.inProgress
    }
}

