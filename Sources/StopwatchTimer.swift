import Foundation

/// Wall-clock accurate stopwatch: elapsed time is derived from dates, never
/// accumulated tick-by-tick, so it cannot drift.
final class StopwatchTimer {
    enum State { case idle, running, paused }

    private(set) var state: State = .idle
    private var accumulated: TimeInterval = 0
    private var startedAt: Date?

    var onTick: (() -> Void)?

    private var ticker: Timer?

    var elapsed: TimeInterval {
        if let startedAt, state == .running {
            return accumulated + Date().timeIntervalSince(startedAt)
        }
        return accumulated
    }

    var elapsedSeconds: Int { Int(elapsed) }

    // MARK: Commands

    func start() {
        guard state != .running else { return }
        startedAt = Date()
        state = .running
        startTicking()
        onTick?()
    }

    func pause() {
        guard state == .running, let startedAt else { return }
        accumulated += Date().timeIntervalSince(startedAt)
        self.startedAt = nil
        state = .paused
        stopTicking()
        onTick?()
    }

    /// Throw away the current count and begin again from zero.
    func restart() {
        accumulated = 0
        startedAt = Date()
        state = .running
        startTicking()
        onTick?()
    }

    /// Stop, and hand back the elapsed seconds so they can be recorded.
    @discardableResult
    func finish() -> Int {
        let seconds = elapsedSeconds
        reset()
        return seconds
    }

    func reset() {
        accumulated = 0
        startedAt = nil
        state = .idle
        stopTicking()
        onTick?()
    }

    // MARK: Ticking

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.onTick?() }
        // .common keeps the display live while menus and tracking loops run.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
