import AppKit
import Carbon.HIToolbox

/// A recorded key combination. The display string is captured at record time,
/// which keeps it correct for any keyboard layout without touching TIS/UCKeyTranslate.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt   // NSEvent.ModifierFlags rawValue, device-independent subset
    var display: String

    var nsModifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// Carbon modifier mask for RegisterEventHotKey.
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        let f = nsModifiers
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.shift)   { m |= UInt32(shiftKey) }
        if f.contains(.option)  { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    static func from(event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .shift, .option, .control])
        guard !flags.isEmpty else { return nil }   // require at least one modifier
        let key = keyName(for: event)
        guard !key.isEmpty else { return nil }
        return Shortcut(keyCode: event.keyCode, modifiers: flags.rawValue,
                        display: modifierGlyphs(flags) + key)
    }

    private static func modifierGlyphs(_ f: NSEvent.ModifierFlags) -> String {
        var s = ""
        if f.contains(.control) { s += "\u{2303}" }
        if f.contains(.option)  { s += "\u{2325}" }
        if f.contains(.shift)   { s += "\u{21E7}" }
        if f.contains(.command) { s += "\u{2318}" }
        return s
    }

    private static let specialKeys: [UInt16: String] = [
        UInt16(kVK_Space): "\u{2423}", UInt16(kVK_Return): "\u{21A9}",
        UInt16(kVK_Tab): "\u{21E5}", UInt16(kVK_Escape): "\u{238B}",
        UInt16(kVK_Delete): "\u{232B}", UInt16(kVK_ForwardDelete): "\u{2326}",
        UInt16(kVK_LeftArrow): "\u{2190}", UInt16(kVK_RightArrow): "\u{2192}",
        UInt16(kVK_UpArrow): "\u{2191}", UInt16(kVK_DownArrow): "\u{2193}",
        UInt16(kVK_Home): "\u{2196}", UInt16(kVK_End): "\u{2198}",
        UInt16(kVK_PageUp): "\u{21DE}", UInt16(kVK_PageDown): "\u{21DF}",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]

    private static func keyName(for event: NSEvent) -> String {
        if let special = specialKeys[event.keyCode] { return special }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            return chars.uppercased()
        }
        return ""
    }
}

// MARK: - Global hotkeys

/// Registers system-wide hotkeys through Carbon. Needs no accessibility
/// permission, unlike a global event monitor.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    func unregisterAll() {
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
    }

    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x54484D45), id: id) // 'THME'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode),
                                         shortcut.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        actions[id] = action
        return true
    }

    fileprivate func fire(id: UInt32) { actions[id]?() }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID), nil,
                                        MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if err == noErr { HotKeyManager.shared.fire(id: hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
