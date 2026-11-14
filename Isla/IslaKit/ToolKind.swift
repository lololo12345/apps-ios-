import SwiftUI

public enum ToolCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case time, move, home, health, fun, work
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .time: "Tiempo"
        case .move: "Movimiento"
        case .home: "Casa"
        case .health: "Salud"
        case .fun: "Ocio"
        case .work: "Trabajo y estudio"
        }
    }
}

/// The 30 tools. Raw values are stable (stored in sessions and favourites).
public enum ToolKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case timer, pomodoro, stopwatch, nap, presentation, turnClock, worldClock, movie
    case busStop, backToCar, speed, parking, flight
    case shopping, recipe, appliance, charging, postIt
    case pill, fasting, breathing, workout, sinceLast
    case score, referee, counter, expense
    case task, flashcards, nextEvent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .timer: "Temporizadores"
        case .pomodoro: "Modo foco"
        case .stopwatch: "Cronómetro"
        case .nap: "Siesta perfecta"
        case .presentation: "Presentación"
        case .turnClock: "Reloj de turnos"
        case .worldClock: "Hora en otra ciudad"
        case .movie: "Peli o serie"
        case .busStop: "Avísame en mi parada"
        case .backToCar: "Volver al coche"
        case .speed: "Velocidad y distancia"
        case .parking: "Ticket de aparcamiento"
        case .flight: "Vuelo o tren"
        case .shopping: "Lista de la compra"
        case .recipe: "Receta paso a paso"
        case .appliance: "Electrodomésticos"
        case .charging: "Cargando"
        case .postIt: "Post-it"
        case .pill: "Pastilla o rutina"
        case .fasting: "Ayuno"
        case .breathing: "Respiración"
        case .workout: "Entreno por series"
        case .sinceLast: "Desde la última vez"
        case .score: "Marcador"
        case .referee: "Árbitro"
        case .counter: "Contador"
        case .expense: "Gasto"
        case .task: "Tarea fija"
        case .flashcards: "Tarjetas de estudio"
        case .nextEvent: "Próxima cita"
        }
    }

    public var summary: String {
        switch self {
        case .timer: "Varios a la vez, con pausa y +1 min desde la isla."
        case .pomodoro: "Trabajo y descanso alternos con anillo de progreso."
        case .stopwatch: "Marca vueltas sin abrir la app."
        case .nap: "20 o 90 minutos y te despierta."
        case .presentation: "Tiempo y ritmo: en qué parte deberías ir."
        case .turnClock: "Como un reloj de ajedrez para juegos de mesa."
        case .worldClock: "La hora de otra ciudad, siempre a la vista."
        case .movie: "A qué hora termina y cuánto falta."
        case .busStop: "Te avisa al acercarte a tu parada."
        case .backToCar: "A cuántos metros está tu coche."
        case .speed: "Velocidad, distancia y tiempo en vivo."
        case .parking: "Cuenta atrás del ticket y aviso antes de que caduque."
        case .flight: "Embarque, puerta y asiento siempre a mano."
        case .shopping: "El siguiente producto y «Cogido»."
        case .recipe: "El paso actual con su temporizador."
        case .appliance: "Lavadora, horno, lavavajillas…"
        case .charging: "Hasta cuándo carga el coche o el patinete."
        case .postIt: "Un dato fijado: pedido, puerta, matrícula."
        case .pill: "Cuenta atrás hasta la próxima toma."
        case .fasting: "Horas de ayuno y fase con anillo."
        case .breathing: "Inspira y espira guiado."
        case .workout: "Serie hecha y el descanso empieza solo."
        case .sinceLast: "Cuenta hacia arriba desde la última vez."
        case .score: "Puntos, o pádel y tenis con 15-30-40."
        case .referee: "Dado, moneda y a quién le toca."
        case .counter: "+ y − desde la isla."
        case .expense: "Suma lo que gastas contra tu presupuesto."
        case .task: "La tarea que tienes entre manos y «Hecho»."
        case .flashcards: "Pregunta, respuesta y «la sabía»."
        case .nextEvent: "Tu próxima cita del calendario."
        }
    }

    public var symbol: String {
        switch self {
        case .timer: "timer"
        case .pomodoro: "brain.head.profile"
        case .stopwatch: "stopwatch.fill"
        case .nap: "bed.double.fill"
        case .presentation: "person.wave.2.fill"
        case .turnClock: "hourglass"
        case .worldClock: "globe.europe.africa.fill"
        case .movie: "popcorn.fill"
        case .busStop: "bus.fill"
        case .backToCar: "car.fill"
        case .speed: "figure.run"
        case .parking: "parkingsign.circle.fill"
        case .flight: "airplane"
        case .shopping: "cart.fill"
        case .recipe: "frying.pan.fill"
        case .appliance: "washer.fill"
        case .charging: "bolt.car.fill"
        case .postIt: "note.text"
        case .pill: "pills.fill"
        case .fasting: "fork.knife.circle.fill"
        case .breathing: "wind"
        case .workout: "dumbbell.fill"
        case .sinceLast: "clock.arrow.circlepath"
        case .score: "sportscourt.fill"
        case .referee: "dice.fill"
        case .counter: "plus.forwardslash.minus"
        case .expense: "eurosign.circle.fill"
        case .task: "checkmark.circle.fill"
        case .flashcards: "rectangle.on.rectangle.angled"
        case .nextEvent: "calendar"
        }
    }

    public var category: ToolCategory {
        switch self {
        case .timer, .pomodoro, .stopwatch, .nap, .turnClock, .worldClock, .movie: .time
        case .busStop, .backToCar, .speed, .parking, .flight: .move
        case .shopping, .recipe, .appliance, .charging, .postIt: .home
        case .pill, .fasting, .breathing, .workout, .sinceLast: .health
        case .score, .referee, .counter, .expense: .fun
        case .task, .flashcards, .nextEvent, .presentation: .work
        }
    }

    /// Tint as RGB hex (shared with the widget extension).
    public var tintHex: UInt32 {
        switch category {
        case .time: 0xFF9F0A
        case .move: 0x30D158
        case .home: 0x64D2FF
        case .health: 0xFF375F
        case .fun: 0xBF5AF2
        case .work: 0x0A84FF
        }
    }

    public var tint: Color { Color(hex: tintHex) }
}

public extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
