import Foundation

/// Fills `{1}` and `{2}` in card texts with distinct random players.
enum CardText {
    static func requiredPlayers(_ template: String) -> Int {
        template.contains("{2}") ? 2 : (template.contains("{1}") ? 1 : 0)
    }

    /// `first` is preferred for `{1}` (usually the player whose turn it is).
    static func fill(
        _ template: String,
        players: [Player],
        first: Player? = nil,
        using generator: inout some RandomNumberGenerator
    ) -> (text: String, involved: [Player]) {
        let needed = requiredPlayers(template)
        guard needed > 0, !players.isEmpty else { return (template, []) }
        var pool = players.shuffled(using: &generator)
        var chosen: [Player] = []
        if let first, let index = pool.firstIndex(of: first) {
            chosen.append(pool.remove(at: index))
        }
        while chosen.count < needed, !pool.isEmpty {
            chosen.append(pool.removeFirst())
        }
        var text = template
        for (offset, player) in chosen.enumerated() {
            text = text.replacingOccurrences(of: "{\(offset + 1)}", with: player.name)
        }
        return (text, chosen)
    }
}

/// Words that change in alcohol-free mode, so every screen stays consistent.
struct Lexicon: Sendable {
    let soberMode: Bool

    func sips(_ count: Int) -> String {
        soberMode
            ? (count == 1 ? "1 punto" : "\(count) puntos")
            : (count == 1 ? "1 sorbo" : "\(count) sorbos")
    }

    /// "bebe 2 sorbos" / "suma 2 puntos"
    func drink(_ count: Int) -> String {
        soberMode ? "suma \(sips(count))" : "bebe \(sips(count))"
    }

    /// Rewrites built-in card text for alcohol-free mode ("bebe 2" → "suma 2 puntos").
    func adapt(_ text: String) -> String {
        guard soberMode else { return text }
        var result = text
        for (from, to) in Self.soberReplacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }

    private static let soberReplacements: [(String, String)] = [
        ("sorbos", "puntos"), ("sorbo", "punto"), ("Bebe toda la mesa", "Suma 1 punto toda la mesa"),
        ("beberá contigo", "sumará contigo"), ("bebe también", "suma también"), ("cada vez que bebas", "cada vez que sumes"),
        ("o bebe ", "o suma "), ("Bebe ", "Suma "), ("bebe ", "suma "), ("bebe.", "suma un punto."),
        ("Te tocan 2. Salud.", "Te tocan 2 puntos."), ("te toca 5 de golpe", "te tocan 5 puntos de golpe"),
        ("Bebes ", "Sumas "), ("Reparte ", "Reparte puntos: "), ("un buen trago de agua", "un vaso de agua"),
    ]

    var unitTitle: String { soberMode ? "Puntos" : "Sorbos" }
    var drinkVerb: String { soberMode ? "Suma" : "Bebe" }
    var drinkSymbol: String { soberMode ? "star.fill" : "wineglass.fill" }
}
