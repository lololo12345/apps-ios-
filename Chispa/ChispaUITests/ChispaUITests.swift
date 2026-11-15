import XCTest

final class ChispaUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-revealAnswers"] + extra
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
    private func tap(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 6) {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: timeout), "Missing \(id)")
        item.tap()
    }

    @MainActor
    private func tab(_ name: String, _ app: XCUIApplication) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab \(name)")
        button.tap()
    }

    @MainActor
    private func wait(for predicate: String, on item: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: item)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Answers whatever challenge is on screen correctly (answers are tagged with -revealAnswers).
    @MainActor
    private func answerCorrectly(_ app: XCUIApplication, kind: String) {
        switch kind {
        case "math":
            let display = element("numberDisplay", app)
            XCTAssertTrue(display.waitForExistence(timeout: 5))
            let answer = (display.value as? String) ?? ""
            XCTAssertFalse(answer.isEmpty, "No test answer")
            for digit in answer { tap("key-\(digit)", app) }
            tap("key-OK", app)
        case "memory":
            let status = element("memoryStatus", app)
            XCTAssertTrue(status.waitForExistence(timeout: 5))
            XCTAssertTrue(wait(for: "label CONTAINS[c] 'Tóca' OR label CONTAINS[c] 'Toca'", on: status, timeout: 20), "Pattern never hid")
            var index = 0
            while element("target-\(index)", app).exists {
                element("target-\(index)", app).tap()
                index += 1
            }
            XCTAssertGreaterThan(index, 3)
        default:
            tap("answer-correct", app)
        }
    }

    @MainActor
    func testOnboardingAndFullDay() {
        let app = launch()
        let name = element("onboardingName", app)
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        snapshot("01-onboarding", app)
        name.tap()
        name.typeText("Lola\n")

        XCTAssertTrue(element("challenge-riddle", app).waitForExistence(timeout: 6))
        snapshot("02-today", app)

        let kinds = ["riddle", "trivia", "math", "memory", "logic"]
        tap("challenge-riddle", app)
        for (index, kind) in kinds.enumerated() {
            XCTAssertTrue(element("startChallenge", app).waitForExistence(timeout: 6), "No intro for \(kind)")
            if index == 0 { snapshot("03-intro", app) }
            tap("startChallenge", app)
            XCTAssertTrue(element("prompt", app).waitForExistence(timeout: 6))
            if kind == "memory" {
                Thread.sleep(forTimeInterval: 2.6)
            }
            snapshot(String(format: "%02d-play-%@", 4 + index * 2, kind), app)
            answerCorrectly(app, kind: kind)
            let title = element("resultTitle", app)
            XCTAssertTrue(title.waitForExistence(timeout: 8), "No result for \(kind)")
            XCTAssertFalse(title.label.contains("no"), "Wrong answer for \(kind): \(title.label)")
            snapshot(String(format: "%02d-result-%@", 5 + index * 2, kind), app)
            if index < kinds.count - 1 {
                tap("nextChallenge", app)
            } else {
                tap("finishChallenge", app)
            }
        }

        let points = element("todayPoints", app)
        XCTAssertTrue(points.waitForExistence(timeout: 6))
        XCTAssertTrue(element("shareResult", app).exists)
        snapshot("14-day-complete", app)
        XCTAssertTrue(element("streak", app).label.contains("1"))
    }

    @MainActor
    func testWrongAnswerAndOneChance() {
        let app = launch(["-playerName", "Lola"])
        tap("challenge-trivia", app, timeout: 8)
        tap("startChallenge", app)
        tap("hintButton", app)
        // 50/50 hides two options; tap a remaining wrong one.
        let wrong = (0..<4).map { element("answer-\($0)", app) }.first { $0.exists && $0.isEnabled }
        XCTAssertNotNil(wrong)
        snapshot("15-fifty-fifty", app)
        wrong?.tap()
        let title = element("resultTitle", app)
        XCTAssertTrue(title.waitForExistence(timeout: 6))
        XCTAssertEqual(title.label, "Esta vez no")
        XCTAssertTrue(element("explanation", app).exists)
        snapshot("16-wrong", app)
        tap("closeChallenge", app)
        // Reopening shows the result again, not a second chance.
        tap("challenge-trivia", app)
        XCTAssertTrue(element("resultTitle", app).waitForExistence(timeout: 6))
        XCTAssertFalse(element("startChallenge", app).exists)
    }

    @MainActor
    func testHistoryLeagueProgressAndPractice() {
        let app = launch(["-playerName", "Lola", "-seedHistory"])
        XCTAssertTrue(element("challenge-riddle", app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("streak", app).label.contains("19"), element("streak", app).label)
        snapshot("17-today-streak", app)

        tab("Liga", app)
        XCTAssertTrue(element("leagueRow-Sara", app).waitForExistence(timeout: 6))
        XCTAssertTrue(element("leagueRow-me", app).exists)
        snapshot("18-league", app)
        tap("addFriend", app)
        let field = element("friendCodeField", app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("hola, esto no es un código")
        tap("confirmAddFriend", app)
        XCTAssertTrue(element("friendCodeError", app).waitForExistence(timeout: 5))
        snapshot("19-add-friend-error", app)
        app.swipeDown(velocity: .fast)

        tab("Progreso", app)
        XCTAssertTrue(element("statsSummary", app).waitForExistence(timeout: 6))
        snapshot("20-progress", app)
        app.swipeUp()
        snapshot("21-calendar", app)
        app.swipeUp()
        app.swipeUp()
        snapshot("22-badges", app)

        tab("Práctica", app)
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'practice-'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 6))
        snapshot("23-practice", app)
        first.tap()
        tap("startChallenge", app)
        XCTAssertTrue(element("prompt", app).waitForExistence(timeout: 6))
        tap("closeChallenge", app)

        tab("Hoy", app)
        tap("settingsButton", app)
        XCTAssertTrue(element("nameField", app).waitForExistence(timeout: 5))
        snapshot("24-settings", app)
    }
}
