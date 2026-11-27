import XCTest

final class BastionUITests: UITestCase {
    override func setUp() {
        super.setUp()
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    /// Mission or bridge celebrations cover the screen: close them before tapping the HUD.
    @MainActor
    private func dismissCelebration(_ app: XCUIApplication) {
        let ok = element("celebration.ok", app)
        if ok.waitForExistence(timeout: 1.2) {
            ok.tap()
            _ = waitToDisappear(ok, timeout: 3)
        }
    }

    @MainActor
    private func openPanel(_ button: String, _ app: XCUIApplication) {
        dismissCelebration(app)
        tap(button, app)
        waitFor("panel.close", app)
    }

    @MainActor
    private func closePanel(_ app: XCUIApplication) {
        dismissCelebration(app)
        tap("panel.close", app)
        _ = waitToDisappear(element("panel.close", app), timeout: 3)
    }

    /// First launch: title, how to play, and the world.
    @MainActor
    func testFirstLaunch() {
        let app = launch()
        waitFor("title.play", app, timeout: 10)
        snapshot("01-title", app, settle: 1)
        tap("title.play", app)
        waitFor("tutorial.start", app)
        snapshot("02-tutorial", app, settle: 1)
        tap("tutorial.start", app)
        waitFor("hud.quest", app)
        snapshot("03-world", app, settle: 1.5)
    }

    /// The base with a full storehouse: every panel.
    @MainActor
    func testBasePanels() {
        let app = launch(["-skipTitle", "-seed", "rich"])
        waitFor("hud.market", app, timeout: 10)
        dismissCelebration(app)
        snapshot("04-base", app, settle: 1)

        openPanel("hud.market", app)
        snapshot("05-market", app)
        tap("sellAll.wood", app)
        closePanel(app)

        openPanel("hud.workshop", app)
        snapshot("06-workshop", app)
        tap("build.kitchen", app)
        closePanel(app)

        openPanel("hud.upgrades", app)
        snapshot("07-gear", app)
        tap("upgrade.backpack", app)
        closePanel(app)

        openPanel("hud.board", app)
        snapshot("08-board", app)
        closePanel(app)

        openPanel("hud.journal", app)
        snapshot("09-journal", app)
        closePanel(app)

        openPanel("hud.settings", app)
        snapshot("10-settings", app)
        closePanel(app)
    }

    /// Out gathering with a half-full backpack.
    @MainActor
    func testField() {
        let app = launch(["-skipTitle", "-seed", "field"])
        waitFor("hud.quest", app, timeout: 10)
        snapshot("11-field", app, settle: 2.5)
    }

    /// At the river: pay the bridge and watch it being built.
    @MainActor
    func testBridge() {
        let app = launch(["-skipTitle", "-seed", "bridge"])
        waitFor("hud.bridge", app, timeout: 10)
        dismissCelebration(app)
        snapshot("12-river", app, settle: 1)
        openPanel("hud.bridge", app)
        snapshot("13-bridge-panel", app)
        tap("bridge.contribute", app)
        waitFor("celebration", app)
        snapshot("14-bridge-built", app, settle: 1)
        dismissCelebration(app)
        snapshot("15-bridge", app, settle: 1.5)
    }

    /// The Old Forest, with its creatures.
    @MainActor
    func testForest() {
        let app = launch(["-skipTitle", "-seed", "forest"])
        waitFor("hud.quest", app, timeout: 10)
        dismissCelebration(app)
        snapshot("16-forest", app, settle: 3)
    }

    /// Nightfall: the Mist attacks the campfire and the towers shoot.
    @MainActor
    func testNightRaid() {
        let app = launch(["-skipTitle", "-seed", "night"])
        waitFor("hud.raid", app, timeout: 15)
        dismissCelebration(app)
        snapshot("17-night", app, settle: 6)
    }

    /// The boss of the Old Forest.
    @MainActor
    func testBoss() {
        let app = launch(["-skipTitle", "-seed", "boss"])
        waitFor("hud.boss", app, timeout: 15)
        dismissCelebration(app)
        snapshot("18-boss", app, settle: 1.5)
        tap("hud.heavy", app)
        snapshot("19-heavy", app, settle: 0.4)
    }
}
