import SwiftUI

/// First-run walkthrough. Interactive where it matters: permissions, engine choice, and
/// shortcut are all decided here — not silently defaulted. Apple Speech starts pre-selected
/// (it is the only engine that works with zero downloads and zero keys); the user can switch.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var step = 0

    private let stepCount = 6

    var body: some View {
        VStack(spacing: 20) {
            // Hand-rolled pager — TabView on macOS renders a segmented page control that
            // floats over the sheet as a detached grey/blue box (the "broken UI" report).
            ZStack {
                switch step {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: engineStep
                case 3: shortcutStep
                case 4: pillStep
                default: historyStep
                }
            }
            .id(step)
            .transition(.opacity)
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard).stroke(.primary.opacity(Theme.hairline), lineWidth: 1))

            HStack {
                Button("Skip") { finish() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if step > 0 {
                    Button("Back") { withAnimation(Theme.motion) { step -= 1 } }.buttonStyle(.bordered).controlSize(.small)
                }
                Button(step == stepCount - 1 ? "Get Started" : "Next") {
                    if step == stepCount - 1 { finish() }
                    else { withAnimation(Theme.motion) { step += 1 } }
                }
                .buttonStyle(.borderedProminent).controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Theme.accent : Color.primary.opacity(0.18))
                        .frame(width: i == step ? 18 : 7, height: 7)
                        .animation(Theme.motion, value: step)
                }
            }
        }
        .padding(22)
        .frame(width: 560, height: 470)
        .tint(Theme.violetAccent)
        .background(.background)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        isPresented = false
    }

    // MARK: Steps

    private func stepHeader(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.accent.opacity(Theme.subtleFill)).frame(width: 68, height: 68)
                Image(systemName: icon).font(.system(size: 30, weight: .semibold)).foregroundStyle(Theme.accent)
            }
            Text(title).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
            Text(desc).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 16)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            stepHeader(icon: "waveform.and.mic", title: "Welcome to WisperVoice",
                       desc: "System-wide dictation — speak in any app, watch the live pill, text lands at your cursor.")
        }.padding(16)
    }

    private var permissionsStep: some View {
        VStack(spacing: 14) {
            stepHeader(icon: "checkmark.shield.fill", title: "Grant Permissions",
                       desc: "Microphone + Speech Recognition + Accessibility (to type at your cursor). One time only.")
            PermissionsQuickRow()
        }.padding(16)
    }

    private var engineStep: some View {
        VStack(spacing: 14) {
            stepHeader(icon: "cpu", title: "Choose Your Engine",
                       desc: "Apple Speech works instantly, offline, free — and is the only engine that shows live text while you speak. Others transcribe when you stop. Switch anytime in Settings.")
            EnginePickerRow()
        }.padding(16)
    }

    private var shortcutStep: some View {
        VStack(spacing: 14) {
            stepHeader(icon: "keyboard.badge.ellipsis", title: "Set Your Shortcut",
                       desc: "Press it anywhere to start/stop dictating. Fn×2 double-tap always works too.")
            ShortcutPickerRow()
        }.padding(16)
    }

    private var pillStep: some View {
        VStack(spacing: 14) {
            stepHeader(icon: "captions.bubble.fill", title: "The Live Pill",
                       desc: "Live transcript + waveform while you speak. Pause briefly and the words so far are typed for you — keep talking to continue. × cancels, Copy grabs the text.")
        }.padding(16)
    }

    private var historyStep: some View {
        VStack(spacing: 14) {
            stepHeader(icon: "clock.arrow.circlepath", title: "History & Clipboard",
                       desc: "Every dictation is saved. Menu bar icon → recents, or the History section in the app for search, copy, and re-paste.")
        }.padding(16)
    }
}

/// Radio-style engine list built from the live provider registry. Engines that need a model
/// download or API key say so inline instead of failing silently later.
private struct EnginePickerRow: View {
    @ObservedObject private var modelManager = ModelManager.shared

    var body: some View {
        VStack(spacing: 6) {
            ForEach(AIProviderRegistry.shared.sttProviders, id: \.id) { p in
                let ready = isReady(p)
                let selected = modelManager.selectedSTTProviderId == p.id
                Button {
                    let firstReadyModel = modelManager.sttModels.first { $0.providerId == p.id && ($0.isDownloaded || $0.sizeMB == 0) }?.id
                    modelManager.selectSTT(providerId: p.id, modelId: firstReadyModel)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected ? Theme.violetAccent : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.displayName).font(.caption.weight(.semibold))
                            Text(readySubtitle(p, ready: ready)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if p.id == "apple-speech" {
                            Text("Recommended").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous))
        .frame(maxWidth: 380)
    }

    private func isReady(_ p: any AIModelProvider) -> Bool {
        if !p.isLocal || p.id == "apple-speech" { return true }
        return modelManager.sttModels.contains { $0.providerId == p.id && $0.isDownloaded }
    }
    private func readySubtitle(_ p: any AIModelProvider, ready: Bool) -> String {
        if p.requiresAPIKey { return "\(p.subtitle) — add API key in Settings" }
        if !ready { return "\(p.subtitle) — download a model in Models first" }
        return p.subtitle
    }
}

/// Shortcut preset picker — applies immediately via the live hotkey manager.
private struct ShortcutPickerRow: View {
    @ObservedObject private var dictation = DictationManager.shared

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(HotkeyManager.presets) { preset in
                // Selection is derived, not shadowed in @State: applyHotkeyPreset's
                // objectWillChange re-renders this grid, and a change made elsewhere
                // (Settings pane) stays reflected here.
                let selected = HotkeyManager.currentPreset.id == preset.id
                Button {
                    dictation.applyHotkeyPreset(preset.id)
                } label: {
                    Text(preset.label)
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selected ? Theme.accent.opacity(Theme.softFill) : Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusControl)
                                .stroke(selected ? Theme.accent.opacity(0.5) : Color.primary.opacity(Theme.hairline), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 400)
    }
}

private struct PermissionsQuickRow: View {
    @ObservedObject var pm = PermissionsManager.shared
    /// Speech Recognition is only asked for when the Apple Speech engine is in use —
    /// other engines never need it.
    private var rows: [(String, Bool)] {
        var r = [("Mic", pm.micGranted)]
        if PermissionsManager.speechRequired { r.append(("Speech (Apple engine)", pm.speechGranted)) }
        r.append(("Accessibility", pm.accessibilityGranted))
        return r
    }
    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.0) { t in
                HStack(spacing: 6) {
                    // The one "brand moment" violet is reserved for (see DESIGN_SYSTEM_ALIGNMENT §4):
                    // a permission flipping to granted during onboarding.
                    Image(systemName: t.1 ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(t.1 ? Theme.violetAccent : Theme.alert).font(.caption)
                    Text(t.0).font(.caption.weight(.medium))
                    Spacer()
                    if t.1 { Text("Granted").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            Button("Recheck") { pm.refresh() }.font(.caption).buttonStyle(.bordered).controlSize(.mini)
        }
        .padding(10).background(Theme.alert.opacity(Theme.hairline), in: RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous))
        .frame(maxWidth: 320)
        .onAppear { pm.refresh() }
    }
}
