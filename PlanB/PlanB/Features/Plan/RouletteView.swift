import SwiftUI

/// "Decide por nosotros": a wheel with up to 8 plans that match the filters.
struct RouletteView: View {
    var onChoose: (Plan) -> Void

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plans: [Plan] = []
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var result: Plan?
    @State private var ticks: Task<Void, Never>?

    private let duration = 3.0

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                VStack(spacing: 22) {
                    if plans.count < 2 {
                        ContentUnavailableView("Pocos planes", systemImage: "dice", description: Text("Quita algún filtro para tener planes que sortear."))
                    } else {
                        ZStack(alignment: .top) {
                            WheelView(plans: plans)
                                .equatable()
                                .rotationEffect(.degrees(rotation))
                                .frame(width: 300, height: 300)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.primary)
                                .offset(y: -16)
                                .accessibilityHidden(true)
                        }
                        .padding(.top, 20)
                        .accessibilityElement()
                        .accessibilityLabel("Ruleta de planes")

                        if let result, !spinning {
                            VStack(spacing: 8) {
                                Text("\(result.emoji) \(result.title)")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .multilineTextAlignment(.center)
                                Text(result.summary)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular.tint(result.colors.first?.opacity(0.2)), in: .rect(cornerRadius: 22))
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .accessibilityIdentifier("roulette.result")
                        }
                        Spacer(minLength: 0)
                        controls
                    }
                }
                .padding(Metrics.gutter)
                .animation(.spring(duration: 0.4, bounce: 0.3), value: spinning)
            }
            .navigationTitle("Decide por nosotros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear {
            if plans.isEmpty { plans = state.randomPlans(8) }
            Haptics.prepare()
        }
        .onDisappear { ticks?.cancel() }
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if let result, !spinning {
                    Button {
                        onChoose(result)
                        dismiss()
                    } label: {
                        Label("¡Este!", systemImage: "heart.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("roulette.choose")
                }
                Button {
                    spin()
                } label: {
                    Label(result == nil ? "¡Girar!" : "Otra vez", systemImage: "arrow.clockwise").frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.glass)
                .disabled(spinning)
                .accessibilityIdentifier("roulette.spin")
            }
            .font(.headline)
        }
    }

    private func spin() {
        let index = state.randomIndex(plans.count)
        let target = PlanWheel.rotation(landingOn: index, count: plans.count, from: rotation, extraTurns: reduceMotion ? 1 : 5, jitter: Double.random(in: -1...1))
        let start = rotation
        spinning = true
        result = nil
        Haptics.thump()
        withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: duration)) { rotation = target }
        // A tick each time a slice passes the pointer, slowing down with the wheel (ease-out ≈ 1 − (1 − t)³).
        ticks?.cancel()
        let crossings = max(1, Int((target - start) / (360 / Double(plans.count))))
        let times = (1...crossings).map { k in duration * (1 - pow(1 - Double(k) / Double(crossings), 1.0 / 3.0)) }
        ticks = Task {
            var previous = 0.0
            for time in times where !reduceMotion {
                try? await Task.sleep(for: .seconds(time - previous))
                if Task.isCancelled { return }
                previous = time
                Haptics.tick(0.45)
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            result = plans[index]
            spinning = false
            Haptics.success()
        }
    }
}

/// Static wheel (only rotated, never redrawn while spinning).
private struct WheelView: View, Equatable {
    let plans: [Plan]

    nonisolated static func == (lhs: WheelView, rhs: WheelView) -> Bool { lhs.plans.map(\.id) == rhs.plans.map(\.id) }

    private static let colors = [Palette.coral, Palette.plum, Palette.peach, Palette.sky, Palette.rose, Palette.mint, Palette.gold, Palette.ember]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let slice = 360.0 / Double(plans.count)
            ZStack {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    Wedge(start: .degrees(Double(index) * slice - 90), end: .degrees(Double(index + 1) * slice - 90))
                        .fill(Self.colors[index % Self.colors.count].gradient)
                    Text(plan.emoji)
                        .font(.system(size: 30))
                        .offset(x: radius * 0.66)
                        .rotationEffect(.degrees((Double(index) + 0.5) * slice - 90))
                }
                Circle()
                    .fill(.background)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .overlay { Text("💞").font(.system(size: size * 0.09)) }
            }
            .frame(width: size, height: size)
            .drawingGroup()
        }
    }
}

private struct Wedge: Shape {
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
