import Foundation

/// One finished challenge, as plain values (the app stores them with SwiftData).
struct ResultSummary: Sendable, Hashable {
    let day: Int
    let kind: ChallengeKind
    let fraction: Double
    let points: Int
    let seconds: Double
    let usedHint: Bool

    var outcome: Outcome { Scoring.outcome(fraction: fraction, usedHint: usedHint) }
    var isCorrect: Bool { fraction >= 1 }
}

struct StreakState: Equatable, Sendable {
    var current = 0
    var best = 0
    var shields = 0
    /// Days a shield saved the streak.
    var savedDays: [Int] = []
}

enum Streaks {
    /// A shield is earned every this many days in a row.
    static let shieldEvery = 7
    static let maxShields = 2

    /// `completed`: day numbers with all five challenges answered. Today only counts once it is complete:
    /// an unfinished today never breaks the streak.
    static func compute(completed: Set<Int>, today: Int) -> StreakState {
        var state = StreakState()
        guard let first = completed.min(), first <= today else { return state }
        for day in first...today {
            if completed.contains(day) {
                state.current += 1
                state.best = max(state.best, state.current)
                if state.current % shieldEvery == 0 && state.shields < maxShields { state.shields += 1 }
            } else if day == today {
                continue
            } else if state.current > 0 && state.shields > 0 {
                state.shields -= 1
                state.savedDays.append(day)
            } else {
                state.current = 0
                state.shields = 0
            }
        }
        return state
    }
}

struct KindStats: Sendable, Identifiable {
    let kind: ChallengeKind
    let played: Int
    let correct: Int
    let averageSeconds: Double

    var id: String { kind.rawValue }
    var accuracy: Double { played == 0 ? 0 : Double(correct) / Double(played) }
}

struct PlayerStats: Sendable {
    let kinds: [KindStats]
    let totalPlayed: Int
    let totalCorrect: Int
    let totalPoints: Int
    let perfectDays: Int
    let daysPlayed: Int
    let hintsUsed: Int

    var accuracy: Double { totalPlayed == 0 ? 0 : Double(totalCorrect) / Double(totalPlayed) }

    /// Best and worst kinds once each has been played at least three times.
    var strongest: KindStats? { kinds.filter { $0.played >= 3 }.max { ($0.accuracy, -$0.averageSeconds) < ($1.accuracy, -$1.averageSeconds) } }
    var weakest: KindStats? {
        guard let strongest else { return nil }
        let rest = kinds.filter { $0.played >= 3 && $0.kind != strongest.kind }
        return rest.min { ($0.accuracy, -$0.averageSeconds) < ($1.accuracy, -$1.averageSeconds) }
    }

    static func make(from results: [ResultSummary]) -> PlayerStats {
        let kinds = ChallengeKind.allCases.map { kind in
            let mine = results.filter { $0.kind == kind }
            let seconds = mine.isEmpty ? 0 : mine.map(\.seconds).reduce(0, +) / Double(mine.count)
            return KindStats(kind: kind, played: mine.count, correct: mine.filter(\.isCorrect).count, averageSeconds: seconds)
        }
        let byDay = Dictionary(grouping: results, by: \.day)
        let perfect = byDay.values.filter { $0.count == ChallengeKind.allCases.count && $0.allSatisfy { $0.outcome == .perfect } }.count
        return PlayerStats(kinds: kinds, totalPlayed: results.count, totalCorrect: results.filter(\.isCorrect).count,
                           totalPoints: results.map(\.points).reduce(0, +), perfectDays: perfect, daysPlayed: byDay.count,
                           hintsUsed: results.filter(\.usedHint).count)
    }
}

enum DayProgress {
    /// Days on which every challenge was answered.
    static func completedDays(_ results: [ResultSummary]) -> Set<Int> {
        Set(Dictionary(grouping: results, by: \.day).filter { $0.value.count >= ChallengeKind.allCases.count }.keys)
    }

    static func points(on day: Int, _ results: [ResultSummary]) -> Int {
        results.filter { $0.day == day }.map(\.points).reduce(0, +)
    }

    /// Points for each day of the week (Monday first) that contains `day`; nil for days not played.
    static func week(containing day: ChallengeDay, _ results: [ResultSummary]) -> [Int?] {
        let monday = day.weekStart.number
        return (0..<7).map { offset in
            let mine = results.filter { $0.day == monday + offset }
            return mine.isEmpty ? nil : mine.map(\.points).reduce(0, +)
        }
    }

    /// "🟩🟨🟥🟩🟩" in the fixed order of the five kinds (⬜ for unplayed).
    static func grid(on day: Int, _ results: [ResultSummary]) -> String {
        ChallengeKind.allCases.map { kind in
            results.first { $0.day == day && $0.kind == kind }?.outcome.emoji ?? "⬜"
        }.joined()
    }
}

struct Badge: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let earned: Bool
    /// 0…1 towards the badge.
    let progress: Double
}

enum Badges {
    static func all(results: [ResultSummary], streak: StreakState, friends: Int) -> [Badge] {
        let stats = PlayerStats.make(from: results)
        let byDay = Dictionary(grouping: results, by: \.day)
        let bossBeaten = byDay.contains { day, items in
            ChallengeDay(number: day).level == .boss && items.count == 5 && items.allSatisfy(\.isCorrect)
        }
        let memoryPerfect = results.filter { $0.kind == .memory && $0.outcome == .perfect }.count
        let lightning = results.contains { $0.isCorrect && $0.seconds < 5 }
        let pureWeek = pureWeekExists(byDay)
        func make(_ id: String, _ title: String, _ detail: String, _ symbol: String, _ value: Double, _ goal: Double) -> Badge {
            Badge(id: id, title: title, detail: detail, symbol: symbol, earned: value >= goal, progress: min(value / goal, 1))
        }
        return [
            make("streak7", "Una semana", "7 días seguidos", "flame.fill", Double(streak.best), 7),
            make("streak30", "Un mes", "30 días seguidos", "flame.circle.fill", Double(streak.best), 30),
            make("streak100", "Centenaria", "100 días seguidos", "medal.fill", Double(streak.best), 100),
            make("streak365", "Un año entero", "365 días seguidos", "crown.fill", Double(streak.best), 365),
            make("perfect", "Día perfecto", "Los cinco retos bien, sin pistas", "star.fill", Double(stats.perfectDays), 1),
            make("boss", "Jefe vencido", "Acierta los cinco retos de un domingo", "shield.lefthalf.filled", bossBeaten ? 1 : 0, 1),
            make("memory", "Memoria de elefante", "10 retos de memoria perfectos", "brain.head.profile.fill", Double(memoryPerfect), 10),
            make("lightning", "Rayo", "Acierta un reto en menos de 5 segundos", "bolt.fill", lightning ? 1 : 0, 1),
            make("pure", "Sin ayuda", "Una semana completa sin usar pistas", "hand.raised.slash.fill", pureWeek ? 1 : 0, 1),
            make("hundred", "Cien aciertos", "Acierta 100 retos", "checkmark.seal.fill", Double(stats.totalCorrect), 100),
            make("social", "En buena compañía", "Añade 3 amigos a tu liga", "person.3.fill", Double(friends), 3),
        ]
    }

    private static func pureWeekExists(_ byDay: [Int: [ResultSummary]]) -> Bool {
        let weeks = Dictionary(grouping: byDay.keys) { ChallengeDay(number: $0).weekStart.number }
        return weeks.values.contains { days in
            days.count == 7 && days.allSatisfy { (byDay[$0]?.count ?? 0) == 5 && !(byDay[$0]?.contains(where: \.usedHint) ?? true) }
        }
    }
}

/// Guards against moving the clock back to replay a day.
enum ClockGuard {
    /// Allowed difference before the app treats the clock as moved back (time zones, small adjustments).
    static let tolerance: TimeInterval = 3 * 3600

    static func isClockBehind(now: Date, latestSeen: Date?) -> Bool {
        guard let latestSeen else { return false }
        return now.addingTimeInterval(tolerance) < latestSeen
    }
}
