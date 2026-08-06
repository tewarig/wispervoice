import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    // Singleton independent of AppDelegate — fixes pill not showing
    static let sharedInstance = OverlayWindow()
    static var shared: OverlayWindow? { sharedInstance }

    var onClose: (() -> Void)?

    private var hosting: NSHostingView<OverlayView>?

    init() {
        let rect = NSRect(x: 0, y: 0, width: 420, height: 72)
        super.init(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        hasShadow = true
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

    func show(state: DictationState, level: Float, transcript: String) {
        let view = OverlayView(state: state, level: level, transcript: transcript, onCopy: { [weak self] t in self?.copyTranscript(t) }, onClose: { [weak self] in self?.onClose?() })
        hosting?.rootView = view
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
            self.orderFrontRegardless()
            self.alphaValue = 1
            self.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: false)
        }
    }

    private func copyTranscript(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        HistoryStore.shared.add(text)
        NSSound(named: "Pop")?.play()
    }

    func updateLevel(_ level: Float) {}

    func hide() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
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
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
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
                        .foregroundStyle(.white)
                    if state == .recording {
                        Circle().fill(.red).frame(width: 6, height: 6).symbolEffect(.pulse)
                    }
                }
                Group {
                    if state == .recording {
                        // Live dictation text
                        if transcript.isEmpty {
                            Text("Listening… press again to stop")
                                .font(.system(size: 11.5, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        } else {
                            Text(transcript)
                                .font(.system(size: 11.5, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .contentTransition(.opacity)
                        }
                    } else if !transcript.isEmpty && state != .recording {
                        Text(transcript)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    } else if state == .transcribing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini).tint(.white)
                            Text("Transcribing…").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.7))
                        }
                    } else if state == .injecting {
                        Text("Pasted at cursor ✓").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("⌥Space  •  Fn×2  to dictate").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            Spacer()

            if state == .recording {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(LinearGradient(colors: [.white, .white.opacity(0.85)], startPoint: .top, endPoint: .bottom))
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
                    .background(didCopy ? Color.green.opacity(0.9) : Color.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
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
                        .foregroundStyle(.white.opacity(0.75))
                        .background(Circle().fill(.white.opacity(0.12)))
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
                .fill(Color.black.opacity(0.82))
                .overlay(Capsule(style: .continuous).fill(.ultraThinMaterial.opacity(0.18)))
                .overlay(Capsule(style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
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
    private var colorForState: Color {
        switch state {
        case .idle: return .white.opacity(0.9)
        case .recording: return .red
        case .transcribing: return .orange
        case .injecting: return .green
        }
    }
    private var titleForState: String {
        switch state {
        case .idle: return "WisperVoice"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .injecting: return "Inserted ✓"
        }
    }
}
