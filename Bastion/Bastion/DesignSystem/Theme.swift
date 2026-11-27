import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

enum Palette {
    static let accent = Color(hex: 0x7ED957)
    static let accentSoft = Color(hex: 0xABE691)
    static let background = Color(hex: 0x0F2418)
    static let backgroundDeep = Color(hex: 0x08130D)
    /// Light mode: a soft wash of the brand colours (never plain grey, so the glass has colour to refract).
    static let lightTop = Color(hex: 0xEFFAEA)
    static let lightBottom = Color(hex: 0xF8F1FB)
    static let good = Color(hex: 0x3DDC97)
    static let bad = Color(hex: 0xFF5A6E)
    /// Complementary hue (accent rotated on the colour wheel) for the third background glow.
    static let secondary = Color(hex: 0xB256D9)
    static let sky = Color(hex: 0x6FA8FF)
    static let gold = Color(hex: 0xF7C948)
    static let brand: [Color] = [accentSoft, accent]
}

enum Metrics {
    /// Side margin of every screen (also the minimum on the smallest iPhone).
    static let gutter: CGFloat = 16
    static let radius: CGFloat = 24
    static let heroRadius: CGFloat = 30
}

// MARK: - Background

/// Screen background: a vertical gradient plus four soft glows. Radial gradients only (no blur),
/// so scrolling and animations on top stay at 120 Hz.
struct AppBackground: View {
    var glow: Color = Palette.accent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        GeometryReader { proxy in
            let longest = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: dark ? [Palette.background, Palette.backgroundDeep] : [Palette.lightTop, Palette.lightBottom],
                               startPoint: .top, endPoint: .bottom)
                spot(glow, dark ? 0.42 : 0.30, UnitPoint(x: 0.95, y: 0.0), longest * 0.62)
                spot(Palette.accentSoft, dark ? 0.26 : 0.22, UnitPoint(x: 0.0, y: 0.45), longest * 0.55)
                spot(Palette.secondary, dark ? 0.24 : 0.18, UnitPoint(x: 0.9, y: 1.0), longest * 0.55)
                spot(Palette.sky, dark ? 0.16 : 0.12, UnitPoint(x: 0.1, y: 1.0), longest * 0.45)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func spot(_ color: Color, _ opacity: Double, _ center: UnitPoint, _ radius: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), .clear], center: center,
                       startRadius: 0, endRadius: radius)
    }
}

// MARK: - Colour helpers

/// Deeper shade of a tint for text on a card of the same colour (lighter in dark mode), so a label like
/// «PRÓXIMO» in orange on a cream card stays readable. Use `.foregroundStyle(tint.ink)`.
struct InkStyle: ShapeStyle {
    let tint: Color

    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? tint.mix(with: .white, by: 0.25) : tint.mix(with: .black, by: 0.42)
    }
}

extension Color {
    var ink: InkStyle { InkStyle(tint: self) }
}

// MARK: - Surfaces

extension View {
    /// Rounded Liquid Glass surface used for every card, with a thin light rim so the edge reads on any
    /// background. Pass a tint to colour it.
    func card(tint: Color? = nil, radius: CGFloat = Metrics.radius, padding inset: CGFloat = 16) -> some View {
        let glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? .regular
        return padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.06)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
    }

    /// The big card at the top of a screen: more colour, bigger corners.
    func heroCard(tint: Color = Palette.accent) -> some View {
        card(tint: tint, radius: Metrics.heroRadius, padding: 20)
    }

    func brandGradientText() -> some View {
        foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .leading, endPoint: .trailing))
    }

    /// Standard screen chrome: background, side margins handled by the content, hidden scroll bars.
    func screenBackground(glow: Color = Palette.accent) -> some View {
        scrollIndicators(.hidden).background(AppBackground(glow: glow))
    }

    /// Fades and lifts the view in when it first appears; pass increasing `order`s for a cascade.
    func appearAnimation(order: Int = 0) -> some View {
        modifier(AppearAnimation(delay: Double(order) * 0.06))
    }
}

private struct AppearAnimation: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                // No cascade under UI tests: screenshots must never catch a card half-way in.
                guard !shown else { return }
                if LaunchOptions.isUITesting {
                    shown = true
                } else {
                    withAnimation(.smooth(duration: 0.45).delay(delay)) { shown = true }
                }
            }
    }
}

// MARK: - Buttons

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

/// Selectable glass chip (filters, options). Put a row of them in a `GlassEffectContainer`.
struct GlassChip: View {
    let title: String
    var systemImage: String?
    let selected: Bool
    var tint: Color = Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? AnyShapeStyle(Color.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            .background {
                if selected { Capsule().fill(tint.gradient) }
            }
            .glassEffect(.regular, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Badges, rings and numbers

/// Glossy round badge with a symbol: the coloured icon in front of rows, cards and headers.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = Palette.accent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            .frame(width: size, height: size)
            .background {
                ZStack {
                    Circle().fill(LinearGradient(colors: [tint, tint.mix(with: .black, by: 0.18)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle()
                        .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                        .padding(size * 0.06)
                }
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: tint.opacity(0.4), radius: size * 0.2, y: size * 0.1)
            .accessibilityHidden(true)
    }
}

/// Circular progress (0…1) with the percentage, or a check when complete.
struct ProgressRing: View {
    let fraction: Double
    var tint: Color = Palette.accent
    var size: CGFloat = 72
    var lineWidth: CGFloat = 8

    var body: some View {
        let value = min(max(fraction, 0), 1)
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(AngularGradient(colors: [tint.opacity(0.65), tint], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if value >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.32, weight: .heavy))
                    .foregroundStyle(tint.ink)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.45), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((value * 100).rounded())) por ciento")
    }
}

/// Number + label in a small glass tile ("12 · racha"). Numbers roll when they change.
struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String?
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .card(tint: tint, radius: 20, padding: 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rows and headers

/// One settings row inside a glass card: icon, title and any trailing control.
struct GlassRow<Trailing: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = Palette.accent
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(tint.opacity(0.2)), in: .circle)
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

/// Friendly empty screen: big glowing symbol in glass, title, message and an optional action.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.accent.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 90))
                    .frame(width: 180, height: 180)
                Image(systemName: systemImage)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .top, endPoint: .bottom))
                    .frame(width: 112, height: 112)
                    .glassEffect(.regular.tint(Palette.accent.opacity(0.2)), in: .circle)
                    .symbolEffect(.breathe)
            }
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: "plus", action: action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Formatting

extension Int {
    /// 12.345 (Spanish grouping) for scores and counters.
    var grouped: String { formatted(.number.locale(Locale(identifier: "es_ES"))) }
}

extension String {
    /// "domingo, 15 de noviembre" → "Domingo, 15 de noviembre" (`capitalized` would capitalise every word).
    var sentenceCased: String { prefix(1).uppercased() + dropFirst() }
}

/// "Buenos días" / "Buenas tardes" / "Buenas noches" for headers.
enum Greeting {
    static func text(hour: Int) -> String {
        switch hour {
        case 6..<14: "Buenos días"
        case 14..<21: "Buenas tardes"
        default: "Buenas noches"
        }
    }

    static var now: String { text(hour: Calendar.current.component(.hour, from: .now)) }
}
