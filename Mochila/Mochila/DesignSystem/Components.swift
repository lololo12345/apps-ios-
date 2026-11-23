import SwiftUI

extension TripType {
    var tint: Color { Color(hex: tintHex) }
}

/// Round tinted glass badge with the trip type's symbol.
struct TypeBadge: View {
    let type: TripType
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [type.tint, type.tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .circle
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: type.tint.opacity(0.35), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

/// Circular progress with the percentage in the middle.
struct ProgressRing: View {
    let progress: PackProgress
    var tint: Color = Palette.accent
    var size: CGFloat = 64
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.7), tint], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if progress.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.32, weight: .heavy))
                    .foregroundStyle(tint)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.45), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Llevas \(progress.text)")
    }
}

/// Slim bar for the trip cards.
struct ProgressBar: View {
    let progress: PackProgress
    var tint: Color = Palette.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.width * progress.fraction, progress.done > 0 ? 8 : 0))
            }
        }
        .frame(height: 8)
        .animation(.smooth(duration: 0.45), value: progress)
        .accessibilityHidden(true)
    }
}

/// Burst of confetti and a big badge when the bag is ready.
struct ReadyCelebration: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void
    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: onClose)
            ForEach(0..<24, id: \.self) { index in
                let angle = Double(index) / 24 * 2 * .pi
                let colors: [Color] = [Palette.accent, Palette.secondary, .white, Palette.accentSoft]
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 2) ? 8 : 6, height: index.isMultiple(of: 3) ? 14 : 8)
                    .rotationEffect(.degrees(burst ? Double(index) * 47 : 0))
                    .offset(x: burst ? cos(angle) * 170 : 0, y: burst ? sin(angle) * 220 + 40 : 0)
                    .opacity(burst ? 0 : 1)
            }
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .symbolEffect(.bounce, value: burst)
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("¡A viajar!", action: onClose)
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("closeCelebration")
            }
            .padding(28)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .padding(32)
            .scaleEffect(burst ? 1 : 0.8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("celebration")
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.35)) { burst = true }
        }
    }
}

/// Selectable glass chip (climate, filters).
struct GlassChip: View {
    let title: String
    let systemImage: String
    let selected: Bool
    var tint: Color = Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? .white : .primary)
                .background {
                    if selected {
                        Capsule().fill(tint.gradient)
                    }
                }
                .glassEffect(.regular, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
