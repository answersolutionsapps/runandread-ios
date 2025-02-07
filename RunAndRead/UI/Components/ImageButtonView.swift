//
//  ImageButtonView.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/28/25.
//

import SwiftUI

struct ImageButtonView: View {
    let imageName: String
    var imageColor: Color = .primary
    var backgroundColor: Color = .surface
    let action: () -> Void
    
    var body: some View {
        Button(action: action){
            VStack(alignment: .center) {
                Image(systemName: imageName)
                .imageScale(.large)
                .tint(imageColor)
                .frame(width: 44, height: 44)
            }
        }
            .background(RoundedRectangle(cornerRadius: UIConfig.normalRadius)
                .fill(backgroundColor)
            .onTapGesture {
                action()
            }
    )
    }
}

#Preview {
    ImageButtonView(imageName: "phone",
                    imageColor: .accentColor,
                    action: {}
    )
}
