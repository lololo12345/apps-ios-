import Foundation
import SwiftData

@Model
final class Story {
    var id: UUID = UUID()
    var title: String = ""
    var genreRaw: String = StoryGenre.storytime.rawValue
    var statusRaw: String = StoryStatus.draft.rawValue
    var targetSeconds: Int = 60
    var isPinned: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Beat.story)
    var beats: [Beat]? = []

    @Relationship(deleteRule: .cascade, inverse: \Take.story)
    var takes: [Take]? = []

    init(title: String, genre: StoryGenre, targetSeconds: Int) {
        self.id = UUID()
        self.title = title
        self.genreRaw = genre.rawValue
        self.statusRaw = StoryStatus.draft.rawValue
        self.targetSeconds = targetSeconds
        self.createdAt = .now
        self.updatedAt = .now
    }

    var genre: StoryGenre {
        get { StoryGenre(rawValue: genreRaw) ?? .storytime }
        set { genreRaw = newValue.rawValue }
    }

    var status: StoryStatus {
        get { StoryStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Historia sin título" : trimmed
    }

    var orderedBeats: [Beat] {
        (beats ?? []).sorted { $0.order < $1.order }
    }

    var orderedTakes: [Take] {
        (takes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// Value snapshot used by the pure script engines.
    var segments: [ScriptSegment] {
        orderedBeats.map { ScriptSegment(id: $0.id, kind: $0.kind, text: $0.text) }
    }

    var hookText: String {
        orderedBeats.first(where: { $0.kind == .hook })?.text ?? ""
    }

    func touch() {
        updatedAt = .now
    }

    @discardableResult
    func appendBeat(_ kind: BeatKind, text: String = "", prompt: String = "") -> Beat {
        let nextOrder = (beats ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let beat = Beat(kind: kind, text: text, prompt: prompt, order: nextOrder)
        if beats == nil { beats = [] }
        beats?.append(beat)
        touch()
        return beat
    }

    /// Re-numbers beat order so it is dense (0, 1, 2…) after moves or deletions.
    func normalizeOrder() {
        for (index, beat) in orderedBeats.enumerated() where beat.order != index {
            beat.order = index
        }
    }

    func move(_ beat: Beat, by delta: Int) {
        var list = orderedBeats
        guard let index = list.firstIndex(where: { $0.id == beat.id }) else { return }
        let target = index + delta
        guard list.indices.contains(target) else { return }
        list.swapAt(index, target)
        for (position, item) in list.enumerated() { item.order = position }
        touch()
    }
}

@Model
final class Beat {
    var id: UUID = UUID()
    var kindRaw: String = BeatKind.free.rawValue
    var text: String = ""
    /// Template-specific writing prompt; falls back to the kind guidance when empty.
    var prompt: String = ""
    var order: Int = 0
    var story: Story?

    init(kind: BeatKind, text: String, prompt: String, order: Int) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.text = text
        self.prompt = prompt
        self.order = order
    }

    var kind: BeatKind {
        get { BeatKind(rawValue: kindRaw) ?? .free }
        set { kindRaw = newValue.rawValue }
    }

    var placeholder: String {
        prompt.isEmpty ? kind.guidance : prompt
    }
}

@Model
final class Take {
    var id: UUID = UUID()
    /// File name inside the app's takes directory (never an absolute path: the container moves between installs).
    var fileName: String = ""
    var durationSeconds: Double = 0
    var createdAt: Date = Date.now
    var savedToPhotos: Bool = false
    var story: Story?

    init(fileName: String, durationSeconds: Double) {
        self.id = UUID()
        self.fileName = fileName
        self.durationSeconds = durationSeconds
        self.createdAt = .now
    }

    var fileURL: URL { TakeStorage.url(for: fileName) }
}

@Model
final class Idea {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date.now

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.createdAt = .now
    }
}
