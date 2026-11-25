import XCTest

final class __name__UITests: UITestCase {
    /// Home and settings in light mode, then switch to dark from Ajustes and look at both screens again.
    @MainActor
    func testHomeSettingsAndAppearance() {
        let app = launch(["-appearance", "light"])
        waitFor("tapButton", app)
        snapshot("01-home", app)
        tap("tapButton", app)
        XCTAssertTrue(wait(until: "label CONTAINS '1'", on: element("tapCount", app)))
        tap("filter.Hoy", app)

        tab("Ajustes", app)
        waitFor("hapticsToggle", app)
        snapshot("02-settings", app)

        tap("appearance.dark", app)
        snapshot("03-settings-dark", app)

        tab("Inicio", app)
        waitFor("tapButton", app)
        snapshot("04-home-dark", app)
    }
}
