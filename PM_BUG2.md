# WisperVoice — PM Bug Spec BUG-2: Pill Z-Index + Menu Bar Presence

> **Author:** PM · **Date:** 2026-08-06 · **Status:** Ready for dev pickup · **Source:** User-reported 2 bugs
> **Scope:** Code-only fixes — do NOT modify `WisperVoice.xcodeproj`. Touch only `WisperVoice/WisperVoiceApp.swift`, `WisperVoice/Managers/OverlayWindow.swift`, `WisperVoice/Views/MenuBarView.swift`, `WisperVoice/Info.plist` if needed. Verify on macOS 13 Ventura → 15 Sequoia, light/dark, notch/no-notch, multi-monitor, Stage Manager, full-screen.

---

## 0. Summary

| # | User bug (verbatim) | Spec title | MoSCoW | Effort | File(s) |
|---|---|---|---|---|---|
| BUG-2a | Main app window / pill hidden behind Chrome/other apps (z-index) | Pill & main window always-on-top when triggered | **Must** | S | `OverlayWindow.swift` (level/collectionBehavior), `WisperVoiceApp.swift` (Window + `openMain` activation) |
| BUG-2b | App not appearing in menu bar (top toolbar near clock/VPN) | Always-visible menu bar icon | **Must** | S | `WisperVoiceApp.swift` (`MenuBarExtra` + `NSStatusItem` fallback), `Info.plist` (`LSUIElement`) |

**Ship together** — both are "app invisible" class. Order: BUG-2b (menu bar) → BUG-2a (pill z-index) — pill fix depends on activation semantics already fixed for menu bar.

**Global DoD:** Each fix verified without Xcode project changes; `xcodebuild build-for-testing` succeeds; manual QA on Chrome/Finder/VSCode full-screen + external monitor + Bartender hidden.

---

## BUG-2a — Pill / Main Window Hidden Behind Other Apps

### User story
> As a user I trigger dictation (`⌥Space` / `Fn×2`) while Chrome (or any app) is frontmost, and the **WisperVoice pill appears visibly on top of the current app**, centered bottom, not hidden behind it. When I click "Open WisperVoice" from menu bar / Dock, the **main dashboard window** comes to the front of the current Space.

### Current state / root cause
- `OverlayWindow.swift:19` sets `level = .floating` (kCGFloatingWindowLevel = 3). Chrome full-screen, Stage Manager, or other `.floating` windows can obscure it. `orderFrontRegardless()` + `makeKeyAndOrderFront(nil)` is called but without `NSApp.activate(ignoringOtherApps:true)` and without a sufficiently high level, so pill stays behind key app.
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` — `stationary` keeps window out of Exposé but does not guarantee visibility in full-screen Spaces; missing `.fullScreenAuxiliary`.
- Main `Window("WisperVoice", id:"main")` in `WisperVoiceApp.swift:26` uses default `.regular` level — when triggered via `AppDelegate.openMain()` it calls `makeKeyAndOrderFront` but without `orderFrontRegardless` / `NSApp.activate(ignoringOtherApps:true)` guarantee, so it lands behind Chrome.
- No `hidesOnDeactivate = false` / `canBecomeKey` override needed — `NSWindow` defaults hide on app deactivation for `.floating`.

### Acceptance criteria
- [ ] **AC-2a.1 — Pill visible on trigger:** Press `⌥Space` while Chrome (or Finder, VS Code, full-screen YouTube) is key → pill appears **within 150 ms** centered bottom (`midX, minY+96`), fully opaque, above the frontmost app on **current Space and current display**. Verified: Chrome normal window, Chrome full-screen, 2 monitors (pill on active screen), Stage Manager on/off.
- [ ] **AC-2a.2 — Pill level & behavior:** `OverlayWindow` uses `level = .floating` **or higher** (`.statusBar` / `.popUpMenu` (101) / `.screenSaver` if needed) — justify chosen level vs side-effects (screen saver level blocks screen-lock UI; prefer `.floating` + `orderFrontRegardless` or `.popUpMenu`). `collectionBehavior` includes `canJoinAllSpaces` + `fullScreenAuxiliary` (so pill joins full-screen Spaces) + `stationary`/`ignoresCycle` as needed. `hidesOnDeactivate = false`. `isReleasedWhenClosed = false` retained.
- [ ] **AC-2a.3 — Activation without stealing focus permanently:** `DictationManager.showOverlay()` / `OverlayWindow.show()` calls `NSApp.activate(ignoringOtherApps: true)` **or** `orderFrontRegardless` without making WisperVoice the permanent key app after hide — text injection target (Chrome text field) must retain insertion point. After `hide()` orderOut, focus returns to previous app (do not leave WisperVoice key).
- [ ] **AC-2a.4 — Main window on demand:** Click menu bar → "Open WisperVoice" or Dock icon → `ContentView` window (`Window id:"main"`) appears frontmost on current Space via `NSApp.activate(ignoringOtherApps:true)` + `makeKeyAndOrderFront(nil)` + `orderFrontRegardless` fallback. If already visible, it is raised, not duplicated. Works when triggered from pill's "Open App" or `MenuBarView` button (`MenuBarView.swift:256`).
- [ ] **AC-2a.5 — Main window style:** `Window("WisperVoice", id:"main")` keeps `.windowResizability(.contentSize)` + `.defaultSize(width:520,height:420)`; no hidden title bar that prevents `makeKeyAndOrderFront`. `Settings` scene unaffected. `applicationShouldHandleReopen` brings main window forward on Dock re-click.
- [ ] **AC-2a.6 — No regressions:** Pill still `borderless`, `isOpaque=false`, `backgroundColor=.clear`, `hasShadow=false` (glass capsule owns shadow), `alphaValue` fade hide (0.22s) intact. Closing pill via `×` / `Esc` (`onClose`) still cancels recording.

### Edge cases
- Full-screen Space (Chrome full-screen): pill must appear — requires `fullScreenAuxiliary` in `collectionBehavior` and level ≥ `.floating`.
- Multiple Spaces / Mission Control: pill follows user to current Space (`canJoinAllSpaces`); main window opens on current Space, not hidden Space.
- Multi-monitor: pill centers on `NSScreen.main` or `NSScreen.screens` containing mouse cursor / key window — not always primary display.
- Stage Manager / Split View: pill not clipped; test with Stage Manager thumbnails.
- Accessibility zoom / notch: pill at `minY+96` leaves Dock clearance; not obscured by notch.
- Rapid toggle (`⌥Space` ×3 quickly): no orphaned windows, no `orderOut` race; `DispatchQueue.main.async` show is idempotent.
- App deactivated mid-recording: pill stays visible (`hidesOnDeactivate=false`).

### Dev notes (which files to change)
- **Primary:** `WisperVoice/Managers/OverlayWindow.swift`
  - `init()`: `level = .floating` → `.floating` + `orderFrontRegardless` **or** `.popUpMenu` (101) / `.screenSaver` (1000) — pick one, document tradeoff. Add `collectionBehavior.insert(.fullScreenAuxiliary)`. Set `hidesOnDeactivate = false`. Ensure `center()` fallback replaced by per-screen positioning (use `NSScreen.main` or `NSApp.keyWindow?.screen ?? NSScreen.main`).
  - `show(state:level:transcript:)`: ensure `DispatchQueue.main.async { self.orderFrontRegardless(); self.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }` ordering; set `alphaValue=1` before ordering.
  - Keep `isReleasedWhenClosed=false`, `styleMask=.borderless`, `isMovableByWindowBackground=false`.
- **Secondary:** `WisperVoice/WisperVoiceApp.swift`
  - `AppDelegate.openMain()`: add `NSApp.activate(ignoringOtherApps:true)` before `makeKeyAndOrderFront`; fallback `orderFrontRegardless` if `keyWindow == nil`. Ensure `applicationShouldHandleReopen` calls same path.
  - `Window("WisperVoice", id:"main")` scene: no level change needed (regular), but ensure `.windowResizability` / `.defaultSize` retained; if adding `NSWindow` customization, do via `NSWindow` accessor, not project change.
  - `MenuBarView.swift:256` "Open App" button already does `NSApp.activate` + `makeKeyAndOrderFront` — align with AppDelegate path.
- **Do NOT** modify `WisperVoice.xcodeproj/project.pbxproj`.
- **Tests:** Extend `OverlayWindowTests.swift` — assert `level.rawValue >= NSWindow.Level.floating.rawValue`, `collectionBehavior.contains(.canJoinAllSpaces) && .fullScreenAuxiliary`, `hidesOnDeactivate==false`, `isReleasedWhenClosed==false`. Mock `NSScreen` if needed.

---

## BUG-2b — App Not Appearing in Menu Bar

### User story
> As a user I always see WisperVoice in the **macOS menu bar** (top-right near clock / VPN / Bartender icons) so I can click it to open the app, check status, and access Settings — even after reboot, sleep/wake, or when the Dock is hidden.

### Current state / root cause
- `WisperVoiceApp.swift:14` declares `MenuBarExtra { MenuBarView } label: { Label("WisperVoice", systemImage: iconName) } .menuBarExtraStyle(.window)` + `.labelStyle(.iconOnly)`. Correct for macOS 13+, but fragile: fails silently if SF Symbol name invalid, if OS < 13, or if Bartender / "Control Centre → Menu Bar" hides it. No diagnostic hint.
- `Info.plist` currently `LSUIElement = false` (regular app — shows in Dock). Previously `true` (accessory) hid Dock but also made menu bar the *only* entry point — loss of both = no entry point. Current `false` is correct for this bug's expectation (user wants both Dock + menu bar).
- Fallback `NSStatusItem` already exists in `AppDelegate: statusItem` (`WisperVoiceApp.swift:110,118`) — creates `NSStatusBar.system.statusItem(withLength:variableLength)` with `waveform` template image + `makeStatusMenu()` + `openMain` action, re-ensured on `screensDidWake` / `didWakeNotification` and `ensureStatusItem()`. This is the intended resilience layer — needs to guarantee **no duplicate icons** and **visibility within 1s of launch**.
- Risk: both `MenuBarExtra` and `NSStatusItem` showing = duplicate icons. Current code creates `NSStatusItem` unconditionally — should de-duplicate after confirming `MenuBarExtra` attached, or keep both with same menu (acceptable if documented).

### Acceptance criteria
- [ ] **AC-2b.1 — Always visible within 1s:** On cold launch, after login launch (`SMAppService.mainApp` registered), and after `NSWorkspace.screensDidWakeNotification` / `didWakeNotification`, a WisperVoice icon is visible in the **system menu bar** within 1s. Tested on macOS 13/14/15, light+dark, translucent menu bar, notch/no-notch.
- [ ] **AC-2b.2 — Correct API:** `MenuBarExtra` retained as primary (Apple HIG `.window` style). `label` uses `Label("WisperVoice", systemImage: iconName) .labelStyle(.iconOnly)` with `iconName` reflecting `DictationState` (idle:`waveform`, recording:`waveform.badge.mic`, transcribing:`waveform.badge.ellipsis`, injecting:`checkmark.circle`) — already implemented in `WisperVoiceApp.iconName` — icon updates live without relaunch.
- [ ] **AC-2b.3 — Fallback guarantee:** `AppDelegate.statusItem: NSStatusItem?` fallback ensures icon never disappears: created in `applicationDidFinishLaunching` via `NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)`, `button.image = NSImage(systemSymbolName:"waveform", accessibilityDescription:"WisperVoice")`, `isTemplate=true`, `toolTip="WisperVoice — Option+Space to dictate"`, `button.action=#selector(openMain)`, `menu=makeStatusMenu()`. Re-created in `ensureStatusItem()` if `statusItem==nil || button==nil`. No duplicate after sleep/wake or Settings close.
- [ ] **AC-2b.4 — De-duplication:** App shows **exactly one** WisperVoice icon in menu bar under normal conditions (either `MenuBarExtra` alone, or `NSStatusItem` alone, or both collapsed to one if both present — document chosen strategy). After `MenuBarExtra` successfully attaches, remove or hide fallback; or keep fallback hidden behind `MenuBarExtra` check (0.5s delay check). No duplicate after rapid relaunch.
- [ ] **AC-2b.5 — Interaction:** Single-click menu bar icon opens `MenuBarView` popover/window (`.window` style) with header, CTA, permissions banner, last transcript, history, footer. Menu bar icon also exposes right-click / long-press menu (`makeStatusMenu()`: Open WisperVoice, Settings…, Quit). Works when `LSUIElement=false` (Dock visible) and when user toggles `showInDock` in Settings.
- [ ] **AC-2b.6 — Appearance:** Template image (`isTemplate=true`) renders with correct contrast on light/dark/translucent menu bar and on notch. No invisible icon due to missing SF Symbol — fallback to `waveform` if `iconName` symbol unavailable.
- [ ] **AC-2b.7 — Persistence:** Icon survives reboot when "Open at Login" enabled (`launchAtLogin` AppStorage → `SMAppService.mainApp.register()`), survives `Cmd+Q` → relaunch, survives `killall SystemUIServer`.

### Edge cases
- Menu bar crowded / Bartender / HiddenMe / Vanilla hiding: icon may be collapsed into overflow — provide in-app hint in `ContentView` / `SettingsView` footer: "If icon hidden, check Bartender or System Settings → Control Centre → Menu Bar → WisperVoice → Show in Menu Bar".
- Multiple displays / Spaces: menu bar is system-owned per display — icon appears on primary display's menu bar (system behavior, not per-space window).
- OS < 13 (no `MenuBarExtra .window`): fallback `NSStatusItem` must fully replace it; test deployment target.
- User toggles `showInDock` OFF (`NSApp.setActivationPolicy(.accessory)`): menu bar icon must remain (only entry point) — never hide both simultaneously; if both hidden, show alert "Press ⌥Space or relaunch from Finder/Spotlight".
- Rapid sleep/wake cycles: `ensureStatusItem` idempotent, does not leak `NSStatusItem` instances.
- Icon state sync: `iconName` changes while menu bar popover closed — icon still updates (SwiftUI `@StateObject dictationManager` drives `MenuBarExtra` label).

### Dev notes (which files to change)
- **Primary:** `WisperVoice/WisperVoiceApp.swift`
  - Keep `MenuBarExtra { MenuBarView.environmentObject(...) } label: { Label("WisperVoice", systemImage: iconName).labelStyle(.iconOnly) } .menuBarExtraStyle(.window)` — do not remove.
  - `AppDelegate.applicationDidFinishLaunching`: `NSApp.setActivationPolicy(.regular)` (Dock visible) + `_ = OverlayWindow.sharedInstance` early init + `NSStatusItem` fallback creation (already present — audit for duplicate). Add 0.5s delayed check: if `MenuBarExtra` attached (heuristic: `NSStatusBar.system.statusItem` count or `MenuBarExtra` visibility), remove fallback to avoid duplicate; otherwise keep fallback.
  - `ensureStatusItem()` on `screensDidWake` / `didWake`: recreate if `button==nil`.
  - `makeStatusMenu()`: Open WisperVoice → `openMain` (activate + raise main window), Settings… → `showSettingsWindow:`, Quit → `NSApp.terminate`. Ensure targets correct.
  - `iconName` computed from `dictationManager.state` — verify SF Symbols exist on macOS 13 (`waveform.badge.mic` requires 14? fallback to `mic.fill` if missing).
- **Secondary:** `WisperVoice/Info.plist`
  - Ensure `LSUIElement = false` (or key removed) so Dock + menu bar both visible. Changing to `true` would re-hide Dock — contradicts BUG-2b user expectation. Coordinate with `showInDock` toggle in `SettingsView.swift:31` (`NSApp.setActivationPolicy`).
  - No entitlements change needed.
- **Tertiary:** `WisperVoice/Views/MenuBarView.swift` — no structural change; ensure `MenuBarView` frame `width:380`, `ultraThinMaterial`, `RoundedRectangle` polish retained; footer already has "Open App" button (`MenuBarView.swift:256`) for discoverability.
- **Do NOT** modify `WisperVoice.xcodeproj/project.pbxproj`.
- **Tests:** Extend `WisperVoiceAppTests.swift` (and add `MenuBarPresenceTests` if missing) — assert `statusItem != nil` after `applicationDidFinishLaunching`, `statusItem.button.image.isTemplate == true`, `MenuBarExtra` scene exists, `ensureStatusItem` recreates after `statusItem=nil`.

---

## MoSCoW — Combined

| Item | MoSCoW | Rationale |
|---|---|---|
| Menu bar always visible (BUG-2b) | **Must** | Without it user has no discoverable entry point (especially if Dock hidden via `showInDock=false`). Blocks all other flows. |
| Pill / main window on top (BUG-2a) | **Must** | Core dictation UX — invisible pill = user thinks hotkey broken. Must be above Chrome. |
| Smart de-duplication of MenuBarExtra vs NSStatusItem | **Should** | Avoid duplicate icons; degrades trust but not blocking if both show. |
| Full-screen Space support (`.fullScreenAuxiliary`) | **Should** | Power users use full-screen Chrome; without it pill invisible in that Space. |
| Bartender hint / diagnostics | **Could** | Helps crowded menu bar case; low cost. |
| Customizable pill position / level in Settings | **Won't** (this sprint) | Nice-to-have; defer to v1.3. Keep fixed bottom-center. |

---

## Verification Checklist (for QA / CTO)

- [ ] Build: `xcodebuild build-for-testing -derivedDataPath /tmp/wisper_build` → `TEST BUILD SUCCEEDED` (no project changes).
- [ ] Menu bar: launch → icon visible ≤1s → click → `MenuBarView` popover → "Open WisperVoice" → main window frontmost. Sleep/wake → still visible, no duplicate. Toggle `showInDock` off/on → menu bar persists.
- [ ] Pill: Chrome frontmost → `⌥Space` → pill above Chrome → `×` cancels → Chrome text field still focused. Chrome full-screen → pill still above. 2 monitors → pill on active display. Stage Manager on/off → pill not clipped.
- [ ] Main window: Chrome frontmost → click menu bar "Open WisperVoice" → dashboard above Chrome. Dock click re-raises.
- [ ] Accessibility: VoiceOver reads menu bar icon label "WisperVoice", pill close button "Stop / Close", copy button "Copy transcript".
- [ ] Dark/light, notch/no-notch, translucent menu bar contrast OK.

---

## Appendix — Window Level Reference

| Level | Raw | Use |
|---|---|---|
| `.normal` | 0 | Regular windows (main dashboard) |
| `.floating` | 3 | Standard floating panels — can be obscured by other floating |
| `.statusBar` | 25 | Menu bar level |
| `.popUpMenu` | 101 | Menus, popovers — reliably above `.floating` |
| `.screenSaver` | 1000 | Above all — use only if pill must be above full-screen video |

**Recommendation:** Start with `.floating` + `orderFrontRegardless` + `fullScreenAuxiliary` + `hidesOnDeactivate=false`. Escalate to `.popUpMenu` if QA still shows Chrome obscuring pill. Avoid `.screenSaver` unless required (blocks system screen saver UI).

---

*Spec ends — dev pickup: `OverlayWindow.swift` (level/collectionBehavior/show), `WisperVoiceApp.swift` (MenuBarExtra/NSStatusItem/openMain), verify `Info.plist LSUIElement=false`.*
