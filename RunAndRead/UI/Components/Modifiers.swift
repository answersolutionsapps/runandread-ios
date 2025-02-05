//
//  Modifiers.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/4/25.
//

import SwiftUI

struct TextModifier: ViewModifier {
    private let font: UIFont
    private let color: Color
    private let multilineTextAlignment: TextAlignment
    
    init(font: UIFont, color: Color = .black, multilineTextAlignment: TextAlignment = .center) {
        self.font = font
        self.color = color
        self.multilineTextAlignment = multilineTextAlignment
    }
    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .font(.custom(font.fontName, size: font.pointSize))
            .foregroundColor(color)
            .multilineTextAlignment(multilineTextAlignment)
            .lineLimit(nil)
    }
}

struct ButtonModifier: ViewModifier {
    private let font: UIFont
    private let color: Color
    private let textColor: Color
    private let width: CGFloat?
    private let height: CGFloat?
    
    init(font: UIFont,
         color: Color,
         textColor: Color = .white,
         width: CGFloat? = nil,
         height: CGFloat? = nil) {
        self.font = font
        self.color = color
        self.textColor = textColor
        self.width = width
        self.height = height
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(TextModifier(font: font, color: textColor))
            .padding()
            .frame(width: width, height: height)
            .background(color)
            .cornerRadius(0)
    }
}

struct LongButtonView: View {
    let title: String
    var backgroundColor: Color = UIConfig.primaryColor
    var textColor: Color = .white
    
    var body: some View {
        Text(title)
        .modifier(ButtonModifier(font: UIConfig.buttonFont2,
                                         color: backgroundColor,
                                         textColor: textColor,
                                         width: UIConfig.actionButtonWidth,
                                         height: UIConfig.actionButtonHeight))
    }
}
