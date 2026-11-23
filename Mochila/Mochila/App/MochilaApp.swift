import SwiftData
import SwiftUI

@main
struct MochilaApp: App {
    @State private var model = AppModel()
    private let container: ModelContainer

    init() {
        let schema = Schema([Trip.self, PackItem.self, SavedTemplate.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: LaunchOptions.isUITesting, cloudKitDatabase: .none)
        let container = (try? ModelContainer(for: schema, configurations: configuration))
            ?? (try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
        self.container = container
        if LaunchOptions.isUITesting && LaunchOptions.arguments.contains("-seedTrips") {
            TripFactory.seed(in: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.accent)
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case trips, templates, settings
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var tab: AppTab = .trips

    var body: some View {
        @Bindable var model = model
        // Native iOS 26 tab bar: Liquid Glass, drag across it to switch tabs, and it shrinks into a capsule
        // while scrolling (kept full-size under UI tests so every tab stays tappable).
        TabView(selection: $tab) {
            Tab("Viajes", systemImage: "suitcase.rolling.fill", value: AppTab.trips) { TripsView() }
            Tab("Plantillas", systemImage: "square.stack.3d.up.fill", value: AppTab.templates) { TemplatesView() }
            Tab("Ajustes", systemImage: "gearshape.fill", value: AppTab.settings) { SettingsView() }
        }
        .tabBarMinimizeBehavior(LaunchOptions.isUITesting ? .never : .onScrollDown)
        .sensoryFeedback(.selection, trigger: tab) { _, _ in model.hapticsOn }
        .sheet(isPresented: $model.showNewTrip) {
            NewTripView(preset: model.pendingNewTrip)
        }
        .onOpenURL { url in
            // mochila://new opens a new trip (widget); mochila://settings the settings tab.
            guard url.scheme == "mochila" else { return }
            switch url.host() {
            case "settings": tab = .settings
            case "new":
                tab = .trips
                model.startNewTrip()
            default: tab = .trips
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { syncReminders() }
        }
        .onChange(of: trips.map { "\($0.id)\($0.startDate)\($0.progress.remaining)" }) { syncReminders() }
        .onChange(of: model.remindersOn) { syncReminders() }
        .onChange(of: model.reminderHour) { syncReminders() }
    }

    private func syncReminders() {
        let upcoming = trips.filter { !$0.isOver }.map {
            Reminders.Upcoming(id: $0.id, name: $0.name, start: $0.startDate, remaining: $0.progress.remaining)
        }
        let enabled = model.remindersOn, hour = model.reminderHour
        Task { await Reminders.sync(upcoming, enabled: enabled, hour: hour) }
    }
}
