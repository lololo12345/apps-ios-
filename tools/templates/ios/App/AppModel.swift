import Foundation
import Observation
import SwiftUI

/// Light or dark, or whatever the iPhone uses. Chosen in Ajustes → Apariencia.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automático"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    /// nil = follow the iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// App-wide state. Settings persist in UserDefaults; UI tests get a fresh, separate store every launch.
@Observable
@MainActor
final class AppModel {
    static let defaultAppearance: Appearance = .__default_appearance__

    private let defaults: UserDefaults

    var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.haptics) } }
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    var launchCount: Int { didSet { defaults.set(launchCount, forKey: Keys.launches) } }

    private enum Keys {
        static let haptics = "settings.haptics", appearance = "settings.appearance", launches = "app.launches"
    }

    init(defaults: UserDefaults = LaunchOptions.defaults) {
        self.defaults = defaults
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        // UI tests can force one (`-appearance dark`) to take screenshots of both modes.
        let saved = LaunchOptions.value(after: "-appearance") ?? defaults.string(forKey: Keys.appearance)
        appearance = saved.flatMap(Appearance.init(rawValue:)) ?? Self.defaultAppearance
        launchCount = defaults.integer(forKey: Keys.launches) + 1
        defaults.set(launchCount, forKey: Keys.launches)
    }

    func reset() {
        hapticsOn = true
        appearance = Self.defaultAppearance
        launchCount = 1
    }
}
