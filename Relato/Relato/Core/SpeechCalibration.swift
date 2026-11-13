import Foundation

/// Measures a person's natural speaking rate from a timed read-aloud of a known text.
enum SpeechCalibration {
    /// Reading the sample faster than this is not plausible: the person most likely skipped it.
    static let minimumSeconds: Double = 8
    /// Rates outside this window are treated as a mis-tap rather than a real measurement.
    static let plausibleRange: ClosedRange<Double> = 60...320

    static let sampleText = """
    Hace tres años me mudé a un edificio antiguo en el centro de la ciudad. La primera noche escuché pasos \
    en el piso de arriba, aunque el casero me había jurado que estaba vacío. Al día siguiente subí a \
    comprobarlo. La puerta estaba abierta y, sobre la mesa, había una taza de café todavía caliente. \
    Nadie vivía allí. Desde entonces, cada mañana, dejo una taza en mi puerta.
    """

    enum Outcome: Equatable {
        /// Rate rounded to 5 wpm and clamped to the range the app supports.
        case measured(Double)
        case tooFast
        case implausible
    }

    static func evaluate(wordCount: Int, seconds: Double) -> Outcome {
        guard wordCount > 0, seconds >= minimumSeconds else { return .tooFast }
        let raw = Double(wordCount) / seconds * 60
        guard plausibleRange.contains(raw) else { return .implausible }
        let rounded = (raw / 5).rounded() * 5
        let range = ScriptMetrics.wordsPerMinuteRange
        return .measured(min(max(rounded, range.lowerBound), range.upperBound))
    }
}
