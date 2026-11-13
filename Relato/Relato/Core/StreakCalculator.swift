import Foundation

enum StreakCalculator {
    /// Consecutive days with at least one activity, ending today (or yesterday, so the streak
    /// does not look broken before you have recorded today).
    static func currentStreak(activityDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(activityDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func count(activityDates: [Date], inLastDays days: Int, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else { return 0 }
        return activityDates.filter { $0 >= start && $0 <= now }.count
    }
}
