import Foundation
import SwiftData
import Testing
@testable import Relato

@MainActor
@Suite("AddIdeaIntent")
struct AddIdeaIntentTests {
    /// The test host launches the app with its real store, so count relative to the current state
    /// and clean up what the test inserts.
    @Test func savesTrimmedIdeaInSharedStore() async throws {
        let context = Persistence.shared.container.mainContext
        let marker = "Idea de prueba \(UUID().uuidString)"
        var intent = AddIdeaIntent()
        intent.text = "   \(marker)  \n"
        _ = try await intent.perform()

        let saved = try context.fetch(FetchDescriptor<Idea>(predicate: #Predicate { $0.text == marker }))
        #expect(saved.count == 1)
        for idea in saved { context.delete(idea) }
        try context.save()
    }

    @Test func ignoresEmptyIdea() async throws {
        let context = Persistence.shared.container.mainContext
        let before = try context.fetchCount(FetchDescriptor<Idea>())
        var intent = AddIdeaIntent()
        intent.text = "   "
        _ = try await intent.perform()
        #expect(try context.fetchCount(FetchDescriptor<Idea>()) == before)
    }
}
