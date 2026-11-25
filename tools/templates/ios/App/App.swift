import SwiftUI

@main
struct __name__App: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // Automático / Claro / Oscuro, chosen in Ajustes → Apariencia (nil follows the iPhone).
                .preferredColorScheme(model.appearance.colorScheme)
                .tint(Palette.accent)
        }
    }
}

enum AppTab: Hashable {
    case home, settings
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .home

    var body: some View {
        // Native iOS 26 tab bar: Liquid Glass, drag across it to switch tabs, and it shrinks into a capsule
        // while scrolling (kept full-size under UI tests so every tab stays tappable).
        TabView(selection: $tab) {
            Tab("Inicio", systemImage: "house.fill", value: AppTab.home) { HomeView() }
            Tab("Ajustes", systemImage: "gearshape.fill", value: AppTab.settings) { SettingsView() }
        }
        .tabBarMinimizeBehavior(LaunchOptions.isUITesting ? .never : .onScrollDown)
        .sensoryFeedback(.selection, trigger: tab) { _, _ in model.hapticsOn }
        .onOpenURL { url in
            // __scheme__://settings opens the settings tab; anything else goes home.
            guard url.scheme == "__scheme__" else { return }
            tab = url.host() == "settings" ? .settings : .home
        }
    }
}
