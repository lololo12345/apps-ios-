import SwiftData
import SwiftUI

/// Proven short-form story structures. Each beat carries a writing prompt specific to the template.
struct StoryTemplate: Identifiable, Sendable {
    struct BeatBlueprint: Sendable {
        let kind: BeatKind
        let prompt: String
    }

    let id: String
    let name: String
    let summary: String
    let symbol: String
    let genre: StoryGenre
    let beats: [BeatBlueprint]

    static let all: [StoryTemplate] = [
        StoryTemplate(
            id: "storytime",
            name: "Storytime clásico",
            summary: "La estructura que más retiene: gancho, tensión y un giro final.",
            symbol: "bubble.left.and.text.bubble.right.fill",
            genre: .storytime,
            beats: [
                .init(kind: .hook, prompt: "Empieza por el momento más intenso: «El día que me echaron de mi propia boda…»"),
                .init(kind: .context, prompt: "¿Dónde estabas y con quién? Dos frases como máximo."),
                .init(kind: .rising, prompt: "Las cosas empiezan a torcerse. ¿Qué detalle raro notaste?"),
                .init(kind: .twist, prompt: "La revelación. Lo que nadie esperaba."),
                .init(kind: .payoff, prompt: "Cómo terminó todo y cómo te sentiste."),
                .init(kind: .cta, prompt: "«¿Qué habrías hecho tú? Te leo en comentarios.»"),
            ]
        ),
        StoryTemplate(
            id: "mystery",
            name: "Misterio sin resolver",
            summary: "Pistas, teorías y una pregunta abierta que dispara los comentarios.",
            symbol: "magnifyingglass",
            genre: .mystery,
            beats: [
                .init(kind: .hook, prompt: "El dato imposible: «En 1959, nueve excursionistas salieron de sus tiendas descalzos…»"),
                .init(kind: .context, prompt: "Fecha, lugar y protagonistas."),
                .init(kind: .rising, prompt: "Las pistas, de la más normal a la más inquietante."),
                .init(kind: .twist, prompt: "La teoría más fuerte… y por qué no encaja del todo."),
                .init(kind: .cta, prompt: "Deja la pregunta abierta: «¿Tú qué crees que pasó?»"),
            ]
        ),
        StoryTemplate(
            id: "terror",
            name: "Terror en 60 segundos",
            summary: "Atmósfera rápida, escalada y un susto final que obliga a volver a verlo.",
            symbol: "moon.haze.fill",
            genre: .terror,
            beats: [
                .init(kind: .hook, prompt: "«Vivo solo. Anoche alguien me dio las buenas noches.»"),
                .init(kind: .context, prompt: "La normalidad antes del miedo: tu casa, tu rutina."),
                .init(kind: .rising, prompt: "Primera señal. Algo pequeño, casi explicable."),
                .init(kind: .rising, prompt: "Segunda señal. Ya no tiene explicación."),
                .init(kind: .twist, prompt: "El susto. Frases cortas. Pausas… [pausa]"),
                .init(kind: .cta, prompt: "«Si quieres saber qué había en el armario, parte 2.»"),
            ]
        ),
        StoryTemplate(
            id: "lesson",
            name: "Lección personal",
            summary: "Un error real, lo que aprendiste y por qué le importa a quien mira.",
            symbol: "graduationcap.fill",
            genre: .lesson,
            beats: [
                .init(kind: .hook, prompt: "«Perdí 3.000 € por no hacer una pregunta.»"),
                .init(kind: .context, prompt: "La situación y lo que creías en ese momento."),
                .init(kind: .twist, prompt: "El error. Sin adornos."),
                .init(kind: .payoff, prompt: "La lección, en una frase que se pueda citar."),
                .init(kind: .cta, prompt: "«Guárdalo para cuando lo necesites.»"),
            ]
        ),
        StoryTemplate(
            id: "pov",
            name: "POV / Confesión",
            summary: "Primera persona, directo y emocional. Ideal para formatos cortos.",
            symbol: "person.wave.2.fill",
            genre: .love,
            beats: [
                .init(kind: .hook, prompt: "«POV: tu ex te escribe después de 2 años y…»"),
                .init(kind: .rising, prompt: "Lo que pasó por tu cabeza, en orden."),
                .init(kind: .twist, prompt: "Lo que hiciste (o lo que te contestó)."),
                .init(kind: .payoff, prompt: "El final, corto y con emoción."),
            ]
        ),
        StoryTemplate(
            id: "blank",
            name: "En blanco",
            summary: "Solo un gancho y un bloque libre. Para cuando ya lo tienes en la cabeza.",
            symbol: "square.and.pencil",
            genre: .storytime,
            beats: [
                .init(kind: .hook, prompt: ""),
                .init(kind: .free, prompt: ""),
            ]
        ),
    ]

    static var storytime: StoryTemplate { all[0] }

    /// Creates and inserts a new story built from this template.
    @MainActor
    @discardableResult
    func instantiate(in context: ModelContext, targetSeconds: Int, title: String = "", hook: String = "") -> Story {
        let story = Story(title: title, genre: genre, targetSeconds: targetSeconds)
        context.insert(story)
        for (index, blueprint) in beats.enumerated() {
            let text = (index == 0 && blueprint.kind == .hook) ? hook : ""
            story.appendBeat(blueprint.kind, text: text, prompt: blueprint.prompt)
        }
        return story
    }
}
