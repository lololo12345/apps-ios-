import Foundation

/// A calendar day in the player's local time zone. Every day has a sequential number ("Chispa #312")
/// and everyone gets the same five challenges for the same number.
struct ChallengeDay: Hashable, Comparable, Sendable, Codable {
    /// Days since 1 January 2025 (day 1).
    let number: Int

    static let epoch: DateComponents = DateComponents(year: 2025, month: 1, day: 1)

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    init(number: Int) { self.number = number }

    init(date: Date, calendar: Calendar = ChallengeDay.calendar) {
        let start = calendar.date(from: Self.epoch) ?? Date(timeIntervalSince1970: 1_735_689_600)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        number = days + 1
    }

    static func today(_ now: Date = .now) -> ChallengeDay { ChallengeDay(date: now) }

    static func < (lhs: ChallengeDay, rhs: ChallengeDay) -> Bool { lhs.number < rhs.number }

    func adding(_ days: Int) -> ChallengeDay { ChallengeDay(number: number + days) }

    /// Midnight at the start of this day.
    func startDate(calendar: Calendar = ChallengeDay.calendar) -> Date {
        let start = calendar.date(from: Self.epoch) ?? Date(timeIntervalSince1970: 1_735_689_600)
        let date = calendar.date(byAdding: .day, value: number - 1, to: start) ?? start
        return calendar.startOfDay(for: date)
    }

    /// Midnight at the end of this day: when the next challenge appears.
    func endDate(calendar: Calendar = ChallengeDay.calendar) -> Date {
        adding(1).startDate(calendar: calendar)
    }

    /// 1 = 1 January 2025 was a Wednesday, so weekday index 0 = Monday … 6 = Sunday.
    var weekdayIndex: Int { ((number - 1) % 7 + 7 + 2) % 7 }

    var level: Level { Level(weekdayIndex: weekdayIndex) }

    /// Monday of this day's week (the league runs Monday to Sunday).
    var weekStart: ChallengeDay { adding(-weekdayIndex) }

    /// Stable identifier of the week, e.g. the number of its Monday.
    var weekNumber: Int { (weekStart.number + 5) / 7 }

    var seed: UInt64 { UInt64(number) &* 0x9E37_79B9_7F4A_7C15 ^ 0xC415_9A }

    func formatted(_ style: Date.FormatStyle = .dateTime.weekday(.wide).day().month(.wide)) -> String {
        startDate().formatted(style.locale(Locale(identifier: "es_ES")))
    }
}

/// Difficulty grows during the week: Monday easy, Sunday the "boss" challenge worth double.
enum Level: Int, CaseIterable, Codable, Sendable {
    case easy = 1, medium, hard, boss

    init(weekdayIndex: Int) {
        switch weekdayIndex {
        case 0, 1: self = .easy
        case 2, 3: self = .medium
        case 4, 5: self = .hard
        default: self = .boss
        }
    }

    var label: String {
        switch self {
        case .easy: "Fácil"
        case .medium: "Media"
        case .hard: "Difícil"
        case .boss: "Reto jefe"
        }
    }

    var multiplier: Double {
        switch self {
        case .easy: 1
        case .medium: 1.25
        case .hard: 1.5
        case .boss: 2
        }
    }

    var multiplierLabel: String {
        switch self {
        case .easy: "×1"
        case .medium: "×1,25"
        case .hard: "×1,5"
        case .boss: "×2"
        }
    }
}

/// SplitMix64: tiny, fast and identical on every device, so the same seed gives the same challenge everywhere.
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func chance(_ probability: Double) -> Bool {
        Double(next() % 10_000) / 10_000 < probability
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            let j = int(0...i)
            result.swapAt(i, j)
        }
        return result
    }
}

/// Walks a pool in a shuffled order that only repeats once every item has been used.
enum Rotation {
    static func index(for day: ChallengeDay, poolSize: Int, salt: UInt64) -> Int {
        guard poolSize > 0 else { return 0 }
        let position = max(day.number - 1, 0)
        let cycle = position / poolSize
        var random = SeededRandom(seed: UInt64(cycle) &* 31 &+ salt)
        let order = random.shuffled(Array(0..<poolSize))
        return order[position % poolSize]
    }
}
