import Foundation

/// Reproducible randomness: the same seed gives the same map, prices and requests on every iPhone.
struct SplitMix: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Everything the Brote can carry, sell or craft.
enum Item: String, CaseIterable, Codable, Sendable, Identifiable {
    // Gathered in the world.
    case wood, berries, stone, mushroom, goldenLog
    // Crafted at the base.
    case planks, pie, brick, stew

    var id: String { rawValue }

    var name: String {
        switch self {
        case .wood: "Madera"
        case .berries: "Bayas"
        case .stone: "Piedra"
        case .mushroom: "Setas"
        case .goldenLog: "Tronco dorado"
        case .planks: "Tablas"
        case .pie: "Tarta de bayas"
        case .brick: "Ladrillos"
        case .stew: "Guiso del bosque"
        }
    }

    var emoji: String {
        switch self {
        case .wood: "🪵"
        case .berries: "🫐"
        case .stone: "🪨"
        case .mushroom: "🍄"
        case .goldenLog: "✨"
        case .planks: "🪚"
        case .pie: "🥧"
        case .brick: "🧱"
        case .stew: "🍲"
        }
    }

    /// Price before the daily market swing.
    var basePrice: Int {
        switch self {
        case .wood: 2
        case .berries: 3
        case .stone: 4
        case .mushroom: 7
        case .goldenLog: 45
        case .planks: 7
        case .pie: 13
        case .brick: 11
        case .stew: 30
        }
    }

    var isCrafted: Bool { Recipe.all.contains { $0.output == self } }
}

/// Turns raw resources into goods worth more than their parts.
struct Recipe: Sendable, Identifiable, Equatable {
    let output: Item
    let inputs: [Item: Int]
    /// Seconds for one unit at station level 1.
    let seconds: Double
    let station: Building

    var id: String { output.rawValue }

    static let all: [Recipe] = [
        Recipe(output: .planks, inputs: [.wood: 2], seconds: 4, station: .sawmill),
        Recipe(output: .pie, inputs: [.berries: 3], seconds: 6, station: .kitchen),
        Recipe(output: .brick, inputs: [.stone: 2], seconds: 6, station: .masonry),
        Recipe(output: .stew, inputs: [.mushroom: 2, .berries: 2], seconds: 10, station: .kitchen),
    ]

    static func making(_ item: Item) -> Recipe? { all.first { $0.output == item } }

    /// Selling the result must always beat selling the ingredients: crafting is worth the wait.
    var profit: Int { output.basePrice - inputs.reduce(0) { $0 + $1.key.basePrice * $1.value } }
}

/// The market changes a little every day; one "estrella" item pays much more.
enum Market {
    static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        return Int((start.timeIntervalSince1970 / 86_400).rounded())
    }

    /// Multiplier per item for that day (0.8…1.25), and ×1.6 for the star item.
    static func multipliers(day: Int) -> [Item: Double] {
        var rng = SplitMix(seed: UInt64(bitPattern: Int64(day)) &* 31 &+ 7)
        var result: [Item: Double] = [:]
        for item in Item.allCases {
            result[item] = 0.8 + rng.unit() * 0.45
        }
        let star = starItem(day: day)
        result[star] = (result[star] ?? 1) * 1.6
        return result
    }

    static func starItem(day: Int) -> Item {
        var rng = SplitMix(seed: UInt64(bitPattern: Int64(day)) &* 131 &+ 3)
        let candidates: [Item] = [.wood, .berries, .stone, .mushroom, .planks, .pie, .brick, .stew]
        return candidates[Int(rng.next() % UInt64(candidates.count))]
    }

    static func price(_ item: Item, day: Int) -> Int {
        max(1, Int((Double(item.basePrice) * (multipliers(day: day)[item] ?? 1)).rounded()))
    }
}
