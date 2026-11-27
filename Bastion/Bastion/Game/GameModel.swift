import Foundation
import Observation
import SwiftUI

/// Panels that pause the world while open.
enum Panel: Identifiable, Equatable {
    case market, workshop, upgrades, board, bridge(Int), journal, settings

    var id: String {
        switch self {
        case .bridge(let id): "bridge\(id)"
        default: String(describing: self)
        }
    }
}

/// Where the Brote is standing, for the context buttons.
enum Place: Equatable {
    case base, bridge(Int)
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let symbol: String
    var tint: Color = Palette.accent
}

/// Big centred moment: mission done, bridge built, night survived…
struct Celebration: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    var tint: Color = Palette.accent
}

/// Things the HUD asks the world to do (the world reads and clears them every frame).
enum WorldCommand: Equatable {
    case buildingsChanged, bridgeBuilt(Int), respawn
}

/// The game for the UI: saved state + what the HUD shows. The SpriteKit world writes here only when
/// something happens (not every frame), so SwiftUI redraws stay rare and the world keeps 120 Hz.
@Observable
@MainActor
final class GameModel {
    var state: GameState
    var panel: Panel?
    var started = false
    var place: Place?
    var zone: Zone = .clearing
    var health: Int
    var isNight = false
    /// Seconds until sunset or dawn, rounded to whole seconds.
    var secondsToChange = 0
    var raid: (enemies: Int, campfire: Int, max: Int)?
    var boss: (health: Int, max: Int)?
    var heavyReady = true
    var toasts: [Toast] = []
    var celebration: Celebration?
    var hapticsTick = 0
    var hurtTick = 0
    var day: Int
    /// Bumped by a new game: the world is rebuilt from scratch.
    var generation = 0
    @ObservationIgnored var commands: [WorldCommand] = []
    /// Joystick, -1…1 on both axes. Read by the world every frame, so not observed.
    @ObservationIgnored var stick = CGVector.zero
    @ObservationIgnored var heavyRequested = false
    @ObservationIgnored let spawn: CGPoint?

    private let defaults: UserDefaults
    private static let key = "bastion.save.v1"

    init(defaults: UserDefaults = LaunchOptions.defaults, now: Date = .now) {
        self.defaults = defaults
        day = Market.dayNumber(now)
        var loaded = defaults.data(forKey: Self.key).flatMap(GameState.decoded) ?? GameState()
        let seeded = Self.seed(LaunchOptions.value(after: "-seed"), into: &loaded)
        spawn = seeded
        loaded.catchUp(now: now)
        state = loaded
        health = loaded.health
        started = LaunchOptions.arguments.contains("-skipTitle")
    }

    // MARK: Test worlds (-seed name). Never used in a normal launch.

    private static func seed(_ name: String?, into game: inout GameState) -> CGPoint? {
        guard let name else { return nil }
        game.tutorialDone = true
        let rich: (inout GameState) -> Void = { g in
            g.coins = 2400
            g.storage = [.wood: 120, .berries: 70, .stone: 60, .mushroom: 18, .planks: 14, .brick: 6, .goldenLog: 2]
            g.buildings = [.sawmill: 1, .garden: 1, .tower: 1]
            g.counters.gathered = [.wood: 140, .berries: 80, .stone: 60]
            g.counters.coinsEarned = 300
            g.questIndex = 4
            g.gardenStock = 24
        }
        func at(_ col: Double, _ row: Double) -> CGPoint {
            CGPoint(x: (col + 0.5) * WorldMap.tileSize, y: (row + 0.5) * WorldMap.tileSize)
        }
        switch name {
        case "rich":
            rich(&game)
            return nil
        case "field":
            game.backpack = [.wood: 9, .berries: 4]
            game.counters.gathered = [.wood: 9, .berries: 4]
            return at(14, 17)
        case "bridge":
            rich(&game)
            return at(19, 14.5)
        case "forest":
            rich(&game)
            game.bridges = [0]
            game.gear[.sword] = 3
            game.gear[.armor] = 3
            game.questIndex = 8
            return at(31, 16)
        case "night":
            rich(&game)
            game.buildings[.tower] = 2
            game.buildings[.palisade] = 1
            game.clock = DayCycle.dayLength - 3
            return at(10, 14)
        case "boss":
            rich(&game)
            game.bridges = [0]
            game.gear = [.axe: 3, .backpack: 3, .boots: 3, .sword: 5, .armor: 5]
            game.health = Stats.maxHealth(armor: 5)
            game.questIndex = 13
            return at(Double(WorldMap.bossLair.col) - 5, Double(WorldMap.bossLair.row))
        default:
            return nil
        }
    }

    // MARK: Saving

    func save() {
        guard !LaunchOptions.isUITesting else { return }
        state.lastSeen = .now
        defaults.set(state.encoded(), forKey: Self.key)
    }

    // MARK: Feedback

    func toast(_ text: String, _ symbol: String, tint: Color = Palette.accent) {
        let item = Toast(text: text, symbol: symbol, tint: tint)
        withAnimation(.snappy) {
            toasts.append(item)
            if toasts.count > 3 { toasts.removeFirst() }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.smooth) { self?.toasts.removeAll { $0.id == item.id } }
        }
    }

    func celebrate(_ title: String, _ detail: String, _ symbol: String, tint: Color = Palette.accent) {
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { celebration = Celebration(title: title, detail: detail, symbol: symbol, tint: tint) }
    }

    /// After anything that changes progress: pay missions, unlock achievements, save.
    func progressChanged() {
        for quest in state.advanceQuests() {
            celebrate("¡Misión cumplida!", "\(quest.title) · +\(quest.reward) 🪙", "flag.checkered")
        }
        for medal in state.checkAchievements() {
            toast("Logro: \(medal.title)", medal.symbol, tint: Palette.gold)
        }
        save()
    }

    func resetGame() {
        state = GameState()
        state.tutorialDone = true
        health = state.maxHealth
        boss = nil
        raid = nil
        panel = nil
        generation += 1
        save()
    }

    // MARK: Actions from the HUD

    func sell(_ item: Item, all: Bool) {
        let n = all ? state.storage[item, default: 0] : min(10, state.storage[item, default: 0])
        let earned = state.sell(item, n, day: day)
        if earned > 0 { hapticsTick += 1 }
        progressChanged()
    }

    func upgrade(_ gear: Gear) {
        guard state.upgrade(gear) else { return }
        if gear == .armor { health = state.maxHealth }
        toast("\(gear.name) nivel \(state.level(gear))", gear.symbol)
        hapticsTick += 1
        progressChanged()
    }

    func build(_ building: Building) {
        guard state.build(building) else { return }
        commands.append(.buildingsChanged)
        toast(state.level(building) == 1 ? "\(building.name) construido" : "\(building.name) nivel \(state.level(building))", building.symbol)
        hapticsTick += 1
        progressChanged()
    }

    func craft(_ recipe: Recipe, count: Int) {
        guard state.craft(recipe, count: count) else { return }
        toast("Fabricando \(count) \(recipe.output.name.lowercased())", recipe.station.symbol)
        save()
    }

    func harvestGarden() {
        let n = state.harvestGarden()
        if n > 0 { toast("+\(n) bayas del huerto", "leaf.fill") }
        progressChanged()
    }

    func contribute(toBridge id: Int) {
        let done = state.contribute(toBridge: id)
        if done {
            panel = nil
            commands.append(.bridgeBuilt(id))
            celebrate("¡Puente construido!", "El \(WorldMap.bridges[id].opens.name) te espera al otro lado.", "road.lanes", tint: Palette.gold)
        }
        hapticsTick += 1
        progressChanged()
    }

    func fulfil(_ request: Request) {
        guard state.fulfil(request) else { return }
        toast("\(request.neighbour) te paga \(request.reward) 🪙", "hands.sparkles.fill", tint: Palette.gold)
        progressChanged()
    }

    func claimDailyReward() {
        guard let coins = state.claimDailyReward(day: day) else { return }
        celebrate("Regalo del día", "Racha de \(state.rewardStreak) día\(state.rewardStreak == 1 ? "" : "s") · +\(coins) 🪙", "gift.fill", tint: Palette.gold)
        save()
    }

    var dailyRewardAvailable: Bool { state.lastRewardDay != day }
    var requests: [Request] { Request.daily(day: day, forestOpen: state.forestOpen) }
}
