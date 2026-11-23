import Foundation

/// Kind of trip: decides the specific things to pack.
enum TripType: String, CaseIterable, Codable, Sendable, Identifiable {
    case beach, mountain, city, weekend, business, camping, snow, festival

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beach: "Playa"
        case .mountain: "Montaña"
        case .city: "Ciudad"
        case .weekend: "Escapada"
        case .business: "Trabajo"
        case .camping: "Camping"
        case .snow: "Nieve"
        case .festival: "Festival"
        }
    }

    var symbol: String {
        switch self {
        case .beach: "beach.umbrella.fill"
        case .mountain: "mountain.2.fill"
        case .city: "building.2.fill"
        case .weekend: "car.fill"
        case .business: "briefcase.fill"
        case .camping: "tent.fill"
        case .snow: "snowflake"
        case .festival: "music.note"
        }
    }

    var tintHex: UInt32 {
        switch self {
        case .beach: 0x33C3F0
        case .mountain: 0x5BBF6B
        case .city: 0x9B8CFF
        case .weekend: 0xFFB547
        case .business: 0x8FA3BF
        case .camping: 0xC98A4B
        case .snow: 0x9FDBFF
        case .festival: 0xFF5FA2
        }
    }

    /// Climate suggested when this type is chosen (the user can change it).
    var suggestedClimate: Climate {
        switch self {
        case .beach, .festival: .hot
        case .snow: .cold
        default: .mild
        }
    }
}

enum Climate: String, CaseIterable, Codable, Sendable, Identifiable {
    case cold, mild, hot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cold: "Frío"
        case .mild: "Templado"
        case .hot: "Calor"
        }
    }

    var symbol: String {
        switch self {
        case .cold: "thermometer.snowflake"
        case .mild: "cloud.sun.fill"
        case .hot: "sun.max.fill"
        }
    }
}

/// Everything about the trip that changes the list.
struct TripOptions: Codable, Sendable, Equatable {
    var days = 3
    var climate: Climate = .mild
    var rain = false
    var flying = false
    var carryOnOnly = false
    var kids = false
    var pet = false
    /// There is a washing machine at the destination: clothes are capped at four days' worth.
    var laundry = false
    /// It can freeze at the destination (minimum ≤ 2 °C): thermal layers and a scarf.
    var freezing = false

    static let maxDays = 60
}

extension TripOptions {
    /// Lenient decoding: options saved by an older version (without newer keys) still load.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        days = try values.decodeIfPresent(Int.self, forKey: .days) ?? days
        climate = try values.decodeIfPresent(Climate.self, forKey: .climate) ?? climate
        rain = try values.decodeIfPresent(Bool.self, forKey: .rain) ?? rain
        flying = try values.decodeIfPresent(Bool.self, forKey: .flying) ?? flying
        carryOnOnly = try values.decodeIfPresent(Bool.self, forKey: .carryOnOnly) ?? carryOnOnly
        kids = try values.decodeIfPresent(Bool.self, forKey: .kids) ?? kids
        pet = try values.decodeIfPresent(Bool.self, forKey: .pet) ?? pet
        laundry = try values.decodeIfPresent(Bool.self, forKey: .laundry) ?? laundry
        freezing = try values.decodeIfPresent(Bool.self, forKey: .freezing) ?? freezing
    }
}

enum PackCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case documents, clothes, toiletries, electronics, health, beach, outdoors, snow, work, camping, festival, kids, pet, extras, beforeLeaving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: "Documentos y dinero"
        case .clothes: "Ropa"
        case .toiletries: "Aseo"
        case .electronics: "Electrónica"
        case .health: "Botiquín"
        case .beach: "Playa"
        case .outdoors: "Montaña"
        case .snow: "Nieve"
        case .work: "Trabajo"
        case .camping: "Acampada"
        case .festival: "Festival"
        case .kids: "Peques"
        case .pet: "Mascota"
        case .extras: "Otros"
        case .beforeLeaving: "Antes de salir de casa"
        }
    }

    var symbol: String {
        switch self {
        case .documents: "wallet.pass.fill"
        case .clothes: "tshirt.fill"
        case .toiletries: "drop.fill"
        case .electronics: "bolt.fill"
        case .health: "cross.case.fill"
        case .beach: "beach.umbrella.fill"
        case .outdoors: "mountain.2.fill"
        case .snow: "snowflake"
        case .work: "briefcase.fill"
        case .camping: "tent.fill"
        case .festival: "music.note"
        case .kids: "figure.and.child.holdinghands"
        case .pet: "pawprint.fill"
        case .extras: "bag.fill"
        case .beforeLeaving: "house.fill"
        }
    }

    /// Position in the list (the order of `allCases`).
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// One line of the packing list.
struct PackEntry: Codable, Sendable, Hashable, Identifiable {
    var name: String
    var category: PackCategory
    /// Number of units ("Camisetas ×5"); nil when a count makes no sense ("Cargador").
    var quantity: Int?
    var note: String?

    var id: String { "\(category.rawValue)|\(name.lowercased())" }
    /// Things to do before leaving home, rather than things to pack.
    var isTask: Bool { category == .beforeLeaving }

    init(_ name: String, _ category: PackCategory, quantity: Int? = nil, note: String? = nil) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.note = note
    }

    /// "Camisetas ×5" or just the name.
    var label: String { quantity.map { "\(name) ×\($0)" } ?? name }
}
