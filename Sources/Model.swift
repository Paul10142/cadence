import Foundation

// MARK: - Session

enum SessionKind: String, Codable {
    case stopwatch, timer

    var symbolName: String { self == .stopwatch ? "stopwatch" : "hourglass" }
    var label: String { self == .stopwatch ? "Stopwatch" : "Timer" }
}

struct Session: Codable {
    let seconds: Int
    let date: Date
    var kind: SessionKind = .stopwatch

    init(seconds: Int, date: Date, kind: SessionKind = .stopwatch) {
        self.seconds = seconds
        self.date = date
        self.kind = kind
    }

    // Sessions saved before kinds existed decode as stopwatch entries.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seconds = try c.decode(Int.self, forKey: .seconds)
        date = try c.decode(Date.self, forKey: .date)
        kind = try c.decodeIfPresent(SessionKind.self, forKey: .kind) ?? .stopwatch
    }
}

// MARK: - Formatting

enum TimeFormat {
    /// "00:23", "12:04", "1:02:33"
    static func clock(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "00:23 - Aug 14, 2026 at 4:41 PM"
    static func menuLine(_ session: Session) -> String {
        "\(clock(session.seconds)) - \(stamp.string(from: session.date))"
    }

    static func stampString(_ date: Date) -> String { stamp.string(from: date) }
}

// MARK: - Session store

final class SessionStore {
    static let folderName = "Cadence"

    private(set) var sessions: [Session] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(SessionStore.folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("sessions.json")
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded
            return
        }
        // First launch: bring across history from the original Thyme, if any.
        sessions = LegacyImport.read()
        if !sessions.isEmpty { save() }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func add(seconds: Int, kind: SessionKind = .stopwatch, date: Date = Date()) {
        sessions.append(Session(seconds: seconds, date: date, kind: kind))
        save()
    }

    func clear() {
        sessions.removeAll()
        save()
    }

    /// Oldest first, matching the original app's menu ordering.
    func recent(_ count: Int) -> [Session] {
        Array(sessions.suffix(count))
    }
}

// MARK: - Import from the original Thyme's Core Data XML store

enum LegacyImport {
    static func read() -> [Session] {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thyme/storedata")
        guard let xml = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var result: [Session] = []
        // Each <object type="SESSION"> carries hours/minutes/seconds plus a
        // Core Data reference-date timestamp (seconds since 2001-01-01).
        for block in xml.components(separatedBy: "<object type=\"SESSION\"").dropFirst() {
            let body = block.components(separatedBy: "</object>").first ?? block
            func intAttr(_ name: String) -> Int {
                value(in: body, attribute: name).flatMap { Int($0) } ?? 0
            }
            guard let raw = value(in: body, attribute: "date"),
                  let interval = Double(raw) else { continue }
            let total = intAttr("hours") * 3600 + intAttr("minutes") * 60 + intAttr("seconds")
            guard total > 0 else { continue }
            result.append(Session(seconds: total,
                                  date: Date(timeIntervalSinceReferenceDate: interval)))
        }
        return result.sorted { $0.date < $1.date }
    }

    private static func value(in body: String, attribute: String) -> String? {
        guard let open = body.range(of: "name=\"\(attribute)\"") else { return nil }
        guard let gt = body.range(of: ">", range: open.upperBound..<body.endIndex) else { return nil }
        guard let close = body.range(of: "</attribute>", range: gt.upperBound..<body.endIndex) else { return nil }
        return String(body[gt.upperBound..<close.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
