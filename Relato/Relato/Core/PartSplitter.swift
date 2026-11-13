import Foundation

struct StoryPart: Identifiable, Equatable, Sendable {
    enum Ending: Equatable, Sendable {
        /// Last part of the series.
        case finale
        /// Ends on a question, an ellipsis or an unresolved action: viewers want part N+1.
        case cliffhanger
        /// Ends on a resolved sentence: risk of losing viewers between parts.
        case flat
    }

    let number: Int
    let sentences: [String]
    let seconds: Double
    let kinds: [BeatKind]
    /// A single sentence is longer than the allowed budget and could not be split further.
    let exceedsLimit: Bool
    let ending: Ending

    var id: Int { number }
    var text: String { sentences.joined(separator: " ") }
    var firstLine: String { sentences.first ?? "" }
    var lastLine: String { sentences.last ?? "" }
}

/// Splits a long script into numbered parts for multi-part series ("Parte 1, 2, 3…").
enum PartSplitter {
    /// Seconds reserved per part for "Parte 2…" intros and "sigue en la parte 3" outros.
    static let defaultReserveSeconds: Double = 2

    static let cliffhangerStems: [String] = [
        "entonces", "de repente", "y ahi", "pero", "cuando", "fue cuando", "y vi", "y escuche", "no era",
        "hasta que", "lo que", "abri", "detras", "y alguien",
    ]

    static func split(
        _ segments: [ScriptSegment],
        maxSeconds: Double,
        wordsPerMinute: Double,
        reserveSeconds: Double = defaultReserveSeconds
    ) -> [StoryPart] {
        let budget = max(5, maxSeconds - reserveSeconds)
        var drafts: [(sentences: [String], seconds: Double, kinds: [BeatKind], exceeds: Bool)] = []
        var current: (sentences: [String], seconds: Double, kinds: [BeatKind], exceeds: Bool) = ([], 0, [], false)

        func close() {
            guard !current.sentences.isEmpty else { return }
            drafts.append(current)
            current = ([], 0, [], false)
        }

        for segment in segments {
            for sentence in sentences(in: segment.text) {
                let cost = ScriptMetrics.spokenSeconds(sentence, wordsPerMinute: wordsPerMinute)
                if !current.sentences.isEmpty, current.seconds + cost > budget {
                    close()
                }
                current.sentences.append(sentence)
                current.seconds += cost
                if !current.kinds.contains(segment.kind) { current.kinds.append(segment.kind) }
                if cost > budget { current.exceeds = true }
            }
        }
        close()

        return drafts.enumerated().map { index, draft in
            let isLast = index == drafts.count - 1
            return StoryPart(
                number: index + 1,
                sentences: draft.sentences,
                seconds: draft.seconds,
                kinds: draft.kinds,
                exceedsLimit: draft.exceeds,
                ending: isLast ? .finale : (isCliffhanger(draft.sentences.last ?? "") ? .cliffhanger : .flat)
            )
        }
    }

    static func isCliffhanger(_ sentence: String) -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("?") || trimmed.hasSuffix("…") || trimmed.hasSuffix("...") || trimmed.hasSuffix("?»") || trimmed.hasSuffix("?\"") {
            return true
        }
        let joined = " " + ScriptMetrics.tokens(trimmed).joined(separator: " ") + " "
        return cliffhangerStems.contains { joined.contains(" \($0) ") }
    }

    /// Sentence segmentation tuned for spoken scripts: ., !, ?, … and line breaks end a sentence.
    static func sentences(in text: String) -> [String] {
        let enders: Set<Character> = [".", "!", "?", "…"]
        let closers: Set<Character> = ["\"", "”", "»", ")", "'"]
        let characters = Array(text)
        var result: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if ScriptMetrics.wordCount(trimmed) > 0 {
                result.append(trimmed)
            } else if !trimmed.isEmpty, let last = result.popLast() {
                // Stray punctuation ("…" on its own line) belongs to the previous sentence.
                result.append(last + trimmed)
            }
            current = ""
        }

        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isNewline {
                flush()
                index += 1
                continue
            }
            current.append(character)
            if enders.contains(character) {
                while index + 1 < characters.count,
                      enders.contains(characters[index + 1]) || closers.contains(characters[index + 1]) {
                    index += 1
                    current.append(characters[index])
                }
                if index + 1 == characters.count || characters[index + 1].isWhitespace {
                    flush()
                }
            }
            index += 1
        }
        flush()
        return result
    }
}
