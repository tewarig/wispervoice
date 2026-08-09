import SwiftUI
import ServiceManagement

// The app is ONE window: these panes mount in the main window's sidebar (ContentView).
// The separate Settings scene / TabView container is intentionally gone — settings is
// not a different part of the app, it's the app itself.
//
// Every pane uses the same scaffold: `Pane` (title + measured column) → `SectionLabel`
// (uppercase tracked group heading) → `Card` (hairline surface) → `SettingRow` (label left,
// control right). Raw `Form` gave all four screens the same undifferentiated look and let
// controls drift far from their labels on a wide window.

struct GeneralSettingsPane: View {
    @EnvironmentObject var dictation: DictationManager
    @EnvironmentObject var modelManager: ModelManager
    @State private var apiKeyVisible = false
    /// nil = not checked yet; refreshed automatically whenever the key text settles.
    @State private var keyCheck: APIKeyCheck?
    @State private var isCheckingKey = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = true
    // OpenAI-compatible cloud endpoint — read by TranscriptionService via CloudConfig.
    @AppStorage(CloudConfig.baseURLKey) private var cloudBaseURL = "https://api.openai.com/v1"
    @AppStorage(CloudConfig.sttModelKey) private var cloudSTTModel = "whisper-1"
    @AppStorage(CloudConfig.polishModelKey) private var cloudPolishModel = "gpt-4o-mini"

    /// Read by OverlayWindow.show() each time the pill is presented. @AppStorage (not a
    /// raw UserDefaults Binding) so picking a new position re-renders the Picker — a plain
    /// Binding published nothing and the control kept displaying the old value.
    @AppStorage("pill.position") private var pillPosition = "bottom-center"

    /// Engine changes route through selectSTT so the model resets to the new engine's first
    /// ready model instead of pointing at the previous engine's.
    private var engineSelection: Binding<String> {
        Binding(get: { modelManager.selectedSTTProviderId },
                set: { newId in
                    let firstReady = modelManager.sttModels.first { $0.providerId == newId && ($0.isDownloaded || $0.sizeMB == 0) }?.id
                    modelManager.selectSTT(providerId: newId, modelId: firstReady)
                })
    }

    private var readyModels: [AIModel] {
        modelManager.sttModels.filter {
            $0.providerId == modelManager.selectedSTTProviderId && ($0.isDownloaded || $0.sizeMB == 0)
        }
    }

    private var usesOpenAI: Bool {
        modelManager.selectedSTTProviderId == "openai-whisper"
            || dictation.providerRaw == TranscriptionProvider.openAIWhisper.rawValue
    }

    var body: some View {
        Pane(title: "Settings", subtitle: "How dictation behaves, and where it appears.") {
            transcriptionSection
            behaviorSection
            shortcutSection
            systemSection
        }
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

    // MARK: Transcription

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Transcription", systemImage: "waveform")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    row {
                        SettingRow(
                            title: "Engine",
                            subtitle: modelManager.selectedSTTProviderId == "apple-speech"
                                ? "Runs on-device and shows live text while you speak"
                                : "Transcribes after you stop — live text is Apple Speech only",
                            systemImage: "cpu"
                        ) {
                            Picker("", selection: engineSelection) {
                                ForEach(AIProviderRegistry.shared.sttProviders, id: \.id) { p in
                                    Text(p.displayName).tag(p.id)
                                }
                            }.labelsHidden().pickerStyle(.menu).frame(width: 190)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(
                            title: "Model",
                            subtitle: readyModels.isEmpty ? "Nothing downloaded yet — pick one in Models" : nil,
                            systemImage: "shippingbox"
                        ) {
                            Picker("", selection: Binding(
                                get: { modelManager.selectedSTTModelId ?? readyModels.first?.id },
                                set: { modelManager.selectSTT(providerId: modelManager.selectedSTTProviderId, modelId: $0) }
                            )) {
                                ForEach(readyModels, id: \.id) { m in Text(m.displayName).tag(Optional(m.id)) }
                                if readyModels.isEmpty { Text("None available").tag(Optional<String>.none) }
                            }
                            .labelsHidden().pickerStyle(.menu).frame(width: 190)
                            .disabled(readyModels.isEmpty)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Language", systemImage: "globe") {
                            Picker("", selection: $dictation.languageCode) {
                                Text("English (US)").tag("en-US")
                                Text("English (UK)").tag("en-GB")
                                Text("English (India)").tag("en-IN")
                                Text("Hindi").tag("hi-IN")
                                Text("Spanish").tag("es-ES")
                                Text("French").tag("fr-FR")
                                Text("German").tag("de-DE")
                                Text("Japanese").tag("ja-JP")
                                Text("Detect automatically").tag("auto")
                            }.labelsHidden().pickerStyle(.menu).frame(width: 190)
                        }
                    }
                    if usesOpenAI {
                        RowDivider()
                        row {
                            SettingRow(
                                title: "Server",
                                subtitle: "Any OpenAI-compatible endpoint. Groq is ~9× cheaper than OpenAI; Mistral about half.",
                                systemImage: "server.rack"
                            ) {
                                HStack(spacing: 8) {
                                    TextField("https://api.openai.com/v1", text: $cloudBaseURL)
                                        .textFieldStyle(.roundedBorder).frame(width: 230)
                                    Menu("Preset") {
                                        Button("OpenAI — whisper-1") { applyPreset("https://api.openai.com/v1", "whisper-1", "gpt-4o-mini") }
                                        Button("Groq — whisper-large-v3-turbo (cheapest)") { applyPreset("https://api.groq.com/openai/v1", "whisper-large-v3-turbo", "llama-3.1-8b-instant") }
                                        Button("Mistral — voxtral-mini") { applyPreset("https://api.mistral.ai/v1", "voxtral-mini-latest", "mistral-small-latest") }
                                    }
                                    .frame(width: 80)
                                }
                            }
                        }
                        RowDivider()
                        row {
                            SettingRow(title: "Transcription model", subtitle: "Model name the server expects", systemImage: "waveform") {
                                TextField("whisper-1", text: $cloudSTTModel)
                                    .textFieldStyle(.roundedBorder).frame(width: 190)
                            }
                        }
                        RowDivider()
                        row {
                            SettingRow(title: "API key", subtitle: "Key for the server above — stored only on this Mac", systemImage: "key") {
                                HStack(spacing: 8) {
                                    Group {
                                        if apiKeyVisible { TextField("sk-…", text: $dictation.openAIKey) }
                                        else { SecureField("sk-…", text: $dictation.openAIKey) }
                                    }.textFieldStyle(.roundedBorder).frame(width: 190)
                                    Button(apiKeyVisible ? "Hide" : "Show") { withAnimation { apiKeyVisible.toggle() } }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                        RowDivider()
                        row { keyStatusRow.padding(.vertical, 9) }
                    }
                }
            }
            .task(id: dictation.openAIKey + "|" + cloudBaseURL) {
                // Probe the key whenever it or the server settles — the debounce avoids
                // hitting the API on every keystroke while pasting/typing.
                guard usesOpenAI, !dictation.openAIKey.isEmpty else {
                    keyCheck = nil
                    isCheckingKey = false
                    return
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                isCheckingKey = true
                let verdict = await TranscriptionService.shared.validateOpenAIKey(dictation.openAIKey)
                // A probe cancelled by further typing throws CancellationError inside the
                // URLSession call, which reads as .unreachable — don't let the dead task
                // flash a false "check your connection" over the replacement probe. Reset
                // the spinner though, or "Checking key…" sticks until a probe completes.
                guard !Task.isCancelled else { isCheckingKey = false; return }
                keyCheck = verdict
                isCheckingKey = false
            }
            // (No hidden "legacy sync" Picker here: a hidden picker can never fire its
            // setter, so it synced nothing. Readers of the legacy "provider" default now
            // resolve the effective engine via UserDefaults.sttProviderId instead.)
        }
    }

    /// One-click server+models switch for known OpenAI-compatible providers.
    private func applyPreset(_ url: String, _ sttModel: String, _ polishModel: String) {
        cloudBaseURL = url
        cloudSTTModel = sttModel
        cloudPolishModel = polishModel
    }

    /// Live verdict on the entered key — verified against the API, not just non-empty.
    @ViewBuilder
    private var keyStatusRow: some View {
        if dictation.openAIKey.isEmpty {
            Label("This engine can't transcribe without an API key.", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.rowMeta).foregroundStyle(Theme.alert)
        } else if isCheckingKey {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text("Checking key…").font(Theme.rowMeta).foregroundStyle(.secondary)
            }
        } else {
            switch keyCheck {
            case .valid:
                Label("Key verified — ready to transcribe.", systemImage: "checkmark.seal.fill")
                    .font(Theme.rowMeta).foregroundStyle(Theme.violetAccent)
            case .invalid:
                // "The server", not "OpenAI" — the probe hits whatever CloudConfig.baseURL
                // points at (Groq/Mistral/custom), so naming OpenAI misdirects debugging.
                Label("The server rejected this key — check it and try again.", systemImage: "xmark.octagon.fill")
                    .font(Theme.rowMeta).foregroundStyle(Theme.alert)
            case .unreachable:
                Label("Couldn't reach the server to verify — check your connection.", systemImage: "wifi.exclamationmark")
                    .font(Theme.rowMeta).foregroundStyle(.secondary)
            case nil:
                EmptyView()
            }
        }
    }

    // MARK: Behavior

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Behavior", systemImage: "slider.horizontal.3")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    row {
                        SettingRow(title: "Type at cursor", subtitle: "Insert the transcript into whatever app is focused", systemImage: "cursorarrow.click.2") {
                            Toggle("", isOn: $dictation.autoPaste).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Type as you pause", subtitle: "Words appear mid-dictation instead of all at the end (Apple Speech)", systemImage: "keyboard.badge.waveform") {
                            Toggle("", isOn: $dictation.liveTyping).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Clean up grammar", subtitle: "Polishes the transcript with an AI model — uses your cloud server and key", systemImage: "sparkles") {
                            Toggle("", isOn: $dictation.llmPolish).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    if dictation.llmPolish {
                        RowDivider()
                        row {
                            SettingRow(title: "Polish model", subtitle: "Chat model on the same server — cheap ones work fine here", systemImage: "text.badge.checkmark") {
                                TextField("gpt-4o-mini", text: $cloudPolishModel)
                                    .textFieldStyle(.roundedBorder).frame(width: 190)
                            }
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Pill position", subtitle: "Where the floating dictation pill appears", systemImage: "rectangle.bottomthird.inset.filled") {
                            Picker("", selection: $pillPosition) {
                                Text("Bottom Center").tag("bottom-center")
                                Text("Bottom Left").tag("bottom-left")
                                Text("Bottom Right").tag("bottom-right")
                                Text("Top Center").tag("top-center")
                                Text("Top Left").tag("top-left")
                                Text("Top Right").tag("top-right")
                            }.labelsHidden().pickerStyle(.menu).frame(width: 190)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Stop after silence", subtitle: "Ends the recording once you stop talking", systemImage: "timer") {
                            Toggle("", isOn: $dictation.autoStopAfterSilence).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    if dictation.autoStopAfterSilence {
                        RowDivider()
                        row {
                            sliderRow(
                                title: "Silence before stopping",
                                value: "\(Int(dictation.autoStopSeconds))s",
                                binding: $dictation.autoStopSeconds, range: 2...10, step: 1
                            )
                        }
                        RowDivider()
                        row {
                            sliderRow(
                                title: "Microphone sensitivity",
                                value: String(format: "%.2f", dictation.silenceThreshold),
                                binding: $dictation.silenceThreshold, range: 0.04...0.20, step: 0.02
                            )
                        }
                    }
                }
            }
        }
    }

    private func sliderRow(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(Theme.rowTitle)
                Spacer()
                Text(value).font(Theme.numeral).foregroundStyle(.secondary)
            }
            Slider(value: binding, in: range, step: step)
        }
        .padding(.vertical, 9)
    }

    // MARK: Shortcut

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Shortcut", systemImage: "keyboard")
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Press this anywhere to start or stop dictating. Double-tapping Fn always works too.")
                        .font(Theme.rowMeta).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(HotkeyManager.presets) { preset in
                            let selected = HotkeyManager.currentPreset.id == preset.id
                            Button { dictation.applyHotkeyPreset(preset.id) } label: {
                                Text(preset.label)
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(
                                        selected ? Theme.violetAccent.opacity(0.16) : Theme.wellFill,
                                        in: RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                                            .stroke(selected ? Theme.violetAccent.opacity(0.55) : Theme.border, lineWidth: 1)
                                    )
                                    .foregroundStyle(selected ? Theme.violetAccent : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: System

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("System", systemImage: "gearshape")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    row {
                        SettingRow(title: "Open at login", subtitle: "Start WisperVoice when you log in", systemImage: "power") {
                            Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Show in Dock", subtitle: "Turn off to run from the menu bar only", systemImage: "dock.rectangle") {
                            Toggle("", isOn: $showInDock).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    RowDivider()
                    row {
                        SettingRow(title: "Downloaded files", subtitle: "Models are stored in Application Support", systemImage: "folder") {
                            HStack(spacing: 8) {
                                Button("Models") { NSWorkspace.shared.open(URL(fileURLWithPath: modelManager.modelsDirectoryPath)) }
                                    .buttonStyle(.bordered)
                                Button("Voices") { NSWorkspace.shared.open(URL(fileURLWithPath: modelManager.ttsDirectoryPath)) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Consistent horizontal inset for rows inside a zero-padding card.
    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().padding(.horizontal, 16)
    }
}


/// Models — one list, grouped by engine. Previously the same whisper.cpp models appeared
/// in two sections (a "legacy" list and the catalog), so the screen showed "Tiny — Active"
/// twice and contradicted itself. The catalog is a superset, so it is the only list now.
struct ModelsPane: View {
    @EnvironmentObject var modelManager: ModelManager

    /// Switching engine also resets the model — a stale id from the previous engine left
    /// the model picker rendering blank.
    private var engineSelection: Binding<String> {
        Binding(get: { modelManager.selectedSTTProviderId },
                set: { newId in
                    let firstReady = modelManager.sttModels.first { $0.providerId == newId && ($0.isDownloaded || $0.sizeMB == 0) }?.id
                    modelManager.selectSTT(providerId: newId, modelId: firstReady)
                })
    }

    var body: some View {
        Pane(title: "Models", subtitle: "Choose the engine that turns your speech into text.") {
            SectionLabel("Active engine", systemImage: "waveform.badge.mic")
            Card {
                VStack(spacing: 0) {
                    SettingRow(title: "Engine", subtitle: engineSubtitle) {
                        Picker("", selection: engineSelection) {
                            ForEach(AIProviderRegistry.shared.sttProviders, id: \.id) { p in
                                Text(p.displayName).tag(p.id)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu).frame(width: 200)
                    }
                    RowDivider()
                    SettingRow(title: "Model", subtitle: readyModels.isEmpty ? "Download one below to use this engine" : nil) {
                        Picker("", selection: Binding(
                            get: { modelManager.selectedSTTModelId ?? readyModels.first?.id },
                            set: { modelManager.selectSTT(providerId: modelManager.selectedSTTProviderId, modelId: $0) }
                        )) {
                            ForEach(readyModels, id: \.id) { m in Text(m.displayName).tag(Optional(m.id)) }
                            if readyModels.isEmpty { Text("None available").tag(Optional<String>.none) }
                        }
                        .labelsHidden().pickerStyle(.menu).frame(width: 200)
                        .disabled(readyModels.isEmpty)
                    }
                }
            }

            ForEach(AIProviderRegistry.shared.sttProviders, id: \.id) { provider in
                let models = modelManager.sttModels.filter { $0.providerId == provider.id }
                if !models.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(provider.displayName, systemImage: provider.isLocal ? "cpu" : "cloud")
                        Text(provider.subtitle).font(Theme.rowMeta).foregroundStyle(.secondary).padding(.leading, 2)
                        Card(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                                    if index > 0 { RowDivider() }
                                    modelRow(model)
                                }
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Voices", systemImage: "speaker.wave.2")
                Text("Text-to-speech is in preview — downloads reserve the model slot while the speech engine is being built.")
                    .font(Theme.rowMeta).foregroundStyle(.secondary).padding(.leading, 2)
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(modelManager.ttsModels.enumerated()), id: \.element.id) { index, model in
                            if index > 0 { RowDivider() }
                            modelRow(model, isTTS: true)
                        }
                    }
                }
            }
        }
    }

    private var readyModels: [AIModel] {
        modelManager.sttModels.filter {
            $0.providerId == modelManager.selectedSTTProviderId && ($0.isDownloaded || $0.sizeMB == 0)
        }
    }

    private var engineSubtitle: String {
        // In-memory mirror, not KeychainStore.get: this runs on every body evaluation
        // (tens of times/sec during a model download), and each get is a securityd IPC.
        if modelManager.selectedSTTProviderId == "openai-whisper",
           DictationManager.shared.openAIKey.isEmpty {
            return "Needs an API key — add it in Settings before this engine can transcribe"
        }
        return modelManager.selectedSTTProviderId == "apple-speech"
            ? "Shows live text while you speak"
            : "Transcribes after you stop — live preview is Apple Speech only"
    }

    @ViewBuilder
    private func modelRow(_ model: AIModel, isTTS: Bool = false) -> some View {
        let isActive = isTTS
            ? modelManager.selectedTTSModelId == model.id
            : modelManager.selectedSTTModelId == model.id
        let isDownloading = modelManager.aiDownloadingId == model.id
        let progress = modelManager.aiDownloadProgress[model.id]
        let builtIn = model.sizeMB == 0

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(model.displayName).font(Theme.rowTitle)
                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold)).tracking(0.6)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.violetAccent.opacity(0.16), in: Capsule())
                            .foregroundStyle(Theme.violetAccent)
                    }
                }
                Text(model.description).font(Theme.rowMeta).foregroundStyle(.secondary).lineLimit(1)
                if isDownloading, let progress {
                    ProgressView(value: progress).controlSize(.small).frame(width: 200)
                }
            }
            Spacer(minLength: 12)
            Text(builtIn ? "Built in" : "\(model.sizeMB) MB")
                .font(Theme.numeral).foregroundStyle(.secondary)
            if builtIn || model.isDownloaded {
                if !isActive {
                    Button("Use") {
                        if isTTS { modelManager.selectTTS(providerId: model.providerId, modelId: model.id) }
                        else { modelManager.selectSTT(providerId: model.providerId, modelId: model.id) }
                    }.buttonStyle(.bordered)
                }
                if !builtIn {
                    Button { modelManager.delete(model) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .help("Remove downloaded model")
                }
            } else if isDownloading {
                ProgressView().controlSize(.small)
            } else {
                Button("Download") { modelManager.download(model) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct AboutPane: View {
    private var build: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "WisperVoice"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let number = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(name) · \(version) (build \(number))"
    }

    var body: some View {
        Pane(title: "About", subtitle: "Speak anywhere on your Mac and the words land at your cursor.") {
            SectionLabel("How it works", systemImage: "play.circle")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    step(1, "Press \(HotkeyManager.currentPreset.label)", "Start dictating from any app — no window to focus first.")
                    RowDivider()
                    step(2, "Speak naturally", "The pill shows a live transcript and a waveform while you talk.")
                    RowDivider()
                    step(3, "Pause or press again", "Your words are typed at the cursor, or copied if pasting isn't available.")
                }
            }

            SectionLabel("Privacy", systemImage: "lock.shield")
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    bullet("Apple Speech runs on-device — your audio never leaves your Mac.")
                    bullet("Downloaded Whisper models also run entirely locally.")
                    bullet("Cloud transcription is used only if you choose it and add your own API key.")
                    bullet("No analytics, no tracking, no accounts.")
                }
            }

            SectionLabel("Version", systemImage: "number")
            Card {
                Text(build).font(Theme.numeral).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: 24, height: 24)
                .background(Theme.violetAccent.opacity(0.14), in: Circle())
                .foregroundStyle(Theme.violetAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.rowTitle)
                Text(detail).font(Theme.rowMeta).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(Theme.violetAccent.opacity(0.5)).frame(width: 4, height: 4).padding(.top, 6)
            Text(text).font(.system(size: 12.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
