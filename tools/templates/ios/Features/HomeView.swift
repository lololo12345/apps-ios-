import SwiftUI

/// Starting screen: a hero card, a row of stats, filter chips and a list of cards. It shows every piece of
/// the design system working together; replace the content with the app's first screen.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var taps = 0
    @State private var filter = Filter.all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Todo", today = "Hoy", saved = "Guardado"
        var id: String { rawValue }
    }

    private let ideas: [(title: String, detail: String, symbol: String, tint: Color)] = [
        ("Primera pantalla", "Cambia esta vista por la de tu app", "sparkles", Palette.accent),
        ("Lógica en el Kit", "Se comprueba en Linux en segundos", "cpu.fill", Palette.secondary),
        ("Capturas", "La CI las saca solas en cada push", "camera.fill", Palette.sky),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero.appearAnimation(order: 0)
                    stats.appearAnimation(order: 1)
                    chips.appearAnimation(order: 2)
                    ForEach(Array(ideas.enumerated()), id: \.offset) { index, idea in
                        HStack(spacing: 14) {
                            IconBadge(systemImage: idea.symbol, tint: idea.tint, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(idea.title).font(.system(.headline, design: .rounded, weight: .bold))
                                Text(idea.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .card()
                        .appearAnimation(order: 3 + index)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("__display__")
            .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in model.hapticsOn }
            .sensoryFeedback(.selection, trigger: filter) { _, _ in model.hapticsOn }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IconBadge(systemImage: "sparkles", size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Greeting.now)
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.accent.ink)
                    Text("__summary__")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(taps.grouped)
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.accent.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("tapCount")
                    Text("pulsaciones")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ProgressRing(fraction: Double(min(taps, 10)) / 10)
            }
            PrimaryButton(title: "Pulsar", systemImage: "hand.tap.fill") {
                withAnimation(.snappy) { taps += 1 }
            }
            .accessibilityIdentifier("tapButton")
        }
        .heroCard()
        .accessibilityElement(children: .contain)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: model.launchCount.grouped, label: "Aperturas", systemImage: "arrow.up.forward.app.fill")
            StatTile(value: "\(min(taps, 10))/10", label: "Objetivo", systemImage: "target", tint: Palette.secondary)
            StatTile(value: model.appearance.title, label: "Apariencia", systemImage: model.appearance.symbol, tint: Palette.sky)
        }
    }

    private var chips: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { item in
                    GlassChip(title: item.rawValue, selected: filter == item) {
                        withAnimation(.snappy) { filter = item }
                    }
                    .accessibilityIdentifier("filter.\(item.rawValue)")
                }
                Spacer(minLength: 0)
            }
        }
    }
}
