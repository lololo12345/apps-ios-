import Foundation

struct HookReport: Equatable, Sendable {
    enum Grade: Equatable, Sendable {
        case empty, weak, decent, strong

        var title: String {
            switch self {
            case .empty: "Sin gancho"
            case .weak: "Débil"
            case .decent: "Correcto"
            case .strong: "Potente"
            }
        }
    }

    struct Insight: Equatable, Identifiable, Sendable {
        let id: String
        let isPositive: Bool
        let message: String
    }

    let score: Int
    let grade: Grade
    let seconds: Double
    let insights: [Insight]
}

/// Heuristic coach for the first seconds of a short-form story (Spanish-language rules).
enum HookAnalyzer {
    static let idealSeconds: Double = 3.5
    static let maxSeconds: Double = 6

    static let weakOpeners: [String] = [
        "hola", "buenas", "bueno", "que tal", "como estan", "como estais",
        "hoy les voy a contar", "hoy os voy a contar", "hoy te voy a contar", "hoy les traigo", "hoy os traigo",
        "en este video", "les quiero contar", "os quiero contar", "te quiero contar", "voy a contar",
    ]

    static let directAddress: Set<String> = [
        "tu", "te", "ti", "tus", "contigo", "vos", "usted", "ustedes", "imagina", "imaginate", "sabias", "alguna",
    ]

    /// Prefixes so inflections match ("desapareció", "desaparecida"…).
    static let tensionStems: [String] = [
        "nunca", "nadie", "jamas", "secret", "verdad", "prohibid", "error", "peor", "miedo", "raro", "extran",
        "muri", "muert", "desaparec", "mentir", "menti", "oculto", "escondi", "grit", "sangre", "polic",
        "despedi", "enga", "traicion", "ultim", "casi",
    ]

    static let tensionPhrases: [String] = ["lo que", "por que", "de repente", "nadie sabe", "no sabia", "todavia no"]

    static func analyze(_ hook: String, wordsPerMinute: Double) -> HookReport {
        let trimmed = hook.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ScriptMetrics.wordCount(trimmed) > 0 else {
            return HookReport(score: 0, grade: .empty, seconds: 0, insights: [
                .init(id: "empty", isPositive: false, message: "Los primeros 3 segundos deciden si se quedan. Escribe tu gancho."),
            ])
        }

        var score = 45
        var insights: [HookReport.Insight] = []
        let seconds = ScriptMetrics.spokenSeconds(trimmed, wordsPerMinute: wordsPerMinute)
        let tokens = ScriptMetrics.tokens(trimmed)
        let joined = " " + tokens.joined(separator: " ") + " "
        let compact = tokens.joined(separator: " ")

        if seconds <= idealSeconds {
            score += 20
            insights.append(.init(id: "length", isPositive: true, message: "Se dice en \(ScriptMetrics.shortDuration(seconds)): cabe en los primeros 3 segundos."))
        } else if seconds <= maxSeconds {
            score += 5
            insights.append(.init(id: "length", isPositive: false, message: "Dura \(ScriptMetrics.shortDuration(seconds)). Intenta bajar de 3 s quitando palabras de relleno."))
        } else {
            score -= 20
            insights.append(.init(id: "length", isPositive: false, message: "Demasiado largo (\(ScriptMetrics.shortDuration(seconds))). Quédate solo con la idea más impactante."))
        }

        if weakOpeners.contains(where: { compact.hasPrefix($0) }) {
            score -= 30
            insights.append(.init(id: "opener", isPositive: false, message: "Empieza con un saludo o anuncio. Entra directo al conflicto."))
        } else {
            score += 10
            insights.append(.init(id: "opener", isPositive: true, message: "Entra directo, sin saludos."))
        }

        if trimmed.contains("?") {
            score += 10
            insights.append(.init(id: "question", isPositive: true, message: "Plantea una pregunta: activa la curiosidad."))
        }

        if trimmed.contains(where: \.isNumber) {
            score += 8
            insights.append(.init(id: "number", isPositive: true, message: "Un dato concreto da credibilidad."))
        }

        if tokens.contains(where: directAddress.contains) {
            score += 8
            insights.append(.init(id: "you", isPositive: true, message: "Hablas directamente a quien mira."))
        }

        let stem = tokens.first { token in tensionStems.contains { token.hasPrefix($0) } }
        let phrase = tensionPhrases.first { joined.contains(" \($0) ") }
        if let trigger = stem ?? phrase {
            score += 12
            insights.append(.init(id: "tension", isPositive: true, message: "“\(trigger)” genera tensión."))
        } else {
            score -= 5
            insights.append(.init(id: "tension", isPositive: false, message: "Añade tensión: un secreto, un error o algo que salió mal."))
        }

        let clamped = min(100, max(0, score))
        let grade: HookReport.Grade = clamped < 40 ? .weak : (clamped < 70 ? .decent : .strong)
        // Positive insights first reads as encouragement; problems follow as next actions.
        let ordered = insights.filter(\.isPositive) + insights.filter { !$0.isPositive }
        return HookReport(score: clamped, grade: grade, seconds: seconds, insights: ordered)
    }
}
