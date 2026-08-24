import AppKit

/// A menu row that runs an action *without* dismissing the menu.
/// A plain NSMenuItem always closes the menu when clicked; a custom view
/// handles the click itself, so the menu stays open.
final class MenuToggleItemView: NSView {

    private let label = NSTextField(labelWithString: "")
    private let onClick: () -> Void
    private var highlighted = false { didSet { needsDisplay = true; restyle() } }

    init(title: String, width: CGFloat = 260, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))

        label.font = .menuFont(ofSize: 0)
        label.stringValue = title
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        restyle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { highlighted = true }
    override func mouseExited(with event: NSEvent) { highlighted = false }
    override func mouseUp(with event: NSEvent) { onClick() }

    private func restyle() {
        label.textColor = highlighted ? .selectedMenuItemTextColor : .labelColor
    }

    override func draw(_ dirtyRect: NSRect) {
        guard highlighted else { return }
        let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0),
                                   xRadius: 4, yRadius: 4)
        NSColor.selectedContentBackgroundColor.setFill()
        rounded.fill()
    }
}
