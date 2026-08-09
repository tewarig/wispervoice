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
        let rect = NSRect(x: 0, y: 0, width: 480, height: 52)
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

        // Always clickable: the × must be able to cancel mid-recording (it used to be dead
        // because the window ignored mouse events while recording). The panel is
        // non-activating, so clicks on it never steal focus from the app being dictated into.
        ignoresMouseEvents = false

        hideToken &+= 1              // supersede any fade-out already in flight

        // The window hugs the capsule (plus a small shadow margin) instead of a fixed
        // 480pt: an invisible full-width window was swallowing clicks aimed at the
        // composer underneath while recording, and mis-aligned the left/right positions.
        // Frame updates run on every call, but only when the size actually changes.
        let capsuleW = OverlayView.width(state: state, transcriptEmpty: transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let w = capsuleW + 24, h: CGFloat = 52
        let firstPresentation = !isPresented || !isVisible

        if firstPresentation {
            isPresented = true
            // Ensure visible on active Space even when Chrome/fullscreen frontmost
            self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            self.level = .statusBar
        }

        if firstPresentation || abs(frame.width - w) > 0.5 {
            // Multi-desktop/multi-monitor: recenter on active screen (mouse or keyWindow), not just NSScreen.main at launch
            let targetScreen: NSScreen? = {
                let mouse = NSEvent.mouseLocation
                if let found = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) { return found }
                if let key = NSApp.keyWindow?.screen { return key }
                if let main = NSScreen.main { return main }
                return NSScreen.screens.first
            }()
            if let screen = targetScreen {
                let visible = screen.visibleFrame
                let margin: CGFloat = 24
                // User-selectable placement (Settings → Behavior → Pill position).
                let position = UserDefaults.standard.string(forKey: "pill.position") ?? "bottom-center"
                let x: CGFloat
                switch position.split(separator: "-").last {
                case "left":  x = visible.minX + margin
                case "right": x = visible.maxX - w - margin
                default:      x = visible.midX - w / 2
                }
                let y: CGFloat = position.hasPrefix("top")
                    ? visible.maxY - h - margin
                    : visible.minY + margin
                self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
            }
        }

        guard firstPresentation else {
            // A superseded hide() fade can still be animating toward alpha 0 (its
            // completion is token-guarded and never runs). Retarget back to opaque so a
            // dictation started mid-fade never runs with an invisible pill.
            if alphaValue < 1 {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0
                    self.animator().alphaValue = 1
                }
            }
            return
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

    // Layout (per user spec): no mic circle. Waveform + live text that tail-follows what
    // you're saying (head truncation = old words slide away, newest stay visible). Copy
    // appears once dictation finishes, not while recording.
    var body: some View {
        HStack(spacing: 12) {
            // Leading status: waveform while recording, spinner while transcribing, tick when done
            Group {
                switch state {
                case .recording:
                    HStack(spacing: 7) {
                        Circle().fill(Theme.alert).frame(width: 6, height: 6)
                            .opacity(0.5 + Double(level) * 0.5)
                            .animation(.easeInOut(duration: 0.2), value: level)
                        // Symmetric center-peaked bars. Raw RMS speech levels are ~0.1–0.4,
                        // which barely moved the old bars — amplify for a visible dance.
                        HStack(spacing: 2.5) {
                            ForEach(0..<5, id: \.self) { i in
                                let mult: CGFloat = [0.5, 0.8, 1.0, 0.8, 0.5][i]
                                let v = min(1, CGFloat(level) * 2.6)
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(Theme.onGlassPrimary)
                                    .frame(width: 3, height: 5 + v * 20 * mult)
                                    .animation(.spring(response: 0.22, dampingFraction: 0.6).delay(Double(i) * 0.02), value: level)
                            }
                        }
                        .frame(height: 26)
                    }
                case .transcribing:
                    ProgressView().controlSize(.mini).tint(Theme.onGlassPrimary)
                case .injecting:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.onGlassPrimary)
                case .idle:
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.onGlassSecondary)
                }
            }
            .frame(minWidth: 30, alignment: .leading)

            // Live text — single line, head-truncated so the newest words are always visible.
            // No "Listening…" placeholder: the red dot + dancing bars already say that.
            Group {
                if state == .recording {
                    if !transcript.isEmpty {
                        Text(transcript).foregroundStyle(Theme.onGlassPrimary)
                    } else if !Self.livePreviewAvailable {
                        // Non-Apple engines have no live partials — set expectations.
                        Text("Transcribes when you stop").foregroundStyle(Theme.onGlassSecondary)
                    }
                } else if state == .transcribing {
                    Text(transcript.isEmpty ? "Transcribing…" : transcript)
                        .foregroundStyle(Theme.onGlassSecondary)
                } else if !transcript.isEmpty {
                    Text(transcript).foregroundStyle(Theme.onGlassPrimary)
                } else {
                    Text("\(HotkeyManager.currentHintLabel)  to dictate")
                        .foregroundStyle(Theme.onGlassSecondary)
                }
            }
            .font(Theme.transcript)
            .lineLimit(1)
            .truncationMode(.head)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.15), value: transcript)

            // Copy — once there is a finished result to take away. Idle counts: after a
            // dictation the pill lingers in idle precisely so Copy stays reachable when
            // the text couldn't be inserted at the cursor.
            if state != .recording,
               !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    onCopy?(transcript)
                    withAnimation { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { didCopy = false } }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    // onAccent, not .white: Theme.accent is near-white in dark mode, so a
                    // white label vanishes the moment the "Copied" state fills the capsule.
                    .foregroundStyle(didCopy ? Theme.onAccent : .white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
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
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.onGlassSecondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.onGlass.opacity(Theme.subtleFill)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Stop / Close")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        // The capsule grows as content arrives: compact while just recording, wide once
        // live text streams in (or a result is shown). The window frame follows it —
        // OverlayWindow.show() sizes the window from OverlayView.width(state:transcriptEmpty:).
        .frame(width: pillWidth, height: 40)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.glassBody)
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.onGlass.opacity(Theme.hairline), lineWidth: 1))
                .shadow(color: .black.opacity(0.20), radius: 18, y: 8)
        }
        .clipShape(Capsule(style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact, trigger: state)
    }

    /// Only Apple Speech produces partials while you talk.
    /// Resolved via the shared legacy-aware accessor so this always agrees with
    /// DictationManager.usesAppleSpeech (a hardcoded fallback here diverged for users
    /// whose selection still lives in the legacy "provider" key).
    private static var livePreviewAvailable: Bool {
        UserDefaults.standard.sttProviderId == "apple-speech"
    }

    /// Capsule width for a given state — also drives the WINDOW frame (OverlayWindow.show),
    /// which hugs the capsule so no invisible margin swallows clicks meant for the app below.
    static func width(state: DictationState, transcriptEmpty: Bool) -> CGFloat {
        switch state {
        case .recording: return transcriptEmpty ? (livePreviewAvailable ? 118 : 250) : 460
        case .idle: return transcriptEmpty ? 250 : 460
        case .transcribing, .injecting: return 460
        }
    }

    private var pillWidth: CGFloat {
        Self.width(state: state, transcriptEmpty: transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
