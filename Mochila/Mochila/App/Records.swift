import Foundation
import SwiftData

/// A trip and its packing list. Everything is saved only on this iPhone.
@Model
final class Trip {
    var id: UUID
    var name: String
    var typeRaw: String
    var startDate: Date
    var days: Int
    var optionsData: Data
    var createdAt: Date
    /// Checking things on the way back home ("que no se quede nada").
    var returnMode: Bool
    /// Weather at the destination (Open-Meteo), when it could be looked up.
    var weatherData: Data?
    @Relationship(deleteRule: .cascade, inverse: \PackItem.trip) var items: [PackItem] = []

    init(name: String, type: TripType, startDate: Date, options: TripOptions, createdAt: Date = .now) {
        id = UUID()
        self.name = name
        typeRaw = type.rawValue
        self.startDate = startDate
        days = options.days
        optionsData = (try? JSONEncoder().encode(options)) ?? Data()
        self.createdAt = createdAt
        returnMode = false
    }

    var type: TripType { TripType(rawValue: typeRaw) ?? .city }

    var options: TripOptions {
        get { (try? JSONDecoder().decode(TripOptions.self, from: optionsData)) ?? TripOptions() }
        set { optionsData = (try? JSONEncoder().encode(newValue)) ?? optionsData }
    }

    var weather: WeatherSummary? {
        get { weatherData.flatMap { try? JSONDecoder().decode(WeatherSummary.self, from: $0) } }
        set { weatherData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var sortedItems: [PackItem] { items.sorted { ($0.category.order, $0.order) < ($1.category.order, $1.order) } }
    var things: [PackItem] { sortedItems.filter { !$0.isTask } }
    var tasks: [PackItem] { sortedItems.filter(\.isTask) }

    /// Packing progress for the current direction (going or coming back). One pass, no sorting:
    /// it is read by every card and header on each redraw.
    var progress: PackProgress {
        var done = 0, total = 0
        for item in items where !item.isTask {
            total += 1
            if returnMode ? item.packedBack : item.packed { done += 1 }
        }
        return PackProgress(done: done, total: total)
    }

    var tasksProgress: PackProgress {
        var done = 0, total = 0
        for item in items where item.isTask {
            total += 1
            if item.packed { done += 1 }
        }
        return PackProgress(done: done, total: total)
    }

    func isDone(_ item: PackItem) -> Bool { returnMode ? item.packedBack : item.packed }

    /// "Te falta: DNI o pasaporte, Cargador y 3 más", in list order (documents first).
    var pendingText: String? { PackingShare.pendingText(things.filter { !isDone($0) }.map(\.name)) }

    var hero: (value: String, caption: String) { TripCountdown.hero(start: startDate, days: days) }
    var isOver: Bool { TripCountdown.isOver(start: startDate, days: days) }
    var countdown: String { TripCountdown.text(start: startDate, days: days) }

    var dateText: String {
        let format = Date.FormatStyle.dateTime.day().month(.wide).locale(Locale(identifier: "es_ES"))
        return "\(startDate.formatted(format)) · \(days) \(days == 1 ? "día" : "días")"
    }

    /// "30 nov · 3 días" for the compact trip cards.
    var shortDateText: String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es_ES"))
        return "\(startDate.formatted(format).replacingOccurrences(of: ".", with: "")) · \(days) \(days == 1 ? "día" : "días")"
    }
}

@Model
final class PackItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var quantity: Int?
    var note: String?
    var packed: Bool
    var packedBack: Bool
    var order: Int
    /// Added by the user (not by the generator).
    var custom: Bool
    var trip: Trip?

    init(entry: PackEntry, order: Int, custom: Bool = false) {
        id = UUID()
        name = entry.name
        categoryRaw = entry.category.rawValue
        quantity = entry.quantity
        note = entry.note
        packed = false
        packedBack = false
        self.order = order
        self.custom = custom
    }

    var category: PackCategory { PackCategory(rawValue: categoryRaw) ?? .extras }
    var isTask: Bool { categoryRaw == PackCategory.beforeLeaving.rawValue }
    var entry: PackEntry { PackEntry(name, category, quantity: quantity, note: note) }
    var label: String { entry.label }
}

/// A list the user saved to reuse ("Mi lista de playa").
@Model
final class SavedTemplate {
    var id: UUID
    var name: String
    var typeRaw: String
    var optionsData: Data
    var entriesData: Data
    var createdAt: Date

    init(name: String, type: TripType, options: TripOptions, entries: [PackEntry]) {
        id = UUID()
        self.name = name
        typeRaw = type.rawValue
        optionsData = (try? JSONEncoder().encode(options)) ?? Data()
        entriesData = (try? JSONEncoder().encode(entries)) ?? Data()
        createdAt = .now
    }

    var type: TripType { TripType(rawValue: typeRaw) ?? .city }
    var options: TripOptions { (try? JSONDecoder().decode(TripOptions.self, from: optionsData)) ?? TripOptions() }
    var entries: [PackEntry] { (try? JSONDecoder().decode([PackEntry].self, from: entriesData)) ?? [] }
}

/// Creating, copying and saving trips.
@MainActor
enum TripFactory {
    @discardableResult
    static func makeTrip(name: String, type: TripType, start: Date, options: TripOptions,
                         entries: [PackEntry]? = nil, weather: WeatherSummary? = nil, in context: ModelContext) -> Trip {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = Trip(name: trimmed.isEmpty ? "Viaje de \(type.title.lowercased())" : String(trimmed.prefix(40)),
                        type: type, startDate: start, options: options)
        trip.weather = weather
        context.insert(trip)
        for (index, entry) in (entries ?? PackingGenerator.items(for: type, options: options)).enumerated() {
            let item = PackItem(entry: entry, order: index)
            item.trip = trip
            context.insert(item)
        }
        try? context.save()
        return trip
    }

    @discardableResult
    static func duplicate(_ trip: Trip, in context: ModelContext) -> Trip {
        makeTrip(name: "\(trip.name) (copia)", type: trip.type, start: trip.startDate, options: trip.options,
                 entries: trip.sortedItems.map(\.entry), in: context)
    }

    static func saveTemplate(from trip: Trip, name: String, in context: ModelContext) {
        context.insert(SavedTemplate(name: name, type: trip.type, options: trip.options, entries: trip.sortedItems.map(\.entry)))
        try? context.save()
    }

    /// New weather for a trip. Returns what the new weather would add to the list that is not there yet.
    static func updateWeather(_ trip: Trip, with summary: WeatherSummary) -> [PackEntry] {
        let newOptions = summary.apply(to: trip.options)
        trip.weather = summary
        trip.options = newOptions
        let existing = Set(trip.items.map { $0.name.lowercased() })
        return PackingGenerator.items(for: trip.type, options: newOptions)
            .filter { !$0.isTask && !existing.contains($0.name.lowercased()) }
    }

    static func addEntries(_ entries: [PackEntry], to trip: Trip, in context: ModelContext) {
        var order = (trip.items.map(\.order).max() ?? 0) + 1
        for entry in entries {
            let item = PackItem(entry: entry, order: order)
            item.trip = trip
            context.insert(item)
            order += 1
        }
        try? context.save()
    }

    static func addItem(_ entry: PackEntry, to trip: Trip, in context: ModelContext) {
        let item = PackItem(entry: entry, order: (trip.items.map(\.order).max() ?? 0) + 1, custom: true)
        item.trip = trip
        context.insert(item)
        try? context.save()
    }

    /// UI tests (-seedTrips): a trip in progress, one almost ready and one that already happened.
    static func seed(in context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        var beach = TripOptions()
        beach.days = 6; beach.climate = .hot; beach.flying = true
        let sunny = WeatherSummary(place: Place(name: "Cádiz", country: "España", latitude: 36.53, longitude: -6.29),
                                   minTemp: 19, maxTemp: 28, rainChance: 5, rainMillimetres: 0, source: .forecast, fetchedAt: now)
        let cadiz = makeTrip(name: "Cádiz", type: .beach, start: calendar.date(byAdding: .day, value: 4, to: now) ?? now, options: beach,
                             weather: sunny, in: context)
        for item in cadiz.things.prefix(14) { item.packed = true }
        for item in cadiz.tasks.prefix(2) { item.packed = true }

        var weekend = TripOptions()
        weekend.days = 2
        let toledo = makeTrip(name: "Toledo", type: .weekend, start: calendar.date(byAdding: .day, value: 1, to: now) ?? now, options: weekend, in: context)
        for item in toledo.things.dropLast() { item.packed = true }

        var snow = TripOptions()
        snow.days = 4; snow.climate = .cold
        let andorra = makeTrip(name: "Andorra", type: .snow, start: calendar.date(byAdding: .day, value: -20, to: now) ?? now, options: snow, in: context)
        for item in andorra.items { item.packed = true; item.packedBack = true }

        context.insert(SavedTemplate(name: "Mi lista de playa", type: .beach, options: beach, entries: cadiz.sortedItems.map(\.entry)))
        try? context.save()
    }
}
