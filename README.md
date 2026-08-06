# WisperVoice — Wispr Flow for Mac (Open Source)

<p align="center">
  <img src="https://via.placeholder.com/720x120/0a0a0b/ffffff?text=●+Recording+—+live+%22draft+a+Slack+message…%22" alt="WisperVoice pill — Recording with live transcript" width="720" />
</p>

<p align="center">
  <a href="https://github.com/OWNER/REPO/actions/workflows/ci.yml"><img src="https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://github.com/OWNER/REPO/actions/workflows/release.yml"><img src="https://github.com/OWNER/REPO/actions/workflows/release.yml/badge.svg" alt="Release" /></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/SwiftUI-MenuBarExtra-purple" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/coverage-✓-brightgreen" alt="Coverage" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License" /></a>
  <a href="https://wisprflow.ai"><img src="https://img.shields.io/badge/inspired%20by-Wispr%20Flow-black" alt="Inspired by Wispr Flow" /></a>
</p>

<p align="center">
  <strong>Native macOS menu-bar dictation — hold <code>⌥Space</code> in any app, speak, and text appears at your cursor.</strong><br/>
  Offline Apple Speech, cloud Whisper, or local <code>ggml</code> models. Live pill overlay. Works in Slack, Notion, Xcode, Gmail — anywhere you can type.
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#how-it-works">How it works</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#settings">Settings</a> •
  <a href="#development">Development</a> •
  <a href="ROADMAP.md">Roadmap</a> •
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

> **Not affiliated with [Wispr Flow](https://wisprflow.ai/).** WisperVoice is an independent, MIT-licensed reference implementation inspired by Wispr Flow's UX. Wispr Flow is a trademark of Wispr AI.

---

## ✨ Features

| Wispr Flow | WisperVoice |
|---|---|
| System-wide hotkey (Fn) | **⌥Space** + **Fn×2** double-tap (Carbon `RegisterEventHotKey` + `NSEvent.flagsChanged`) |
| Floating pill overlay | `OverlayWindow` — floating `NSWindow` with `Capsule` glass, waveform, live transcript, `×` to cancel |
| Live dictation in pill | `DictationManager.liveTranscript` via `SFSpeechAudioBufferRecognitionRequest` (`shouldReportPartialResults`) |
| Auto-edits & cleanup | Local filler-word removal (`um`/`uh`/`like`) + optional `gpt-4o-mini` polish |
| 100+ languages, Hinglish | Apple Speech (100+ locales) + Whisper `language` passthrough; tested `en-IN` Hinglish |
| Works in every app | Accessibility `AXSelectedText` → `AXValue` → clipboard + `CGEvent` `Cmd+V` fallback |
| Menu bar tray + history | `MenuBarExtra(.window)` with last transcript, **Copy** / **Paste Again**, 8-item history |
| Local models | `ModelManager` — download `ggml-tiny` / `base` / `small` from `whisper.cpp` to `Application Support/WisperVoice/models` |
| Launch at login | `SMAppService.mainApp` toggle in Settings |
| No Dock icon | `LSUIElement` + `.accessory` activation policy |
| Always visible | `MenuBarExtra` + `NSStatusItem` fallback + main `Window("WisperVoice")` |

---

## 📦 Installation

### Download (recommended)

1. Go to [**Releases**](../../releases) → download `WisperVoice-<version>-macOS.zip` (or `.dmg` if available).
2. Unzip and move to Applications:

   ```bash
   unzip WisperVoice-*.zip
   mv WisperVoice.app /Applications/
   open /Applications/WisperVoice.app
   ```

3. Grant **Microphone**, **Speech Recognition**, and **Accessibility** when prompted (System Settings → Privacy & Security). The app shows an inline banner until Accessibility is granted (`AXIsProcessTrusted()` poll).

> **Gatekeeper on first launch:** Right-click → Open if macOS blocks the unsigned build. Tagged releases from CI are ad-hoc signed; enable real Developer ID signing and notarization by adding Apple secrets — see [`release.yml`](.github/workflows/release.yml) and [`SECURITY.md`](SECURITY.md).

### Homebrew (placeholder)

```bash
# Once a cask is published:
brew install --cask wispervoice
```

### Build from source

**Requirements:** macOS 14+, Xcode 16+, Swift 5.9+.

```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
open WisperVoice.xcodeproj   # Select "My Mac" → Cmd+R
```

CLI (sandbox-safe — Xcode GUI builds work without this):

```bash
xcodebuild -project WisperVoice.xcodeproj -scheme WisperVoice -configuration Debug \
  build -derivedDataPath /tmp/wisper_build
open /tmp/wisper_build/Build/Products/Debug/WisperVoice.app
# or, if you copied the built app to the repo root:
open WisperVoice.app
```

> The macOS sandbox on some machines blocks `~/Library/Developer/Xcode/DerivedData`. Use `-derivedDataPath /tmp/wisper_build` for CLI builds.

---

## 🚀 Usage

1. **Launch** — icon (`waveform`) appears in the menu bar. A main window also opens (big **Start** button, `⌘Space` shortcut).
2. **Focus any text field** — Slack, Notion, Xcode, Gmail, TextEdit, …
3. **Press `⌥Space`** or double-tap **Fn** → pill shows **● Recording** with live transcript and waveform.
4. **Speak naturally** — filler words (`um`, `uh`) are stripped locally.
5. **Press hotkey again** → **Transcribing…** → text is pasted at cursor. Pill shows **Inserted ✓**, then hides.
6. **Menu bar window** → **Copy** / **Paste Again** / click a history item to re-inject.

**Cancel:** click `×` on the pill or press `Esc` → `DictationManager.cancelRecording()` invalidates timers, cancels `SFSpeechRecognitionTask`, plays `Basso`.

**First launch:** approve **Microphone**, **Speech Recognition**, **Accessibility** (System Settings → Privacy & Security → Accessibility → WisperVoice).

---

## ⚙️ Settings (`⌘,`)

| Setting | Description |
|---|---|
| **Provider** | **Apple Speech** (default, free, on-device/cloud) or **OpenAI Whisper** (`/v1/audio/transcriptions`) |
| **Language** | `en-US`, `en-GB`, `hi-IN`, `en-IN` (Hinglish), `es-ES`, `fr-FR`, `de-DE`, `ja-JP`, `auto` — passed as Whisper `language` or `SFSpeech` locale |
| **OpenAI API Key** | Stored in `UserDefaults` (`openAIKey`), used for Whisper + optional LLM polish. Never logged. |
| **Auto-paste** | Toggle `TextInjector` injection |
| **AI polish** | When on + key set, sends cleaned text to `gpt-4o-mini` with a system prompt that preserves mixed-language (Hinglish) |
| **Models** | Download `ggml-tiny` / `base` / `small` via `ModelManager` (uses `URLSession.downloadTask` + `Progress` KVO); `Reveal Models Folder` opens `Application Support/WisperVoice/models` |
| **Launch at Login** | `SMAppService.mainApp` toggle (`@AppStorage launchAtLogin`), auto-registers on launch if enabled |

---

## 🧠 How it works

```
Mic → AVAudioEngine (16 kHz mono WAV in tmp/)
  → TranscriptionService
      ├─ Apple Speech: SFSpeechURLRecognitionRequest (file) + SFSpeechAudioBufferRecognitionRequest (live partials)
      └─ Whisper: POST /v1/audio/transcriptions (multipart, language passthrough)
  → polish(_:)  — regex filler removal, collapse spaces, capitalise, then optional gpt-4o-mini
  → TextInjector — AXSelectedText → AXValue → clipboard + CGEvent Cmd+V fallback
  → OverlayWindow (NSWindow .floating, canJoinAllSpaces, hasShadow=false) + SwiftUI OverlayView
  → HistoryStore (UserDefaults JSON, 100 items)
```

- **Audio:** `AudioRecorder` taps `AVAudioEngine`; in tests, hardware is bypassed via `NSClassFromString("XCTestCase")`.
- **Live transcript:** `DictationManager` starts a `SFSpeechAudioBufferRecognitionRequest` with `shouldReportPartialResults=true`; partials stream to `liveTranscript` → `OverlayView`.
- **Injection:** `TextInjector` prefers Accessibility; falls back to `NSPasteboard` + synthetic `CGEvent` keydown/up for `Cmd+V`.
- **Overlay:** `OverlayWindow.sharedInstance` singleton; `show`/`hide` always on main, `makeKeyAndOrderFront`, `level=.floating`.

---

## 🏗️ Architecture

```
WisperVoice/
  WisperVoiceApp.swift              # @main, MenuBarExtra, Window("main"), AppDelegate (.accessory)
  Managers/
    DictationManager.swift          # @MainActor state machine: idle → recording → transcribing → injecting
    AudioRecorder.swift             # AVAudioEngine → WAV
    TranscriptionService.swift      # Apple Speech + Whisper + polish() + llmPolish()
    TextInjector.swift              # AX + clipboard CGEvent
    HotkeyManager.swift             # Carbon RegisterEventHotKey + Fn double-tap
    OverlayWindow.swift             # NSWindow floating pill + SwiftUI OverlayView (Capsule glass, waveform, ×)
    PermissionsManager.swift        # Mic / Speech / AX (AXIsProcessTrusted)
    ModelManager.swift              # whisper.cpp ggml downloads + activeModelId
    HistoryStore.swift              # UserDefaults JSON, 100-item ring
  Views/
    MenuBarView.swift               # Tray window (gradient orb, pulsing dot, matchedGeometryEffect, swipeActions)
    SettingsView.swift              # TabView General/Models/About (Form(.grouped), LabeledContent)
  Resources/Assets.xcassets
  WisperVoice.entitlements          # audio-input
  Info.plist                        # NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
WisperVoiceTests/                   # XCTest logic bundle (9 suites, ~60 cases)
WisperVoice.xcodeproj/              # Xcode project, shared scheme (TestAction codeCoverageEnabled=YES)
.github/workflows/
  ci.yml                            # Build + test + coverage (macos-14)
  release.yml                       # Tag-triggered GitHub Release with .app zip + notarization placeholder
website/index.html                  # Landing page for GitHub Pages / Cloudflare Pages
```

Detailed product roadmap: [`ROADMAP.md`](ROADMAP.md).

---

## 🔐 Permissions

| Permission | Why | Prompt |
|---|---|---|
| `NSMicrophoneUsageDescription` | Capture audio for transcription | System mic dialog |
| `NSSpeechRecognitionUsageDescription` | Apple Speech recognition | System speech dialog |
| Accessibility (`AXIsProcessTrustedWithOptions`) | Paste at cursor in any app | System Settings → Privacy & Security → Accessibility |
| `com.apple.security.device.audio-input` | Entitlement for audio input | — |

---

## 🛠️ Development

### Prerequisites

- macOS 14+, Xcode 16+, Swift 5.9+
- Optional: `brew install swiftlint swiftformat xcpretty`

### Build & test

```bash
# Build
xcodebuild -project WisperVoice.xcodeproj -scheme WisperVoice -configuration Debug \
  build -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Test with coverage (mirrors CI)
xcodebuild test -project WisperVoice.xcodeproj -scheme WisperVoice \
  -destination 'platform=macOS' -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO

# Coverage report
xcrun xccov view --report TestResults.xcresult
xcrun xccov view --report --json TestResults.xcresult > coverage.json

# Fast logic-bundle run (no simulator, matches local sandbox workaround)
xcodebuild build-for-testing -project WisperVoice.xcodeproj -scheme WisperVoice -derivedDataPath /tmp/wisper_build
/Applications/Xcode.app/Contents/Developer/usr/bin/xctest /tmp/wisper_build/Build/Products/Debug/WisperVoiceTests.xctest
```

### Lint

```bash
swiftlint lint
swiftlint lint --reporter github-actions-logging
swiftformat --lint .
```

### Project conventions

- Swift API Design Guidelines; `async/await` + `@MainActor` for UI state.
- Keep managers testable; gate hardware with dependency injection where possible.
- Mark `// TODO:` with an issue link.

---

## 🤝 Contributing

We love contributions! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, branch/commit style (Conventional Commits), and PR checklist.

- Search [existing issues](../../issues) before opening a new one.
- Use the **Bug report** / **Feature request** issue templates.
- PRs must be green on CI (build + test + coverage) and include tests for new behavior.
- Be kind — see [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

Security reports: **do not open a public issue** — see [`SECURITY.md`](SECURITY.md) or use GitHub's private advisories.

---

## 🗺️ Roadmap

See [`ROADMAP.md`](ROADMAP.md) for shipped (v1.0/v1.1), near-term (v1.2: streaming Whisper via WhisperKit, hold-to-talk, custom vocabulary, per-app formatting, Sparkle updates), and future (v1.3: iOS companion, notetaker, on-device LLM polish).

---

## 📄 License

[MIT](LICENSE) — Copyright © 2026 WisperVoice Contributors. Not affiliated with Wispr AI.

---

## 🙏 Acknowledgements

- [Wispr Flow](https://wisprflow.ai/) for the product inspiration.
- Apple `Speech` framework, OpenAI Whisper, and `whisper.cpp` for transcription.
- The macOS accessibility and audio communities for `AX` / `CGEvent` / `AVAudioEngine` patterns.
