import AppKit
import Carbon.HIToolbox

/// Countdown and pomodoro settings. Both modes share one layout language --
/// a right-aligned label, a value box, a stepper and a unit -- so switching
/// between them changes only the rows, never the shape of the window.
final class TimerSettingsWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    static let shared = TimerSettingsWindowController()

    enum Mode: Int { case general = 0, pomodoro = 1 }

    /// Called when the user presses Start.
    var onStart: ((CountdownTimer.Config) -> Void)?

    /// Both modes render at one width, so the mode switch never shifts sideways.
    /// Measured from the layout rather than guessed, so there is no dead space.
    private var contentWidth: CGFloat = 380

    private var mode: Mode = .general
    /// Set once the controls have been filled from the saved settings. Saving
    /// before that would write the blank state of freshly built checkboxes over
    /// everything the user had.
    private var didLoad = false

    private let modePicker = NSSegmentedControl(labels: ["Countdown", "Pomodoro"],
                                                trackingMode: .selectOne, target: nil, action: nil)

    private let hoursField = NSTextField(), minutesField = NSTextField(), secondsField = NSTextField()
    private let hoursStep = NSStepper(), minutesStep = NSStepper(), secondsStep = NSStepper()
    private var countdownRows: NSStackView!

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
    private let atLaunchBox = NSButton(checkboxWithTitle: "Show when application starts", target: nil, action: nil)

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Layout

    /// One settings row: label, value box, stepper, unit.
    ///
    /// The value box is centred on the row itself, and the two flanks are given
    /// the same fixed width, so the box lands on the exact centre line of the
    /// window rather than wherever the surrounding text happens to push it.
    private static let flankWidth: CGFloat = 74
    private static let boxWidth: CGFloat = 60

    private func row(_ caption: String, _ field: NSTextField, _ stepper: NSStepper,
                     _ suffix: String, range: ClosedRange<Int>) -> NSView {
        let container = NSView()

        let label = NSTextField(labelWithString: caption)
        label.alignment = .right

        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.target = self
        field.action = #selector(fieldChanged(_:))
        // A field with an action of its own swallows Return, so the Start
        // button never sees it. The delegate hands it back.
        field.delegate = self

        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))

        let unit = NSTextField(labelWithString: suffix)
        unit.textColor = .secondaryLabelColor

        let flank = NSView()   // holds the stepper and unit, mirroring the label's width

        for view in [label, field, stepper, unit, flank] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        flank.addSubview(stepper)
        flank.addSubview(unit)
        container.addSubview(label)
        container.addSubview(field)
        container.addSubview(flank)

        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            field.widthAnchor.constraint(equalToConstant: Self.boxWidth),
            field.topAnchor.constraint(equalTo: container.topAnchor),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            label.widthAnchor.constraint(equalToConstant: Self.flankWidth),
            label.trailingAnchor.constraint(equalTo: field.leadingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),

            flank.widthAnchor.constraint(equalToConstant: Self.flankWidth),
            flank.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8),
            flank.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            flank.heightAnchor.constraint(equalTo: stepper.heightAnchor),
            flank.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),

            stepper.leadingAnchor.constraint(equalTo: flank.leadingAnchor),
            stepper.centerYAnchor.constraint(equalTo: flank.centerYAnchor),
            unit.leadingAnchor.constraint(equalTo: stepper.trailingAnchor, constant: 6),
            unit.centerYAnchor.constraint(equalTo: flank.centerYAnchor),
            unit.trailingAnchor.constraint(lessThanOrEqualTo: flank.trailingAnchor),
        ])
        return container
    }

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
        modePicker.setWidth(120, forSegment: 0)
        modePicker.setWidth(120, forSegment: 1)
        let pickerRow = NSView()
        modePicker.translatesAutoresizingMaskIntoConstraints = false
        pickerRow.addSubview(modePicker)
        NSLayoutConstraint.activate([
            modePicker.topAnchor.constraint(equalTo: pickerRow.topAnchor),
            modePicker.bottomAnchor.constraint(equalTo: pickerRow.bottomAnchor),
            modePicker.leadingAnchor.constraint(greaterThanOrEqualTo: pickerRow.leadingAnchor),
            modePicker.trailingAnchor.constraint(lessThanOrEqualTo: pickerRow.trailingAnchor),
        ])

        countdownRows = NSStackView(views: [
            // No trailing unit here: the label already names it.
            row("Hours:", hoursField, hoursStep, "", range: 0...23),
            row("Minutes:", minutesField, minutesStep, "", range: 0...59),
            row("Seconds:", secondsField, secondsStep, "", range: 0...59),
        ])
        pomodoroRows = NSStackView(views: [
            row("Work:", workField, workStep, "min", range: 1...600),
            row("Break:", breakField, breakStep, "min", range: 1...600),
            row("Rounds:", roundsField, roundsStep, "\u{00D7}", range: 1...99),
        ])
        for rows in [countdownRows!, pomodoroRows!] {
            rows.orientation = .vertical
            rows.alignment = .leading
            rows.spacing = 8
        }

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
            pickerRow, countdownRows, pomodoroRows,
            heading("When the timer reaches 00:00:00:"), alerts,
            heading("Announcement:"), announcement,
            secondsBox, atLaunchBox, buttons,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(18, after: pickerRow)
        stack.setCustomSpacing(20, after: countdownRows)
        stack.setCustomSpacing(20, after: pomodoroRows)
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
        ])
        for row in [pickerRow, announcement, buttons, countdownRows!, pomodoroRows!] as [NSView] {
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
                row.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            ])
        }
        // Centred against the window, not against a stack whose own width is
        // itself decided by the solver.
        modePicker.centerXAnchor.constraint(equalTo: content.centerXAnchor).isActive = true

        // Each settings row fills its stack, which now spans the window, so a
        // row's centre line and the window's centre line are the same line.
        for rows in [countdownRows!, pomodoroRows!] {
            for row in rows.arrangedSubviews {
                row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            }
        }
        window.contentView = content
        contentWidth = measureWidestMode(in: content)
        applyMode()
        resizeToFit()
    }

    /// The window keeps one width across both modes, so it must be wide enough
    /// for whichever mode needs more room.
    private func measureWidestMode(in content: NSView) -> CGFloat {
        var widest: CGFloat = 0
        for candidate in [Mode.general, .pomodoro] {
            countdownRows.isHidden = (candidate != .general)
            pomodoroRows.isHidden = (candidate != .pomodoro)
            content.layoutSubtreeIfNeeded()
            widest = max(widest, content.fittingSize.width)
        }
        return ceil(widest)
    }

    private func resizeToFit() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: contentWidth, height: content.fittingSize.height))
    }

    // MARK: Loading and saving

    private func load() {
        defer { didLoad = true }
        let prefs = Preferences.shared
        let config = prefs.timerConfig

        let total = Int(config.duration)
        set(hoursField, hoursStep, total / 3600)
        set(minutesField, minutesStep, (total % 3600) / 60)
        set(secondsField, secondsStep, total % 60)
        set(workField, workStep, Int(config.workDuration / 60))
        set(breakField, breakStep, Int(config.breakDuration / 60))
        set(roundsField, roundsStep, config.rounds)

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

    private func set(_ field: NSTextField, _ stepper: NSStepper, _ value: Int) {
        field.integerValue = value
        stepper.integerValue = value
    }

    /// Alert choices are settings, so they stick even if the user cancels the run.
    private func saveSettings() {
        guard didLoad else { return }
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
        let seconds = hoursField.integerValue * 3600
            + minutesField.integerValue * 60 + secondsField.integerValue
        config.duration = TimeInterval(max(1, seconds))
        config.workDuration = TimeInterval(max(1, workField.integerValue) * 60)
        config.breakDuration = TimeInterval(max(1, breakField.integerValue) * 60)
        config.rounds = max(1, roundsField.integerValue)
        prefs.timerConfig = config
    }

    private func applyMode() {
        countdownRows.isHidden = (mode != .general)
        pomodoroRows.isHidden = (mode != .pomodoro)
        modePicker.selectedSegment = mode.rawValue
        window?.title = mode == .general ? "Countdown Settings" : "Pomodoro Settings"
    }

    // MARK: Actions

    @objc private func modeChanged() {
        mode = Mode(rawValue: modePicker.selectedSegment) ?? .general
        Preferences.shared.lastTimerMode = mode.rawValue
        applyMode()
        resizeToFit()
    }

    @objc private func notificationToggled() { notifySoundBox.isEnabled = notifyBox.state == .on }

    @objc private func stepperChanged(_ sender: NSStepper) {
        switch sender {
        case hoursStep:   hoursField.integerValue = sender.integerValue
        case minutesStep: minutesField.integerValue = sender.integerValue
        case secondsStep: secondsField.integerValue = sender.integerValue
        case workStep:    workField.integerValue = sender.integerValue
        case breakStep:   breakField.integerValue = sender.integerValue
        default:          roundsField.integerValue = sender.integerValue
        }
    }

    @objc private func fieldChanged(_ sender: NSTextField) {
        switch sender {
        case hoursField:   hoursStep.integerValue = sender.integerValue
        case minutesField: minutesStep.integerValue = sender.integerValue
        case secondsField: secondsStep.integerValue = sender.integerValue
        case workField:    workStep.integerValue = sender.integerValue
        case breakField:   breakStep.integerValue = sender.integerValue
        default:           roundsStep.integerValue = sender.integerValue
        }
    }

    /// Return in any of the value boxes starts the timer, the same as the
    /// Start button, so setting a length and running it is one gesture.
    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)),
              let field = control as? NSTextField else { return false }
        fieldChanged(field)   // keep the stepper in step with what was typed
        // Deferred: starting closes the window, and the field editor is still
        // part-way through handling this keystroke.
        DispatchQueue.main.async { [weak self] in self?.startPressed() }
        return true
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
        resizeToFit()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
