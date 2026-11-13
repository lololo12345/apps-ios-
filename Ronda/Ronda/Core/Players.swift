import Foundation

struct Player: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum PlayerRules {
    static let maxNameLength = 16
    static let maxPlayers = 16

    /// Trims, collapses inner whitespace and limits length. Returns nil for empty or duplicate names.
    static func sanitize(_ raw: String, existing: [Player]) -> String? {
        let collapsed = raw
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        let name = String(collapsed.prefix(maxNameLength))
        let taken = existing.contains { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        return taken ? nil : name
    }
}

/// Seat order around the table: who is on your left and right, whose turn is next.
struct TurnOrder: Sendable {
    let count: Int
    private(set) var current: Int = 0

    init(count: Int, start: Int = 0) {
        self.count = count
        current = count > 0 ? ((start % count) + count) % count : 0
    }

    mutating func advance() {
        guard count > 0 else { return }
        current = (current + 1) % count
    }

    func left(of index: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index + 1) % count
    }

    func right(of index: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index - 1 + count) % count
    }
}
