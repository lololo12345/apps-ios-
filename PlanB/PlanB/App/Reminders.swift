import Foundation
import UserNotifications

struct ReminderSettings: Codable, Equatable {
    var enabled = false
    /// Calendar weekday: 1 = Sunday … 7 = Saturday.
    var weekday = 6
    var hour = 19
    var minute = 0

    static let weekdayNames = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    var weekdayName: String { Self.weekdayNames[(weekday - 1 + 7) % 7] }
    var timeText: String { String(format: "%02d:%02d", hour, minute) }
}

/// Weekly "noche de cita" notification.
enum ReminderScheduler {
    static let identifier = "planb.date-night"

    static func apply(_ settings: ReminderSettings, names: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard settings.enabled else { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Noche de cita 💘"
        content.body = "\(names), abrid Plan B y que decida por vosotros."
        content.sound = .default
        var components = DateComponents()
        components.weekday = settings.weekday
        components.hour = settings.hour
        components.minute = settings.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }
}
