import Foundation

/// Deterministic generator (SplitMix64) so game logic can be tested with fixed seeds.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Draws items in random order without repeating any until all have been used, then reshuffles.
/// Avoids the classic party-game annoyance of seeing the same card twice in a night.
struct ShuffledDeck<Element> {
    private(set) var items: [Element]
    private var order: [Int] = []
    private(set) var drawnCount = 0

    init(_ items: [Element]) {
        self.items = items
    }

    var isEmpty: Bool { items.isEmpty }
    var remainingInCycle: Int { order.count }

    mutating func draw(using generator: inout some RandomNumberGenerator) -> Element? {
        guard !items.isEmpty else { return nil }
        if order.isEmpty {
            order = Array(items.indices).shuffled(using: &generator)
        }
        drawnCount += 1
        return items[order.removeLast()]
    }

    mutating func draw() -> Element? {
        var generator = SystemRandomNumberGenerator()
        return draw(using: &generator)
    }
}
