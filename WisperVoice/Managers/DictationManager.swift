import Foundation
import SwiftUI
import AVFoundation
import ApplicationServices
import Combine
import Speech

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case injecting
}

@MainActor
final class DictationManager: ObservableObject {
    /// One instance for the whole app. The AppKit status-item popover and the SwiftUI scenes
    /// must observe the same object — and `init()` registers the global hotkey, which would
    /// double-fire if a second instance ever existed.
    static let shared = DictationManager()

    @Published var state: DictationState = .idle
    @Published var lastTranscript: String = ""
    @Published var liveTranscript: String = ""
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0

    @AppStorage("provider") var providerRaw: String = TranscriptionProvider.appleSpeech.rawValue
    /// Keychain-backed (encrypted), not @AppStorage — UserDefaults is a plaintext plist.
    /// `didSet` fires for @Published properties during `init` too, so loading the stored
    /// value must not write back: a transient Keychain read failure (locked keychain at
    /// login, errSecInteractionNotAllowed) would otherwise assign "" and DELETE the real key.
    /// Only user edits reach the Keychain.
    private var isHydratingKey = false
    @Published var openAIKey: String = "" {
        didSet {
            guard !isHydratingKey else { return }
            KeychainStore.set(openAIKey, account: "openAIKey")
        }
    }
    @AppStorage("languageCode") var languageCode: String = "en-US"
    @AppStorage("autoPaste") var autoPaste: Bool = true
    @AppStorage("llmPolish") var llmPolish: Bool = false
    @AppStorage("holdToTalk") var holdToTalk: Bool = false
    @AppStorage("autoStopAfterSilence") var autoStopAfterSilence: Bool = true
    @AppStorage("autoStopSeconds") var autoStopSeconds: Double = 5.0
    @AppStorage("silenceThreshold") var silenceThreshold: Double = 0.08
    /// Wispr-Flow-style: when you pause mid-dictation, the words so far are inserted at the
    /// cursor immediately instead of waiting for the recording to end. Apple Speech only
    /// (needs live partials).
    @AppStorage("liveTyping") var liveTyping: Bool = true

    var provider: TranscriptionProvider {
        get { TranscriptionProvider(rawValue: providerRaw) ?? .appleSpeech }
        set { providerRaw = newValue.rawValue }
    }

    /// The engine actually in use — the modern ai.stt.* selection, falling back to legacy.
    /// Everything Apple-Speech-specific (live partials, live typing, speech permission)
    /// must key off this, NOT the legacy `provider`, which stays `.appleSpeech` even after
    /// the user switches to Whisper in Settings.
    var usesAppleSpeech: Bool {
        // One resolver for the whole app: UserDefaults.sttProviderId already handles the
        // ai.stt.provider → ai.sttProvider → legacy "provider" fallback chain. Hand-rolled
        // fallbacks here vs. PermissionsManager/OverlayView diverged for legacy users.
        UserDefaults.standard.sttProviderId == "apple-speech"
    }

    private let recorder = AudioRecorder()
    private var recordingURL: URL?
    private var hotkeyManager = HotkeyManager()
    private var levelTimer: Timer?
    private var liveTask: Task<Void, Never>?
    private var speechTask: SFSpeechRecognitionTask?
    private var bufferRequest: SFSpeechAudioBufferRecognitionRequest?
    private var silenceStart: Date?
    private var silenceTimer: Timer?
    /// Live-typing bookkeeping: the prefix of `liveTranscript` already inserted at the cursor,
    /// and whether the current pause has already triggered a commit.
    private var liveCommitted = ""
    private var pauseCommitted = false
    /// A pause this long (but shorter than auto-stop) commits the words dictated so far.
    private let pauseCommitSeconds: TimeInterval = 0.9
    /// The app that was frontmost when recording began — where the transcript must land.
    /// Snapshotted at start so an app activating mid-dictation cannot hijack the paste.
    private var targetApp: NSRunningApplication?
    /// When the current recording started — feeds the minutes-dictated stat.
    private var recordingStartedAt: Date?
    /// Invalidates overlay-dismiss timers from PREVIOUS dictations: a stale 8s grace timer
    /// must not hide the pill while it is showing the next dictation's result.
    private var dismissToken = 0

    init() {
        // Legacy-domain import must land BEFORE the key is read, or an upgrading user's
        // key exists but openAIKey stays empty until the next relaunch. Self-guarded.
        LegacyDefaults.migrateOnce()
        KeychainStore.migrate(defaultsKey: "openAIKey", account: "openAIKey")
        isHydratingKey = true
        openAIKey = KeychainStore.get("openAIKey") ?? ""
        isHydratingKey = false
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in self?.toggleDictation() }
        }
        hotkeyManager.register()
        OverlayWindow.sharedInstance.onClose = { [weak self] in
            Task { @MainActor in self?.cancelRecording() }
        }
    }

    /// Change the global shortcut (persisted preset id from `HotkeyManager.presets`).
    func applyHotkeyPreset(_ id: String) {
        hotkeyManager.apply(presetId: id)
        objectWillChange.send() // UI hint chips re-read HotkeyManager.currentHintLabel
    }

    func toggleDictation() {
        switch state {
        case .idle: startRecording()
        case .recording: stopAndTranscribe()
        case .transcribing, .injecting: break
        }
    }

    func startRecording() {
        errorMessage = nil
        // Fail fast: recording with a key-less cloud engine would only error after the
        // user finished speaking — worse than refusing up front with a clear reason.
        let effectiveProvider = UserDefaults.standard.sttProviderId
        if effectiveProvider == "openai-whisper", openAIKey.isEmpty {
            errorMessage = "OpenAI Whisper needs an API key — add it in Settings, or switch to Apple Speech."
            NSSound(named: "Basso")?.play()
            return
        }
        liveTranscript = ""
        liveCommitted = ""
        pauseCommitted = false
        guard state == .idle else { return }
        targetApp = FocusTracker.shared.lastExternalApp
        FocusLog.log("startRecording: captured target=\(targetApp?.localizedName ?? "nil"), axTrusted=\(AXIsProcessTrusted())")
        do {
            recordingURL = try recorder.startRecording()
            recordingStartedAt = Date()
            state = .recording
            startLevelMetering()
            startLiveTranscription()
            showOverlay()
            NSSound(named: "Pop")?.play()
        } catch {
            errorMessage = error.localizedDescription
            state = .idle
        }
    }

    func stopAndTranscribe() {
        guard state == .recording else { return }
        levelTimer?.invalidate()
        silenceTimer?.invalidate()
        silenceStart = nil
        liveTask?.cancel()
        bufferRequest?.endAudio()
        bufferRequest = nil
        speechTask?.cancel()
        audioLevel = 0
        recorder.onLevel = nil
        let url = recorder.stopRecording()
        recordingURL = url
        // Keep last live text as fallback if file transcription fails
        let fallbackLive = liveTranscript
        let recordedSeconds = recordingStartedAt.map { Date().timeIntervalSince($0) }
        recordingStartedAt = nil
        // Live typing already inserted this prefix at the cursor — the final injection must
        // only deliver the remainder, and must not re-polish (that would rewrite text the
        // target app already has).
        let alreadyCommitted = liveCommitted
        liveCommitted = ""
        pauseCommitted = false
        liveTranscript = ""
        guard let url else { state = .idle; hideOverlay(); return }

        state = .transcribing
        updateOverlay()

        if !alreadyCommitted.isEmpty {
            let full = fallbackLive
            lastTranscript = full
            if !full.isEmpty { HistoryStore.shared.add(full, duration: recordedSeconds) }
            try? FileManager.default.removeItem(at: url)
            // Word-count alignment, not strict prefix: on-device recognition routinely
            // revises committed text ("hello world" → "Hello world,"), and a strict
            // hasPrefix check made the remainder empty — everything said after the last
            // pause was silently dropped. Counting words survives those revisions.
            let remainder: String
            if full.hasPrefix(alreadyCommitted) {
                remainder = String(full.dropFirst(alreadyCommitted.count))
            } else {
                let committedWordCount = alreadyCommitted.split(whereSeparator: \.isWhitespace).count
                let allWords = full.split(whereSeparator: \.isWhitespace)
                remainder = allWords.count > committedWordCount
                    ? " " + allWords.dropFirst(committedWordCount).joined(separator: " ")
                    : ""
            }
            if autoPaste, !remainder.isEmpty {
                state = .injecting
                updateOverlay()
                Task {
                    // Same 250 ms settle the normal path uses: the stop hotkey's modifiers
                    // can still be physically held, which would corrupt the synthetic ⌘V
                    // fallback if we inject in the same tick.
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    TextInjector.inject(text: remainder, target: targetApp)
                    NSSound(named: "Glass")?.play()
                    state = .idle
                    updateOverlay()
                    scheduleOverlayDismiss()
                }
                return
            }
            state = .idle
            updateOverlay()
            scheduleOverlayDismiss()
            return
        }

        Task {
            do {
                let raw: String
                // If we have live text and provider is Apple, reuse it for speed
                if !fallbackLive.isEmpty && usesAppleSpeech {
                    raw = fallbackLive
                } else {
                    // Vercel AI SDK style: unified provider dispatch via ModelManager selection
                    let sttProvider = UserDefaults.standard.sttProviderId
                    let sttModel = UserDefaults.standard.string(forKey: AISettingsKeys.sttModel)
                    // If ModelManager selection differs from legacy provider, prefer unified path
                    if AIProviderRegistry.shared.provider(for: sttProvider) != nil {
                        let lang = languageCode.split(separator: "-").first.map(String.init)
                        raw = try await TranscriptionService.shared.transcribe(fileURL: url, providerId: sttProvider, modelId: sttModel, language: lang, apiKey: openAIKey.isEmpty ? nil : openAIKey)
                    } else {
                        switch provider {
                        case .appleSpeech:
                            raw = try await TranscriptionService.shared.transcribeWithAppleSpeech(fileURL: url, locale: Locale(identifier: languageCode))
                        case .openAIWhisper:
                            let lang = languageCode.split(separator: "-").first.map(String.init)
                            raw = try await TranscriptionService.shared.transcribeWithWhisper(fileURL: url, apiKey: openAIKey, language: lang)
                        }
                    }
                }
                let polished = await TranscriptionService.shared.polish(raw, useLLMPolishing: llmPolish, openAIKey: openAIKey.isEmpty ? nil : openAIKey)
                lastTranscript = polished.isEmpty ? raw : polished
                if !lastTranscript.isEmpty { HistoryStore.shared.add(lastTranscript, duration: recordedSeconds) }
                try? FileManager.default.removeItem(at: url)
                if autoPaste, !lastTranscript.isEmpty {
                    state = .injecting
                    updateOverlay()
                    try await Task.sleep(nanoseconds: 250_000_000)
                    TextInjector.inject(text: lastTranscript, target: targetApp)
                    NSSound(named: "Glass")?.play()
                }
                state = .idle
                updateOverlay()
                scheduleOverlayDismiss()
            } catch {
                // Fallback to live transcript on error
                if !fallbackLive.isEmpty {
                    lastTranscript = fallbackLive
                    HistoryStore.shared.add(fallbackLive, duration: recordedSeconds)
                    if autoPaste { TextInjector.inject(text: fallbackLive, target: targetApp) }
                } else {
                    errorMessage = error.localizedDescription
                }
                state = .idle
                updateOverlay()
                try? FileManager.default.removeItem(at: url)
                scheduleOverlayDismiss()
            }
        }
    }

    /// Hide the pill after a result. Quick when the text landed at the cursor; a longer
    /// grace period — with Copy showing — when insertion couldn't have worked (auto-paste
    /// off, no captured target app, or Accessibility not granted), so the user can still
    /// take the transcript before the pill removes itself.
    private func scheduleOverlayDismiss() {
        let inserted = autoPaste && targetApp != nil && AXIsProcessTrusted()
        let delay: TimeInterval = inserted ? 1.2 : 8
        dismissToken &+= 1
        let token = dismissToken
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.dismissToken == token, self.state == .idle else { return } // a newer dictation owns the pill now
            self.hideOverlay()
        }
    }

    func cancelRecording() {
        levelTimer?.invalidate()
        silenceTimer?.invalidate()
        silenceStart = nil
        liveTask?.cancel()
        bufferRequest?.endAudio()
        bufferRequest = nil
        speechTask?.cancel()
        recorder.onLevel = nil
        recorder.cancelRecording()
        recordingStartedAt = nil
        liveTranscript = ""
        liveCommitted = ""
        pauseCommitted = false
        state = .idle
        hideOverlay()
        NSSound(named: "Basso")?.play()
    }

    // MARK: - Live transcription (Apple Speech partials)
    private func startLiveTranscription() {
        guard usesAppleSpeech else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)), recognizer.isAvailable else { return }
        if SFSpeechRecognizer.authorizationStatus() != .authorized { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // On-device recognition streams partials word-by-word as you speak. Server
        // recognition batches — words only appeared after a pause, which read as "not live".
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        if #available(macOS 13, *) { request.addsPunctuation = true }
        self.bufferRequest = request
        // Feed the mic tap into the recognizer — partials never arrive without this.
        // Capture the request itself, NOT self: the tap thread reading the MainActor
        // `bufferRequest` while the main thread endAudio()s and nils it is a data race.
        // The closure's strong capture keeps the request alive until the recorder clears
        // onBuffer on stop/cancel; append-after-endAudio is safely ignored by the API.
        recorder.onBuffer = { buffer in
            request.append(buffer)
        }

        // Feed audio engine buffers if available — otherwise use timer to simulate live for demo
        // For real mic, AudioRecorder would expose tap; here we use a lightweight timer that updates liveTranscript with accumulating words from level
        liveTask = Task { @MainActor in
            // Hook into recorder's audio if possible later — for now poll and also listen to recognizer partials
            self.speechTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result = result, self.state == .recording {
                        // The state guard matters: a partial queued around cancel/stop would
                        // otherwise re-present the pill after hideOverlay() — and supersede
                        // the hide fade's token — leaving it stranded with no dismissal.
                        self.liveTranscript = result.bestTranscription.formattedString
                        self.showOverlay() // update pill with live text
                    }
                    if error != nil {
                        self.speechTask = nil
                    }
                }
            }
            // Keep request alive by not finishing audio — engine's tap would feed here if implemented
            while !Task.isCancelled && self.state == .recording {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    // MARK: - Overlay (always via singleton)
    private func showOverlay() {
        let text = state == .recording ? (liveTranscript.isEmpty ? "" : liveTranscript) : (state == .transcribing ? "Transcribing…" : lastTranscript)
        OverlayWindow.sharedInstance.show(state: state, level: audioLevel, transcript: text)
    }
    private func updateOverlay() {
        let text: String
        if state == .recording { text = liveTranscript }
        else if state == .transcribing { text = "Transcribing…" }
        else { text = lastTranscript }
        OverlayWindow.sharedInstance.show(state: state, level: audioLevel, transcript: text)
    }
    private func hideOverlay() { OverlayWindow.sharedInstance.hide() }

    private func startLevelMetering() {
        // Real RMS from AudioRecorder drives waveform + VAD; fallback to random when in tests/no tap
        var hasRealLevel = false
        recorder.onLevel = { [weak self] lvl in
            Task { @MainActor in
                guard let self, self.state == .recording else { return }
                hasRealLevel = true
                self.audioLevel = lvl
                self.showOverlay()
                self.handleVAD(level: lvl)
            }
        }
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .recording else { return }
                if !hasRealLevel {
                    self.audioLevel = Float.random(in: 0.08...0.22) // quieter fallback simulates silence detection
                    self.showOverlay()
                    self.handleVAD(level: self.audioLevel)
                }
            }
        }
        // Poll silence every 0.25s as backup
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .recording, self.autoStopAfterSilence else { return }
                if let start = self.silenceStart, Date().timeIntervalSince(start) >= self.autoStopSeconds {
                    self.stopAndTranscribe()
                }
            }
        }
    }

    private func handleVAD(level: Float) {
        if Double(level) < silenceThreshold {
            if silenceStart == nil { silenceStart = Date() }
            let pause = Date().timeIntervalSince(silenceStart!)
            // Short pause: commit the words dictated so far at the cursor (once per pause).
            if liveTyping, !pauseCommitted, pause >= pauseCommitSeconds {
                pauseCommitted = true
                commitLivePause()
            }
            // Long silence: end the recording entirely.
            if autoStopAfterSilence, pause >= autoStopSeconds {
                stopAndTranscribe()
            }
        } else {
            silenceStart = nil
            pauseCommitted = false
        }
    }

    /// Insert the not-yet-committed suffix of the live transcript at the cursor.
    /// Only ever inserts a suffix — if the recognizer revised text it already committed,
    /// we skip rather than retype (revision would need selection surgery in the target app).
    private func commitLivePause() {
        guard state == .recording, usesAppleSpeech, autoPaste else { return }
        let full = liveTranscript
        guard full.count > liveCommitted.count, full.hasPrefix(liveCommitted) else { return }
        let delta = String(full.dropFirst(liveCommitted.count))
        guard !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        liveCommitted = full
        TextInjector.inject(text: delta, target: targetApp)
    }
}
