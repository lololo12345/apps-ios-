import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

enum Palette {
    static let accent = Color(hex: 0x2BB3A3)
    static let accentSoft = Color(hex: 0x75CDC3)
    static let background = Color(hex: 0x0B1D2E)
    static let backgroundDeep = Color(hex: 0x060F19)
    static let good = Color(hex: 0x3DDC97)
    static let bad = Color(hex: 0xFF5A6E)
    /// Warm sunset glow (third background light), the travel counterpart of the sea-green accent.
    static let secondary = Color(hex: 0xFFB547)
    static let sky = Color(hex: 0x6FA8FF)
    static let brand: [Color] = [accentSoft, accent]
}

enum Metrics {
    /// Side margin of every screen (also the minimum on the smallest iPhone).
    static let gutter: CGFloat = 16
    static let radius: CGFloat = 24
}

/// Screen background: a vertical gradient plus two soft glows. Radial gradients only (no blur),
/// so scrolling and animations on top stay at 120 Hz.
struct AppBackground: View {
    var glow: Color = Palette.accent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        GeometryReader { proxy in
            let longest = max(proxy.size.width, proxy.size.height)
            ZStack {
                if dark {
                    LinearGradient(colors: [Palette.background, Palette.backgroundDeep], startPoint: .top, endPoint: .bottom)
                } else {
                    // Soft sky instead of plain grey: the glass picks up the colour.
                    LinearGradient(colors: [Color(hex: 0xEAF6F4), Color(hex: 0xF4F1EA)], startPoint: .top, endPoint: .bottom)
                }
                // Colour for the glass to refract: Liquid Glass looks best over soft, saturated light.
                glowSpot(glow, dark ? 0.42 : 0.34, at: UnitPoint(x: 0.95, y: 0.0), radius: longest * 0.62)
                glowSpot(Palette.accentSoft, dark ? 0.26 : 0.24, at: UnitPoint(x: 0.0, y: 0.45), radius: longest * 0.55)
                glowSpot(Palette.secondary, dark ? 0.24 : 0.22, at: UnitPoint(x: 0.9, y: 1.0), radius: longest * 0.55)
                glowSpot(Palette.sky, dark ? 0.18 : 0.16, at: UnitPoint(x: 0.1, y: 1.0), radius: longest * 0.45)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glowSpot(_ color: Color, _ opacity: Double, at center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), .clear], center: center,
                       startRadius: 0, endRadius: radius)
    }
}

extension View {
    /// Rounded Liquid Glass surface used for every card. Pass a tint to colour it.
    func card(tint: Color? = nil, radius: CGFloat = Metrics.radius) -> some View {
        let glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? .regular
        return padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: radius))
            .overlay {
                // Thin light rim: the glass edge reads clearly on pale backgrounds too.
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
    }

    func brandGradientText() -> some View {
        foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .leading, endPoint: .trailing))
    }

    /// Standard screen chrome: background, side margins handled by the content, hidden scroll bars.
    func screenBackground(glow: Color = Palette.accent) -> some View {
        scrollIndicators(.hidden).background(AppBackground(glow: glow))
    }
}

/// Press-down feedback for custom tappable surfaces (cards, tiles).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Big full-width call to action.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.accent)
    }
}

/// Round glass icon button (toolbars, headers). Group several inside a `GlassEffectContainer` so they blend.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.headline).frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }
}

/// One settings row inside a glass card: icon, title and any trailing control.
struct GlassRow<Trailing: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(Palette.accent.opacity(0.18)), in: .circle)
            Text(title)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 4)
    }
}

/// Title + optional subtitle used at the top of cards.
struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(.headline, design: .rounded, weight: .bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Int {
    /// 12.345 (Spanish grouping) for scores and counters.
    var grouped: String { formatted(.number.locale(Locale(identifier: "es_ES"))) }
}

extension String {
    /// "domingo, 15 de noviembre" → "Domingo, 15 de noviembre" (`capitalized` would capitalise every word).
    var sentenceCased: String { prefix(1).uppercased() + dropFirst() }
}
