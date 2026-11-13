import SwiftUI

struct RouletteGameView: View {
    let mode: PartyMode

    @Environment(PartySession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var result: (segment: Roulette.Segment, player: Player?)?
    @State private var resolveTask: Task<Void, Never>?

    private var wheel: Roulette { Roulette(segments: mode == .hot ? CardBank.rouletteHot : CardBank.rouletteNormal) }
    private var colors: [Color] { GameKind.roulette.gradient(for: mode) }
    private let spinDuration: Double = 3.2

    var body: some View {
        GameScaffold(game: .roulette, mode: mode) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Text("Gira \(session.currentPlayer?.name ?? "")")
                    .font(.title3.weight(.bold))
                    .gradientText(colors)

                ZStack(alignment: .top) {
                    WheelView(segments: wheel.segments, palette: palette)
                        .rotationEffect(.degrees(rotation))
                        .frame(width: 300, height: 300)
                        .shadow(color: (colors.first ?? .clear).opacity(0.5), radius: 24)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                        .offset(y: -14)
                        .accessibilityHidden(true)
                }
                .accessibilityElement()
                .accessibilityLabel("Ruleta")

                if let result, !spinning {
                    VStack(spacing: 6) {
                        Text(result.segment.title)
                            .font(.title2.weight(.black))
                            .gradientText(colors)
                        Text(session.lexicon.adapt(result.segment.detail))
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .neonCard(colors, padding: 16)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .accessibilityIdentifier("roulette.result")
                }
                Spacer(minLength: 0)
            }
            .animation(.spring(duration: 0.4, bounce: 0.3), value: spinning)
        } controls: {
            BigButton(title: spinning ? "Girando…" : "¡Girar!", symbol: "arrow.clockwise", tint: colors.first ?? Neon.violet, identifier: "roulette.spin") {
                spin()
            }
            .disabled(spinning)
        }
        .onDisappear { resolveTask?.cancel() }
    }

    private var palette: [Color] {
        mode == .hot
            ? [Neon.crimson, Neon.magenta, Neon.rose, Neon.orange, Neon.violet]
            : [Neon.violet, Neon.cyan, Neon.magenta, Neon.lime, Neon.orange]
    }

    private func spin() {
        var generator = SystemRandomNumberGenerator()
        let index = wheel.pick(using: &generator)
        let jitter = Double.random(in: -1...1, using: &generator)
        let target = wheel.rotation(landingOn: index, from: rotation, extraTurns: reduceMotion ? 1 : 5, jitter: jitter)
        let spinner = session.currentPlayer
        spinning = true
        result = nil
        Haptics.tap(.heavy)
        withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: spinDuration)) {
            rotation = target
        }
        resolveTask?.cancel()
        resolveTask = Task {
            try? await Task.sleep(for: .seconds(spinDuration))
            guard !Task.isCancelled else { return }
            let segment = wheel.segments[index]
            apply(segment, spinner: spinner)
            Haptics.success()
            result = (segment, spinner)
            spinning = false
            session.nextTurn()
            session.registerRound()
        }
    }

    private func apply(_ segment: Roulette.Segment, spinner: Player?) {
        if segment.spinnerSips > 0 { session.give(segment.spinnerSips, to: spinner) }
        if segment.everyoneSips > 0 { session.everyone(segment.everyoneSips) }
        guard mode == .normal, let spinner else { return }
        if segment.title == "Izquierda" { session.give(1, to: session.player(leftOf: spinner)) }
        if segment.title == "Derecha" { session.give(1, to: session.player(rightOf: spinner)) }
    }
}

/// Static wheel drawing. Segment i spans [i, i+1) × slice, clockwise from the top.
private struct WheelView: View {
    let segments: [Roulette.Segment]
    let palette: [Color]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let slice = 360.0 / Double(segments.count)
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    WedgeShape(start: .degrees(Double(index) * slice - 90), end: .degrees(Double(index + 1) * slice - 90))
                        .fill(palette[index % palette.count].gradient)
                        .overlay {
                            WedgeShape(start: .degrees(Double(index) * slice - 90), end: .degrees(Double(index + 1) * slice - 90))
                                .stroke(Neon.ink, lineWidth: 2)
                        }
                    // Radial label confined to the outer part of its slice so neighbours never overlap.
                    Text(segment.title)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Neon.ink)
                        .frame(width: radius * 0.56, alignment: .trailing)
                        .offset(x: radius * 0.6)
                        .rotationEffect(.degrees((Double(index) + 0.5) * slice - 90))
                }
                Circle()
                    .fill(Neon.ink)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .overlay { Circle().strokeBorder(.white.opacity(0.8), lineWidth: 3) }
            }
            .frame(width: size, height: size)
            .drawingGroup()
        }
    }
}

private struct WedgeShape: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}
