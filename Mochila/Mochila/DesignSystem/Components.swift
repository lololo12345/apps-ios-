import SwiftUI

extension TripType {
    var tint: Color { Color(hex: tintHex) }
}

/// Round glossy badge with the trip type's symbol.
struct TypeBadge: View {
    let type: TripType
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            .frame(width: size, height: size)
            .background {
                ZStack {
                    Circle().fill(LinearGradient(colors: [type.tint, type.tint.mix(with: .black, by: 0.18)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    // Glossy highlight at the top.
                    Circle()
                        .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                        .padding(size * 0.06)
                }
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: type.tint.opacity(0.45), radius: size * 0.2, y: size * 0.1)
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

extension Climate {
    var tint: Color {
        switch self {
        case .cold: Color(hex: 0x7FC4FF)
        case .mild: Color(hex: 0x9BD67B)
        case .hot: Color(hex: 0xFFB547)
        }
    }
}

/// Weather at the destination: place, temperatures, rain and advice.
struct WeatherPanel: View {
    let weather: WeatherSummary
    var tint: Color = Palette.accent
    var note: String?
    var refreshing = false
    var onRefresh: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: weather.symbol)
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(weather.climate.tint.opacity(0.3)), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(weather.place.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(weather.climate.tint.ink)
                Text(weather.text)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                TemperatureBar(weather: weather)
                    .padding(.vertical, 3)
                Text(weather.advice)
                    .font(.subheadline)
                Text(note.map { "\(weather.sourceText). \($0)" } ?? weather.sourceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(refreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: refreshing)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(refreshing)
                .accessibilityLabel("Actualizar el tiempo")
                .accessibilityIdentifier("refreshWeather")
            }
        }
        .card(tint: weather.climate.tint)
        .accessibilityElement(children: .contain)
    }
}

/// Temperature range on a cold-to-hot scale, like the Weather app: −10 °C on the left, 40 °C on the right.
struct TemperatureBar: View {
    let weather: WeatherSummary
    private static let scale: [Color] = [Color(hex: 0x6FA8FF), Color(hex: 0x7FD6C8), Color(hex: 0xB9E07A),
                                         Color(hex: 0xFFC857), Color(hex: 0xFF7A59)]

    var body: some View {
        GeometryReader { proxy in
            let range = weather.rangeOnScale
            let width = proxy.size.width
            let start = width * range.lowerBound
            let length = max(width * (range.upperBound - range.lowerBound), 8)
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: Self.scale, startPoint: .leading, endPoint: .trailing))
                    // The whole scale is drawn and masked, so each trip shows its own part of the colours.
                    .mask(alignment: .leading) {
                        Capsule().frame(width: length).offset(x: min(start, width - length))
                    }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Small ring for a category header: fills up and turns into a check when the group is packed.
struct MiniRing: View {
    let progress: PackProgress
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(tint)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 20, height: 20)
        .animation(.smooth(duration: 0.4), value: progress)
        .accessibilityHidden(true)
    }
}

/// The next trip, big: countdown, destination weather and how much is packed.
struct HeroTripCard: View {
    let trip: Trip

    var body: some View {
        let progress = trip.progress
        let hero = trip.hero
        let tint = trip.type.tint
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                TypeBadge(type: trip.type, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tu próximo viaje")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(tint.ink)
                        .textCase(.uppercase)
                    Text(trip.name)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(trip.type.title) · \(trip.shortDateText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let weather = trip.weather {
                    VStack(spacing: 2) {
                        Image(systemName: weather.symbol)
                            .font(.title2)
                            .symbolRenderingMode(.multicolor)
                        Text("\(Int(weather.maxTemp.rounded()))°")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(weather.climate.tint.opacity(0.3)), in: .rect(cornerRadius: 16))
                }
            }
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(hero.value)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(hero.caption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ProgressRing(progress: progress, tint: tint, size: 74, lineWidth: 8)
            }
            if let pending = trip.pendingText {
                Label(pending, systemImage: "checklist")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: 14))
            } else {
                Label("¡Mochila lista!", systemImage: "checkmark.seal.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint.ink)
            }
        }
        .padding(4)
        .card(tint: tint, radius: 30)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
