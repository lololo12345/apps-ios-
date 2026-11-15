import Foundation

enum ChallengeKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case riddle, trivia, math, memory, logic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .riddle: "Acertijo"
        case .trivia: "Cultura general"
        case .math: "Matemáticas"
        case .memory: "Memoria"
        case .logic: "Lógica"
        }
    }

    var subtitle: String {
        switch self {
        case .riddle: "Piensa diferente"
        case .trivia: "¿Cuánto sabes?"
        case .math: "Cálculo mental"
        case .memory: "Recuerda el patrón"
        case .logic: "Encuentra la regla"
        }
    }

    var symbol: String {
        switch self {
        case .riddle: "questionmark.bubble.fill"
        case .trivia: "globe.europe.africa.fill"
        case .math: "plus.forwardslash.minus"
        case .memory: "square.grid.3x3.fill"
        case .logic: "lightbulb.max.fill"
        }
    }

    var tintHex: UInt32 {
        switch self {
        case .riddle: 0xA77BFF
        case .trivia: 0x4DA3FF
        case .math: 0x3DDC97
        case .memory: 0xFF6FB5
        case .logic: 0xFFB020
        }
    }
}

struct MemoryBoard: Sendable, Equatable {
    let columns: Int
    let rows: Int
    /// Cells to remember, in the order they light up.
    let targets: [Int]
    /// When true the cells must be tapped in the order they were shown.
    let ordered: Bool

    var cellCount: Int { columns * rows }

    /// Seconds the pattern stays visible.
    var showSeconds: Double { ordered ? Double(targets.count) * 0.7 + 0.6 : 2.2 + Double(targets.count) * 0.25 }
}

struct Challenge: Identifiable, Sendable, Equatable {
    enum Body: Sendable, Equatable {
        case choice(options: [String], answer: Int)
        case number(answer: Int)
        case memory(MemoryBoard)
    }

    let day: ChallengeDay
    let kind: ChallengeKind
    let prompt: String
    let body: Body
    /// Text hint (numeric answers). Multiple choice uses 50/50 and memory shows the pattern again.
    let hint: String
    let explanation: String

    var id: String { "\(day.number)-\(kind.rawValue)" }
    var level: Level { day.level }

    var answerText: String {
        switch body {
        case .choice(let options, let answer): options[answer]
        case .number(let answer): "\(answer)"
        case .memory(let board): board.ordered ? "Las \(board.targets.count) casillas en orden" : "Las \(board.targets.count) casillas"
        }
    }

    var hintLabel: String {
        switch body {
        case .choice: "50 / 50"
        case .number: "Pista"
        case .memory: "Ver otra vez"
        }
    }

    /// Two wrong options removed by the 50/50 hint (always the same ones for a given challenge).
    var fiftyFiftyRemoved: Set<Int> {
        guard case .choice(let options, let answer) = body else { return [] }
        var random = SeededRandom(seed: day.seed ^ 0x5050)
        let wrong = random.shuffled(options.indices.filter { $0 != answer })
        return Set(wrong.prefix(2))
    }
}

/// Result of one challenge, as a 0…1 fraction (memory can be partly right).
enum Outcome: String, Codable, Sendable {
    case perfect, assisted, wrong

    var emoji: String {
        switch self {
        case .perfect: "🟩"
        case .assisted: "🟨"
        case .wrong: "🟥"
        }
    }
}

enum Scoring {
    static let base = 100.0
    static let maxTimeBonus = 50.0
    static let hintCost = 30.0

    /// Seconds within which the full time bonus is earned; it fades to nothing at `slowSeconds`.
    static let fastSeconds = 10.0
    static let slowSeconds = 90.0

    static func timeBonus(seconds: Double) -> Double {
        if seconds <= fastSeconds { return maxTimeBonus }
        if seconds >= slowSeconds { return 0 }
        return maxTimeBonus * (slowSeconds - seconds) / (slowSeconds - fastSeconds)
    }

    static func points(fraction: Double, seconds: Double, usedHint: Bool, level: Level) -> Int {
        let fraction = min(max(fraction, 0), 1)
        guard fraction > 0 else { return 0 }
        var raw = base * fraction
        if fraction >= 1 { raw += timeBonus(seconds: seconds) }
        if usedHint { raw -= hintCost }
        return max(0, Int((raw * level.multiplier).rounded()))
    }

    static func outcome(fraction: Double, usedHint: Bool) -> Outcome {
        if fraction >= 1 { return usedHint ? .assisted : .perfect }
        return fraction >= 0.5 ? .assisted : .wrong
    }

    /// Best possible score for a day (five perfect, instant answers).
    static func maxPoints(level: Level) -> Int {
        Int(((base + maxTimeBonus) * level.multiplier).rounded()) * ChallengeKind.allCases.count
    }
}
