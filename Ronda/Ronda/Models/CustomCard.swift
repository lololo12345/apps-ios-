import Foundation
import SwiftData

/// A prompt written by the group (inside jokes, local references…), mixed into the built-in deck.
@Model
final class CustomCard {
    var id: UUID = UUID()
    var gameRaw: String = GameKind.neverHave.rawValue
    var modeRaw: String = PartyMode.normal.rawValue
    var text: String = ""
    var createdAt: Date = Date.now

    init(game: GameKind, mode: PartyMode, text: String) {
        self.id = UUID()
        self.gameRaw = game.rawValue
        self.modeRaw = mode.rawValue
        self.text = text
        self.createdAt = .now
    }

    var game: GameKind { GameKind(rawValue: gameRaw) ?? .neverHave }
    var mode: PartyMode { PartyMode(rawValue: modeRaw) ?? .normal }
}

enum CustomCardRules {
    static let maxLength = 160

    /// Normalises a custom card: trims, collapses whitespace, adds the game's prefix where it helps.
    static func normalize(_ raw: String, for game: GameKind) -> String? {
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard text.count >= 3 else { return nil }
        let limited = String(text.prefix(maxLength))
        switch game {
        case .neverHave:
            let folded = limited.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            return folded.hasPrefix("yo nunca") ? limited : "Yo nunca " + lowercasedFirst(limited)
        case .mostLikely:
            let folded = limited.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            if folded.hasPrefix("¿quien") || folded.hasPrefix("quien") {
                return limited.hasPrefix("¿") ? limited : "¿" + limited + (limited.hasSuffix("?") ? "" : "?")
            }
            return "¿Quién es más probable que " + lowercasedFirst(limited.trimmingCharacters(in: CharacterSet(charactersIn: "¿?"))) + "?"
        default:
            return limited
        }
    }

    private static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }
}
