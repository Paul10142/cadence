import AppKit
import AVFoundation
import Carbon.HIToolbox
import UniformTypeIdentifiers
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let timer = StopwatchTimer()
    private let countdown = CountdownTimer()
    private let store = SessionStore()
    private let menu = NSMenu()
    private let speech = AVSpeechSynthesizer()

    /// Set while the menu is dropped down, so a global hotkey and the menu's own
    /// key equivalent can't both fire for the same keypress.
    private var menuIsOpen = false
    /// The stopwatch was paused by the system (sleep / screen lock), not by the
    /// user, so it should resume by itself.
    private var pausedBySystem = false
    /// Suppresses the shortcut-conflict alert during the initial registration at launch.
    private var didFinishLaunching = false
    /// Expanded session list in the menu.
    private var showAllSessions = false

    private var blinkTimer: Timer?
    private var blinkOn = true

    private lazy var stopwatchImage: NSImage = {
        let base = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Thyme Custom")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        // The default symbol size renders noticeably smaller than neighbouring
        // menu bar icons, so it gets nudged up to match them.
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        return image
    }()

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menu.delegate = self
        menu.autoenablesItems = false

        // The menu is attached only for the duration of a right click, so a left
        // click is free to start and pause the stopwatch.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])

        timer.onTick = { [weak self] in self?.refreshStatusItem() }
        countdown.onTick = { [weak self] in self?.refreshStatusItem() }
        countdown.onPhaseComplete = { [weak self] phase, length, runIsOver in
            self?.phaseCompleted(phase, length: length, runIsOver: runIsOver)
        }
        TimerSettingsWindowController.shared.onStart = { [weak self] config in
            self?.countdown.start(config: config)
        }
        refreshStatusItem()

        NotificationCenter.default.addObserver(self, selector: #selector(registerHotKeys),
                                               name: Preferences.didChange, object: nil)
        registerHotKeys()
        didFinishLaunching = true
        observeSystemEvents()
        requestNotificationPermission()

        if Preferences.shared.showTimerWindowAtLaunch {
            let mode = TimerSettingsWindowController.Mode(
                rawValue: Preferences.shared.lastTimerMode) ?? .general
            TimerSettingsWindowController.shared.show(mode: mode)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: Status item

    /// The countdown owns the display whenever it is armed; otherwise the
    /// stopwatch does; otherwise the icon.
    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }

        if countdown.isActive {
            // A pomodoro shows its phase at a glance: a bar underneath while
            // working, a bar on top during a break.
            if countdown.config.cycling, countdown.state != .finished {
                button.attributedTitle = NSAttributedString(string: "")
                button.image = PhaseIndicator.image(countdownText(), barOnTop: countdown.phase == .rest)
            } else {
                button.image = nil
                button.attributedTitle = title(countdownText(), dimmed: !blinkOn)
            }
        } else if timer.state != .idle {
            button.image = nil
            button.attributedTitle = title(TimeFormat.clock(timer.elapsedSeconds))
        } else {
            button.image = stopwatchImage
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    private func title(_ text: String, dimmed: Bool = false) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: dimmed
                ? NSColor.labelColor.withAlphaComponent(0.15)
                : NSColor.labelColor,
        ])
    }

    private func countdownText() -> String {
        let seconds = countdown.remainingSeconds
        guard !Preferences.shared.displaySeconds else { return TimeFormat.clock(seconds) }
        // Minute resolution, labelled so it can't be misread as seconds.
        let minutes = Int((Double(seconds) / 60).rounded(.up))
        return minutes < 1 ? "<1m" : "\(minutes)m"
    }

    // MARK: Clicking the status item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseDown
            || event?.modifierFlags.contains(.control) == true

        // Any click clears a finished timer that is blinking for attention.
        if countdown.state == .finished {
            stopBlinking()
            countdown.acknowledge()
            refreshStatusItem()
            if !wantsMenu { return }
        }

        if wantsMenu || !Preferences.shared.startOnClick {
            showMenu()
        } else if timer.state == .running {
            // Clicking a running stopwatch pauses it and opens the menu, so the
            // frozen time is right there to read.
            timer.pause()
            pausedBySystem = false
            showMenu()
        } else {
            toggleStartPause()
        }
    }

    private func showMenu() {
        rebuildMenu()
        // Attaching the menu hands positioning to AppKit, which tucks it under
        // the status item; positioning it by hand left a gap and a scroll arrow.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)   // blocks until the menu closes
        statusItem.menu = nil
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        // Opening the menu while the stopwatch runs pauses it, and it stays paused.
        if timer.state == .running {
            timer.pause()
            pausedBySystem = false
        }
    }

    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

    private func rebuildMenu() {
        menu.removeAllItems()

        let isIdle = timer.state == .idle
        let startTitle = timer.state == .running ? "Pause" : "Start"

        menu.addItem(header("Stopwatch"))
        menu.addItem(item(startTitle, #selector(toggleStartPause), key: .startPause, enabled: true))
        menu.addItem(item("Restart", #selector(restart), key: .restart, enabled: !isIdle))
        menu.addItem(item("Finish", #selector(finish), key: .finish, enabled: !isIdle))

        addTimerSection()
        addSessionSection()

        menu.addItem(.separator())
        menu.addItem(item("Export\u{2026}", #selector(export), enabled: !store.sessions.isEmpty))
        menu.addItem(item("Preferences\u{2026}", #selector(showPreferences), enabled: true))

        menu.addItem(.separator())
        menu.addItem(item("About Thyme Custom", #selector(about), enabled: true))
        menu.addItem(item("Quit", #selector(quit), enabled: true))
    }

    /// A dimmed, non-clickable section label.
    private func header(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        return item
    }

    private func addTimerSection() {
        menu.addItem(.separator())
        menu.addItem(header("Timer"))

        menu.addItem(item("Start General Timer", #selector(startGeneralTimer),
                          key: .startGeneralTimer, enabled: true))
        menu.addItem(item("Start Pomodoro Timer", #selector(startPomodoroTimer),
                          key: .startPomodoroTimer, enabled: true))

        if countdown.isActive, let status = countdown.statusLine {
            let detail = countdown.state == .finished
                ? status
                : "\(status) \u{00B7} \(TimeFormat.clock(countdown.remainingSeconds)) left"
            let line = NSMenuItem(title: detail, action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)

            if countdown.state == .running {
                menu.addItem(item("Pause Timer", #selector(pauseTimer), enabled: true))
            } else if countdown.state == .paused {
                menu.addItem(item("Resume Timer", #selector(resumeTimer), enabled: true))
            }
            menu.addItem(item("Restart Timer", #selector(restartTimer), enabled: true))
            menu.addItem(item("Stop Timer", #selector(stopTimer), enabled: true))
        }
    }

    private func addSessionSection() {
        guard !store.sessions.isEmpty else { return }
        menu.addItem(.separator())

        let count = store.sessions.count
        let title = showAllSessions ? "Hide Sessions" : "Show All Sessions (\(count))"
        // A custom view, so clicking it does not dismiss the menu.
        let toggle = NSMenuItem()
        toggle.view = MenuToggleItemView(title: title) { [weak self] in
            self?.toggleSessionList()
        }
        menu.addItem(toggle)

        guard showAllSessions else { return }

        // The whole list lives in one menu item, so expanding it never reflows
        // the items below.
        let list = NSMenuItem()
        list.view = SessionsMenuView(sessions: store.sessions)
        menu.addItem(list)

        let total = store.sessions.reduce(0) { $0 + $1.seconds }
        let line = NSMenuItem(title: "Total: \(TimeFormat.clock(total))", action: nil, keyEquivalent: "")
        line.isEnabled = false
        menu.addItem(line)

        // Clearing only makes sense next to the list it wipes.
        menu.addItem(item("Clear", #selector(clear), enabled: true))
    }

    private func item(_ title: String, _ action: Selector,
                      key: Preferences.Key? = nil, enabled: Bool) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.isEnabled = enabled
        if let key, let shortcut = Preferences.shared.shortcut(key),
           let equivalent = menuKeyEquivalent(for: shortcut) {
            menuItem.keyEquivalent = equivalent
            menuItem.keyEquivalentModifierMask = shortcut.nsModifiers
        }
        return menuItem
    }

    /// Only plain letter/number keys can be shown as a native menu key equivalent.
    private func menuKeyEquivalent(for shortcut: Shortcut) -> String? {
        let stripped = shortcut.display.filter { !"\u{2303}\u{2325}\u{21E7}\u{2318}".contains($0) }
        guard stripped.count == 1, let ch = stripped.first,
              ch.isLetter || ch.isNumber else { return nil }
        return String(ch).lowercased()
    }

    // MARK: Stopwatch actions

    @objc private func toggleStartPause() {
        pausedBySystem = false
        timer.state == .running ? timer.pause() : timer.start()
    }

    @objc private func restart() {
        pausedBySystem = false
        timer.restart()
    }

    @objc private func finish() {
        guard timer.state != .idle else { return }
        pausedBySystem = false
        let seconds = timer.finish()
        if seconds > 0 { store.add(seconds: seconds, kind: .stopwatch) }
        refreshStatusItem()
    }

    // MARK: Timer actions

    @objc private func startGeneralTimer() { TimerSettingsWindowController.shared.show(mode: .general) }
    @objc private func startPomodoroTimer() { TimerSettingsWindowController.shared.show(mode: .pomodoro) }

    /// Keyboard shortcuts skip the settings window: they start the timer with
    /// whatever is saved, and stop it if one is already running.
    private func toggleTimer(pomodoro: Bool) {
        if countdown.isActive {
            stopTimer()
            return
        }
        var config = Preferences.shared.timerConfig
        config.cycling = pomodoro
        countdown.start(config: config)
    }
    @objc private func pauseTimer() { countdown.pause() }
    @objc private func resumeTimer() { countdown.resume() }
    @objc private func restartTimer() { countdown.restart() }

    @objc private func stopTimer() {
        stopBlinking()
        countdown.stop()
        refreshStatusItem()
    }

    private func toggleSessionList() {
        showAllSessions.toggle()
        // Rebuild in place; the menu is still open and simply re-lays out.
        rebuildMenu()
        menu.update()
    }

    private func phaseCompleted(_ phase: CountdownTimer.Phase, length: TimeInterval, runIsOver: Bool) {
        // Work counts towards your history; breaks don't.
        if phase == .work, Int(length) > 0 { store.add(seconds: Int(length), kind: .timer) }

        let message: String
        if runIsOver {
            message = countdown.config.cycling
                ? "All \(countdown.config.rounds) rounds complete"
                : "Timer finished"
        } else if phase == .work {
            message = "Work done \u{2014} take a break"
        } else {
            message = "Break over \u{2014} back to work"
        }

        fireAlerts(message: message, runIsOver: runIsOver)
    }

    // MARK: Alerts

    private func fireAlerts(message: String, runIsOver: Bool) {
        let prefs = Preferences.shared

        if prefs.alertBlink, runIsOver { startBlinking() }

        if prefs.alertNotification { postNotification(message) }

        if prefs.alertSpeak {
            let spoken = runIsOver ? prefs.announcement : message
            speech.speak(AVSpeechUtterance(string: spoken))
        }

        if prefs.alertWindow {
            // Deferred so the alert never runs inside the countdown's tick.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let alert = NSAlert()
                alert.messageText = message
                alert.informativeText = runIsOver ? Preferences.shared.announcement : ""
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
                self.stopBlinking()
                self.countdown.acknowledge()
                self.refreshStatusItem()
            }
        }
    }

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification(_ message: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Thyme Custom"
        content.body = message
        if Preferences.shared.alertNotificationSound { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func startBlinking() {
        stopBlinking()
        blinkOn = true
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.blinkOn.toggle()
            self.refreshStatusItem()
        }
        RunLoop.main.add(t, forMode: .common)
        blinkTimer = t
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkOn = true
    }

    // MARK: Export / clear

    @objc private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Thyme Sessions.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var csv = "Duration,Seconds,Date\n"
        for session in store.sessions {
            csv += "\(TimeFormat.clock(session.seconds)),\(session.seconds),"
            csv += "\"\(TimeFormat.stampString(session.date))\"\n"
        }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func clear() {
        guard Preferences.shared.confirmClear else {
            store.clear()
            showAllSessions = false
            return
        }
        let alert = NSAlert()
        alert.messageText = "Clear all sessions?"
        alert.informativeText = "This removes all \(store.sessions.count) recorded sessions. It can't be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.clear()
            showAllSessions = false
        }
    }

    @objc private func showPreferences() { PreferencesWindowController.shared.show() }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Global hotkeys

    @objc private func registerHotKeys() {
        HotKeyManager.shared.unregisterAll()
        let bindings: [(Preferences.Key, () -> Void)] = [
            (.startPause, { [weak self] in self?.toggleStartPause() }),
            (.restart,    { [weak self] in self?.restart() }),
            (.finish,     { [weak self] in self?.finish() }),
            (.startGeneralTimer,  { [weak self] in self?.toggleTimer(pomodoro: false) }),
            (.startPomodoroTimer, { [weak self] in self?.toggleTimer(pomodoro: true) }),
        ]
        var taken: [String] = []
        for (key, action) in bindings {
            guard let shortcut = Preferences.shared.shortcut(key) else { continue }
            let ok = HotKeyManager.shared.register(shortcut) { [weak self] in
                guard let self, !self.menuIsOpen else { return }  // menu handles its own equivalent
                action()
            }
            // Only one app on the Mac can own a given system-wide shortcut. Losing
            // that race silently is the worst outcome, so say so.
            if !ok { taken.append(shortcut.display) }
        }
        if !taken.isEmpty, didFinishLaunching { warnAboutTakenShortcuts(taken) }
    }

    private func warnAboutTakenShortcuts(_ shortcuts: [String]) {
        let list = shortcuts.joined(separator: ", ")
        let alert = NSAlert()
        alert.messageText = shortcuts.count == 1
            ? "\(list) is already in use"
            : "These shortcuts are already in use: \(list)"
        alert.informativeText = """
            Another app on your Mac has already claimed it system-wide, so Thyme \
            Custom can't respond to it. Quit the other app, or pick a different \
            combination here.

            If you still have the original Thyme running, that's the likely culprit.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: Sleep / screensaver

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillPause),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidResume),
                              name: NSWorkspace.didWakeNotification, object: nil)

        let distributed = DistributedNotificationCenter.default()
        for name in ["com.apple.screensaver.didstart", "com.apple.screenIsLocked"] {
            distributed.addObserver(self, selector: #selector(screenWillPause),
                                    name: Notification.Name(name), object: nil)
        }
        for name in ["com.apple.screensaver.didstop", "com.apple.screenIsUnlocked"] {
            distributed.addObserver(self, selector: #selector(screenDidResume),
                                    name: Notification.Name(name), object: nil)
        }
    }

    @objc private func systemWillPause() {
        guard Preferences.shared.pauseDuringSleep else { return }
        autoPause()
    }

    @objc private func systemDidResume() {
        guard Preferences.shared.pauseDuringSleep else { return }
        autoResume()
    }

    @objc private func screenWillPause() {
        guard Preferences.shared.pauseDuringScreensaver else { return }
        autoPause()
    }

    @objc private func screenDidResume() {
        guard Preferences.shared.pauseDuringScreensaver else { return }
        autoResume()
    }

    private func autoPause() {
        guard timer.state == .running else { return }
        timer.pause()
        pausedBySystem = true
    }

    private func autoResume() {
        guard pausedBySystem, timer.state == .paused else { return }
        pausedBySystem = false
        timer.start()
    }
}
