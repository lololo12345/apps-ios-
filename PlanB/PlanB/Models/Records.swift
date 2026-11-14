import Foundation
import SwiftData
import SwiftUI

/// A plan you actually did: the diary of your dates.
@Model
final class Memory {
    var id: UUID = UUID()
    var planID: String = ""
    var title: String = ""
    var emoji: String = ""
    var moodRaw: String = Mood.romantic.rawValue
    var intimate: Bool = false
    var doneAt: Date = Date.now
    /// 0 = not rated, 1…5 hearts.
    var rating: Int = 0
    var note: String = ""
    @Attribute(.externalStorage) var photo: Data?

    init(plan: Plan, doneAt: Date, rating: Int, note: String, photo: Data?) {
        id = UUID()
        planID = plan.id
        title = plan.title
        emoji = plan.emoji
        moodRaw = plan.mood.rawValue
        intimate = plan.intimate
        self.doneAt = doneAt
        self.rating = rating
        self.note = note
        self.photo = photo
    }

    var mood: Mood { Mood(rawValue: moodRaw) ?? .romantic }
    var colors: [Color] { intimate ? [Palette.ember, Palette.plum] : mood.colors }
}

/// A plan written by the couple.
@Model
final class CustomPlanRecord {
    var id: UUID = UUID()
    var emoji: String = "💡"
    var title: String = ""
    var summary: String = ""
    var tip: String = ""
    var budgetRaw: Int = Budget.free.rawValue
    var placeRaw: String = Place.home.rawValue
    var durationRaw: Int = Duration.evening.rawValue
    var moodRaw: String = Mood.romantic.rawValue
    var intimate: Bool = false
    var createdAt: Date = Date.now

    init(emoji: String, title: String, summary: String, tip: String, budget: Budget, place: Place, duration: Duration, mood: Mood, intimate: Bool) {
        id = UUID()
        self.emoji = emoji
        self.title = title
        self.summary = summary
        self.tip = tip
        budgetRaw = budget.rawValue
        placeRaw = place.rawValue
        durationRaw = duration.rawValue
        moodRaw = mood.rawValue
        self.intimate = intimate
        createdAt = .now
    }

    var plan: Plan {
        Plan(
            id: "custom-\(id.uuidString)", emoji: emoji.isEmpty ? "💡" : emoji, title: title, summary: summary, tip: tip,
            budget: Budget(rawValue: budgetRaw) ?? .free, place: Place(rawValue: placeRaw) ?? .home,
            duration: Duration(rawValue: durationRaw) ?? .evening, times: Set(TimeOfDay.allCases),
            mood: Mood(rawValue: moodRaw) ?? .romantic, intimate: intimate, isCustom: true
        )
    }
}

enum CustomPlanRules {
    static let maxTitle = 60
    static let maxSummary = 280

    /// Trims and collapses whitespace; nil when too short to be a plan.
    static func clean(_ raw: String, max: Int) -> String? {
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard text.count >= 3 else { return nil }
        return String(text.prefix(max))
    }

    /// First emoji typed (or the default).
    static func emoji(_ raw: String) -> String {
        let found = raw.first { character in
            guard let scalar = character.unicodeScalars.first else { return false }
            return scalar.properties.isEmojiPresentation || (character.unicodeScalars.count > 1 && scalar.properties.isEmoji)
        }
        return found.map(String.init) ?? "💡"
    }
}
