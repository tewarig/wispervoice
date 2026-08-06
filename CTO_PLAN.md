# WisperVoice — CTO Plan (7 Fixes)

**Owner:** CTO / Architect  
**App:** WisperVoice — SwiftUI macOS 14+ (Xcode 16+, Swift 5.9+) at `WisperVoice/`  
**Date:** 2026-08-06  
**Constraint:** Do **not** modify `WisperVoice.xcodeproj/project.pbxproj` in this phase. All new files are added on disk + documented; project membership is a one-time Xcode step (listed per fix).  
**Sync target:** Repo root = `/Users/gauravtewari/Desktop/Desktop/wisperVoice` (no `/Users/gauravtewari/Desktop/wisperVoice`). Canonical copy of this doc: `/tmp/cto_plan.md` ↔ `CTO_PLAN.md` (identical).

---

## 0. Current baseline (read before changing)

- **App entry:** `WisperVoice/WisperVoiceApp.swift` — `@main struct WisperVoiceApp: App` + `AppDelegate` (statusItem fallback, `NSApp.setActivationPolicy(.accessory)`, `OverlayWindow.sharedInstance`).
- **Menu bar:** `MenuBarExtra(.window)` with `Label("WisperVoice", systemImage: iconName)` + fallback `NSStatusItem.variableLength` in `AppDelegate`. Works but single `iconName = waveform` family; can disappear if MenuBarExtra coalesced or LSUIElement hiding Dock confuses users.
- **Overlay pill:** `WisperVoice/Managers/OverlayWindow.swift` — `NSWindow(level:.floating, canJoinAllSpaces, stationary, ignoresCycle)` + `NSHostingView<OverlayView>` capsule with live transcript, waveform 5 bars, `xmark.circle.fill` close → `DictationManager.cancelRecording()`.
- **Dictation/tap:** `DictationManager` owns `AudioRecorder`, `HotkeyManager`, `SFSpeechAudioBufferRecognitionRequest` with `shouldReportPartialResults=true`. Bug: `bufferRequest` created but never fed via `AVAudioEngine.installTap → append(_:)` — live text only works from file-based fallback today. Level meter is `Float.random`.
- **Audio:** `Managers/AudioRecorder.swift` — `AVAudioEngine` → 16 kHz mono WAV via `installTap(bufferSize:4096)` → `AVAudioFile`; test bypass via `XCTestConfigurationFilePath`/`NSClassFromString("XCTestCase")`.
- **Settings:** `Views/SettingsView.swift` — `TabView` General/Models/About, 580×460, `ServiceManagement.SMAppService` launchAtLogin toggle. Scene: `Settings { SettingsView() }`.
- **History:** `Managers/HistoryStore.swift` — `UserDefaults(JSON)`, 100 items, `@Published items`; MenuBar shows 8.
- **Plists/entitlements:** `WisperVoice/Info.plist` has `LSUIElement=true`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSAppleEventsUsageDescription`. `WisperVoice.entitlements` grants `audio-input` + `microphone`. `project.pbxproj` sets `INFOPLIST_FILE=WisperVoice/Info.plist`, `INFOPLIST_KEY_LSUIElement=YES`, deployment target 14.0.
- **Project groups:** `Managers/` (Dictation/Permissions/Audio/Transcribe/TextInject/Hotkey/Overlay/TTS/AIModel/History/Model) + `Views/` (MenuBar/Settings) + `Resources/Assets.xcassets`. Tests: `WisperVoiceTests/` 9 suites.

---

## 1. Menu-bar top-nav icon always visible

**Problem:** `MenuBarExtra` alone can be hidden by Control Center coalescing or by `LSUIElement` edge cases; users report "icon disappears" especially on macOS 14 notch/bartender setups. Existing `NSStatusItem` fallback helps but is not kept in sync with state.

**Decision:**

- Keep **both** `MenuBarExtra` and `NSStatusItem` (dual guarantee). Treat `MenuBarExtra` as canonical popover (`.window` style for HIG) and `NSStatusItem` as *always-visible fallback that never auto-hides*. Sync them.
- `WisperVoiceApp.swift: AppDelegate.statusItem` — retain, don't recreate; update `button.image` + `menu` on every `dictation.state` change via Combine.
- `WisperVoiceApp.swift: iconName` — extend with tint/state badge (recording red). Use `NSImage(systemSymbolName:..., variableValue: level)` for audio-responsive fill.
- Add `NSMenu` fallback for when MenuBarExtra popover can't show (headless run, limited menu bar space): items Open WisperVoice / Start|Stop / Settings / Quit with same actions.

**Files:**

- `WisperVoice/WisperVoiceApp.swift` — add `cancellables: Set<AnyCancellable>`, subscribe `dictationManager.$state` in `applicationDidFinishLaunching`, call `syncStatusItem(state:level:)`. Make `statusItem.button.menu` the fallback menu; `button.action` stays `#selector(openMain)` for click, right-click shows menu. Ensure `statusItem.isVisible = true` and `autosaveName` set.
- `WisperVoice/Info.plist` — **no change yet** (LSUIElement decision deferred to §3; menu bar works in both modes).
- No new file.

**macOS APIs:** `MenuBarExtra(.window)`, `NSStatusBar.system.statusItem(withLength:)`, `NSStatusItem.button`, `NSMenu`, `Combine` (`@Published DictationState`).

**Risks & mitigations:**

- Duplicate icons if both show: Intentional; fallback icon uses same symbol so user sees one icon (system deduplicates per process in `.accessory` mode). If macOS shows two, set fallback `statusItem.length = NSStatusItem.variableLength` and hide MenuBarExtra label on demand via feature flag.
- Memory leak `NSEvent` monitors / Carbon hotkey refs — reuse existing `HotkeyManager` teardown.
- State sync on background thread: All `NSStatusItem` updates on `DispatchQueue.main`.

**Testing:** Launch with `LSUIElement=true/false` both; assert `NSApp.windows` + `NSStatusBar.system.statusItem` exist; snapshot `MenuBarView` header; manual: open Control Center edit → confirm icon persists; kill Bartender/HiddenBar → still visible.

---

## 2. Pill with Copy + live text

**Problem:** `OverlayView` shows `liveTranscript` but has no Copy button; live text is not truly live because `AudioRecorder` tap never feeds `SFSpeechAudioBufferRecognitionRequest`. Level meter is random.

**Decision:**

- Make pill the canonical live surface: left orb + title, center live text (truncated, `lineLimit(1)`), right actions: **Copy** + **×**.
- Wire real audio → live transcription: extend `AudioRecorder` to expose `onBuffer: (AVAudioPCMBuffer)->Void` and `currentLevel: Float` (RMS). `DictationManager.startLiveTranscription()` installs *its own* tap or subscribes to recorder's buffer to call `bufferRequest.append(buffer)`. When `SFSpeechRecognizer` not available, degrade gracefully (pill still shows "Listening…" + waveform).
- Add Copy: `NSPasteboard.general.setString(lastText, forType:.string)` + `NSSound("Glass")` + transient "Copied!" label; same action used by MenuBar's Copy.

**Files:**

- `WisperVoice/Managers/OverlayWindow.swift` — add `onCopy: (() -> Void)?` to `OverlayWindow` + `OverlayView`. In `OverlayView` body, `HStack(spacing:8)` with `Button("Copy")` (`.bordered`, `.controlSize(.small)`) visible when `!transcript.isEmpty`. Existing × stays. Add `NSPasteboard` helper. Update `show(state:level:transcript:onCopy:onClose:)` to pass copy closure.
- `WisperVoice/Managers/AudioRecorder.swift` — add `var onBuffer: ((AVAudioPCMBuffer)->Void)?` and `var levelHandler: ((Float)->Void)?`. In `installTap`, compute RMS: `pow = 20*log10(rms)` normalized 0..1; call `levelHandler`. Forward `buffer` to `onBuffer`. Provide `removeTap` symmetry. Keep test bypass (return empty file + don't install tap).
- `WisperVoice/Managers/DictationManager.swift` — in `startLiveTranscription()`, after creating `bufferRequest`, set `recorder.onBuffer = { [weak self] buf in self?.bufferRequest?.append(buf) }`, `recorder.levelHandler = { [weak self] lvl in self?.audioLevel = lvl; self?.updateOverlay() }`. Replace `startLevelMetering()` random timer with real level callback (keep timer as fallback if `levelHandler` not firing). Add `func copyLive()`/`copyLast()` used by both pill and menu. Set `OverlayWindow.sharedInstance.onCopy` → copy. Call `bufferRequest?.endAudio()` in `stopAndTranscribe()` before file dispatch. Fix `showOverlay` to compute `transcript = liveTranscript.isEmpty ? "Listening… press again to stop" : liveTranscript` and always `orderFrontRegardless`.

**macOS APIs:** `AVAudioEngine.inputNode.installTap(onBus:bufferSize:format:)`, `AVAudioPCMBuffer.floatChannelData`, `SFSpeechAudioBufferRecognitionRequest.append(_:)`, `shouldReportPartialResults`, `requiresOnDeviceRecognition`, `SFSpeechRecognizer.recognitionTask(with:)`, `NSPasteboard`, `NSHostingView`.

**Risks:**

- Feeding buffer on audio thread must not hop to main before `append`; `append` is thread-safe but recognitionTask callback hops to main — verify not blocking audio render (bufferSize 1024–4096, 16 kHz).
- Whisper users: `provider != appleSpeech` should skip live buffer path (no Apple partials); pill shows waveform only. Document.
- Accessibility permission denied → copy fallback still works (clipboard).

**Testing:** Unit: mock `onBuffer` closure receives buffer; RMS calc `XCTAssertGreaterThan(level,0)` on synthetic sine buffer. UI: `OverlayWindowTests` assert Copy button exists when transcript non-empty; tap Copy → `NSPasteboard.string` equals live text. Manual: `⌥Space` → speak "draft a Slack message" → pill updates live word-by-word within 120ms.

---

## 3. Dock icon so app can be opened

**Problem:** `Info.plist LSUIElement=true` + `NSApp.setActivationPolicy(.accessory)` hides Dock, Cmd-Tab, and Force Quit entry — users can't find the app; double-clicking `WisperVoice.app` appears to do nothing.

**Decision (explicit):**

- **Default to `LSUIElement = false`** in `Info.plist` (or remove key and set `INFOPLIST_KEY_LSUIElement=NO` in project — but do not edit `project.pbxproj` now; edit plist so built product shows Dock). Provide *user preference* "Hide Dock icon (menu bar only)" that toggles at runtime.
- Runtime toggle pattern (Apple-approved): start as `.regular` (Dock visible) so first launch is discoverable; if user enables "Hide Dock icon" (`@AppStorage("hideDockIcon")`), call `NSApp.setActivationPolicy(.accessory)` and set `LSUIElement` soft-hide; else stay `.regular`. On toggle, call `NSApp.setActivationPolicy(_:)` immediately — no relaunch needed (Apple docs: accessory↔regular is live).
- `AppDelegate.applicationShouldHandleReopen` + `NSApp.activate(ignoringOtherApps:true)` already handles Dock click reopening main window — keep.

**Files:**

- `WisperVoice/Info.plist` — flip `LSUIElement` to `<false/>` (or delete key). This is the only plist edit; keep other keys.
- `WisperVoice/WisperVoiceApp.swift` — in `AppDelegate.applicationDidFinishLaunching`, replace hard `setActivationPolicy(.accessory)` with:

  ```swift
  let hideDock = UserDefaults.standard.bool(forKey: "hideDockIcon")
  NSApp.setActivationPolicy(hideDock ? .accessory : .regular)
  ```

  Observe `UserDefaults.didChangeNotification` or `@AppStorage` publisher to flip policy on toggle. Keep `statusItem` creation regardless. Update `openMain()` to `NSApp.setActivationPolicy(.regular)` briefly if hidden, then `makeKeyAndOrderFront`.

- `WisperVoice/Views/SettingsView.swift` — add Section in General tab: `Toggle("Hide Dock icon (menu bar only)", isOn: $hideDockIcon)` with help text "Requires menu bar icon — unchecking shows Dock + Cmd-Tab". Persist `@AppStorage("hideDockIcon")`.

**macOS APIs:** `LSUIElement` / `LSBackgroundOnly`, `NSApplication.setActivationPolicy(_:)`, `NSApplication.ActivationPolicy.{regular, accessory, prohibited}`, `UserDefaults`, `@AppStorage`, `applicationShouldHandleReopen`.

**Alternatives considered & rejected:**

- Keep `LSUIElement=true` + `NSWorkspace` Dock tile hack — fragile, rejected.
- `LSUIElement` toggling via `defaults write` at runtime — requires relaunch, rejected for UX.

**Risks:**

- First-run Dock bounce: users accustomed to LSUIElement may see Dock icon and complain — mitigate with onboarding explaining toggle (§6) and defaulting new installs to `hideDockIcon=false` for discoverability.
- App Store review: `LSUIElement` change doesn't affect entitlements; `accessory` still valid for `SMAppService`.
- Test sandbox: `setActivationPolicy` fails in unit tests (no NSApp) — guard with `if NSApp != nil`.

**Testing:** Build and `plutil -p WisperVoice.app/Contents/Info.plist | grep LSUI` shows false. Launch cold → Dock shows WisperVoice; menu bar also shows; click Dock → `Window("WisperVoice", id:"main")` key. Toggle Settings hideDock → Dock disappears within one runloop, menu bar stays; relaunch preserves choice. Assert `applicationShouldHandleReopen` reopens window.

---

## 4. Settings openable

**Problem:** With `.accessory` policy, `SettingsLink` and `Settings { ... }` can fail to key the window (no app activation). Users report Cmd+, does nothing. `AppDelegate.openMain` fallback `showSettingsWindow:` selector is misspelled/hashed and unreliable.

**Decision:**

- Make Settings *always* openable via three paths: `SettingsLink`, MenuBar footer button, and menu fallback. All must call `NSApp.activate(ignoringOtherApps:true)` before opening and ensure activation policy is `.regular` transiently.
- Centralize `openSettings()` in `AppDelegate`: `NSApp.setActivationPolicy(.regular)` (if hidden), `NSApp.sendAction(Selector(("showSettingsWindow:")), to:nil, from:nil)` or SwiftUI `openSettings` environment action via `@Environment(\.openSettings)`. For SwiftUI Settings scene, use `openSettings()` from `MenuBarView` footer + `ContentView`.
- Add explicit `Window("Settings", id:"settings")` alternative if `Settings` scene proves unreliable under `.accessory` (keep both; Window is always openable via `openMain` pattern). Prefer fixing `Settings` over duplicating, but keep Window as escape hatch gated by `if #available(macOS 14, *)`.

**Files:**

- `WisperVoice/WisperVoiceApp.swift` — add `func openSettingsWindow()` to `AppDelegate` (activate + `NSApp.sendAction`), inject into environment via `\.appDelegate`. Update `ContentView` body to `@Environment(\.openSettings) var openSettings` with fallback button `Button("Open Settings…") { NSApp.sendAction(...) }`.
- `WisperVoice/Views/MenuBarView.swift` — replace `SettingsLink { Label("Settings", ...) }` with `Button { NSApp.activate(...); NSApp.sendAction(Selector(("showSettingsWindow:")), to:nil, from:nil) }` or keep `SettingsLink` but wrap in `NSApp.activate` on appear. Add `.keyboardShortcut(",", modifiers:.command)` to footer Settings button.
- `WisperVoice/Views/SettingsView.swift` — ensure `.frame(width:580,height:460)` stable; add `onAppear { NSApp.activate(...) }` if needed.

**macOS APIs:** `SwiftUI.Settings` scene, `@Environment(\.openSettings)`, `SettingsLink`, `NSApplication.sendAction(_:to:from:)`, `NSApplication.activate(ignoringOtherApps:)`, `NSWindow.makeKeyAndOrderFront`.

**Risks:**

- Selector `showSettingsWindow:` vs `showPreferencesWindow:` confusion — test both; SwiftUI generates `showSettingsWindow:` on macOS 14+.
- Activation policy race: calling `setActivationPolicy` then immediately `sendAction` can drop; add `DispatchQueue.main.async { sendAction }` after policy change.

**Testing:** With Dock hidden and shown both: Cmd+, opens Settings; Menu bar Settings button opens; `open -a WisperVoice` then `osascript -e 'tell app "WisperVoice" to activate'` → Settings key. XCTest: verify `AppDelegate.openSettingsWindow` not crashing when `NSApp == nil` (guard).

---

## 5. Auto-stop after 5s silence (VAD, configurable)

**Problem:** User must press hotkey twice; long silence wastes battery and Whisper cost. Need voice-activity detection to auto-stop after configurable silence (default 5s).

**Decision:**

- Implement *energy-based VAD* in `AudioRecorder` (RMS threshold) + hangover timer in `DictationManager`. No third-party VAD lib yet; local threshold is sufficient for v1.1. Provide Settings slider 2–10s + threshold.
- Algorithm: `AudioRecorder` computes per-buffer RMS → dBFS. If `rmsDB < silenceThresholdDB` (default -38 dB, ~0.012 linear RMS) → silent frame. `DictationManager` maintains `lastVoiceDate` updated on voiced frames (level > threshold). A `Timer` (0.2s) checks `Date().timeIntervalSince(lastVoiceDate) >= silenceSeconds` while `state==.recording` and `continuousSinceVoiceStarted > 1.0s` guard (don't auto-stop in first second). On trigger, call `stopAndTranscribe()`. Add `NSSound("Pop")` on auto-stop distinction.
- Configurable via `@AppStorage("vadEnabled")`, `@AppStorage("vadSilenceSeconds")` (Double, 5.0), `@AppStorage("vadThresholdDB")` (Double, -38). Expose in SettingsView Behavior section as Toggle + Slider.

**Files:**

- `WisperVoice/Managers/AudioRecorder.swift` — add `@Published var vadSilenceThreshold: Float = 0.02` (linear) or dB path; add `func rms(for buffer: AVAudioPCMBuffer) -> Float` helper (compute `sqrt(meanSquare)`). Publish `isSilent: Bool` or just `levelHandler` already; let DictationManager decide.
- `WisperVoice/Managers/DictationManager.swift` — add `@AppStorage("vadEnabled") var vadEnabled = true`, `@AppStorage("vadSilenceSeconds") var vadSilenceSeconds: Double = 5`, `@AppStorage("vadThresholdDB") var vadThresholdDB: Double = -38`, `@Published var vadSilenceRemaining: Double?` for UI countdown. Add `vadTimer: Timer?`, `lastVoiceDate: Date?`. In `startRecording()`, set `lastVoiceDate = Date()`, start `vadTimer = Timer.scheduledTimer(withTimeInterval:0.2, repeats:true) { checkVAD() }`. In `levelHandler` update `lastVoiceDate` if `level > thresholdLinear`. In `checkVAD()`, if silence elapsed → `stopAndTranscribe()`. Invalidate on `stopAndTranscribe/cancelRecording`. Guard `state != .recording`.

- `WisperVoice/Views/SettingsView.swift` — add Behavior section rows: `Toggle("Auto-stop on silence", isOn: $dictation.vadEnabled)` + `Slider(value: $dictation.vadSilenceSeconds, in: 2...10, step: 1) { Text("\(Int(vadSilenceSeconds))s") }` + `Slider(value: $dictation.vadThresholdDB, in: -50...-20, step: 2)` with labels. Persist via `@AppStorage`.

**macOS APIs:** `AVAudioEngine` tap, `AVAudioPCMBuffer.floatChannelData`, `Timer`, `UserDefaults/@AppStorage`, `Combine`.

**Risks & mitigations:**

- False trigger on soft speech / far mic — default threshold conservative (-38dB ~ whisper); provide slider. Add hysteresis: require 3 consecutive silent buffers before counting.
- Whisper `auto` language may need longer pause for Hinglish — recommend 5s default covers.
- Power: 0.2s timer negligible; don't poll at 8ms.
- Test bypass: VAD disabled in XCTest (`XCTestConfigurationFilePath` check) to avoid flake.

**Testing:** Unit: synthetic buffer with silence → `lastVoiceDate` not updated → timer fires → `XCTestExpectation` that `stopAndTranscribe` called. Param: `vadSilenceSeconds=2` in test speeds up. Manual: speak then stay silent 5s → auto-stops, pill shows Transcribing; toggle off → does not auto-stop; slider 2s → stops at 2s.

---

## 6. First-run dashboard walkthrough

**Problem:** No onboarding; users don't know `⌥Space` vs `Fn×2`, permissions flow, or Dock toggle.

**Decision:**

- Add `Views/OnboardingView.swift` — 4-page `TabView(.page)` walkthrough shown once on first launch (`@AppStorage("hasCompletedOnboarding") == false`). Trigger from `ContentView.onAppear` or `AppDelegate.applicationDidFinishLaunching`. Can be re-opened via Settings About → "Show Walkthrough" + MenuBar footer.
- Pages: (1) Welcome — hero orb + "WisperVoice works in any app" (2) Permissions — Mic/Speech/Accessibility with action buttons + inline granted checks via `PermissionsManager` (3) Try it — press `⌥Space`, live pill demo (mock transcript) + "Try dictating now" button that calls `dictation.startRecording()` (4) Finish — Dock toggle, Launch at Login, "Open Settings", "Start Dictating" CTA.
- Store `hasCompletedOnboarding = true` on "Get Started" + "Skip". Also set `UserDefaults.standard.set(true, forKey: "hasSeenOnboarding_v1")` versioned so future onboarding revisions can re-show.
- Presentation: `Window("Welcome to WisperVoice", id:"onboarding")` sized 640×480, or sheet over `ContentView` via `.sheet(isPresented: $showOnboarding)`. Prefer `Window` so it works when main window closed; use `.windowResizability(.contentSize)`.

**Files (new):**

- `WisperVoice/Views/OnboardingView.swift` — new SwiftUI view with `@AppStorage("hasCompletedOnboarding")`, `@EnvironmentObject` perms/dictation, `@Environment(\.dismiss)`. Pages via `enum OnboardingPage`. Include `PermissionsManager` bindings for live check. No new entitlements.

- Edits:
  - `WisperVoice/WisperVoiceApp.swift` — add `Window("Welcome", id:"onboarding") { OnboardingView() ... }` gated by `if !hasCompletedOnboarding` or show via `openWindow(id:"onboarding")` from AppDelegate. In `applicationDidFinishLaunching`, if `!hasCompletedOnboarding`, dispatch `openWindow`.
  - `WisperVoice/Views/SettingsView.swift` — add About tab button `Button("Show Walkthrough Again") { UserDefaults.standard.set(false, forKey:"hasCompletedOnboarding"); NSApp.sendAction(...) }`.

**macOS APIs:** `TabView` paged, `Window(id:)`, `@AppStorage`, `openWindow` environment, `PermissionsManager` (AVFoundation/Speech/AXIsProcessTrusted).

**Risks:**

- Showing onboarding as `Window` under `.accessory` policy may not activate — same fix as §4: `NSApp.activate(ignoringOtherApps:true)` before `openWindow`.
- Don't block returning users — check `hasCompletedOnboarding` early, no animation on skip.
- Localization: strings are English only for now; note for future.

**Testing:** Fresh `defaults delete com.wispervoice.app hasCompletedOnboarding` → launch → onboarding appears, 4 pages swipeable, Permissions buttons trigger system prompts, Finish → flag set. Relaunch → not shown. Settings "Show Walkthrough" reopens. Snapshot tests for each page.

---

## 7. Clipboard / history view

**Problem:** History exists in `HistoryStore` + MenuBar 8-item list, but no dedicated searchable clipboard view; users want to copy/paste old transcripts without hunting MenuBar popover.

**Decision:**

- Add `Views/ClipboardHistoryView.swift` (aka `HistoryView`) — dedicated view with searchable, time-sorted list, Copy / Paste Again / Delete per item, Clear All, and live `NSPasteboard` sync.
- Architecture: reuse `HistoryStore.shared` (already `ObservableObject` + JSON). Extend `HistoryItem` with `id`, `text`, `date`, `provider`; add `searchText` filtering + `filteredItems` computed. Add `NSPasteboard` monitoring: optional `Timer` every 1s polling `NSPasteboard.general.changeCount` if user enables "Monitor clipboard" toggle — when external copy detected, offer to import (guard against loops by checking `lastTranscript` equality).
- UI: `NavigationSplitView` or simple `VStack` with `SearchField`, `List { ForEach(filtered) { row } }` with `swipeActions` delete, contextMenu Copy/Delete, double-click to inject. Add keyboard shortcuts: `⌘C` copy selected, `↩` paste again. Add empty state "No history yet — dictate to see transcripts".
- Entry points: (a) MenuBar footer `Button("Clipboard History…")` that opens `Window("Clipboard History", id:"clipboard")`, (b) Settings tab "Clipboard", (c) Dock right-click menu.

**Files (new):**

- `WisperVoice/Views/ClipboardHistoryView.swift` — new file, ~180 LOC, imports SwiftUI/AppKit. Uses `@StateObject var history = HistoryStore.shared`, `@State private var searchText = ""`, `@State private var selectedId: UUID?`, `@EnvironmentObject var dictation` for paste.

- Edits:
  - `WisperVoice/Managers/HistoryStore.swift` — add `func remove(_ item: HistoryItem)`, `func item(matching id: UUID) -> HistoryItem?`, `var filtered(search:)`. Optionally add `maxItems` as `@AppStorage("historyMaxItems")` configurable (100 default). Add `func copyToClipboard(_ text: String)` helper.
  - `WisperVoice/Views/MenuBarView.swift` — in `historySection` footer add `Button("Open Clipboard History…") { NSApp.activate(...); openWindow(id:"clipboard") }`. Keep inline 8-item preview for quick access.
  - `WisperVoice/WisperVoiceApp.swift` — add `Window("Clipboard History", id:"clipboard") { ClipboardHistoryView().environmentObject(...) } .windowResizability(.contentSize).defaultSize(width:620,height:460)`; also add menu bar command `CommandGroup` for History.

**macOS APIs:** `HistoryStore` (UserDefaults JSON), `NSPasteboard`, `Searchable` (`searchable(text:)`), `List`, `swipeActions`, `contextMenu`, `NSApplication.openWindow`.

**Risks:**

- Large history (100 items) with `JSONEncoder` on main thread — keep `didSet { save() }` but debounce or move to background queue; 100 items trivial.
- Pasteboard polling at 1s is cheap but must be disabled by default to avoid privacy concern — default off, user opts in.
- Text injection from history row must respect `AXIsProcessTrusted` fallback path already in `TextInjector`.

**Testing:** Unit: `HistoryStoreTests` add/search/filter/remove. UI: `ClipboardHistoryView` render with 0/1/100 items, search filters correctly, Copy → pasteboard equals text, Paste Again → `TextInjector.inject` called (mock). Manual: dictate 3 times → history shows newest first; search "Slack" filters; delete one persists after relaunch.

---

## Cross-cutting

### File map (final: which files change for which fix)

| Fix | `Info.plist` | `WisperVoiceApp.swift` | `OverlayWindow.swift` | `DictationManager.swift` | `AudioRecorder.swift` | `SettingsView.swift` | New file |
|---|---|---|---|---|---|---|---|
| 1 Menu bar | — | ✦ sync statusItem | — | — | — | — | — |
| 2 Pill Copy+live | — | — | ✦ Copy btn + onCopy | ✦ buffer feed + level | ✦ RMS + onBuffer | — | — |
| 3 Dock icon | ✦ LSUIElement false | ✦ policy toggle | — | — | — | ✦ hideDock toggle | — |
| 4 Settings openable | — | ✦ openSettings() | — | — | — | ✦ activate | — |
| 5 VAD 5s | — | — | — | ✦ timer + threshold | ✦ RMS helper | ✦ sliders | — |
| 6 Onboarding | — | ✦ onboarding Window | — | — | — | ✦ re-show btn | `OnboardingView.swift` ✦ |
| 7 Clipboard | — | ✦ clipboard Window | — | — | — | — | `ClipboardHistoryView.swift` ✦ |
| HistoryStore ext | — | — | — | — | — | — | — (+ `HistoryStore.swift` ✦ filter/remove) |

✦ = edit or create. No `project.pbxproj` edit in this doc phase; adding `OnboardingView.swift` + `ClipboardHistoryView.swift` requires one-time Xcode: select Project → WisperVoice target → Build Phases → Sources → + → Add Files.

### macOS API inventory

- `LSUIElement`, `NSApplication.ActivationPolicy`, `SMAppService`, `UserDefaults/@AppStorage`, `MenuBarExtra`, `NSStatusItem/NSStatusBar`, `NSWindow(level:.floating, collectionBehavior)`, `NSHostingView`, `AVAudioEngine`, `AVAudioFile`, `AVAudioPCMBuffer`, `SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`, `SFSpeechURLRecognitionRequest`, `AXIsProcessTrusted`, `CGEvent`, `NSPasteboard`, `ServiceManagement` (already in use), plus new `Timer`, `Combine` subscriptions, `searchable`.

### Risks (top 5) + mitigations

1. **LSUIElement flip surprises existing users / CI** — Keep `hideDockIcon` default `false` for new installs; document migration note; CI `plutil` check asserts expected value per branch.
2. **Live buffer feed regression breaks dictation** — Gate behind `provider == appleSpeech` + `SFSpeechRecognizer.isAvailable`; fallback to file transcription; add feature flag `enableLiveBuffer` default true for kill switch.
3. **VAD false stops** — Conservative 5s + 3-frame hysteresis + disable in first second; make slider discoverable; default `vadEnabled=true` but one-click off.
4. **Accessory activation losing key window** — Always `NSApp.activate(ignoringOtherApps:true)` before `orderFrontRegardless` / `openSettings` / `openWindow`; add `DispatchQueue.main.async` after policy flip.
5. **Project not updated for new files** — Archive step `xcodebuild build` will fail until files added to project; CTO gate: "Files on disk ≠ built until PBX edit" — note explicitly in PR description; provide `project.pbxproj` patch snippet as appendix (not applied).

### Testing plan (per-fix, no Xcode edit needed to run existing)

- **Unit (XCTest, logic bundle):** Extend `AudioRecorderTests` (RMS, onBuffer), `DictationManagerTests` (VAD timer, state transitions), `HistoryStoreTests` (filter/remove, 100 cap), `OverlayWindowTests` (Copy button visibility, onCopy), `WisperVoiceAppTests` (activationPolicy toggle, openSettings not crashing).
- **Build:** `xcodebuild -project WisperVoice.xcodeproj -scheme WisperVoice -configuration Debug build -derivedDataPath /tmp/wisper_build` → `BUILD SUCCEEDED` (existing path); outside sandbox `xcodebuild test -enableCodeCoverage` → `xccov` check.
- **Manual matrix (5 min):** Cold launch (onboarding shows) → grant perms → `⌥Space` pill shows live → speak 3s → silent 5s auto-stop → pill Copy → Menu bar icon persists after Control Center edit → Settings via Cmd+, / MenuBar / Dock → Clipboard History search/copy → toggle Hide Dock → relaunch → Dock state preserved.
- **Entitlements sanity:** `codesign -d --entitlements - /tmp/wisper_build/Build/Products/Debug/WisperVoice.app` still shows `audio-input`.

### Rollout

1. Land this doc (no code). 2. PR #1: §1–§4 (minimal, high-visibility fixes). 3. PR #2: §5 VAD + §2 live buffer wiring (audio-touching, needs QA). 4. PR #3: §6 onboarding + §7 clipboard windows (new UI, snapshot tests). Each PR includes the corresponding `project.pbxproj` delta for its new files only.

### Appendix — project.pbxproj patch snippet (do not apply now)

When ready, add two files to `GR_VIEWS` and `PBXSourcesBuildPhase`:

```
FR_ONBOARD = { isa=PBXFileReference; lastKnownFileType=sourcecode.swift; path=OnboardingView.swift; sourceTree="<group>"; };
FR_CLIP = { isa=PBXFileReference; lastKnownFileType=sourcecode.swift; path=ClipboardHistoryView.swift; sourceTree="<group>"; };
// add to GR_VIEWS children, PH_SOURCES files, BF_ buildFiles
```

Keep `INFOPLIST_FILE = WisperVoice/Info.plist` and flip plist key directly; `INFOPLIST_KEY_LSUIElement` build setting can stay `NO` after plist edit or be updated to match plist to avoid warning.

---

*Reviewed files: `WisperVoiceApp.swift`, `Info.plist`, `WisperVoice.entitlements`, `Managers/*` (AudioRecorder, DictationManager, OverlayWindow, HistoryStore, PermissionsManager, HotkeyManager, TextInjector, TranscriptionService, ModelManager), `Views/*` (MenuBarView, SettingsView), `project.pbxproj`, `README.md`, `ROADMAP.md`.*
