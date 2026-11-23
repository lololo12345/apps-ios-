import Foundation

/// Builds the packing list for a trip from its type and options.
enum PackingGenerator {
    /// Days of clothes to pack: one outfit per day, capped (four with a washing machine, ten otherwise).
    static func clothesDays(_ options: TripOptions) -> Int {
        let days = max(1, min(options.days, TripOptions.maxDays))
        return min(days, options.laundry ? 4 : 10)
    }

    static func items(for type: TripType, options: TripOptions) -> [PackEntry] {
        var list: [PackEntry] = []
        func add(_ name: String, _ category: PackCategory, quantity: Int? = nil, note: String? = nil) {
            list.append(PackEntry(name, category, quantity: quantity, note: note))
        }
        let days = max(1, min(options.days, TripOptions.maxDays))
        let outfits = clothesDays(options)
        let liquidNote = options.flying && options.carryOnOnly ? "En botes de 100 ml dentro de una bolsa transparente" : nil

        // Documents and money
        add("DNI o pasaporte", .documents)
        add("Tarjetas y algo de efectivo", .documents)
        add("Llaves de casa", .documents)
        if options.flying {
            add("Tarjeta de embarque", .documents, note: "En el móvil o impresa")
        }
        if days >= 3 || options.flying {
            add("Tarjeta sanitaria", .documents)
        }
        if type == .city || type == .festival {
            add("Entradas y reservas", .documents, note: "Descárgalas por si no hay cobertura")
        }

        // Clothes
        add("Ropa interior", .clothes, quantity: min(outfits + 1, 11))
        add("Calcetines", .clothes, quantity: min(outfits + 1, 11))
        add("Camisetas", .clothes, quantity: outfits)
        add("Pantalones", .clothes, quantity: min(max(1, Int((Double(days) / 3).rounded(.up))), 4))
        add("Pijama", .clothes)
        add("Calzado cómodo", .clothes)
        switch options.climate {
        case .cold:
            add("Abrigo", .clothes)
            add("Jerséis", .clothes, quantity: min(max(1, Int((Double(days) / 3).rounded(.up))), 4))
            add("Gorro y guantes", .clothes)
        case .mild:
            add("Chaqueta ligera", .clothes)
            add("Sudadera", .clothes)
        case .hot:
            add("Pantalones cortos", .clothes, quantity: min(max(1, Int((Double(days) / 2).rounded(.up))), 5))
            add("Gafas de sol", .clothes)
            add("Gorra o sombrero", .clothes)
        }
        if options.rain || type == .festival {
            add("Chubasquero", .clothes)
        }
        if options.rain && type != .festival {
            add("Paraguas plegable", .clothes)
        }

        // Toiletries
        add("Cepillo y pasta de dientes", .toiletries, note: liquidNote)
        add("Desodorante", .toiletries, note: liquidNote)
        add("Champú y gel", .toiletries, note: liquidNote)
        add("Peine o cepillo", .toiletries)
        if days >= 3 {
            add("Maquinilla de afeitar", .toiletries)
        }
        if options.climate == .hot || [.beach, .mountain, .snow, .festival].contains(type) {
            add("Crema solar", .toiletries, note: liquidNote)
        }
        add("Pañuelos", .toiletries)

        // Electronics
        add("Móvil y cargador", .electronics)
        add("Batería externa", .electronics)
        add("Auriculares", .electronics)
        if options.flying {
            add("Adaptador de enchufe", .electronics, note: "Si vas a un país con otro enchufe")
        }

        // First aid
        add("Medicinas habituales", .health)
        add("Analgésicos", .health)
        add("Tiritas", .health)
        if [.mountain, .camping, .beach].contains(type) {
            add("Repelente de mosquitos", .health)
        }

        // Specific to the kind of trip
        switch type {
        case .beach:
            add("Bañador", .beach, quantity: days >= 4 ? 2 : 1)
            add("Toalla de playa", .beach)
            add("Chanclas", .beach)
            add("Aftersun", .beach, note: liquidNote)
            add("Bolsa de playa", .beach)
            add("Gafas de sol", .beach)
        case .mountain:
            add("Botas de montaña", .outdoors)
            add("Mochila pequeña", .outdoors)
            add("Forro polar", .outdoors)
            add("Cantimplora", .outdoors)
            add("Linterna frontal", .outdoors)
            add("Mapa sin conexión", .outdoors, note: "Descárgalo antes de ir")
        case .city:
            add("Zapatillas cómodas para andar", .extras)
            add("Mochila o bolso antirrobo", .extras)
        case .weekend:
            add("Gafas de sol", .extras)
            add("Cargador del coche", .electronics)
        case .business:
            add("Traje o ropa formal", .work)
            add("Zapatos de vestir", .work)
            add("Portátil y cargador", .work)
            add("Documentos de la reunión", .work)
        case .camping:
            add("Tienda de campaña", .camping)
            add("Saco de dormir", .camping)
            add("Esterilla", .camping)
            add("Linterna", .camping)
            add("Hornillo y gas", .camping)
            add("Mechero", .camping)
            add("Cazo y cubiertos", .camping)
            add("Papel higiénico", .camping)
            add("Bolsas de basura", .camping)
        case .snow:
            add("Ropa térmica", .snow, quantity: min(max(1, Int((Double(days) / 2).rounded(.up))), 4))
            add("Chaqueta y pantalón de esquí", .snow)
            add("Guantes de nieve", .snow)
            add("Braga de cuello", .snow)
            add("Gafas de ventisca", .snow)
            add("Protector labial", .snow)
            add("Forfait", .snow)
        case .festival:
            add("Entrada o pulsera", .festival)
            add("Tapones para los oídos", .festival)
            add("Riñonera", .festival)
            add("Toallitas húmedas", .festival)
            add("Batería externa de sobra", .festival)
        }

        // Who comes along
        if options.kids {
            add("Ropa de cambio para los peques", .kids, quantity: outfits)
            add("Juguetes y algo para el viaje", .kids)
            add("Snacks", .kids)
            add("Medicinas de los niños", .kids)
            add("Toallitas húmedas", .kids)
        }
        if options.pet {
            add("Comida y cuencos", .pet)
            add("Correa", .pet)
            add("Bolsas para recoger", .pet)
            add("Cartilla y chip", .pet)
            add("Su manta o juguete", .pet)
        }

        // Extras
        add("Botella de agua reutilizable", .extras)
        if days >= 3 {
            add("Bolsa para la ropa sucia", .extras)
        }
        if options.flying {
            add("Algo para leer o ver", .extras)
        }

        // Before leaving home (tasks, not things)
        add("Cerrar ventanas y persianas", .beforeLeaving)
        add("Desenchufar electrodomésticos", .beforeLeaving)
        add("Sacar la basura", .beforeLeaving)
        add("Vaciar la nevera de lo que caduca", .beforeLeaving)
        if days >= 4 {
            add("Regar las plantas o dejarlas encargadas", .beforeLeaving)
            add("Cerrar la llave del agua", .beforeLeaving)
        }
        if days >= 7 {
            add("Dejar una copia de las llaves a alguien de confianza", .beforeLeaving)
        }
        if options.flying {
            add("Hacer el check-in online", .beforeLeaving)
            add("Comprobar la hora del vuelo", .beforeLeaving)
        }

        return deduplicated(list)
    }

    /// The same thing can come from two rules ("Gafas de sol" for heat and for the beach): keep the first.
    static func deduplicated(_ list: [PackEntry]) -> [PackEntry] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.name.lowercased()).inserted }
    }
}

/// How much of the list is done.
struct PackProgress: Equatable, Sendable {
    let done: Int
    let total: Int

    init(done: Int, total: Int) {
        self.done = min(done, total)
        self.total = total
    }

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    var isComplete: Bool { total > 0 && done >= total }
    var remaining: Int { total - done }
    var text: String { "\(done) de \(total)" }
}

/// "Faltan 3 días", "Sales mañana", "Día 2 de 5"…
enum TripCountdown {
    static func text(start: Date, days: Int, now: Date = .now, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let first = calendar.startOfDay(for: start)
        let diff = calendar.dateComponents([.day], from: today, to: first).day ?? 0
        switch diff {
        case 1...: return diff == 1 ? "Sales mañana" : "Faltan \(diff) días"
        case 0: return "Hoy sales"
        default:
            let day = -diff + 1
            return day <= days ? "Día \(day) de \(days)" : "Viaje terminado"
        }
    }

    /// The trip is over (its last day has passed).
    static func isOver(start: Date, days: Int, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let end = calendar.date(byAdding: .day, value: max(days, 1), to: calendar.startOfDay(for: start)) ?? start
        return now >= end
    }
}

/// Plain-text list to send by WhatsApp or keep in Notes.
enum PackingShare {
    static func text(title: String, subtitle: String, entries: [(entry: PackEntry, done: Bool)]) -> String {
        var lines = ["🎒 \(title)", subtitle, ""]
        let grouped = Dictionary(grouping: entries, by: \.entry.category)
        for category in PackCategory.allCases {
            guard let items = grouped[category], !items.isEmpty else { continue }
            lines.append(category.title.uppercased())
            for item in items {
                lines.append("\(item.done ? "☑︎" : "☐") \(item.entry.label)")
            }
            lines.append("")
        }
        lines.append("Hecho con Mochila")
        return lines.joined(separator: "\n")
    }
}
