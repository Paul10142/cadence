import AppKit
import ServiceManagement

/// Launching Cadence at login. A menu bar app people forget to reopen is a menu
/// bar app they stop using, so this is offered once, on the first run.
enum LoginItem {

    /// False when running the bare binary rather than the bundled app, where
    /// there is nothing for the system to register.
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Returns false if the system refused, in which case the Login Items pane
    /// is the fallback -- the user can add Cadence there by hand.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard isAvailable else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    static func openLoginItemsSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Shown once, the first time Cadence runs. Answering it either way is the
    /// end of it: the checkbox in Preferences takes over from here.
    static func offerOnFirstLaunch() {
        let prefs = Preferences.shared
        guard isAvailable, !prefs.openAtLoginOffered else { return }
        prefs.openAtLoginOffered = true
        guard !isEnabled else { return }

        let alert = NSAlert()
        alert.messageText = "Open Cadence at login?"
        alert.informativeText = """
            Cadence lives in the menu bar with no dock icon, so it is easy to \
            forget to start it. Opening it automatically at login keeps it there. \
            You can change this any time in Cadence Preferences.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open at Login")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard !setEnabled(true) else { return }

        // The system declined -- usually an unsigned or quarantined copy. Point
        // the user at the pane where they can add it themselves.
        let failed = NSAlert()
        failed.messageText = "Add Cadence in Login Items"
        failed.informativeText = """
            macOS wouldn't let Cadence add itself. Opening Login Items now -- \
            click + under "Open at Login" and choose Cadence from Applications.
            """
        failed.addButton(withTitle: "Open Login Items")
        failed.addButton(withTitle: "Cancel")
        if failed.runModal() == .alertFirstButtonReturn { openLoginItemsSettings() }
    }
}
