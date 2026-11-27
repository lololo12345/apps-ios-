import Foundation

/// A craft in progress at a station.
struct CraftJob: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let item: Item
    let count: Int
    let finish: Date
}

/// The whole saved game. Plain data + rules, no SwiftUI, so every rule is tested on Linux.
struct GameState: Codable, Equatable, Sendable {
    var coins = 0
    var backpack: [Item: Int] = [:]
    var storage: [Item: Int] = [:]
    var gear: [Gear: Int] = Dictionary(uniqueKeysWithValues: Gear.allCases.map { ($0, 1) })
    var buildings: [Building: Int] = [:]
    var bridges: Set<Int> = []
    /// Goods already handed in for each bridge under construction.
    var bridgeProgress: [Int: [Item: Int]] = [:]
    var bridgeCoins: [Int: Int] = [:]
    var counters = Counters()
    var questIndex = 0
    var achievements: Set<String> = []
    var jobs: [CraftJob] = []
    var gardenStock = 0
    var gardenUpdated = Date.distantPast
    var lastSeen = Date.distantPast
    var clock = 30.0
    var night = 0
    var health = 60
    var completedRequests: Set<Int> = []
    var lastRewardDay = -1
    var rewardStreak = 0
    var tutorialDone = false

    // MARK: Derived

    func level(_ g: Gear) -> Int { gear[g, default: 1] }
    func level(_ b: Building) -> Int { buildings[b, default: 0] }
    var capacity: Int { Stats.capacity(backpack: level(.backpack)) }
    var carried: Int { backpack.values.reduce(0, +) }
    var isFull: Bool { carried >= capacity }
    var maxHealth: Int { Stats.maxHealth(armor: level(.armor)) }
    var forestOpen: Bool { bridges.contains(0) }
    var currentQuest: Quest? { Quests.all.indices.contains(questIndex) ? Quests.all[questIndex] : nil }

    // MARK: Gathering

    /// Adds to the backpack as much as fits. Returns how many went in.
    @discardableResult
    mutating func pick(_ item: Item, _ amount: Int = 1) -> Int {
        let room = item == .goldenLog ? amount : max(0, capacity - carried)
        let taken = min(room, amount)
        guard taken > 0 else { return 0 }
        backpack[item, default: 0] += taken
        counters.gathered[item, default: 0] += taken
        return taken
    }

    /// Entering the base empties the backpack into the storehouse.
    @discardableResult
    mutating func unload() -> [Item: Int] {
        let moved = backpack.filter { $0.value > 0 }
        for (item, n) in moved { storage[item, default: 0] += n }
        backpack = [:]
        return moved
    }

    // MARK: Market

    @discardableResult
    mutating func sell(_ item: Item, _ amount: Int, day: Int) -> Int {
        let n = min(amount, storage[item, default: 0])
        guard n > 0 else { return 0 }
        storage[item, default: 0] -= n
        let earned = Market.price(item, day: day) * n
        coins += earned
        counters.coinsEarned += earned
        return earned
    }

    func canPay(_ cost: Cost) -> Bool {
        coins >= cost.coins && cost.items.allSatisfy { storage[$0.key, default: 0] >= $0.value }
    }

    private mutating func pay(_ cost: Cost) {
        coins -= cost.coins
        for (item, n) in cost.items { storage[item, default: 0] -= n }
    }

    // MARK: Upgrades

    @discardableResult
    mutating func upgrade(_ g: Gear) -> Bool {
        guard let cost = g.cost(from: level(g)), canPay(cost) else { return false }
        pay(cost)
        gear[g] = level(g) + 1
        if g == .armor { health = maxHealth }
        return true
    }

    @discardableResult
    mutating func build(_ b: Building, now: Date = .now) -> Bool {
        guard let cost = b.cost(from: level(b)), canPay(cost) else { return false }
        if b == .garden { settleGarden(now: now) }
        pay(cost)
        buildings[b] = level(b) + 1
        if b == .garden && gardenUpdated == .distantPast { gardenUpdated = now }
        return true
    }

    // MARK: Crafting

    func canCraft(_ recipe: Recipe, count: Int = 1) -> Bool {
        level(recipe.station) > 0 && recipe.inputs.allSatisfy { storage[$0.key, default: 0] >= $0.value * count }
    }

    /// Most units of a recipe the storehouse allows.
    func maxCraftable(_ recipe: Recipe) -> Int {
        guard level(recipe.station) > 0 else { return 0 }
        return recipe.inputs.map { storage[$0.key, default: 0] / $0.value }.min() ?? 0
    }

    @discardableResult
    mutating func craft(_ recipe: Recipe, count: Int, now: Date = .now) -> Bool {
        guard count > 0, canCraft(recipe, count: count) else { return false }
        for (item, n) in recipe.inputs { storage[item, default: 0] -= n * count }
        // Jobs at the same station queue one after another.
        let busyUntil = jobs.filter { Recipe.making($0.item)?.station == recipe.station }.map(\.finish).max() ?? now
        let start = max(now, busyUntil)
        let seconds = recipe.seconds * Double(count) / Stats.craftSpeed(station: level(recipe.station))
        jobs.append(CraftJob(id: UUID(), item: recipe.output, count: count, finish: start.addingTimeInterval(seconds)))
        return true
    }

    /// Moves finished crafts to the storehouse. Returns what finished.
    @discardableResult
    mutating func collectJobs(now: Date = .now) -> [CraftJob] {
        let done = jobs.filter { $0.finish <= now }
        jobs.removeAll { $0.finish <= now }
        for job in done {
            storage[job.item, default: 0] += job.count
            counters.crafted[job.item, default: 0] += job.count
        }
        return done
    }

    // MARK: Garden (grows also while the game is closed)

    mutating func settleGarden(now: Date = .now) {
        let lvl = level(.garden)
        guard lvl > 0, gardenUpdated != .distantPast else { gardenUpdated = now; return }
        let hours = max(0, now.timeIntervalSince(gardenUpdated)) / 3600
        let grown = Int(Double(Stats.gardenPerHour(level: lvl)) * hours)
        if grown > 0 {
            gardenStock = min(Stats.gardenCap(level: lvl), gardenStock + grown)
            gardenUpdated = gardenUpdated.addingTimeInterval(Double(grown) / Double(Stats.gardenPerHour(level: lvl)) * 3600)
        }
        if gardenStock >= Stats.gardenCap(level: lvl) { gardenUpdated = now }
    }

    @discardableResult
    mutating func harvestGarden(now: Date = .now) -> Int {
        settleGarden(now: now)
        let n = gardenStock
        storage[.berries, default: 0] += n
        counters.gathered[.berries, default: 0] += n
        gardenStock = 0
        return n
    }

    // MARK: Bridges

    /// Hands in whatever the storehouse can give towards the bridge. Returns true when it is finished.
    @discardableResult
    mutating func contribute(toBridge id: Int) -> Bool {
        guard let site = WorldMap.bridges.first(where: { $0.id == id }), !bridges.contains(id) else { return false }
        if site.needsBoss && !counters.bossesDefeated.contains(.boss) { return false }
        var progress = bridgeProgress[id, default: [:]]
        for (item, needed) in site.cost.items {
            let missing = needed - progress[item, default: 0]
            let given = min(missing, storage[item, default: 0])
            if given > 0 {
                storage[item, default: 0] -= given
                progress[item, default: 0] += given
            }
        }
        let coinsMissing = site.cost.coins - bridgeCoins[id, default: 0]
        let coinsGiven = min(coinsMissing, coins)
        coins -= coinsGiven
        bridgeCoins[id, default: 0] += coinsGiven
        bridgeProgress[id] = progress
        let done = bridgeCoins[id, default: 0] >= site.cost.coins
            && site.cost.items.allSatisfy { progress[$0.key, default: 0] >= $0.value }
        if done { bridges.insert(id) }
        return done
    }

    /// 0…1 of the bridge already paid.
    func bridgeFraction(_ id: Int) -> Double {
        guard let site = WorldMap.bridges.first(where: { $0.id == id }) else { return 0 }
        if bridges.contains(id) { return 1 }
        let total = Double(site.cost.coins + site.cost.items.values.reduce(0, +))
        let paid = Double(bridgeCoins[id, default: 0] + bridgeProgress[id, default: [:]].values.reduce(0, +))
        return total == 0 ? 1 : min(1, paid / total)
    }

    // MARK: Combat and nights

    mutating func defeated(_ kind: EnemyKind) {
        counters.enemiesDefeated += 1
        coins += kind.coins
        counters.coinsEarned += kind.coins
        if kind == .boss { counters.bossesDefeated.insert(.boss) }
    }

    /// The Brote fell: back to the campfire, half the backpack lost, full health.
    mutating func knockedOut() {
        backpack = Combat.penalty(backpack)
        health = maxHealth
    }

    mutating func nightEnded(campfireStanding: Bool) -> Int {
        night += 1
        let plan = RaidPlan(night: night)
        if campfireStanding {
            counters.nightsSurvived += 1
            coins += plan.reward
            counters.coinsEarned += plan.reward
            return plan.reward
        }
        storage = storage.mapValues { $0 - Int((Double($0) * RaidPlan.stolenShare).rounded()) }
        return 0
    }

    // MARK: Requests and rewards

    mutating func fulfil(_ request: Request) -> Bool {
        guard !completedRequests.contains(request.id), storage[request.item, default: 0] >= request.amount else { return false }
        storage[request.item, default: 0] -= request.amount
        coins += request.reward
        counters.coinsEarned += request.reward
        counters.requestsDone += 1
        completedRequests.insert(request.id)
        return true
    }

    /// Daily gift if not claimed today. Returns the coins given, or nil.
    mutating func claimDailyReward(day: Int) -> Int? {
        guard lastRewardDay != day else { return nil }
        rewardStreak = lastRewardDay == day - 1 ? rewardStreak + 1 : 1
        lastRewardDay = day
        let gift = DailyReward.coins(streak: rewardStreak)
        coins += gift
        return gift
    }

    // MARK: Missions and achievements

    func isMet(_ goal: Goal) -> Bool {
        switch goal {
        case .gather(let item, let n): counters.gathered(item) >= n
        case .earn(let n): counters.coinsEarned >= n
        case .gear(let g, let n): level(g) >= n
        case .build(let b, let n): level(b) >= n
        case .craft(let item, let n): counters.crafted[item, default: 0] >= n
        case .surviveNights(let n): counters.nightsSurvived >= n
        case .bridge(let id): bridges.contains(id)
        case .defeat(let n): counters.enemiesDefeated >= n
        case .boss(let kind): counters.bossesDefeated.contains(kind)
        case .request(let n): counters.requestsDone >= n
        }
    }

    /// Progress 0…1 towards a goal, for the bars.
    func progress(_ goal: Goal) -> Double {
        func f(_ a: Int, _ b: Int) -> Double { b == 0 ? 1 : min(1, Double(a) / Double(b)) }
        switch goal {
        case .gather(let item, let n): return f(counters.gathered(item), n)
        case .earn(let n): return f(counters.coinsEarned, n)
        case .gear(let g, let n): return f(level(g) - 1, n - 1)
        case .build(let b, let n): return f(level(b), n)
        case .craft(let item, let n): return f(counters.crafted[item, default: 0], n)
        case .surviveNights(let n): return f(counters.nightsSurvived, n)
        case .bridge(let id): return bridgeFraction(id)
        case .defeat(let n): return f(counters.enemiesDefeated, n)
        case .boss(let kind): return counters.bossesDefeated.contains(kind) ? 1 : 0
        case .request(let n): return f(counters.requestsDone, n)
        }
    }

    /// Completes every mission already met (in order) and pays them. Returns the finished ones.
    mutating func advanceQuests() -> [Quest] {
        var finished: [Quest] = []
        while let quest = currentQuest, isMet(quest.goal) {
            coins += quest.reward
            finished.append(quest)
            questIndex += 1
        }
        return finished
    }

    /// Newly earned achievements.
    mutating func checkAchievements() -> [Achievement] {
        let new = Achievement.all.filter { !achievements.contains($0.id) && isMet($0.goal) }
        achievements.formUnion(new.map(\.id))
        return new
    }

    /// Back in the game: finish crafts and grow the garden for the time away (at most 8 hours count).
    mutating func catchUp(now: Date = .now) {
        collectJobs(now: now)
        settleGarden(now: now)
        lastSeen = now
    }

    // MARK: Save

    func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    static func decoded(_ data: Data) -> GameState? { try? JSONDecoder().decode(GameState.self, from: data) }
}
