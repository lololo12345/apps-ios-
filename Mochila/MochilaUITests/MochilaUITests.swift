import XCTest

final class MochilaUITests: UITestCase {
    /// A SwiftUI Toggle is exposed as a switch; tap its inner switch when there is one.
    @MainActor
    private func toggleSwitch(_ id: String, _ app: XCUIApplication) {
        let item = waitFor(id, app)
        let inner = item.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            item.tap()
        }
    }

    /// From nothing: create a beach trip, pack a few things, look at the way back.
    @MainActor
    func testCreateTripAndPack() {
        let app = launch()
        waitFor("startFirstTrip", app)
        snapshot("01-empty", app)

        tap("startFirstTrip", app)
        enter("Cádiz", into: "tripName", app, submit: true)
        // The weather at the destination adjusts the list (stubbed under UI tests: Cádiz is hot).
        waitFor("weatherCard", app, timeout: 8)
        tap("type.beach", app)
        toggleSwitch("option.flying", app)
        snapshot("02-new-trip", app)
        tap("createTrip", app)

        let card = waitFor("trip.Cádiz", app)
        snapshot("03-trips", app)
        card.tap()

        waitFor("tripProgress", app)
        waitFor("tripWeather", app)
        snapshot("04-list", app)
        for name in ["DNI o pasaporte", "Tarjetas y algo de efectivo", "Llaves de casa", "Tarjeta de embarque"] {
            tap("item.\(name)", app)
        }
        XCTAssertTrue(wait(until: "label CONTAINS 'faltan'", on: element("tripStatus", app)))
        snapshot("05-packing", app)

        tap("mode.return", app)
        XCTAssertTrue(wait(until: "label CONTAINS 'Vuelta'", on: element("tripStatus", app)))
        snapshot("06-return", app)
    }

    /// Seeded trips: finish one bag (celebration), add something, templates and settings.
    @MainActor
    func testSeededTripsTemplatesAndSettings() {
        let app = launch(["-seedTrips"])
        waitFor("trip.Cádiz", app)
        snapshot("07-trips-seeded", app)

        // Toledo is missing a single thing: hide what is packed and tick the last one.
        tap("trip.Toledo", app)
        waitFor("tripProgress", app)
        toggleSwitch("hidePacked", app)
        tap("item.Botella de agua reutilizable", app)
        waitFor("celebration", app)
        snapshot("08-ready", app)
        tap("closeCelebration", app)

        tap("addItem", app)
        enter("Gafas de bucear", into: "newItemName", app, submit: true)
        waitFor("item.Gafas de bucear", app)
        snapshot("09-added", app)

        // Toledo had no weather yet: look it up (stub: cold and rainy) and accept the suggestions.
        tap("refreshWeather", app)
        waitFor("addSuggestions", app, timeout: 8)
        snapshot("10-weather", app)
        tap("addSuggestions", app)
        XCTAssertTrue(waitToDisappear(element("addSuggestions", app)))

        tab("Plantillas", app)
        waitFor("template.type.mountain", app)
        snapshot("11-templates", app)
        tap("template.type.mountain", app)
        waitFor("createTrip", app)
        snapshot("12-from-template", app)
        tap("cancelNewTrip", app)

        tab("Ajustes", app)
        waitFor("remindersToggle", app)
        snapshot("13-settings", app)
    }
}
