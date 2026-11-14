import ActivityKit
import AppIntents
import Foundation

/// A clock region the system animates by itself (no updates needed): countdown or count-up.
public struct IslaTimer: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var countsDown: Bool
    /// When set, the timer is frozen and shows this many seconds.
    public var frozen: TimeInterval?

    public init(start: Date, end: Date, countsDown: Bool, frozen: TimeInterval? = nil) {
        self.start = start
        self.end = end
        self.countsDown = countsDown
        self.frozen = frozen
    }

    /// Count-up from `start` that keeps running for a day.
    public static func countUp(from start: Date) -> IslaTimer {
        IslaTimer(start: start, end: start.addingTimeInterval(24 * 3600), countsDown: false)
    }
}

public enum IslaProgress: Codable, Hashable, Sendable {
    /// Fixed fraction 0…1.
    case value(Double)
    /// Animates from start to end on its own.
    case timer(Date, Date)
}

public struct IslaButton: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var symbol: String
    public var prominent: Bool

    public init(_ id: String, _ title: String, _ symbol: String, prominent: Bool = false) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.prominent = prominent
    }
}

/// Everything the island and the Lock Screen show for one tool. Built by the app's engine.
public struct IslaDisplay: Codable, Hashable, Sendable {
    public var headline: String
    public var detail: String?
    /// Big value when there is no timer ("7", "15 – 30", "42 €").
    public var value: String?
    public var timer: IslaTimer?
    public var progress: IslaProgress?
    public var buttons: [IslaButton]
    public var finished: Bool
    /// Replaces the tool symbol (e.g. an arrow pointing to the car).
    public var symbol: String?
    /// Degrees to rotate `symbol` (direction arrows).
    public var rotation: Double?

    public init(headline: String, detail: String? = nil, value: String? = nil, timer: IslaTimer? = nil, progress: IslaProgress? = nil,
                buttons: [IslaButton] = [], finished: Bool = false, symbol: String? = nil, rotation: Double? = nil) {
        self.headline = headline
        self.detail = detail
        self.value = value
        self.timer = timer
        self.progress = progress
        self.buttons = buttons
        self.finished = finished
        self.symbol = symbol
        self.rotation = rotation
    }
}

public struct IslaAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var display: IslaDisplay
        public init(display: IslaDisplay) { self.display = display }
    }

    public var sessionID: String
    public var kind: ToolKind
    public var title: String

    public init(sessionID: String, kind: ToolKind, title: String) {
        self.sessionID = sessionID
        self.kind = kind
        self.title = title
    }
}

/// Routes island button taps to the app's engine. The intent always runs in the app's process.
@MainActor
public final class IslaActionRouter {
    public static let shared = IslaActionRouter()
    public var handler: ((String, String) async -> Void)?

    public func handle(session: String, action: String) async {
        await handler?(session, action)
    }
}

/// A button inside a Live Activity (pause, +1 min, «Cogido», +1 point…).
public struct IslaActionIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Acción de Isla"
    public static let isDiscoverable = false

    @Parameter(title: "Sesión") public var session: String
    @Parameter(title: "Acción") public var action: String

    public init() {}

    public init(session: String, action: String) {
        self.session = session
        self.action = action
    }

    public func perform() async throws -> some IntentResult {
        await IslaActionRouter.shared.handle(session: session, action: action)
        return .result()
    }
}
