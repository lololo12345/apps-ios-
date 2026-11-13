import Foundation
import Testing
@testable import Relato

@Suite("SpeechCalibration")
struct SpeechCalibrationTests {
    @Test func sampleTextHasAMeaningfulLength() {
        let words = ScriptMetrics.wordCount(SpeechCalibration.sampleText)
        #expect((50...90).contains(words))
    }

    @Test func measuresAndRoundsToFive() {
        // 70 words in 26 s ≈ 161.5 wpm → 160.
        #expect(SpeechCalibration.evaluate(wordCount: 70, seconds: 26) == .measured(160))
    }

    @Test func clampsToSupportedRange() {
        // 70 words in 15 s = 280 wpm: plausible, but above what the app supports.
        #expect(SpeechCalibration.evaluate(wordCount: 70, seconds: 15) == .measured(ScriptMetrics.wordsPerMinuteRange.upperBound))
        // 70 words in 60 s = 70 wpm: slow but plausible, clamped up to the minimum.
        #expect(SpeechCalibration.evaluate(wordCount: 70, seconds: 60) == .measured(ScriptMetrics.wordsPerMinuteRange.lowerBound))
    }

    @Test func rejectsSkippedReading() {
        #expect(SpeechCalibration.evaluate(wordCount: 70, seconds: 3) == .tooFast)
        #expect(SpeechCalibration.evaluate(wordCount: 0, seconds: 30) == .tooFast)
    }

    @Test func rejectsImplausibleRates() {
        // Forgot to stop the timer: 70 words in 5 minutes = 14 wpm.
        #expect(SpeechCalibration.evaluate(wordCount: 70, seconds: 300) == .implausible)
    }
}
