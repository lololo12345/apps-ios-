import SwiftData
import Foundation

/// Example stories so a first-time user sees a finished script, a draft and a half-written one.
@MainActor
enum SampleContent {
    static func insert(into context: ModelContext) {
        let storytime = StoryTemplate.storytime
        let terror = StoryTemplate.all.first { $0.id == "terror" } ?? storytime

        let neighbor = storytime.instantiate(in: context, targetSeconds: 60, title: "La vecina del 4ºB")
        neighbor.genre = .mystery
        fill(neighbor, with: [
            "Durante tres años saludé cada mañana a una vecina que, según el casero, nunca existió.",
            "Me mudé a un edificio viejo en el centro. En el cuarto piso solo había dos puertas: la mía y la del 4ºB.",
            "Cada mañana, a las 7:40, una señora mayor salía del 4ºB con un abrigo verde. Me sonreía, me decía «buen día, hijo» y bajaba por las escaleras. Nunca usaba el ascensor. Nunca la vi volver.",
            "El día que me mudé, le pregunté al casero por ella para despedirme. Me miró raro y me dijo que el 4ºB lleva vacío desde 1987… desde que murió la señora Elvira.",
            "Esa noche encontré, en mi buzón, un abrigo verde perfectamente doblado.",
            "¿Tú qué crees que era? Te leo en comentarios.",
        ])
        neighbor.status = .ready
        neighbor.isPinned = true
        neighbor.updatedAt = .now.addingTimeInterval(-3_600)

        let wedding = storytime.instantiate(in: context, targetSeconds: 90, title: "El día que me equivoqué de boda")
        wedding.genre = .humor
        fill(wedding, with: [
            "Fui a una boda, comí, bailé, lloré en el discurso… y no conocía a nadie.",
            "Mi primo se casaba un sábado a las seis en una finca a las afueras. Llegué tarde, vi globos blancos, música y gente arreglada. Entré.",
            "Nadie me preguntó nada. Me sentaron en la mesa 9 con unos señores encantadores. Brindé por los novios sin mirarlos mucho. Hasta me tocó el ramo, que lo cogí yo, claro.",
            "A las diez me llama mi madre: «¿Dónde estás? Tu primo está preguntando por ti.» Miro a la novia por primera vez. No la había visto en mi vida.",
            "La finca de al lado tenía otra boda. Mi primo todavía no me lo perdona… pero la otra novia me invitó a su aniversario.",
            "Cuéntame tu peor confusión en comentarios.",
        ])
        wedding.updatedAt = .now.addingTimeInterval(-86_400)

        let attic = terror.instantiate(in: context, targetSeconds: 60, title: "Lo que encontré en el desván")
        fill(attic, with: [
            "Mi abuela me dejó una casa y una sola condición: no subir nunca al desván.",
            "La casa estaba en un pueblo de 200 habitantes. La primera noche escuché pasos justo encima de mi habitación.",
        ])
        attic.updatedAt = .now.addingTimeInterval(-3 * 86_400)

        for (offset, text) in [
            "Un taxista me contó que llevó a un pasajero que no se reflejaba en el retrovisor.",
            "Mi primer día en un call center: la llamada de las 3:00 de la madrugada.",
            "El vecino que deja notas anónimas en el ascensor… y siempre acierta.",
        ].enumerated() {
            let idea = Idea(text: text)
            idea.createdAt = .now.addingTimeInterval(Double(-offset) * 7_200)
            context.insert(idea)
        }

        try? context.save()
    }

    private static func fill(_ story: Story, with texts: [String]) {
        for (beat, text) in zip(story.orderedBeats, texts) {
            beat.text = text
        }
    }
}
