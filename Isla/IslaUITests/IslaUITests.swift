import XCTest

final class IslaUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    private func tap(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 5) {
        let item = element(id, app)
        if !item.waitForExistence(timeout: timeout) {
            app.swipeUp()
        }
        XCTAssertTrue(item.waitForExistence(timeout: 3), "Missing \(id)")
        item.tap()
    }

    @MainActor
    private func open(_ kind: String, _ app: XCUIApplication) {
        let tile = element("tool.\(kind)", app)
        var attempts = 0
        while !tile.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(tile.exists, "Missing tool \(kind)")
        tile.tap()
        XCTAssertTrue(element("setup.start", app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func scrollToTop(_ app: XCUIApplication) {
        app.statusBars.firstMatch.tap()
        sleep(1)
    }

    @MainActor
    func testTimerCounterAndIsland() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Isla"].waitForExistence(timeout: 5))
        snapshot("00-home", app)

        open("timer", app)
        let title = element("setup.title", app)
        title.tap()
        title.typeText("Pasta")
        snapshot("01-timer-setup", app)
        tap("setup.start", app)
        XCTAssertTrue(element("session.timer", app).waitForExistence(timeout: 5))
        tap("action.timer.pause", app)
        XCTAssertTrue(element("action.timer.resume", app).waitForExistence(timeout: 3))
        tap("action.timer.resume", app)

        // A favourite from the starter set.
        tap("favorite.Vasos de agua", app)
        XCTAssertTrue(element("session.counter", app).waitForExistence(timeout: 5))
        tap("action.counter.plus", app)
        tap("action.counter.plus", app)
        XCTAssertEqual(element("session.value.counter", app).label, "2")
        sleep(1)
        snapshot("02-running", app)

        // The island itself, on the home screen.
        XCUIDevice.shared.press(.home)
        sleep(3)
        snapshot("03-island-home-screen", app)
        app.activate()
        XCTAssertTrue(element("session.timer", app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testScoreboardAndShoppingList() {
        let app = launch()
        open("score", app)
        let toggle = app.switches.firstMatch
        toggle.switches.firstMatch.tap()
        tap("setup.start", app)
        XCTAssertTrue(element("session.score", app).waitForExistence(timeout: 5))
        tap("action.score.a", app)
        tap("action.score.a", app)
        tap("action.score.b", app)
        XCTAssertEqual(element("session.value.score", app).label, "30 – 15")

        open("shopping", app)
        let lines = element("setup.lines", app)
        lines.tap()
        lines.typeText("Leche\nPan\nTomates")
        tap("setup.start", app)
        XCTAssertTrue(element("session.shopping", app).waitForExistence(timeout: 5))
        tap("action.shopping.next", app)
        XCTAssertTrue(app.staticTexts["Pan"].waitForExistence(timeout: 3))
        sleep(1)
        snapshot("04-score-and-list", app)
    }

    @MainActor
    func testFlashcardsAndPomodoro() {
        let app = launch()
        open("flashcards", app)
        let lines = element("setup.lines", app)
        lines.tap()
        lines.typeText("Capital de Italia = Roma\nApple = Manzana")
        tap("setup.start", app)
        tap("action.flashcards.reveal", app)
        XCTAssertTrue(app.staticTexts["Roma"].waitForExistence(timeout: 3))
        tap("action.flashcards.right", app)

        tap("favorite.Foco 25/5", app)
        XCTAssertTrue(element("session.pomodoro", app).waitForExistence(timeout: 5))
        sleep(1)
        snapshot("05-flashcards-focus", app)
        XCUIDevice.shared.press(.home)
        sleep(3)
        snapshot("06-island-two-activities", app)
    }

    @MainActor
    func testCatalogAndSearch() {
        let app = launch()
        let search = app.searchFields.firstMatch
        app.swipeDown()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("parada")
        XCTAssertTrue(element("tool.busStop", app).waitForExistence(timeout: 3))
        XCTAssertFalse(element("tool.timer", app).exists)
        snapshot("07-search", app)
        app.buttons["Cancelar"].firstMatch.tap()
        app.swipeUp()
        app.swipeUp()
        sleep(1)
        snapshot("08-catalog", app)
    }
}
