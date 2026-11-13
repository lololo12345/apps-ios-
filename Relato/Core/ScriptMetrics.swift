import Foundation

/// Immutable snapshot of a beat, decoupled from SwiftData so the engines are pure and testable.
struct ScriptSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: BeatKind
    let text: String

    init(id: UUID = UUID(), kind: BeatKind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// Spoken-time estimation for scripts.
enum ScriptMetrics {
    static let defaultWordsPerMinute: Double = 150
    static let wordsPerMinuteRange: ClosedRange<Double> = 110...210
    /// Extra time added for every explicit pause marker ("…", "..." or "[pausa]").
    static let pauseSeconds: Double = 0.6

    /// Counts tokens that contain at least one letter or digit, so stray punctuation ("—", "…") is not a word.
    static func wordCount(_ text: String) -> Int {
        var count = 0
        var inWord = false
        var tokenHasAlphanumeric = false
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if inWord, tokenHasAlphanumeric { count += 1 }
                inWord = false
                tokenHasAlphanumeric = false
            } else {
                inWord = true
                if CharacterSet.alphanumerics.contains(scalar) { tokenHasAlphanumeric = true }
            }
        }
        if inWord, tokenHasAlphanumeric { count += 1 }
        return count
    }

    static func pauseCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let ellipsis = text.filter { $0 == "…" }.count
        let dots = text.components(separatedBy: "...").count - 1
        let markers = text.lowercased().components(separatedBy: "[pausa]").count - 1
        return ellipsis + dots + markers
    }

    static func spokenSeconds(_ text: String, wordsPerMinute: Double) -> Double {
        guard wordsPerMinute > 0 else { return 0 }
        let words = Double(wordCount(text))
        guard words > 0 else { return 0 }
        return words / wordsPerMinute * 60 + Double(pauseCount(text)) * pauseSeconds
    }

    static func spokenSeconds(_ segments: [ScriptSegment], wordsPerMinute: Double) -> Double {
        segments.reduce(0) { $0 + spokenSeconds($1.text, wordsPerMinute: wordsPerMinute) }
    }

    static func wordCount(_ segments: [ScriptSegment]) -> Int {
        segments.reduce(0) { $0 + wordCount($1.text) }
    }

    /// "m:ss" clock formatting, rounding to the nearest second.
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Compact human label: "8 s", "1:05".
    static func shortDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return total < 60 ? "\(total) s" : clock(seconds)
    }

    /// Text folded for keyword matching: lowercase, no diacritics.
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }

    static func tokens(_ text: String) -> [String] {
        normalized(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
