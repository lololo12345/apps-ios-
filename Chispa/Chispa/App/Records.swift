import Foundation
import SwiftData

/// One daily challenge the player has opened. It exists from the moment the timer starts, so leaving the
/// app does not give a second chance: coming back resumes the same attempt.
@Model
final class ChallengeRecord {
    var day: Int
    var kindRaw: String
    var startedAt: Date
    var finishedAt: Date?
    var fraction: Double
    var points: Int
    var seconds: Double
    var usedHint: Bool

    init(day: Int, kind: ChallengeKind, startedAt: Date = .now) {
        self.day = day
        self.kindRaw = kind.rawValue
        self.startedAt = startedAt
        self.finishedAt = nil
        self.fraction = 0
        self.points = 0
        self.seconds = 0
        self.usedHint = false
    }

    var kind: ChallengeKind { ChallengeKind(rawValue: kindRaw) ?? .riddle }
    var isFinished: Bool { finishedAt != nil }

    var summary: ResultSummary {
        ResultSummary(day: day, kind: kind, fraction: fraction, points: points, seconds: seconds, usedHint: usedHint)
    }
}

/// A friend added from a shared code. Updated every time they send a newer code.
@Model
final class FriendRecord {
    @Attribute(.unique) var playerID: String
    var name: String
    var week: Int
    var days: [Int]
    var streak: Int
    var day: Int
    var grid: String
    var updatedAt: Date

    init(card: LeagueCard) {
        playerID = card.playerID
        name = card.name
        week = card.week
        days = card.days
        streak = card.streak
        day = card.day
        grid = card.grid
        updatedAt = .now
    }

    func update(from card: LeagueCard) {
        name = card.name
        // An older code never overwrites newer data.
        guard card.week > week || (card.week == week && card.day >= day) else { return }
        week = card.week
        days = card.days
        streak = card.streak
        day = card.day
        grid = card.grid
        updatedAt = .now
    }

    var card: LeagueCard {
        LeagueCard(playerID: playerID, name: name, week: week, days: days, streak: streak, day: day, grid: grid)
    }
}
