import Foundation

// Menu bar formatting: seconds always tick, and anything an hour or over reads
// as hours:minutes rather than a runaway minute count.
var formatFailures: [String] = []
func expect(_ actual: String, _ expected: String, _ what: String) {
    if actual != expected { formatFailures.append("\(what): got \(actual), expected \(expected)") }
}
expect(TimeFormat.clock(60 * 60), "1:00:00", "60 min with seconds")
expect(TimeFormat.clock(135 * 60), "2:15:00", "2h15m with seconds")
expect(TimeFormat.clock(59), "00:59", "59s with seconds")
expect(TimeFormat.minuteClock(135 * 60), "2:15", "2h15m without seconds")
expect(TimeFormat.minuteClock(45 * 60), "45m", "45 min without seconds")
expect(TimeFormat.minuteClock(30), "1m", "30s without seconds")
expect(TimeFormat.minuteClock(0), "<1m", "zero without seconds")
if formatFailures.isEmpty {
    print("formatting: PASS")
} else {
    formatFailures.forEach { print("formatting: \($0)") }
    print("formatting: FAIL")
    exit(1)
}

// Exercises the work/break cycling state machine at high speed.
let t = CountdownTimer()
var log: [String] = []

var config = CountdownTimer.Config()
config.cycling = true
config.workDuration = 0.3
config.breakDuration = 0.2
config.rounds = 3

t.onPhaseComplete = { phase, length, runIsOver in
    log.append("\(phase == .work ? "WORK" : "BREAK") done (\(String(format: "%.1f", length))s) over=\(runIsOver)")
    if runIsOver {
        print("--- sequence ---")
        log.forEach { print($0) }
        let works = log.filter { $0.hasPrefix("WORK") }.count
        let breaks = log.filter { $0.hasPrefix("BREAK") }.count
        print("work intervals: \(works) (expected 3)")
        print("break intervals: \(breaks) (expected 2)")
        print("final round reached: \(t.round) (expected 3)")
        print(works == 3 && breaks == 2 && t.round == 3 ? "PASS" : "FAIL")
        exit(works == 3 && breaks == 2 && t.round == 3 ? 0 : 1)
    }
}
t.start(config: config)
RunLoop.main.run(until: Date().addingTimeInterval(5))
print("TIMEOUT - FAIL")
exit(1)
