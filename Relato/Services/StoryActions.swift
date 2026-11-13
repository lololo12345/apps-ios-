import SwiftData
import SwiftUI

/// Mutations that touch more than one model or the file system, kept out of the views.
@MainActor
enum StoryActions {
    static func delete(_ story: Story, in context: ModelContext) {
        for take in story.takes ?? [] {
            TakeStorage.delete(fileName: take.fileName)
        }
        context.delete(story)
        try? context.save()
    }

    static func delete(_ take: Take, in context: ModelContext) {
        TakeStorage.delete(fileName: take.fileName)
        take.story?.takes?.removeAll { $0.id == take.id }
        context.delete(take)
        try? context.save()
    }

    static func delete(_ beat: Beat, from story: Story, in context: ModelContext) {
        story.beats?.removeAll { $0.id == beat.id }
        context.delete(beat)
        story.normalizeOrder()
        story.touch()
    }

    @discardableResult
    static func duplicate(_ story: Story, in context: ModelContext) -> Story {
        let copy = Story(title: story.displayTitle + " (copia)", genre: story.genre, targetSeconds: story.targetSeconds)
        context.insert(copy)
        for beat in story.orderedBeats {
            copy.appendBeat(beat.kind, text: beat.text, prompt: beat.prompt)
        }
        return copy
    }

    /// Turns a captured idea into a story: the idea becomes the hook and a short title is derived from it.
    @discardableResult
    static func makeStory(from idea: Idea, in context: ModelContext, targetSeconds: Int) -> Story {
        let text = idea.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let story = StoryTemplate.storytime.instantiate(
            in: context,
            targetSeconds: targetSeconds,
            title: suggestedTitle(from: text),
            hook: text
        )
        context.delete(idea)
        try? context.save()
        return story
    }

    static func suggestedTitle(from text: String) -> String {
        let firstSentence = PartSplitter.sentences(in: text).first ?? text
        let words = firstSentence
            .trimmingCharacters(in: CharacterSet(charactersIn: "¿¡«»\"“”"))
            .split(whereSeparator: \.isWhitespace)
        let title = words.prefix(7).joined(separator: " ")
        let cleaned = title.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        guard let first = cleaned.first else { return "" }
        return first.uppercased() + cleaned.dropFirst() + (words.count > 7 ? "…" : "")
    }

    /// Promotes status after a recording, never demotes (a published story stays published).
    static func markRecorded(_ story: Story) {
        if story.status < .recorded { story.status = .recorded }
        story.touch()
    }

    static func deleteEverything(in context: ModelContext) {
        try? context.delete(model: Take.self)
        try? context.delete(model: Beat.self)
        try? context.delete(model: Story.self)
        try? context.delete(model: Idea.self)
        try? context.save()
        TakeStorage.deleteAll()
    }
}
