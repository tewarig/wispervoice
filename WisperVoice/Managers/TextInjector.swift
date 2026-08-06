import AppKit
import ApplicationServices
import Carbon
import os

/// Append-only diagnostics for focus/injection, so a single real reproduction shows
/// exactly which app was frontmost at each stage and which delivery path ran.
/// Tail with: `tail -f ~/Library/Logs/WisperVoice/focus.log`
enum FocusLog {
    private static let logger = Logger(subsystem: "com.wispervoice.app", category: "focus")
    private static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/WisperVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("focus.log")
    }()
    private static let queue = DispatchQueue(label: "com.wispervoice.focuslog")

    static func log(_ message: String) {
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
        let line = "\(Self.stamp())  [front=\(front)] \(message)\n"
        logger.info("\(message, privacy: .public)")
        queue.async {
            if let data = line.data(using: .utf8) {
                if let h = try? FileHandle(forWritingTo: fileURL) {
                    defer { try? h.close() }
                    _ = try? h.seekToEnd()
                    try? h.write(contentsOf: data)
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}

/// Remembers which app the user was actually working in.
///
/// Dictation can be triggered from the menu bar or the main window, at which point WisperVoice
/// itself is frontmost — so "paste where the cursor is" cannot mean "paste into whatever is
/// frontmost right now". This tracks the last *external* app so injection has a real target.
final class FocusTracker {
    static let shared = FocusTracker()

    private(set) var lastExternalApp: NSRunningApplication?
    private let selfPID = ProcessInfo.processInfo.processIdentifier

    private init() {
        lastExternalApp = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == selfPID ? nil : $0 }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        guard app.processIdentifier != selfPID else { return }
        lastExternalApp = app
    }

    /// Bring `app` back to the front and call `work` once it is actually frontmost.
    /// Posting Cmd+V before the app has focus delivers the keystroke to the wrong process.
    static func restoreFocus(to app: NSRunningApplication?, then work: @escaping () -> Void) {
        guard let app, !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { work(); return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { work(); return }
        app.activate(options: [])
        waitUntilFrontmost(app, attempts: 14, then: work)
    }

    private static func waitUntilFrontmost(_ app: NSRunningApplication, attempts: Int, then work: @escaping () -> Void) {
        guard attempts > 0 else { work(); return } // give up and try anyway rather than drop the transcript
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                work()
            } else {
                waitUntilFrontmost(app, attempts: attempts - 1, then: work)
            }
        }
    }
}

enum TextInjector {
    /// Inject into the last app the user was working in.
    static func inject(text: String) {
        inject(text: text, target: FocusTracker.shared.lastExternalApp)
    }

    /// Restore focus to `target`, then insert at its cursor (AX) or paste (Cmd+V).
    static func inject(text: String, target: NSRunningApplication?) {
        guard !text.isEmpty else { return }
        FocusLog.log("inject: \(text.count) chars, target=\(target?.localizedName ?? "nil"), axTrusted=\(AXIsProcessTrusted())")
        FocusTracker.restoreFocus(to: target) {
            if tryAccessibilityInsert(text, pid: target?.processIdentifier) {
                FocusLog.log("inject: delivered via Accessibility")
                return
            }
            FocusLog.log("inject: falling back to clipboard + Cmd+V")
            pasteViaClipboard(text)
        }
    }

    // MARK: Accessibility
    private static func tryAccessibilityInsert(_ text: String, pid: pid_t?) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        // Ask the *target app* for its focused element. The system-wide element resolves to
        // whatever is frontmost, which is wrong the moment our own UI is in the picture.
        let root = pid.map { AXUIElementCreateApplication($0) } ?? AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element as CFTypeRef) == AXUIElementGetTypeID() else { return false }

        // Only the atomic "replace the selection" operation is safe. The previous fallback read
        // kAXValue and wrote the whole field back, which clobbers an existing draft and is
        // unreliable in Electron apps (Slack/Discord/Chrome). Anything else falls through to Cmd+V.
        let el = element as! AXUIElement
        return AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }

    // MARK: Clipboard + Cmd+V
    private static func pasteViaClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)
        let stamped = pb.changeCount

        // Small delay to ensure pasteboard sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .hidSystemState)
            let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // kVK_V = 0x09
            let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            vDown?.flags = .maskCommand
            vUp?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)

            // Restore previous clipboard, but only if nothing else claimed the pasteboard meanwhile
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard pb.changeCount == stamped, let prev = previous else { return }
                pb.clearContents()
                pb.setString(prev, forType: .string)
            }
        }
    }
}
