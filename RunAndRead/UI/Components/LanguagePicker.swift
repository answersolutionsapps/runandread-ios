//
//  LanguagePicker.swift
//  TalkWise
//
//  Created by Serge Nes on 4/1/23.
//


import SwiftUI
import AVFoundation

struct LimitedDictionary {
    let limit: UInt
    private(set) var values: [String] = []

    init(limit: UInt) {
        self.limit = limit
    }

    mutating func push(value: String) {
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        }
        values.insert(value, at: 0)
        if values.count > limit {
            values.removeLast()
        }
    }
}

struct LanguagePicker: View {
    var title = "Select the main language of this book"
    @Environment(\.presentationMode) var presentationMode
    @StateObject var viewModel: BookSettingsViewModel
    
    @State private var recentSelections = LimitedDictionary(limit: 5)
    @State private var recentlySelectedLanguages: [Locale] = []
    @State private var untestedLanguages: [Locale] = []
    @State private var supportedLanguages: [Locale] = []
    
    
    func languageString(locale: Locale) -> String {
        let regionCode = locale.region?.identifier ?? "Unknown"
        let lng = locale.localizedString(forLanguageCode: locale.identifier) ?? "Unknown"
        let reg = locale.localizedString(forRegionCode: regionCode) ?? "Unknown"
        return "\(lng) (\(reg) - \(regionCode))"
    }
    
    func recentOptions() -> [Locale] {
        supportedLanguages.filter { recentSelections.values.contains($0.identifier) }
    }

    func setRecentLangSelection(selected: Locale) {
        recentSelections.push(value: selected.identifier)
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.set(self.recentSelections.values, forKey: "recentSelections")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(title)
                    .font(.title2)
                    .multilineTextAlignment(.leading)
                
                List {
                    if !recentlySelectedLanguages.isEmpty {
                        Section(header: Text("Recent Selections")) {
                            ForEach(recentlySelectedLanguages, id: \.identifier) { language in
                                Button(action: {
                                    viewModel.onSelectLanguage(language: language)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack {
                                        Text(languageString(locale: language))
                                            .font(.title2)
                                            
                                        Spacer()
                                        if language == viewModel.selectedLanguage {
                                            Image(systemName: "checkmark").tint(.accentColor)
                                        }
                                    }
                                }
                                .tint(.accentColor)
                                .padding(.vertical, UIConfig.smallSpace)
                            }
                        }
                    }

                    Section(header: Text("All Supported Languages")) {
                        ForEach(untestedLanguages, id: \.identifier) { language in
                            Button(action: {
                                viewModel.onSelectLanguage(language: language)
                                setRecentLangSelection(selected: language)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Text(languageString(locale: language))
                                        .font(.title2)
                                        .tint(.accentColor)
                                    Spacer()
                                    if language == viewModel.selectedLanguage {
                                        Image(systemName: "checkmark").tint(.accentColor)
                                    }
                                }
                            }
                            .padding(.vertical, UIConfig.smallSpace)
                        }
                    }
                }
                .listStyle(.grouped)
            }
            .task {
                
            }
            .onAppear {
                let uniqueLanguageIdentifiers = Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language })
                self.supportedLanguages = uniqueLanguageIdentifiers.map { Locale(identifier: $0) }
                if let savedSelections = UserDefaults.standard.stringArray(forKey: "recentSelections") {
                    savedSelections.forEach { recentSelections.push(value: $0) }
                }
                recentlySelectedLanguages = recentOptions()
                untestedLanguages = supportedLanguages.sorted { languageString(locale: $0) < languageString(locale: $1) }
            }
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.font(UIConfig.buttonFont).tint(.accentColor))
        }.accentColor(Color("AccentColor"))
    }
}


#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
        LanguagePicker(
                viewModel: BookSettingsViewModel(
                        path: path.projectedValue,
                        bookManager: BookManager(),
                        simplePlayer: SimpleTTSPlayer())).accentColor(Color("AccentColor"))
    }
}
