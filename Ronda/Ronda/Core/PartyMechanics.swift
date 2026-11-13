import Foundation

/// "La Bomba": the phone ticks while being passed around and explodes at a random moment.
/// The tick interval shrinks as the fuse burns, so tension builds.
struct BombFuse: Sendable {
    static let durationRange: ClosedRange<Double> = 15...40

    let duration: Double

    init(using generator: inout some RandomNumberGenerator, range: ClosedRange<Double> = durationRange) {
        duration = Double.random(in: range, using: &generator)
    }

    init(duration: Double) {
        self.duration = duration
    }

    /// Seconds until the next tick, given the elapsed time. From ~1 s at the start down to 0.15 s at the end.
    func tickInterval(elapsed: Double) -> Double {
        let progress = min(1, max(0, elapsed / duration))
        return max(0.15, 1.0 - 0.85 * progress * progress)
    }

    func hasExploded(elapsed: Double) -> Bool { elapsed >= duration }
}

/// Head-to-head mini games played on one screen, one player per half.
enum Duel {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case reflex, taps, colors

        var id: String { rawValue }

        var title: String {
            switch self {
            case .reflex: "Reflejos"
            case .taps: "Toques"
            case .colors: "Colores"
            }
        }

        var instructions: String {
            switch self {
            case .reflex: "Espera a que tu mitad se ponga verde y toca. Si tocas antes, pierdes."
            case .taps: "Toca tu mitad todas las veces que puedas en 5 segundos."
            case .colors: "Toca solo cuando el color de la palabra coincida con lo que dice. Si fallas, pierdes."
            }
        }

        var symbol: String {
            switch self {
            case .reflex: "bolt.fill"
            case .taps: "hand.tap.fill"
            case .colors: "paintpalette.fill"
            }
        }
    }

    enum Side: Sendable { case top, bottom

        var other: Side { self == .top ? .bottom : .top }
    }

    enum Result: Equatable, Sendable {
        case winner(Side)
        case tie
    }

    /// Reflex duel: a tap before "go" loses immediately; otherwise the first tap after "go" wins.
    static func resolveReflex(tap side: Side, beforeGo: Bool) -> Result {
        beforeGo ? .winner(side.other) : .winner(side)
    }

    static let tapDuration: Double = 5

    static func resolveTaps(top: Int, bottom: Int) -> Result {
        top == bottom ? .tie : .winner(top > bottom ? .top : .bottom)
    }

    /// Colour-word duel (Stroop effect). A round matches when the ink colour equals the written word.
    struct ColorRound: Equatable, Sendable {
        static let palette = ["ROJO", "AZUL", "VERDE", "AMARILLO"]

        let word: Int
        let ink: Int
        var matches: Bool { word == ink }
    }

    /// Sequence of rounds that guarantees a match appears within the first `maxRounds`.
    static func colorRounds(count: Int = 12, using generator: inout some RandomNumberGenerator) -> [ColorRound] {
        let palette = ColorRound.palette.count
        var rounds: [ColorRound] = []
        let guaranteedMatch = Int.random(in: 2..<max(3, min(count, 7)), using: &generator)
        for index in 0..<count {
            let word = Int.random(in: 0..<palette, using: &generator)
            if index == guaranteedMatch {
                rounds.append(ColorRound(word: word, ink: word))
            } else {
                var ink = Int.random(in: 0..<palette, using: &generator)
                // Keep matches rare (~1 in 4) so the duel tests attention, not luck.
                if ink == word, Int.random(in: 0..<3, using: &generator) != 0 {
                    ink = (ink + 1 + Int.random(in: 0..<(palette - 1), using: &generator)) % palette
                }
                rounds.append(ColorRound(word: word, ink: ink))
            }
        }
        return rounds
    }

    static func resolveColorTap(side: Side, round: ColorRound) -> Result {
        round.matches ? .winner(side) : .winner(side.other)
    }
}

/// "La Ruleta": weighted wheel of outcomes.
struct Roulette: Sendable {
    struct Segment: Equatable, Sendable {
        let title: String
        let detail: String
        /// Sips for the spinner, applied automatically.
        let spinnerSips: Int
        /// Sips for everyone, applied automatically.
        let everyoneSips: Int
        let weight: Int
    }

    let segments: [Segment]

    var totalWeight: Int { segments.reduce(0) { $0 + $1.weight } }

    func pick(using generator: inout some RandomNumberGenerator) -> Int {
        var roll = Int.random(in: 0..<max(1, totalWeight), using: &generator)
        for (index, segment) in segments.enumerated() {
            if roll < segment.weight { return index }
            roll -= segment.weight
        }
        return segments.count - 1
    }

    /// Final wheel rotation (degrees, clockwise) so that `index` stops under the pointer at the top,
    /// after a few full turns from `currentRotation`.
    func rotation(landingOn index: Int, from currentRotation: Double, extraTurns: Int = 5, jitter: Double = 0) -> Double {
        let slice = 360.0 / Double(segments.count)
        // Segment i is drawn starting at angle i*slice (clockwise from the top), centred at (i + 0.5)*slice.
        let target = 360 - (Double(index) + 0.5) * slice + jitter * slice * 0.35
        let base = currentRotation - currentRotation.truncatingRemainder(dividingBy: 360)
        return base + Double(extraTurns) * 360 + target
    }

    /// Which segment is under the top pointer for a given rotation.
    func segment(atRotation rotation: Double) -> Int {
        let slice = 360.0 / Double(segments.count)
        var angle = (360 - rotation.truncatingRemainder(dividingBy: 360)).truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return min(segments.count - 1, Int(angle / slice))
    }
}
