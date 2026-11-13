import Foundation
import SwiftData
import Testing
@testable import Relato

@MainActor
@Suite("Story model & actions")
struct StoryModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() {
        container = Persistence.inMemoryContainer()
    }

    @Test func templateCreatesOrderedBeatsWithPrompts() throws {
        let template = StoryTemplate.storytime
        let story = template.instantiate(in: context, targetSeconds: 90, title: "Prueba")
        try context.save()

        #expect(story.orderedBeats.map(\.kind) == template.beats.map(\.kind))
        #expect(story.orderedBeats.map(\.order) == Array(0..<template.beats.count))
        #expect(story.orderedBeats.allSatisfy { !$0.placeholder.isEmpty })
        #expect(story.targetSeconds == 90)
        #expect(story.status == .draft)
    }

    @Test func moveAndDeleteKeepDenseOrder() throws {
        let story = StoryTemplate.storytime.instantiate(in: context, targetSeconds: 60)
        let beats = story.orderedBeats
        story.move(beats[0], by: 1)
        #expect(story.orderedBeats.first?.id == beats[1].id)
        #expect(story.orderedBeats[1].id == beats[0].id)

        story.move(story.orderedBeats[0], by: -1) // out of range: no-op
        #expect(story.orderedBeats.first?.id == beats[1].id)

        StoryActions.delete(story.orderedBeats[2], from: story, in: context)
        try context.save()
        #expect(story.orderedBeats.count == beats.count - 1)
        #expect(story.orderedBeats.map(\.order) == Array(0..<(beats.count - 1)))
    }

    @Test func duplicateCopiesContent() throws {
        let story = StoryTemplate.storytime.instantiate(in: context, targetSeconds: 60, title: "Original", hook: "Nadie lo sabía.")
        let copy = StoryActions.duplicate(story, in: context)
        try context.save()
        #expect(copy.id != story.id)
        #expect(copy.title == "Original (copia)")
        #expect(copy.hookText == "Nadie lo sabía.")
        #expect(copy.orderedBeats.count == story.orderedBeats.count)
    }

    @Test func ideaBecomesStoryWithHookAndTitle() throws {
        let idea = Idea(text: "El vecino que deja notas anónimas en el ascensor y siempre acierta. Increíble.")
        context.insert(idea)
        try context.save()

        let story = StoryActions.makeStory(from: idea, in: context, targetSeconds: 60)
        #expect(story.hookText.hasPrefix("El vecino"))
        #expect(story.title == "El vecino que deja notas anónimas en…")
        #expect(try context.fetchCount(FetchDescriptor<Idea>()) == 0)
    }

    @Test func suggestedTitleHandlesShortAndEmptyText() {
        #expect(StoryActions.suggestedTitle(from: "¿quién fue?") == "Quién fue")
        #expect(StoryActions.suggestedTitle(from: "   ") == "")
    }

    @Test func recordingPromotesButNeverDemotesStatus() {
        let story = Story(title: "S", genre: .humor, targetSeconds: 60)
        context.insert(story)
        StoryActions.markRecorded(story)
        #expect(story.status == .recorded)
        story.status = .published
        StoryActions.markRecorded(story)
        #expect(story.status == .published)
    }

    @Test func deletingStoryCascadesBeats() throws {
        let story = StoryTemplate.storytime.instantiate(in: context, targetSeconds: 60)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Beat>()) == StoryTemplate.storytime.beats.count)
        StoryActions.delete(story, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Story>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Beat>()) == 0)
    }

    @Test func sampleContentIsCoherent() throws {
        SampleContent.insert(into: context)
        let stories = try context.fetch(FetchDescriptor<Story>())
        #expect(stories.count == 3)
        #expect(try context.fetchCount(FetchDescriptor<Idea>()) == 3)
        let ready = try #require(stories.first { $0.status == .ready })
        let seconds = ScriptMetrics.spokenSeconds(ready.segments, wordsPerMinute: 150)
        // The "ready" example must actually fit its target, or the demo contradicts the app.
        #expect(seconds <= Double(ready.targetSeconds) + 2)
    }

    @Test func unknownRawValuesFallBackSafely() {
        let story = Story(title: "", genre: .terror, targetSeconds: 60)
        story.genreRaw = "corrupt"
        story.statusRaw = "???"
        #expect(story.genre == .storytime)
        #expect(story.status == .draft)
        #expect(story.displayTitle == "Historia sin título")
    }
}
