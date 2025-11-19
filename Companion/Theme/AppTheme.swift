// periphery:ignore:all
//
//  AppTheme.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import SwiftUI

struct AppTheme {
    static let primaryDark = Color(hex: "#3D3D3E")
    static let primaryOrange = Color(hex: "#F8654B")
    
    static let backgroundColor = Color(UIColor.systemBackground)
    static let secondaryBackgroundColor = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackgroundColor = Color(UIColor.tertiarySystemBackground)
    
    static let labelColor = Color(UIColor.label)
    static let secondaryLabelColor = Color(UIColor.secondaryLabel)
    static let tertiaryLabelColor = Color(UIColor.tertiaryLabel)
    
    static let separatorColor = Color(UIColor.separator)
    
    static let successColor = Color.green
    static let errorColor = Color.red
    static let warningColor = Color.orange
    
    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    
    static let shadowColor = Color.black.opacity(0.1)
    static let shadowRadius: CGFloat = 4
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
