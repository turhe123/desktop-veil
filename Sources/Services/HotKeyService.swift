import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey through Carbon's `RegisterEventHotKey`.
final class HotKeyService {
    static let shared = HotKeyService()
    static let defaultKeyCode = kVK_ANSI_D
    static let defaultModifiers = controlKey | optionKey | cmdKey
    static let defaultDisplay = "⌃⌥⌘D"

    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers the hotkey stored in user defaults (or the default one).
    func registerFromDefaults() {
        let defaults = UserDefaults.standard
        let code = defaults.object(forKey: SettingKey.hotKeyCode) as? Int ?? Self.defaultKeyCode
        let mods = defaults.object(forKey: SettingKey.hotKeyModifiers) as? Int ?? Self.defaultModifiers
        register(keyCode: code, modifiers: mods)
    }

    func register(keyCode: Int, modifiers: Int) {
        unregister()
        installHandlerIfNeeded()
        guard keyCode >= 0 else { return }
        let id = EventHotKeyID(signature: OSType(0x4456_4C31), id: 1) // "DVL1"
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { NSLog("DesktopVeil: hotkey registration failed (\(status))") }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyService.shared.onTrigger?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    /// Converts AppKit modifier flags to Carbon modifier bits.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return result
    }

    /// Human-readable shortcut such as "⌃⌥⌘D".
    static func displayString(flags: NSEvent.ModifierFlags, key: String) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + key.uppercased()
    }
}
