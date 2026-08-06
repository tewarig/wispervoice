import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var dictation: DictationManager
    @EnvironmentObject var modelManager: ModelManager
    @State private var apiKeyVisible = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = true
    @State private var showClipboard = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape.2") }
            modelsTab
                .tabItem { Label("Models", systemImage: "externaldrive") }
            historyTab
                .tabItem { Label("Clipboard", systemImage: "clock.arrow.circlepath") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 580, height: 460)
        .background(.ultraThinMaterial)
        .onChange(of: launchAtLogin) { _, new in
            do {
                if new { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { launchAtLogin = !new }
        }
        .onChange(of: showInDock) { _, new in
            NSApp.setActivationPolicy(new ? .regular : .accessory)
            if new { NSApp.activate(ignoringOtherApps: false) }
        }
    }
    private var historyTab: some View {
        ClipboardHistoryView()
    }

    private var generalTab: some View {
        Form {
            Section {
                // Vercel AI SDK style provider picker — unified STT provider
                Picker("STT Provider", selection: $modelManager.selectedSTTProviderId) {
                    ForEach(AIProviderRegistry.shared.sttProviders, id: \.id) { p in
                        Label { Text(p.displayName) } icon: { Image(systemName: p.isLocal ? "cpu" : "cloud.fill") }
                            .tag(p.id)
                    }
                }.pickerStyle(.menu)
                Picker("STT Model", selection: Binding(
                    get: { modelManager.selectedSTTModelId ?? AIProviderRegistry.shared.provider(for: modelManager.selectedSTTProviderId)?.availableModels.first?.id },
                    set: { modelManager.selectSTT(providerId: modelManager.selectedSTTProviderId, modelId: $0) }
                )) {
                    let models = AIProviderRegistry.shared.provider(for: modelManager.selectedSTTProviderId)?.availableModels ?? []
                    ForEach(models, id: \.id) { m in Text(m.displayName).tag(Optional(m.id)) }
                    Text("Default").tag(Optional<String>.none)
                }.pickerStyle(.menu)
                if let prov = AIProviderRegistry.shared.provider(for: modelManager.selectedSTTProviderId) {
                    Text(prov.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                // Keep legacy picker for backward compat (hidden, sync shim)
                Picker("Legacy Provider", selection: $dictation.providerRaw) {
                    ForEach(TranscriptionProvider.allCases) { p in
                        Label(p.rawValue, systemImage: p == .appleSpeech ? "cpu" : "cloud.fill").tag(p.rawValue)
                    }
                }.pickerStyle(.menu).hidden()
                Picker("Language", selection: $dictation.languageCode) {
                    Text("English (US)").tag("en-US"); Text("English (UK)").tag("en-GB")
                    Text("Hindi").tag("hi-IN"); Text("Hinglish").tag("en-IN")
                    Text("Spanish").tag("es-ES"); Text("French").tag("fr-FR")
                    Text("German").tag("de-DE"); Text("Japanese").tag("ja-JP"); Text("Auto (Whisper)").tag("auto")
                }
                if modelManager.selectedSTTProviderId == "openai-whisper" || dictation.providerRaw == TranscriptionProvider.openAIWhisper.rawValue {
                    LabeledContent("API Key") {
                        HStack(spacing: 8) {
                            Group {
                                if apiKeyVisible { TextField("sk-…", text: $dictation.openAIKey) }
                                else { SecureField("sk-…", text: $dictation.openAIKey) }
                            }.textFieldStyle(.roundedBorder).frame(width: 220)
                            Button(apiKeyVisible ? "Hide" : "Show") { withAnimation { apiKeyVisible.toggle() } }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                    Text("Stored locally. Create at platform.openai.com").font(.caption2).foregroundStyle(.secondary)
                }
            } header: { Label("Transcription", systemImage: "waveform").font(.callout.weight(.semibold)) }

            Section {
                Toggle(isOn: $dictation.autoPaste) {
                    Label("Auto-paste at cursor", systemImage: "cursorarrow.click.2")
                    Text("Accessibility → Clipboard fallback").font(.caption2).foregroundStyle(.secondary)
                }
                Toggle(isOn: $dictation.llmPolish) {
                    Label("AI polish", systemImage: "sparkles")
                    Text("Fixes grammar via gpt-4o-mini (needs key)").font(.caption2).foregroundStyle(.secondary)
                }
                Toggle(isOn: $dictation.autoStopAfterSilence) {
                    Label("Auto-stop after silence", systemImage: "timer")
                    Text("Ends recording after \(Int(dictation.autoStopSeconds))s silence (VAD)").font(.caption2).foregroundStyle(.secondary)
                }
                if dictation.autoStopAfterSilence {
                    HStack {
                        Text("Silence duration").font(.caption)
                        Slider(value: $dictation.autoStopSeconds, in: 2...10, step: 1) { Text("Seconds") }
                            .frame(width: 120)
                        Text("\(Int(dictation.autoStopSeconds))s").font(.caption.monospacedDigit()).frame(width: 28)
                    }
                    HStack {
                        Text("Sensitivity").font(.caption)
                        Slider(value: $dictation.silenceThreshold, in: 0.04...0.20, step: 0.02)
                            .frame(width: 120)
                        Text(String(format: "%.2f", dictation.silenceThreshold)).font(.caption2.monospacedDigit()).frame(width: 36)
                    }
                }
            } header: { Label("Behavior", systemImage: "slider.horizontal.3").font(.callout.weight(.semibold)) }

            Section {
                Picker("TTS Provider", selection: $modelManager.selectedTTSProviderId) {
                    ForEach(AIProviderRegistry.shared.ttsProviders, id: \.id) { p in
                        Label(p.displayName, systemImage: "speaker.wave.2").tag(p.id)
                    }
                }.pickerStyle(.menu)
                Picker("TTS Voice/Model", selection: Binding(
                    get: { modelManager.selectedTTSModelId ?? AIProviderRegistry.shared.provider(for: modelManager.selectedTTSProviderId)?.availableModels.first?.id },
                    set: { modelManager.selectTTS(providerId: modelManager.selectedTTSProviderId, modelId: $0) }
                )) {
                    let models = AIProviderRegistry.shared.provider(for: modelManager.selectedTTSProviderId)?.availableModels ?? []
                    ForEach(models, id: \.id) { m in Text(m.displayName).tag(Optional(m.id)) }
                }.pickerStyle(.menu)
                if let prov = AIProviderRegistry.shared.provider(for: modelManager.selectedTTSProviderId) {
                    Text(prov.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
            } header: { Label("Voice / TTS", systemImage: "speaker.wave.3.fill").font(.callout.weight(.semibold)) }

            Section {
                LabeledContent("Hotkey", value: "⌥ Space  •  Fn ×2").font(.callout)
                Toggle(isOn: $launchAtLogin) {
                    Label("Open at Login", systemImage: "power.circle")
                    Text("Launches WisperVoice when you log in").font(.caption2).foregroundStyle(.secondary)
                }
                Toggle(isOn: $showInDock) {
                    Label("Show in Dock", systemImage: "dock.rectangle")
                    Text("Keep WisperVoice in Dock for quick access").font(.caption2).foregroundStyle(.secondary)
                }
                Text("Change hotkey in HotkeyManager.swift → keyCode / modifiers.").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Reveal STT Folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: modelManager.modelsDirectoryPath))
                    }.controlSize(.small)
                    Button("Reveal TTS Folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: modelManager.ttsDirectoryPath))
                    }.controlSize(.small)
                }
            } header: { Label("System", systemImage: "gearshape").font(.callout.weight(.semibold)) }
        }
        .formStyle(.grouped).scrollContentBackground(.hidden).padding(16)
    }

    private var modelsTab: some View {
        ScrollView {
            Form {
                Section {
                    Picker("STT Provider", selection: $modelManager.selectedSTTProviderId) {
                        ForEach(AIProviderRegistry.shared.sttProviders, id: \.id) { p in Text(p.displayName).tag(p.id) }
                    }.pickerStyle(.menu)
                    Picker("Active Model", selection: Binding(
                        get: { modelManager.selectedSTTModelId ?? AIProviderRegistry.shared.provider(for: modelManager.selectedSTTProviderId)?.availableModels.first?.id },
                        set: { modelManager.selectSTT(providerId: modelManager.selectedSTTProviderId, modelId: $0) }
                    )) {
                        let ms = AIProviderRegistry.shared.provider(for: modelManager.selectedSTTProviderId)?.availableModels ?? []
                        ForEach(ms, id: \.id) { m in Text(m.displayName).tag(Optional(m.id)) }
                        Text("None").tag(Optional<String>.none)
                    }.pickerStyle(.menu)
                    Text("Vercel AI SDK style: `provider(model)` — switch provider+model without code changes.").font(.caption2).foregroundStyle(.secondary)
                } header: { Label("STT Provider & Model", systemImage: "waveform.badge.mic").font(.callout.weight(.semibold)) }

                Section {
                    ForEach(modelManager.models) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.displayName).font(.callout.weight(.medium))
                                Text(m.isDownloaded ? "Downloaded • \(m.localPath?.path ?? "")" : "\(m.sizeMB) MB • \(m.url.lastPathComponent)")
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                if let prog = modelManager.downloadProgress[m.id], modelManager.isDownloading == m.id {
                                    ProgressView(value: prog).controlSize(.mini).frame(width: 160)
                                }
                            }
                            Spacer()
                            if m.isDownloaded {
                                if modelManager.activeModelId == m.id {
                                    Label("Active", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                                } else {
                                    Button("Use") { modelManager.select(m.id) }.buttonStyle(.bordered).controlSize(.small)
                                }
                                Button(role: .destructive) { modelManager.delete(m) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                            } else {
                                if modelManager.isDownloading == m.id {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Button("Download") { modelManager.download(m) }.buttonStyle(.borderedProminent).controlSize(.small)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Local Whisper Models (whisper.cpp) — legacy", systemImage: "externaldrive.connected.to.line.below")
                            .font(.callout.weight(.semibold))
                        Text("Kept for backward compat. New catalog below. Files in Application Support/WisperVoice/models.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(modelManager.sttModels.filter { $0.providerId != "apple-speech" && $0.providerId != "openai-whisper" }, id: \.id) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.displayName).font(.callout.weight(.medium))
                                HStack(spacing: 4) {
                                    Text(m.providerId).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                    Text("• \(m.sizeMB) MB • \(m.fileName)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                if m.isDownloaded { Text(m.localPath?.path ?? "Downloaded").font(.caption2).foregroundStyle(Theme.accent).lineLimit(1) }
                                if let prog = modelManager.aiDownloadProgress[m.id], modelManager.aiDownloadingId == m.id {
                                    ProgressView(value: prog).controlSize(.mini).frame(width: 160)
                                }
                            }
                            Spacer()
                            if m.isDownloaded {
                                if modelManager.selectedSTTModelId == m.id {
                                    Label("Active", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                                } else {
                                    Button("Use") { modelManager.selectSTT(providerId: m.providerId, modelId: m.id) }.buttonStyle(.bordered).controlSize(.small)
                                }
                                Button(role: .destructive) { modelManager.delete(m) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                            } else {
                                if modelManager.aiDownloadingId == m.id {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Button("Download") { modelManager.download(m) }.buttonStyle(.borderedProminent).controlSize(.small)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Open Whisper Variants (Whisper.cpp • Faster-Whisper • Parakeet)", systemImage: "cpu")
                            .font(.callout.weight(.semibold))
                        Text("Multi-provider STT — Vercel AI SDK abstraction. Switch via Settings without code change.").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(modelManager.ttsModels, id: \.id) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.displayName).font(.callout.weight(.medium))
                                HStack(spacing: 4) {
                                    Text(m.providerId).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                    Text("• \(m.sizeMB) MB • \(m.fileName)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                if m.isDownloaded { Text(m.localPath?.path ?? "Downloaded").font(.caption2).foregroundStyle(Theme.accent).lineLimit(1) }
                                if let prog = modelManager.aiDownloadProgress[m.id], modelManager.aiDownloadingId == m.id {
                                    ProgressView(value: prog).controlSize(.mini).frame(width: 160)
                                    Text("Downloading \(Int((prog)*100))%").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if m.isDownloaded {
                                if modelManager.selectedTTSModelId == m.id {
                                    Label("Active", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                                } else {
                                    Button("Use") { modelManager.selectTTS(providerId: m.providerId, modelId: m.id) }.buttonStyle(.bordered).controlSize(.small)
                                }
                                Button(role: .destructive) { modelManager.delete(m) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                            } else {
                                if modelManager.aiDownloadingId == m.id {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Button("Download") { modelManager.download(m) }.buttonStyle(.borderedProminent).controlSize(.small)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Open Voice TTS Models (Piper • Coqui XTTS • Whisper-TTS)", systemImage: "speaker.wave.2.fill")
                            .font(.callout.weight(.semibold))
                        Text("Download open voice models — stubbed with progress (writes placeholder to Application Support/WisperVoice/tts). Replace stub with real Piper/Coqui engine.").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Section {
                    LabeledContent("Active STT", value: AIProviderRegistry.shared.model(for: modelManager.selectedSTTModelId ?? "")?.displayName ?? modelManager.activeModel?.displayName ?? "System default")
                    LabeledContent("Active TTS", value: AIProviderRegistry.shared.model(for: modelManager.selectedTTSModelId ?? "")?.displayName ?? "None")
                    Text("STT: when provider is Apple Speech model is unused. For local Whisper variants select a downloaded model. TTS stub plays placeholder.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden).padding(16)
        }
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("How to use — like Wispr Flow", systemImage: "play.circle.fill").font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Press ⌥Space or Fn×2 to start", systemImage: "mic.circle.fill")
                            Label("See bubble — live text + waveform + × to cancel", systemImage: "capsule.portrait.fill")
                            Label("Press again → transcribes → pastes at cursor", systemImage: "text.cursor")
                            Label("Works everywhere: Slack, Notion, Xcode, Gmail", systemImage: "macwindow.on.rectangle")
                        }.font(.callout).foregroundStyle(.secondary)
                    }.padding(4)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Wispr Flow parity", systemImage: "checkmark.seal.fill").font(.subheadline.weight(.semibold))
                        Text("• System-wide dictation  • Floating pill with live text  • Auto-edits  • 100+ languages  • Clipboard fallback  • History  • Offline Apple + Cloud Whisper + Local models").font(.caption).foregroundStyle(.secondary)
                    }
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Privacy", systemImage: "lock.shield.fill").font(.subheadline.weight(.semibold))
                        Text("Apple Speech on-device. Whisper API only if you pick it. Local models stay on Mac. No analytics.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(16)
        }.background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }
}
