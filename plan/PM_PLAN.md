# WisperVoice — PM Plan

> Clone of Wispr Flow for macOS. Native menu-bar dictation that works in every app. This plan decomposes `ROADMAP.md` into executable workstreams for frontend / backend / AI agents.

---

## 1. Vision

**Problem:** Typing is the bottleneck for knowledge workers. Existing dictation (macOS built-in, browser-only) is slow, modal, or requires context-switching. Wispr Flow proved users want `hold → speak → text appears` everywhere.

**Vision:** WisperVoice is the fastest, most private voice-to-text on Mac — **< 800ms end-to-end**, offline-first, works in *any* text field via Accessibility injection. Feels native to macOS (HIG, glass, `MenuBarExtra`, `LSUIElement`).

**North-star metric:** % of sessions where transcription is inserted within 1s of release (target: 95%).
**Supporting KPIs:** WER (Hinglish `en-IN`), cancellation rate, cold-start time, App Store / DMG crash-free %, model-download success rate, DAU/WAU retention after week 1.

**Principles:** Offline-first → Privacy by default → Native HIG polish → No Dock clutter → Extensible AI provider layer (Vercel AI SDK-style).

---

## 2. Personas

| Persona | Goal | Pain | Must-have |
|---|---|---|---|
| **A. Founder / PM (Arjun, 31)** | Draft emails/Slack/PRDs 3× faster, Hinglish | Switching apps to dictate; cloud latency | `⌥Space` anywhere, live pill, filler removal, Hinglish |
| **B. Engineer (Maya, 27)** | Dictate code comments, standup notes, chat | Built-in dictation inserts slowly, no per-app formatting | Per-app formatting (code vs chat), history paste-again |
| **C. Creator / Student (Leo, 22)** | Transcribe meetings, TTS playback | Meeting notes scattered; voice cloning expensive | Notetaker + diarization, local STT/TTS, offline |
| **D. Privacy user (Priya, 34)** | No audio leaves device | Cloud APIs log audio | On-device Whisper.cpp / Parakeet + MLX polish |

---

## 3. User Stories

**v1.0 / v1.1 — Shipped (reference)**
- As Arjun I press `⌥Space` in any app and see a pill instantly so I know recording started.
- As Arjun I see live partial transcript + waveform while speaking, and `×` / `Esc` to cancel.
- As any user I speak and text is injected at cursor via AX → clipboard fallback without losing clipboard history.
- As any user I open Menu Bar → see last transcript, Copy / Paste Again, 8-item history (`HistoryStore` cap 100).
- As Priya I download `ggml-tiny/base` in Settings → Models and select it for offline STT.
- As any user I toggle Open at Login (`SMAppService.mainApp`) and app re-registers on launch.

**v1.2 — Near term (active backlog)**
- As Priya I get streaming local transcription (< 300ms partials) via WhisperKit/CoreML while still speaking.
- As Arjun I hold `⌥Space` to talk and release to send (hold-to-talk).
- As Maya my domain words ("Kubernetes", "WisperVoice") are recognized via custom vocabulary (`SFSpeechLanguageModel`).
- As Maya code pasted in Xcode is formatted as code, while Slack keeps casual formatting (per-app formatting).
- As any user the DMG is notarized and auto-updates via Sparkle.

**v1.3 — Future**
- As Leo I hand off dictation from iPhone to Mac and review meeting transcripts with speaker diarization.
- As Priya I get LLM polish without an API key via on-device MLX.
- As Leo I clone my voice (Piper/Coqui) and hear TTS playback of any transcript.

---

## 4. Workstream Decomposition (from ROADMAP.md)

### Frontend (SwiftUI + AppKit shell)
| Area | Owners | Key files |
|---|---|---|
| Pill / Overlay | Frontend | `Managers/OverlayWindow.swift`, `Views/OverlayView` (inside `MenuBarView.swift`/`WisperVoiceApp.swift`) |
| Menu bar + Main window | Frontend | `WisperVoiceApp.swift` (`MenuBarExtra` + `NSStatusItem` fallback), `Views/MenuBarView.swift`, `Views/SettingsView.swift`, `Views/ContentView` |
| Settings UI | Frontend | `Views/SettingsView.swift` (Form `.grouped`, Pickers, `ProgressView`, reveal-folder) |
| Hotkey UX | Frontend+Backend | `Managers/HotkeyManager.swift` (Carbon + `NSEvent.flagsChanged`) |
| HIG polish | Frontend | `sensoryFeedback`, `matchedGeometryEffect`, `glassEffect`, SF Symbols |
| History UI | Frontend | `Views/MenuBarView.swift` (ScrollView + swipeActions), `Managers/HistoryStore.swift` |

### Backend (macOS system integration)
| Area | Owners | Key files |
|---|---|---|
| Audio capture | Backend | `Managers/AudioRecorder.swift` (`AVAudioEngine` 16 kHz mono WAV, XCTest bypass) |
| Text injection | Backend | `Managers/TextInjector.swift` (AX → clipboard + `CGEvent` Cmd+V) |
| Permissions + Launch | Backend | `Managers/PermissionsManager.swift`, `ServiceManagement.SMAppService`, `WisperVoiceApp.swift` `AppDelegate` |
| History persistence | Backend | `Managers/HistoryStore.swift` (`UserDefaults` JSON, 100 cap) |
| Hold-to-talk events | Backend | `Managers/HotkeyManager.swift` `holdToTalk` + `NSEvent` keyDown/up state machine |
| Per-app formatting | Backend | New `Managers/FormattingManager.swift` (bundleId → profile) |
| Release / Signing | Backend | `.github/workflows/*`, `Info.plist`, `WisperVoice.entitlements` |

### AI / Model
| Area | Owners | Key files |
|---|---|---|
| Provider abstraction | AI | `Managers/AIModelProvider.swift` (`protocol AIModelProvider`, `AIProviderRegistry.resolve(spec:)`, 7 providers) |
| Model lifecycle | AI+Backend | `Managers/ModelManager.swift` (download, progress KVO, `Application Support/WisperVoice/{models,tts}`, `UserDefaults` `ai.stt.*`/`ai.tts.*`) |
| Transcription | AI | `Managers/TranscriptionService.swift` (`transcribe` + `synthesize`, `polish`, legacy `aiProviderId` shim) |
| Local STT engines | AI | `WhisperCppProvider`, `FasterWhisperProvider`, `ParakeetProvider` (TDT 0.6B/1.1B), streaming `WhisperKit`/`swift-whisper` |
| TTS | AI | `PiperTTSProvider` (ryan/amy/alba/rohan), `CoquiXTTSProvider`, `Managers/TTSManager.swift` |
| Vocabulary / LLM | AI | `SFSpeechLanguageModel`, MLX on-device polish (`gpt-4o-mini` fallback) |
| Benchmarking | AI | WER harness for `en-IN` Hinglish, `WisperVoiceTests/TranscriptionServiceTests.swift` |

---

## 5. Prioritized Backlog — MoSCoW

Derived strictly from ROADMAP.md `v1.2` remaining + `v1.3` future.

| ID | Item (ROADMAP ref) | Workstream | MoSCoW |
|---|---|---|---|
| F1 | Hold-to-talk (`holdToTalk` AppStorage, keyDown/up) | BE + FE | **Must** |
| F2 | Custom vocabulary / `SFSpeechLanguageModel` | AI | **Must** |
| F3 | Streaming Whisper local (`WhisperKit`/`swift-whisper`, CoreML) | AI + BE | **Must** |
| F4 | LaunchAtLogin helper validation + notarized DMG + Sparkle | BE | **Must** |
| F5 | Per-app formatting (code vs email vs chat) | BE + FE | **Should** |
| F6 | TTS voice cloning + more Piper voices (huggingface.co/rhasspy/piper-voices) | AI + FE | **Should** |
| F7 | On-device LLM polish without API key (MLX) — replace `gpt-4o-mini` | AI | **Should** |
| F8 | iOS companion + Handoff | FE + BE | **Could** |
| F9 | Notetaker (meeting transcripts, speaker diarization) | AI + BE + FE | **Could** |
| F10 | Analytics for `freeWispr` corpus (opt-in) | BE + AI | **Could** |
| F11 | Real TTS downloads (replace stub `Task.sleep` in `ModelManager.download(_: AIModel)`) | AI + BE | **Must** *(debt from v1.2)* |
| F12 | Unified error / retry UI for model downloads + transcription failures | FE | **Should** |

**Debt note:** `ModelManager.download(_: AIModel)` TTS path is stubbed (10×150ms `Task.sleep` + placeholder file). Must be replaced with real Piper/Coqui fetch before v1.2 GA.

---

## 6. RICE Scoring

`RICE = (Reach × Impact × Confidence) / Effort` — Reach = % weekly active users affected, Impact 0.25–3, Confidence 0.5–1, Effort = person-weeks.

| ID | Item | Reach | Impact | Confidence | Effort | RICE | Rank |
|---|---|---|---|---|---|---|---|
| F3 | Streaming Whisper local | 80 | 3 | 0.6 | 5 | **28.8** | 1 |
| F1 | Hold-to-talk | 70 | 2 | 0.9 | 1.5 | **84.0** | 1* |
| F2 | Custom vocabulary | 45 | 2 | 0.8 | 2 | **36.0** | 2 |
| F4 | Notarized DMG + Sparkle | 100 | 2 | 0.9 | 3 | **60.0** | 2* |
| F5 | Per-app formatting | 40 | 2 | 0.7 | 3 | **18.7** | 5 |
| F11 | Real TTS downloads | 30 | 1.5 | 0.9 | 2 | **20.3** | 4 |
| F7 | MLX on-device polish | 50 | 2 | 0.5 | 5 | **10.0** | 7 |
| F6 | TTS voice cloning | 25 | 1.5 | 0.6 | 4 | **5.6** | 8 |
| F9 | Notetaker + diarization | 30 | 3 | 0.4 | 8 | **4.5** | 9 |
| F8 | iOS companion + Handoff | 20 | 2 | 0.6 | 6 | **4.0** | 10 |
| F10 | Opt-in analytics | 15 | 1 | 0.8 | 2 | **6.0** | 8 |
| F12 | Error/retry UI | 60 | 1 | 0.9 | 1 | **54.0** | 3 |

*Sorted by value/effort: ship F1, F12, F4, F2 early for momentum; F3 is biggest strategic bet and runs in parallel.*

**Priority order for sprints:** F1 → F12 → F2 → F11 → F4 → F3 → F5 → F7 → F10 → F6 → F9 → F8

---

## 7. Milestones

| Milestone | Scope | Exit criteria | Target |
|---|---|---|---|
| **M1 — v1.2 Beta** | F1, F2, F11, F12 + polish | Hold-to-talk works, vocab adds 15% WER win on `en-IN`, real Piper download succeeds, error toasts covered by tests | End of Sprint 2 |
| **M2 — v1.2 GA** | F3, F4, F5 | Streaming partials < 300ms, `LaunchAtLogin` validated, per-app formatting behind feature flag, DMG notarized + Sparkle feeding | End of Sprint 4 |
| **M3 — v1.3 Alpha** | F7, F10 | MLX polish parity with `gpt-4o-mini` on offline, opt-in analytics pipeline | End of Sprint 6 |
| **M4 — v1.3 Beta** | F6, F9, F8 | Voice cloning demo, 30-min meeting diarization (≤3 speakers), Handoff prototype | End of Sprint 8 |

---

## 8. Sprint Plan — 2-Week Sprints

All sprints: planning Mon, daily async standup, review + retro Fri week 2. Capacity assumed 2 agents (FE + BE/AI), ~8–10 story points / sprint / agent.

### Sprint 1 — Foundation & Quick Wins (Weeks 1–2)
**Goal:** Unblock v1.2 Musts, close UI debt.
- **FE:** F12 error/retry UI (download + transcription failures → banner + Retry), F1 UI (hold indicator in `OverlayView`, Settings toggle `holdToTalk`).
- **BE:** F1 state machine (`HotkeyManager` keyDown/up, debounce, `DictationManager` start/cancel lifecycle), add `holdToTalk` `@AppStorage` + tests in `HotkeyManagerTests`.
- **AI:** F11 spec real TTS fetch (Piper manifest from `huggingface.co/rhasspy/piper-voices`, checksum), stub replacement plan.
- **Joint:** Define `FormattingManager` interface (F5) and feature flag `perAppFormattingEnabled`.
- **Done:** `HotkeyManagerTests` + `OverlayWindowTests` pass; manual QA: hold `⌥Space` in TextEdit/Slack.

### Sprint 2 — Vocabulary + Real TTS (Weeks 3–4) → **M1**
**Goal:** Ship M1 beta.
- **AI (lead):** F2 `SFSpeechLanguageModel` custom vocab store (`UserDefaults` + file), Settings → Vocabulary editor, benchmark `en-IN` WER.
- **AI+BE:** F11 implement real `ModelManager.download(_: AIModel)` for Piper/Coqui (streaming `URLSession`, checksum, resume), remove `Task.sleep` stub.
- **BE:** Persist vocab + selected TTS voice (`ai.tts.*`), `TTSManager` playback queue.
- **FE:** Models tab per-voice Download/Use/Active reflects real progress; Vocabulary editor in Settings General.
- **Done:** M1 beta DMG; WER regression test in `TranscriptionServiceTests`.

### Sprint 3 — Streaming Spike + Signing (Weeks 5–6)
**Goal:** De-risk F3, land F4 infra.
- **AI (lead):** F3 spike — integrate `WhisperKit` (fallback `swift-whisper`) behind `AIProviderRegistry`, `SFSpeechAudioBufferRecognitionRequest` → local streaming path, CoreML model caching.
- **BE:** F4 Notarization pipeline (Developer ID, `notarytool`, `stapler`), Sparkle appcast generation in `release.yml`.
- **FE:** Streaming partials wired to `DictationManager.liveTranscript` → `OverlayView` with throttled updates (≤10 Hz) to avoid jank.
- **Done:** Streaming flag `streamingLocalEnabled` default OFF, benchmark latency on M1/M2; CI produces notarized artifact on tag.

### Sprint 4 — Streaming GA + Per-App Formatting (Weeks 7–8) → **M2**
**Goal:** M2 GA.
- **AI+BE:** F3 GA — `WhisperCppProvider` streaming `transcribeChunk`, fallback to file-based, battery/thermal guard.
- **BE+FE:** F5 per-app formatting (detect `NSWorkspace.frontmostApplication.bundleIdentifier` → `FormattingManager` profile: `code` preserves case/punct, `chat` casual, `email` capitalized).
- **FE:** Per-app rules editor in Settings; pill shows streaming indicator.
- **Done:** M2 GA release candidate; full QA matrix (see §10).

### Sprint 5–6 — MLX + Analytics (Weeks 9–12) → **M3**
- **AI:** F7 MLX on-device polish (small LM, prompt parity with `gpt-4o-mini`, gated by `ai.polish.local` flag), benchmark quality vs cloud.
- **BE:** F10 opt-in analytics (event schema, on-device aggregation, no audio exfiltration, `UserDefaults` opt-in default OFF).
- **FE:** Settings → Privacy → Analytics opt-in, local-vs-cloud polish toggle.
- **Done:** M3 alpha, privacy review passes.

### Sprint 7–8 — Voice & Notetaker (Weeks 13–16) → **M4**
- **AI+FE:** F6 voice cloning (additional Piper voices browser, Coqui XTTS voice preview + download).
- **AI+BE+FE:** F9 Notetaker prototype (continuous capture, VAD, speaker diarization stub → local, export markdown).
- **BE+FE:** F8 Handoff spike (Universal Clipboard / `NSUbiquitousKeyValueStore` probe, iOS companion spec).
- **Done:** M4 beta, TestFlight for iOS if pursued.

> Backlog beyond Sprint 8 returns to ROADMAP `🔮 v1.3` ordering by next RICE re-score.

---

## 9. Task Assignment (Agents)

| Sprint | Frontend Agent | Backend Agent | AI Model Agent |
|---|---|---|---|
| S1 | Overlay hold indicator, Settings toggle, F12 banners (`MenuBarView`, `SettingsView`, `OverlayView`) | `HotkeyManager` hold state, `DictationManager` lifecycle, Tests | TTS manifest spec, `AIModelProvider` review |
| S2 | Vocabulary editor, Models tab real progress | `TTSManager` queue, persistence | `SFSpeechLanguageModel`, `ModelManager.download` real impl, WER harness |
| S3 | Streaming live-text throttling | Notarization + Sparkle (`release.yml`) | `WhisperKit` integration, CoreML cache |
| S4 | Per-app rules editor, streaming indicator | `FormattingManager` + bundleId detection | Streaming GA + thermal guard |
| S5–6 | Privacy/Analytics settings | Analytics pipeline, event schema | MLX polish |
| S7–8 | Voice browser, Notetaker UI | Handoff + continuous capture | Voice cloning, diarization |

**Cross-cutting ownership:** AI agent owns `Managers/AIModelProvider.swift`, `Managers/ModelManager.swift`, `Managers/TranscriptionService.swift`, `Managers/TTSManager.swift`. Backend owns `AudioRecorder`, `TextInjector`, `HotkeyManager`, `PermissionsManager`, `HistoryStore`. Frontend owns `Views/*`, `OverlayWindow`, `WisperVoiceApp.swift` scenes.

---

## 10. Collaboration — Branching, PR, Review

### Branching
- `main` is protected (requires PR, 1 approval, CI green). Never push directly.
- Branch naming: `feat/<id>-<slug>` (e.g. `feat/f1-hold-to-talk`), `fix/<slug>`, `ai/<slug>`, `chore/<slug>`.
- Agents branch from `main`, rebase before PR (`git fetch && git rebase origin/main`).
- Feature flags for risky work: `@AppStorage("feature.streamingLocalEnabled")`, `"feature.perAppFormattingEnabled"` — default OFF until M2/M3.

### PR Process
1. **Small PRs:** ≤ 300 lines, one MoSCoW item. Larger work split by workstream (FE/BE/AI) into stacked PRs.
2. **Template** (`.github/pull_request_template.md`): Summary, ROADMAP link, Screenshots/GIF for UI, Test plan, Risk, Flag.
3. **Checks (required):** `xcodebuild build-for-testing -derivedDataPath /tmp/wisper_build` (sandbox-safe path), `WisperVoiceTests` (9 suites), `swiftformat`/`swiftlint` if configured.
4. **Coverage:** `xcodebuild test -enableCodeCoverage` outside sandbox → `xccov` (keep 100% on changed files where feasible).
5. **PR assignment:** FE PRs → BE reviewer, BE PRs → AI reviewer, AI PRs → FE reviewer (round-robin; rotate to avoid silos).

### Review SLA & Definition of Done
- **SLA:** Review within 24h, 2nd ping after 48h. Blocked PRs flagged in standup.
- **DoD (all PRs):**
  - [ ] Tests added/updated (`WisperVoiceTests/*Tests.swift`) and passing
  - [ ] Manual QA in TextEdit + one Electron app (Slack) + one native (Xcode)
  - [ ] Permissions path tested (Mic/Speech/Accessibility denied → banner)
  - [ ] No `UserDefaults` key collision (prefix `ai.*`, `feature.*`)
  - [ ] Docs updated (`../README.md` / `ROADMAP.md` checkbox) if user-visible
  - [ ] No Xcode source formatting churn (only touched files)
- **AI PR extra:** WER/latency note + model size / download time.
- **Release PR:** Notarization log + Sparkle appcast diff attached.

### Communication
- **Single source of truth:** This `PM_PLAN.md` + `ROADMAP.md` + GitHub Issues (one per F-ID, labeled `workstream:fe|be|ai` + `MoSCoW:*` + `RICE`).
- **Standup (async):** Each agent posts Yesterday / Today / Blocker in the sprint issue.
- **Conflict resolution:** PM (this plan) is tiebreaker; escalate scope cuts to MoSCoW (drop Could before Should).

### Risks & Mitigations
| Risk | Mitigation |
|---|---|
| `whisper.cpp` native lib blocks streaming (F3) | Spike in S3, keep Apple `SFSpeechAudioBufferRecognitionRequest` as fallback, flag-gated |
| Sandbox blocks `xcodebuild test` (`IOPMAssertion`) | Use `-derivedDataPath /tmp/wisper_build` in CI; coverage run outside sandbox |
| TTS stub replaced incorrectly | Contract test: `ModelManager.download` writes real file + checksum; keep placeholder fallback |
| Hold-to-talk conflicts with `Fn×2` | State machine with 300ms debounce, Settings toggle, telemetry on cancel rate |
| Notarization secrets missing | Degrade to ad-hoc signed ZIP, warn in release notes; never block M1/M2 |
| Scope creep (v1.3) | MoSCoW + RICE re-score at M2; Could items stay flagged OFF |

---

## 11. Release Checklist (per milestone)
- [ ] ROADMAP checkboxes updated
- [ ] `xcodebuild build-for-testing` green + tests green
- [ ] DMG/ZIP attached to GitHub Release, notarized if secrets present
- [ ] Sparkle appcast updated (post-M2)
- [ ] README “How to test” steps verified on clean Mac
- [ ] Tag `vX.Y.Z` + release notes (user-facing + known issues)

---

*Plan version: 2026-08-06 · Owner: PM Agent · Next review: end of Sprint 2 (M1).*
