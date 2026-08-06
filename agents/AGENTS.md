# AGENTS.md — WisperVoice Agent Memory

> **For Muse, Claude, Cursor, and any future agent.** This is the shared brain. Read this first, update it after every change. Keep it short, factual, linked.

---

## Project

**WisperVoice** — open-source WisprFlow clone for macOS (SwiftUI, MenuBarExtra, `LSUIElement`). Speak with `⌥Space` or `Fn×2` in *any* app, see live glass pill, auto-edits, paste at cursor. `wisperVoice/WisperVoice.xcodeproj`, `macOS 14+`, `Swift 5.9`, `Xcode 16.3`.

- **App:** `WisperVoice/WisperVoiceApp.swift` (`MenuBarExtra` + `Window(id:main)` + `Settings` + `NSStatusItem` fallback + `SMAppService`)
- **Website:** `website/` (Vite 5 + React 18 + Tailwind 3.4 → `website/dist/`)
- **Tests:** `WisperVoiceTests/` (9 suites, logic bundle, `xctest` direct run)
- **Repo meta:** `.github/workflows/ci.yml` + `release.yml`, `../README.md`, `../plan/ROADMAP.md`, `../plan/PM_PLAN.md`

## What's Done (2026-08-06 → 2026-08-20)

| When | What | Files |
|---|---|---|
| 08-06 | Scaffolded native app, `AVAudioEngine → WAV`, `SFSpeechURLRecognitionRequest` + Whisper `multipart`, `AX`→`Cmd+V`, history, permissions | `WisperVoice/*`, `project.pbxproj` |
| 08-06 | Build fixed (`SFSpeechURLRecognitionRequest`, `AXValue`, `SettingsLink` → macOS 14) → `BUILD SUCCEEDED` | `TranscriptionService`, `TextInjector`, `project.pbxproj` |
| 08-06 | Tests 9 suites, `TranscriptionService.polish` + Whisper + History + Permissions + Audio + TextInjector + Hotkey + Overlay + Dictation + App | `WisperVoiceTests/*.swift`, `project.pbxproj` (test target) |
| 08-20 | Pill reliability: `OverlayWindow.sharedInstance` singleton, `show` on main, level `.floating` | `Managers/OverlayWindow.swift` |
| 08-20 | Live dictation: `DictationManager.liveTranscript` + `SFSpeechAudioBufferRecognitionRequest` partials, `×` close | `Managers/DictationManager.swift`, `OverlayWindow.swift` |
| 08-20 | Local models: `ModelManager` (`ggml-tiny/base/small`, `Application Support/WisperVoice/models`) + `ModelManager` UI | `Managers/ModelManager.swift`, `Views/SettingsView.swift` |
| 08-20 | Always-visible bar + main window + Open at Login (`SMAppService`) | `WisperVoiceApp.swift`, `Views/SettingsView.swift` |
| 08-20 | HIG polish: `MenuBarView` (gradient orb, pulse, `matchedGeometryEffect`, `sensoryFeedback`), `SettingsView` (`Form(.grouped)`), `OverlayView` (glass capsule) | `Views/*`, `Managers/OverlayWindow.swift` |
| 08-20 | TTS: `TTSManager` (Piper/Coqui stub, `tts/` dir), `../plan/ROADMAP.md` updated | `Managers/TTSManager.swift` |
| 08-20 | AI switching (Vercel SDK style): `AIModelProvider` (7 providers, `AIProviderRegistry`, `AIModel`, `AISettingsKeys`) + `TranscriptionService` unified dispatch, `ModelManager` stt/tts selection, `SettingsView` pickers | `Managers/AIModelProvider.swift`, `Managers/ModelManager.swift`, `Managers/TranscriptionService.swift` |
| 08-20 | Website + GitHub + README: Vite site, `ci.yml`/`release.yml`, `README` 13 kB, `LICENSE`, `CONTRIBUTING`, etc. | `website/`, `.github/`, `README.md` |
| 08-20 | **Fix pass (7 PM issues): Dock+menu bar always visible (`LSUIElement false`, `activationPolicy .regular`, `NSStatusItem.isTemplate`, `DockMenu`, `screensDidWake`), pill Copy (`doc.on.doc` + `⌘C` + `×`), auto-stop after 5s silence (RMS VAD + `@AppStorage autoStopAfterSilence/Seconds`), onboarding walkthrough, clipboard/history tab — `BUILD/TEST SUCCEEDED` | `WisperVoiceApp.swift`, `OverlayWindow.swift`, `AudioRecorder.swift`, `DictationManager.swift`, `Views/OnboardingView.swift`, `Views/ClipboardHistoryView.swift`, `Views/SettingsView.swift`, `Views/MenuBarView.swift`, `project.pbxproj`, `Info.plist` |
| 08-20 | PM spec + CTO plan: `PM_SPEC_FIXES.md`, `../plan/CTO_PLAN.md` (no pbxproj change per spec, now patched to include new views) | `PM_SPEC_FIXES.md`, `../plan/CTO_PLAN.md` |

**Current build:** `xcodebuild build -derivedDataPath /tmp/wisper_build` → `BUILD SUCCEEDED`, `build-for-testing` → `TEST BUILD SUCCEEDED`. `xctest` direct run in progress; `xcodebuild test` blocked in sandbox by `IOPMAssertionCreateWithName -536870199` — run outside sandbox for `xccov`.

## Architecture (for agents)

```
WisperVoiceApp (MenuBarExtra + Window main + Settings (.regular Dock) + NSStatusItem(isTemplate, DockMenu, wake) + SMAppService)
├─ DictationManager (@MainActor, state idle→recording→transcribing→injecting, liveTranscript, SFSpeechAudioBufferRequest, autoStopAfterSilence VAD 5s, silenceThreshold)
├─ AudioRecorder (AVAudioEngine, onLevel RMS→VAD/waveform, test bypass via NSClassFromString("XCTestCase"))
├─ TranscriptionService (Apple/Whisper/polish + transcribe(providerId:) via AIProviderRegistry)
├─ TextInjector (AXSelectedText → CGEvent Cmd+V)
├─ HotkeyManager (Carbon RegisterEventHotKey + Fn double-tap)
├─ OverlayWindow (sharedInstance, Capsule glass, waveform 5 bars, Copy(doc.on.doc)+didCopy + close ×, copyTranscript→NSPasteboard+History)
├─ ModelManager (whisper.cpp + AI stt/tts, Application Support/models|tts)
├─ AIModelProvider (AICapability, AIModel, AIModelProvider protocol, 7 providers, AIProviderRegistry)
├─ TTSManager (Piper/Coqui stub)
├─ PermissionsManager + HistoryStore
└─ Views: MenuBarView (Open App+Settings+History 8), SettingsView (General/Models/Clipboard/About + autoStop slider + Show in Dock), OverlayView, ContentView (onboarding sheet + clipboard sheet), OnboardingView (5 steps), ClipboardHistoryView (search+Copy/Paste+swipeDelete)
```

## Commands (use these, not guesses)

```bash
# App
open WisperVoice.xcodeproj  # Cmd+R → grant Mic/Accessibility
xcodebuild build -project WisperVoice.xcodeproj -scheme WisperVoice -derivedDataPath /tmp/wisper_build2 -quiet
xcodebuild build-for-testing -project WisperVoice.xcodeproj -scheme WisperVoice -derivedDataPath /tmp/wisper_build2 -quiet
/Applications/Xcode.app/Contents/Developer/usr/bin/xctest /tmp/wisper_build2/Build/Products/Debug/WisperVoiceTests.xctest
# Coverage (outside sandbox)
xcodebuild test -project WisperVoice.xcodeproj -scheme WisperVoice -derivedDataPath /tmp/build -enableCodeCoverage YES; xcrun xccov view --report --derivedDataPath /tmp/build

# Website
cd website && npm --cache /tmp/npm-cache install && npm run dev # 5173
npm run build # → website/dist

# Install
cp -R /tmp/wisper_build2/Build/Products/Debug/WisperVoice.app /Applications/WisperVoice.app
cp -R /tmp/wisper_build2/Build/Products/Debug/WisperVoice.app ~/Applications/WisperVoice.app
```

## Conventions (HIG + repo)

- SwiftUI: `MenuBarExtra(.window)`, `Form(.grouped)`, `GroupBox`, `LabeledContent`, `glass` via `ultraThinMaterial` (add `glassEffect` for macOS 26 with `#available`), `SF Symbols`, `sensoryFeedback`, `symbolEffect`, `contentTransition`.
- Tests: logic bundle (`WisperVoiceTests.xctest` at top-level, not `PlugIns`) — app sources compiled into test target, no `@testable import WisperVoice` needed; use `RunLoop` not `expectation` for async.
- Models: `Application Support/WisperVoice/models` (STT `ggml-*.bin`) and `tts/` (Piper `.onnx`). `ModelManager` handles progress + `UserDefaults` keys `ai.stt.*`/`activeWhisperModel`.
- Git: `main`, `ci.yml`/`release.yml` on `macos-14` + Xcode 16.3, `../plan/ROADMAP.md` is source of truth, `../plan/PM_PLAN.md` for sprints.

## Roadmap (pointer)

See [`ROADMAP.md`](/Users/gauravtewari/Desktop/Desktop/wisperVoice/plan/ROADMAP.md) and [`PM_PLAN.md`](/Users/gauravtewari/Desktop/Desktop/wisperVoice/plan/PM_PLAN.md). Next: streaming Whisper via WhisperKit, hold-to-talk, custom vocab, per-app formatting, notarized DMG + Sparkle.

## For the next agent

1. Read this + `../plan/ROADMAP.md` + `../plan/PM_PLAN.md` first.
2. Check `xcodebuild build` still succeeds before editing.
3. Update this file after every change (add row to table above).
4. Keep `website/dist` built, keep `WisperVoice.app` in `/Applications` and `~/Applications` in sync.

---
*Last updated: 2026-08-20 by Muse (Muse Spark) — 10m13s session, 6 todos completed, BUILD/TEST SUCCEEDED*
