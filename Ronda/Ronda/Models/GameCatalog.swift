import SwiftUI

/// The two sections of the home screen.
enum PartyMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case normal
    case hot

    var id: String { rawValue }
    var title: String { self == .normal ? "Normal" : "Hot" }
    var symbol: String { self == .normal ? "party.popper.fill" : "flame.fill" }
}

/// Content intensity inside the Normal section.
enum Intensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case soft
    case party

    var id: String { rawValue }
    var title: String { self == .soft ? "Suave" : "Fiesta" }
}

enum GameKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case neverHave
    case mostLikely
    case truthOrDrink
    case dares
    case bomb
    case higherLower
    case circle
    case duels
    case roulette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neverHave: "Yo nunca"
        case .mostLikely: "¿Quién es más probable?"
        case .truthOrDrink: "Verdad o trago"
        case .dares: "Retos"
        case .bomb: "La Bomba"
        case .higherLower: "Mayor o menor"
        case .circle: "El Círculo"
        case .duels: "Duelos"
        case .roulette: "La Ruleta"
        }
    }

    var tagline: String {
        switch self {
        case .neverHave: "Bebe quien sí lo haya hecho"
        case .mostLikely: "A la de 3, todos señaláis"
        case .truthOrDrink: "Contesta o bebe"
        case .dares: "Retos atrevidos entre dos"
        case .bomb: "Pásala antes de que explote"
        case .higherLower: "Adivina con la baraja española"
        case .circle: "Cada carta, una norma"
        case .duels: "Cara a cara en la pantalla"
        case .roulette: "Gira y que decida la suerte"
        }
    }

    var symbol: String {
        switch self {
        case .neverHave: "hand.raised.fill"
        case .mostLikely: "person.3.fill"
        case .truthOrDrink: "questionmark.bubble.fill"
        case .dares: "heart.circle.fill"
        case .bomb: "flame.circle.fill"
        case .higherLower: "arrow.up.arrow.down.circle.fill"
        case .circle: "suit.club.fill"
        case .duels: "bolt.horizontal.circle.fill"
        case .roulette: "circle.dashed.inset.filled"
        }
    }

    var minimumPlayers: Int {
        switch self {
        case .mostLikely: 3
        case .dares, .duels: 2
        default: 2
        }
    }

    var howToPlay: String {
        switch self {
        case .neverHave: "Sale una frase «Yo nunca…». Quien SÍ lo haya hecho bebe. Marca en la app quién ha bebido para llevar la cuenta y pasa a la siguiente."
        case .mostLikely: "Lee la pregunta en voz alta. A la de 3, todos señaláis a la vez a alguien. Quien reciba más dedos bebe 2. Si hay empate, beben todos los empatados."
        case .truthOrDrink: "Le toca a quien sale en pantalla: o contesta la pregunta con sinceridad, o bebe y pasa."
        case .dares: "La app elige a dos jugadores y un reto. Se puede rechazar siempre: quien no quiera hacerlo bebe 3 y no pasa nada."
        case .bomb: "Sale una categoría. Pulsad «Encender» y pasad el móvil diciendo cada uno una palabra. La bomba explota en un momento al azar: quien la tenga, bebe."
        case .higherLower: "Adivina si la siguiente carta será mayor o menor. Cada acierto suma 1 al bote; si fallas o hay empate, te bebes el bote entero. Con 3 aciertos puedes plantarte y pasarle el bote al siguiente."
        case .circle: "Por turnos, sacad una carta de la baraja española. Cada número tiene una norma. Quien saque el cuarto Rey se lleva el castigo final."
        case .duels: "Elegid dos jugadores. Cada uno en su mitad de la pantalla, cara a cara. Quien pierda el minijuego, bebe 2."
        case .roulette: "Gira la ruleta en tu turno y haz lo que salga."
        }
    }

    /// Games whose content changes between sections, and which games belong to each section.
    static func games(for mode: PartyMode) -> [GameKind] {
        switch mode {
        case .normal: [.neverHave, .mostLikely, .truthOrDrink, .bomb, .higherLower, .circle, .duels, .roulette]
        case .hot: [.neverHave, .mostLikely, .truthOrDrink, .dares, .bomb, .roulette, .circle]
        }
    }

    var supportsCustomCards: Bool {
        [.neverHave, .mostLikely, .truthOrDrink, .dares].contains(self)
    }

    func gradient(for mode: PartyMode) -> [Color] {
        if mode == .hot {
            switch self {
            case .neverHave: return [Neon.rose, Neon.crimson]
            case .mostLikely: return [Neon.magenta, Neon.rose]
            case .truthOrDrink: return [Neon.crimson, Neon.orange]
            case .dares: return [Neon.rose, Neon.violet]
            case .bomb: return [Neon.orange, Neon.crimson]
            case .roulette: return [Neon.magenta, Neon.crimson]
            default: return [Neon.crimson, Neon.violet]
            }
        }
        switch self {
        case .neverHave: return [Neon.cyan, Neon.violet]
        case .mostLikely: return [Neon.lime, Neon.cyan]
        case .truthOrDrink: return [Neon.violet, Neon.magenta]
        case .dares: return [Neon.rose, Neon.violet]
        case .bomb: return [Neon.orange, Neon.crimson]
        case .higherLower: return [Neon.amber, Neon.orange]
        case .circle: return [Neon.cyan, Neon.lime]
        case .duels: return [Neon.magenta, Neon.orange]
        case .roulette: return [Neon.violet, Neon.cyan]
        }
    }
}

/// Built-in prompt decks per game, mode and intensity.
enum PromptDecks {
    static func prompts(for game: GameKind, mode: PartyMode, intensity: Intensity) -> [String] {
        switch (game, mode) {
        case (.neverHave, .hot): CardBank.neverHot
        case (.neverHave, _): intensity == .soft ? CardBank.neverSoft : CardBank.neverSoft + CardBank.neverParty
        case (.mostLikely, .hot): CardBank.mostLikelyHot
        case (.mostLikely, _): intensity == .soft ? CardBank.mostLikelySoft : CardBank.mostLikelySoft + CardBank.mostLikelyParty
        case (.truthOrDrink, .hot): CardBank.truthHot
        case (.truthOrDrink, _): intensity == .soft ? CardBank.truthSoft : CardBank.truthSoft + CardBank.truthParty
        case (.dares, _): CardBank.daresHot
        case (.bomb, .hot): CardBank.bombHot
        case (.bomb, _): CardBank.bombNormal
        default: []
        }
    }

    /// Sips for refusing or losing on each card type.
    static func penalty(for game: GameKind, mode: PartyMode) -> Int {
        switch game {
        case .neverHave: 1
        case .mostLikely: 2
        case .truthOrDrink: mode == .hot ? 3 : 2
        case .dares: 3
        case .bomb: 2
        case .duels: 2
        default: 1
        }
    }
}
