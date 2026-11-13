import Foundation
import UserNotifications

/// Daily "time to tell a story" local notification.
enum ReminderScheduler {
    static let identifier = "relato.daily-reminder"

    private static let messages: [(String, String)] = [
        ("Hora de contar una historia", "Tu audiencia está esperando la parte 2. Abre Relato y graba una toma."),
        ("¿Tienes 10 minutos?", "Un gancho potente y una toma. Es todo lo que necesitas hoy."),
        ("No rompas la racha", "Graba aunque sea un ensayo: la constancia es lo que hace crecer tu canal."),
    ]

    /// Returns whether notifications are allowed. Only prompts the first time; afterwards it reports the current choice.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let message = messages[Calendar.current.component(.weekday, from: .now) % messages.count]
        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
