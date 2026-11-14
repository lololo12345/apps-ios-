import Foundation

/// Rough cost of a plan for the two of you.
public enum Budget: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case free, low, mid, high

    public var id: Int { rawValue }
    public var label: String { ["Gratis", "€", "€€", "€€€"][rawValue] }
    public var detail: String { ["Gratis", "Menos de 20 €", "20–60 €", "Más de 60 €"][rawValue] }
    public static func < (lhs: Budget, rhs: Budget) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum Place: String, CaseIterable, Codable, Sendable, Identifiable {
    case home, out

    public var id: String { rawValue }
    public var label: String { self == .home ? "En casa" : "Fuera" }
    public var symbol: String { self == .home ? "house.fill" : "figure.walk" }
}

/// How long the plan takes. A plan fits any slot at least as long as its own duration.
public enum Duration: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case hour, evening, day, weekend

    public var id: Int { rawValue }
    public var label: String { ["1 hora", "Una tarde", "Todo el día", "Un finde"][rawValue] }
    public static func < (lhs: Duration, rhs: Duration) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum TimeOfDay: String, CaseIterable, Codable, Sendable, Identifiable {
    case morning, afternoon, night

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .morning: "Mañana"
        case .afternoon: "Tarde"
        case .night: "Noche"
        }
    }
    public var symbol: String {
        switch self {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .night: "moon.stars.fill"
        }
    }
}

public enum Mood: String, CaseIterable, Codable, Sendable, Identifiable {
    case calm, romantic, active, adventure, creative

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .calm: "Tranquilo"
        case .romantic: "Romántico"
        case .active: "Activo"
        case .adventure: "Aventura"
        case .creative: "Creativo"
        }
    }
    public var symbol: String {
        switch self {
        case .calm: "leaf.fill"
        case .romantic: "heart.fill"
        case .active: "figure.run"
        case .adventure: "map.fill"
        case .creative: "paintpalette.fill"
        }
    }
}

/// One idea for the two of you.
public struct Plan: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let emoji: String
    public let title: String
    public let summary: String
    /// "Para hacerlo especial".
    public let tip: String
    /// "Qué necesitáis" (empty when nothing special is needed).
    public let needs: String
    public let budget: Budget
    public let place: Place
    public let duration: Duration
    public let times: Set<TimeOfDay>
    public let mood: Mood
    /// +18 section: suggestive, never explicit. Only shown when both partners opted in.
    public let intimate: Bool
    public let isCustom: Bool

    public init(
        id: String, emoji: String, title: String, summary: String, tip: String = "", needs: String = "",
        budget: Budget, place: Place, duration: Duration, times: Set<TimeOfDay>, mood: Mood,
        intimate: Bool = false, isCustom: Bool = false
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.summary = summary
        self.tip = tip
        self.needs = needs
        self.budget = budget
        self.place = place
        self.duration = duration
        self.times = times
        self.mood = mood
        self.intimate = intimate
        self.isCustom = isCustom
    }
}

/// Compact tag grammar used by the catalog: "free home evening night calm".
/// Budget: free low mid high · Place: home out · Duration: hour evening day weekend ·
/// Time: am pm night any · Mood: calm romantic active adventure creative · "hot" marks intimate plans.
public enum PlanTags {
    public struct Parsed: Equatable, Sendable {
        public var budget: Budget?
        public var place: Place?
        public var duration: Duration?
        public var times: Set<TimeOfDay> = []
        public var mood: Mood?
        public var intimate = false
        public var unknown: [String] = []

        public var isComplete: Bool {
            budget != nil && place != nil && duration != nil && !times.isEmpty && mood != nil && unknown.isEmpty
        }
    }

    public static func parse(_ tags: String) -> Parsed {
        var result = Parsed()
        for token in tags.split(separator: " ") {
            switch token {
            case "free": result.budget = .free
            case "low": result.budget = .low
            case "mid": result.budget = .mid
            case "high": result.budget = .high
            case "home": result.place = .home
            case "out": result.place = .out
            case "hour": result.duration = .hour
            case "evening": result.duration = .evening
            case "day": result.duration = .day
            case "weekend": result.duration = .weekend
            case "am": result.times.insert(.morning)
            case "pm": result.times.insert(.afternoon)
            case "night": result.times.insert(.night)
            case "any": result.times.formUnion(TimeOfDay.allCases)
            case "calm": result.mood = .calm
            case "romantic": result.mood = .romantic
            case "active": result.mood = .active
            case "adventure": result.mood = .adventure
            case "creative": result.mood = .creative
            case "hot": result.intimate = true
            default: result.unknown.append(String(token))
            }
        }
        return result
    }

    /// Stable identifier from a title: "Picnic en el parque" → "picnic-en-el-parque".
    public static func slug(_ title: String) -> String {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        let parts = folded.lowercased().split { !($0.isLetter || $0.isNumber) }
        return parts.joined(separator: "-")
    }
}

/// Catalog entry builder: `P("🍿", "Título", "Descripción.", "Truco.", "Qué necesitáis", "free home evening night calm")`.
func P(_ emoji: String, _ title: String, _ summary: String, _ tip: String, _ needs: String = "", _ tags: String) -> Plan {
    let parsed = PlanTags.parse(tags)
    return Plan(
        id: PlanTags.slug(title), emoji: emoji, title: title, summary: summary, tip: tip, needs: needs,
        budget: parsed.budget ?? .free, place: parsed.place ?? .home, duration: parsed.duration ?? .evening,
        times: parsed.times.isEmpty ? Set(TimeOfDay.allCases) : parsed.times, mood: parsed.mood ?? .calm,
        intimate: parsed.intimate
    )
}
