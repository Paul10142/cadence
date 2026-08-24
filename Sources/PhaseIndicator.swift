import AppKit

/// Draws the menu bar time with a rule above or below it.
///
/// The time is rendered as a template image rather than styled text because
/// AppKit offers an underline attribute but no overline, and a pomodoro needs
/// to distinguish work from break at a glance.
enum PhaseIndicator {
    static func image(_ text: String, barOnTop: Bool) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = (text as NSString).size(withAttributes: attributes)

        let bar: CGFloat = 2, gap: CGFloat = 2
        let size = NSSize(width: ceil(textSize.width),
                          height: ceil(textSize.height) + bar + gap)

        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            if barOnTop {
                NSRect(x: 0, y: size.height - bar, width: size.width, height: bar).fill()
                (text as NSString).draw(at: .zero, withAttributes: attributes)
            } else {
                NSRect(x: 0, y: 0, width: size.width, height: bar).fill()
                (text as NSString).draw(at: NSPoint(x: 0, y: bar + gap), withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
