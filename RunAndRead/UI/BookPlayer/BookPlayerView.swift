import SwiftUI
import AVFoundation

struct BookPlayerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel: BookPlayerViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                VStack {
                    if let book = viewModel.currentBook() {
                        BookmarkListView(book: book)
                        Divider()
                        BookCoverDetailsView(book: book)
                        PositionSliderView(book: book)
                        Divider()
                        HorizontalyScrolledTextView(
                            highlite: (book is Book),
                                words: viewModel.currentFrame,
                                index: viewModel.currentWordIndexInFrame,
                                locale: book.language)
                                .frame(maxWidth: .infinity, maxHeight: 60)
                        Divider()
                        PlaybackContrallsView(book: book)
                    } else if viewModel.isInitializing() {
                        Spacer()
                        Text("Loading...")
                        Spacer()
                    } else {
                        Spacer()
                        Text("Error: No book found")
                                .foregroundColor(.red)
                        Spacer()
                    }
                }
                        .padding()
            }
        }
                .onAppear {
                    if !isPreview {
                        viewModel.setupBook()
                    } else {
                        viewModel.setupForPreview()
                    }
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
                .onDisappear {
                    viewModel.stopPlayer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                        leading:
                        Button(action: {
                            viewModel.onGoToLibrary()
                        }, label: {
                            Text("Library").font(UIConfig.buttonFont)
                        }),
                        trailing:
                        Button(action: {
                            viewModel.onEditAction()
                        }, label: {
                            Text("Edit").font(UIConfig.buttonFont)
                        })
                )
                .navigationBarHidden(false)
                .navigationBarBackButtonHidden(true)
    }

    private func BookCoverDetailsView(book: any RunAndReadBook) -> some View {
        return VStack(spacing: 16) {
            Text(book.title)
                    .font(.title)
                    .lineLimit(3)
                    .fontWeight(.bold)

            Text(book.author)
                    .font(.title2)
                    .foregroundColor(.secondary)
        }
    }

    private func PlaybackContrallsView(book: any RunAndReadBook) -> some View {
        return VStack {
            HStack(spacing: 40) {
                Button(action: { viewModel.onRewind() }) {
                    Image(systemName: "gobackward.30")
                            .font(.largeTitle)
                }
                        .accessibilityLabel("Rewind 30 seconds")
                Button(action: {
                    viewModel.onPlayPause()
                }) {
                    Image(systemName: viewModel.playButtonIconName())
                            .font(.system(size: 64))
                }
                        .accessibilityLabel("Play and Pause")
                Button(action: { viewModel.onFastForward() }) {
                    Image(systemName: "goforward.30")
                            .font(.largeTitle)
                }
                        .accessibilityLabel("Fastforward 30 seconds")
            }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

            VStack(alignment: .trailing) {
                Button(action: {
                    viewModel.addBookmark()
                    viewModel.generateBookmarks(book: book)
                }) {
                    Image(systemName: "bookmark.circle")
                            .font(.largeTitle)
                }
                        .disabled(!viewModel.isPlaying())
                        .accessibilityLabel("Add a bookmark")
            }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
        }
    }

    private func PositionSliderView(book: any RunAndReadBook) -> some View {
        return VStack {
            Slider(value: $viewModel.currentTime,
                    in: 0...viewModel.currentDuration,
                    onEditingChanged: { editing in
                        if !editing {
                            viewModel.updatePosition(book: book)
                        }
                    }
            )
            HStack {
                Text("\(viewModel.currentTimeString)").padding(.leading, 4)
                Spacer()
                Text("\(viewModel.currentDurationString)").padding(.trailing, 4)
            }
        }
                .padding(.horizontal)
    }

    private func BookmarkListView(book: any RunAndReadBook) -> some View {
        return List {
            ForEach(book.bookmarks, id: \.position) { item in
                Text(item.text)
                    .font(.title3)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                        .padding(10)
                        .onTapGesture {
                            viewModel.onBookmarkSelect(bookmark: item)
                        }
            }
                    .onDelete { indices in
                        for index in indices {
                            let bookmarkToDelete = book.bookmarks[index]
                            // Remove the bookmark from the data source (array)
                            // Assuming book.bookmarks is a mutable array
                            if let index = book.bookmarks.firstIndex(where: { $0.position == bookmarkToDelete.position }) {
                                book.bookmarks.remove(at: index)
                            }
                        }
                    }
        }
        .listStyle(.plain)
        .onAppear {
            viewModel.generateBookmarks(book: book)
        }
    }
}


#Preview {
    NavigationView {
        let path = State(initialValue: NavigationPath())
       
        BookPlayerView(viewModel: BookPlayerViewModel(
                path: path.projectedValue,
                bookManager: returnBookManagerForPreview(),
                player: TextToSpeechPlayer(), audioPlayer: AudioBookPlayer()))
    }
            .environmentObject(returnBookManagerForPreview())

}

