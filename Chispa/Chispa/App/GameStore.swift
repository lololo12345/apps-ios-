import Foundation
import Observation
import SwiftData

enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var seedHistory: Bool { arguments.contains("-seedHistory") }
    /// UI tests: tags the right answer so the test can play without knowing the content.
    static var revealAnswers: Bool { isUITesting && arguments.contains("-revealAnswers") }

    static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

struct LeagueRow: Identifiable, Equatable {
    let id: String
    let name: String
    let days: [Int]
    let total: Int
    let streak: Int
    let grid: String
    let isMe: Bool
}

enum ImportError: LocalizedError {
    case code(ShareCodeError), ownCode

    var errorDescription: String? {
        switch self {
        case .code(.notFound): "No encuentro ningún código de Chispa en el texto. Debe empezar por «CH1.»."
        case .code(.damaged): "El código está incompleto. Pide a tu amigo que te lo vuelva a enviar."
        case .code(.tampered): "El código ha sido modificado y no es válido."
        case .ownCode: "Ese es tu propio código. Envíaselo a tus amigos para que te añadan."
        }
    }
}

@Observable
@MainActor
final class GameStore {
    let context: ModelContext
    private let defaults: UserDefaults

    private(set) var today: ChallengeDay
    private(set) var todayChallenges: [Challenge]
    private(set) var records: [ChallengeRecord] = []
    private(set) var friends: [FriendRecord] = []
    /// The device clock went back in time: playing is paused so nobody replays a day.
    private(set) var clockBehind = false

    let playerID: String
    var playerName: String { didSet { defaults.set(playerName, forKey: Keys.name) } }
    var reminderOn: Bool { didSet { defaults.set(reminderOn, forKey: Keys.reminderOn); scheduleReminders() } }
    var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: Keys.reminderMinutes); scheduleReminders() } }
    var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.sound) } }
    var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.haptics) } }

    private enum Keys {
        static let name = "player.name", id = "player.id", reminderOn = "reminder.on", reminderMinutes = "reminder.minutes"
        static let sound = "sound.on", haptics = "haptics.on", latestSeen = "clock.latestSeen"
    }

    init(context: ModelContext, defaults: UserDefaults, now: Date = .now) {
        self.context = context
        self.defaults = defaults
        let day = ChallengeDay(date: now)
        today = day
        todayChallenges = DailySet.challenges(for: day)
        if let id = defaults.string(forKey: Keys.id) {
            playerID = id
        } else {
            let id = UUID().uuidString.prefix(12).lowercased()
            defaults.set(String(id), forKey: Keys.id)
            playerID = String(id)
        }
        playerName = defaults.string(forKey: Keys.name) ?? ""
        reminderOn = defaults.object(forKey: Keys.reminderOn) as? Bool ?? false
        reminderMinutes = defaults.object(forKey: Keys.reminderMinutes) as? Int ?? 20 * 60
        soundOn = defaults.object(forKey: Keys.sound) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        refreshDay(now: now)
    }

    // MARK: Day

    /// Call on launch, when the app comes back and at midnight.
    func refreshDay(now: Date = .now) {
        let latest = defaults.object(forKey: Keys.latestSeen) as? Date
        clockBehind = ClockGuard.isClockBehind(now: now, latestSeen: latest)
        if !clockBehind, now > (latest ?? .distantPast) { defaults.set(now, forKey: Keys.latestSeen) }
        let day = ChallengeDay(date: now)
        if day != today {
            today = day
            todayChallenges = DailySet.challenges(for: day)
        }
        reload()
        closeAbandoned()
    }

    func reload() {
        records = (try? context.fetch(FetchDescriptor<ChallengeRecord>(sortBy: [SortDescriptor(\.day), SortDescriptor(\.startedAt)]))) ?? []
        friends = (try? context.fetch(FetchDescriptor<FriendRecord>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    /// Challenges started on an earlier day and never answered count as failed.
    private func closeAbandoned() {
        var changed = false
        for record in records where !record.isFinished && record.day < today.number {
            record.finishedAt = record.startedAt
            record.fraction = 0
            record.points = 0
            record.seconds = 0
            changed = true
        }
        if changed { save() }
    }

    // MARK: Results

    var summaries: [ResultSummary] { records.filter(\.isFinished).map(\.summary) }
    var streak: StreakState { Streaks.compute(completed: DayProgress.completedDays(summaries), today: today.number) }
    var stats: PlayerStats { PlayerStats.make(from: summaries) }
    var badges: [Badge] { Badges.all(results: summaries, streak: streak, friends: friends.count) }

    func record(for challenge: Challenge) -> ChallengeRecord? {
        records.first { $0.day == challenge.day.number && $0.kindRaw == challenge.kind.rawValue }
    }

    var todayFinished: [ChallengeRecord] { records.filter { $0.day == today.number && $0.isFinished } }
    var todayDone: Bool { todayFinished.count >= ChallengeKind.allCases.count }
    var todayPoints: Int { todayFinished.map(\.points).reduce(0, +) }
    var todayGrid: String { DayProgress.grid(on: today.number, summaries) }

    var nextUnplayed: Challenge? { todayChallenges.first { record(for: $0)?.isFinished != true } }

    /// Starts (or resumes) today's attempt. Returns nil if the clock looks wrong.
    @discardableResult
    func start(_ challenge: Challenge, now: Date = .now) -> ChallengeRecord? {
        guard !clockBehind, challenge.day == today else { return nil }
        if let existing = record(for: challenge) { return existing }
        let record = ChallengeRecord(day: challenge.day.number, kind: challenge.kind, startedAt: now)
        context.insert(record)
        save()
        reload()
        return record
    }

    /// The hint costs points even if the player leaves before answering.
    func markHint(_ challenge: Challenge) {
        guard let record = record(for: challenge), !record.isFinished else { return }
        record.usedHint = true
        save()
    }

    @discardableResult
    func finish(_ challenge: Challenge, fraction: Double, usedHint: Bool, now: Date = .now) -> ResultSummary? {
        guard let record = record(for: challenge) else { return nil }
        if record.isFinished { return record.summary }
        let hint = usedHint || record.usedHint
        let seconds = max(0, now.timeIntervalSince(record.startedAt))
        record.finishedAt = now
        record.fraction = fraction
        record.usedHint = hint
        record.seconds = seconds
        record.points = Scoring.points(fraction: fraction, seconds: seconds, usedHint: hint, level: challenge.level)
        save()
        reload()
        if todayDone {
            scheduleReminders()
            GameCenter.submit(weekPoints: myCard().weekTotal)
        }
        return record.summary
    }

    // MARK: League

    func myCard() -> LeagueCard {
        let week = DayProgress.week(containing: today, summaries).map { $0 ?? -1 }
        return LeagueCard(playerID: playerID, name: playerName.isEmpty ? "Yo" : playerName, week: today.weekNumber,
                          days: week, streak: streak.current, day: today.number, grid: todayGrid)
    }

    var shareMessage: String { ShareCode.message(for: myCard(), level: today.level) }

    @discardableResult
    func importFriend(from text: String) throws -> FriendRecord {
        let card: LeagueCard
        do { card = try ShareCode.decode(text) } catch let error as ShareCodeError { throw ImportError.code(error) } catch { throw ImportError.code(.damaged) }
        guard card.playerID != playerID else { throw ImportError.ownCode }
        let friend: FriendRecord
        if let existing = friends.first(where: { $0.playerID == card.playerID }) {
            existing.update(from: card)
            friend = existing
        } else {
            friend = FriendRecord(card: card)
            context.insert(friend)
        }
        save()
        reload()
        return friend
    }

    func remove(_ friend: FriendRecord) {
        context.delete(friend)
        save()
        reload()
    }

    var leagueRows: [LeagueRow] {
        let me = myCard()
        var rows = [LeagueRow(id: playerID, name: me.name, days: me.days, total: me.weekTotal, streak: me.streak, grid: me.grid, isMe: true)]
        for friend in friends where friend.week == today.weekNumber {
            let card = friend.card
            rows.append(LeagueRow(id: friend.playerID, name: friend.name, days: card.days, total: card.weekTotal,
                                  streak: card.streak, grid: friend.day == today.number ? friend.grid : "", isMe: false))
        }
        return rows.sorted { $0.total != $1.total ? $0.total > $1.total : $0.isMe }
    }

    /// Friends whose last code is from an earlier week.
    var waitingFriends: [FriendRecord] { friends.filter { $0.week != today.weekNumber } }

    // MARK: Settings

    var reminderTime: Date {
        get { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
        }
    }

    func scheduleReminders() {
        let on = reminderOn, minutes = reminderMinutes, skipToday = todayDone, streak = streak.current
        Task { await Reminders.schedule(enabled: on, minutes: minutes, skipToday: skipToday, streak: streak) }
    }

    func resetAll() {
        for record in records { context.delete(record) }
        for friend in friends { context.delete(friend) }
        save()
        reload()
    }

    func save() {
        try? context.save()
    }

    // MARK: Screenshots

    /// UI tests (-seedHistory): three weeks of play, one day saved by a shield, and three friends.
    func seedHistory() {
        guard records.isEmpty else { return }
        var random = SeededRandom(seed: 42)
        let start = today.number - 20
        for day in start..<today.number where day != today.number - 12 {
            for kind in ChallengeKind.allCases {
                let record = ChallengeRecord(day: day, kind: kind, startedAt: ChallengeDay(number: day).startDate().addingTimeInterval(3600 * 19))
                let roll = random.int(0...9)
                record.fraction = roll < 7 ? 1 : (kind == .memory ? 0.6 : 0)
                record.usedHint = roll == 6
                record.seconds = Double(random.int(6...70))
                record.finishedAt = record.startedAt.addingTimeInterval(record.seconds)
                record.points = Scoring.points(fraction: record.fraction, seconds: record.seconds, usedHint: record.usedHint, level: ChallengeDay(number: day).level)
                context.insert(record)
            }
        }
        let week = today.weekNumber
        let friendsSeed: [(String, String, [Int], Int)] = [
            ("f-marta", "Marta", [520, 610, 480, 700, 655, 590, 980], 23),
            ("f-dani", "Dani", [430, -1, 650, 590, 720, 610, 1040], 4),
            ("f-sara", "Sara", [610, 540, 720, 660, 300, 700, 1120], 41),
        ]
        for (id, name, days, streak) in friendsSeed {
            var shown = days
            for i in 0..<7 where i >= today.weekdayIndex { shown[i] = -1 }
            context.insert(FriendRecord(card: LeagueCard(playerID: id, name: name, week: week, days: shown, streak: streak,
                                                         day: today.number - 1, grid: "🟩🟩🟨🟩🟥")))
        }
        save()
        reload()
    }
}
