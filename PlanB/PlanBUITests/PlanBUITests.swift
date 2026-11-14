import XCTest

final class PlanBUITests: XCTestCase {
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
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    private func tap(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 5) {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: timeout), "Missing \(id)")
        item.tap()
    }

    @MainActor
    private func text(_ fragment: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    @MainActor
    private func waitToDisappear(_ item: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: item)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func tab(_ name: String, _ app: XCUIApplication) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab \(name)")
        button.tap()
    }

    @MainActor
    func testOnboardingChooseAndRemember() {
        let app = launch(["-freshInstall"])
        let first = app.textFields["onboarding.nameA"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        snapshot("00-onboarding", app)
        first.tap()
        first.typeText("Ana")
        let second = app.textFields["onboarding.nameB"]
        second.tap()
        second.typeText("Leo")
        tap("onboarding.start", app)

        XCTAssertTrue(element("card.top", app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¿Qué os apetece hoy?"].exists)
        snapshot("01-discover", app)

        let saved = element("card.top", app).label
        tap("deck.save", app)
        usleep(400_000)
        snapshot("01b-saved-toast", app)
        sleep(1)
        tap("deck.pass", app)
        sleep(1)

        tap("card.top", app)
        XCTAssertTrue(element("detail.title", app).waitForExistence(timeout: 5))
        snapshot("02-detail", app)
        tap("detail.choose", app)
        XCTAssertTrue(element("active.banner", app).waitForExistence(timeout: 5))
        sleep(1)
        snapshot("03-chosen", app)

        tap("active.done", app)
        tap("done.heart.5", app)
        let note = element("done.note", app)
        note.tap()
        note.typeText("Nos ha encantado")
        snapshot("04-done", app)
        tap("done.save", app)
        XCTAssertTrue(waitToDisappear(element("active.banner", app)))

        tab("Recuerdos", app)
        XCTAssertTrue(element("memories.stats", app).waitForExistence(timeout: 5))
        XCTAssertTrue(text("Nos ha encantado", app).waitForExistence(timeout: 3))
        snapshot("05-memories", app)

        tab("Guardados", app)
        XCTAssertTrue(app.navigationBars["Guardados"].waitForExistence(timeout: 3))
        let firstWords = saved.components(separatedBy: ", ").dropFirst().first ?? ""
        XCTAssertTrue(text(firstWords, app).waitForExistence(timeout: 3), "Saved plan \(firstWords) not listed")
        snapshot("06-saved", app)
    }

    @MainActor
    func testFiltersAndRoulette() {
        let app = launch()
        XCTAssertTrue(element("card.top", app).waitForExistence(timeout: 5))
        let count = element("discover.count", app)
        let before = count.label
        tap("filter.place", app)
        let home = app.buttons["En casa"]
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        home.tap()
        tap("filter.budget", app)
        let free = app.buttons["Gratis"]
        XCTAssertTrue(free.waitForExistence(timeout: 3))
        free.tap()
        sleep(1)
        XCTAssertNotEqual(count.label, before)
        XCTAssertTrue(element("filter.clear", app).exists)
        snapshot("07-filters", app)

        tap("discover.roulette", app)
        tap("roulette.spin", app)
        XCTAssertTrue(element("roulette.result", app).waitForExistence(timeout: 6))
        snapshot("08-roulette", app)
        tap("roulette.choose", app)
        XCTAssertTrue(element("active.banner", app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testSurprise() {
        let app = launch()
        tap("discover.surprise", app)
        XCTAssertTrue(element("surprise.pick", app).waitForExistence(timeout: 5))
        tap("surprise.next", app)
        sleep(1)
        snapshot("09-surprise-pick", app)
        tap("surprise.pick", app)
        XCTAssertTrue(element("surprise.clues", app).waitForExistence(timeout: 3))
        snapshot("10-surprise-handover", app)
        tap("surprise.clues", app)
        tap("surprise.hint", app)
        tap("surprise.hint", app)
        sleep(1)
        snapshot("11-surprise-clues", app)
        tap("surprise.reveal", app)
        let confirm = app.buttons["Sí, revelar"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(element("surprise.plan", app).waitForExistence(timeout: 3))
        sleep(1)
        snapshot("12-surprise-reveal", app)
        tap("surprise.go", app)
        XCTAssertTrue(element("active.banner", app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testMemoriesStats() {
        let app = launch(["-seedMemories"])
        tab("Recuerdos", app)
        XCTAssertTrue(element("memories.stats", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("memories.onThisDay", app).waitForExistence(timeout: 3))
        snapshot("13-memories-stats", app)
    }

    @MainActor
    func testIntimateAndCustomPlans() {
        let app = launch()
        tab("Ajustes", app)
        let toggle = app.switches["settings.intimate"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        snapshot("14-settings", app)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(element("intimate.confirm", app).waitForExistence(timeout: 3))
        snapshot("15-consent", app)
        tap("intimate.confirm", app)

        tap("settings.custom", app)
        let title = element("custom.title", app)
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("Bolos y hamburguesa")
        tap("custom.add", app)
        XCTAssertTrue(text("Bolos y hamburguesa", app).waitForExistence(timeout: 3))
        snapshot("16-custom", app)

        // Leave the form (and its keyboard) before switching tabs.
        app.navigationBars.buttons.firstMatch.tap()
        tab("Descubrir", app)
        let intimate = app.buttons["Íntimo"]
        XCTAssertTrue(intimate.waitForExistence(timeout: 5))
        intimate.tap()
        sleep(1)
        XCTAssertTrue(element("card.top", app).waitForExistence(timeout: 3))
        snapshot("17-intimate", app)
    }
}
