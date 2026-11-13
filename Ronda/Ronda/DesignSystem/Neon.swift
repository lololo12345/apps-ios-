import SwiftUI
import UIKit

/// Ronda's identity: neon on near-black, like a club at night. The app is dark-only on purpose
/// (UIUserInterfaceStyle = Dark): it is played in dim rooms at night, and a bright screen in the
/// middle of the table would ruin the atmosphere.
enum Neon {
    static let cyan = Color(hex: 0x2EE6FF)
    static let violet = Color(hex: 0x8B5CFF)
    static let magenta = Color(hex: 0xFF3FD8)
    static let lime = Color(hex: 0xB6FF3B)
    static let orange = Color(hex: 0xFF7A2F)
    static let amber = Color(hex: 0xFFC234)
    static let crimson = Color(hex: 0xFF2E5E)
    static let rose = Color(hex: 0xFF6FA8)

    static let ink = Color(hex: 0x07060D)
    static let surface = Color(hex: 0x15121F)
    static let surfaceRaised = Color(hex: 0x1E1A2C)
    static let hairline = Color.white.opacity(0.09)

    static func accent(for mode: PartyMode) -> Color { mode == .hot ? crimson : violet }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Metrics {
    static let gutter: CGFloat = 16
    static let radius: CGFloat = 26
}

/// Static glow backdrop (no per-frame work).
struct NightBackground: View {
    var colors: [Color]

    var body: some View {
        ZStack {
            Neon.ink
            Circle()
                .fill(colors.first ?? Neon.violet)
                .frame(width: 420, height: 420)
                .blur(radius: 140)
                .opacity(0.45)
                .offset(x: -140, y: -320)
            Circle()
                .fill(colors.last ?? Neon.cyan)
                .frame(width: 380, height: 380)
                .blur(radius: 150)
                .opacity(0.35)
                .offset(x: 160, y: 360)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Card surface with a neon gradient rim.
struct NeonCard: ViewModifier {
    var colors: [Color]
    var radius: CGFloat = Metrics.radius
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Neon.surface.opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    }
                    .shadow(color: (colors.first ?? .clear).opacity(0.35), radius: 24, y: 8)
            }
    }
}

extension View {
    func neonCard(_ colors: [Color], radius: CGFloat = Metrics.radius, padding: CGFloat = 20) -> some View {
        modifier(NeonCard(colors: colors, radius: radius, padding: padding))
    }

    func gradientText(_ colors: [Color]) -> some View {
        foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
    }
}

/// Subtle scale-down on press.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

@MainActor
enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func select() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func boom() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
    }
}
