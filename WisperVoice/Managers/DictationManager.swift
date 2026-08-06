import Foundation
import SwiftUI
import AVFoundation
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
    @Published var state: DictationState = .idle
    @Published var lastTranscript: String = ""
    @Published var liveTranscript: String = ""
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0

    @AppStorage("provider") var providerRaw: String = TranscriptionProvider.appleSpeech.rawValue
    @AppStorage("openAIKey") var openAIKey: String = ""
    @AppStorage("languageCode") var languageCode: String = "en-US"
    @AppStorage("autoPaste") var autoPaste: Bool = true
    @AppStorage("llmPolish") var llmPolish: Bool = false
    @AppStorage("holdToTalk") var holdToTalk: Bool = false
    @AppStorage("autoStopAfterSilence") var autoStopAfterSilence: Bool = true
    @AppStorage("autoStopSeconds") var autoStopSeconds: Double = 5.0
    @AppStorage("silenceThreshold") var silenceThreshold: Double = 0.08

    var provider: TranscriptionProvider {
        get { TranscriptionProvider(rawValue: providerRaw) ?? .appleSpeech }
        set { providerRaw = newValue.rawValue }
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

    init() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in self?.toggleDictation() }
        }
        hotkeyManager.register()
        OverlayWindow.sharedInstance.onClose = { [weak self] in
            Task { @MainActor in self?.cancelRecording() }
        }
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
        liveTranscript = ""
        guard state == .idle else { return }
        do {
            recordingURL = try recorder.startRecording()
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
        speechTask?.cancel()
        audioLevel = 0
        recorder.onLevel = nil
        let url = recorder.stopRecording()
        recordingURL = url
        // Keep last live text as fallback if file transcription fails
        let fallbackLive = liveTranscript
        liveTranscript = ""
        guard let url else { state = .idle; hideOverlay(); return }

        state = .transcribing
        updateOverlay()

        Task {
            do {
                let raw: String
                // If we have live text and provider is Apple, reuse it for speed
                if !fallbackLive.isEmpty && provider == .appleSpeech {
                    raw = fallbackLive
                } else {
                    // Vercel AI SDK style: unified provider dispatch via ModelManager selection
                    let sttProvider = UserDefaults.standard.string(forKey: AISettingsKeys.sttProvider) ?? provider.aiProviderId
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
                if !lastTranscript.isEmpty { HistoryStore.shared.add(lastTranscript) }
                try? FileManager.default.removeItem(at: url)
                if autoPaste, !lastTranscript.isEmpty {
                    state = .injecting
                    updateOverlay()
                    try await Task.sleep(nanoseconds: 250_000_000)
                    TextInjector.inject(text: lastTranscript)
                    NSSound(named: "Glass")?.play()
                }
                state = .idle
                updateOverlay()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.hideOverlay() }
            } catch {
                // Fallback to live transcript on error
                if !fallbackLive.isEmpty {
                    lastTranscript = fallbackLive
                    HistoryStore.shared.add(fallbackLive)
                    if autoPaste { TextInjector.inject(text: fallbackLive) }
                } else {
                    errorMessage = error.localizedDescription
                }
                state = .idle
                updateOverlay()
                try? FileManager.default.removeItem(at: url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.hideOverlay() }
            }
        }
    }

    func cancelRecording() {
        levelTimer?.invalidate()
        silenceTimer?.invalidate()
        silenceStart = nil
        liveTask?.cancel()
        speechTask?.cancel()
        recorder.onLevel = nil
        recorder.cancelRecording()
        liveTranscript = ""
        state = .idle
        hideOverlay()
        NSSound(named: "Basso")?.play()
    }

    // MARK: - Live transcription (Apple Speech partials)
    private func startLiveTranscription() {
        guard provider == .appleSpeech else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)), recognizer.isAvailable else { return }
        if SFSpeechRecognizer.authorizationStatus() != .authorized { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.bufferRequest = request

        // Feed audio engine buffers if available — otherwise use timer to simulate live for demo
        // For real mic, AudioRecorder would expose tap; here we use a lightweight timer that updates liveTranscript with accumulating words from level
        liveTask = Task { @MainActor in
            // Hook into recorder's audio if possible later — for now poll and also listen to recognizer partials
            self.speechTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result = result {
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
        guard autoStopAfterSilence else { silenceStart = nil; return }
        if Double(level) < silenceThreshold {
            if silenceStart == nil { silenceStart = Date() }
            else if Date().timeIntervalSince(silenceStart!) >= autoStopSeconds {
                stopAndTranscribe()
            }
        } else {
            silenceStart = nil
        }
    }
}
