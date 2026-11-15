import AudioToolbox
import Foundation
import GameKit
import UIKit
import UserNotifications

/// Daily reminder: one notification per day for the next two weeks, skipping today once it is done.
enum Reminders {
    static let prefix = "chispa.reminder."

    static func schedule(enabled: Bool, minutes: Int, skipToday: Bool, streak: Int, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        let calendar = Calendar.current
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                  fire > now, !(offset == 0 && skipToday) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "⚡ Tu reto de hoy te espera"
            content.body = streak > 0 && offset == 0
                ? "Llevas \(streak) \(streak == 1 ? "día" : "días") de racha. ¡No la pierdas!"
                : "Cinco retos nuevos: acertijo, cultura, cálculo, memoria y lógica."
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(identifier: prefix + "\(offset)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }
}

/// Game Center leaderboard. Off by default: it needs a paid Apple developer account and the leaderboard
/// "chispa.weekly" created in App Store Connect. Set `ChispaGameCenterEnabled` to YES in Info.plist to use it.
@MainActor
enum GameCenter {
    static let leaderboardID = "chispa.weekly"

    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "ChispaGameCenterEnabled") as? Bool ?? false
    }

    static func authenticate() {
        guard isEnabled, !LaunchOptions.isUITesting else { return }
        GKLocalPlayer.local.authenticateHandler = { _, _ in }
    }

    static func submit(weekPoints: Int) {
        guard isEnabled, GKLocalPlayer.local.isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(weekPoints, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID])
        }
    }
}

/// Short system sounds for right and wrong answers.
@MainActor
enum Sounds {
    static func play(correct: Bool, enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(correct ? 1407 : 1053)
    }

    static func tap(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1104)
    }
}
