import Foundation

/// Creatures of the Mist.
enum EnemyKind: String, CaseIterable, Codable, Sendable {
    case slime, wolf, boss

    var name: String {
        switch self {
        case .slime: "Babosa de Niebla"
        case .wolf: "Lobo de Humo"
        case .boss: "Gran Lobo de Humo"
        }
    }

    var health: Int {
        switch self {
        case .slime: 18
        case .wolf: 46
        case .boss: 520
        }
    }

    var damage: Int {
        switch self {
        case .slime: 4
        case .wolf: 9
        case .boss: 18
        }
    }

    /// Points per second.
    var speed: Double {
        switch self {
        case .slime: 58
        case .wolf: 118
        case .boss: 96
        }
    }

    /// Distance (points) from which it hits.
    var reach: Double { self == .boss ? 70 : 38 }
    var attackInterval: Double { self == .boss ? 1.3 : 1.0 }
    /// How far away it notices the Brote.
    var sight: Double { self == .boss ? 330 : 240 }

    var coins: Int {
        switch self {
        case .slime: 3
        case .wolf: 8
        case .boss: 260
        }
    }
}

/// Player combat numbers.
enum Combat {
    static let attackRange = 78.0
    static let attackInterval = 0.55
    static let critChance = 0.15
    static let heavyCooldown = 4.0
    static let heavyRadius = 96.0
    static let heavyMultiplier = 3

    /// Damage of one auto-attack; `roll` in 0…1 decides the critical hit.
    static func hit(sword: Int, roll: Double) -> (damage: Int, critical: Bool) {
        let base = Stats.damage(sword: sword)
        return roll < critChance ? (base * 2, true) : (base, false)
    }

    /// Losing a fight: back to the campfire with half the backpack.
    static func penalty(_ backpack: [Item: Int]) -> [Item: Int] {
        backpack.mapValues { $0 / 2 }
    }
}

/// Day and night. Each night the Mist raids the base.
enum DayCycle {
    static let dayLength = 150.0
    static let nightLength = 70.0
    static var length: Double { dayLength + nightLength }

    /// 0…1 through the full cycle, night when ≥ day fraction.
    static func isNight(clock: Double) -> Bool { clock.truncatingRemainder(dividingBy: length) >= dayLength }

    /// Seconds until the next change (sunset or dawn).
    static func secondsToChange(clock: Double) -> Double {
        let t = clock.truncatingRemainder(dividingBy: length)
        return t < dayLength ? dayLength - t : length - t
    }

    /// How dark the world is (0 midday … 0.62 deep night), smoothed at dusk and dawn.
    static func darkness(clock: Double) -> Double {
        let t = clock.truncatingRemainder(dividingBy: length)
        let fade = 12.0
        if t < dayLength - fade { return 0 }
        if t < dayLength { return (t - (dayLength - fade)) / fade * 0.62 }
        if t > length - fade { return (length - t) / fade * 0.62 }
        return 0.62
    }
}

/// Who attacks the base on night `n` (1-based).
struct RaidPlan: Equatable, Sendable {
    let night: Int
    let slimes: Int
    let wolves: Int

    init(night: Int) {
        self.night = night
        slimes = min(3 + night, 14)
        wolves = min(max(night - 2, 0), 7)
    }

    var total: Int { slimes + wolves }
    var reward: Int { 25 + night * 15 }
    /// Share of the stored goods the Mist steals if the campfire goes out.
    static let stolenShare = 0.2
}
