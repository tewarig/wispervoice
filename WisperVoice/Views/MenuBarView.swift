import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var dictation: DictationManager
    @EnvironmentObject var permissions: PermissionsManager
    @StateObject private var history = HistoryStore.shared
    @State private var showCopied = false
    @State private var isHoveringMain = false
    @Namespace private var ns

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.6)

            mainCTA
                .padding(.horizontal, 12).padding(.vertical, 10)

            if let err = dictation.errorMessage {
                Label(err, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .lineLimit(3)
                    .contentTransition(.opacity)
            }

            permissionsBanner

            if !dictation.lastTranscript.isEmpty {
                lastTranscriptCard
                    .padding(.horizontal, 12).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            historySection

            footer
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        .onAppear { permissions.refresh() }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: dictation.state)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dictation.lastTranscript)
    }

    // MARK: Header — Explore SwiftUI: glass + SF Symbol + status dot with pulse
    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .shadow(color: .purple.opacity(0.25), radius: 8, y: 4)
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("WisperVoice").font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(statusText).font(.caption2).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            statusDot
        }
        .padding(14)
        .background(
            LinearGradient(colors: [.white.opacity(0.02), .clear], startPoint: .top, endPoint: .bottom)
        )
    }

    private var statusDot: some View {
        ZStack {
            if dictation.state == .recording {
                Circle().fill(.red.opacity(0.25))
                    .frame(width: 22, height: 22)
                    .scaleEffect(1.15)
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: dictation.state)
            }
            Circle()
                .fill(dictation.state == .recording ? Color.red : dictation.state == .transcribing ? Color.orange : Color.green)
                .frame(width: 9, height: 9)
                .shadow(color: (dictation.state == .recording ? Color.red : Color.green).opacity(0.6), radius: 4)
                .opacity(dictation.state == .idle ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.3), value: dictation.state)
        }
        .frame(width: 22, height: 22)
    }

    // MARK: Main CTA — borderedProminent + hover + progress
    private var mainCTA: some View {
        Button(action: { dictation.toggleDictation() }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isRecording ? .red.opacity(0.14) : Color.accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: isRecording ? "stop.fill" : isTranscribing ? "waveform" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isRecording ? .red : .accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, isActive: isRecording)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRecording ? "Stop Recording" : isTranscribing ? "Transcribing…" : isInjecting ? "Inserted ✓" : "Start Dictating")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(isRecording ? "Press again to finish" : "Speak naturally — auto-edits on")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if isTranscribing {
                    ProgressView().controlSize(.small).tint(.orange)
                } else {
                    Text(hintText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(isHoveringMain ? 0.08 : 0.04), radius: isHoveringMain ? 10 : 6, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).strokeBorder(
                            isRecording ? Color.red.opacity(0.18) : Color.primary.opacity(0.06), lineWidth: 1
                        )
                    )
            }
            .overlay {
                if isRecording {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.22), lineWidth: 1)
                        .matchedGeometryEffect(id: "cta", in: ns)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHoveringMain = $0 }
        .disabled(isTranscribing || isInjecting)
        .sensoryFeedback(.impact, trigger: dictation.state)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHoveringMain)
    }

    private var permissionsBanner: some View {
        Group {
            if !permissions.allGranted {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Permissions needed", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    VStack(spacing: 6) {
                        if !permissions.micGranted { permRow("Microphone", icon: "mic.slash", action: { PermissionsManager.requestMicrophonePermission() }) }
                        if !permissions.speechGranted { permRow("Speech Recognition", icon: "waveform.badge.mic", action: { permissions.requestSpeechPermission() }) }
                        if !permissions.accessibilityGranted { permRow("Accessibility", icon: "cursorarrow.click.2", action: { permissions.requestAccessibility() }) }
                    }
                    Button("Recheck") { permissions.refresh() }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered).controlSize(.mini).tint(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.14), lineWidth: 1))
                .padding(.horizontal, 12).padding(.top, 4)
            }
        }
    }

    private var lastTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Last transcript", systemImage: "text.bubble.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(showCopied ? "Copied!" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(dictation.lastTranscript, forType: .string)
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now()+1.5){ withAnimation { showCopied=false } }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.bordered).controlSize(.mini)
                .contentTransition(.numericText())

                Button("Paste Again") { TextInjector.inject(text: dictation.lastTranscript) }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.borderedProminent).controlSize(.mini)
            }
            Text(dictation.lastTranscript)
                .font(.system(size: 12.5, design: .rounded))
                .lineSpacing(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                .textSelection(.enabled)
        }
    }

    private var historySection: some View {
        Group {
            if !history.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("History").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear", role: .destructive) { withAnimation { history.clear() } }
                            .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(history.items.prefix(8)) { item in
                                Button(action: { TextInjector.inject(text: item.text) }) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.text).font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                                            Text(item.date, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.forward.app")
                                            .font(.caption2).foregroundStyle(.quaternary)
                                    }
                                    .padding(9)
                                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { history.items.removeAll { $0.id == item.id } }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 170)
                    .scrollIndicators(.hidden)
                }
                .padding(.top, 6)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { NSApp.activate(ignoringOtherApps: true); if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) { w.makeKeyAndOrderFront(nil) } else { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } } label: { Label("Open App", systemImage: "macwindow") }
                .font(.caption.weight(.medium)).buttonStyle(.bordered).controlSize(.small)
            SettingsLink { Label("Settings", systemImage: "gearshape") }
                .font(.caption.weight(.medium))
                .buttonStyle(.bordered).controlSize(.small)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .font(.caption.weight(.medium))
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.bar)
    }

    private func permRow(_ title: String, icon: String, action: @escaping ()->Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.orange).frame(width: 16)
            Text(title).font(.caption)
            Spacer()
            Button("Enable", action: action).font(.caption.weight(.medium)).buttonStyle(.bordered).controlSize(.mini)
        }
    }

    private var isRecording: Bool { dictation.state == .recording }
    private var isTranscribing: Bool { dictation.state == .transcribing }
    private var isInjecting: Bool { dictation.state == .injecting }
    private var statusText: String {
        switch dictation.state {
        case .idle: return "Ready — \(dictation.providerRaw)"
        case .recording: return "● Recording — press again to stop"
        case .transcribing: return "Transcribing…"
        case .injecting: return "Inserted ✓"
        }
    }
    private var hintText: String { "⌥Space  •  Fn×2" }
}
