import Foundation
import Observation

enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var freshInstall: Bool { arguments.contains("-freshInstall") }
    static var seedMemories: Bool { arguments.contains("-seedMemories") }
}

/// Which deck the Discover screen shows.
enum DeckSection: String, CaseIterable, Identifiable, Codable {
    case together, intimate
    var id: String { rawValue }
    var title: String { self == .together ? "Para los dos" : "Íntimo" }
}

/// Surprise mode: one partner picks a plan in secret, the other gets clues.
struct Surprise: Codable, Equatable {
    var planID: String
    var revealedHints: Int = 1
    var revealed = false
}

/// Everything that is not a SwiftData record: names, filters, saved plans, the plan in progress,
/// surprise mode and reminder settings. Persisted in UserDefaults (a throwaway suite in UI tests).
@MainActor
@Observable
final class AppState {
    private enum Key {
        static let names = "names", filter = "filter", saved = "saved", active = "activePlan", surprise = "surprise"
        static let intimate = "intimateUnlocked", reminder = "reminder", section = "section"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var rng: SeededGenerator

    var nameA: String
    var nameB: String
    var filter: PlanFilter { didSet { save(filter, Key.filter); rebuildDeck() } }
    var section: DeckSection { didSet { save(section, Key.section); rebuildDeck() } }
    var intimateUnlocked: Bool { didSet { defaults.set(intimateUnlocked, forKey: Key.intimate); if !intimateUnlocked { section = .together } } }
    private(set) var savedIDs: [String] { didSet { save(savedIDs, Key.saved) } }
    private(set) var activePlanID: String? { didSet { defaults.set(activePlanID, forKey: Key.active) } }
    var surprise: Surprise? { didSet { save(surprise, Key.surprise) } }
    var reminder: ReminderSettings { didSet { save(reminder, Key.reminder) } }

    private(set) var deck: PlanDeck
    /// Custom plans (mirrored from SwiftData by the root view).
    var customPlans: [Plan] = [] { didSet { if oldValue.map(\.id) != customPlans.map(\.id) { rebuildDeck() } } }
    /// Plan opened from the widget or a deep link.
    var presentedPlan: Plan?

    init(defaults: UserDefaults? = nil, uiTesting: Bool = LaunchOptions.isUITesting) {
        let store: UserDefaults
        if let defaults {
            store = defaults
        } else if uiTesting {
            let suite = "planb.uitests"
            UserDefaults().removePersistentDomain(forName: suite)
            store = UserDefaults(suiteName: suite) ?? .standard
        } else {
            store = .standard
        }
        self.defaults = store
        var generator = SeededGenerator(seed: uiTesting ? 7 : UInt64.random(in: 1...UInt64.max))

        let names = store.stringArray(forKey: Key.names) ?? []
        if uiTesting && !LaunchOptions.freshInstall {
            nameA = "Ana"
            nameB = "Leo"
        } else {
            nameA = names.first ?? ""
            nameB = names.count > 1 ? names[1] : ""
        }
        filter = Self.load(PlanFilter.self, store, Key.filter) ?? PlanFilter()
        section = Self.load(DeckSection.self, store, Key.section) ?? .together
        intimateUnlocked = store.bool(forKey: Key.intimate)
        savedIDs = Self.load([String].self, store, Key.saved) ?? []
        activePlanID = store.string(forKey: Key.active)
        surprise = Self.load(Surprise.self, store, Key.surprise)
        reminder = Self.load(ReminderSettings.self, store, Key.reminder) ?? ReminderSettings()
        deck = PlanDeck(plans: [], using: &generator)
        rng = generator
        rebuildDeck()
    }

    // MARK: Couple

    var hasNames: Bool { !nameA.isEmpty && !nameB.isEmpty }
    var coupleName: String { hasNames ? "\(nameA) y \(nameB)" : "vosotros" }

    func setNames(_ a: String, _ b: String) {
        nameA = Self.cleanName(a)
        nameB = Self.cleanName(b)
        defaults.set([nameA, nameB], forKey: Key.names)
    }

    static func cleanName(_ raw: String) -> String {
        String(raw.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(20))
    }

    // MARK: Plans

    var allPlans: [Plan] { PlanCatalog.all + customPlans }

    func plan(id: String) -> Plan? {
        PlanCatalog.plan(id: id) ?? customPlans.first { $0.id == id }
    }

    /// Plans that match the filters in the current section.
    var matchingPlans: [Plan] {
        let intimate = section == .intimate && intimateUnlocked
        return allPlans.filter { $0.intimate == intimate && filter.matches($0) }
    }

    func rebuildDeck() {
        var generator = rng
        deck = PlanDeck(plans: matchingPlans, using: &generator)
        rng = generator
    }

    func nextCard() {
        var generator = rng
        deck.advance(using: &generator)
        rng = generator
    }

    func randomPlans(_ count: Int) -> [Plan] {
        var generator = rng
        let picked = Array(matchingPlans.shuffled(using: &generator).prefix(count))
        rng = generator
        return picked
    }

    func randomIndex(_ count: Int) -> Int {
        var generator = rng
        let index = Int.random(in: 0..<max(count, 1), using: &generator)
        rng = generator
        return index
    }

    // MARK: Saved

    func isSaved(_ plan: Plan) -> Bool { savedIDs.contains(plan.id) }

    func toggleSaved(_ plan: Plan) {
        if let index = savedIDs.firstIndex(of: plan.id) {
            savedIDs.remove(at: index)
        } else {
            savedIDs.insert(plan.id, at: 0)
        }
    }

    func unsave(ids: [String]) {
        savedIDs.removeAll { ids.contains($0) }
    }

    var savedPlans: [Plan] { savedIDs.compactMap(plan(id:)) }

    // MARK: Plan in progress

    var activePlan: Plan? { activePlanID.flatMap(plan(id:)) }

    func choose(_ plan: Plan) {
        activePlanID = plan.id
    }

    func clearActive() {
        activePlanID = nil
    }

    // MARK: Persistence

    private func save(_ value: some Encodable, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ defaults: UserDefaults, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
