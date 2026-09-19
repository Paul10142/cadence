import Foundation

/// Carries settings and session history forward whenever the app's identity
/// changes, so a rename or a new bundle identifier costs the user nothing.
///
/// The app has had three identities: `com.paulclancy.ThymeCustom` (the original
/// name), `com.paulclancy.Cadence` (the rename), and the current one. Each move
/// leaves the previous settings stranded in their own defaults domain, so on a
/// first run the old domains are read newest-first and anything the new domain
/// does not already have is copied over.
enum Migration {
    private static let flagKey = "migratedFromPreviousIdentity"
    private static let oldFolder = "Thyme Custom"

    /// Newest first, so a key still present in two old domains takes its value
    /// from the more recent one.
    private static let previousDomains = [
        "com.paulclancy.Cadence",
        "com.paulclancy.ThymeCustom",
    ]

    /// Menu bar placement is deliberately not inherited. These keys record which
    /// slot macOS gave the icon under the *old* identity; carrying them over
    /// re-imports a placement the system has already made up its mind about,
    /// which is exactly what a new identity is meant to leave behind.
    private static func isMenuBarPlacement(_ key: String) -> Bool {
        key.hasPrefix("NSStatusItem ")
    }

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }

        // Settings: copy anything the new domain doesn't already have.
        for domain in previousDomains {
            guard let previous = defaults.persistentDomain(forName: domain) else { continue }
            for (key, value) in previous
            where defaults.object(forKey: key) == nil && !isMenuBarPlacement(key) {
                defaults.set(value, forKey: key)
            }
        }

        // Sessions. The store is keyed by folder name rather than bundle
        // identifier, so history survives an identity change on its own; this
        // only has to cover the original name.
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
        // The old flag is kept in step so a build from before this change,
        // running against the same domain, does not migrate a second time.
        defaults.set(true, forKey: "migratedFromThymeCustom")
    }
}
