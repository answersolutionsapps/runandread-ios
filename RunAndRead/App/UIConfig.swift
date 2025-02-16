//
//  UIConfig.swift
//  RunAndRead
//
//  Created by Serge Nes on 1/27/25.
//

import SwiftUI
import UIKit

extension Color {
    static let primary = Color("Primary")
//    static let surface = Color("Surface")
}

class UIConfig {
    static let buttonFont2 = UIFont(name: "Avenir-Heavy", size: 20)!
    static let buttonFont = Font.custom("Avenir-Heavy", size: 20)
    
    static let normalRadius = 10.0
    static let cornerRadiusFixed = 45.0
    
    static let noSpace = 0.0
    static let minimalSpace = 4.0
    static let smallSpace = 8.0
    static let normalSpace = 16.0
    static let largeSpace = 32.0
    
    static let dialogButtonWidth = 155.0
    static let actionButtonWidth = 275.0
    static let actionButtonHeight = 45.0
}
