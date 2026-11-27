import Foundation

/// Everything worth counting, for missions and achievements.
struct Counters: Codable, Equatable, Sendable {
    var gathered: [Item: Int] = [:]
    var crafted: [Item: Int] = [:]
    var coinsEarned = 0
    var enemiesDefeated = 0
    var nightsSurvived = 0
    var goldenTrees = 0
    var requestsDone = 0
    var bestCombo = 0
    var bossesDefeated: Set<EnemyKind> = []

    func gathered(_ item: Item) -> Int { gathered[item, default: 0] }
}

/// What a mission asks for, checked against the game state.
enum Goal: Codable, Equatable, Sendable {
    case gather(Item, Int)
    case earn(Int)
    case gear(Gear, Int)
    case build(Building, Int)
    case craft(Item, Int)
    case surviveNights(Int)
    case bridge(Int)
    case defeat(Int)
    case boss(EnemyKind)
    case request(Int)
}

struct Quest: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let hint: String
    let goal: Goal
    let reward: Int
}

/// The guide: always one next thing to do.
enum Quests {
    static let all: [Quest] = [
        Quest(id: 0, title: "Tala 10 de madera", hint: "Acércate a un árbol: tu Brote lo tala solo.", goal: .gather(.wood, 10), reward: 15),
        Quest(id: 1, title: "Recoge 10 bayas", hint: "Los arbustos con puntitos azules dan bayas.", goal: .gather(.berries, 10), reward: 15),
        Quest(id: 2, title: "Gana 40 monedas en el mercado", hint: "Vuelve a la base: lo que llevas se guarda solo. Vende en el puesto.", goal: .earn(40), reward: 20),
        Quest(id: 3, title: "Mejora la mochila", hint: "Más espacio, menos viajes.", goal: .gear(.backpack, 2), reward: 25),
        Quest(id: 4, title: "Construye el aserradero", hint: "Las tablas valen más que la madera suelta.", goal: .build(.sawmill, 1), reward: 30),
        Quest(id: 5, title: "Fabrica 6 tablas", hint: "Tablas en el taller de la base.", goal: .craft(.planks, 6), reward: 30),
        Quest(id: 6, title: "Sobrevive a una noche", hint: "Al anochecer la Niebla ataca la hoguera. ¡Defiéndela!", goal: .surviveNights(1), reward: 40),
        Quest(id: 7, title: "Construye el puente del río", hint: "Ve al puente marcado en el río con madera, piedra y monedas.", goal: .bridge(0), reward: 60),
        Quest(id: 8, title: "Recoge 6 setas", hint: "Crecen en la sombra del Bosque Viejo.", goal: .gather(.mushroom, 6), reward: 40),
        Quest(id: 9, title: "Derrota 12 criaturas", hint: "Tu Brote ataca solo; usa el golpe fuerte cuando te rodeen.", goal: .defeat(12), reward: 60),
        Quest(id: 10, title: "Construye una torre", hint: "Las torres disparan en los asaltos nocturnos.", goal: .build(.tower, 1), reward: 70),
        Quest(id: 11, title: "Cumple 3 encargos", hint: "Los vecinos piden cosas en el tablón y pagan bien.", goal: .request(3), reward: 80),
        Quest(id: 12, title: "Mejora la espada a nivel 3", hint: "El Gran Lobo no se deja vencer con un palo.", goal: .gear(.sword, 3), reward: 90),
        Quest(id: 13, title: "Vence al Gran Lobo de Humo", hint: "Te espera junto al segundo río. Esquiva su embestida.", goal: .boss(.boss), reward: 300),
    ]
}

/// One-off medals.
struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let goal: Goal

    static let all: [Achievement] = [
        Achievement(id: "lumber", title: "Leñador", detail: "Tala 100 de madera", symbol: "tree.fill", goal: .gather(.wood, 100)),
        Achievement(id: "berries", title: "Dedos azules", detail: "Recoge 100 bayas", symbol: "circle.grid.3x3.fill", goal: .gather(.berries, 100)),
        Achievement(id: "stone", title: "Picapiedra", detail: "Recoge 80 de piedra", symbol: "mountain.2.fill", goal: .gather(.stone, 80)),
        Achievement(id: "gold", title: "Árbol de oro", detail: "Tala un árbol dorado", symbol: "sparkles", goal: .gather(.goldenLog, 1)),
        Achievement(id: "trader", title: "Mercader", detail: "Gana 1.000 monedas", symbol: "dollarsign.circle.fill", goal: .earn(1000)),
        Achievement(id: "chef", title: "Cocinero", detail: "Cocina 10 guisos", symbol: "frying.pan.fill", goal: .craft(.stew, 10)),
        Achievement(id: "builder", title: "Constructor", detail: "Construye el primer puente", symbol: "road.lanes", goal: .bridge(0)),
        Achievement(id: "guard", title: "Vigía", detail: "Sobrevive a 5 noches", symbol: "moon.stars.fill", goal: .surviveNights(5)),
        Achievement(id: "hunter", title: "Cazador de Niebla", detail: "Derrota 50 criaturas", symbol: "bolt.shield.fill", goal: .defeat(50)),
        Achievement(id: "neighbour", title: "Buen vecino", detail: "Cumple 10 encargos", symbol: "hands.sparkles.fill", goal: .request(10)),
        Achievement(id: "wolf", title: "Domador", detail: "Vence al Gran Lobo de Humo", symbol: "crown.fill", goal: .boss(.boss)),
        Achievement(id: "sword", title: "Hoja legendaria", detail: "Espada al nivel máximo", symbol: "star.fill", goal: .gear(.sword, 6)),
    ]
}

/// Something a neighbour asks for on the notice board. Three new ones every day.
struct Request: Identifiable, Codable, Equatable, Sendable {
    let id: Int
    let neighbour: String
    let item: Item
    let amount: Int
    let reward: Int

    static let neighbours = ["Mora", "Tilo", "Abeto", "Nuez", "Lila", "Roble", "Musgo", "Avellana"]

    /// Same three requests for everybody on the same day; harder once the forest is open.
    static func daily(day: Int, forestOpen: Bool) -> [Request] {
        var rng = SplitMix(seed: UInt64(bitPattern: Int64(day)) &* 977 &+ 11)
        let pool: [Item] = forestOpen ? [.wood, .berries, .stone, .mushroom, .planks, .pie, .brick, .stew]
                                      : [.wood, .berries, .stone, .planks, .pie]
        var used: Set<Item> = []
        var result: [Request] = []
        while result.count < 3 {
            let item = pool[Int(rng.next() % UInt64(pool.count))]
            guard used.insert(item).inserted else { continue }
            let amount = item.isCrafted ? 3 + Int(rng.next() % 5) : 8 + Int(rng.next() % 13)
            let name = neighbours[Int(rng.next() % UInt64(neighbours.count))]
            // Pays ~70 % more than the market: worth the trip.
            let reward = Int((Double(item.basePrice * amount) * 1.7).rounded())
            result.append(Request(id: day * 10 + result.count, neighbour: name, item: item, amount: amount, reward: reward))
        }
        return result
    }
}

/// Daily gift: grows with the streak of days in a row, up to the seventh.
enum DailyReward {
    static func coins(streak: Int) -> Int { [20, 30, 40, 55, 70, 90, 150][min(max(streak, 1), 7) - 1] }
}
