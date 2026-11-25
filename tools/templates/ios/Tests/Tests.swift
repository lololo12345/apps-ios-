import Foundation
import Testing
@testable import __name__

@Suite("App")
@MainActor
struct AppModelTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "__name__.tests.\(UUID().uuidString)")!
    }

    @Test func startsWithSensibleDefaults() {
        let model = AppModel(defaults: makeDefaults())
        #expect(model.hapticsOn)
        #expect(model.appearance == AppModel.defaultAppearance)
        #expect(model.launchCount == 1)
    }

    @Test func appearanceIsRememberedAndReset() {
        let defaults = makeDefaults()
        let model = AppModel(defaults: defaults)
        model.appearance = .dark
        #expect(AppModel(defaults: defaults).appearance == .dark)
        model.hapticsOn = false
        model.reset()
        #expect(model.hapticsOn)
        #expect(model.appearance == AppModel.defaultAppearance)
    }

    @Test func appearanceOptions() {
        #expect(Appearance.allCases.map(\.title) == ["Automático", "Claro", "Oscuro"])
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }

    @Test func formatting() {
        #expect(12345.grouped == "12.345")
        #expect("domingo, 15 de noviembre".sentenceCased == "Domingo, 15 de noviembre")
        #expect(Greeting.text(hour: 9) == "Buenos días")
        #expect(Greeting.text(hour: 16) == "Buenas tardes")
        #expect(Greeting.text(hour: 23) == "Buenas noches")
        #expect(Greeting.text(hour: 3) == "Buenas noches")
    }
}
