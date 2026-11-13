import Foundation
import Observation

/// Time base of the teleprompter. It stores only an anchor (elapsed + start date), and views derive
/// the current position from the display-link date. Nothing is mutated per frame, so scrolling stays
/// at the screen's native refresh rate (up to 120 Hz on ProMotion) with negligible CPU cost.
@MainActor
@Observable
final class PrompterEngine {
    private(set) var isRunning = false
    private(set) var baseElapsed: Double = 0
    private(set) var speed: Double = 1
    private(set) var totalTime: Double = 0
    private(set) var didReachEnd = false

    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var endTask: Task<Void, Never>?

    func configure(totalTime: Double, speed: Double) {
        self.totalTime = max(0, totalTime)
        self.speed = speed
        baseElapsed = min(baseElapsed, self.totalTime)
    }

    func elapsed(at date: Date) -> Double {
        guard isRunning, let startDate else { return baseElapsed }
        return min(totalTime, baseElapsed + max(0, date.timeIntervalSince(startDate)) * speed)
    }

    var progress: Double {
        totalTime > 0 ? elapsed(at: .now) / totalTime : 0
    }

    func play() {
        guard !isRunning, totalTime > 0 else { return }
        if baseElapsed >= totalTime - 0.05 { baseElapsed = 0 }
        didReachEnd = false
        startDate = .now
        isRunning = true
        scheduleEnd()
    }

    func pause() {
        guard isRunning else { return }
        baseElapsed = elapsed(at: .now)
        isRunning = false
        startDate = nil
        endTask?.cancel()
    }

    func toggle() {
        isRunning ? pause() : play()
    }

    func seek(to time: Double) {
        baseElapsed = min(max(0, time), totalTime)
        didReachEnd = false
        if isRunning {
            startDate = .now
            scheduleEnd()
        }
    }

    func restart() {
        pause()
        baseElapsed = 0
        didReachEnd = false
    }

    func setSpeed(_ newValue: Double) {
        if isRunning {
            let now = Date.now
            baseElapsed = elapsed(at: now)
            startDate = now
        }
        speed = newValue
        if isRunning { scheduleEnd() }
    }

    private func scheduleEnd() {
        endTask?.cancel()
        let remaining = max(0, (totalTime - baseElapsed) / max(speed, 0.1))
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard isRunning else { return }
        baseElapsed = totalTime
        isRunning = false
        startDate = nil
        didReachEnd = true
    }
}
