import Foundation

/// Flags passed by the UI tests (`app.launchArguments`). Never active in a normal launch.
enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    /// `-flag value` pairs, e.g. `-playerName Lola`.
    static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Real defaults normally; an empty, throw-away suite under UI tests so every test starts clean.
    static var defaults: UserDefaults {
        guard isUITesting else { return .standard }
        let suite = "app.mochila.travel.uitests"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }
}
