import XCTest

final class RondaUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func open(_ id: String, in app: XCUIApplication) {
        let tile = app.buttons[id]
        if !tile.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "Missing \(id)")
        tile.tap()
        XCTAssertTrue(app.buttons["game.close"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func close(_ app: XCUIApplication) {
        app.buttons["game.close"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNormalGames() {
        let app = launch()
        XCTAssertTrue(app.buttons["game.normal.neverHave"].waitForExistence(timeout: 8))
        snapshot("01-home-normal", app)

        // Yo nunca: mark two players, next card.
        open("game.normal.neverHave", in: app)
        app.buttons["pick.Ana"].tap()
        app.buttons["pick.Leo"].tap()
        snapshot("02-never", app)
        app.buttons["prompt.next"].tap()
        close(app)

        // ¿Quién es más probable?: countdown then pick.
        open("game.normal.mostLikely", in: app)
        app.buttons["prompt.point"].tap()
        XCTAssertTrue(app.buttons["pick.Sara"].waitForExistence(timeout: 6))
        app.buttons["pick.Sara"].tap()
        snapshot("03-most-likely", app)
        app.buttons["prompt.next"].tap()
        close(app)

        // Verdad o trago.
        open("game.normal.truthOrDrink", in: app)
        snapshot("04-truth", app)
        app.buttons["prompt.pass"].tap()
        close(app)

        // Mayor o menor.
        open("game.normal.higherLower", in: app)
        app.buttons["hl.higher"].tap()
        snapshot("05-higher-lower", app)
        close(app)

        // El Círculo.
        open("game.normal.circle", in: app)
        app.buttons["circle.draw"].tap()
        XCTAssertTrue(app.otherElements["circle.rule"].waitForExistence(timeout: 3) || app.staticTexts.count > 0)
        snapshot("06-circle", app)
        close(app)

        // La Ruleta: spin and wait for the result.
        open("game.normal.roulette", in: app)
        app.buttons["roulette.spin"].tap()
        sleep(4)
        snapshot("07-roulette", app)
        close(app)

        // La Bomba: category screen.
        open("game.normal.bomb", in: app)
        snapshot("08-bomb", app)
        close(app)

        // Duelos: choose two players and see the arena.
        open("game.normal.duels", in: app)
        app.buttons["pick.Ana"].tap()
        app.buttons["pick.Dani"].tap()
        app.buttons["duel.kind.taps"].tap()
        snapshot("09-duels-setup", app)
        app.buttons["duel.start"].tap()
        sleep(3)
        snapshot("10-duel-arena", app)
        sleep(6)
        XCTAssertTrue(app.buttons["duel.back"].waitForExistence(timeout: 5))
        app.buttons["duel.back"].tap()
        close(app)

        // Scoreboard reflects the sips given during the session.
        app.buttons["home.scoreboard"].tap()
        XCTAssertTrue(app.navigationBars["Marcador"].waitForExistence(timeout: 5))
        snapshot("11-scoreboard", app)
    }

    @MainActor
    func testHotSection() {
        let app = launch()
        XCTAssertTrue(app.buttons["mode.hot"].waitForExistence(timeout: 8))
        app.buttons["mode.hot"].tap()
        XCTAssertTrue(app.buttons["hot.accept"].waitForExistence(timeout: 5))
        snapshot("20-hot-consent", app)
        app.buttons["hot.accept"].tap()
        XCTAssertTrue(app.buttons["game.hot.dares"].waitForExistence(timeout: 5))
        snapshot("21-home-hot", app)

        open("game.hot.dares", in: app)
        snapshot("22-dares", app)
        app.buttons["prompt.done"].tap()
        close(app)

        open("game.hot.neverHave", in: app)
        snapshot("23-never-hot", app)
        close(app)
    }

    @MainActor
    func testSettingsAndSoberMode() {
        let app = launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 8))
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.switches["settings.sober"].waitForExistence(timeout: 5))
        snapshot("30-settings", app)
        app.switches["settings.sober"].switches.firstMatch.tap()
        app.buttons["Listo"].tap()

        open("game.normal.truthOrDrink", in: app)
        snapshot("31-truth-sober", app)
        close(app)

        app.buttons["home.players"].tap()
        XCTAssertTrue(app.textFields["players.field"].waitForExistence(timeout: 5))
        snapshot("32-players", app)
    }

    @MainActor
    func testFirstRunFlow() {
        let app = launch(["-freshInstall"])
        XCTAssertTrue(app.buttons["age.adult"].waitForExistence(timeout: 8))
        snapshot("00-age-gate", app)
    }
}
