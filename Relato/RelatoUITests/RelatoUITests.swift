import XCTest

/// End-to-end flows on the simulator. Each step attaches a screenshot to the result bundle
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

    /// Raw screen capture: does not query the accessibility tree, so it works even if the app is busy.
    @MainActor
    private func screenCapture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openSampleStory(_ app: XCUIApplication) {
        let story = app.buttons["story.La vecina del 4ºB"]
        XCTAssertTrue(story.waitForExistence(timeout: 8))
        story.tap()
        XCTAssertTrue(app.buttons["editor.rehearse"].waitForExistence(timeout: 5))
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
    func testWritingFlowLight() {
        runWritingFlow(dark: false)
    }

    @MainActor
    func testWritingFlowDark() {
        runWritingFlow(dark: true)
    }

    @MainActor
    private func runWritingFlow(dark: Bool) {
        let suffix = dark ? "dark" : "light"
        let app = launch(dark: dark)

        XCTAssertTrue(app.buttons["story.La vecina del 4ºB"].waitForExistence(timeout: 8))
        snapshot("10-library-\(suffix)", app)

        openSampleStory(app)
        snapshot("11-editor-\(suffix)", app)
        app.swipeUp()
        snapshot("12-editor-beats-\(suffix)", app)

        app.buttons["editor.parts"].tap()
        XCTAssertTrue(app.navigationBars["Dividir en partes"].waitForExistence(timeout: 5))
        app.buttons["30 s"].tap()
        snapshot("13-parts-\(suffix)", app)
        app.buttons["Listo"].tap()

        // Back to the library; new story from a template.
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 5))
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
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Ideas"].tap()
        let capture = app.textFields["ideas.capture"].exists ? app.textFields["ideas.capture"] : app.textViews["ideas.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        snapshot("19-ideas-\(suffix)", app)

        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        snapshot("20-settings-\(suffix)", app)

        // Speaking-rate calibration: start, stop too early, see the guidance, close.
        app.buttons["settings.calibrate"].tap()
        XCTAssertTrue(app.buttons["calibration.start"].waitForExistence(timeout: 5))
        snapshot("21-calibration-\(suffix)", app)
        app.buttons["calibration.start"].tap()
        XCTAssertTrue(app.buttons["calibration.stop"].waitForExistence(timeout: 3))
        app.buttons["calibration.stop"].tap()
        XCTAssertTrue(app.buttons["Repetir"].waitForExistence(timeout: 3))
        app.buttons["Cerrar"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPrompterRehearsalAndRecordFallback() {
        let app = launch()
        openSampleStory(app)

        app.buttons["editor.rehearse"].tap()
        sleep(2)
        screenCapture("14a-prompter-raw")
        XCTAssertTrue(app.buttons["prompter.play"].waitForExistence(timeout: 10))
        snapshot("14-prompter", app)

        app.buttons["prompter.play"].tap()
        sleep(6) // 3 s countdown + 3 s of scrolling
        screenCapture("15-prompter-running")
        app.buttons["prompter.play"].tap() // pause
        snapshot("15b-prompter-paused", app)
        app.buttons["Cerrar teleprompter"].tap()

        // The simulator has no camera: record mode must degrade gracefully.
        XCTAssertTrue(app.buttons["editor.record"].waitForExistence(timeout: 5))
        app.buttons["editor.record"].tap()
        XCTAssertTrue(app.buttons["Ensayar sin grabar"].waitForExistence(timeout: 8))
        snapshot("16-record-unavailable", app)
        app.buttons["Ensayar sin grabar"].tap()
        XCTAssertTrue(app.buttons["prompter.play"].waitForExistence(timeout: 5))
        app.buttons["Cerrar teleprompter"].tap()
        XCTAssertTrue(app.buttons["editor.record"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            _ = launch()
        }
    }
}
