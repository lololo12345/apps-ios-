import SwiftData
import SwiftUI

@main
struct RelatoApp: App {
    private let persistence: Persistence
    @State private var router = AppRouter()

    init() {
        persistence = Persistence.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView(storeRecoveryNotice: persistence.recoveryNotice)
                .environment(router)
                .tint(Palette.ember)
                .modifier(ForcedAppearance())
        }
        .modelContainer(persistence.container)
    }
}

/// Builds the SwiftData stack and recovers from an unreadable store instead of crashing at launch.
struct Persistence {
    let container: ModelContainer
    let recoveryNotice: String?

    static let schema = Schema([Story.self, Beat.self, Take.self, Idea.self])

    /// One container per process, shared by the UI and by App Intents (Siri, Shortcuts, Action Button),
    /// so an idea saved from Siri shows up in the app immediately.
    @MainActor static let shared = make()

    @MainActor
    static func make() -> Persistence {
        if LaunchOptions.isUITesting {
            let container = inMemoryContainer()
            SampleContent.insert(into: container.mainContext)
            return Persistence(container: container, recoveryNotice: nil)
        }

        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return Persistence(container: try ModelContainer(for: schema, configurations: configuration), recoveryNotice: nil)
        } catch {
            // The store could not be opened (e.g. corrupted). Keep the old files aside so nothing is
            // silently destroyed, then start a fresh store.
            let storeURL = configuration.url
            let backup = storeURL.deletingLastPathComponent()
                .appending(path: "Relato-recuperado-\(Int(Date.now.timeIntervalSince1970)).store")
            try? FileManager.default.moveItem(at: storeURL, to: backup)
            if let container = try? ModelContainer(for: schema, configurations: configuration) {
                return Persistence(
                    container: container,
                    recoveryNotice: "No se pudo abrir tu biblioteca anterior. Hemos guardado una copia y empezado una nueva."
                )
            }
            return Persistence(
                container: inMemoryContainer(),
                recoveryNotice: "No se pudo acceder al almacenamiento. Los cambios de esta sesión no se guardarán."
            )
        }
    }

    @MainActor
    static func inMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // An in-memory store with a static schema cannot fail; a failure here is a programming error.
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable { case stories, ideas, settings }

    var tab: Tab = .stories
    var storyPath: [Story] = []

    func open(_ story: Story) {
        tab = .stories
        storyPath = [story]
    }
}

/// Applies a forced dark appearance only when requested by a launch argument (screenshots, UI tests).
private struct ForcedAppearance: ViewModifier {
    func body(content: Content) -> some View {
        if LaunchOptions.forceDark {
            content.preferredColorScheme(.dark)
        } else {
            content
        }
    }
}
