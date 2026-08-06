import AppKit
import ApplicationServices
import Carbon

enum TextInjector {
    /// Primary: try Accessibility insertion, fallback: clipboard + Cmd+V
    static func inject(text: String) {
        if !tryAccessibilityInsert(text) {
            pasteViaClipboard(text)
        }
    }

    // MARK: Accessibility
    private static func tryAccessibilityInsert(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let element = focused else { return false }

        // Try kAXSelectedTextAttribute / value
        // First try to set selected text, then value
        let setSelected = AXUIElementSetAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if setSelected == .success { return true }

        // Fallback: set value directly (overwrites)
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value) == .success,
           let current = value as? String {
            // Insert at cursor: if we can get selected range, use it; else append
            var rangeVal: AnyObject?
            var newValue: String
            if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success,
               let axVal = rangeVal, CFGetTypeID(axVal as CFTypeRef) == AXValueGetTypeID() {
                let range = axVal as! AXValue
                var cfRange = CFRange()
                if AXValueGetValue(range, .cfRange, &cfRange) {
                    let ns = current as NSString
                    let loc = max(0, min(cfRange.location, ns.length))
                    newValue = ns.replacingCharacters(in: NSRange(location: loc, length: cfRange.length), with: text)
                } else {
                    newValue = current + text
                }
            } else {
                newValue = current + text
            }
            if AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, newValue as CFTypeRef) == .success {
                return true
            }
        }
        return false
    }

    // MARK: Clipboard + Cmd+V
    private static func pasteViaClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Small delay to ensure pasteboard sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .hidSystemState)
            let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // kVK_V = 0x09
            let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            vDown?.flags = .maskCommand
            vUp?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)

            // Restore previous clipboard after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let prev = previous {
                    pb.clearContents()
                    pb.setString(prev, forType: .string)
                }
            }
        }
    }
}
