import XCTest

/// End-to-end smoke flows on the simulator. Each step attaches a screenshot to the result bundle
/// so the UI can be reviewed in light and dark mode.
final class RelatoUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = [], dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        if dark { app.launchArguments.append("-forceDark") }
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
    func testOnboardingPages() {
        let app = launch(["-showOnboarding"])
        XCTAssertTrue(app.buttons["Siguiente"].waitForExistence(timeout: 5))
        snapshot("01-onboarding-1", app)
        app.buttons["Siguiente"].tap()
        app.buttons["Siguiente"].tap()
        XCTAssertTrue(app.buttons["onboarding.samples"].waitForExistence(timeout: 3))
        snapshot("02-onboarding-3", app)
    }

    @MainActor
    func testCoreFlowLight() {
        runCoreFlow(dark: false)
    }

    @MainActor
    func testCoreFlowDark() {
        runCoreFlow(dark: true)
    }

    @MainActor
    private func runCoreFlow(dark: Bool) {
        let suffix = dark ? "dark" : "light"
        let app = launch(dark: dark)

        // Library with sample content.
        let story = app.buttons["story.La vecina del 4ºB"]
        XCTAssertTrue(story.waitForExistence(timeout: 8))
        snapshot("10-library-\(suffix)", app)

        // Editor: duration, hook coach and beats.
        story.tap()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 5))
        snapshot("11-editor-\(suffix)", app)
        app.swipeUp()
        snapshot("12-editor-beats-\(suffix)", app)

        // Parts sheet.
        app.buttons["editor.parts"].tap()
        XCTAssertTrue(app.navigationBars["Dividir en partes"].waitForExistence(timeout: 5))
        app.buttons["30 s"].tap()
        snapshot("13-parts-\(suffix)", app)
        app.buttons["Listo"].tap()

        // Rehearsal teleprompter (no camera needed).
        XCTAssertTrue(app.buttons["editor.rehearse"].waitForExistence(timeout: 5))
        app.buttons["editor.rehearse"].tap()
        XCTAssertTrue(app.buttons["prompter.play"].waitForExistence(timeout: 5))
        snapshot("14-prompter-\(suffix)", app)
        app.buttons["prompter.play"].tap()
        sleep(5) // 3 s countdown + 2 s of scrolling
        snapshot("15-prompter-running-\(suffix)", app)
        app.buttons["Cerrar teleprompter"].tap()

        // Record mode on the simulator: no camera, must degrade gracefully.
        XCTAssertTrue(app.buttons["editor.record"].waitForExistence(timeout: 5))
        app.buttons["editor.record"].tap()
        XCTAssertTrue(app.buttons["Ensayar sin grabar"].waitForExistence(timeout: 5))
        snapshot("16-record-unavailable-\(suffix)", app)
        app.buttons["Ensayar sin grabar"].tap()
        XCTAssertTrue(app.buttons["prompter.play"].waitForExistence(timeout: 3))
        app.buttons["Cerrar teleprompter"].tap()

        // Back to the library; new story from template.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["library.new"].waitForExistence(timeout: 5))
        app.buttons["library.new"].tap()
        XCTAssertTrue(app.buttons["template.mystery"].waitForExistence(timeout: 5))
        snapshot("17-templates-\(suffix)", app)
        app.buttons["template.mystery"].tap()
        let firstBeat = app.textViews["beat.0"].exists ? app.textViews["beat.0"] : app.textFields["beat.0"]
        XCTAssertTrue(firstBeat.waitForExistence(timeout: 5))
        firstBeat.tap()
        firstBeat.typeText("¿Sabías que nadie ha vuelto de esta casa?")
        snapshot("18-new-story-typing-\(suffix)", app)
        app.buttons["Listo"].firstMatch.tap()

        // Ideas tab.
        app.tabBars.buttons["Ideas"].tap()
        let capture = app.textFields["ideas.capture"].exists ? app.textFields["ideas.capture"] : app.textViews["ideas.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        snapshot("19-ideas-\(suffix)", app)

        // Settings tab.
        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        snapshot("20-settings-\(suffix)", app)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()], options: {
            let options = XCTMeasureOptions()
            options.iterationCount = 3
            return options
        }()) {
            _ = launch()
        }
    }
}
