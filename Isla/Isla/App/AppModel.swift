import ActivityKit
import Foundation
import Observation
import UserNotifications

enum LaunchOptions {
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

/// A saved setup you can launch with one tap ("Pasta 9 min", "Pádel con Leo").
struct Favorite: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var kind: ToolKind
    var state: ToolState
}

/// Running tools, favourites and their Live Activities. Persisted as JSON so island buttons
/// (which can wake the app in the background) always find the session they act on.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var sessions: [ToolSession] = []
    private(set) var favorites: [Favorite] = []
    var liveActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var activities: [UUID: Activity<IslaAttributes>] = [:]
    @ObservationIgnored var location: LocationTracker?

    private struct Store: Codable {
        var sessions: [ToolSession]
        var favorites: [Favorite]
    }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        storeURL = base.appendingPathComponent(LaunchOptions.isUITesting && directory == nil ? "isla-uitest.json" : "isla.json")
        if LaunchOptions.isUITesting && directory == nil { try? FileManager.default.removeItem(at: storeURL) }
        if let data = try? Data(contentsOf: storeURL), let store = try? JSONDecoder().decode(Store.self, from: data) {
            sessions = store.sessions.filter { !$0.ended }
            favorites = store.favorites
        } else {
            favorites = Self.starterFavorites
        }
        reattachActivities()
    }

    // MARK: Sessions

    @discardableResult
    func start(_ kind: ToolKind, title: String, state: ToolState) -> ToolSession {
        let session = ToolSession(kind: kind, title: title.isEmpty ? kind.title : title, state: state)
        sessions.insert(session, at: 0)
        startActivity(for: session)
        scheduleAlert(for: session)
        if case .location = state { location?.begin(session.id) }
        save()
        return session
    }

    func start(_ favorite: Favorite) {
        start(favorite.kind, title: favorite.name, state: favorite.state.restarted(now: .now))
    }

    func session(_ id: UUID) -> ToolSession? { sessions.first { $0.id == id } }

    /// Island and in-app buttons.
    func perform(_ action: String, on id: UUID, now: Date = .now) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        if action == "nextEvent" {
            advanceEvent(at: index, now: now)
            return
        }
        var session = sessions[index]
        if session.handle(action, now: now) {
            sessions[index] = session
            refresh(session, now: now)
        } else {
            end(id)
        }
        save()
    }

    func end(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let session = sessions.remove(at: index)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [session.id.uuidString])
        if case .location = session.state { location?.end(session.id) }
        if let activity = activities.removeValue(forKey: session.id) {
            let final = ActivityContent(state: IslaAttributes.ContentState(display: session.display()), staleDate: nil)
            Self.withActivity(activity.id) { await $0.end(final, dismissalPolicy: .immediate) }
        }
        save()
    }

    func endAll() {
        for session in sessions { end(session.id) }
    }

    /// Replaces a session's state from a service (location, breathing, calendar).
    func update(_ id: UUID, now: Date = .now, _ change: (inout ToolSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        var session = sessions[index]
        change(&session)
        sessions[index] = session
        refresh(session, now: now)
        save()
    }

    private func refresh(_ session: ToolSession, now: Date) {
        scheduleAlert(for: session, now: now)
        guard let activity = activities[session.id] else { return }
        let display = session.display(now: now)
        let content = ActivityContent(state: IslaAttributes.ContentState(display: display), staleDate: session.staleDate(now: now))
        Self.withActivity(activity.id) { await $0.update(content) }
    }

    private func advanceEvent(at index: Int, now: Date) {
        guard case .event(let current) = sessions[index].state else { return }
        let id = sessions[index].id
        Task {
            guard let next = await CalendarService.nextEvent(after: current.start) else { return }
            update(id, now: now) { $0.state = .event(next); $0.title = next.title }
        }
    }

    // MARK: Favourites

    func addFavorite(name: String, kind: ToolKind, state: ToolState) {
        favorites.insert(Favorite(name: name, kind: kind, state: state), at: 0)
        save()
    }

    func removeFavorites(_ ids: Set<UUID>) {
        favorites.removeAll { ids.contains($0.id) }
        save()
    }

    static let starterFavorites: [Favorite] = [
        Favorite(name: "Pasta", kind: .timer, state: .countdown(CountdownState(total: 9 * 60, now: .now, note: "Al dente"))),
        Favorite(name: "Foco 25/5", kind: .pomodoro, state: .pomodoro(PomodoroState(phaseEnd: .now.addingTimeInterval(25 * 60)))),
        Favorite(name: "Vasos de agua", kind: .counter, state: .counter(CounterState(value: 0, step: 1, goal: 8))),
        Favorite(name: "Lavadora", kind: .appliance, state: .countdown(CountdownState(total: 59 * 60, now: .now))),
    ]

    // MARK: Live Activities

    private func startActivity(for session: ToolSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = IslaAttributes(sessionID: session.id.uuidString, kind: session.kind, title: session.title)
        let content = ActivityContent(state: IslaAttributes.ContentState(display: session.display()), staleDate: session.staleDate())
        if let activity = try? Activity.request(attributes: attributes, content: content, pushType: nil) {
            activities[session.id] = activity
        }
    }

    /// After a relaunch, reconnect to activities that are still on screen.
    private func reattachActivities() {
        for activity in Activity<IslaAttributes>.activities {
            if let id = UUID(uuidString: activity.attributes.sessionID), sessions.contains(where: { $0.id == id }) {
                activities[id] = activity
            } else {
                Self.withActivity(activity.id) { await $0.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    /// Activity objects are not Sendable: look the activity up by id inside the task instead of passing it in.
    private nonisolated static func withActivity(_ id: String, _ body: @escaping @Sendable (Activity<IslaAttributes>) async -> Void) {
        Task.detached {
            for activity in Activity<IslaAttributes>.activities where activity.id == id {
                await body(activity)
            }
        }
    }

    // MARK: Notifications

    private func scheduleAlert(for session: ToolSession, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [session.id.uuidString])
        guard let alert = session.alertDate(now: now), alert.date > now.addingTimeInterval(1) else { return }
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: alert.date.timeIntervalSince(now), repeats: false)
        center.add(UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: trigger))
    }

    // MARK: Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(Store(sessions: sessions, favorites: favorites)) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}

extension ToolState {
    /// Same setup, with every clock starting now (used by favourites).
    func restarted(now: Date) -> ToolState {
        switch self {
        case .countdown(var c):
            c.end = now.addingTimeInterval(c.total); c.paused = nil; c.part = 1
            return .countdown(c)
        case .pomodoro(var p):
            p.phase = .work; p.round = 1; p.completed = 0; p.paused = nil; p.phaseEnd = now.addingTimeInterval(p.work)
            return .pomodoro(p)
        case .stopwatch: return .stopwatch(StopwatchState(start: now))
        case .countUp(var c): c.start = now; c.history = []; return .countUp(c)
        case .counter(var c): c.value = 0; c.log = []; return .counter(c)
        case .steps(var s): s.index = 0; s.set = 1; s.right = 0; s.wrong = 0; s.revealed = false; s.restEnd = nil; s.stepTimerEnd = nil; return .steps(s)
        case .score(var s): s.points = [0, 0]; s.match = RacketScore(); s.pointsHistory = []; s.matchHistory = []; return .score(s)
        case .turnClock(var t):
            let each = t.remaining.max() ?? 300
            t.remaining = Array(repeating: each, count: t.players.count); t.current = 0; t.turnStart = now; t.paused = false
            return .turnClock(t)
        case .location(var l): l.started = now; l.travelled = 0; l.distance = nil; l.alerted = false; return .location(l)
        case .breathing(var b): b.start = now; return .breathing(b)
        default: return self
        }
    }
}
