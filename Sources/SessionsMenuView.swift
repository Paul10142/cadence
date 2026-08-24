import AppKit

/// Top-down layout, so rows can be positioned from the top edge.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// The session history, rendered as a single scrollable menu row.
///
/// Drawing the list ourselves rather than as many NSMenuItems keeps the menu's
/// item count constant when the list is expanded, which is what stops the rest
/// of the menu shifting, and lets a long history scroll instead of pushing
/// Preferences and Quit off the bottom of the screen.
final class SessionsMenuView: NSView {

    static let rowHeight: CGFloat = 20
    static let maxVisibleRows = 20

    init(sessions: [Session], width: CGFloat = 300) {
        let visibleRows = min(sessions.count, Self.maxVisibleRows)
        let visibleHeight = CGFloat(visibleRows) * Self.rowHeight
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: visibleHeight + 8))

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 4, width: width, height: visibleHeight))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = sessions.count > Self.maxVisibleRows
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.autoresizingMask = [.width, .height]

        let contentHeight = max(CGFloat(sessions.count) * Self.rowHeight, visibleHeight)
        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: contentHeight))

        for (index, session) in sessions.enumerated() {
            let row = Self.makeRow(session, width: width)
            row.frame = NSRect(x: 0, y: CGFloat(index) * Self.rowHeight,
                               width: width, height: Self.rowHeight)
            document.addSubview(row)
        }

        scroll.documentView = document
        addSubview(scroll)

        // Sessions run oldest first, so open on the most recent ones.
        if contentHeight > visibleHeight {
            document.scroll(NSPoint(x: 0, y: contentHeight - visibleHeight))
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private static func makeRow(_ session: Session, width: CGFloat) -> NSView {
        let row = FlippedView()

        let glyph = NSImageView()
        glyph.translatesAutoresizingMaskIntoConstraints = false
        if let icon = NSImage(systemSymbolName: session.kind.symbolName,
                              accessibilityDescription: session.kind.label) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            let sized = icon.withSymbolConfiguration(config) ?? icon
            sized.isTemplate = true
            glyph.image = sized
        }
        glyph.contentTintColor = .secondaryLabelColor
        glyph.toolTip = session.kind.label

        let label = NSTextField(labelWithString: TimeFormat.menuLine(session))
        label.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.toolTip = session.kind.label

        row.addSubview(glyph)
        row.addSubview(label)
        NSLayoutConstraint.activate([
            glyph.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            glyph.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            glyph.widthAnchor.constraint(equalToConstant: 14),
            label.leadingAnchor.constraint(equalTo: glyph.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -12),
        ])
        return row
    }
}
