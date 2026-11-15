import SwiftData
import SwiftUI

@main
struct ChispaApp: App {
    private let container: ModelContainer
    @State private var store: GameStore

    init() {
        let schema = Schema([ChallengeRecord.self, FriendRecord.self])
        let uiTesting = LaunchOptions.isUITesting
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: uiTesting, cloudKitDatabase: .none)
        let container = (try? ModelContainer(for: schema, configurations: configuration))
            ?? (try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
        self.container = container

        let defaults: UserDefaults
        if uiTesting {
            UserDefaults().removePersistentDomain(forName: "chispa.uitests")
            defaults = UserDefaults(suiteName: "chispa.uitests") ?? .standard
        } else {
            defaults = .standard
        }
        let store = GameStore(context: container.mainContext, defaults: defaults)
        if uiTesting {
            store.playerName = LaunchOptions.value(after: "-playerName") ?? ""
            if LaunchOptions.seedHistory { store.seedHistory() }
        }
        _store = State(initialValue: store)
        GameCenter.authenticate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Palette.amber)
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case today, league, progress, practice
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today

    var body: some View {
        ZStack {
            if store.playerName.isEmpty {
                OnboardingView()
                    .transition(.opacity)
            } else {
                TabView(selection: $tab) {
                    Tab("Hoy", systemImage: "sparkles", value: AppTab.today) { TodayView() }
                    Tab("Liga", systemImage: "trophy.fill", value: AppTab.league) { LeagueView() }
                    Tab("Progreso", systemImage: "chart.bar.fill", value: AppTab.progress) { StatsView() }
                    Tab("Práctica", systemImage: "dumbbell.fill", value: AppTab.practice) { PracticeView() }
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: store.playerName.isEmpty)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDay() }
        }
        .onOpenURL { url in
            // chispa://today (widget) · chispa://league
            guard url.scheme == "chispa" else { return }
            tab = url.host() == "league" ? .league : .today
        }
        .task {
            store.scheduleReminders()
            // Roll over to the new day at midnight while the app is open.
            while !Task.isCancelled {
                let wait = max(1, store.today.endDate().timeIntervalSinceNow + 1)
                try? await Task.sleep(for: .seconds(min(wait, 3600)))
                store.refreshDay()
            }
        }
    }
}
