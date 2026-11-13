import Foundation

/// The 40-card Spanish deck: 1–7, Sota (10), Caballo (11) and Rey (12) in four suits.
struct SpanishCard: Hashable, Identifiable, Sendable {
    enum Suit: String, CaseIterable, Sendable {
        case oros, copas, espadas, bastos

        var name: String {
            switch self {
            case .oros: "Oros"
            case .copas: "Copas"
            case .espadas: "Espadas"
            case .bastos: "Bastos"
            }
        }

        var glyph: String {
            switch self {
            case .oros: "🪙"
            case .copas: "🏆"
            case .espadas: "⚔️"
            case .bastos: "🪵"
            }
        }
    }

    static let ranks = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]

    let rank: Int
    let suit: Suit

    var id: String { "\(rank)-\(suit.rawValue)" }

    var rankName: String {
        switch rank {
        case 1: "As"
        case 10: "Sota"
        case 11: "Caballo"
        case 12: "Rey"
        default: "\(rank)"
        }
    }

    var shortRank: String {
        switch rank {
        case 1: "A"
        case 10: "S"
        case 11: "C"
        case 12: "R"
        default: "\(rank)"
        }
    }

    var fullName: String { "\(rankName) de \(suit.name)" }

    static var fullDeck: [SpanishCard] {
        Suit.allCases.flatMap { suit in ranks.map { SpanishCard(rank: $0, suit: suit) } }
    }
}

/// "Mayor o menor": guess whether the next card is higher or lower. Each hit adds a sip to the pot;
/// a miss (or a tie) means drinking the whole pot. After 3 hits in a row you may stand and pass the
/// pot to the next player.
struct HigherLowerGame: Sendable {
    enum Guess: Sendable { case higher, lower }

    enum Outcome: Equatable, Sendable {
        case hit(pot: Int)
        case miss(drinks: Int)
        case tie(drinks: Int)
    }

    static let hitsNeededToStand = 3

    private(set) var deck: [SpanishCard]
    private(set) var current: SpanishCard
    private(set) var pot = 0
    private(set) var streak = 0

    init(using generator: inout some RandomNumberGenerator) {
        var cards = SpanishCard.fullDeck.shuffled(using: &generator)
        current = cards.removeLast()
        deck = cards
    }

    var canStand: Bool { streak >= Self.hitsNeededToStand }
    var cardsLeft: Int { deck.count }

    mutating func guess(_ guess: Guess, using generator: inout some RandomNumberGenerator) -> (card: SpanishCard, outcome: Outcome) {
        if deck.isEmpty {
            deck = SpanishCard.fullDeck.filter { $0 != current }.shuffled(using: &generator)
        }
        let next = deck.removeLast()
        defer { current = next }

        if next.rank == current.rank {
            let drinks = max(1, pot)
            pot = 0
            streak = 0
            return (next, .tie(drinks: drinks))
        }
        let isHigher = next.rank > current.rank
        if (guess == .higher) == isHigher {
            pot += 1
            streak += 1
            return (next, .hit(pot: pot))
        }
        let drinks = max(1, pot)
        pot = 0
        streak = 0
        return (next, .miss(drinks: drinks))
    }

    /// Ends the current player's run; the pot stays for the next player.
    mutating func stand() {
        streak = 0
    }
}

/// "El Círculo": each rank of the Spanish deck carries a rule. Whoever draws the fourth king
/// drinks the final penalty and the round ends.
struct CircleGame: Sendable {
    struct Rule: Equatable, Sendable {
        let title: String
        let detail: String
        /// Sips for the player who drew the card, if the rule applies automatically.
        let drawerSips: Int
        /// Sips for everyone at the table.
        let everyoneSips: Int
    }

    private(set) var deck: [SpanishCard]
    private(set) var kingsDrawn = 0
    private(set) var lastCard: SpanishCard?
    let hot: Bool

    init(hot: Bool, using generator: inout some RandomNumberGenerator) {
        self.hot = hot
        deck = SpanishCard.fullDeck.shuffled(using: &generator)
    }

    var cardsLeft: Int { deck.count }
    var isFinished: Bool { kingsDrawn >= 4 || deck.isEmpty }

    mutating func draw() -> (card: SpanishCard, rule: Rule, isFinalKing: Bool)? {
        guard !isFinished, let card = deck.popLast() else { return nil }
        lastCard = card
        var isFinalKing = false
        if card.rank == 12 {
            kingsDrawn += 1
            isFinalKing = kingsDrawn == 4
        }
        return (card, Self.rule(for: card.rank, hot: hot, finalKing: isFinalKing), isFinalKing)
    }

    static func rule(for rank: Int, hot: Bool, finalKing: Bool = false) -> Rule {
        if rank == 12 {
            return finalKing
                ? Rule(title: "¡El cuarto Rey!", detail: "Has sacado el último Rey: te toca 5 de golpe y se acaba la ronda.", drawerSips: 5, everyoneSips: 0)
                : Rule(title: "Rey", detail: "Apunta: ya van más reyes. Quien saque el cuarto se lleva el castigo final.", drawerSips: 1, everyoneSips: 0)
        }
        let table = hot ? hotRules : normalRules
        return table[rank] ?? Rule(title: "Libre", detail: "Te libras esta vez.", drawerSips: 0, everyoneSips: 0)
    }

    static let normalRules: [Int: Rule] = [
        1: Rule(title: "Todos", detail: "Brindis general: bebe toda la mesa.", drawerSips: 0, everyoneSips: 1),
        2: Rule(title: "Reparte", detail: "Reparte 2 entre quien quieras.", drawerSips: 0, everyoneSips: 0),
        3: Rule(title: "Para ti", detail: "Te tocan 2. Salud.", drawerSips: 2, everyoneSips: 0),
        4: Rule(title: "Izquierda", detail: "Le toca a quien tienes a tu izquierda.", drawerSips: 0, everyoneSips: 0),
        5: Rule(title: "Derecha", detail: "Le toca a quien tienes a tu derecha.", drawerSips: 0, everyoneSips: 0),
        6: Rule(title: "Yo nunca", detail: "Di un «yo nunca». Bebe quien sí lo haya hecho.", drawerSips: 0, everyoneSips: 0),
        7: Rule(title: "Categoría", detail: "Elige una categoría y decid cosas por turnos. Quien se quede en blanco, 2.", drawerSips: 0, everyoneSips: 0),
        10: Rule(title: "Norma", detail: "Inventa una norma que dure toda la ronda. Quien la rompa, bebe.", drawerSips: 0, everyoneSips: 0),
        11: Rule(title: "Preguntón", detail: "Hasta tu próximo turno, quien conteste a tus preguntas bebe.", drawerSips: 0, everyoneSips: 0),
    ]

    static let hotRules: [Int: Rule] = [
        1: Rule(title: "Brindis hot", detail: "Brindad mirándoos a los ojos. Quien aparte la mirada primero, bebe 2.", drawerSips: 0, everyoneSips: 1),
        2: Rule(title: "Reparte", detail: "Reparte 2 entre quien más te guste de la mesa.", drawerSips: 0, everyoneSips: 0),
        3: Rule(title: "Confiesa", detail: "Cuenta tu último ligue o bebe 3.", drawerSips: 0, everyoneSips: 0),
        4: Rule(title: "Izquierda", detail: "Piropo a quien tienes a tu izquierda. Si se ríe, bebe.", drawerSips: 0, everyoneSips: 0),
        5: Rule(title: "Derecha", detail: "Quien está a tu derecha te pregunta lo que quiera. Contesta o bebe 2.", drawerSips: 0, everyoneSips: 0),
        6: Rule(title: "Yo nunca hot", detail: "Di un «yo nunca» picante. Bebe quien sí lo haya hecho.", drawerSips: 0, everyoneSips: 0),
        7: Rule(title: "Categoría hot", detail: "Categoría picante (lugares para una cita, apps de ligar…). Quien se quede en blanco, 2.", drawerSips: 0, everyoneSips: 0),
        10: Rule(title: "Norma hot", detail: "Inventa una norma picante para la ronda. Quien la rompa, bebe.", drawerSips: 0, everyoneSips: 0),
        11: Rule(title: "Pareja de tragos", detail: "Elige a alguien: cada vez que bebas tú, bebe también, hasta tu próximo turno.", drawerSips: 0, everyoneSips: 0),
    ]
}
