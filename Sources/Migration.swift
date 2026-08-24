import Foundation

/// Carries settings and session history over from the app's former name so a
/// rename costs the user nothing.
enum Migration {
    private static let flagKey = "migratedFromThymeCustom"
    private static let oldDomain = "com.paulclancy.ThymeCustom"
    private static let oldFolder = "Thyme Custom"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }

        // Settings: copy anything the new domain doesn't already have.
        if let previous = defaults.persistentDomain(forName: oldDomain) {
            for (key, value) in previous where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        // Sessions.
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let destination = base.appendingPathComponent("\(SessionStore.folderName)/sessions.json")
        let source = base.appendingPathComponent("\(oldFolder)/sessions.json")
        if !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: source.path) {
            try? fm.createDirectory(at: destination.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
            try? fm.copyItem(at: source, to: destination)
        }

        defaults.set(true, forKey: flagKey)
    }
}
