import Foundation

/// Counts down, optionally cycling between work and break periods for a set
/// number of rounds. Like the stopwatch, remaining time is derived from dates
/// rather than accumulated per tick, so it cannot drift.
final class CountdownTimer {

    enum Phase { case work, rest }
    enum State { case idle, running, paused, finished }

    struct Config: Codable, Equatable {
        var duration: TimeInterval = 10 * 60      // plain countdown
        var cycling: Bool = false
        var workDuration: TimeInterval = 25 * 60
        var breakDuration: TimeInterval = 5 * 60
        var rounds: Int = 4
    }

    private(set) var state: State = .idle
    private(set) var phase: Phase = .work
    private(set) var round = 1
    private(set) var config = Config()

    /// Length of the period currently being counted down.
    private(set) var phaseLength: TimeInterval = 0

    private var endsAt: Date?
    private var remainingWhenPaused: TimeInterval = 0
    private var ticker: Timer?

    var onTick: (() -> Void)?
    /// (finished phase, its length, whether the whole run is now over)
    var onPhaseComplete: ((Phase, TimeInterval, Bool) -> Void)?

    var isActive: Bool { state != .idle }

    var remaining: TimeInterval {
        switch state {
        case .running: return max(0, endsAt?.timeIntervalSinceNow ?? 0)
        case .paused:  return remainingWhenPaused
        case .idle, .finished: return 0
        }
    }

    var remainingSeconds: Int { Int(remaining.rounded(.up)) }

    /// "Round 2 of 4 · Break" — nil when nothing is running.
    var statusLine: String? {
        guard isActive else { return nil }
        guard config.cycling else {
            return state == .finished ? "Timer finished" : "Countdown"
        }
        if state == .finished { return "All \(config.rounds) rounds complete" }
        return "Round \(round) of \(config.rounds) \u{00B7} \(phase == .work ? "Work" : "Break")"
    }

    // MARK: Commands

    func start(config: Config) {
        self.config = config
        round = 1
        phase = .work
        begin(config.cycling ? config.workDuration : config.duration)
    }

    func pause() {
        guard state == .running else { return }
        remainingWhenPaused = remaining
        endsAt = nil
        state = .paused
        stopTicking()
        onTick?()
    }

    func resume() {
        guard state == .paused else { return }
        endsAt = Date().addingTimeInterval(remainingWhenPaused)
        state = .running
        startTicking()
        onTick?()
    }

    /// Back to the start of the current run, still armed.
    func restart() {
        guard isActive else { return }
        round = 1
        phase = .work
        begin(config.cycling ? config.workDuration : config.duration)
    }

    func stop() {
        state = .idle
        endsAt = nil
        remainingWhenPaused = 0
        phaseLength = 0
        stopTicking()
        onTick?()
    }

    /// Clears the finished state once the user has seen the alert.
    func acknowledge() {
        guard state == .finished else { return }
        stop()
    }

    // MARK: Internals

    private func begin(_ length: TimeInterval) {
        phaseLength = length
        endsAt = Date().addingTimeInterval(length)
        state = .running
        startTicking()
        onTick?()
    }

    private func tick() {
        guard state == .running else { return }
        if remaining <= 0 { completePhase() } else { onTick?() }
    }

    private func completePhase() {
        let finished = phase
        let length = phaseLength
        stopTicking()

        let isLastWorkRound = config.cycling && phase == .work && round >= config.rounds
        let runIsOver = !config.cycling || isLastWorkRound

        if runIsOver {
            state = .finished
            endsAt = nil
        } else if phase == .work {
            phase = .rest
            begin(config.breakDuration)
        } else {
            phase = .work
            round += 1
            begin(config.workDuration)
        }

        onPhaseComplete?(finished, length, runIsOver)
        onTick?()
    }

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
