import Foundation
import SwiftData
import Testing
@testable import Mochila

@Suite("Listas")
struct GeneratorTests {
    @Test func everyCombinationGivesAUsefulListWithoutRepeats() {
        for type in TripType.allCases {
            for days in [1, 3, 7, 30] {
                for climate in Climate.allCases {
                    for flags in 0..<64 {
                        var options = TripOptions(days: days, climate: climate)
                        options.rain = flags & 1 != 0
                        options.flying = flags & 2 != 0
                        options.carryOnOnly = flags & 4 != 0
                        options.kids = flags & 8 != 0
                        options.pet = flags & 16 != 0
                        options.laundry = flags & 32 != 0
                        let list = PackingGenerator.items(for: type, options: options)
                        let names = list.map { $0.name.lowercased() }
                        #expect(list.count >= 20)
                        #expect(Set(names).count == names.count, "\(type) repite algo")
                        #expect(list.allSatisfy { ($0.quantity ?? 1) >= 1 })
                    }
                }
            }
        }
    }

    @Test func quantitiesFollowTheDays() {
        let short = PackingGenerator.items(for: .city, options: TripOptions(days: 2))
        let long = PackingGenerator.items(for: .city, options: TripOptions(days: 20))
        #expect(short.first { $0.name == "Camisetas" }?.quantity == 2)
        #expect(short.first { $0.name == "Ropa interior" }?.quantity == 3)
        #expect(long.first { $0.name == "Camisetas" }?.quantity == 10)
        var laundry = TripOptions(days: 20)
        laundry.laundry = true
        #expect(PackingGenerator.items(for: .city, options: laundry).first { $0.name == "Camisetas" }?.quantity == 4)
    }

    @Test func detailsChangeTheList() {
        var options = TripOptions(days: 5, climate: .hot)
        options.flying = true
        options.carryOnOnly = true
        options.kids = true
        options.pet = true
        let list = PackingGenerator.items(for: .beach, options: options)
        #expect(list.contains { $0.name == "Bañador" && $0.quantity == 2 })
        #expect(list.contains { $0.name == "Tarjeta de embarque" })
        #expect(list.first { $0.name == "Champú y gel" }?.note?.contains("100 ml") == true)
        #expect(list.contains { $0.category == .kids })
        #expect(list.contains { $0.category == .pet })
        #expect(list.contains { $0.name == "Hacer el check-in online" && $0.isTask })
        let snow = PackingGenerator.items(for: .snow, options: TripOptions(days: 4, climate: .cold))
        #expect(snow.contains { $0.name == "Forfait" })
        #expect(snow.contains { $0.name == "Abrigo" })
        #expect(!snow.contains { $0.name == "Bañador" })
    }

    @Test func countdownAndProgress() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12))!
        func start(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now)! }
        #expect(TripCountdown.text(start: start(3), days: 5, now: now, calendar: calendar) == "Faltan 3 días")
        #expect(TripCountdown.text(start: start(1), days: 5, now: now, calendar: calendar) == "Sales mañana")
        #expect(TripCountdown.text(start: start(0), days: 5, now: now, calendar: calendar) == "Hoy sales")
        #expect(TripCountdown.text(start: start(-1), days: 5, now: now, calendar: calendar) == "Día 2 de 5")
        #expect(TripCountdown.text(start: start(-9), days: 5, now: now, calendar: calendar) == "Viaje terminado")
        #expect(TripCountdown.isOver(start: start(-9), days: 5, now: now, calendar: calendar))
        #expect(!TripCountdown.isOver(start: start(-2), days: 5, now: now, calendar: calendar))
        #expect(PackProgress(done: 3, total: 4).text == "3 de 4")
        #expect(PackProgress(done: 4, total: 4).isComplete)
        #expect(!PackProgress(done: 0, total: 0).isComplete)
    }

    @Test func shareTextListsEverything() {
        let entries = [(PackEntry("DNI o pasaporte", .documents), true), (PackEntry("Camisetas", .clothes, quantity: 3), false)]
        let text = PackingShare.text(title: "Roma", subtitle: "Ciudad · 3 días", entries: entries)
        #expect(text.contains("🎒 Roma"))
        #expect(text.contains("☑︎ DNI o pasaporte"))
        #expect(text.contains("☐ Camisetas ×3"))
    }

    @Test func dailyTipChangesEveryDay() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(TravelTips.tip(for: today, calendar: calendar) != TravelTips.tip(for: tomorrow, calendar: calendar))
    }
}

@Suite("Viajes guardados")
@MainActor
struct TripStoreTests {
    private func context() throws -> ModelContext {
        let schema = Schema([Trip.self, PackItem.self, SavedTemplate.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test func newTripGetsItsListAndProgress() throws {
        let context = try context()
        let trip = TripFactory.makeTrip(name: "  Lisboa  ", type: .city, start: .now, options: TripOptions(days: 3), in: context)
        #expect(trip.name == "Lisboa")
        #expect(!trip.things.isEmpty && !trip.tasks.isEmpty)
        #expect(trip.progress.done == 0)
        trip.things[0].packed = true
        trip.things[1].packed = true
        #expect(trip.progress.done == 2)
        // The way back is counted separately.
        trip.returnMode = true
        #expect(trip.progress.done == 0)
        trip.things[0].packedBack = true
        #expect(trip.progress.done == 1)
    }

    @Test func emptyNameUsesTheKind() throws {
        let trip = TripFactory.makeTrip(name: "", type: .snow, start: .now, options: TripOptions(), in: try context())
        #expect(trip.name == "Viaje de nieve")
    }

    @Test func duplicateTemplateAndCustomItems() throws {
        let context = try context()
        let trip = TripFactory.makeTrip(name: "Cádiz", type: .beach, start: .now, options: TripOptions(days: 5), in: context)
        TripFactory.addItem(PackEntry("Gafas de bucear", .beach), to: trip, in: context)
        #expect(trip.items.contains { $0.name == "Gafas de bucear" && $0.custom })
        let copy = TripFactory.duplicate(trip, in: context)
        #expect(copy.items.count == trip.items.count)
        #expect(copy.name == "Cádiz (copia)")
        TripFactory.saveTemplate(from: trip, name: "Mi playa", in: context)
        let templates = try context.fetch(FetchDescriptor<SavedTemplate>())
        #expect(templates.count == 1)
        #expect(templates[0].entries.contains { $0.name == "Gafas de bucear" })
        #expect(templates[0].type == .beach)
    }
}
