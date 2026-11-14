import Foundation

/// Pádel / tenis: 15-30-40, ventaja, juegos, sets y tie-break a 7 con 6-6.
struct RacketScore: Codable, Hashable, Sendable {
    /// Points in the current game (or tie-break) for each side.
    var points = [0, 0]
    var games = [0, 0]
    /// Finished sets, e.g. [[6, 4], [3, 6]].
    var sets: [[Int]] = []
    var tieBreak = false
    /// Sets needed to win the match.
    var setsToWin = 2

    var winner: Int? {
        let won = [0, 1].map { side in sets.filter { $0[side] > $0[1 - side] }.count }
        return won.firstIndex { $0 >= setsToWin }
    }

    mutating func point(_ side: Int) {
        guard winner == nil else { return }
        let other = 1 - side
        points[side] += 1
        if tieBreak {
            if points[side] >= 7 && points[side] - points[other] >= 2 { winGame(side) }
        } else if points[side] >= 4 && points[side] - points[other] >= 2 {
            winGame(side)
        }
    }

    private mutating func winGame(_ side: Int) {
        let other = 1 - side
        points = [0, 0]
        games[side] += 1
        if tieBreak || (games[side] >= 6 && games[side] - games[other] >= 2) {
            sets.append(games)
            games = [0, 0]
            tieBreak = false
        } else if games[0] == 6 && games[1] == 6 {
            tieBreak = true
        }
    }

    /// "15", "40", "AD" (or tie-break numbers).
    func pointLabel(_ side: Int) -> String {
        if tieBreak { return "\(points[side])" }
        let mine = points[side], theirs = points[1 - side]
        if mine >= 3 && theirs >= 3 {
            if mine == theirs { return "40" }
            return mine > theirs ? "AD" : "40"
        }
        return ["0", "15", "30", "40"][min(mine, 3)]
    }

    var setsText: String {
        (sets.map { "\($0[0])-\($0[1])" } + [winner == nil ? "\(games[0])-\(games[1])" : nil].compactMap { $0 }).joined(separator: "  ")
    }
}

/// Fasting phases by hours fasted (approximate, for motivation).
enum FastingPhase {
    static func label(hours: Double) -> String {
        switch hours {
        case ..<4: "Digestión"
        case ..<12: "Bajando el azúcar"
        case ..<16: "Quemando grasa"
        case ..<24: "Cetosis"
        default: "Ayuno largo"
        }
    }
}

/// Breathing patterns: seconds for inhale, hold, exhale, hold.
enum BreathPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm, relax, box
    var id: String { rawValue }
    var title: String {
        switch self {
        case .calm: "Calma (4-6)"
        case .relax: "Relajación (4-7-8)"
        case .box: "Caja (4-4-4-4)"
        }
    }
    var phases: [(label: String, seconds: Double)] {
        switch self {
        case .calm: [("Inspira", 4), ("Espira", 6)]
        case .relax: [("Inspira", 4), ("Aguanta", 7), ("Espira", 8)]
        case .box: [("Inspira", 4), ("Aguanta", 4), ("Espira", 4), ("Aguanta", 4)]
        }
    }
    var cycle: Double { phases.reduce(0) { $0 + $1.seconds } }

    /// Phase at `elapsed` seconds: index, label, start and end offsets.
    func phase(at elapsed: Double) -> (index: Int, label: String, start: Double, end: Double) {
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        let base = elapsed - t
        var cursor = 0.0
        for (index, phase) in phases.enumerated() {
            if t < cursor + phase.seconds { return (index, phase.label, base + cursor, base + cursor + phase.seconds) }
            cursor += phase.seconds
        }
        return (0, phases[0].label, base + cycle, base + cycle + phases[0].seconds)
    }
}

enum Geo {
    /// Metres between two coordinates (haversine).
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180, dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Initial bearing in degrees (0 = north, clockwise).
    static func bearing(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180, Δλ = (lon2 - lon1) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func format(_ metres: Double) -> String {
        metres < 1000 ? "\(Int((metres / 10).rounded() * 10)) m" : String(format: "%.1f km", metres / 1000).replacingOccurrences(of: ".", with: ",")
    }
}

enum Fmt {
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func number(_ value: Double, money: Bool) -> String {
        let text = value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
        return money ? "\(text) €" : text
    }
}
