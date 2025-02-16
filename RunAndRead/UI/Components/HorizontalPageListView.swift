//
//  HorizontalPageListView.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import SwiftUI

struct HorizontalPageListView: View {
    @Binding var selectedPage: Int
    let totalPages: Int
    let onPageChanged: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(0..<totalPages, id: \.self) { pageIndex in
                        Button(action: {
                            selectedPage = pageIndex
                            onPageChanged(pageIndex)
                        }) {
                            Text("\(pageIndex + 1)")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(selectedPage == pageIndex ? .primary : Color.gray)
                                .foregroundColor(.surface)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    // Detect the first visible item when the view appears
                    let firstVisibleItem = calculateFirstVisibleItem(in: geometry)
                    selectedPage = firstVisibleItem
                    onPageChanged(firstVisibleItem)
                }
                .onChange(of: geometry.frame(in: .global).origin.x) { _ in
                    let firstVisibleItem = calculateFirstVisibleItem(in: geometry)
                    selectedPage = firstVisibleItem
                    onPageChanged(firstVisibleItem)
                }
            }
        }
        .frame(height: 60)
    }
    
    private func calculateFirstVisibleItem(in geometry: GeometryProxy) -> Int {
        let offset = geometry.frame(in: .global).origin.x
        let itemWidth = 50.0 // button width + spacing (if any)
        let firstVisibleIndex = Int(offset / itemWidth)
        return max(0, firstVisibleIndex)
    }
}

#Preview {
    HorizontalPageListView(
        selectedPage: State(initialValue: 3).projectedValue,
        totalPages: 15,
        onPageChanged: {_ in})
}
