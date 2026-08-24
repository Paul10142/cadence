import Foundation

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
