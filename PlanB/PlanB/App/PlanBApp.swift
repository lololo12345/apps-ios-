import SwiftData
import SwiftUI

@main
struct PlanBApp: App {
    @State private var state = AppState()
    private let container: ModelContainer

    init() {
        let schema = Schema([Memory.self, CustomPlanRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: LaunchOptions.isUITesting, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            self.container = container
        } else {
            // If the store cannot be opened, keep the app usable with an in-memory one.
            self.container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .tint(Palette.coral)
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case discover, saved, memories, settings
}

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomPlanRecord.createdAt) private var customRecords: [CustomPlanRecord]
    @State private var tab: AppTab = .discover

    var body: some View {
        @Bindable var state = state
        ZStack {
            if state.hasNames {
                TabView(selection: $tab) {
                    Tab("Descubrir", systemImage: "sparkles", value: AppTab.discover) { DiscoverView() }
                    Tab("Guardados", systemImage: "bookmark.fill", value: AppTab.saved) { SavedView() }
                    Tab("Recuerdos", systemImage: "heart.text.square.fill", value: AppTab.memories) { MemoriesView() }
                    Tab("Ajustes", systemImage: "gearshape.fill", value: AppTab.settings) { SettingsView() }
                }
                .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: state.hasNames)
        .sheet(item: $state.presentedPlan) { plan in
            PlanDetailView(plan: plan)
        }
        .onChange(of: customRecords.map(\.id), initial: true) {
            state.customPlans = customRecords.map(\.plan)
        }
        .onOpenURL { url in
            // planb://plan/<id> (from the widget)
            guard url.scheme == "planb", url.host() == "plan", let id = url.pathComponents.dropFirst().first else { return }
            tab = .discover
            state.presentedPlan = state.plan(id: id)
        }
        .task { seedForScreenshots() }
    }

    /// UI tests (-seedMemories): a few memories so the stats and "hace un año" screens have content.
    private func seedForScreenshots() {
        guard LaunchOptions.isUITesting, LaunchOptions.seedMemories else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Memory>())) ?? 0
        guard existing == 0 else { return }
        let calendar = Calendar.current
        let now = Date.now
        let seeds: [(String, Int, Int, String)] = [
            ("picnic-en-el-parque", -2, 5, "El mejor bocadillo de tortilla de la historia."),
            ("ruta-de-senderismo-corta", -9, 4, "Casi no llegamos a la cima, pero mereció la pena."),
            ("cena-con-menu-sorpresa", -16, 5, ""),
            ("subir-a-una-noria", -365, 5, "Nuestra primera foto en lo más alto."),
        ]
        for (id, days, rating, note) in seeds {
            guard let plan = PlanCatalog.plan(id: id), let date = calendar.date(byAdding: .day, value: days, to: now) else { continue }
            context.insert(Memory(plan: plan, doneAt: date, rating: rating, note: note, photo: nil))
        }
        try? context.save()
    }
}
