import AppKit

/// Hours : minutes : seconds entry, three fields each with a stepper.
final class DurationField: NSView {
    private let hours = NSTextField(), minutes = NSTextField(), seconds = NSTextField()
    private let hoursStep = NSStepper(), minutesStep = NSStepper(), secondsStep = NSStepper()

    var duration: TimeInterval {
        get { TimeInterval(hours.integerValue * 3600 + minutes.integerValue * 60 + seconds.integerValue) }
        set {
            let total = Int(newValue)
            set(hours, hoursStep, total / 3600)
            set(minutes, minutesStep, (total % 3600) / 60)
            set(seconds, secondsStep, total % 60)
        }
    }

    init(showLabels: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        var columns: [NSView] = []
        for (field, stepper, cap, name) in [(hours, hoursStep, 23, "Hours"),
                                            (minutes, minutesStep, 59, "Minutes"),
                                            (seconds, secondsStep, 59, "Seconds")] {
            configure(field, stepper, max: cap)
            let pair = NSStackView(views: [field, stepper])
            pair.spacing = 2
            let column: NSView
            if showLabels {
                let caption = NSTextField(labelWithString: name)
                caption.font = .systemFont(ofSize: 10)
                caption.textColor = .secondaryLabelColor
                caption.alignment = .center
                let v = NSStackView(views: [pair, caption])
                v.orientation = .vertical
                v.spacing = 2
                v.alignment = .centerX
                column = v
            } else {
                column = pair
            }
            columns.append(column)
            if name != "Seconds" {
                let colon = NSTextField(labelWithString: ":")
                columns.append(colon)
            }
        }

        let row = NSStackView(views: columns)
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func configure(_ field: NSTextField, _ stepper: NSStepper, max cap: Int) {
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.formatter = twoDigitFormatter(max: cap)
        field.widthAnchor.constraint(equalToConstant: 46).isActive = true
        field.target = self
        field.action = #selector(fieldChanged(_:))

        stepper.minValue = 0
        stepper.maxValue = Double(cap)
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))
    }

    private func twoDigitFormatter(max cap: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.minimumIntegerDigits = 2
        f.maximum = NSNumber(value: cap)
        f.minimum = 0
        f.allowsFloats = false
        return f
    }

    private func set(_ field: NSTextField, _ stepper: NSStepper, _ value: Int) {
        field.integerValue = value
        stepper.integerValue = value
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        switch sender {
        case hoursStep:   hours.integerValue = sender.integerValue
        case minutesStep: minutes.integerValue = sender.integerValue
        default:          seconds.integerValue = sender.integerValue
        }
    }

    @objc private func fieldChanged(_ sender: NSTextField) {
        switch sender {
        case hours:   hoursStep.integerValue = sender.integerValue
        case minutes: minutesStep.integerValue = sender.integerValue
        default:      secondsStep.integerValue = sender.integerValue
        }
    }
}

// MARK: - Timer settings window

final class TimerSettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = TimerSettingsWindowController()

    enum Mode: Int { case general = 0, pomodoro = 1 }

    /// Called when the user presses Start.
    var onStart: ((CountdownTimer.Config) -> Void)?

    private var mode: Mode = .general

    private let modePicker = NSSegmentedControl(labels: ["General", "Pomodoro"],
                                                trackingMode: .selectOne, target: nil, action: nil)
    private let countdown = DurationField()
    private lazy var generalRow: NSStackView = {
        let row = NSStackView(views: [NSTextField(labelWithString: "Countdown:"), countdown])
        row.spacing = 10
        row.alignment = .centerY
        return row
    }()

    private let workField = NSTextField(), breakField = NSTextField(), roundsField = NSTextField()
    private let workStep = NSStepper(), breakStep = NSStepper(), roundsStep = NSStepper()
    private var pomodoroRows: NSStackView!

    private let blinkBox = NSButton(checkboxWithTitle: "Blink in menu bar", target: nil, action: nil)
    private let windowBox = NSButton(checkboxWithTitle: "Show alert window", target: nil, action: nil)
    private let notifyBox = NSButton(checkboxWithTitle: "Show notification", target: nil, action: nil)
    private let notifySoundBox = NSButton(checkboxWithTitle: "With sound", target: nil, action: nil)
    private let speakBox = NSButton(checkboxWithTitle: "Speak announcement", target: nil, action: nil)
    private let announcement = NSTextField()
    private let secondsBox = NSButton(checkboxWithTitle: "Display seconds in menu bar", target: nil, action: nil)
    private let atLaunchBox = NSButton(checkboxWithTitle: "Show this window when application starts", target: nil, action: nil)

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Timer Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Layout

    private func buildContent() {
        guard let window else { return }

        func heading(_ text: String) -> NSTextField {
            let f = NSTextField(labelWithString: text)
            f.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
            return f
        }

        modePicker.target = self
        modePicker.action = #selector(modeChanged)
        modePicker.selectedSegment = 0
        modePicker.controlSize = .large
        modePicker.segmentDistribution = .fillEqually
        modePicker.setWidth(110, forSegment: 0)
        modePicker.setWidth(110, forSegment: 1)
        let pickerRow = NSStackView(views: [NSView(), modePicker, NSView()])
        pickerRow.distribution = .fill

        for (field, stepper, cap) in [(workField, workStep, 600.0), (breakField, breakStep, 600.0),
                                      (roundsField, roundsStep, 99.0)] {
            field.alignment = .center
            field.widthAnchor.constraint(equalToConstant: 48).isActive = true
            stepper.minValue = 1
            stepper.maxValue = cap
            stepper.target = self
            stepper.action = #selector(cycleStepperChanged(_:))
        }

        func labelled(_ text: String, _ field: NSTextField, _ stepper: NSStepper, _ suffix: String) -> NSStackView {
            let caption = NSTextField(labelWithString: text)
            caption.alignment = .right
            caption.widthAnchor.constraint(equalToConstant: 62).isActive = true
            let row = NSStackView(views: [caption, field, stepper, NSTextField(labelWithString: suffix)])
            row.spacing = 6
            row.alignment = .centerY
            return row
        }

        pomodoroRows = NSStackView(views: [
            labelled("Work:", workField, workStep, "minutes"),
            labelled("Break:", breakField, breakStep, "minutes"),
            labelled("Rounds:", roundsField, roundsStep, "\u{00D7}"),
        ])
        pomodoroRows.orientation = .vertical
        pomodoroRows.alignment = .leading
        pomodoroRows.spacing = 6

        notifyBox.target = self
        notifyBox.action = #selector(notificationToggled)

        let indentedSound = NSStackView(views: [notifySoundBox])
        indentedSound.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)

        let alerts = NSStackView(views: [blinkBox, windowBox, notifyBox, indentedSound, speakBox])
        alerts.orientation = .vertical
        alerts.alignment = .leading
        alerts.spacing = 6

        announcement.placeholderString = "Done"

        let start = NSButton(title: "Start", target: self, action: #selector(startPressed))
        start.keyEquivalent = "\r"
        start.bezelStyle = .rounded
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.keyEquivalent = "\u{1b}"
        cancel.bezelStyle = .rounded
        let buttons = NSStackView(views: [NSView(), cancel, start])
        buttons.spacing = 10

        let stack = NSStackView(views: [
            pickerRow,
            generalRow,
            pomodoroRows,
            heading("When the timer reaches 00:00:00:"),
            alerts,
            heading("Announcement:"),
            announcement,
            secondsBox,
            atLaunchBox,
            buttons,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(16, after: pickerRow)
        stack.setCustomSpacing(18, after: generalRow)
        stack.setCustomSpacing(18, after: pomodoroRows)
        stack.setCustomSpacing(14, after: alerts)
        stack.setCustomSpacing(16, after: announcement)
        stack.setCustomSpacing(16, after: atLaunchBox)

        let content = NSView()
        content.addSubview(stack)
        let pad: CGFloat = 20
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: pad),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -pad),
            pickerRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            announcement.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        window.contentView = content

        applyMode()
        // Size the window to exactly what the content needs, so there is no
        // dead space on the right.
        window.setContentSize(content.fittingSize)
    }

    // MARK: Loading and saving

    private func load() {
        let prefs = Preferences.shared
        let config = prefs.timerConfig

        countdown.duration = config.duration
        workField.integerValue = Int(config.workDuration / 60)
        workStep.integerValue = workField.integerValue
        breakField.integerValue = Int(config.breakDuration / 60)
        breakStep.integerValue = breakField.integerValue
        roundsField.integerValue = config.rounds
        roundsStep.integerValue = config.rounds

        blinkBox.state = prefs.alertBlink ? .on : .off
        windowBox.state = prefs.alertWindow ? .on : .off
        notifyBox.state = prefs.alertNotification ? .on : .off
        notifySoundBox.state = prefs.alertNotificationSound ? .on : .off
        speakBox.state = prefs.alertSpeak ? .on : .off
        announcement.stringValue = prefs.announcement
        secondsBox.state = prefs.displaySeconds ? .on : .off
        atLaunchBox.state = prefs.showTimerWindowAtLaunch ? .on : .off

        notifySoundBox.isEnabled = notifyBox.state == .on
    }

    /// Alert choices are settings, so they stick even if the user cancels the run.
    private func saveSettings() {
        let prefs = Preferences.shared
        prefs.alertBlink = blinkBox.state == .on
        prefs.alertWindow = windowBox.state == .on
        prefs.alertNotification = notifyBox.state == .on
        prefs.alertNotificationSound = notifySoundBox.state == .on
        prefs.alertSpeak = speakBox.state == .on
        prefs.announcement = announcement.stringValue.isEmpty ? "Done" : announcement.stringValue
        prefs.displaySeconds = secondsBox.state == .on
        prefs.showTimerWindowAtLaunch = atLaunchBox.state == .on

        var config = prefs.timerConfig
        config.duration = max(1, countdown.duration)
        config.workDuration = TimeInterval(max(1, workField.integerValue) * 60)
        config.breakDuration = TimeInterval(max(1, breakField.integerValue) * 60)
        config.rounds = max(1, roundsField.integerValue)
        prefs.timerConfig = config
    }

    private func applyMode() {
        generalRow.isHidden = (mode != .general)
        pomodoroRows.isHidden = (mode != .pomodoro)
        modePicker.selectedSegment = mode.rawValue
        window?.title = mode == .general ? "Timer Settings" : "Pomodoro Settings"
    }

    // MARK: Actions

    @objc private func modeChanged() {
        mode = Mode(rawValue: modePicker.selectedSegment) ?? .general
        Preferences.shared.lastTimerMode = mode.rawValue
        applyMode()
        if let window, let content = window.contentView {
            window.setContentSize(content.fittingSize)
        }
    }

    @objc private func notificationToggled() { notifySoundBox.isEnabled = notifyBox.state == .on }

    @objc private func cycleStepperChanged(_ sender: NSStepper) {
        switch sender {
        case workStep:  workField.integerValue = sender.integerValue
        case breakStep: breakField.integerValue = sender.integerValue
        default:        roundsField.integerValue = sender.integerValue
        }
    }

    @objc private func startPressed() {
        window?.makeFirstResponder(nil)   // commit any field still being edited
        saveSettings()
        var config = Preferences.shared.timerConfig
        config.cycling = (mode == .pomodoro)
        close()
        onStart?(config)
    }

    @objc private func cancelPressed() {
        saveSettings()
        close()
    }

    func windowWillClose(_ notification: Notification) { saveSettings() }

    func show(mode: Mode) {
        self.mode = mode
        Preferences.shared.lastTimerMode = mode.rawValue
        load()
        applyMode()
        if let window, let content = window.contentView {
            window.setContentSize(content.fittingSize)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
