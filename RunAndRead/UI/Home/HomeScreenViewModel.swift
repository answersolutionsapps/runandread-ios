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
    @Published var filteredBooks: [any RunAndReadBook] = []
    @Published var errorMessage: String? = nil
    @Published var showErrorMessage = false
    
    @Binding var path: NavigationPath
    var bookManager: BookManager

    init(bookManager: BookManager, path: Binding<NavigationPath>) {
        self.bookManager = bookManager
        _path = path
    }
    
    var dataSource: [any RunAndReadBook] {
        return bookManager.library.isEmpty ? bookManager.libraryDefault : bookManager.library
    }
    
    private func updateFilteredBooks() {
        filteredBooks = dataSource.sorted(by: { b1, b2 in
            b1.created > b2.created
        }).filter {
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
        DispatchQueue.main.async {
            self.bookManager.inProgress = true
        }
        bookManager.loadText(from: fileURL) { bookFile, error in
            guard let bookFile = bookFile else {
                DispatchQueue.main.async {
                    self.errorMessage = error
                    self.showErrorMessage = true
                    self.bookManager.inProgress = false
                }
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
            bookManager.loadText2(from: url) { bookFile, error in
                guard let bookFile = bookFile else {
                    DispatchQueue.main.async {
                        self.errorMessage = error
                        self.showErrorMessage = true
                        self.bookManager.inProgress = false
                    }
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
    }
    
    func onSelectBook(book: any RunAndReadBook) {
        bookManager.saveCurrentBook(book: book) {
            DispatchQueue.main.async {
                self.path.append(AppScreen.player)
            }
        }
    }
    
    func onFileSelected(fileURL: URL) {
        DispatchQueue.main.async {
            self.bookManager.inProgress = true
        }
//        TimeLogger.log("onFileSelected", message: "before.loadText")
        bookManager.loadText(from: fileURL) { bookFile, error in
            guard let bookFile = bookFile else {
                DispatchQueue.main.async {
                    self.errorMessage = error
                    self.showErrorMessage = true
                    self.bookManager.inProgress = false
                }
                return
            }
            
            if bookFile.content.isEmpty {
                self.bookManager.plainTextPartData =  bookFile.text
                self.bookManager.audioPath =  bookFile.audioPath
                self.bookManager.plainTextData = []
            } else {
                self.bookManager.audioPath = ""
                self.bookManager.plainTextPartData = []
                self.bookManager.plainTextData =  bookFile.content
                self.bookManager.plainTextData.append("This text has been narrated by the Run and Read app! We hope you enjoyed listening!")
            }
            
            self.bookManager.titleData = bookFile.title
            self.bookManager.authorData = bookFile.author

            DispatchQueue.main.async {
                print("loadText.title => \(bookFile.title)")
                print("loadText.author => \(bookFile.author)")
//                TimeLogger.log("onFileSelected", message: "loadText.title")
                self.path.append(AppScreen.newBook)
                
                DispatchQueue.main.async {
                    self.bookManager.inProgress = false
//                    TimeLogger.log("onFileSelected", message: "loadText.inProgress")
                }
                
            }
        }
    }
    
    func onBackToForegraund() {
        if let url = bookManager.openedFilePath {
            bookManager.loadText(from: url) { bookFile, error in
                self.bookManager.openedFilePath?.stopAccessingSecurityScopedResource()
                self.bookManager.openedFilePath = nil
                guard let bookFile = bookFile else {
                    DispatchQueue.main.async {
                        self.errorMessage = error
                        self.showErrorMessage = true
                        self.bookManager.inProgress = false
                    }
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
                    self.bookManager.inProgress = false
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
    
    @MainActor func onShowFilePicker(){
        showFilePicker = true
    }
}

