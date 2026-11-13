import Foundation

/// UserDefaults keys. Defaults live next to each `@AppStorage` declaration via `PrefDefault`.
enum PrefKey {
    static let onboardingCompleted = "onboarding.completed"
    static let wordsPerMinute = "speech.wordsPerMinute"
    static let defaultTarget = "story.defaultTarget"
    static let prompterFontSize = "prompter.fontSize"
    static let prompterMirror = "prompter.mirror"
    static let prompterCountdown = "prompter.countdown"
    static let prompterSpeed = "prompter.speed"
    static let haptics = "haptics.enabled"
    static let reminderEnabled = "reminder.enabled"
    static let reminderHour = "reminder.hour"
    static let reminderMinute = "reminder.minute"
    static let partLength = "parts.maxSeconds"
}

enum PrefDefault {
    static let wordsPerMinute = ScriptMetrics.defaultWordsPerMinute
    static let defaultTarget = 60
    static let prompterFontSize: Double = 34
    static let prompterSpeed: Double = 1
    static let reminderHour = 19
    static let reminderMinute = 0
    static let partLength = 60
    static let prompterFontRange: ClosedRange<Double> = 22...56
    static let prompterSpeedRange: ClosedRange<Double> = 0.5...2
}

/// Launch arguments used by UI tests and screenshot runs.
enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var forceOnboarding: Bool { arguments.contains("-showOnboarding") }
    static var forceDark: Bool { arguments.contains("-forceDark") }
    static func has(_ flag: String) -> Bool { arguments.contains(flag) }
}
