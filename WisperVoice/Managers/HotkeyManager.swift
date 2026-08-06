import AppKit
import Carbon
import SwiftUI

/// Global hotkey manager — default Option+Space (like Wispr Flow) + Fn double-tap.
/// Uses Carbon RegisterEventHotKey for reliability across apps.
final class HotkeyManager: ObservableObject {
    var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // Fn double-tap detection
    private var lastFnTap: Date?
    var fnDoubleTapEnabled: Bool = true

    // Configurable hotkey (default Option+Space)
    var keyCode: UInt32 = 49 // Space
    var modifiers: UInt32 = UInt32(optionKey) // Option

    func register() {
        unregister()
        var hotKeyID = EventHotKeyID(signature: OSType(0x57565350), id: 1) // WVSP
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
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                if e.modifierFlags.contains(.option) && e.keyCode == 49 {
                    self?.onHotkeyPressed?(); return nil
                }
                return e
            }
        }

        // Global Fn monitor (requires Input Monitoring permission for global key, but local works)
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            self?.handleFlagsChanged(e)
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            self?.handleFlagsChanged(e); return e
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = eventHandler { RemoveEventHandler(h); eventHandler = nil }
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
