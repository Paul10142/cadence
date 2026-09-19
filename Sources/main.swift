import AppKit

// Carry over settings and history from the app's former identities first, so
// the defaults below don't overwrite anything the user already had.
Migration.run()

// Give the status item a sensible menu bar slot on first launch. Left to itself
// macOS drops a brand-new item at the far left of the menu bar, which is exactly
// where menu bar managers (Ice, Bartender) keep their hidden section -- so the
// icon exists but nobody can see it.
//
// The number is a distance leftwards from the right-hand end of the bar, so a
// *smaller* value sits further right. It has to stay clear of the hidden
// section, and a manager's divider is itself just another item with a position:
// Ice's "hidden" divider on the machine this was written for sits at 453, and
// the 460 used here previously landed seven units the wrong side of it, hiding
// the icon it was meant to reveal. 300 leaves room for a divider to be dragged
// a good way rightwards before the icon disappears behind it again.
let positionKey = "NSStatusItem Preferred Position Item-0"
if UserDefaults.standard.object(forKey: positionKey) == nil {
    UserDefaults.standard.set(300, forKey: positionKey)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
