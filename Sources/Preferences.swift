import AppKit
import Carbon.HIToolbox

/// User settings, backed by UserDefaults.
/// What a plain left click on the menu bar icon does.
enum ClickAction: Int, CaseIterable {
    case menu = 0, stopwatch, countdown, pomodoro

    var label: String {
        switch self {
        case .menu:      return "Open the menu"
        case .stopwatch: return "Start / pause the stopwatch"
        case .countdown: return "Start / pause the countdown timer"
        case .pomodoro:  return "Start / pause the pomodoro timer"
        }
    }
}

final class Preferences {
    static let shared = Preferences()

    enum Key: String {
        case startPause, restart, finish
        case startGeneralTimer, startPomodoroTimer
        case pauseDuringSleep, pauseDuringScreensaver, startOnClick, confirmClear, clickAction
        case timerConfig, announcement
        case alertBlink, alertWindow, alertNotification, alertNotificationSound, alertSpeak
        case displaySeconds, showTimerWindowAtLaunch, lastTimerMode
    }

    static let didChange = Notification.Name("ThymeCustomPreferencesDidChange")

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.pauseDuringSleep.rawValue: true,
            Key.pauseDuringScreensaver.rawValue: true,
            Key.startOnClick.rawValue: true,
            Key.alertBlink.rawValue: true,
            Key.alertWindow.rawValue: true,
            Key.alertNotification.rawValue: true,
            Key.alertNotificationSound.rawValue: true,
            Key.alertSpeak.rawValue: false,
            Key.announcement.rawValue: "Done",
            Key.displaySeconds.rawValue: true,
            Key.showTimerWindowAtLaunch.rawValue: false,
            Key.confirmClear.rawValue: false,
        ])
    }

    // MARK: Shortcuts (none are set out of the box)

    func shortcut(_ key: Key) -> Shortcut? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    func setShortcut(_ shortcut: Shortcut?, for key: Key) {
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
        NotificationCenter.default.post(name: Preferences.didChange, object: nil)
    }

    // MARK: Toggles

    var pauseDuringSleep: Bool {
        get { defaults.bool(forKey: Key.pauseDuringSleep.rawValue) }
        set { defaults.set(newValue, forKey: Key.pauseDuringSleep.rawValue) }
    }

    var pauseDuringScreensaver: Bool {
        get { defaults.bool(forKey: Key.pauseDuringScreensaver.rawValue) }
        set { defaults.set(newValue, forKey: Key.pauseDuringScreensaver.rawValue) }
    }

    /// Left click runs whichever timer is chosen here; the menu is on right click.
    var clickAction: ClickAction {
        get {
            if let raw = defaults.object(forKey: Key.clickAction.rawValue) as? Int {
                return ClickAction(rawValue: raw) ?? .stopwatch
            }
            // Carried over from the older on/off setting.
            if defaults.object(forKey: Key.startOnClick.rawValue) != nil,
               !defaults.bool(forKey: Key.startOnClick.rawValue) {
                return .menu
            }
            return .stopwatch
        }
        set { defaults.set(newValue.rawValue, forKey: Key.clickAction.rawValue) }
    }

    private func flag(_ key: Key) -> Bool { defaults.bool(forKey: key.rawValue) }
    private func setFlag(_ value: Bool, _ key: Key) { defaults.set(value, forKey: key.rawValue) }

    var confirmClear: Bool { get { flag(.confirmClear) } set { setFlag(newValue, .confirmClear) } }
    var alertBlink: Bool { get { flag(.alertBlink) } set { setFlag(newValue, .alertBlink) } }
    var alertWindow: Bool { get { flag(.alertWindow) } set { setFlag(newValue, .alertWindow) } }
    var alertNotification: Bool { get { flag(.alertNotification) } set { setFlag(newValue, .alertNotification) } }
    var alertNotificationSound: Bool { get { flag(.alertNotificationSound) } set { setFlag(newValue, .alertNotificationSound) } }
    var alertSpeak: Bool { get { flag(.alertSpeak) } set { setFlag(newValue, .alertSpeak) } }
    var displaySeconds: Bool { get { flag(.displaySeconds) } set { setFlag(newValue, .displaySeconds) } }
    var showTimerWindowAtLaunch: Bool {
        get { flag(.showTimerWindowAtLaunch) } set { setFlag(newValue, .showTimerWindowAtLaunch) }
    }

    /// 0 = general, 1 = pomodoro. The settings window reopens where you left it.
    var lastTimerMode: Int {
        get { defaults.integer(forKey: Key.lastTimerMode.rawValue) }
        set { defaults.set(newValue, forKey: Key.lastTimerMode.rawValue) }
    }

    var announcement: String {
        get { defaults.string(forKey: Key.announcement.rawValue) ?? "Done" }
        set { defaults.set(newValue, forKey: Key.announcement.rawValue) }
    }

    var timerConfig: CountdownTimer.Config {
        get {
            guard let data = defaults.data(forKey: Key.timerConfig.rawValue),
                  let decoded = try? JSONDecoder().decode(CountdownTimer.Config.self, from: data)
            else { return CountdownTimer.Config() }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.timerConfig.rawValue)
            }
        }
    }
}

// MARK: - Shortcut recorder control

/// A button that records the next key combination you press.
final class ShortcutRecorderButton: NSButton {
    var onChange: ((Shortcut?) -> Void)?

    private var shortcut: Shortcut? { didSet { refreshTitle() } }
    private var recording = false { didSet { refreshTitle() } }
    private var monitor: Any?

    init(shortcut: Shortcut?) {
        super.init(frame: .zero)
        self.shortcut = shortcut
        bezelStyle = .rounded
        target = self
        action = #selector(toggleRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func refreshTitle() {
        if recording {
            title = "Type shortcut  (\u{238B} cancel  \u{232B} clear)"
        } else if let shortcut {
            title = shortcut.display
        } else {
            title = "Click to record shortcut"
        }
    }

    @objc private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.recording else { return event }
            guard event.type == .keyDown else { return nil }

            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }
            if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
                self.shortcut = nil
                self.onChange?(nil)
                self.stopRecording()
                return nil
            }
            if let recorded = Shortcut.from(event: event) {
                self.shortcut = recorded
                self.onChange?(recorded)
                self.stopRecording()
            }
            return nil   // swallow everything while recording
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}

// MARK: - Preferences window

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 330),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Thyme Custom Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildContent() {
        guard let window else { return }
        let content = NSView(frame: window.contentLayoutRect)

        func label(_ text: String) -> NSTextField {
            let f = NSTextField(labelWithString: text)
            f.alignment = .right
            f.translatesAutoresizingMaskIntoConstraints = false
            return f
        }

        let rows: [(String, Preferences.Key)] = [
            ("Start / Pause:", .startPause),
            ("Restart:", .restart),
            ("Finish:", .finish),
            ("Start / Stop General Timer:", .startGeneralTimer),
            ("Start / Stop Pomodoro Timer:", .startPomodoroTimer),
        ]

        let grid = NSGridView(numberOfColumns: 2, rows: 0)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 12

        for (title, key) in rows {
            let button = ShortcutRecorderButton(shortcut: Preferences.shared.shortcut(key))
            button.translatesAutoresizingMaskIntoConstraints = false
            button.onChange = { Preferences.shared.setShortcut($0, for: key) }
            button.widthAnchor.constraint(equalToConstant: 260).isActive = true
            grid.addRow(with: [label(title), button])
        }

        let clickPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        clickPopUp.addItems(withTitles: ClickAction.allCases.map(\.label))
        clickPopUp.selectItem(at: Preferences.shared.clickAction.rawValue)
        clickPopUp.target = self
        clickPopUp.action = #selector(clickActionChanged(_:))

        let clickRow = NSStackView(views: [
            NSTextField(labelWithString: "Clicking the menu bar icon:"), clickPopUp,
        ])
        clickRow.spacing = 8
        clickRow.alignment = .centerY

        let sleepBox = NSButton(checkboxWithTitle: "Pause during sleep", target: self,
                                action: #selector(toggleSleep(_:)))
        sleepBox.state = Preferences.shared.pauseDuringSleep ? .on : .off

        let screensaverBox = NSButton(checkboxWithTitle: "Pause during screensaver / screen lock",
                                      target: self, action: #selector(toggleScreensaver(_:)))
        screensaverBox.state = Preferences.shared.pauseDuringScreensaver ? .on : .off

        let confirmBox = NSButton(checkboxWithTitle: "Ask before clearing sessions",
                                  target: self, action: #selector(toggleConfirmClear(_:)))
        confirmBox.state = Preferences.shared.confirmClear ? .on : .off

        let checks = NSStackView(views: [clickRow, sleepBox, screensaverBox, confirmBox])
        checks.orientation = .vertical
        checks.alignment = .leading
        checks.spacing = 8
        checks.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(grid)
        content.addSubview(checks)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            checks.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 22),
            checks.leadingAnchor.constraint(equalTo: grid.leadingAnchor),
            checks.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
        ])

        window.contentView = content
        // Size to the content so nothing is clipped as rows are added.
        window.setContentSize(content.fittingSize)
    }

    @objc private func toggleConfirmClear(_ sender: NSButton) {
        Preferences.shared.confirmClear = (sender.state == .on)
    }

    @objc private func clickActionChanged(_ sender: NSPopUpButton) {
        Preferences.shared.clickAction = ClickAction(rawValue: sender.indexOfSelectedItem) ?? .stopwatch
    }

    @objc private func toggleSleep(_ sender: NSButton) {
        Preferences.shared.pauseDuringSleep = (sender.state == .on)
    }

    @objc private func toggleScreensaver(_ sender: NSButton) {
        Preferences.shared.pauseDuringScreensaver = (sender.state == .on)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
