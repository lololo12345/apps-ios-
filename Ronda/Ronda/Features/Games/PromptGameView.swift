import SwiftData
import SwiftUI

/// Card-based games: Yo nunca, ¿Quién es más probable?, Verdad o trago and Retos.
struct PromptGameView: View {
    let kind: GameKind
    let mode: PartyMode

    @Environment(PartySession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CustomCard.createdAt) private var customCards: [CustomCard]

    @State private var deck = ShuffledDeck<String>([])
    @State private var card: (text: String, involved: [Player])?
    @State private var selection: Set<UUID> = []
    @State private var pointingPhase: PointingPhase = .question
    @State private var countdownTask: Task<Void, Never>?
    @State private var loaded = false
    /// Increments on every new card so even a repeated text animates as a fresh card.
    @State private var dealt = 0

    private enum PointingPhase: Equatable {
        case question
        case countdown(Int)
        case pick
    }

    private var colors: [Color] { kind.gradient(for: mode) }
    private var penalty: Int { PromptDecks.penalty(for: kind, mode: mode) }
    private var lexicon: Lexicon { session.lexicon }

    var body: some View {
        GameScaffold(game: kind, mode: mode) {
            VStack(spacing: 18) {
                Spacer(minLength: 8)
                ZStack {
                    if let card {
                        PromptCardView(text: lexicon.adapt(card.text), colors: colors, eyebrow: eyebrow(for: card))
                            .id(dealt)
                            .transition(.deal(reduceMotion: reduceMotion))
                    } else if loaded {
                        ContentUnavailableView("Sin cartas", systemImage: "rectangle.stack", description: Text("No hay cartas para este juego."))
                    } else {
                        // Same footprint as a card while the deck is prepared: no flash of empty states.
                        PromptCardView(text: " ", colors: colors)
                            .redacted(reason: .placeholder)
                    }
                }
                if case .countdown(let value) = pointingPhase {
                    Text("\(value)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .gradientText(colors)
                        .contentTransition(.numericText(countsDown: true))
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Cuenta atrás \(value)")
                } else {
                    SipBadge(count: penalty, lexicon: lexicon, prefix: badgePrefix)
                }
                Spacer(minLength: 8)
            }
            .animation(.spring(duration: 0.3), value: pointingPhase)
        } controls: {
            controls
        }
        .onAppear {
            guard !loaded else { return }
            setUp()
        }
        .onDisappear { countdownTask?.cancel() }
    }

    // MARK: - Labels

    private func eyebrow(for card: (text: String, involved: [Player])) -> String {
        switch kind {
        case .neverHave: mode == .hot ? "Yo nunca · Hot" : "Yo nunca"
        case .mostLikely: "¿Quién es más probable…?"
        case .truthOrDrink: "Le toca a \(session.currentPlayer?.name ?? "alguien")"
        case .dares: card.involved.isEmpty ? "Reto para \(session.currentPlayer?.name ?? "alguien")" : "Reto"
        default: kind.title
        }
    }

    private var badgePrefix: String {
        switch kind {
        case .neverHave: lexicon.soberMode ? "Quien sí, suma" : "Quien sí, bebe"
        case .mostLikely: lexicon.soberMode ? "El más señalado suma" : "El más señalado bebe"
        case .truthOrDrink, .dares: lexicon.soberMode ? "Si pasas, sumas" : "Si pasas, bebes"
        default: ""
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch kind {
        case .neverHave:
            VStack(spacing: 12) {
                Text(lexicon.soberMode ? "¿Quién suma punto?" : "¿Quién ha bebido?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                PlayerPicker(players: session.players, selection: $selection, accent: colors.first ?? Neon.violet)
                BigButton(title: "Siguiente", symbol: "arrow.right", tint: colors.first ?? Neon.violet, identifier: "prompt.next") {
                    session.give(penalty, to: selection)
                    next(advanceTurn: false)
                }
            }
        case .mostLikely:
            VStack(spacing: 12) {
                if pointingPhase == .pick {
                    Text("¿A quién habéis señalado más? (si hay empate, marca a todos)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    PlayerPicker(players: session.players, selection: $selection, accent: colors.first ?? Neon.violet)
                    BigButton(title: "Siguiente", symbol: "arrow.right", tint: colors.first ?? Neon.violet, identifier: "prompt.next") {
                        session.give(penalty, to: selection)
                        next(advanceTurn: false)
                    }
                    .disabled(selection.isEmpty)
                } else {
                    BigButton(title: "3, 2, 1… ¡Señalad!", symbol: "hand.point.up.left.fill", tint: colors.first ?? Neon.violet, identifier: "prompt.point") {
                        startCountdown()
                    }
                    .disabled(pointingPhase != .question)
                }
            }
        case .truthOrDrink, .dares:
            let target = card?.involved.first ?? session.currentPlayer
            HStack(spacing: 10) {
                BigButton(title: lexicon.soberMode ? "Pasa: +\(penalty)" : "Pasa: bebe \(penalty)", tint: Neon.amber, prominent: false, identifier: "prompt.pass") {
                    session.give(penalty, to: target)
                    Haptics.tap(.medium)
                    next(advanceTurn: true)
                }
                BigButton(title: kind == .dares ? "¡Reto cumplido!" : "Ha contestado", symbol: "checkmark", tint: colors.first ?? Neon.violet, identifier: "prompt.done") {
                    Haptics.success()
                    next(advanceTurn: true)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Flow

    private func setUp() {
        let custom = customCards.filter { $0.game == kind && $0.mode == mode }.map(\.text)
        deck = ShuffledDeck(PromptDecks.prompts(for: kind, mode: mode, intensity: session.intensity) + custom)
        draw()
        loaded = true
        Haptics.prepare()
    }

    private func draw() {
        guard let template = deck.draw() else {
            card = nil
            return
        }
        var generator = SystemRandomNumberGenerator()
        let filled = CardText.fill(template, players: session.players, first: session.currentPlayer, using: &generator)
        card = (filled.text, filled.involved)
        dealt += 1
    }

    private func next(advanceTurn: Bool) {
        selection = []
        pointingPhase = .question
        if advanceTurn { session.nextTurn() }
        session.registerRound()
        withAnimation(.spring(duration: 0.45, bounce: 0.18)) { draw() }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task {
            for value in stride(from: 3, through: 1, by: -1) {
                pointingPhase = .countdown(value)
                Haptics.tap(.medium)
                try? await Task.sleep(for: .milliseconds(800))
                if Task.isCancelled { return }
            }
            Haptics.success()
            pointingPhase = .pick
        }
    }
}
