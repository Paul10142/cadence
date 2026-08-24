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

    /// Called when the user presses Start.
    var onStart: ((CountdownTimer.Config) -> Void)?

    private let countdown = DurationField()
    private let cyclingBox = NSButton(checkboxWithTitle: "Cycle between work and break", target: nil, action: nil)
    private let workField = NSTextField(), breakField = NSTextField(), roundsField = NSTextField()
    private let workStep = NSStepper(), breakStep = NSStepper(), roundsStep = NSStepper()

    private let blinkBox = NSButton(checkboxWithTitle: "Blink in menu bar", target: nil, action: nil)
    private let windowBox = NSButton(checkboxWithTitle: "Show alert window", target: nil, action: nil)
    private let notifyBox = NSButton(checkboxWithTitle: "Show notification", target: nil, action: nil)
    private let notifySoundBox = NSButton(checkboxWithTitle: "With sound", target: nil, action: nil)
    private let speakBox = NSButton(checkboxWithTitle: "Speak announcement", target: nil, action: nil)
    private let announcement = NSTextField()
    private let secondsBox = NSButton(checkboxWithTitle: "Display seconds in menu bar", target: nil, action: nil)
    private let atLaunchBox = NSButton(checkboxWithTitle: "Show this window when application starts", target: nil, action: nil)

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 620),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Timer Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildContent()
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

        // Work / break row
        for (field, stepper, cap) in [(workField, workStep, 600), (breakField, breakStep, 600),
                                      (roundsField, roundsStep, 99)] {
            field.alignment = .center
            field.widthAnchor.constraint(equalToConstant: 52).isActive = true
            stepper.minValue = 1
            stepper.maxValue = Double(cap)
            stepper.target = self
            stepper.action = #selector(cycleStepperChanged(_:))
        }

        func labelled(_ text: String, _ field: NSTextField, _ stepper: NSStepper, _ suffix: String) -> NSStackView {
            let row = NSStackView(views: [NSTextField(labelWithString: text), field, stepper,
                                          NSTextField(labelWithString: suffix)])
            row.spacing = 6
            row.alignment = .centerY
            return row
        }

        let cycleRows = NSStackView(views: [
            labelled("Work:", workField, workStep, "minutes"),
            labelled("Break:", breakField, breakStep, "minutes"),
            labelled("Rounds:", roundsField, roundsStep, "\u{00D7}"),
        ])
        cycleRows.orientation = .vertical
        cycleRows.alignment = .leading
        cycleRows.spacing = 8
        cycleRows.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)

        cyclingBox.target = self
        cyclingBox.action = #selector(cyclingToggled)

        notifyBox.target = self
        notifyBox.action = #selector(notificationToggled)

        let indentedSound = NSStackView(views: [notifySoundBox])
        indentedSound.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)

        let alerts = NSStackView(views: [blinkBox, windowBox, notifyBox, indentedSound, speakBox])
        alerts.orientation = .vertical
        alerts.alignment = .leading
        alerts.spacing = 8

        announcement.placeholderString = "Done"
        announcement.translatesAutoresizingMaskIntoConstraints = false

        let start = NSButton(title: "Start", target: self, action: #selector(startPressed))
        start.keyEquivalent = "\r"
        start.bezelStyle = .rounded
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.keyEquivalent = "\u{1b}"
        cancel.bezelStyle = .rounded
        let buttons = NSStackView(views: [NSView(), cancel, start])
        buttons.spacing = 12

        let countdownRow = NSStackView(views: [NSTextField(labelWithString: "Countdown:"), countdown])
        countdownRow.spacing = 12
        countdownRow.alignment = .centerY

        let stack = NSStackView(views: [
            countdownRow,
            cyclingBox,
            cycleRows,
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
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(22, after: cycleRows)
        stack.setCustomSpacing(22, after: announcement)

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            announcement.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            announcement.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
        window.contentView = content
    }

    // MARK: Loading and saving

    private func load() {
        let prefs = Preferences.shared
        let config = prefs.timerConfig

        countdown.duration = config.duration
        cyclingBox.state = config.cycling ? .on : .off
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

        updateEnabledStates()
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
    }

    private func currentConfig() -> CountdownTimer.Config {
        var config = CountdownTimer.Config()
        config.duration = max(1, countdown.duration)
        config.cycling = cyclingBox.state == .on
        config.workDuration = TimeInterval(max(1, workField.integerValue) * 60)
        config.breakDuration = TimeInterval(max(1, breakField.integerValue) * 60)
        config.rounds = max(1, roundsField.integerValue)
        return config
    }

    private func updateEnabledStates() {
        let cycling = cyclingBox.state == .on
        [workField, breakField, roundsField].forEach { $0.isEnabled = cycling }
        [workStep, breakStep, roundsStep].forEach { $0.isEnabled = cycling }
        countdown.alphaValue = cycling ? 0.4 : 1
        notifySoundBox.isEnabled = notifyBox.state == .on
    }

    // MARK: Actions

    @objc private func cyclingToggled() { updateEnabledStates() }
    @objc private func notificationToggled() { updateEnabledStates() }

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
        let config = currentConfig()
        Preferences.shared.timerConfig = config
        close()
        onStart?(config)
    }

    @objc private func cancelPressed() {
        saveSettings()
        close()
    }

    func windowWillClose(_ notification: Notification) { saveSettings() }

    func show() {
        load()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
