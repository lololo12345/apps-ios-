import SwiftUI

@main
struct BastionApp: App {
    @State private var model = AppModel()
    @State private var game = GameModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            GameScreen(game: game)
                .environment(model)
                // Automático / Claro / Oscuro, chosen in Ajustes → Apariencia (nil follows the iPhone).
                .preferredColorScheme(model.appearance.colorScheme)
                .tint(Palette.accent)
        }
        .onChange(of: phase) { _, newPhase in
            // Save when leaving the app; on return, finished crafts and the garden catch up.
            if newPhase == .background { game.save() }
            if newPhase == .active { game.state.catchUp() }
        }
    }
}
