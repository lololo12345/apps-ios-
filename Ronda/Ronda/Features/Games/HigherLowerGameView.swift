import SwiftUI

struct HigherLowerGameView: View {
    @Environment(PartySession.self) private var session

    @State private var game: HigherLowerGame?
    @State private var message: (text: String, good: Bool)?
    @State private var flip = 0.0

    private let colors = GameKind.higherLower.gradient(for: .normal)

    var body: some View {
        GameScaffold(game: .higherLower, mode: .normal) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Text("Le toca a \(session.currentPlayer?.name ?? "—")")
                    .font(.title3.weight(.bold))
                    .gradientText(colors)
                    .accessibilityIdentifier("hl.player")

                if let game {
                    SpanishCardView(card: game.current, size: 160)
                        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0))
                        .id(game.current.id)
                        .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))

                    HStack(spacing: 10) {
                        SipBadge(count: max(1, game.pot), lexicon: session.lexicon, prefix: "Bote:")
                        if game.streak > 0 {
                            Label("\(game.streak) seguidos", systemImage: "flame.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Neon.amber)
                        }
                    }
                    .accessibilityIdentifier("hl.pot")
                }

                if let message {
                    Text(message.text)
                        .font(.headline)
                        .foregroundStyle(message.good ? Neon.lime : Neon.orange)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .id(message.text)
                }
                Spacer(minLength: 0)
            }
            .animation(.spring(duration: 0.45, bounce: 0.3), value: game?.current)
            .animation(.smooth(duration: 0.25), value: message?.text)
        } controls: {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    BigButton(title: "Menor", symbol: "arrow.down", tint: Neon.cyan, identifier: "hl.lower") { guess(.lower) }
                    BigButton(title: "Mayor", symbol: "arrow.up", tint: Neon.amber, identifier: "hl.higher") { guess(.higher) }
                }
                if game?.canStand == true {
                    BigButton(title: "Plantarse y pasar el bote", symbol: "hand.raised.fill", tint: Neon.lime, prominent: false, identifier: "hl.stand") {
                        stand()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Text("Orden: As · 2–7 · Sota · Caballo · Rey. Si sale igual, cuenta como fallo.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .animation(.smooth, value: game?.canStand)
        }
        .onAppear {
            var generator = SystemRandomNumberGenerator()
            game = HigherLowerGame(using: &generator)
        }
    }

    private func guess(_ guess: HigherLowerGame.Guess) {
        guard var current = game else { return }
        var generator = SystemRandomNumberGenerator()
        let player = session.currentPlayer
        let result = current.guess(guess, using: &generator)
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            game = current
            flip += 360
        }
        let name = player?.name ?? "Alguien"
        switch result.outcome {
        case .hit(let pot):
            Haptics.success()
            message = ("¡Acierto! \(result.card.fullName). El bote sube a \(pot).", true)
        case .miss(let drinks):
            Haptics.warning()
            session.give(drinks, to: player)
            message = ("Fallo: \(result.card.fullName). \(name) \(session.lexicon.drink(drinks)).", false)
            session.nextTurn()
            session.registerRound()
        case .tie(let drinks):
            Haptics.warning()
            session.give(drinks, to: player)
            message = ("¡Empate! \(result.card.fullName). \(name) \(session.lexicon.drink(drinks)).", false)
            session.nextTurn()
            session.registerRound()
        }
    }

    private func stand() {
        guard var current = game else { return }
        let name = session.currentPlayer?.name ?? "Alguien"
        current.stand()
        game = current
        session.nextTurn()
        Haptics.tap(.medium)
        message = ("\(name) se planta. El bote de \(current.pot) pasa a \(session.currentPlayer?.name ?? "el siguiente").", true)
    }
}
