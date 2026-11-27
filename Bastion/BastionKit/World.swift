import Foundation

/// A tile on the map grid (column, row). Row 0 is the bottom edge (SpriteKit's y grows upwards).
struct Tile: Hashable, Codable, Sendable {
    var col: Int
    var row: Int
}

enum Zone: Int, CaseIterable, Codable, Sendable {
    case clearing, oldForest, quarry

    var name: String {
        switch self {
        case .clearing: "El Claro"
        case .oldForest: "Bosque Viejo"
        case .quarry: "La Cantera"
        }
    }

    /// Zones still hidden in mist (next update).
    var comingSoon: Bool { self == .quarry }
}

enum Terrain: Sendable, Equatable {
    case grass, water, bank, bridge(Int), base
}

/// What can be gathered on the map.
enum NodeKind: String, CaseIterable, Codable, Sendable {
    case tree, goldenTree, bush, rock, mushroom

    /// Hits until it is depleted (one item per hit).
    var hits: Int {
        switch self {
        case .tree: 4
        case .goldenTree: 6
        case .bush: 3
        case .rock: 5
        case .mushroom: 2
        }
    }

    var item: Item {
        switch self {
        case .tree, .goldenTree: .wood
        case .bush: .berries
        case .rock: .stone
        case .mushroom: .mushroom
        }
    }

    /// Seconds until it grows back.
    var respawn: Double {
        switch self {
        case .tree: 45
        case .goldenTree: 420
        case .bush: 35
        case .rock: 60
        case .mushroom: 50
        }
    }

    /// The last hit on a golden tree also drops golden logs.
    var bonus: (item: Item, count: Int)? { self == .goldenTree ? (.goldenLog, 2) : nil }
}

struct ResourceNode: Identifiable, Sendable, Equatable {
    let id: Int
    let kind: NodeKind
    /// Position in tile units (with a little jitter so the forest does not look like a grid).
    let x: Double
    let y: Double
    let zone: Zone
}

/// A river crossing that has to be built.
struct BridgeSite: Identifiable, Sendable, Equatable {
    let id: Int
    let rows: ClosedRange<Int>
    let cols: ClosedRange<Int>
    let cost: Cost
    /// Zone that opens on the far side.
    let opens: Zone
    /// Needs the boss of the previous zone defeated first.
    let needsBoss: Bool
}

/// The fixed map: three zones from left to right, split by two winding rivers.
struct WorldMap: Sendable {
    static let columns = 64
    static let rows = 30
    static let tileSize = 56.0
    static let seed: UInt64 = 0xB4_57_10_00

    /// Centre of the campfire, heart of the base.
    static let campfire = Tile(col: 8, row: 15)
    static let baseRadius = 4.6

    static let bridges: [BridgeSite] = [
        BridgeSite(id: 0, rows: 14...15, cols: riverColumns(river: 0, row: 14), cost: Cost(coins: 160, items: [.wood: 40, .stone: 15]),
                   opens: .oldForest, needsBoss: false),
        BridgeSite(id: 1, rows: 9...10, cols: riverColumns(river: 1, row: 9), cost: Cost(coins: 900, items: [.planks: 40, .brick: 25]),
                   opens: .quarry, needsBoss: true),
    ]

    /// Where the boss of the Old Forest waits, guarding the second bridge.
    static let bossLair = Tile(col: 42, row: 9)

    static func riverCenter(river: Int, row: Int) -> Int {
        let base = river == 0 ? 22 : 46
        // Straight around the bridges so the crossing looks built for the spot.
        let bridgeRows = river == 0 ? 13...16 : 8...11
        if bridgeRows.contains(row) { return base }
        return base + Int((sin(Double(row) * 0.42 + Double(river)) * 1.4).rounded())
    }

    static func riverColumns(river: Int, row: Int) -> ClosedRange<Int> {
        let c = riverCenter(river: river, row: row)
        return (c - 1)...c
    }

    static func terrain(_ tile: Tile) -> Terrain {
        for river in 0..<2 {
            let cols = riverColumns(river: river, row: tile.row)
            if cols.contains(tile.col) {
                if let bridge = bridges.first(where: { $0.id == river && $0.rows.contains(tile.row) }) {
                    return .bridge(bridge.id)
                }
                return .water
            }
            if tile.col == cols.lowerBound - 1 || tile.col == cols.upperBound + 1 { return .bank }
        }
        let dx = Double(tile.col - campfire.col), dy = Double(tile.row - campfire.row)
        if (dx * dx + dy * dy).squareRoot() <= baseRadius { return .base }
        return .grass
    }

    static func zone(col: Double, row: Double) -> Zone {
        let r = Int(row.rounded())
        if col < Double(riverCenter(river: 0, row: r)) - 0.5 { return .clearing }
        if col < Double(riverCenter(river: 1, row: r)) - 0.5 { return .oldForest }
        return .quarry
    }

    /// Water blocks walking unless a bridge has been built; map edges block too.
    static func isWalkable(col: Double, row: Double, builtBridges: Set<Int>) -> Bool {
        guard col >= 0.2, row >= 0.2, col <= Double(columns) - 1.2, row <= Double(rows) - 1.2 else { return false }
        let tile = Tile(col: Int(col.rounded()), row: Int(row.rounded()))
        switch terrain(tile) {
        case .water: return false
        case .bridge(let id): return builtBridges.contains(id)
        default: return true
        }
    }

    /// Every resource node, always the same (seeded). Nothing grows on the base, the river or a bridge approach.
    static let nodes: [ResourceNode] = {
        var rng = SplitMix(seed: seed)
        var placed: [ResourceNode] = []
        let plan: [(Zone, NodeKind, Int)] = [
            (.clearing, .tree, 26), (.clearing, .bush, 14), (.clearing, .rock, 9),
            (.oldForest, .tree, 30), (.oldForest, .goldenTree, 3), (.oldForest, .bush, 10),
            (.oldForest, .rock, 12), (.oldForest, .mushroom, 16),
            (.quarry, .rock, 14), (.quarry, .tree, 8),
        ]
        for (zone, kind, count) in plan {
            var made = 0, attempts = 0
            while made < count, attempts < 4000 {
                attempts += 1
                let x = 1.0 + rng.unit() * Double(columns - 3)
                let y = 1.0 + rng.unit() * Double(rows - 3)
                guard WorldMap.zone(col: x, row: y) == zone else { continue }
                let tile = Tile(col: Int(x.rounded()), row: Int(y.rounded()))
                guard terrain(tile) == .grass else { continue }
                // Keep the paths to the bridges and the boss arena clear.
                if bridges.contains(where: { abs(Double($0.rows.lowerBound) + 0.5 - y) < 2.2 && abs(Double($0.cols.lowerBound) - x) < 5 }) { continue }
                if hypot(x - Double(bossLair.col), y - Double(bossLair.row)) < 3.5 { continue }
                if placed.contains(where: { hypot($0.x - x, $0.y - y) < 1.35 }) { continue }
                placed.append(ResourceNode(id: placed.count, kind: kind, x: x, y: y, zone: zone))
                made += 1
            }
        }
        return placed
    }()
}
