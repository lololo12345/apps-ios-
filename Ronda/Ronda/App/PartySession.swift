import Foundation
import Observation

enum AgeStatus: String, Codable, Sendable {
    case adult
    case minor
}

enum LaunchOptions {
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    /// `-flag value` pairs passed by the UI tests, e.g. `-appearance light`.
    static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

/// State of the night: players, the sip tally, settings and the water-break schedule.
/// Players, tally and settings persist so a game survives the app being closed between rounds.
@MainActor
@Observable
final class PartySession {
    private enum Key {
        static let players = "players"
        static let ledger = "ledger"
        static let age = "ageStatus"
        static let sober = "soberMode"
        static let water = "waterEvery"
        static let intensity = "intensity"
        static let setup = "setupDone"
        static let turn = "turn"
        static let appearance = "appearance"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var players: [Player] { didSet { persistPlayers(); turn = TurnOrder(count: players.count, start: turn.current) } }
    private(set) var ledger: SipLedger { didSet { persist(ledger, key: Key.ledger) } }
    var ageStatus: AgeStatus? { didSet { defaults.set(ageStatus?.rawValue, forKey: Key.age) } }
    var soberPreference: Bool { didSet { defaults.set(soberPreference, forKey: Key.sober) } }
    var waterEvery: Int { didSet { defaults.set(waterEvery, forKey: Key.water); water = WaterBreakSchedule(every: waterEvery) } }
    var intensity: Intensity { didSet { defaults.set(intensity.rawValue, forKey: Key.intensity) } }
    /// Automático / Claro / Oscuro (Ajustes → Apariencia). Dark by default.
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    /// Set when the group finishes the first-run player list.
    var setupDone: Bool { didSet { defaults.set(setupDone, forKey: Key.setup) } }

    var mode: PartyMode = .normal
    /// Group consent for the Hot section; asked again every time the app is launched.
    var hotUnlocked = false
    var pendingWaterBreak: String?
    private(set) var turn: TurnOrder

    @ObservationIgnored private var water: WaterBreakSchedule
    @ObservationIgnored private var waterMessages = ShuffledDeck(CardBank.waterBreaks)

    init(defaults: UserDefaults = .standard, uiTesting: Bool = LaunchOptions.isUITesting) {
        self.defaults = defaults
        // Resolve everything into locals first: stored properties cannot be read before all are set.
        let initialPlayers: [Player]
        let initialWater: Int
        if uiTesting {
            let fresh = ProcessInfo.processInfo.arguments.contains("-freshInstall")
            initialPlayers = fresh ? [] : ["Ana", "Leo", "Sara", "Dani"].map { Player(name: $0) }
            initialWater = 0
            ledger = SipLedger()
            ageStatus = fresh ? nil : .adult
            soberPreference = false
            intensity = .party
            setupDone = !fresh
            appearance = LaunchOptions.value(after: "-appearance").flatMap(Appearance.init(rawValue:)) ?? .standard
        } else {
            initialPlayers = Self.decode([Player].self, from: defaults, key: Key.players) ?? []
            initialWater = defaults.object(forKey: Key.water) as? Int ?? 10
            ledger = Self.decode(SipLedger.self, from: defaults, key: Key.ledger) ?? SipLedger()
            ageStatus = defaults.string(forKey: Key.age).flatMap(AgeStatus.init(rawValue:))
            soberPreference = defaults.bool(forKey: Key.sober)
            intensity = defaults.string(forKey: Key.intensity).flatMap(Intensity.init(rawValue:)) ?? .party
            setupDone = defaults.bool(forKey: Key.setup)
            appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .standard
        }
        players = initialPlayers
        waterEvery = initialWater
        turn = TurnOrder(count: initialPlayers.count, start: uiTesting ? 0 : defaults.integer(forKey: Key.turn))
        water = WaterBreakSchedule(every: initialWater)
    }

    // MARK: Derived

    /// Minors can use the app only in alcohol-free mode and never see the Hot section.
    var soberMode: Bool { soberPreference || ageStatus == .minor }
    var canUseHot: Bool { ageStatus == .adult }
    var lexicon: Lexicon { Lexicon(soberMode: soberMode) }
    var currentPlayer: Player? { players.indices.contains(turn.current) ? players[turn.current] : nil }

    func player(leftOf player: Player) -> Player? {
        guard let index = players.firstIndex(of: player) else { return nil }
        return players[turn.left(of: index)]
    }

    func player(rightOf player: Player) -> Player? {
        guard let index = players.firstIndex(of: player) else { return nil }
        return players[turn.right(of: index)]
    }

    // MARK: Players

    @discardableResult
    func addPlayer(named raw: String) -> Bool {
        guard players.count < PlayerRules.maxPlayers,
              let name = PlayerRules.sanitize(raw, existing: players) else { return false }
        players.append(Player(name: name))
        return true
    }

    func removePlayer(_ player: Player) {
        players.removeAll { $0.id == player.id }
    }

    func movePlayers(from source: IndexSet, to destination: Int) {
        players.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Turns & sips

    func nextTurn() {
        turn.advance()
        if !LaunchOptions.isUITesting { defaults.set(turn.current, forKey: Key.turn) }
    }

    /// Undo a mistaken sip from the scoreboard.
    func undoSip(for player: Player) {
        ledger.remove(1, from: player.id)
    }

    func give(_ sips: Int, to ids: some Sequence<UUID>) {
        ledger.add(sips, to: ids)
    }

    func give(_ sips: Int, to player: Player?) {
        guard let player else { return }
        ledger.add(sips, to: player.id)
    }

    func everyone(_ sips: Int) {
        ledger.add(sips, to: players.map(\.id))
    }

    func resetLedger() {
        ledger.reset()
    }

    /// Call once per card/round. Schedules a water break when due (never in alcohol-free mode).
    func registerRound() {
        guard !soberMode, water.registerCard() else { return }
        pendingWaterBreak = waterMessages.draw()
        Haptics.warning()
    }

    // MARK: Persistence

    private func persistPlayers() {
        persist(players, key: Key.players)
    }

    private func persist(_ value: some Encodable, key: String) {
        guard !LaunchOptions.isUITesting, let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
