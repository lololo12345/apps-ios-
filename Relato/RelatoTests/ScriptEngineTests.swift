import Foundation
import Testing
@testable import Relato

@Suite("ScriptMetrics")
struct ScriptMetricsTests {
    @Test func countsWordsIgnoringPunctuationTokens() {
        #expect(ScriptMetrics.wordCount("") == 0)
        #expect(ScriptMetrics.wordCount("   \n ") == 0)
        #expect(ScriptMetrics.wordCount("Hola — adiós …") == 2)
        #expect(ScriptMetrics.wordCount("¿Sabías que nadie volvió?") == 4)
        #expect(ScriptMetrics.wordCount("En 1987,\nmurió.") == 3)
    }

    @Test func estimatesSpokenTimeFromRate() {
        let text = Array(repeating: "palabra", count: 150).joined(separator: " ")
        #expect(abs(ScriptMetrics.spokenSeconds(text, wordsPerMinute: 150) - 60) < 0.001)
        #expect(abs(ScriptMetrics.spokenSeconds(text, wordsPerMinute: 75) - 120) < 0.001)
        #expect(ScriptMetrics.spokenSeconds(text, wordsPerMinute: 0) == 0)
        #expect(ScriptMetrics.spokenSeconds("", wordsPerMinute: 150) == 0)
    }

    @Test func addsTimeForPauseMarkers() {
        #expect(ScriptMetrics.pauseCount("Y entonces… nada... [pausa] [PAUSA]") == 4)
        let plain = ScriptMetrics.spokenSeconds("uno dos tres", wordsPerMinute: 60)
        let paused = ScriptMetrics.spokenSeconds("uno… dos tres", wordsPerMinute: 60)
        #expect(abs(paused - plain - ScriptMetrics.pauseSeconds) < 0.001)
    }

    @Test func formatsClock() {
        #expect(ScriptMetrics.clock(0) == "0:00")
        #expect(ScriptMetrics.clock(59.6) == "1:00")
        #expect(ScriptMetrics.clock(125) == "2:05")
        #expect(ScriptMetrics.clock(-3) == "0:00")
        #expect(ScriptMetrics.shortDuration(8.2) == "8 s")
        #expect(ScriptMetrics.shortDuration(65) == "1:05")
    }

    @Test func normalizesForMatching() {
        #expect(ScriptMetrics.tokens("¿Jamás MURIÓ?") == ["jamas", "murio"])
    }
}

@Suite("HookAnalyzer")
struct HookAnalyzerTests {
    @Test func emptyHookScoresZero() {
        let report = HookAnalyzer.analyze("  ", wordsPerMinute: 150)
        #expect(report.score == 0)
        #expect(report.grade == .empty)
    }

    @Test func greetingOpenerIsWeak() {
        let report = HookAnalyzer.analyze("Hola chicos, hoy les voy a contar algo", wordsPerMinute: 150)
        #expect(report.grade == .weak)
        #expect(report.insights.contains { $0.id == "opener" && !$0.isPositive })
    }

    @Test func curiosityQuestionIsStrong() {
        let report = HookAnalyzer.analyze("¿Sabías que nadie ha vuelto de esta casa?", wordsPerMinute: 150)
        #expect(report.grade == .strong)
        #expect(report.score >= 70)
        #expect(report.insights.contains { $0.id == "question" })
        #expect(report.insights.contains { $0.id == "tension" && $0.isPositive })
    }

    @Test func longHookIsPenalized() {
        let long = "Esta es una historia que me pasó hace mucho tiempo en un pueblo pequeño donde vivía con mis padres y mis hermanos"
        let report = HookAnalyzer.analyze(long, wordsPerMinute: 150)
        #expect(report.seconds > HookAnalyzer.maxSeconds)
        #expect(report.insights.contains { $0.id == "length" && !$0.isPositive })
    }

    @Test func positiveInsightsComeFirst() {
        let report = HookAnalyzer.analyze("Perdí 3.000 € por no hacer una pregunta.", wordsPerMinute: 150)
        let firstNegative = report.insights.firstIndex { !$0.isPositive } ?? report.insights.count
        let leading = report.insights[..<firstNegative].map(\.isPositive)
        #expect(!leading.contains(false))
        #expect(report.insights.contains { $0.id == "number" })
    }

    @Test func scoreIsAlwaysClamped() {
        for text in ["a", "Hola hola hola", "¿Tú sabías que en 1959 nadie murió de verdad por un secreto prohibido?"] {
            let score = HookAnalyzer.analyze(text, wordsPerMinute: 150).score
            #expect((0...100).contains(score))
        }
    }
}

@Suite("PartSplitter")
struct PartSplitterTests {
    @Test func splitsSentencesOnPunctuationAndNewlines() {
        let sentences = PartSplitter.sentences(in: "Hola. ¿Qué tal?\nBien… gracias! «Vale.» Fin")
        #expect(sentences == ["Hola.", "¿Qué tal?", "Bien…", "gracias!", "«Vale.»", "Fin"])
    }

    @Test func keepsDecimalsTogether() {
        #expect(PartSplitter.sentences(in: "Costó 3.50 euros. Barato.") == ["Costó 3.50 euros.", "Barato."])
    }

    @Test func emptyScriptHasNoParts() {
        #expect(PartSplitter.split([], maxSeconds: 60, wordsPerMinute: 150).isEmpty)
        #expect(PartSplitter.split([ScriptSegment(kind: .hook, text: "  ")], maxSeconds: 60, wordsPerMinute: 150).isEmpty)
    }

    @Test func shortScriptIsSinglePartFinale() {
        let parts = PartSplitter.split([ScriptSegment(kind: .hook, text: "Una frase. Otra frase.")], maxSeconds: 60, wordsPerMinute: 150)
        #expect(parts.count == 1)
        #expect(parts[0].ending == .finale)
        #expect(parts[0].number == 1)
    }

    @Test func respectsBudgetPerPart() {
        // 20 sentences of 10 words = 4 s each at 150 wpm → 80 s total; budget 29 s fits 7 sentences.
        let sentence = "uno dos tres cuatro cinco seis siete ocho nueve diez."
        let text = Array(repeating: sentence, count: 20).joined(separator: " ")
        let parts = PartSplitter.split([ScriptSegment(kind: .free, text: text)], maxSeconds: 31, wordsPerMinute: 150, reserveSeconds: 2)
        #expect(parts.map(\.sentences.count) == [7, 7, 6])
        for part in parts { #expect(part.seconds <= 29) }
        #expect(parts.map(\.number) == [1, 2, 3])
        #expect(parts.last?.ending == .finale)
        #expect(parts.reduce(0) { $0 + $1.sentences.count } == 20)
    }

    @Test func flagsSentencesLongerThanBudget() {
        let huge = Array(repeating: "palabra", count: 100).joined(separator: " ") + "."
        let parts = PartSplitter.split([ScriptSegment(kind: .free, text: huge)], maxSeconds: 15, wordsPerMinute: 150)
        #expect(parts.count == 1)
        #expect(parts[0].exceedsLimit)
    }

    @Test func detectsCliffhangers() {
        #expect(PartSplitter.isCliffhanger("¿Y sabes quién estaba detrás?"))
        #expect(PartSplitter.isCliffhanger("Abrí la puerta y…"))
        #expect(PartSplitter.isCliffhanger("Y entonces escuché mi nombre."))
        #expect(!PartSplitter.isCliffhanger("Al final todo salió bien."))
    }

    @Test func tracksBeatKindsPerPart() {
        let segments = [
            ScriptSegment(kind: .hook, text: "Gancho corto."),
            ScriptSegment(kind: .context, text: "Contexto corto."),
        ]
        let parts = PartSplitter.split(segments, maxSeconds: 60, wordsPerMinute: 150)
        #expect(parts.first?.kinds == [.hook, .context])
    }
}

@Suite("PrompterPacing")
struct PrompterPacingTests {
    let pacing = PrompterPacing(segmentSeconds: [10, 20], segmentOffsets: [0, 100], endOffset: 400)

    @Test func interpolatesBetweenAnchors() {
        #expect(pacing.totalTime == 30)
        #expect(pacing.offset(at: 0) == 0)
        #expect(pacing.offset(at: 5) == 50)
        #expect(pacing.offset(at: 10) == 100)
        #expect(pacing.offset(at: 20) == 250)
        #expect(pacing.offset(at: 30) == 400)
    }

    @Test func clampsOutsideRange() {
        #expect(pacing.offset(at: -4) == 0)
        #expect(pacing.offset(at: 99) == 400)
        #expect(pacing.time(atOffset: -10) == 0)
        #expect(pacing.time(atOffset: 9_999) == 30)
    }

    @Test func inverseMappingRoundTrips() {
        for time in stride(from: 0.0, through: 30, by: 2.5) {
            #expect(abs(pacing.time(atOffset: pacing.offset(at: time)) - time) < 0.0001)
        }
    }

    @Test func reportsActiveSegment() {
        #expect(pacing.segmentIndex(at: 0) == 0)
        #expect(pacing.segmentIndex(at: 9.9) == 0)
        #expect(pacing.segmentIndex(at: 10) == 1)
        #expect(pacing.segmentIndex(at: 30) == 1)
    }

    @Test func enforcesMinimumSegmentTime() {
        let tiny = PrompterPacing(segmentSeconds: [0, 0], segmentOffsets: [0, 10], endOffset: 20)
        #expect(tiny.totalTime == 2 * PrompterPacing.minimumSegmentSeconds)
    }
}

@Suite("StreakCalculator")
struct StreakCalculatorTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    func day(_ offset: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    @Test func countsConsecutiveDaysEndingToday() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = [day(0, from: now), day(-1, from: now), day(-2, from: now), day(-4, from: now)]
        #expect(StreakCalculator.currentStreak(activityDates: dates, now: now, calendar: calendar) == 3)
    }

    @Test func yesterdayKeepsStreakAlive() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = [day(-1, from: now), day(-2, from: now)]
        #expect(StreakCalculator.currentStreak(activityDates: dates, now: now, calendar: calendar) == 2)
    }

    @Test func gapBreaksStreak() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(StreakCalculator.currentStreak(activityDates: [day(-2, from: now)], now: now, calendar: calendar) == 0)
        #expect(StreakCalculator.currentStreak(activityDates: [], now: now, calendar: calendar) == 0)
    }

    @Test func multipleTakesSameDayCountOnce() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = [now, now.addingTimeInterval(-60), now.addingTimeInterval(-120)]
        #expect(StreakCalculator.currentStreak(activityDates: dates, now: now, calendar: calendar) == 1)
        #expect(StreakCalculator.count(activityDates: dates, inLastDays: 7, now: now, calendar: calendar) == 3)
    }
}

@Suite("ScriptExporter")
struct ScriptExporterTests {
    @Test func exportIncludesHeadersAndSkipsEmptyBeats() {
        let text = ScriptExporter.plainText(
            title: "Mi historia",
            segments: [
                ScriptSegment(kind: .hook, text: "Nadie me creyó."),
                ScriptSegment(kind: .context, text: "   "),
                ScriptSegment(kind: .twist, text: "Era verdad."),
            ],
            wordsPerMinute: 150
        )
        #expect(text.hasPrefix("MI HISTORIA"))
        #expect(text.contains("— GANCHO"))
        #expect(text.contains("— GIRO"))
        #expect(!text.contains("— CONTEXTO"))
        #expect(text.contains("5 palabras"))
    }

    @Test func partTextAddsContinuationExceptForFinale() {
        let parts = PartSplitter.split(
            [ScriptSegment(kind: .free, text: Array(repeating: "uno dos tres cuatro cinco seis siete ocho nueve diez.", count: 12).joined(separator: " "))],
            maxSeconds: 30,
            wordsPerMinute: 150
        )
        #expect(parts.count >= 2)
        #expect(ScriptExporter.partText(title: "T", part: parts[0], totalParts: parts.count).contains("Sigue en la parte 2"))
        #expect(!ScriptExporter.partText(title: "T", part: parts[parts.count - 1], totalParts: parts.count).contains("Sigue en"))
    }
}
