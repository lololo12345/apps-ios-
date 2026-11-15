import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Palette {
    static let night = Color(hex: 0x120C2E)
    static let dusk = Color(hex: 0x2A1B5E)
    static let amber = Color(hex: 0xFFB020)
    static let ember = Color(hex: 0xFF5E3A)
    static let spark: [Color] = [Color(hex: 0xFFD65A), Color(hex: 0xFF8A3D), Color(hex: 0xFF5E3A)]
    static let good = Color(hex: 0x3DDC97)
    static let assisted = Color(hex: 0xFFC845)
    static let bad = Color(hex: 0xFF5A6E)
    static let muted = Color.white.opacity(0.62)
}

extension ChallengeKind {
    var tint: Color { Color(hex: tintHex) }
}

extension Outcome {
    var color: Color {
        switch self {
        case .perfect: Palette.good
        case .assisted: Palette.assisted
        case .wrong: Palette.bad
        }
    }
}

/// Night sky with a warm glow, drawn with radial gradients (no blur) so it stays cheap at 120 Hz.
struct NightBackground: View {
    var glow: Color = Palette.ember

    var body: some View {
        GeometryReader { proxy in
            let longest = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [Palette.dusk, Palette.night, Color(hex: 0x0A0718)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [glow.opacity(0.30), .clear], center: UnitPoint(x: 0.9, y: 0.02),
                               startRadius: 0, endRadius: longest * 0.55)
                RadialGradient(colors: [Color(hex: 0x6E4BFF).opacity(0.22), .clear], center: UnitPoint(x: 0.0, y: 0.7),
                               startRadius: 0, endRadius: longest * 0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Rounded glass surface used for every card.
    func card(tint: Color? = nil, radius: CGFloat = 24, interactive: Bool = false) -> some View {
        let glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? .regular
        return self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(interactive ? glass.interactive() : glass, in: .rect(cornerRadius: radius))
    }

    func sparkText() -> some View {
        foregroundStyle(LinearGradient(colors: Palette.spark, startPoint: .leading, endPoint: .trailing))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Coloured round icon for a kind of challenge.
struct KindIcon: View {
    let kind: ChallengeKind
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [kind.tint, kind.tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: size * 0.32)
            )
            .accessibilityHidden(true)
    }
}

/// "🔥 12" chip with the shields underneath.
struct StreakChip: View {
    let streak: StreakState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(LinearGradient(colors: Palette.spark, startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: streak.current)
            Text("\(streak.current)")
                .contentTransition(.numericText())
                .font(.system(.headline, design: .rounded, weight: .heavy))
            if streak.shields > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<streak.shields, id: \.self) { _ in
                        Image(systemName: "shield.fill").font(.caption2).foregroundStyle(Color(hex: 0x7FD3FF))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(Palette.ember.opacity(0.25)), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Racha de \(streak.current) días, \(streak.shields) protectores")
        .accessibilityIdentifier("streak")
    }
}

/// Live countdown to the next midnight.
struct CountdownLabel: View {
    let target: Date
    var prefix = "Nuevo reto en"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill").foregroundStyle(Palette.amber)
            Text(prefix).foregroundStyle(Palette.muted)
            Text(timerInterval: Date.now...max(target, .now.addingTimeInterval(1)), countsDown: true)
                .monospacedDigit()
                .fontWeight(.bold)
        }
        .font(.subheadline)
    }
}

/// A burst of sparks for correct answers.
struct SparkBurst: View {
    let trigger: Int
    /// 1 = finished (invisible), 0 = just fired.
    @State private var progress: CGFloat = 1

    var body: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                let angle = Double(i) / 14 * 2 * .pi
                Image(systemName: i.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: i.isMultiple(of: 3) ? 18 : 12))
                    .foregroundStyle(Palette.spark[i % 3])
                    .offset(x: cos(angle) * 150 * progress, y: sin(angle) * 150 * progress)
                    .scaleEffect(1.2 - 0.8 * progress)
                    .opacity(1 - progress)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { progress = 0 }
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
            }
        }
    }
}

extension Double {
    var secondsText: String {
        self < 60 ? String(format: "%.1f s", self) : String(format: "%d min %02d s", Int(self) / 60, Int(self) % 60)
    }
}
