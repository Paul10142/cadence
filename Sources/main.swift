import AppKit

// Carry over settings and history from the app's former name first, so the
// defaults below don't overwrite anything the user already had.
Migration.run()

// Give the status item a sensible menu bar slot on first launch. Left to itself
// macOS drops a brand-new item at the far left of the menu bar, which is exactly
// where menu bar managers (Ice, Bartender) keep their hidden section -- so the
// icon exists but nobody can see it. A mid-bar position lands it in plain sight.
let positionKey = "NSStatusItem Preferred Position Item-0"
if UserDefaults.standard.object(forKey: positionKey) == nil {
    UserDefaults.standard.set(460, forKey: positionKey)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
