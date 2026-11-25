import SwiftUI

struct ActiveGame: Identifiable, Hashable {
    let kind: GameKind
    let mode: PartyMode
    var id: String { "\(mode.rawValue)-\(kind.rawValue)" }
}

struct HomeView: View {
    @Environment(PartySession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var zoom
    @State private var tilesVisible = false
    @State private var activeGame: ActiveGame?
    @State private var showPlayers = false
    @State private var showScoreboard = false
    @State private var showSettings = false

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
                    stats.appearAnimation(order: 1)
                    modePicker.appearAnimation(order: 2)
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
            // Native zoom: the tile grows into the game and shrinks back when closing.
            GameRouter(game: game)
                .navigationTransition(.zoom(sourceID: game.id, in: zoom))
        }
        .onAppear {
            guard !tilesVisible else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) { tilesVisible = true }
        }
        .sheet(isPresented: $showPlayers) {
            NavigationStack {
                PlayersView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { showPlayers = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showScoreboard) {
            ScoreboardView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
                Text(session.mode == .hot ? "Modo Hot · solo adultos" : "La fiesta empieza aquí")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    headerButton("person.2.fill", label: "Jugadores", id: "home.players") { showPlayers = true }
                    headerButton("trophy.fill", label: "Marcador", id: "home.scoreboard") { showScoreboard = true }
                    headerButton("gearshape.fill", label: "Ajustes", id: "home.settings") { showSettings = true }
                }
            }
        }
        .padding(.top, 8)
    }

    /// Players, the tally and whose turn it is, in three small neon tiles.
    private var stats: some View {
        let total = session.ledger.total(for: session.players)
        return HStack(spacing: 10) {
            StatTile(value: "\(session.players.count)", label: "Jugadores", symbol: "person.2.fill", colors: [Neon.cyan, Neon.violet])
            StatTile(value: "\(total)", label: session.lexicon.unitTitle, symbol: session.soberMode ? "star.fill" : "drop.fill",
                     colors: [Neon.magenta, Neon.violet])
            StatTile(value: session.currentPlayer?.name ?? "—", label: "Le toca", symbol: "sparkles", colors: [Neon.lime, Neon.cyan])
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.stats")
    }

    private func headerButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.headline).frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private var modePicker: some View {
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
                        .background {
                            if selected {
                                Capsule().fill(LinearGradient(
                                    colors: item == .hot ? [Neon.crimson, Neon.magenta] : [Neon.violet, Neon.cyan],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("mode.\(item.rawValue)")
            }
        }
        .padding(5)
        .glassEffect(.regular, in: .capsule)
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
                        .matchedTransitionSource(id: game.id, in: zoom)
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
            NeonBadge(symbol: kind.symbol, colors: colors)
            Spacer(minLength: 0)
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(.primary)
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
