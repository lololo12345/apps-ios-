import Foundation

enum ScriptExporter {
    /// Plain-text script with beat headers and spoken-time estimates, ready to paste anywhere.
    static func plainText(title: String, segments: [ScriptSegment], wordsPerMinute: Double) -> String {
        let total = ScriptMetrics.spokenSeconds(segments, wordsPerMinute: wordsPerMinute)
        let words = ScriptMetrics.wordCount(segments)
        var lines: [String] = [
            title.uppercased(),
            "Duración estimada: \(ScriptMetrics.clock(total)) · \(words) palabras",
        ]
        for segment in segments where ScriptMetrics.wordCount(segment.text) > 0 {
            let seconds = ScriptMetrics.spokenSeconds(segment.text, wordsPerMinute: wordsPerMinute)
            lines.append("")
            lines.append("— \(segment.kind.title.uppercased()) (\(ScriptMetrics.shortDuration(seconds)))")
            lines.append(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return lines.joined(separator: "\n")
    }

    /// Text for a single series part, with the part number as an on-screen intro.
    static func partText(title: String, part: StoryPart, totalParts: Int) -> String {
        var lines = ["\(title) — Parte \(part.number)/\(totalParts)", "", part.text]
        if part.ending != .finale {
            lines.append("")
            lines.append("(Sigue en la parte \(part.number + 1))")
        }
        return lines.joined(separator: "\n")
    }
}
