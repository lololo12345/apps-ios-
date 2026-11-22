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

/// Static glow backdrop. Radial gradients instead of large blurs: identical look, but no
/// per-frame blur filter, so animations on top of it stay at the display's full refresh rate.
struct NightBackground: View {
    var colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Neon.ink
                RadialGradient(
                    colors: [(colors.first ?? Neon.violet).opacity(0.42), .clear],
                    center: UnitPoint(x: 0.1, y: 0.05),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.62
                )
                RadialGradient(
                    colors: [(colors.last ?? Neon.cyan).opacity(0.34), .clear],
                    center: UnitPoint(x: 0.95, y: 0.95),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.58
                )
                // Extra glows so the glass always has colour to bend.
                RadialGradient(
                    colors: [(colors.last ?? Neon.cyan).opacity(0.22), .clear],
                    center: UnitPoint(x: 1.0, y: 0.3),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.42
                )
                RadialGradient(
                    colors: [(colors.first ?? Neon.violet).opacity(0.2), .clear],
                    center: UnitPoint(x: 0.0, y: 0.7),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.45
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Liquid Glass card tinted with the game's colours, with a thin neon rim and a coloured glow underneath.
struct NeonCard: ViewModifier {
    var colors: [Color]
    var radius: CGFloat = Metrics.radius
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .glassEffect(.regular.tint((colors.first ?? Neon.violet).opacity(0.16)), in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: colors.map { $0.opacity(0.6) } + [Color.white.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            }
            .shadow(color: (colors.first ?? .clear).opacity(0.28), radius: 18, y: 8)
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
