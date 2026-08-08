import AppKit
import Carbon
import SwiftUI

/// A user-selectable shortcut. Presets rather than a free-form recorder: every option is
/// pre-checked to not collide with common system shortcuts, and the picker UI stays trivial.
struct HotkeyPreset: Identifiable, Equatable {
    let id: String
    let label: String
    let keyCode: UInt32
    let modifiers: UInt32
}

/// Global hotkey manager — default Option+Space (like Wispr Flow) + Fn double-tap.
/// Uses Carbon RegisterEventHotKey for reliability across apps.
final class HotkeyManager: ObservableObject {
    static let presets: [HotkeyPreset] = [
        HotkeyPreset(id: "opt-space", label: "⌥ Space", keyCode: 49, modifiers: UInt32(optionKey)),
        HotkeyPreset(id: "ctrl-space", label: "⌃ Space", keyCode: 49, modifiers: UInt32(controlKey)),
        HotkeyPreset(id: "ctrl-opt-space", label: "⌃⌥ Space", keyCode: 49, modifiers: UInt32(controlKey | optionKey)),
        HotkeyPreset(id: "cmd-shift-space", label: "⌘⇧ Space", keyCode: 49, modifiers: UInt32(cmdKey | shiftKey)),
        HotkeyPreset(id: "opt-d", label: "⌥ D", keyCode: 2, modifiers: UInt32(optionKey)),
        HotkeyPreset(id: "cmd-shift-d", label: "⌘⇧ D", keyCode: 2, modifiers: UInt32(cmdKey | shiftKey)),
        HotkeyPreset(id: "opt-backtick", label: "⌥ `", keyCode: 50, modifiers: UInt32(optionKey)),
        HotkeyPreset(id: "f5", label: "F5", keyCode: 96, modifiers: 0),
    ]
    static let presetDefaultsKey = "hotkey.preset"

    static var currentPreset: HotkeyPreset {
        let id = UserDefaults.standard.string(forKey: presetDefaultsKey)
        return presets.first { $0.id == id } ?? presets[0]
    }
    /// For UI hint chips — e.g. "⌥ Space  •  Fn×2".
    static var currentHintLabel: String { "\(currentPreset.label)  •  Fn×2" }

    var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    /// NSEvent monitors added by register(). Must be torn down in unregister(): apply()
    /// re-registers, and stacked flagsChanged monitors made a SINGLE Fn tap read as a
    /// double-tap (each monitor's handler saw the other's fresh lastFnTap).
    private var eventMonitors: [Any] = []

    // Fn double-tap detection
    private var lastFnTap: Date?
    var fnDoubleTapEnabled: Bool = true

    // Configurable hotkey (default Option+Space); loaded from the saved preset on register()
    var keyCode: UInt32 = 49 // Space
    var modifiers: UInt32 = UInt32(optionKey) // Option

    /// Persist a preset choice and re-register immediately.
    func apply(presetId: String) {
        guard let preset = Self.presets.first(where: { $0.id == presetId }) else { return }
        UserDefaults.standard.set(preset.id, forKey: Self.presetDefaultsKey)
        keyCode = preset.keyCode
        modifiers = preset.modifiers
        register()
    }

    func register() {
        unregister()
        // Pick up the saved preset so a customized shortcut survives relaunch.
        let preset = Self.currentPreset
        keyCode = preset.keyCode
        modifiers = preset.modifiers
        let hotKeyID = EventHotKeyID(signature: OSType(0x57565350), id: 1) // WVSP
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        if status == noErr {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                HotkeyManager.shared?.onHotkeyPressed?()
                return noErr
            }, 1, &spec, nil, &eventHandler)
            HotkeyManager.shared = self
        } else {
            // Fallback: local monitor (works when app is active)
            if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
                guard let self else { return e }
                if e.keyCode == self.keyCode && e.modifierFlags.carbonMatches(self.modifiers) {
                    self.onHotkeyPressed?(); return nil
                }
                return e
            }) { eventMonitors.append(monitor) }
        }

        // Global Fn monitor (requires Input Monitoring permission for global key, but local works)
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.handleFlagsChanged(e)
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.handleFlagsChanged(e); return e
        }) { eventMonitors.append(monitor) }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = eventHandler { RemoveEventHandler(h); eventHandler = nil }
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors.removeAll()
    }

    private func handleFlagsChanged(_ e: NSEvent) {
        guard fnDoubleTapEnabled else { return }
        // Fn key: keyCode 63, flags .function
        if e.keyCode == 63 {
            let isDown = e.modifierFlags.contains(.function)
            if isDown {
                let now = Date()
                if let last = lastFnTap, now.timeIntervalSince(last) < 0.35 {
                    onHotkeyPressed?()
                    lastFnTap = nil
                } else {
                    lastFnTap = now
                }
            }
        }
    }

    // Carbon helper singletons
    private static var shared: HotkeyManager?

    deinit { unregister() }
}

extension NSEvent.ModifierFlags {
    /// Compare against the Carbon modifier mask the presets store, ignoring unrelated flags.
    func carbonMatches(_ carbon: UInt32) -> Bool {
        var expected: NSEvent.ModifierFlags = []
        if carbon & UInt32(optionKey) != 0 { expected.insert(.option) }
        if carbon & UInt32(controlKey) != 0 { expected.insert(.control) }
        if carbon & UInt32(cmdKey) != 0 { expected.insert(.command) }
        if carbon & UInt32(shiftKey) != 0 { expected.insert(.shift) }
        return intersection([.option, .control, .command, .shift]) == expected
    }
}
