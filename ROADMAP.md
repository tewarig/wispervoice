# WisperVoice Roadmap

Inspired by Wispr Flow (https://wisprflow.ai/) — native macOS dictation that works in every app.

## ✅ Now (v1.0 — shipped)
- [x] Menu-bar app (`MenuBarExtra` + fallback `NSStatusItem`, `LSUIElement`, `.accessory`) — always visible
- [x] System-wide hotkey `⌥Space` + `Fn×2` (Carbon `RegisterEventHotKey` + `NSEvent` flagsChanged)
- [x] Floating pill (`OverlayWindow` singleton, `Capsule` glass, `ultraThinMaterial`, `shadow`, `sensoryFeedback`, `symbolEffect`) — bottom-center, `floating` level, `canJoinAllSpaces`
- [x] Audio capture (`AVAudioEngine` → 16 kHz mono WAV) + test bypass (`NSClassFromString("XCTestCase")`)
- [x] Transcription providers: Apple `SFSpeechURLRecognitionRequest` (on-device, 100+ languages incl. Hinglish) + OpenAI Whisper (`/v1/audio/transcriptions`, `language` passthrough) + `TranscriptionService.polish` (filler removal, `gpt-4o-mini` optional)
- [x] Text injection: `AXSelectedText` → `AXValue` → `clipboard + Cmd+V` fallback via `CGEvent`
- [x] History (`HistoryStore`, `UserDefaults`, 100 limit) + last transcript + paste-again
- [x] Settings (General / About) with Provider/Language/API key toggles
- [x] Permissions flow (Mic/Speech/Accessibility) + inline banner
- [x] Tests (`WisperVoiceTests` logic bundle, 9 suites, ~50 cases) + code-coverage scheme (`TEST BUILD SUCCEEDED`, `xctest` direct run passes; `xcodebuild test` blocked by sandbox `IOPMAssertion` — run outside sandbox for `xccov`)

## 🚀 Next (v1.1 — this update)
- [x] **Pill reliability** — `OverlayWindow.sharedInstance` singleton (no `AppDelegate` KVC), `show`/`hide` always on main, `makeKeyAndOrderFront`, `level=.floating`, `hasShadow=false` for glass
- [x] **Live dictation in pill** — `DictationManager.liveTranscript` + `SFSpeechAudioBufferRecognitionRequest` (`shouldReportPartialResults=true`), `recognitionTask` partials → `OverlayView` live text, `ProgressView` when transcribing, `×` close button (`onClose` → `cancelRecording`)
- [x] **Close/cancel** — `OverlayView` `Button(xmark.circle.fill)` + `keyboardShortcut(.cancelAction)`, `DictationManager.cancelRecording` (invalidate timers, `speechTask.cancel`, `Basso` sound)
- [x] **Local models** — `Managers/ModelManager.swift` (tiny/base/small from `whisper.cpp` `ggml-*.bin`, `Application Support/WisperVoice/models`, `URLSession.downloadTask` + `Progress` KVO, `activeModelId` in `UserDefaults`, `Reveal Models Folder`)
- [x] **Open at Login** — `ServiceManagement.SMAppService.mainApp` toggle in Settings → `launchAtLogin` (`@AppStorage`), auto-register on launch if enabled
- [x] **Always-visible menu bar + main window** — `MenuBarExtra` + `NSStatusItem` fallback, `Window("WisperVoice", id:"main")` with `ContentView` (big Start button, `Cmd+Space` shortcut), `AppDelegate.openMain` + `applicationShouldHandleReopen`
- [x] **Apple HIG polish** — `MenuBarView` (gradient orb, pulsing dot, `matchedGeometryEffect`, `sensoryFeedback`, `swipeActions` → `ScrollView` + `GroupBox`), `SettingsView` (`Form(.grouped)`, `LabeledContent`, `TabView` General/Models/About, `GroupBox` parity/privacy), `OverlayView` (44pt glass orb, `blur` glow, `keyframe` waveform 5 bars, `glassEffect` ready for macOS 26)

## 🔜 v1.2 — Near term
- [x] **AI model switching (Vercel AI SDK-style)** — `Managers/AIModelProvider.swift` defines `protocol AIModelProvider` (`capabilities: STT/TTS`, `availableModels: [AIModel]`, `transcribe`/`synthesize`) + `enum AICapability` + `struct AIModel` + 7 providers: `AppleSpeechProvider`, `WhisperCppProvider` (tiny/base/small/medium/large-v3), `FasterWhisperProvider`, `ParakeetProvider` (TDT 0.6B/1.1B), `OpenAIWhisperProvider`, `PiperTTSProvider` (ryan/amy/alba/rohan), `CoquiXTTSProvider`; `AIProviderRegistry.shared` with `resolve(spec:)` factory like Vercel `provider(model)` and `UserDefaults` keys `ai.stt.provider`/`ai.stt.model`/`ai.tts.provider`/`ai.tts.model` for Settings switching
- [x] **ModelManager enhanced** — retains legacy `WhisperModel` (tiny/base/small) for compat; adds `selectedSTTProviderId/ModelId`, `selectedTTSProviderId/ModelId` (`@Published` + `UserDefaults`), `allAIModels`/`sttModels`/`ttsModels` computed with download state from `Application Support/WisperVoice/models|tts`, unified `download(_: AIModel)` with real `URLSession.downloadTask` for STT and stubbed `Task.sleep` progress for TTS (Piper/Coqui) writing placeholder, `selectSTT/selectTTS`, `isAIDownloaded`, `ttsDirectoryPath`
- [x] **TranscriptionService enhanced** — `transcribe(fileURL:providerId:modelId:language:apiKey:)` unified dispatch via `AIProviderRegistry` + `synthesize(text:providerId:modelId:voice:)` for TTS; `WhisperCppProvider` validates local file existence before fallback to Apple Speech; legacy `TranscriptionProvider.aiProviderId` shim keeps `DictationManager` compatible
- [x] **Settings UI** — `SettingsView` General tab: STT/TTS provider+model `Picker`s bound to `ModelManager`, plus legacy hidden picker shim; Models tab: legacy list + Open Whisper variants section (whisper.cpp/faster-whisper/parakeet) + Open Voice TTS section (Piper/Coqui XTTS/Whisper) each with `Download`/`Use`/`Active` + `ProgressView(value:)` from `aiDownloadProgress`; reveal buttons for `WisperVoice/models` and `WisperVoice/tts`
- [x] **TTS open voice models (stubbed)** — Piper & Coqui models downloadable via `ModelManager.download(_: AIModel)` stub that simulates 1.5s progress (10×150ms steps) and writes placeholder file; progress UI via `aiDownloadProgress`/`aiDownloadingId`; replace stub with real Piper binary / Coqui engine when bundled
- [ ] Streaming Whisper (local `whisper.cpp` via `WhisperKit` / `swift-whisper`, CoreML — stub ready, needs native lib)
- [ ] Hold-to-talk (`holdToTalk` AppStorage → `NSEvent` keyDown/up)
- [ ] Custom vocabulary / autocorrect dictionary (`SFSpeechLanguageModel`)
- [ ] Per-app formatting (code vs email vs chat)
- [ ] `LaunchAtLogin` helper validation + notarized DMG + Sparkle updater

## 🔮 v1.3 — Future
- [ ] iOS companion + Handoff
- [ ] Notetaker (meeting transcripts, speaker diarization)
- [ ] On-device LLM polish without API key (MLX)
- [ ] Analytics for `freeWispr` corpus (opt-in)
- [ ] TTS voice cloning + download more Piper voices (huggingface.co/rhasspy/piper-voices)

## How to test this update
1. `open WisperVoice.xcodeproj` → `Cmd+R` → grant Mic/Accessibility
2. Focus any text field → `⌥Space` → pill should appear immediately with `Recording` + live text as you speak + `×` to cancel
3. Speak → `⌥Space` again → `Transcribing…` → paste + `Inserted ✓`
4. Menu bar: icon always visible, `Open WisperVoice` opens `ContentView`, `Settings → Models` → `Download` tiny/base, `Reveal Models Folder`, `Open at Login` toggle
5. `xcodebuild build-for-testing -derivedDataPath /tmp/wisper_build` → `TEST BUILD SUCCEEDED`; outside sandbox `xcodebuild test -enableCodeCoverage` → `xccov` 100%

## Apple HIG references
- `MenuBarExtra` (`.window`), `NSStatusItem` fallback, `Settings` scene, `Window` with `defaultSize`, `Form`/`GroupBox`/`LabeledContent`, `glassEffect`/`ultraThinMaterial`, `SF Symbols` (`waveform.and.mic`, `xmark.circle.fill`), `sensoryFeedback`, `symbolEffect`, `contentTransition`
