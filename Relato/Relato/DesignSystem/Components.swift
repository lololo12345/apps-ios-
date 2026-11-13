import SwiftUI

// MARK: - Background

/// Static mesh gradient backdrop. Static on purpose: zero per-frame cost and no battery drain,
/// while still giving glass controls something rich to refract.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    var intensity: Double = 1

    var body: some View {
        let base = Palette.canvas
        let glowA = Palette.ember.opacity((scheme == .dark ? 0.32 : 0.20) * intensity)
        let glowB = Palette.violet.opacity((scheme == .dark ? 0.34 : 0.16) * intensity)
        let glowC = Palette.magenta.opacity((scheme == .dark ? 0.22 : 0.12) * intensity)
        ZStack {
            base
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.45], [0.6, 0.4], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    glowA, glowC, glowB,
                    base.opacity(0), base.opacity(0), glowB.opacity(0.5),
                    base.opacity(0), base.opacity(0), base.opacity(0),
                ]
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

struct SurfaceCard: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Metrics.cardRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
            }
    }
}

extension View {
    func surfaceCard(padding: CGFloat = 18, radius: CGFloat = Metrics.cardRadius) -> some View {
        modifier(SurfaceCard(padding: padding, radius: radius))
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var symbol: String?
    var tint: Color = Palette.ember
    var isSelected: Bool = false
    var count: Int?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.caption.weight(.semibold))
            }
            Text(title).font(.subheadline.weight(.semibold))
            if let count {
                Text("\(count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isSelected ? tint : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(isSelected ? Color.white.opacity(0.9) : Palette.surfaceSunken))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            Capsule().fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.surface))
        }
        .overlay {
            Capsule().strokeBorder(isSelected ? .clear : Palette.hairline, lineWidth: 1)
        }
        .contentShape(Capsule())
        .animation(.snappy(duration: 0.22), value: isSelected)
    }
}

/// Small tinted label, e.g. genre or status.
struct Pill: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.13)))
    }
}

// MARK: - Timing bar

struct TimingBar: View {
    struct Slice: Identifiable {
        let id: UUID
        let seconds: Double
        let tint: Color
    }

    let slices: [Slice]
    let targetSeconds: Double
    var height: CGFloat = 10

    var body: some View {
        let total = slices.reduce(0) { $0 + $1.seconds }
        let scale = max(total, targetSeconds, 1)
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceSunken)
                HStack(spacing: 2) {
                    ForEach(slices.filter { $0.seconds > 0 }) { slice in
                        Rectangle()
                            .fill(slice.tint.gradient)
                            .frame(width: max(2, width * slice.seconds / scale - 2))
                    }
                }
                .clipShape(Capsule())
                if total > targetSeconds, targetSeconds > 0 {
                    // Target marker: everything to the right of it is over time.
                    Rectangle()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: 2, height: height + 6)
                        .offset(x: width * targetSeconds / scale - 1)
                }
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.35), value: total)
        .accessibilityElement()
        .accessibilityLabel("Duración \(ScriptMetrics.clock(total)) de \(ScriptMetrics.clock(targetSeconds))")
    }
}

// MARK: - Score ring

struct ScoreRing: View {
    let score: Int
    let tint: Color
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                .contentTransition(.numericText(value: Double(score)))
        }
        .animation(.smooth(duration: 0.4), value: score)
        .accessibilityElement()
        .accessibilityLabel("Puntuación \(score) de 100")
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(padding: 14, radius: 20)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Palette.brandGradient)
                    .frame(width: 112, height: 112)
                    .blur(radius: 30)
                    .opacity(0.55)
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Palette.brandGradient)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular, in: .circle)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle).font(.headline).padding(.horizontal, 12).padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.ember)
                }
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.glass)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Section header

struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing).font(.footnote).foregroundStyle(.tertiary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Press feedback

/// Subtle scale-down on press for tappable cards (no layout change, GPU-cheap).
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
