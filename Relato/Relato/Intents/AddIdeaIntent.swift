import AppIntents
import SwiftData

/// "Apuntar idea en Relato": capture a story idea from Siri, Shortcuts, Spotlight or the Action Button
/// without opening the app.
struct AddIdeaIntent: AppIntent {
    static var title: LocalizedStringResource { "Apuntar idea" }
    static var description: IntentDescription {
        IntentDescription("Guarda una idea para una historia en tu banco de ideas de Relato.")
    }

    @Parameter(title: "Idea", requestValueDialog: "¿Qué idea quieres guardar?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let idea = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idea.isEmpty else {
            return .result(dialog: "No había ninguna idea que guardar.")
        }
        let context = Persistence.shared.container.mainContext
        context.insert(Idea(text: idea))
        try context.save()
        return .result(dialog: "Guardada en tu banco de ideas.")
    }
}

struct RelatoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddIdeaIntent(),
            phrases: [
                "Apuntar idea en \(.applicationName)",
                "Nueva idea en \(.applicationName)",
                "Guardar una idea en \(.applicationName)",
            ],
            shortTitle: "Apuntar idea",
            systemImageName: "lightbulb.max.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .orange }
}
