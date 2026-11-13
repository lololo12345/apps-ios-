import SwiftUI

/// Narrative building block of a short-form story.
enum BeatKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case hook
    case context
    case rising
    case twist
    case payoff
    case cta
    case free

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hook: "Gancho"
        case .context: "Contexto"
        case .rising: "Tensión"
        case .twist: "Giro"
        case .payoff: "Desenlace"
        case .cta: "Cierre"
        case .free: "Bloque libre"
        }
    }

    var symbol: String {
        switch self {
        case .hook: "bolt.fill"
        case .context: "map.fill"
        case .rising: "chart.line.uptrend.xyaxis"
        case .twist: "arrow.triangle.swap"
        case .payoff: "sparkles"
        case .cta: "hand.point.up.left.fill"
        case .free: "text.alignleft"
        }
    }

    /// Writing guidance shown as placeholder when the beat is empty.
    var guidance: String {
        switch self {
        case .hook: "La frase que hace que no deslicen. Sin saludos: entra directo al conflicto."
        case .context: "Quién, dónde y cuándo. Solo lo imprescindible para entender lo que viene."
        case .rising: "Sube la tensión paso a paso. Cada frase debe hacer querer la siguiente."
        case .twist: "El momento que nadie ve venir. Cambia el sentido de todo lo anterior."
        case .payoff: "Resuelve (o deja la duda a propósito). Que se sienta como una recompensa."
        case .cta: "Invita a comentar, seguir o ver la parte 2. Una sola petición, concreta."
        case .free: "Escribe libremente."
        }
    }

    var tint: Color {
        switch self {
        case .hook: Palette.ember
        case .context: Palette.sky
        case .rising: Palette.violet
        case .twist: Palette.magenta
        case .payoff: Palette.amber
        case .cta: Palette.mint
        case .free: Palette.slate
        }
    }
}

enum StoryGenre: String, Codable, CaseIterable, Identifiable, Sendable {
    case storytime
    case terror
    case mystery
    case trueCrime
    case humor
    case love
    case curiosity
    case lesson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .storytime: "Storytime"
        case .terror: "Terror"
        case .mystery: "Misterio"
        case .trueCrime: "True crime"
        case .humor: "Humor"
        case .love: "Amor"
        case .curiosity: "Curiosidades"
        case .lesson: "Lección personal"
        }
    }

    var symbol: String {
        switch self {
        case .storytime: "bubble.left.and.text.bubble.right.fill"
        case .terror: "moon.haze.fill"
        case .mystery: "magnifyingglass"
        case .trueCrime: "exclamationmark.shield.fill"
        case .humor: "face.smiling.inverse"
        case .love: "heart.fill"
        case .curiosity: "lightbulb.max.fill"
        case .lesson: "graduationcap.fill"
        }
    }

    var tint: Color {
        switch self {
        case .storytime: Palette.ember
        case .terror: Palette.violet
        case .mystery: Palette.sky
        case .trueCrime: Palette.crimson
        case .humor: Palette.amber
        case .love: Palette.magenta
        case .curiosity: Palette.mint
        case .lesson: Palette.slate
        }
    }
}

enum StoryStatus: String, Codable, CaseIterable, Identifiable, Sendable, Comparable {
    case draft
    case ready
    case recorded
    case published

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: "Borrador"
        case .ready: "Lista"
        case .recorded: "Grabada"
        case .published: "Publicada"
        }
    }

    var symbol: String {
        switch self {
        case .draft: "pencil.line"
        case .ready: "checkmark.seal.fill"
        case .recorded: "video.fill"
        case .published: "paperplane.fill"
        }
    }

    var tint: Color {
        switch self {
        case .draft: Palette.slate
        case .ready: Palette.mint
        case .recorded: Palette.ember
        case .published: Palette.sky
        }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: StoryStatus, rhs: StoryStatus) -> Bool { lhs.rank < rhs.rank }
}

/// Common short-form durations, in seconds.
enum TargetDuration {
    static let presets: [Int] = [15, 30, 60, 90, 180, 300]

    static func label(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) s" : (seconds % 60 == 0 ? "\(seconds / 60) min" : ScriptMetrics.clock(Double(seconds)))
    }
}
