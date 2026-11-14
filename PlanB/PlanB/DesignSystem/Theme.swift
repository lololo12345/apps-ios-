import SwiftUI
import UIKit

enum Metrics {
    static let gutter: CGFloat = 16
    static let radius: CGFloat = 28
}

/// Soft sunset glow behind every screen. Radial gradients (no blur), so the 120 Hz animations
/// on top never pay for a full-screen filter.
struct WarmBackground: View {
    var colors: [Color] = Palette.brand
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let longest = max(proxy.size.width, proxy.size.height)
            ZStack {
                Color(uiColor: .systemBackground)
                RadialGradient(colors: [(colors.first ?? Palette.coral).opacity(scheme == .dark ? 0.35 : 0.22), .clear],
                               center: UnitPoint(x: 0.05, y: 0.0), startRadius: 0, endRadius: longest * 0.6)
                RadialGradient(colors: [(colors.last ?? Palette.plum).opacity(scheme == .dark ? 0.30 : 0.16), .clear],
                               center: UnitPoint(x: 1.0, y: 0.85), startRadius: 0, endRadius: longest * 0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func gradientText(_ colors: [Color]) -> some View {
        foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
    }
}

/// Subtle press-down for custom tappable surfaces.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Small glass tag: "€€ · Una tarde".
struct TagChip: View {
    let text: String
    var symbol: String?
    var tint: Color?

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let symbol { Image(systemName: symbol) }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.35)) } ?? Glass.regular, in: .capsule)
    }
}

/// Prepared feedback generators: every vibration fires without latency.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred(); light.prepare() }
    static func thump() { medium.impactOccurred(); medium.prepare() }
    static func tick(_ intensity: CGFloat = 0.5) { rigid.impactOccurred(intensity: intensity); rigid.prepare() }
    static func select() { selection.selectionChanged(); selection.prepare() }
    static func success() { notification.notificationOccurred(.success); notification.prepare() }
    static func warning() { notification.notificationOccurred(.warning); notification.prepare() }
    static func prepare() { light.prepare(); rigid.prepare(); selection.prepare() }
}

/// Confetti burst drawn with a single Canvas (one draw call per frame instead of dozens of views).
struct ConfettiBurst: View {
    let trigger: Int
    @State private var start: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Piece {
        let angle: Double, speed: Double, spin: Double, size: CGFloat, color: Color
    }

    private let pieces: [Piece] = (0..<70).map { index in
        var generator = SeededGenerator(seed: UInt64(index) &* 2654435761)
        func unit() -> Double { Double(generator.next() % 10_000) / 10_000 }
        let colors = [Palette.coral, Palette.rose, Palette.plum, Palette.gold, Palette.mint, Palette.sky]
        return Piece(angle: -Double.pi / 2 + (unit() - 0.5) * 2.2, speed: 380 + unit() * 520, spin: (unit() - 0.5) * 14,
                     size: 6 + CGFloat(unit()) * 7, color: colors[index % colors.count])
    }

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                guard t < 2.2 else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.62)
                for piece in pieces {
                    let x = origin.x + cos(piece.angle) * piece.speed * t
                    let y = origin.y + sin(piece.angle) * piece.speed * t + 900 * t * t / 2
                    var copy = context
                    copy.opacity = max(0, 1 - t / 2.2)
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(piece.spin * t))
                    copy.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            start = .now
            Task {
                try? await Task.sleep(for: .seconds(2.3))
                start = nil
            }
        }
    }
}
