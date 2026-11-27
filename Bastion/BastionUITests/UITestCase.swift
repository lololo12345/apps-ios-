import XCTest

/// Base class for UI tests: launch with test flags, find by identifier, tap, wait and take screenshots.
/// Screenshots named "01-something" are exported by CI (artifact screenshots-<App>), sorted by name.
class UITestCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        return app
    }

    @MainActor
    func snapshot(_ name: String, _ app: XCUIApplication, settle: TimeInterval = 0.5) {
        // Let transitions finish so the screenshot never catches a half-drawn screen.
        if settle > 0 { Thread.sleep(forTimeInterval: settle) }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    @discardableResult
    func waitFor(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 6) -> XCUIElement {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: timeout), "Missing \(id)")
        return item
    }

    @MainActor
    func tap(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 6) {
        waitFor(id, app, timeout: timeout).tap()
    }

    @MainActor
    func enter(_ text: String, into id: String, _ app: XCUIApplication, submit: Bool = false) {
        let field = waitFor(id, app)
        field.tap()
        // "\n" submits through the keyboard: buttons under the keyboard cannot be tapped.
        field.typeText(submit ? text + "\n" : text)
    }

    @MainActor
    func tab(_ name: String, _ app: XCUIApplication) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab \(name)")
        button.tap()
    }

    @MainActor
    func text(containing fragment: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    @MainActor
    func wait(until predicate: String, on item: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: item)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func waitToDisappear(_ item: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        wait(until: "exists == false", on: item, timeout: timeout)
    }
}
