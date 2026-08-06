# WisperVoice — PM Spec Fixes (User-Reported 7 Issues)

> **Author:** PM · **Date:** 2026-08-06 · **Status:** Ready for CTO/dev pickup
> **Scope:** Fix 7 user-reported defects without modifying Xcode project structure (code-only). Source of truth: `WisperVoice/WisperVoiceApp.swift`, `OverlayWindow.swift`, `HotkeyManager.swift`, `DictationManager.swift`, `HistoryStore.swift`, `PermissionsManager.swift`, `Views/{MenuBarView,SettingsView}.swift`, `Info.plist` (`LSUIElement`).

---

## 0. Summary & Prioritization

| # | Issue (user wording) | Spec title | MoSCoW | Effort | Depends |
|---|---|---|---|---|---|
| 1 | App not appearing in top menu bar (where time is) | Reliable Menu Bar presence | **Must** | S | — |
| 4 | Nothing works to open app/settings | Guaranteed entry points to app & Settings | **Must** | S | #1, #3 |
| 3 | App should appear in Dock so can open and change shortcuts | Dock icon + proper activationPolicy toggle | **Must** | S | #4 |
| 2 | Pill should have Copy button | Copy button on pill/overlay | **Must** | XS | — |
| 7 | Clipboard/history where can see/copy/paste | Clipboard History panel | **Should** | M | #2 |
| 5 | Auto-input after 5s silence (configurable enable/disable) | Silence auto-commit (VAD, 5s, toggle) | **Should** | M | — |
| 6 | Dashboard walkthrough on first install | First-run onboarding walkthrough | **Should** | S | #4 |

**Ship order (sprint):** 1+4+3 together (single activation fix) → 2 → 7 → 5 → 6.

**Global AC for "done":** each fix verified on macOS 13/14/15, light+dark, notch/no-notch, multi-monitor, without requiring Xcode project changes.

---

## 1. Reliable Menu Bar Presence — top bar (where time is)

### User story
> As a user I see WisperVoice in the **right menu bar** (near the clock) at all times so I can click it to open the app/dashboard, even after reboot.

### Current state / root cause
- `WisperVoiceApp.swift` uses `MenuBarExtra { MenuBarView } .menuBarExtraStyle(.window)` with `.labelStyle(.iconOnly)` — correct but fragile.
- `Info.plist` has `LSUIElement = true` (agent app) → no Dock, relies entirely on MenuBarExtra.
- Pitfalls: `labelStyle(.iconOnly)` can render invisible if SF Symbol missing; `.window` style not available < macOS 13; no `NSStatusItem` fallback; icon color blends on dark menu bar.

### Acceptance criteria
- [ ] AC1.1: On launch (and on `NSWorkspace.didWakeNotification`) a WisperVoice icon is visible in the **system menu bar** within 1s, on every macOS 13 Ventura → 15 Sequoia.
- [ ] AC1.2: Icon is tappable: single-click opens `MenuBarView` popover/window (existing `.window` style); icon reflects `DictationState` (idle/waveform, recording/waveform.badge.mic, transcribing/waveform.badge.ellipsis, injecting/checkmark.circle) — already implemented in `WisperVoiceApp.iconName`.
- [ ] AC1.3: Resilience: if `MenuBarExtra` fails to attach (e.g., Bartender/Dozer hiding, or OS < 13), fallback `NSStatusItem` is created programmatically in `AppDelegate.applicationDidFinishLaunching` so icon still appears. Remove fallback on success to avoid duplicates.
- [ ] AC1.4: Icon uses template rendering + sufficient contrast; test on translucent menu bar and notch.
- [ ] AC1.5: No duplicate icons after sleep/wake, after Settings close, after `login` launch.

### Edge cases
- Menu bar crowded / Bartender hidden items → provide Diagnostics hint in `ContentView`/`SettingsView` ("If hidden, check Bartender / System Settings → Control Centre → Menu Bar").
- Multiple Spaces / external monitors → icon appears on primary screen's menu bar (system-owned, not per-space window).
- User revokes → re-grants permissions: icon must not disappear.

### Dev notes (actionable)
- Touch: `WisperVoiceApp.swift` (keep `MenuBarExtra`; add `NSStatusItem` fallback in `AppDelegate` if `NSStatusBar.system.statusItem` not present after 0.5s). Optional: `NSImage.isTemplate = true` for icon.
- Do NOT change `LSUIElement` solely for this — see #3 for coordinated fix.
- Test hook: `defaults write` not needed; manual QA + add `MenuBarPresenceTests` (XCTest: assert `NSStatusBar.system.items` or `MenuBarExtra` attached).

---

## 2. Pill — Copy Button

### User story
> As a user when the pill appears (recording / live transcript / result) I can copy its text with one click without opening the menu bar.

### Current state
- `OverlayView` (`OverlayWindow.swift:60`) shows icon/level/waveform/close `×` but **no Copy**. `MenuBarView.lastTranscriptCard` has Copy but pill does not.

### Acceptance criteria
- [ ] AC2.1: Pill (`OverlayView`) shows a **Copy** button whenever `transcript` / `liveTranscript` is non-empty (both `.recording` with partials and post-transcribe `.idle` result if pill persists). Button label: `Copy` + SF `doc.on.doc`, tooltip "Copy transcript (⌘C)".
- [ ] AC2.2: Click Copy → `NSPasteboard.general` set with transcript, show 1.5s confirmation (`checkmark` / "Copied" toast or button state change), add to `HistoryStore` if not already added. Do not dismiss pill on copy.
- [ ] AC2.3: Keyboard: `⌘C` when pill is key window also copies. `Esc`/`×` still cancels (existing `onClose`).
- [ ] AC2.4: Disabled state when transcript empty (button hidden or disabled, not crashing).
- [ ] AC2.5: VoiceOver: button has accessibility label "Copy transcript".

### Edge cases
- Empty / whitespace-only transcript → button disabled; no empty string written to pasteboard.
- Very long transcript (5k+ chars) → pasteboard handles, pill truncates with `lineLimit(2)` + tooltip shows full on hover; copy still copies full.
- Concurrent injection: copy + auto-paste should not race; copy uses `NSPasteboard.clearContents` + `setString`.

### Dev notes
- Touch: `OverlayWindow.swift: OverlayView` — add `Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(transcript, forType: .string); HistoryStore.shared.add(transcript) }`. Inject `NSPasteboard` via protocol for tests.
- Reuse existing `NSPasteboard` mock pattern from `TextInjectorTests` if present.

---

## 3. Appear in Dock (so user can open & change shortcuts)

### User story
> As a user I see WisperVoice in the **Dock** so I can click to bring the app forward, access Settings/shortcuts, and quit — like a normal Mac app.

### Current state
- `Info.plist` `LSUIElement = true` → `activationPolicy = .accessory` (no Dock, no Cmd+Tab, no Dock menu). This is intentional "no Dock clutter" per `PM_PLAN.md` principle, but directly conflicts with user expectation + blocks discoverability of Settings.

### Decision (PM + CTO must approve one)

**Recommended: Option A — Regular app with user toggle (default: show in Dock).**
- Change `LSUIElement` to `false` (or remove key) and set `NSApplication.shared.activationPolicy = .regular` on launch.
- Add `Settings → General → Show in Dock` (`@AppStorage("showInDock") Bool default true`) that toggles `.regular` ↔ `.accessory` at runtime (requires `NSApp.setActivationPolicy`). When hidden, menu bar remains; user can re-enable via menu bar → Settings.
- Alternative: leave `LSUIElement` false and manage visibility via `activationPolicy` only (no plist change needed if policy set early in `AppDelegate`).

**Rejected alternative:** keep `LSUIElement = true` with Dock workaround (e.g., `NSDockTile`) — not a real Dock icon; user explicitly asked for Dock.

### Acceptance criteria
- [ ] AC3.1: After install/launch, WisperVoice **appears in Dock** by default.
- [ ] AC3.2: Click Dock icon → app activates, `ContentView` / main `Window("WisperVoice", id:"main")` comes to front (`NSApp.activate(ignoringOtherApps:true)` + `openWindow(id:"main")`). If already front, no duplicate window.
- [ ] AC3.3: Dock menu (right-click) shows: Open WisperVoice, Settings…, Start/Stop Dictating, Quit.
- [ ] AC3.4: Settings toggle "Show in Dock" persists via `@AppStorage`; toggling applies immediately without restart. When OFF, Dock icon hides but menu bar icon stays (and menu bar offers way to re-enable).
- [ ] AC3.5: `Cmd+Tab` includes WisperVoice when Dock is shown; does not when hidden (matches policy).

### Edge cases
- User hides Dock, hides menu bar (via Bartender) simultaneously → at least one entry point must remain: show alert "Both hidden — press ⌥Space to open menu bar or relaunch from Finder/Spotlight".
- macOS Login Items: Dock visibility persists across reboot.
- App Store review: toggling `activationPolicy` is allowed; no private API.

### Dev notes
- Touch: `Info.plist` (LSUIElement → false/remove) + `WisperVoiceApp.swift` `AppDelegate.applicationDidFinishLaunching`: `NSApp.setActivationPolicy(.regular)`, observe `showInDock` changes. `SettingsView` toggle.
- Do NOT modify Xcode project file (`.pbxproj`) — plist + code only.

---

## 4. Nothing Works to Open App / Settings — guaranteed entry points

### User story
> As a user I can always open WisperVoice / Settings, regardless of menu bar / Dock / hotkey state.

### Current state
- Entry points exist but all fragile: `MenuBarExtra` (broken per #1), `Window("WisperVoice")` with no `openWindow` trigger except menu bar "Open WisperVoice", `SettingsLink` only inside `ContentView`, `HotkeyManager` (`⌥Space`, `Fn×2`) requires permissions and may fail silently. If menu bar invisible and Dock hidden, zero paths work.

### Acceptance criteria
- [ ] AC4.1: **At least 4 independent ways** to open Settings, each verified:
  1. Menu bar icon → "Open WisperVoice" / "Settings…" row in `MenuBarView`
  2. Dock icon click / Dock menu → Settings…
  3. Spotlight / Launchpad / Finder → launching `WisperVoice.app` brings existing instance forward (`applicationShouldHandleReopen` / `openWindow`)
  4. Global hotkey `⌥Space` / `Fn×2` → dictation toggle, and when held? Also `⌘,` when app is active opens Settings via `Settings` scene (`SettingsLink` + `openSettings` environment)
- [ ] AC4.2: `MenuBarView` footer always shows "Settings…", "Open WisperVoice", "Quit" rows (already in `footer` — ensure visible even when `dictation.state != .idle`).
- [ ] AC4.3: `applicationShouldHandleReopen(_:hasVisibleWindows:)` implemented → if no windows visible, open main window; if already visible, bring to front.
- [ ] AC4.4: Keyboard: `⌘,` opens Settings; `⌘Q` quits from any window.
- [ ] AC4.5: Failure telemetry: if `HotkeyManager.register()` fails (`RegisterEventHotKey != noErr`), show non-blocking banner in `MenuBarView` + `ContentView` with "Hotkey unavailable — open Settings to reassign".
- [ ] AC4.6: No dead-end: even if Accessibility/Microphone denied, app still launches and shows `PermissionsManager` banner with "Open System Settings" buttons.

### Edge cases
- App already running but all windows closed (`orderOut`) → Dock/Spotlight reopen must recreate.
- `LSUIElement` transition race: ensure `NSApp.activate` called after `setActivationPolicy`.
- Input Monitoring permission denied for `NSEvent.addGlobalMonitorForEvents` → hotkey degrades to local monitor only; inform user but don't block Settings.

### Dev notes
- Touch: `WisperVoiceApp.swift` (`AppDelegate`, `@Environment(\.openWindow)`, `@Environment(\.openSettings)`), `MenuBarView.footer`, `HotkeyManager.register()` error path, `PermissionsManager` banner. Add `AppDelegate.applicationShouldHandleReopen`.
- Test: `AppLaunchTests` — simulate `applicationShouldHandleReopen` and assert window count.

---

## 5. Auto-Input After 5s Silence (configurable enable/disable)

### User story
> As a user I can dictate, pause, and after ~5s of silence the text is automatically committed/injected at cursor, so I don't have to press the hotkey again. I can disable this if I prefer manual commit.

### Acceptance criteria
- [ ] AC5.1: Settings → Behavior has **Toggle `Auto-commit on silence`** (`@AppStorage("autoCommitOnSilence") Bool default false` — default OFF to avoid surprise) + **Stepper `Silence threshold`** `3–10s`, default `5s`, step `1s`, visible only when enabled.
- [ ] AC5.2: When enabled and `state == .recording`, a silence detector starts. After continuous silence ≥ threshold, `stopAndTranscribe()` → `transcribe` → `inject` fires automatically (same pipeline as manual `toggleDictation`).
- [ ] AC5.3: Silence definition: audio level (RMS from `AudioRecorder` / `AVAudioEngine` tap) below `silenceThresholdDb` (e.g., -45 dB) for full threshold duration. Use simple RMS + hysteresis; no external VAD dependency for v1. If `SFSpeech` VAD available, prefer it.
- [ ] AC5.4: Any speech above threshold **resets** the 5s timer. Manual `toggleDictation` / `Esc` cancel also cancels timer.
- [ ] AC5.5: While auto-commit is counting, pill shows countdown hint: "Auto-sending in 3s…" (updates every second) so user can cancel if unintended.
- [ ] AC5.6: `autoPaste == false` still respects auto-commit: transcript goes to `HistoryStore` + pasteboard + notification, but does not inject.
- [ ] AC5.7: Persistence: threshold + enabled survive reboot (`@AppStorage` / `UserDefaults` keys `autoCommitOnSilence`, `silenceThresholdSec`).

### Edge cases
- Background noise (fan, keyboard) → hysteresis prevents false speech; provide "Silence sensitivity" advanced slider if needed (future, not required for v1).
- User pauses mid-sentence intentionally → auto-commit may split transcript; mitigate with countdown UI + easy undo (Cmd+Z in target app is out-of-scope, but history re-paste is required).
- Multiple monitors / app in background → timer still runs; injection targets `NSWorkspace.frontmostApplication` at commit time (existing `TextInjector` logic).
- Very short utterance (<0.5s) followed by silence → still auto-commits if enabled (no minimum speech guard).
- Battery: silence timer is cheap `Timer` on main run loop; no polling >10 Hz.

### Dev notes
- Touch: `DictationManager.swift` (`@AppStorage` keys, `silenceTimer: Timer?`, `silenceElapsed`, `audioLevel` publisher), `AudioRecorder` (expose `levelPublisher` or pass `audioLevel` already published), `OverlayView` countdown text, `SettingsView` toggle+stepper.
- Impl sketch: on `startRecording` start `Timer.scheduledTimer(withTimeInterval: 0.2)` checking `audioLevel < threshold`; increment `silentSec`, reset on `level > threshold`. When `silentSec >= threshold` → `stopAndTranscribe()`.
- Test: `DictationManagerTests.testAutoCommitAfterSilence` with mocked `AudioRecorder` levels.

---

## 6. Dashboard Walkthrough on First Install

### User story
> As a first-time user I see a short dashboard walkthrough so I know how to dictate, where the menu bar lives, and that I can change shortcuts.

### Acceptance criteria
- [ ] AC6.1: On **first launch only** (`@AppStorage("hasSeenOnboarding") == false`, or `UserDefaults` key `hasCompletedOnboarding`), a walkthrough appears **before** the main `ContentView` — modal sheet or dedicated `OnboardingView` window (400×500) with 4 steps, progress dots.
- [ ] AC6.2: Steps:
  1. **Welcome** — "WisperVoice — Speak in any app" + hero animation (waveform.and.mic).
  2. **Permissions** — Microphone + Accessibility, with "Grant" buttons that call `PermissionsManager.request*` and deep-link to System Settings (`x-apple.systempreferences:com.apple.preference.security`).
  3. **Try it** — "Press ⌥Space or Fn×2 anywhere" + live pill preview + "Try dictation" button that calls `dictation.startRecording`.
  4. **Customize** — "Change shortcut & Dock" → `SettingsLink` + "Show in Dock" toggle preview + "Done" → dismiss + mark `hasSeenOnboarding=true`.
- [ ] AC6.3: Controls: Next / Back / Skip; Skip marks onboarding complete. `Esc` does not accidentally dismiss before completion — require explicit Skip/Done.
- [ ] AC6.4: Relaunch does not show again. Settings → About has "Show walkthrough again" button that resets flag.
- [ ] AC6.5: Walkthrough is accessible (VoiceOver labels, keyboard nav `Tab`/`Return`) and localizable-ready (no hard-coded layout that breaks on longer strings).

### Edge cases
- User quits mid-onboarding → on next launch, resume at step 1 (or last step if persistence desired — spec says restart from 1, simpler).
- Permissions already granted → step 2 shows checkmarks and auto-advances hint "You're all set".
- Window management: onboarding window is `NSWindow` level `.floating` centered, modal to main window, not hidden by menu bar.

### Dev notes
- Touch: new `Views/OnboardingView.swift` (4-step `TabView` or `ZStack` with `matchedGeometryEffect`), `WisperVoiceApp.swift` (`@AppStorage("hasSeenOnboarding")` gating `.sheet` / `fullScreenCover`), `PermissionsManager`, `SettingsView` "Show walkthrough again".
- No new entitlements; use existing `AVAudio` + `AXIsProcessTrustedWithOptions` flow.

---

## 7. Clipboard / History — see / copy / paste

### User story
> As a user I have a **clipboard/history** where I can see recent transcriptions and copy or paste any of them again.

### Current state
- `HistoryStore.shared` already persists 100 items in `UserDefaults` JSON, shows in `MenuBarView.historySection` (ScrollView + swipeActions, 8-item preview). `DictationManager.lastTranscript` shows card. But: limited to menu bar, no search, no dedicated window, Copy/Paste Again affordances are subtle, 100 cap not surfaced.

### Acceptance criteria
- [ ] AC7.1: **Menu bar history** remains: `MenuBarView` shows last 8 items (newest first) with timestamp, provider badge, `Copy` and `Paste Again` buttons (existing `swipeActions` + add explicit buttons for discoverability). "Clear" with confirmation alert.
- [ ] AC7.2: **Dedicated History window**: "Open WisperVoice" main window (`ContentView`) gains a History tab/list (or `Window("History", id:"history")`) showing full 100 items, `List` with `searchable` filter, sort newest-first, empty state "No transcriptions yet — press ⌥Space to start".
- [ ] AC7.3: Per-row actions: **Copy** (pasteboard), **Paste Again** (via `TextInjector.inject(text:)` → AX → clipboard fallback, same as `MenuBarView`'s paste), **Delete** (swipe or context menu). Click row copies.
- [ ] AC7.4: Persistence: history survives quit/reboot (`UserDefaults` key `wisper.history` — existing), cap 100, newest insertion at top, overflow drops oldest. No duplicates filter (keep duplicates — user may dictate same phrase twice).
- [ ] AC7.5: Keyboard: `⌘C` copies selected row, `Delete` deletes, `⌘K` focuses search (if present).
- [ ] AC7.6: Accessibility: list rows have `accessibilityLabel = transcript`, `accessibilityHint = "Double-click to copy"`.

### Edge cases
- Empty clipboard / pasteboard race: `TextInjector` restores previous clipboard after paste (existing behavior) — preserve that; history Copy does not clobber restore logic.
- Very long transcript (10k chars) → row shows `lineLimit(2)` + "Show more" disclosure; copy still copies full.
- History `UserDefaults` corruption (invalid JSON) → `HistoryStore.load()` resets to `[]` and logs, does not crash.
- Privacy: history contains sensitive dictation; add Settings → Privacy → "Clear history on quit" toggle (optional stretch, not required for AC).
- Performance: 100 items × searchable filter must stay < 16ms per keystroke (use `@Published` + `filteredItems` computed, no DB needed).

### Dev notes
- Touch: `HistoryStore.swift` (add `remove(_:)`, `item(for:)`, maybe `search(query:)`), `MenuBarView.historySection` (explicit Copy/Paste buttons), `Views/ContentView.swift` or new `Views/HistoryView.swift` (`List`, `searchable`, `contextMenu`), `TextInjector` reuse for Paste Again, `SettingsView` optional "Clear on quit".
- No new framework: SwiftUI `List` + `UserDefaults` suffices; no CoreData.

---

## 8. Cross-Cutting Requirements

- **Do not modify Xcode project** (`.xcodeproj`, `.pbxproj`, schemes, `Info.plist` entitlements beyond `LSUIElement` case). All changes are Swift source + `Info.plist` value.
- **Permissions:** Microphone (`NSMicrophoneUsageDescription`), Accessibility (`AXIsProcessTrustedWithOptions`) — reuse `PermissionsManager`; no new permission needed.
- **Telemetry (optional):** log `onboarding_completed`, `auto_commit_fired`, `history_copy`, `dock_toggle` via existing analytics if present; otherwise no-op.
- **QA matrix:** test each AC on macOS 13/14/15, with/without Dock, with/without Bartender, with screen recording permission denied, with offline STT provider (`appleSpeech`).

## 9. Open Questions for CTO (resolve before sprint)

1. Dock default: PM recommends **default ON** — confirm with design? (PM_PLAN.md "No Dock clutter" principle conflicts; needs explicit override note.)
2. Silence threshold default: 5s — too long for chatty users? Consider 3s default with 5s max? PM says keep 5s to reduce false commits.
3. Onboarding persistence key: `hasSeenOnboarding` vs existing `hasCompletedOnboarding` — check `UserDefaults` for collision.
4. History search: v1 filter only, or also fuzzy? Spec says simple `localizedCaseInsensitiveContains`.

## 10. Definition of Done (for this batch)

- [ ] All 7 specs have AC checklist → PR per spec or grouped PR for #1+#3+#4.
- [ ] Manual QA video/screenshot: menu bar icon, Dock icon, pill Copy, history window, auto-commit countdown, onboarding flow.
- [ ] Unit tests added: `HistoryStoreTests`, `DictationManagerAutoCommitTests`, `OnboardingPersistenceTests`, `HotkeyManagerFallbackTests`.
- [ ] No Xcode project file diff; only `*.swift` + `Info.plist` value change.
- [ ] `PM_SPEC_FIXES.md` updated (this file) + `/tmp/pm_spec.md` written as requested — done.

---

*Spec prepared to be directly taskable — each section maps 1:1 to a ticket. File: `PM_SPEC_FIXES.md` (repo) and `/tmp/pm_spec.md`.*
