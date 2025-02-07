//
//  HorizontalyScrolledTextView.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import SwiftUI

struct HorizontalyScrolledTextView: View {
    var words: [String] = []
    var idx: Int = -1
    var locale: Locale

    @State private var scrollProxy: ScrollViewProxy?

    init(words: [String], index: Int, locale: Locale) {
        self.idx = index
        self.words = words
        self.locale = locale
    }
    
    // Compute whether the locale is right-to-left.
    var isRTL: Bool {
        if let languageCode = locale.language.languageCode?.identifier {
            return Locale.Language(identifier:languageCode).characterDirection == .rightToLeft
        }
        return false
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack {
                    ForEach(words.indices, id: \.self) { index in
                        Text(words[index])
                            .font(.title2)
                            .fontWeight(index == (idx - 1) ? .bold : .regular)
                            .foregroundColor(index == (idx - 1) ? .background : .primary)
                            .background(index == (idx - 1) ? .accentColor : Color.clear)
                            .id(index) // Assign an ID for scrolling
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToCurrentWord(proxy: proxy)
                }
                .onChange(of: idx) { _ in
                    scrollToCurrentWord(proxy: proxy)
                }
            }
        }
        // Set the layout direction of the ScrollView only
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .frame(height: 50) // Adjust height as needed
    }

    private func scrollToCurrentWord(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(idx, anchor: .center)
        }
    }
}

#Preview {
    HorizontalyScrolledTextView(
        words: ["Test 123", "Test 345", "Test 567"],
        index: 0,
        locale: Locale.current
    )
}
