import Foundation
import Observation
import UserNotifications

/// App-wide settings. They persist in UserDefaults; UI tests get a fresh, separate store every launch.
@Observable
@MainActor
final class AppModel {
    private let defaults: UserDefaults

    var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.haptics) } }
    var remindersOn: Bool { didSet { defaults.set(remindersOn, forKey: Keys.reminders) } }
    /// Hour of the reminder the day before leaving (0…23).
    var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) } }
    var hidePacked: Bool { didSet { defaults.set(hidePacked, forKey: Keys.hidePacked) } }

    /// Set by the widget / `mochila://new` to open the new-trip sheet.
    var pendingNewTrip: TripType?
    var showNewTrip = false

    private enum Keys {
        static let haptics = "settings.haptics", reminders = "settings.reminders", reminderHour = "settings.reminderHour"
        static let hidePacked = "list.hidePacked"
    }

    init(defaults: UserDefaults = LaunchOptions.defaults) {
        self.defaults = defaults
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        remindersOn = defaults.object(forKey: Keys.reminders) as? Bool ?? true
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 20
        hidePacked = defaults.object(forKey: Keys.hidePacked) as? Bool ?? false
    }

    func reset() {
        hapticsOn = true
        remindersOn = true
        reminderHour = 20
        hidePacked = false
    }

    func startNewTrip(_ type: TripType? = nil) {
        pendingNewTrip = type
        showNewTrip = true
    }
}

/// "Mañana sales a Cádiz": one notification the day before each upcoming trip.
enum Reminders {
    static let prefix = "mochila.trip."

    struct Upcoming: Sendable {
        let id: UUID
        let name: String
        let start: Date
        let remaining: Int
    }

    static func sync(_ trips: [Upcoming], enabled: Bool, hour: Int, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled, !trips.isEmpty, !LaunchOptions.isUITesting else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let calendar = Calendar.current
        for trip in trips {
            guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: trip.start)),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayBefore),
                  fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "🎒 Mañana sales: \(trip.name)"
            content.body = trip.remaining == 0
                ? "Tu mochila está lista. ¡Buen viaje!"
                : "Te faltan \(trip.remaining) \(trip.remaining == 1 ? "cosa" : "cosas") por meter. Repasa la lista."
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            try? await center.add(UNNotificationRequest(identifier: prefix + trip.id.uuidString, content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
    }
}
