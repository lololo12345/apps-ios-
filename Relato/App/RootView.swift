import SwiftData
import SwiftUI

struct RootView: View {
    let storeRecoveryNotice: String?

    @AppStorage(PrefKey.onboardingCompleted) private var onboardingCompleted = LaunchOptions.isUITesting
    @State private var showRecoveryAlert = false

    var body: some View {
        ZStack {
            if onboardingCompleted && !LaunchOptions.forceOnboarding {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingView { onboardingCompleted = true }
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: onboardingCompleted)
        .onAppear { showRecoveryAlert = storeRecoveryNotice != nil }
        .alert("Biblioteca recuperada", isPresented: $showRecoveryAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(storeRecoveryNotice ?? "")
        }
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Historias", systemImage: "book.pages.fill", value: AppRouter.Tab.stories) {
                LibraryView()
            }
            Tab("Ideas", systemImage: "lightbulb.max.fill", value: AppRouter.Tab.ideas) {
                IdeasView()
            }
            Tab("Ajustes", systemImage: "slider.horizontal.3", value: AppRouter.Tab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: router.tab) { Haptics.selection() }
    }
}
