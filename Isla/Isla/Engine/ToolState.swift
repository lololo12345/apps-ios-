import Foundation

// MARK: - State of each family of tools

struct CountdownState: Codable, Hashable, Sendable {
    var total: TimeInterval
    var end: Date
    /// Remaining seconds while paused.
    var paused: TimeInterval?
    var note: String = ""
    /// Pill / routine: restart automatically every `total` when marked as taken.
    var repeats = false
    /// Presentation: number of parts, and the part you are on.
    var parts = 0
    var part = 1
    /// Charging: battery from → to.
    var batteryFrom = 0
    var batteryTo = 0

    init(total: TimeInterval, now: Date, note: String = "") {
        self.total = total
        end = now.addingTimeInterval(total)
        self.note = note
    }

    func remaining(_ now: Date) -> TimeInterval { paused ?? max(0, end.timeIntervalSince(now)) }
    var start: Date { end.addingTimeInterval(-total) }
}

struct PomodoroState: Codable, Hashable, Sendable {
    enum Phase: String, Codable, Sendable { case work, shortBreak, longBreak }
    var work: TimeInterval = 25 * 60
    var shortBreak: TimeInterval = 5 * 60
    var longBreak: TimeInterval = 15 * 60
    var phase: Phase = .work
    var round = 1
    var completed = 0
    var phaseEnd: Date
    var paused: TimeInterval?

    func length(_ phase: Phase) -> TimeInterval {
        switch phase {
        case .work: work
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }

    /// Moves to the next phase: every 4th break is long.
    mutating func advance(now: Date) {
        if phase == .work {
            completed += 1
            phase = completed % 4 == 0 ? .longBreak : .shortBreak
        } else {
            phase = .work
            round += 1
        }
        paused = nil
        phaseEnd = now.addingTimeInterval(length(phase))
    }
}

struct StopwatchState: Codable, Hashable, Sendable {
    var start: Date
    var paused: TimeInterval?
    var laps: [TimeInterval] = []

    func elapsed(_ now: Date) -> TimeInterval { paused ?? now.timeIntervalSince(start) }
}

struct CountUpState: Codable, Hashable, Sendable {
    var start: Date
    /// Fasting goal in hours (0 = none).
    var goalHours: Double = 0
    /// Previous resets (since-last history).
    var history: [Date] = []
}

struct CounterState: Codable, Hashable, Sendable {
    var value: Double = 0
    var step: Double = 1
    var goal: Double = 0
    var money = false
    /// Quick amounts for expenses.
    var amounts: [Double] = []
    var log: [Double] = []
}

struct StepItem: Codable, Hashable, Sendable {
    var text: String
    /// Answer (flashcards) or extra info.
    var detail: String = ""
    /// Recipe step with its own timer.
    var minutes: Double = 0
}

struct StepsState: Codable, Hashable, Sendable {
    var items: [StepItem]
    var index = 0
    /// Flashcards: answer visible, right and wrong counts.
    var revealed = false
    var right = 0
    var wrong = 0
    /// Workout: sets per exercise, current set, rest seconds and rest end.
    var sets = 0
    var set = 1
    var rest: TimeInterval = 0
    var restEnd: Date?
    /// Recipe step timer end.
    var stepTimerEnd: Date?

    var isFinished: Bool { index >= items.count }
    var current: StepItem? { items.indices.contains(index) ? items[index] : nil }
}

struct ScoreState: Codable, Hashable, Sendable {
    var names = ["Equipo A", "Equipo B"]
    var racket = false
    var points = [0, 0]
    var match = RacketScore()
    var pointsHistory: [[Int]] = []
    var matchHistory: [RacketScore] = []
}

struct TurnClockState: Codable, Hashable, Sendable {
    var players: [String]
    /// Remaining seconds per player.
    var remaining: [TimeInterval]
    var current = 0
    var turnStart: Date
    var paused = false

    func left(_ index: Int, now: Date) -> TimeInterval {
        index == current && !paused ? max(0, remaining[index] - now.timeIntervalSince(turnStart)) : remaining[index]
    }
}

struct RefereeState: Codable, Hashable, Sendable {
    var players: [String] = []
    var result = "Toca para empezar"
    var seed: UInt64 = 1
}

struct LocationState: Codable, Hashable, Sendable {
    var targetLat: Double?
    var targetLon: Double?
    var targetName = ""
    /// Alert radius (bus stop).
    var radius: Double = 400
    var distance: Double?
    var bearing: Double?
    var heading: Double?
    var travelled: Double = 0
    var speed: Double = 0
    var started: Date
    var alerted = false
    var photo: Data?
}

struct BreathingState: Codable, Hashable, Sendable {
    var pattern: BreathPattern = .calm
    var start: Date
    var minutes: Double = 3
    var end: Date { start.addingTimeInterval(minutes * 60) }
}

struct WorldClockState: Codable, Hashable, Sendable {
    var timeZone: String
    var city: String
}

struct EventState: Codable, Hashable, Sendable {
    var title: String
    var start: Date
    var location: String = ""
    var identifier: String = ""
}

enum ToolState: Codable, Hashable, Sendable {
    case countdown(CountdownState)
    case pomodoro(PomodoroState)
    case stopwatch(StopwatchState)
    case countUp(CountUpState)
    case counter(CounterState)
    case steps(StepsState)
    case score(ScoreState)
    case turnClock(TurnClockState)
    case referee(RefereeState)
    case note(String)
    case worldClock(WorldClockState)
    case location(LocationState)
    case breathing(BreathingState)
    case event(EventState)
}

/// One running tool: what the island shows comes from here.
struct ToolSession: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var kind: ToolKind
    var title: String
    var created = Date.now
    var state: ToolState
    var ended = false
}
