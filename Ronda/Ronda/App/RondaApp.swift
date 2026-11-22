import SwiftData
import SwiftUI

@main
struct RondaApp: App {
    @State private var session = PartySession()
    private let container: ModelContainer

    init() {
        let schema = Schema([CustomCard.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: LaunchOptions.isUITesting, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            self.container = container
        } else {
            // Custom cards are a nice-to-have: if the store cannot be opened, keep playing with an in-memory one.
            // An in-memory store with a static schema cannot fail.
            self.container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(Neon.violet)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(PartySession.self) private var session

    var body: some View {
        ZStack {
            if session.ageStatus == nil {
                AgeGateView()
                    .transition(.opacity)
            } else if !session.setupDone || session.players.count < 2 {
                NavigationStack {
                    PlayersView(isFirstRun: true)
                }
                .transition(.opacity)
            } else {
                RondaTabs()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: session.ageStatus)
        .animation(.smooth(duration: 0.4), value: session.setupDone && session.players.count >= 2)
    }
}

enum RondaTab: Hashable {
    case games, players, scoreboard, settings
}

/// Liquid Glass tab bar: drag across it to switch; it shrinks into a capsule while scrolling the games.
struct RondaTabs: View {
    @State private var tab: RondaTab = .games

    var body: some View {
        TabView(selection: $tab) {
            Tab("Juegos", systemImage: "gamecontroller.fill", value: RondaTab.games) { HomeView() }
            Tab("Jugadores", systemImage: "person.2.fill", value: RondaTab.players) {
                NavigationStack {
                    PlayersView()
                }
            }
            Tab("Marcador", systemImage: "trophy.fill", value: RondaTab.scoreboard) { ScoreboardView(inTab: true) }
            Tab("Ajustes", systemImage: "gearshape.fill", value: RondaTab.settings) { SettingsView(inTab: true) }
        }
        .tabBarMinimizeBehavior(LaunchOptions.isUITesting ? .never : .onScrollDown)
        .sensoryFeedback(.selection, trigger: tab)
    }
}
