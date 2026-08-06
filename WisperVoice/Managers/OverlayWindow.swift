import AppKit
import SwiftUI

/// Non-activating HUD panel. Must NEVER take focus from the app the user is dictating into —
/// it is an NSPanel with `.nonactivatingPanel` so ordering it in leaves Slack/Chrome frontmost.
final class OverlayWindow: NSPanel {
    // Singleton independent of AppDelegate — fixes pill not showing
    static let sharedInstance = OverlayWindow()
    static var shared: OverlayWindow? { sharedInstance }

    var onClose: (() -> Void)?

    private var hosting: NSHostingView<OverlayView>?
    /// Window ordering/positioning happens once per presentation, not on every content update.
    private var isPresented = false
    /// Invalidates an in-flight fade-out when a new `show()` supersedes it.
    private var hideToken = 0

    init() {
        let rect = NSRect(x: 0, y: 0, width: 420, height: 72)
        super.init(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        hasShadow = true
        // Only grab key status if the user actually clicks a control in the pill
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = true
        worksWhenModal = true
        center()
        if let screen = NSScreen.main {
            let x = screen.frame.midX - rect.width/2
            let y = screen.frame.minY + 96
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        let view = OverlayView(state: .idle, level: 0, transcript: "", onCopy: { [weak self] t in self?.copyTranscript(t) }, onClose: { [weak self] in self?.onClose?() })
        hosting = NSHostingView(rootView: view)
        hosting?.wantsLayer = true
        contentView = hosting
        orderOut(nil)
    }

    /// Present the pill and/or refresh its contents.
    ///
    /// This is called at audio-level rate (~12×/s) while recording, so only the SwiftUI
    /// root view is swapped on the hot path. Window ordering and repositioning run once per
    /// presentation — and never activate the app, which would steal focus from the app the
    /// user is dictating into.
    func show(state: DictationState, level: Float, transcript: String) {
        hosting?.rootView = OverlayView(state: state, level: level, transcript: transcript, onCopy: { [weak self] t in self?.copyTranscript(t) }, onClose: { [weak self] in self?.onClose?() })

        // The pill floats at bottom-centre — directly over the message composer in Slack/Discord/
        // Chrome. While the user is talking it must not intercept clicks meant for that field;
        // it only becomes clickable once there is a result worth copying.
        ignoresMouseEvents = (state == .recording || state == .transcribing)

        hideToken &+= 1              // supersede any fade-out already in flight
        guard !isPresented || !isVisible else { return }
        isPresented = true

        // Ensure visible on active Space even when Chrome/fullscreen frontmost
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        self.level = .statusBar
        // Multi-desktop/multi-monitor: recenter on active screen (mouse or keyWindow), not just NSScreen.main at launch
        let targetScreen: NSScreen? = {
            let mouse = NSEvent.mouseLocation
            if let found = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) { return found }
            if let key = NSApp.keyWindow?.screen { return key }
            if let main = NSScreen.main { return main }
            return NSScreen.screens.first
        }()
        if let screen = targetScreen {
            let w: CGFloat = 420, h: CGFloat = 72
            let x = screen.frame.midX - w/2
            let y = screen.frame.minY + 96
            // Keep within visibleFrame (notch/Dock)
            let visible = screen.visibleFrame
            let clampedY = max(visible.minY + 12, min(y, visible.maxY - h - 12))
            let clampedX = max(visible.minX + 12, min(x, visible.maxX - w - 12))
            self.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        }
        DispatchQueue.main.async {
            // Retarget any running fade-out back to opaque before ordering in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0
                self.animator().alphaValue = 1
            }
            // orderFrontRegardless only — no makeKey, no NSApp.activate: the frontmost app keeps focus
            self.orderFrontRegardless()
        }
    }

    /// The pill is a HUD: it must never become the app's main window.
    override var canBecomeMain: Bool { false }

    private func copyTranscript(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        HistoryStore.shared.add(text)
        NSSound(named: "Pop")?.play()
    }

    func updateLevel(_ level: Float) {}

    func hide() {
        hideToken &+= 1
        let token = hideToken
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.hideToken == token else { return } // a show() superseded this hide
            self.orderOut(nil)
            self.alphaValue = 1
            self.isPresented = false
        }
    }
}

struct OverlayView: View {
    var state: DictationState
    var level: Float
    var transcript: String
    var onCopy: ((String) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(colorForState.opacity(state == .recording ? 0.22 : 0.12))
                    .frame(width: 44, height: 44)
                    .blur(radius: state == .recording ? 6 : 0)
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(Theme.onGlass.opacity(Theme.softFill), lineWidth: 1))
                    .shadow(color: colorForState.opacity(0.18), radius: 8, y: 4)
                Image(systemName: iconForState)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colorForState)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: state)
                if state == .recording {
                    Circle().stroke(colorForState.opacity(0.45), lineWidth: 2)
                        .scaleEffect(1 + CGFloat(level) * 0.45)
                        .opacity(1 - Double(level) * 0.3)
                        .animation(.easeInOut(duration: 0.35), value: level)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(titleForState)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.onGlassPrimary)
                    if state == .recording {
                        Circle().fill(Theme.alert).frame(width: 6, height: 6).symbolEffect(.pulse)
                    }
                }
                Group {
                    if state == .recording {
                        // Live dictation text
                        if transcript.isEmpty {
                            Text("Listening… press again to stop")
                                .font(Theme.compact)
                                .foregroundStyle(Theme.onGlassSecondary)
                        } else {
                            Text(transcript)
                                .font(Theme.compact)
                                .foregroundStyle(Theme.onGlassPrimary)
                                .lineLimit(1)
                                .contentTransition(.opacity)
                        }
                    } else if !transcript.isEmpty && state != .recording {
                        Text(transcript)
                            .font(Theme.compact)
                            .foregroundStyle(Theme.onGlassSecondary)
                            .lineLimit(1)
                    } else if state == .transcribing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini).tint(Theme.onGlassPrimary)
                            Text("Transcribing…").font(Theme.compact).foregroundStyle(Theme.onGlassSecondary)
                        }
                    } else if state == .injecting {
                        Text("Pasted at cursor ✓").font(Theme.compact).foregroundStyle(Theme.onGlassSecondary)
                    } else {
                        Text("⌥Space  •  Fn×2  to dictate").font(Theme.compact).foregroundStyle(Theme.onGlassSecondary)
                    }
                }
            }

            Spacer()

            if state == .recording {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.onGlassPrimary)
                            .frame(width: 3, height: 10 + CGFloat(level) * 16 * (i % 2 == 0 ? 1 : 0.55) + CGFloat(i) * 1.2)
                            .animation(.easeInOut(duration: 0.18).delay(Double(i)*0.04), value: level)
                    }
                }
                .frame(height: 28)
            }

            // Copy button — when transcript present (live or result)
            if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && state != .idle {
                Button(action: {
                    onCopy?(transcript)
                    withAnimation { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { didCopy = false } }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(didCopy ? Theme.accent : Theme.onGlass.opacity(Theme.subtleFill), in: Capsule())
                    .overlay(Capsule().stroke(Theme.onGlass.opacity(Theme.hairline), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy transcript (⌘C)")
                .accessibilityLabel("Copy transcript")
                .contentTransition(.symbolEffect(.replace))
            }

            // Close button — always visible when not idle
            if state != .idle {
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.onGlassSecondary)
                        .background(Circle().fill(Theme.onGlass.opacity(Theme.subtleFill)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Stop / Close")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 420, height: 72)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.glassBody)
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.onGlass.opacity(Theme.hairline), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
                .shadow(color: colorForState.opacity(state == .recording ? 0.18 : 0), radius: 18, y: 6)
        }
        .clipShape(Capsule(style: .continuous))
        .sensoryFeedback(.impact, trigger: state)
    }

    private var iconForState: String {
        switch state {
        case .idle: return "waveform"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform.badge.magnifyingglass"
        case .injecting: return "checkmark.circle.fill"
        }
    }
    private var colorForState: Color { Theme.onGlassColor(for: state) }
    private var titleForState: String {
        switch state {
        case .idle: return "WisperVoice"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .injecting: return "Inserted ✓"
        }
    }
}
