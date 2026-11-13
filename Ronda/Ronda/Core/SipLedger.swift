import Foundation

/// Running tally of sips (or points in alcohol-free mode) per player for the whole night.
struct SipLedger: Codable, Equatable, Sendable {
    private(set) var sips: [UUID: Int] = [:]
    private(set) var total: Int = 0

    mutating func add(_ amount: Int, to playerID: UUID) {
        guard amount > 0 else { return }
        sips[playerID, default: 0] += amount
        total += amount
    }

    mutating func add(_ amount: Int, to playerIDs: some Sequence<UUID>) {
        for id in Set(playerIDs) { add(amount, to: id) }
    }

    func count(for playerID: UUID) -> Int {
        sips[playerID, default: 0]
    }

    mutating func reset() {
        sips = [:]
        total = 0
    }

    struct Standing: Equatable, Sendable {
        let player: Player
        let sips: Int
        /// Competition ranking: ties share a position (1, 2, 2, 4).
        let position: Int
    }

    func standings(for players: [Player]) -> [Standing] {
        let sorted = players.enumerated().sorted { lhs, rhs in
            let l = count(for: lhs.element.id), r = count(for: rhs.element.id)
            return l != r ? l > r : lhs.offset < rhs.offset
        }
        var result: [Standing] = []
        for (index, entry) in sorted.enumerated() {
            let value = count(for: entry.element.id)
            let position = (index > 0 && result[index - 1].sips == value) ? result[index - 1].position : index + 1
            result.append(Standing(player: entry.element, sips: value, position: position))
        }
        return result
    }
}

/// Every N cards the game inserts a water break. 0 disables it.
struct WaterBreakSchedule: Sendable {
    let every: Int
    private(set) var cardsSinceBreak = 0

    init(every: Int) {
        self.every = every
    }

    /// Call once per card shown. Returns true when a water break should be shown now.
    mutating func registerCard() -> Bool {
        guard every > 0 else { return false }
        cardsSinceBreak += 1
        if cardsSinceBreak >= every {
            cardsSinceBreak = 0
            return true
        }
        return false
    }
}
