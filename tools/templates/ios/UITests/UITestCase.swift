import UIKit
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
        // The whole screen, not app.screenshot(): for a landscape-only app the app's frame comes out
        // cropped to a square. The screen capture has every pixel (rotated, fixed just below).
        var image = XCUIScreen.main.screenshot().image
        // In landscape the screen pixels are stored sideways (portrait buffer): tag them with the
        // device orientation so the redraw below turns them upright.
        let frame = app.frame
        if image.imageOrientation == .up, image.size.width < image.size.height, frame.width > frame.height, let cg = image.cgImage {
            let sideways: UIImage.Orientation = XCUIDevice.shared.orientation == .landscapeRight ? .right : .left
            image = UIImage(cgImage: cg, scale: image.scale, orientation: sideways)
        }
        // Landscape screenshots carry an orientation flag that export tools mishandle (rotated and cropped):
        // redraw them upright so the saved pixels are exactly what is on screen.
        if image.imageOrientation != .up {
            let format = UIGraphicsImageRendererFormat()
            format.scale = image.scale
            let source = image
            image = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
                source.draw(in: CGRect(origin: .zero, size: source.size))
            }
        }
        let attachment = XCTAttachment(image: image)
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
