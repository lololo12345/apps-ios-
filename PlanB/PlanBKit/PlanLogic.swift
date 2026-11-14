import Foundation

/// What the couple asks for. Every nil/empty field means "me da igual".
public struct PlanFilter: Codable, Equatable, Sendable {
    public var maxBudget: Budget?
    public var place: Place?
    /// Time available: plans that take this long or less.
    public var maxDuration: Duration?
    public var time: TimeOfDay?
    public var moods: Set<Mood> = []

    public init(maxBudget: Budget? = nil, place: Place? = nil, maxDuration: Duration? = nil, time: TimeOfDay? = nil, moods: Set<Mood> = []) {
        self.maxBudget = maxBudget
        self.place = place
        self.maxDuration = maxDuration
        self.time = time
        self.moods = moods
    }

    public var isEmpty: Bool { self == PlanFilter() }
    public var activeCount: Int {
        [maxBudget != nil, place != nil, maxDuration != nil, time != nil, !moods.isEmpty].filter { $0 }.count
    }

    public func matches(_ plan: Plan) -> Bool {
        if let maxBudget, plan.budget > maxBudget { return false }
        if let place, plan.place != place { return false }
        if let maxDuration, plan.duration > maxDuration { return false }
        if let time, !plan.times.contains(time) { return false }
        if !moods.isEmpty, !moods.contains(plan.mood) { return false }
        return true
    }
}

/// Plans in random order, never repeating one until every match has been seen.
public struct PlanDeck: Sendable {
    public private(set) var plans: [Plan]
    private var order: [Int] = []
    public private(set) var seen = 0

    public init(plans: [Plan], using generator: inout some RandomNumberGenerator) {
        self.plans = plans
        order = Array(plans.indices).shuffled(using: &generator)
    }

    public var isEmpty: Bool { plans.isEmpty }

    /// The next `count` plans, without consuming them (for the visible card stack).
    public func upcoming(_ count: Int) -> [Plan] {
        order.suffix(count).reversed().map { plans[$0] }
    }

    public var current: Plan? { order.last.map { plans[$0] } }

    /// Moves to the next plan; reshuffles when the deck runs out.
    public mutating func advance(using generator: inout some RandomNumberGenerator) {
        guard !plans.isEmpty else { return }
        let last = current?.id
        if !order.isEmpty { order.removeLast() }
        seen += 1
        if order.isEmpty {
            order = Array(plans.indices).shuffled(using: &generator)
            // Never show the same card twice in a row across a reshuffle.
            if plans.count > 1, let last, plans[order.last!].id == last { order.swapAt(order.count - 1, 0) }
        }
    }
}

/// Deterministic random generator (SplitMix64) for tests and the plan of the day.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// "Plan del día": the same plan all day long, a different one every day (app and widget agree).
public enum DailyPlan {
    public static func pick(for date: Date, from plans: [Plan], calendar: Calendar = .current) -> Plan? {
        let pool = plans.filter { !$0.intimate }
        guard !pool.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        var generator = SeededGenerator(seed: UInt64(day))
        return pool[Int(generator.next() % UInt64(pool.count))]
    }
}

/// Clues for the surprise mode: enough to get ready, never enough to guess.
public enum SurpriseHints {
    public static func hints(for plan: Plan) -> [String] {
        var hints: [String] = []
        hints.append(plan.place == .home ? "No hace falta salir de casa 🏠" : "Vamos a salir: prepárate 🚪")
        switch plan.duration {
        case .hour: hints.append("Es algo cortito: con una hora sobra ⏱️")
        case .evening: hints.append("Guárdame la tarde libre 🗓️")
        case .day: hints.append("Resérvame el día entero ☀️")
        case .weekend: hints.append("Haz una pequeña maleta: es de finde 🧳")
        }
        switch plan.mood {
        case .calm: hints.append("Plan tranquilo: ponte cómodo 🛋️")
        case .romantic: hints.append("Ponte guapo, que la ocasión lo merece ✨")
        case .active: hints.append("Ropa y calzado cómodos, que nos vamos a mover 👟")
        case .adventure: hints.append("Algo que no hacemos todos los días 🧭")
        case .creative: hints.append("Trae ganas de crear y de reírte 🎨")
        }
        switch plan.budget {
        case .free: hints.append("No nos va a costar nada 💸")
        case .low: hints.append("Un plan sencillo y barato 🪙")
        case .mid: hints.append("Me he estirado un poquito 💳")
        case .high: hints.append("Esta vez tiramos la casa por la ventana 🥂")
        }
        if plan.times.count == 1, let time = plan.times.first {
            hints.append(time == .morning ? "Toca madrugar un poco 🌅" : time == .night ? "Es un plan de noche 🌙" : "Es un plan de tarde 🌇")
        }
        return hints
    }
}

/// Numbers for "Nuestros recuerdos".
public enum MemoryStats {
    /// Consecutive weeks (Monday-based) with at least one plan done, counting back from this week.
    /// If nothing was done yet this week, the streak is still alive from last week.
    public static func weeklyStreak(_ dates: [Date], now: Date, calendar: Calendar = Self.weekCalendar) -> Int {
        let weeks = Set(dates.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        if !weeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var streak = 0
        while weeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    public static var weekCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    /// Index of a memory from about a year ago (same day ± `tolerance` days, 1+ years back), if any.
    public static func onThisDay(_ dates: [Date], now: Date, tolerance: Int = 3, calendar: Calendar = .current) -> Int? {
        var best: (index: Int, distance: Int)?
        for (index, date) in dates.enumerated() {
            // Calendar years apart (not full years), so an anniversary two days from now still counts.
            let years = calendar.component(.year, from: now) - calendar.component(.year, from: date)
            guard years >= 1, let anniversary = calendar.date(byAdding: .year, value: years, to: date) else { continue }
            let distance = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: anniversary), to: calendar.startOfDay(for: now)).day ?? 99)
            if distance <= tolerance, distance < (best?.distance ?? .max) { best = (index, distance) }
        }
        return best?.index
    }

    public static func averageRating(_ ratings: [Int]) -> Double? {
        let rated = ratings.filter { $0 > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }
}

/// Wheel for "Decide por nosotros": equal slices, lands on a chosen index.
public enum PlanWheel {
    public static func rotation(landingOn index: Int, count: Int, from current: Double, extraTurns: Int = 5, jitter: Double = 0) -> Double {
        let slice = 360.0 / Double(max(count, 1))
        let target = 360 - (Double(index) + 0.5) * slice + jitter * slice * 0.35
        let base = current - current.truncatingRemainder(dividingBy: 360)
        return base + Double(extraTurns) * 360 + target
    }

    public static func segment(atRotation rotation: Double, count: Int) -> Int {
        let slice = 360.0 / Double(max(count, 1))
        var angle = (360 - rotation.truncatingRemainder(dividingBy: 360)).truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return min(count - 1, Int(angle / slice))
    }
}
