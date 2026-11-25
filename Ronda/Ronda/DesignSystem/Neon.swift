import SwiftUI
import UIKit

/// Ronda's identity: neon on near-black, like a club at night. It starts dark (it is played in dim rooms,
/// and a bright screen in the middle of the table ruins the atmosphere), but Ajustes → Apariencia offers
/// light mode too: the same neon over a soft lilac dawn.
enum Neon {
    static let cyan = Color(hex: 0x2EE6FF)
    static let violet = Color(hex: 0x8B5CFF)
    static let magenta = Color(hex: 0xFF3FD8)
    static let lime = Color(hex: 0xB6FF3B)
    static let orange = Color(hex: 0xFF7A2F)
    static let amber = Color(hex: 0xFFC234)
    static let crimson = Color(hex: 0xFF2E5E)
    static let rose = Color(hex: 0xFF6FA8)

    /// Always near-black: text and strokes on top of bright neon fills (roulette labels, «¡TOCA!»…).
    static let ink = Color(hex: 0x07060D)
    /// The two canvases, for previews.
    static let night = Color(hex: 0x07060D)
    static let dawn = Color(hex: 0xF3EEFF)

    /// Screen background: night in dark mode, a soft lilac dawn in light mode.
    static let canvas = adaptive(dark: 0x07060D, light: 0xF3EEFF)
    static let canvasDeep = adaptive(dark: 0x07060D, light: 0xE6F6FF)
    static let surface = adaptive(dark: 0x15121F, light: 0xFFFFFF, lightOpacity: 0.78)
    static let surfaceRaised = adaptive(dark: 0x1E1A2C, light: 0xEFE9FF)
    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.09) : UIColor.black.withAlphaComponent(0.08)
    })

    static func accent(for mode: PartyMode) -> Color { mode == .hot ? crimson : violet }

    private static func adaptive(dark: UInt32, light: UInt32, lightOpacity: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light).withAlphaComponent(lightOpacity)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
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

/// Static glow backdrop. Radial gradients instead of large blurs: identical look, but no
/// per-frame blur filter, so animations on top of it stay at the display's full refresh rate.
struct NightBackground: View {
    var colors: [Color]
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        GeometryReader { proxy in
            let size = proxy.size
            let longest = max(size.width, size.height)
            ZStack {
                LinearGradient(colors: [Neon.canvas, Neon.canvasDeep], startPoint: .top, endPoint: .bottom)
                glow(colors.first ?? Neon.violet, dark ? 0.42 : 0.30, UnitPoint(x: 0.1, y: 0.05), longest * 0.62)
                glow(colors.last ?? Neon.cyan, dark ? 0.32 : 0.24, UnitPoint(x: 0.95, y: 0.95), longest * 0.58)
                // Third, fainter light in between: more colour for the glass to refract.
                glow(Neon.magenta, dark ? 0.14 : 0.10, UnitPoint(x: 0.95, y: 0.35), longest * 0.45)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, _ opacity: Double, _ center: UnitPoint, _ radius: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), .clear], center: center,
                       startRadius: 0, endRadius: radius)
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
                    // Soft sheen from the top: the card reads as glass, not a flat panel.
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [(colors.first ?? .clear).opacity(0.14), .clear], startPoint: .top, endPoint: .center))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    }
                    .shadow(color: (colors.first ?? .clear).opacity(0.3), radius: 18, y: 8)
            }
    }
}

extension View {
    func neonCard(_ colors: [Color], radius: CGFloat = Metrics.radius, padding: CGFloat = 20) -> some View {
        modifier(NeonCard(colors: colors, radius: radius, padding: padding))
    }

    /// Neon gradient text. In light mode the colours are deepened so lime or cyan stay readable on a pale card.
    func gradientText(_ colors: [Color]) -> some View {
        modifier(GradientText(colors: colors))
    }

    /// Fades and lifts the view in when it first appears; pass increasing `order`s for a cascade.
    func appearAnimation(order: Int = 0) -> some View {
        modifier(AppearAnimation(delay: Double(order) * 0.06))
    }
}

private struct GradientText: ViewModifier {
    let colors: [Color]
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shown = scheme == .dark ? colors : colors.map { $0.mix(with: .black, by: 0.32) }
        content.foregroundStyle(LinearGradient(colors: shown, startPoint: .leading, endPoint: .trailing))
    }
}

private struct AppearAnimation: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                // No cascade under UI tests: screenshots must never catch a card half-way in.
                if LaunchOptions.isUITesting || reduceMotion {
                    shown = true
                } else {
                    withAnimation(.smooth(duration: 0.45).delay(delay)) { shown = true }
                }
            }
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

/// Feedback generators are created once and kept prepared, so every vibration fires with no latency.
@MainActor
enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard enabled else { return }
        let generator: UIImpactFeedbackGenerator = switch style {
        case .heavy: heavy
        case .medium: medium
        case .rigid: rigid
        default: light
        }
        generator.impactOccurred()
        generator.prepare()
    }

    /// Short crisp tick (roulette segments, bomb fuse).
    static func tick(intensity: CGFloat = 0.6) {
        guard enabled else { return }
        rigid.impactOccurred(intensity: intensity)
        rigid.prepare()
    }

    static func select() {
        guard enabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    static func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func warning() {
        guard enabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    static func boom() {
        guard enabled else { return }
        notification.notificationOccurred(.error)
        heavy.impactOccurred(intensity: 1)
        heavy.prepare()
    }

    /// Call when a screen with frequent feedback appears.
    static func prepare() {
        guard enabled else { return }
        light.prepare()
        rigid.prepare()
        selection.prepare()
    }
}

// MARK: - Motion

/// Card dealt from a deck: the new card scales up from behind, the old one is flicked away.
struct DeckDealModifier: ViewModifier {
    let offset: CGFloat
    let rotation: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .offset(x: offset)
            .opacity(opacity)
    }
}

/// Card turned over around the vertical axis.
struct FlipModifier: ViewModifier {
    let angle: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .opacity(opacity)
    }
}

/// Horizontal shake for impacts (bomb explosion). `shakes` animates from n to n+1.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amplitude: CGFloat = 12

    nonisolated var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = shakes - shakes.rounded(.down)
        let damping = 1 - progress
        let x = sin(progress * .pi * 8) * amplitude * damping
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

extension AnyTransition {
    /// Deck deal, or a plain cross-fade when Reduce Motion is on.
    static func deal(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(
                active: DeckDealModifier(offset: 0, rotation: 0, scale: 0.86, opacity: 0),
                identity: DeckDealModifier(offset: 0, rotation: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: DeckDealModifier(offset: -420, rotation: -14, scale: 0.96, opacity: 0),
                identity: DeckDealModifier(offset: 0, rotation: 0, scale: 1, opacity: 1)
            )
        )
    }

    static func flip(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: FlipModifier(angle: -90, opacity: 0), identity: FlipModifier(angle: 0, opacity: 1)),
            removal: .modifier(active: FlipModifier(angle: 90, opacity: 0), identity: FlipModifier(angle: 0, opacity: 1))
        )
    }
}
