import SwiftUI
import AVFoundation

struct BookPlayerView: View {
    @EnvironmentObject var bookManager: BookManager
    @EnvironmentObject var player: TextToSpeechPlayer
    @Binding var path: NavigationPath
    @State private var isDragging = false
    @State private var currentTime: TimeInterval = 0
    @State private var currentDuration: TimeInterval = 0
    
    
    @State private var currentFrame: [String] = []
    
    @State private var currentWordIndexInFrame = 0
    
    struct ContentView: View {
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
                                .foregroundColor(index == (idx - 1) ? UIConfig.backgroundColor : UIConfig.primaryColor)
                                .background(index == (idx - 1) ? UIConfig.accentColor : Color.clear)
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
    

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                
                VStack {
                    
                    if let book = bookManager.currentBook {
                        if !currentFrame.isEmpty {
                            ContentView(
                                words: currentFrame,
                                index: currentWordIndexInFrame,
                                locale: book.language)
                                .frame(maxWidth: .infinity, maxHeight: 150)
                        }
                        Spacer()
                        // Book cover and details
                        VStack(spacing: 16) {
                            
                            Text(book.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(book.author)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    
                        VStack {
                            Slider(value: $currentTime,
                                   in: 0...currentDuration,
                                   onEditingChanged: { editing in
                                
                                if !editing {
                                    bookManager.updateLastPositionWith(elapsedTime: Float(currentTime))
                                }
                            })
                            HStack{
                                Text("\(currentTime.formatSecondsToHMS(currentTime))").padding(.leading, 4)
                                Spacer()
                                Text("\(currentDuration.formatSecondsToHMS(currentDuration))").padding(.trailing, 4)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Playback controls
                        HStack(spacing: 40) {
                            Button(action: {
                                player.rewind()
                            }) {
                                Image(systemName: "gobackward.5")
                                    .font(.title)
                            }
                            
                            Button(action: {
                                player.playPause()
                            }) {
                                Image(systemName: player.isPlaying() ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                            }
                            
                            Button(action: {
                                player.fastForward()
                            }) {
                                Image(systemName: "goforward.5")
                                    .font(.title)
                            }
                        }
                        .padding(.bottom, 40)
                        .onAppear {
                            bookManager.loadCurrentBook {
                                if let b = bookManager.currentBook {
                                    self.player.setup(
                                        text: b.text,
                                        progressCallback: { progress, currentWord, frame, indexInFrame in
                                            DispatchQueue.main.async {
                                                self.currentFrame = frame
                                                self.currentWordIndexInFrame = indexInFrame
                                                self.currentTime = TimeInterval(progress)
                                                bookManager.updateLastPosition(for: b.id, newPosition: Float(currentWord))
                                            }
                                        }
                                    )
                                    DispatchQueue.main.async {
                                        self.player.loadSelectedVoice(currentBook: b)
                                        self.player.currentWordIndex = Int(b.lastPosition)
                                        self.player.updateProgress()
                                        self.currentDuration = TimeInterval(self.player.totalTime)
                                    }
                                }
                            }
                        }.onDisappear {
                            DispatchQueue.main.async {
                                self.currentWordIndexInFrame = 0
                                self.currentFrame.removeAll()
                                self.bookManager.persist {_ in
                                    
                                }
                                self.player.stop()
                            }
                        }
                    } else {
                        Text("Error: No book found")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }.padding()
            }
//            if bookManager.inProgress {
//                CustomActivityIndicator()
//            }
        }
 
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                    leading:
                        Button(action: {
                            self.currentWordIndexInFrame = 0
                            self.currentFrame.removeAll()
                            self.bookManager.persist {_ in
                                self.bookManager.deleteCurrentBook {
                                    path.removeLast(path.count)
                                    path.append(AppScreen.home)
                                }
                            }
                        }, label: {
                            Text("Library").font(UIConfig.buttonFont)
                        }),
                    trailing: Button(action: {
                            path.append(AppScreen.newBook)
                    }, label: {
                        Text("Edit").font(UIConfig.buttonFont)
                    })
                )
                .navigationBarHidden(false)
                .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
        BookPlayerView(path: path.projectedValue)
    }
    .environmentObject(returnBookManagerForPreview())
    .environmentObject(TextToSpeechSimplePlayer())
    .environmentObject(TextToSpeechPlayer())
}

