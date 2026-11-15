import AppIntents
import SwiftUI
import UserNotifications

@main
struct IslaApp: App {
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = AppModel.shared
        // Island buttons wake the app in the background and land here.
        IslaActionRouter.shared.handler = { session, action in
            guard let id = UUID(uuidString: session) else { return }
            await MainActor.run { model.perform(action, on: id) }
        }
        model.location = LocationTracker(model: model)
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Color(hex: 0xFF9F0A))
                .task {
                    guard !LaunchOptions.isUITesting else { return }
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                }
                .task(id: scenePhase) {
                    // While the app is open, keep phase-based tools (breathing, foco…) in step with the clock.
                    while scenePhase == .active && !Task.isCancelled {
                        model.tick()
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
        }
    }
}

extension AppModel {
    /// Advances anything whose island text depends on the clock (only while the app runs).
    func tick(now: Date = .now) {
        for session in sessions {
            switch session.state {
            case .pomodoro(let p) where p.paused == nil && p.phaseEnd <= now:
                perform("tick", on: session.id, now: now)
            case .breathing(let b):
                let before = b.pattern.phase(at: max(0, now.timeIntervalSince(b.start) - 1)).index
                let after = b.pattern.phase(at: max(0, now.timeIntervalSince(b.start))).index
                if before != after || (now >= b.end && now.timeIntervalSince(b.end) < 1.5) { update(session.id, now: now) { _ in } }
            case .steps(let s):
                if let rest = s.restEnd, rest <= now { perform("skipRest", on: session.id, now: now) }
            case .countdown(let c) where c.paused == nil && c.end <= now && now.timeIntervalSince(c.end) < 1.5:
                // Just finished: switch the island to «Se acabó» while the app is open.
                update(session.id, now: now) { _ in }
            case .countdown(let c) where session.kind == .presentation && c.paused == nil:
                // Pace text ("deberías ir por la 3") changes at part boundaries.
                let elapsed = c.total - c.remaining(now)
                let slice = c.total / Double(max(c.parts, 1))
                if slice > 0, elapsed.truncatingRemainder(dividingBy: slice) < 1 { update(session.id, now: now) { _ in } }
            default:
                break
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var path = NavigationPath()
    @State private var showFavorites = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(showFavorites: $showFavorites)
                .navigationDestination(for: ToolKind.self) { ToolSetupView(kind: $0) }
        }
        .onOpenURL { url in handle(url) }
    }

    /// isla://start/timer?minutes=5 · isla://favorites · isla://session/<id>
    private func handle(_ url: URL) {
        guard url.scheme == "isla" else { return }
        switch url.host() {
        case "start":
            let minutes = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "minutes" }?.value.flatMap(Double.init) ?? 5
            model.start(.timer, title: "Temporizador", state: .countdown(CountdownState(total: minutes * 60, now: .now)))
            path = NavigationPath()
        case "favorites":
            path = NavigationPath()
            showFavorites = true
        default:
            path = NavigationPath()
        }
    }
}

/// Shows alerts (timer finished, your stop…) even while Isla is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

/// «Oye Siri, temporizador en Isla».
struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Temporizador en la isla"
    static let description = IntentDescription("Arranca un temporizador en la Isla Dinámica.")
    static let openAppWhenRun = false

    @Parameter(title: "Minutos", default: 5, inclusiveRange: (1, 600)) var minutes: Int
    @Parameter(title: "Nombre", default: "Temporizador") var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppModel.shared.start(.timer, title: name, state: .countdown(CountdownState(total: Double(minutes) * 60, now: .now)))
        return .result(dialog: "\(name): \(minutes) minutos en la isla.")
    }
}

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Modo foco en la isla"
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppModel.shared.start(.pomodoro, title: "Foco", state: .pomodoro(PomodoroState(phaseEnd: .now.addingTimeInterval(25 * 60))))
        return .result(dialog: "25 minutos de foco. ¡A por ello!")
    }
}

struct IslaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTimerIntent(), phrases: ["Temporizador en \(.applicationName)", "Pon un temporizador en \(.applicationName)"],
                    shortTitle: "Temporizador", systemImageName: "timer")
        AppShortcut(intent: StartFocusIntent(), phrases: ["Modo foco en \(.applicationName)", "Empieza a concentrarme con \(.applicationName)"],
                    shortTitle: "Modo foco", systemImageName: "brain.head.profile")
    }
}
