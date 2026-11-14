import SwiftUI

/// Colours shared by the app and the widget: warm sunset tones that work in light and dark mode.
public enum Palette {
    public static let coral = Color(red: 1.00, green: 0.42, blue: 0.42)
    public static let rose = Color(red: 0.98, green: 0.35, blue: 0.62)
    public static let plum = Color(red: 0.55, green: 0.33, blue: 0.85)
    public static let peach = Color(red: 1.00, green: 0.66, blue: 0.45)
    public static let sky = Color(red: 0.35, green: 0.65, blue: 1.00)
    public static let mint = Color(red: 0.25, green: 0.80, blue: 0.62)
    public static let gold = Color(red: 1.00, green: 0.78, blue: 0.30)
    public static let ember = Color(red: 0.90, green: 0.18, blue: 0.35)

    public static let brand: [Color] = [coral, rose, plum]
}

public extension Mood {
    var colors: [Color] {
        switch self {
        case .calm: [Palette.mint, Palette.sky]
        case .romantic: [Palette.rose, Palette.coral]
        case .active: [Palette.peach, Palette.coral]
        case .adventure: [Palette.sky, Palette.plum]
        case .creative: [Palette.gold, Palette.peach]
        }
    }
}

public extension Plan {
    var colors: [Color] { intimate ? [Palette.ember, Palette.plum] : mood.colors }
}
