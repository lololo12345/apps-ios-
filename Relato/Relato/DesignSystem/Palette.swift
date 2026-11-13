import SwiftUI
import UIKit

/// Relato's color system. Every color adapts to light and dark mode.
///
/// Identity: "campfire at night" — warm ember accents over deep ink in dark mode,
/// and over warm paper in light mode, so long scripts are comfortable to read.
enum Palette {
    // Accents (one per narrative role)
    static let ember = Color(light: 0xE8512F, dark: 0xFF7A55)
    static let magenta = Color(light: 0xD1306F, dark: 0xFF5C9A)
    static let violet = Color(light: 0x6D4AE0, dark: 0x9D85FF)
    static let sky = Color(light: 0x1F7FD6, dark: 0x5DB5FF)
    static let amber = Color(light: 0xC98A06, dark: 0xFFC53D)
    static let mint = Color(light: 0x15936B, dark: 0x4FD8A6)
    static let crimson = Color(light: 0xC8263A, dark: 0xFF5266)
    static let slate = Color(light: 0x6B6F80, dark: 0x9A9EB2)

    // Surfaces
    static let canvas = Color(light: 0xF6F2EC, dark: 0x0A0A10)
    static let surface = Color(light: 0xFFFFFF, dark: 0x16161F)
    static let surfaceSunken = Color(light: 0xEFEAE3, dark: 0x101017)
    static let hairline = Color(light: 0x000000, lightAlpha: 0.07, dark: 0xFFFFFF, darkAlpha: 0.08)

    static let record = Color(light: 0xE5263D, dark: 0xFF3B4E)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [ember, magenta, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(light: UInt32, lightAlpha: CGFloat = 1, dark: UInt32, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum Metrics {
    static let cardRadius: CGFloat = 24
    static let smallRadius: CGFloat = 14
    static let gutter: CGFloat = 16
}
