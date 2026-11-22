import SwiftUI

struct ActiveGame: Identifiable, Hashable {
    let kind: GameKind
    let mode: PartyMode
    var id: String { "\(mode.rawValue)-\(kind.rawValue)" }
}

struct HomeView: View {
    @Environment(PartySession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var modeGlass
    @State private var tilesVisible = false
    @State private var activeGame: ActiveGame?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        @Bindable var session = session
        let mode = session.mode
        ZStack {
            NightBackground(colors: mode == .hot ? [Neon.crimson, Neon.magenta] : [Neon.violet, Neon.cyan])
                .animation(.smooth(duration: 0.5), value: mode)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    modePicker
                    if mode == .normal {
                        intensityPicker
                    }
                    if mode == .hot && !session.canUseHot {
                        lockedHot
                    } else if mode == .hot && !session.hotUnlocked {
                        HotConsentCard {
                            withAnimation(.smooth) { session.hotUnlocked = true }
                        }
                    } else {
                        grid(for: mode)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .fullScreenCover(item: $activeGame) { game in
            GameRouter(game: game)
        }
        .onAppear {
            guard !tilesVisible else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) { tilesVisible = true }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ronda")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .gradientText(session.mode == .hot ? [Neon.rose, Neon.crimson] : [Neon.magenta, Neon.cyan])
                let total = session.ledger.total(for: session.players)
                Text("\(session.players.count) jugadores · \(session.lexicon.unitTitle.lowercased()): \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(total)))
                    .animation(.snappy, value: total)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var modePicker: some View {
        GlassEffectContainer(spacing: 6) {
        HStack(spacing: 6) {
            ForEach(PartyMode.allCases) { item in
                let selected = session.mode == item
                Button {
                    withAnimation(.smooth(duration: 0.3)) { session.mode = item }
                } label: {
                    Label(item.title, systemImage: item.symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .contentShape(.capsule)
                        // The selected pane of glass carries the same id in both options, so switching makes it
                        // flow like liquid from one side to the other.
                        .glassEffect(selected ? .regular.tint((item == .hot ? Neon.crimson : Neon.violet).opacity(0.7)) : .identity,
                                     in: .capsule)
                        .glassEffectID(selected ? "mode" : "mode.\(item.rawValue)", in: modeGlass)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("mode.\(item.rawValue)")
            }
        }
        .padding(5)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var intensityPicker: some View {
        @Bindable var session = session
        return Picker("Nivel", selection: $session.intensity) {
            ForEach(Intensity.allCases) { level in
                Text(level.title).tag(level)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("home.intensity")
    }

    private func grid(for mode: PartyMode) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(GameKind.games(for: mode).enumerated()), id: \.element) { index, kind in
                let enabled = session.players.count >= kind.minimumPlayers
                let game = ActiveGame(kind: kind, mode: mode)
                Button {
                    Haptics.tap(.medium)
                    activeGame = game
                } label: {
                    GameTile(kind: kind, mode: mode, enabled: enabled)
                }
                .buttonStyle(PressableStyle())
                .disabled(!enabled)
                .accessibilityIdentifier("game.\(mode.rawValue).\(kind.rawValue)")
                // Staggered entrance the first time the home appears.
                .opacity(tilesVisible ? 1 : 0)
                .offset(y: tilesVisible || reduceMotion ? 0 : 18)
                .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.2).delay(Double(index) * 0.035), value: tilesVisible)
            }
        }
        // Normal ⇄ Hot swaps the whole grid with a cross-fade instead of recolouring tiles in place.
        .id(mode)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var lockedHot: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Neon.crimson)
            Text("El apartado Hot es solo para mayores de edad.")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .neonCard([Neon.crimson, Neon.magenta])
    }
}

struct GameTile: View {
    let kind: GameKind
    let mode: PartyMode
    let enabled: Bool

    var body: some View {
        let colors = kind.gradient(for: mode)
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: (colors.first ?? .clear).opacity(0.8), radius: 10)
            Spacer(minLength: 0)
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(enabled ? kind.tagline : "Mínimo \(kind.minimumPlayers) jugadores")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .neonCard(colors, radius: 22, padding: 16)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
    }
}

struct HotConsentCard: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Antes de entrar", systemImage: "flame.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Neon.rose)
            VStack(alignment: .leading, spacing: 10) {
                consentLine("person.badge.shield.checkmark.fill", "Todos los que jugáis sois mayores de edad.")
                consentLine("hand.thumbsup.fill", "Todo el grupo quiere jugar al modo Hot.")
                consentLine("hand.raised.fill", "Cualquiera puede pasar de un reto o pregunta: bebe y listo, sin dar explicaciones.")
            }
            BigButton(title: "Todos estamos de acuerdo", symbol: "flame.fill", tint: Neon.crimson, identifier: "hot.accept", action: onAccept)
        }
        .neonCard([Neon.crimson, Neon.magenta])
    }

    private func consentLine(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.callout)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Neon.rose)
        }
    }
}
