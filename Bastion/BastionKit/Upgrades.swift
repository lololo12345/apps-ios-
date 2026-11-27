import Foundation

/// What the Brote carries: better tools, bigger pack, faster feet.
enum Gear: String, CaseIterable, Codable, Sendable, Identifiable {
    case axe, backpack, boots, sword, armor

    var id: String { rawValue }

    var name: String {
        switch self {
        case .axe: "Hacha"
        case .backpack: "Mochila"
        case .boots: "Botas"
        case .sword: "Espada"
        case .armor: "Armadura"
        }
    }

    var symbol: String {
        switch self {
        case .axe: "hammer.fill"
        case .backpack: "backpack.fill"
        case .boots: "shoeprints.fill"
        case .sword: "bolt.fill"
        case .armor: "shield.lefthalf.filled"
        }
    }

    /// Levels are 1…maxLevel; level 1 is what you start with.
    var maxLevel: Int { 6 }

    /// Cost to go from `level` to `level + 1`.
    func cost(from level: Int) -> Cost? {
        guard level < maxLevel else { return nil }
        let step = level - 1
        let coins = [30, 80, 180, 360, 650][step]
        switch self {
        case .axe: return Cost(coins: coins, items: [.wood: 8 + step * 10])
        case .backpack: return Cost(coins: Int(Double(coins) * 0.8), items: [.berries: 6 + step * 8])
        case .boots: return Cost(coins: coins, items: [.stone: 4 + step * 6])
        case .sword: return Cost(coins: Int(Double(coins) * 1.2), items: step >= 2 ? [.brick: step * 3] : [.stone: 8 + step * 6])
        case .armor: return Cost(coins: Int(Double(coins) * 1.1), items: step >= 2 ? [.planks: step * 4] : [.wood: 10 + step * 8])
        }
    }

    /// What one level gives, in words.
    func effect(at level: Int) -> String {
        switch self {
        case .axe: "Recoge cada \(String(format: "%.2f", Stats.gatherInterval(axe: level))) s"
        case .backpack: "Caben \(Stats.capacity(backpack: level)) cosas"
        case .boots: "Velocidad \(Int(Stats.speed(boots: level)))"
        case .sword: "Daño \(Stats.damage(sword: level))"
        case .armor: "Vida \(Stats.maxHealth(armor: level))"
        }
    }
}

/// Buildings of the base camp.
enum Building: String, CaseIterable, Codable, Sendable, Identifiable {
    case sawmill, kitchen, masonry, garden, tower, palisade

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sawmill: "Aserradero"
        case .kitchen: "Cocina"
        case .masonry: "Cantería"
        case .garden: "Huerto"
        case .tower: "Torre de arqueros"
        case .palisade: "Empalizada"
        }
    }

    var symbol: String {
        switch self {
        case .sawmill: "square.split.diagonal.2x2.fill"
        case .kitchen: "flame.fill"
        case .masonry: "square.stack.3d.up.fill"
        case .garden: "leaf.fill"
        case .tower: "scope"
        case .palisade: "shield.checkered"
        }
    }

    var summary: String {
        switch self {
        case .sawmill: "Convierte madera en tablas, que valen más."
        case .kitchen: "Tartas de bayas y guisos del bosque."
        case .masonry: "Convierte piedra en ladrillos."
        case .garden: "Da bayas solo, también con el juego cerrado."
        case .tower: "Dispara a la Niebla en los asaltos nocturnos."
        case .palisade: "Más vida para la hoguera de la base."
        }
    }

    /// Level 0 = not built.
    var maxLevel: Int { self == .tower ? 4 : 5 }

    func cost(from level: Int) -> Cost? {
        guard level < maxLevel else { return nil }
        let scale = [1.0, 2.2, 4.5, 8.0, 14.0][level]
        func c(_ coins: Int, _ items: [Item: Int]) -> Cost {
            Cost(coins: Int(Double(coins) * scale), items: items.mapValues { Int((Double($0) * scale).rounded()) })
        }
        switch self {
        case .sawmill: return c(60, [.wood: 15])
        case .kitchen: return c(90, [.wood: 12, .stone: 6])
        case .masonry: return c(120, [.wood: 10, .stone: 15])
        case .garden: return c(70, [.wood: 10, .berries: 10])
        case .tower: return c(150, level >= 2 ? [.planks: 10, .brick: 6] : [.wood: 25, .stone: 12])
        case .palisade: return c(80, level >= 2 ? [.planks: 12] : [.wood: 30])
        }
    }

    func effect(at level: Int) -> String {
        switch self {
        case .sawmill, .kitchen, .masonry:
            level == 0 ? "Sin construir" : "Fabrica ×\(String(format: "%.1f", Stats.craftSpeed(station: level))) de rápido"
        case .garden: level == 0 ? "Sin construir" : "\(Stats.gardenPerHour(level: level)) bayas por hora"
        case .tower: level == 0 ? "Sin construir" : "\(level) torre\(level == 1 ? "" : "s"), daño \(Stats.towerDamage(level: level))"
        case .palisade: "Hoguera con \(Stats.campfireHealth(palisade: level)) de vida"
        }
    }
}

struct Cost: Equatable, Sendable {
    var coins: Int
    var items: [Item: Int]
}

/// Numbers derived from levels. One place, so the HUD, the world and the tests agree.
enum Stats {
    static func gatherInterval(axe: Int) -> Double { max(0.3, 0.95 - Double(axe - 1) * 0.12) }
    static func capacity(backpack: Int) -> Int { [20, 35, 55, 80, 110, 150][min(max(backpack, 1), 6) - 1] }
    static func speed(boots: Int) -> Double { 150 + Double(boots - 1) * 22 }
    static func damage(sword: Int) -> Int { [6, 10, 15, 22, 31, 42][min(max(sword, 1), 6) - 1] }
    static func maxHealth(armor: Int) -> Int { [60, 85, 120, 165, 220, 290][min(max(armor, 1), 6) - 1] }
    static func craftSpeed(station: Int) -> Double { 1 + Double(max(station - 1, 0)) * 0.5 }
    static func gardenPerHour(level: Int) -> Int { level * 30 }
    static func gardenCap(level: Int) -> Int { level * 40 }
    static func towerDamage(level: Int) -> Int { level == 0 ? 0 : 7 + level * 4 }
    static func campfireHealth(palisade: Int) -> Int { 120 + palisade * 80 }
}
