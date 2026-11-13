import SwiftUI

struct CircleGameView: View {
    let mode: PartyMode

    @Environment(PartySession.self) private var session

    @State private var game: CircleGame?
    @State private var drawn: (card: SpanishCard, rule: CircleGame.Rule, drawer: Player?, finalKing: Bool)?
    @State private var autoNote: String?

    private var colors: [Color] { GameKind.circle.gradient(for: mode) }

    var body: some View {
        GameScaffold(game: .circle, mode: mode) {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                if let game {
                    HStack(spacing: 14) {
                        Label("\(game.cardsLeft) cartas", systemImage: "rectangle.stack.fill")
                        Label("Reyes: \(game.kingsDrawn)/4", systemImage: "crown.fill")
                            .foregroundStyle(game.kingsDrawn >= 3 ? Neon.crimson : .secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("circle.status")
                }

                if let drawn {
                    SpanishCardView(card: drawn.card, size: 130)
                        .id(drawn.card.id)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    VStack(spacing: 8) {
                        Text(drawn.rule.title)
                            .font(.title2.weight(.black))
                            .gradientText(drawn.finalKing ? [Neon.crimson, Neon.orange] : colors)
                        Text(session.lexicon.adapt(drawn.rule.detail))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if let autoNote {
                            Text(autoNote)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Neon.amber)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .neonCard(colors, padding: 18)
                    .accessibilityIdentifier("circle.rule")
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "suit.club.fill")
                            .font(.system(size: 64))
                            .gradientText(colors)
                        Text("Las cartas están en círculo. Por turnos, sacad una y cumplid su norma.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
                Spacer(minLength: 0)
            }
            .animation(.spring(duration: 0.45, bounce: 0.3), value: drawn?.card)
        } controls: {
            VStack(spacing: 10) {
                if game?.isFinished == true {
                    BigButton(title: "Nueva ronda", symbol: "arrow.counterclockwise", tint: colors.first ?? Neon.cyan, identifier: "circle.restart") {
                        restart()
                    }
                } else {
                    BigButton(title: "Saca \(session.currentPlayer?.name ?? "carta")", symbol: "hand.draw.fill", tint: colors.first ?? Neon.cyan, identifier: "circle.draw") {
                        draw()
                    }
                }
            }
        }
        .onAppear(perform: restart)
    }

    private func restart() {
        var generator = SystemRandomNumberGenerator()
        game = CircleGame(hot: mode == .hot, using: &generator)
        drawn = nil
        autoNote = nil
    }

    private func draw() {
        guard var current = game, let result = current.draw() else { return }
        game = current
        let drawer = session.currentPlayer
        let rule = result.rule
        var notes: [String] = []
        if rule.drawerSips > 0, let drawer {
            session.give(rule.drawerSips, to: drawer)
            notes.append("\(drawer.name): +\(rule.drawerSips)")
        }
        if rule.everyoneSips > 0 {
            session.everyone(rule.everyoneSips)
            notes.append("Todos: +\(rule.everyoneSips)")
        }
        // In the normal deck, 4 and 5 send a sip to the neighbours automatically.
        if mode == .normal, let drawer, result.card.rank == 4 || result.card.rank == 5 {
            let target = result.card.rank == 4 ? session.player(leftOf: drawer) : session.player(rightOf: drawer)
            if let target {
                session.give(1, to: target)
                notes.append("\(target.name): +1")
            }
        }
        autoNote = notes.isEmpty ? nil : "Apuntado en el marcador · " + notes.joined(separator: " · ")
        result.isFinalKing ? Haptics.boom() : Haptics.tap(.medium)
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            drawn = (result.card, rule, drawer, result.isFinalKing)
        }
        session.nextTurn()
        session.registerRound()
    }
}
