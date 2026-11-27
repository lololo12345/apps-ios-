import Foundation
import Testing
@testable import Bastion

@Suite("Mundo")
struct WorldTests {
    private func reachable(bridges: Set<Int>) -> Set<Tile> {
        var seen: Set<Tile> = [WorldMap.campfire]
        var queue = [WorldMap.campfire]
        while let tile = queue.popLast() {
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let next = Tile(col: tile.col + dc, row: tile.row + dr)
                if !seen.contains(next), WorldMap.isWalkable(col: Double(next.col), row: Double(next.row), builtBridges: bridges) {
                    seen.insert(next)
                    queue.append(next)
                }
            }
        }
        return seen
    }

    @Test func theRiverClosesTheForestUntilTheBridgeIsBuilt() {
        let before = reachable(bridges: [])
        #expect(!before.contains { WorldMap.zone(col: Double($0.col), row: Double($0.row)) == .oldForest })
        let after = reachable(bridges: [0])
        #expect(after.contains(WorldMap.bossLair))
        #expect(!after.contains { WorldMap.zone(col: Double($0.col), row: Double($0.row)) == .quarry })
    }

    @Test func nodesAreSpreadAndNeverOnWaterOrBase() {
        #expect(WorldMap.nodes.count > 120)
        for node in WorldMap.nodes {
            #expect(WorldMap.terrain(Tile(col: Int(node.x.rounded()), row: Int(node.y.rounded()))) == .grass)
        }
        #expect(WorldMap.nodes.contains { $0.kind == .goldenTree })
        #expect(WorldMap.nodes.filter { $0.zone == .clearing }.count >= 40)
    }
}

@Suite("Economía")
struct EconomyTests {
    @Test func craftingAlwaysPaysMoreThanSellingRaw() {
        for recipe in Recipe.all {
            #expect(recipe.profit > 0, "\(recipe.output)")
        }
    }

    @Test func marketIsTheSameForEveryoneOnADayAndChangesNextDay() {
        #expect(Market.price(.wood, day: 100) == Market.price(.wood, day: 100))
        let week = (100..<107).map { Market.starItem(day: $0) }
        #expect(Set(week).count > 1)
        for item in Item.allCases { #expect(Market.price(item, day: 5) >= 1) }
    }

    @Test func backpackFillsUpAndUnloadsAtTheBase() {
        var game = GameState()
        let result1 = game.pick(.wood, 15)
        #expect(result1 == 15)
        let result2 = game.pick(.stone, 15)
        #expect(result2 == 5)
        #expect(game.isFull)
        game.unload()
        #expect(game.carried == 0)
        #expect(game.storage[.wood] == 15 && game.storage[.stone] == 5)
        let earned = game.sell(.wood, 10, day: 1)
        #expect(earned == Market.price(.wood, day: 1) * 10)
        #expect(game.coins == earned && game.counters.coinsEarned == earned)
    }

    @Test func upgradesNeedCoinsAndMaterials() {
        var game = GameState()
        let result3 = game.upgrade(.backpack)
        #expect(!result3)
        game.coins = 100
        game.storage[.berries] = 10
        let result4 = game.upgrade(.backpack)
        #expect(result4)
        #expect(game.level(.backpack) == 2 && game.capacity == 35)
        #expect(game.coins == 100 - Gear.backpack.cost(from: 1)!.coins)
    }

    @Test func craftingQueuesAndFinishesLater() {
        var game = GameState()
        let now = Date(timeIntervalSince1970: 1_000_000)
        game.coins = 500
        game.storage = [.wood: 40]
        let result5 = game.build(.sawmill, now: now)
        #expect(result5)
        let recipe = Recipe.making(.planks)!
        #expect(game.maxCraftable(recipe) == 12)
        let result6 = game.craft(recipe, count: 5, now: now)
        #expect(result6)
        let result7 = game.collectJobs(now: now.addingTimeInterval(5))
        #expect(result7.isEmpty)
        let done = game.collectJobs(now: now.addingTimeInterval(21))
        #expect(done.count == 1 && game.storage[.planks] == 5 && game.counters.crafted[.planks] == 5)
    }

    @Test func gardenGrowsWhileClosedUpToItsCap() {
        var game = GameState()
        let now = Date(timeIntervalSince1970: 2_000_000)
        game.coins = 500
        game.storage = [.wood: 20, .berries: 20]
        let result8 = game.build(.garden, now: now)
        #expect(result8)
        game.settleGarden(now: now.addingTimeInterval(3600))
        #expect(game.gardenStock == Stats.gardenPerHour(level: 1))
        game.settleGarden(now: now.addingTimeInterval(3600 * 24))
        #expect(game.gardenStock == Stats.gardenCap(level: 1))
        let result9 = game.harvestGarden(now: now.addingTimeInterval(3600 * 24))
        #expect(result9 == Stats.gardenCap(level: 1))
    }

    @Test func bridgeIsPaidBitByBit() {
        var game = GameState()
        let site = WorldMap.bridges[0]
        game.storage = [.wood: 10]
        game.coins = 50
        let result10 = game.contribute(toBridge: 0)
        #expect(!result10)
        #expect(game.bridgeFraction(0) > 0 && game.bridgeFraction(0) < 1)
        game.storage = site.cost.items
        game.coins = site.cost.coins
        let result11 = game.contribute(toBridge: 0)
        #expect(result11)
        #expect(game.forestOpen)
        // The second bridge waits for the boss.
        game.coins = 10_000
        game.storage = [.planks: 100, .brick: 100]
        let result12 = game.contribute(toBridge: 1)
        #expect(!result12)
    }
}

@Suite("Aventura")
struct AdventureTests {
    @Test func questsAdvanceInOrderAndPay() {
        var game = GameState()
        game.pick(.wood, 12)
        let done = game.advanceQuests()
        #expect(done.map(\.id) == [0])
        #expect(game.coins == Quests.all[0].reward)
        #expect(game.currentQuest?.id == 1)
    }

    @Test func nightsRewardOrStealFromTheStore() {
        var game = GameState()
        game.storage = [.wood: 50]
        let result13 = game.nightEnded(campfireStanding: true)
        #expect(result13 == RaidPlan(night: 1).reward)
        #expect(game.counters.nightsSurvived == 1)
        let result14 = game.nightEnded(campfireStanding: false)
        #expect(result14 == 0)
        #expect(game.storage[.wood] == 40)
        #expect(RaidPlan(night: 1).wolves == 0 && RaidPlan(night: 5).wolves == 3)
    }

    @Test func knockoutLosesHalfTheBackpack() {
        var game = GameState()
        game.pick(.berries, 9)
        game.health = 3
        game.knockedOut()
        #expect(game.backpack[.berries] == 4 && game.health == game.maxHealth)
    }

    @Test func requestsAndDailyReward() {
        let today = Request.daily(day: 400, forestOpen: false)
        #expect(today.count == 3 && Set(today.map(\.item)).count == 3)
        #expect(!today.contains { $0.item == .mushroom || $0.item == .stew })
        var game = GameState()
        let request = today[0]
        game.storage[request.item] = request.amount
        let result15 = game.fulfil(request)
        #expect(result15)
        let result16 = game.fulfil(request)
        #expect(!result16)
        #expect(game.coins == request.reward)
        let result17 = game.claimDailyReward(day: 10)
        #expect(result17 == DailyReward.coins(streak: 1))
        let result18 = game.claimDailyReward(day: 10)
        #expect(result18 == nil)
        let result19 = game.claimDailyReward(day: 11)
        #expect(result19 == DailyReward.coins(streak: 2))
        let result20 = game.claimDailyReward(day: 13)
        #expect(result20 == DailyReward.coins(streak: 1))
    }

    @Test func dayAndNight() {
        #expect(!DayCycle.isNight(clock: 10))
        #expect(DayCycle.isNight(clock: DayCycle.dayLength + 1))
        #expect(DayCycle.darkness(clock: 10) == 0)
        #expect(DayCycle.darkness(clock: DayCycle.dayLength + 30) > 0.5)
    }

    @Test func saveRoundTrip() throws {
        var game = GameState()
        game.coins = 77
        game.pick(.mushroom, 3)
        game.bridges = [0]
        let copy = try #require(GameState.decoded(game.encoded()))
        #expect(copy == game)
    }
}
