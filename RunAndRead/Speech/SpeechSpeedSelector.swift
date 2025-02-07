//
//  SpeechSpeedSelector.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/31/25.
//

import SwiftUI

struct SpeechSpeedSelector: View {
    let speeds: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    @State private var selectedSpeed: Float

    var onSpeedSelected: (Float) -> Void

    init(defaultSpeed: Float, onSpeedSelected: @escaping (Float) -> Void) {
        _selectedSpeed = State(initialValue: defaultSpeed)
        self.onSpeedSelected = onSpeedSelected
        nprint("_selectedSpeed=>\(_selectedSpeed)")
    }

    var body: some View {
        VStack(alignment: .center) {
            Text("Speech Rate")
                    .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(speeds, id: \.self) { speed in
                        Text(String(format: "%.2f", speed))
                                .font(.headline)
                                .frame(width: 50, height: 50)
                                .background(selectedSpeed == speed ? .accentColor : Color.gray.opacity(0.3))
                                .foregroundColor(selectedSpeed == speed ? Color.white : .black)
                                .cornerRadius(0)
                                .onTapGesture {
                                    selectedSpeed = speed
                                    onSpeedSelected(speed)
                                }
                    }
                }
            }
        }
                .padding()
    }
}


#Preview {
    SpeechSpeedSelector(defaultSpeed: 1.0) { newSpeed in
        print("Selected speed: \(newSpeed)")
    }
}
