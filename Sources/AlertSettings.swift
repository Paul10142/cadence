import Foundation

/// What happens when a timer reaches zero.
///
/// These exist in two layers. Preferences holds the general set, which is what
/// every timer starts from. The timer settings window opens showing that set,
/// and any change made there rides along with that one run and is then
/// forgotten -- so a one-off timer can announce itself differently without
/// disturbing the settings you normally want.
struct AlertSettings: Equatable {
    var blink = true
    var window = true
    var notification = true
    var notificationSound = true
    var speak = false
    var announcement = "Done"
}
