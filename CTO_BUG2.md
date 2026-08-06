# WisperVoice — CTO Bug 2: Chrome Covers App + Menu Bar Icon Missing

**Owner:** CTO / Architect · **Date:** 2026-08-06 · **App:** WisperVoice SwiftUI macOS 14+ (`WisperVoice/`, Xcode 16.3, Swift 5.9)
**Constraint:** Do **not** modify `WisperVoice.xcodeproj/project.pbxproj` (no `INFOPLIST_KEY_LSUIElement` / target edits). Only `*.swift` + `WisperVoice/Info.plist` values. Sync target: `/tmp/cto_bug2.md` ↔ `CTO_BUG2.md` (identical).
**Related:** `CTO_PLAN.md` (§1–§4), `PM_SPEC_FIXES.md` (#1, #3, #4), existing implementation in `WisperVoiceApp.swift:12-181`, `Managers/OverlayWindow.swift:1-231`, `Views/MenuBarView.swift:1-291`, `Info.plist:9`.

---

## 0. Repro & root causes

### Bug A — "Chrome hides the app"
User opens WisperVoice (main `Window(id:"main")` + floating pill `OverlayWindow`), switches to Chrome (or Chrome fullscreen video / Google Meet / Notion), WisperVoice disappears behind Chrome and pill never reappears on next dictation. On Chrome fullscreen, pill missing entirely.

Root causes (audited 2026-08-06):
1. `OverlayWindow.level = .floating` alone is correct for normal Spaces but `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` is missing `.fullScreenAuxiliary` → AppKit hides `.floating` windows when a Space enters fullscreen (Chrome fullscreen video / presentation). Chrome fullscreen is a dedicated Space; without `fullScreenAuxiliary`, pill is excluded.
2. `OverlayWindow.show()` calls both `orderFrontRegardless()` and `makeKeyAndOrderFront(nil)` on `DispatchQueue.main.async`. `makeKeyAndOrderFront` **steals key** from Chrome's text field. That breaks injection target detection (`AXFocusedUIElement` / `frontmostApplication` now points at WisperVoice) and triggers `hidesOnDeactivate`-style deactivation flicker. Order+key race also explains Chrome "covering" main window after toggle.
3. `WisperVoiceApp.swift: AppDelegate.applicationDidFinishLaunching` does `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps:false)` then never re-activates on `openMain`. `openMain()` at `WisperVoiceApp.swift:139-152` does `activate(ignoringOtherApps:true)` + `makeKeyAndOrderFront` for the SwiftUI `Window` — correct — but it searches `NSApp.windows.first(where: { identifier == "main" })` which is nil until SwiftUI lazily creates the Window scene; fallback `sendAction(Selector(("showMainWindow:")))` is not a real selector (SwiftUI uses `openWindow(id:)` / `showSettingsWindow:`). So Dock/menubar "Open WisperVoice" can no-op, making Chrome appear to have "hidden" the app permanently.
4. No `NSWindow.Level` choice documented for **main Window** vs **overlay**. Current main `Window("WisperVoice", id:"main")` inherits `.normal` (good). If someone promotes it to `.floating`/`.statusBar` to "fix Chrome", it will float above Chrome permanently and break HIG.

### Bug B — "Menu bar icon not beside VPN"
Icon expected in right menu bar (next to VPN/clock, near `NSStatusItem` area where Bartender shows hidden items) never appears, or appears intermittently, or appears twice.

Root causes:
1. Dual registration: `WisperVoiceApp.body: MenuBarExtra(.window)` at `WisperVoiceApp.swift:14-23` **and** `AppDelegate.statusItem = NSStatusBar.system.statusItem(withLength: .variableLength)` at `WisperVoiceApp.swift:119` unconditionally. On macOS 14 with `LSUIElement=false` + `.regular`, both are visible → **duplicate icons**. On macOS 13/Bartender coalescing, `MenuBarExtra` can be coalesced into Control Center overflow while `NSStatusItem` stays visible — user sees "icon disappeared" when they look at `.window`-style popover location, but fallback is at a different x-position.
2. `isTemplate` handling: current `WisperVoiceApp.swift:121,158` sets `img?.isTemplate = true` — correct — but `iconName` computed at `WisperVoiceApp.swift:43-50` uses `waveform.badge.mic` / `waveform.badge.ellipsis` which are **multicolor** symbols; with `isTemplate=true`, badge tint is lost on dark translucent bar. Not a visibility bug but exacerbates "looks invisible" reports.
3. `LSUIElement` / `activationPolicy` mismatch: `WisperVoice/Info.plist:9` now `<false/>` matches `project.pbxproj:476,500 INFOPLIST_KEY_LSUIElement=NO` (both false — good). But `SettingsView.swift: onChange(showInDock)` toggles `NSApp.setActivationPolicy(.regular/.accessory)` at runtime. If user flips to `hideDockIcon=true` (→ `.accessory`), Control Center can hide `.accessory` status items more aggressively on notch Macs; without re-asserting `statusItem.isVisible` the icon vanishes.
4. Lifecycle leaks: `ensureStatusItem` at `WisperVoiceApp.swift:154-162` is called on `screensDidWake`/`didWake` and re-creates `statusItem` if `button==nil` but never removes the old `NSStatusItem` → duplicates after sleep/wake. No `autosaveName` set, so Bartender cannot pin position beside VPN. No `statusItem.isVisible = true` (macOS 14 API) asserted.
5. Symbol fallback: `NSImage(systemSymbolName: "waveform")` is macOS 13+; older or missing font returns nil → button.image nil → empty gap beside VPN. No fallback PNG.

---

## 1. Decisions — Chrome / always-on-top

### 1.1 `NSWindow.Level` — split by role

| Window | Level | Why |
|---|---|---|
| **Main `Window("WisperVoice", id:"main")`** (SwiftUI `Window` scene at `WisperVoiceApp.swift:26-33`) | **`.normal` (default, do not override)** | Main dashboard must behave like a normal document window: obeys Exposé, Mission Control, Cmd-Tab, can be ordered behind Chrome when not active. Floating the main window is HIG violation and annoys Chrome users. |
| **`OverlayWindow` pill** (`Managers/OverlayWindow.swift:19`) | **`.floating`** (keep) — not `.statusBar` | `.floating` (CG `kCGFloatingWindowLevelKey`, level 3) floats above Chrome's `.normal` windows and is the Apple-approved level for transient dictation pills. `.statusBar` (level 25) sits above Control Center / menu bar and covers system UI; reserved for screen-capture/critical alerts. `.screenSaver` (level 1000) is rejected. If QA proves Chrome's Picture-in-Picture still covers `.floating`, escalate to `.popUpMenu` (101) behind a feature flag — but default stays `.floating`. |

Do **not** use `.modalPanel` / `.tornOffMenu` — they impose modal session.

### 1.2 `collectionBehavior`

**OverlayWindow** (`OverlayWindow.swift:21`):
```swift
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
```
- Keep `.canJoinAllSpaces` — pill must appear in every Space (Chrome fullscreen creates a new Space).
- **Add `.fullScreenAuxiliary`** — required for the window to appear over a fullscreen Space without forcing that Space to exit fullscreen. This is the missing piece for Chrome fullscreen video / Meet.
- Keep `.stationary` — pill doesn't move when Spaces slide.
- Keep `.ignoresCycle` — Cmd-` excludes pill.

**Main Window** (`Window` scene): no explicit `collectionBehavior` override. SwiftUI `Window` defaults to `.managed` + `.transient` + `.participatesInCycle`, which is correct. If explicit code is added via `NSWindow` accessor, use `[.managed, .transient]` — do not set `.canJoinAllSpaces` on the main window (user expects main window in one Space).

Also set for overlay:
```swift
hidesOnDeactivate = false
hasShadow = true          // keep shadow for visibility over Chrome white pages
isMovableByWindowBackground = false
styleMask = .borderless
isReleasedWhenClosed = false
canBecomeKey = false      // see §1.5
```

### 1.3 `NSApp.activationPolicy` vs `LSUIElement`

- **Source of truth:** `WisperVoice/Info.plist: LSUIElement = false` (current `<false/>` is correct). Keep. This makes the app **regular** by default: Dock visible, Cmd-Tab, Force Quit, Dock menu — discoverability per `PM_SPEC_FIXES.md` AC3.1. Built product `WisperVoice.app/Contents/Info.plist` must show `LSUIElement => false` (`plutil -p` verified 2026-08-06).
- **Build setting:** `project.pbxproj: INFOPLIST_KEY_LSUIElement = NO` (lines 476, 500) stays — do not touch per constraint. It already agrees with plist; changing plist alone is enough because `GENERATE_INFOPLIST_FILE=NO`.
- **`NSApp.setActivationPolicy`:** `AppDelegate.applicationDidFinishLaunching` at `WisperVoiceApp.swift:113` reads `@AppStorage("hideDockIcon")` / `UserDefaults.standard.bool(forKey: "hideDockIcon")` and sets `.accessory` only if user opted into "Hide Dock icon (menu bar only)" in `SettingsView.generalTab`. Default: `.regular`. Toggling is live via `NSApp.setActivationPolicy(_:)` — no relaunch. When hidden, menu bar fallback must stay visible (assert `statusItem?.isVisible = true` after policy change).

Rejected: `LSUIElement=true` + `NSDockTile` hack — not a real Dock icon. Rejected: `LSBackgroundOnly` — terminates on `orderOut`.

### 1.4 `Window` style

- Main SwiftUI `Window`: keep declarative `.windowResizability(.contentSize)` + `.defaultSize(width:520,height:420)` at `WisperVoiceApp.swift:32-33`. Do not add `.windowStyle(.hiddenTitleBar)` off-spec; keep `.titled` with `.closable` so `applicationShouldTerminateAfterLastWindowClosed -> false` at `WisperVoiceApp.swift:176` works (close ≠ quit).
- OverlayWindow: `NSWindow(contentRect:styleMask:.borderless, backing:.buffered, defer:false)` at `OverlayWindow.swift:15` stays. Alternative considered: `NSPanel` with `.nonactivatingPanel` — semantically cleaner for a non-key overlay, but `NSWindow` + `canBecomeKey=false` is equivalent and avoids `NSPanel` becoming key on click. Keep `NSWindow`.

### 1.5 `orderFrontRegardless` vs `makeKeyAndOrderFront` + Chrome focus

**Rule: never steal key from Chrome.**

- **OverlayWindow.show(state:level:transcript:) at `OverlayWindow.swift:36-44`:** use **only** `orderFrontRegardless()` (or `orderFront(nil)` + `NSApp.activate` guard) — **remove `makeKeyAndOrderFront`**. The pill must not become key; Chrome's focused text field must stay `AXFocusedUIElement` so `TextInjector.inject(text:)` at `Managers/TextInjector.swift` targets the right field. Implement:

  ```swift
  func show(state: DictationState, level: Float, transcript: String) {
      hosting?.rootView = OverlayView(state: state, level: level, transcript: transcript,
                                      onCopy: { [weak self] t in self?.copyTranscript(t) },
                                      onClose: { [weak self] in self?.onClose?() })
      // Re-center if screen changed (multi-monitor / Chrome moved)
      recenterIfNeeded()
      DispatchQueue.main.async {
          self.alphaValue = 1
          self.orderFrontRegardless()          // not makeKey
          // Optional: briefly order front without keying
          // self.order(.above, relativeTo: 0)
      }
  }
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
  ```

  Also override `canBecomeKey/canBecomeMain` to false so accidental click on Copy/Close buttons does not key the pill. If buttons need key for `⌘C` (see §1.6), route keyboard via `NSWindow` `keyDown` without becoming key.

- **Main Window (`openMain` at `WisperVoiceApp.swift:139-152`):** use **`makeKeyAndOrderFront`** + `NSApp.activate(ignoringOtherApps:true)`. This is the only place where key is desired — user explicitly asked to "Open WisperVoice." Sequence:

  ```swift
  @objc func openMain() {
      // If Dock-hidden, temporarily become regular so window can be key
      if NSApp.activationPolicy() == .accessory {
          NSApp.setActivationPolicy(.regular)
      }
      NSApp.activate(ignoringOtherApps: true)
      // SwiftUI Window scene: prefer environment openWindow over private identifier search
      // Fallback to NSApp.windows search for already-created window
      if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
          w.makeKeyAndOrderFront(nil)
      } else {
          // Use SwiftUI openWindow via notification/Combine — not private selector
          NotificationCenter.default.post(name: .openMainWindow, object: nil)
          // Brief fallback: show Settings if main still nil after 0.25s
      }
  }
  ```

  Keep `NSApplication.shared.activate(ignoringOtherApps:true)` before `makeKeyAndOrderFront` — ordering matters.

- **Focus on current app:** After overlay `hide()` at `OverlayWindow.swift:56-64`, do **not** call `NSApp.activate`. Leave focus where it was (Chrome). Only `openMain` / `openSettings` should activate WisperVoice. This preserves "speak in any app" promise.

---

## 2. Decisions — Menu bar icon beside VPN

### 2.1 `MenuBarExtra(.window)` vs `NSStatusItem` fallback

- **Keep both, but de-duplicate.** `MenuBarExtra` at `WisperVoiceApp.swift:14-23` is canonical: `.window` style gives a real SwiftUI `Window` (rounded, `ultraThinMaterial`, 380pt wide) attached to menu bar — HIG preferred. It coalesces into Control Center overflow on macOS 14 when bar is crowded (where VPN, Bartender live) → appears to "hide."
- **`NSStatusItem` is fallback, not primary.** Keep `AppDelegate.statusItem` but **gate creation**: create it lazily 0.6s after launch only if `MenuBarExtra` did not attach, or always create but set `statusItem.isVisible = false` when `MenuBarExtra` is confirmed visible, and flip on `screensDidWake`/`didWake`. Simplest ship: always create fallback but use **same icon + same menu** and set `autosaveName` so Bartender treats them as one slot — user perceives one icon beside VPN. Document duplicate risk in release notes; provide Settings toggle "Use legacy status icon" to let power users disable `MenuBarExtra` and keep only `NSStatusItem(.menu)` if they run Bartender/Ice.

Recommended AppDelegate shape:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hideDock = UserDefaults.standard.bool(forKey: "hideDockIcon")
        NSApp.setActivationPolicy(hideDock ? .accessory : .regular)
        NSApp.activate(ignoringOtherApps: false)
        _ = OverlayWindow.sharedInstance

        // Primary MenuBarExtra is declared in SwiftUI scene; fallback defers to avoid duplicate.
        setupStatusItemFallback()
        observeDictationStateForIconSync()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(ensureStatusItem),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    private func setupStatusItemFallback() {
        // Delay to let MenuBarExtra attach; check if we still need fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.ensureStatusItem()
        }
    }

    @objc func ensureStatusItem() {
        if statusItem != nil, statusItem?.button != nil {
            statusItem?.isVisible = true
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "WisperVoice"            // Bartender can pin beside VPN
        item.isVisible = true
        if #available(macOS 14.0, *) { item.isVisible = true }
        let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WisperVoice")
            ?? NSImage(named: "NSApplicationIcon")
        img?.isTemplate = true                        // monochrome template for dark/light
        item.button?.image = img
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(openMain)
        item.button?.toolTip = "WisperVoice — Option+Space to dictate"
        item.menu = makeStatusMenu()                  // right-click menu; left-click opens main
        // Left-click opens main, right-click shows menu: set behavior
        item.behavior = .terminationOnRemoval         // clean on quit
        statusItem = item
    }
}
```

- **`.window` vs `.menu` style:** Keep `.menuBarExtraStyle(.window)` (as at `WisperVoiceApp.swift:23`) — `.menu` is deprecated for SwiftUI panels and truncates at 380pt. `.window` supports `VStack` with history 8-item `ScrollView`. If OS < 13, gracefully falls back (but deployment target is 14.0 so safe).

### 2.2 `isTemplate`, `iconName`, contrast

- `isTemplate = true` at `WisperVoiceApp.swift:121,158` stays **true** for `NSStatusItem`. For `MenuBarExtra` Label, SwiftUI template is automatic; keep `Label("WisperVoice", systemImage: iconName).labelStyle(.iconOnly)` at `WisperVoiceApp.swift:19-21`.
- `iconName` at `WisperVoiceApp.swift:43-50`: keep `waveform` family for idle/recording; `waveform.badge.mic` renders badge as multicolor — with `isTemplate=true` the badge becomes monochrome and may look "invisible" on translucent bar. Mitigation: use `waveform` for idle, `waveform.badge.mic` only for `.recording`, and set `button.appearsDisabled = false` always. Provide fallback: if `NSImage(systemSymbolName:)` returns nil, use `NSImage(named: "NSMicrophoneBadge")` or asset PNG.
- **Why beside VPN:** VPN icons use `.variableLength` + `isTemplate=true` + `autosaveName` so System Settings → Control Center can order them deterministically. WisperVoice must do the same to be sortable next to VPN.

### 2.3 `LSUIElement` / `Info.plist` duplication

- `WisperVoice/Info.plist` `LSUIElement = false` (Info.plist:9) + `project.pbxproj` `INFOPLIST_KEY_LSUIElement=NO` (lines 476, 500) **must agree**. Current state agrees — keep. Do not set `LSUIElement=true` to "hide from Dock to get menu bar" — that pattern is for `LSUIElement`-only agents; WisperVoice is now `.regular` with user toggle. If CLI toggle is needed: `defaults write com.wispervoice.app hideDockIcon -bool YES` then relaunch, not plist edit.
- If future build must be agent-only (e.g., App Store LSUIElement review), gate via build config: `INFOPLIST_KEY_LSUIElement=YES` + `activationPolicy=.accessory` + ensure `statusItem.isVisible` still asserted — but default stays NO.

### 2.4 Duplicate `NSStatusItem` after wake

- `ensureStatusItem` must be idempotent: check `statusItem?.button != nil` before creating; on `screensDidWakeNotification` call `ensureStatusItem` but do not create a second `statusItem` if one exists. Also remove observer on `deinit`. Current code at `WisperVoiceApp.swift:129-130` adds two observers but never removes and may create second item if button was temporarily nil — fix by reusing existing item and just resetting `image`/`isVisible`.

### 2.5 Bartender / Ice / Hidden Bar

- Users with Bartender see WisperVoice in Bartender Bar unless `autosaveName` is set and user pins it. Mitigation: set `autosaveName = "WisperVoice"` above so Bartender → Settings → Menu Bar Items shows "WisperVoice" by name; document in `SettingsView` footer and `MenuBarView.permissionsBanner` hint: "If icon hidden, check Bartender / System Settings → Control Center → Menu Bar Only / Bartender Bar."
- Do not attempt to programmatically set Bartender order — private API.

---

## 3. File-level changes (no Xcode project mod)

### 3.1 `WisperVoice/WisperVoiceApp.swift`

**Current:** `MenuBarExtra(.window)` + unconditional `statusItem` creation, `openMain` via private selector, `iconName` dynamic, `NSApp.setActivationPolicy(.regular)`.

**Change:**

- Add `import Combine` (if not present) + `var cancellables = Set<AnyCancellable>()`.
- In `applicationDidFinishLaunching`:
  - Keep `NSApp.setActivationPolicy(hideDock ? .accessory : .regular)` gating on `UserDefaults.standard.bool(forKey: "hideDockIcon")`.
  - Replace immediate `statusItem` creation with `setupStatusItemFallback()` (0.6s delay) + `ensureStatusItem` idempotent helper that sets `autosaveName`, `isVisible=true`, `isTemplate=true`, `behavior`.
  - Subscribe to `dictationManager.$state` + `dictationManager.$audioLevel` to sync statusItem image/tint: `statusItem?.button?.image = NSImage(systemSymbolName: iconNameFor(state), ...)` on main queue.
  - Observe `UserDefaults.didChangeNotification` for `hideDockIcon` → `NSApp.setActivationPolicy` + `statusItem?.isVisible = true`.
- Fix `openMain()`:
  - Check `NSApp.activationPolicy() == .accessory` → temporarily `setActivationPolicy(.regular)` before `activate`.
  - `NSApp.activate(ignoringOtherApps: true)` **before** `makeKeyAndOrderFront`.
  - Search `NSApp.windows.first(where: { $0.identifier?.rawValue == "main" })` then fallback to posting `Notification.Name("openMainWindow")` observed by a SwiftUI `onReceive` that calls `openWindow(id:"main")` — remove private `Selector(("showMainWindow:"))`. Keep `DispatchQueue.main.asyncAfter` fallback to `openSettings` only if main still nil.
  - Fix `makeStatusMenu()` at `WisperVoiceApp.swift:164-174`: correct targets (`m.items[3].target = NSApp`), set `keyEquivalentModifierMask` for Quit.
- Fix `ensureStatusItem()`: make idempotent, reuse existing `statusItem`, update `isVisible` and `image`; set `autosaveName`.

**Symbol-level diff sketch:**

```diff
- statusItem = NSStatusBar.system.statusItem(withLength: .variableLength)
- let img = NSImage(systemSymbolName: "waveform", ...)
- img?.isTemplate = true; statusItem?.button?.image = img
+ private func setupStatusItemFallback() { DispatchQueue.main.asyncAfter(deadline: .now()+0.6) { self.ensureStatusItem() } }
+ @objc func ensureStatusItem() {
+   if let item = statusItem, item.button != nil { item.isVisible = true; return }
+   let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
+   item.autosaveName = "WisperVoice"; item.isVisible = true
+   // ...
+ }

- NSApp.activate(ignoringOtherApps: false)
+ NSApp.activate(ignoringOtherApps: false) // keep, but openMain uses true

- if let window = NSApp.windows.first(where: { ... }) { window.makeKeyAndOrderFront(nil) }
+ if NSApp.activationPolicy() == .accessory { NSApp.setActivationPolicy(.regular) }
+ NSApp.activate(ignoringOtherApps: true)
+ if let w = NSApp.windows.first(where: { ... }) { w.makeKeyAndOrderFront(nil) } else {
+   NotificationCenter.default.post(name: .openMainWindow, object: nil)
+ }
```

### 3.2 `WisperVoice/Managers/OverlayWindow.swift`

**Current:** `level=.floating`, `collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle]`, `show()` does `orderFrontRegardless` + `makeKeyAndOrderFront`.

**Change:**

- At `OverlayWindow.swift:19-21`:

  ```swift
  level = .floating
  collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
  hidesOnDeactivate = false
  hasShadow = true
  styleMask = .borderless
  isReleasedWhenClosed = false
  isMovableByWindowBackground = false
  backgroundColor = .clear
  isOpaque = false
  ```

- Add overrides:

  ```swift
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
  ```

- Add helper `recenterIfNeeded()` that recomputes origin from `NSScreen.main` (or `screen` containing mouse) — Chrome fullscreen moves screens.

- Fix `show()` at `OverlayWindow.swift:36-44`: remove `makeKeyAndOrderFront(nil)`, keep only `orderFrontRegardless()` + `alphaValue = 1` inside `DispatchQueue.main.async`. Remove double-ordering. Ensure `hosting?.rootView` update happens before ordering.

- Keep `hide()` fade animation at `OverlayWindow.swift:56-64` but do not call `makeKeyAndOrderFront` there.

- Add `hidesOnDeactivate = false` so switching to Chrome does not hide pill.

Diff sketch:

```diff
- level = .floating
- collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
+ level = .floating
+ collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
+ hidesOnDeactivate = false
+ hasShadow = true

  func show(...) {
-   DispatchQueue.main.async { self.orderFrontRegardless(); self.alphaValue=1; self.makeKeyAndOrderFront(nil) }
+   DispatchQueue.main.async { self.alphaValue=1; self.orderFrontRegardless() }
  }
+ override var canBecomeKey: Bool { false }
+ override var canBecomeMain: Bool { false }
```

### 3.3 `WisperVoice/Info.plist`

**Current:** `LSUIElement <false/>` at `Info.plist:9` — already correct per §1.3. Also `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSAppleEventsUsageDescription`.

**Change:**

- **Keep `LSUIElement = false`.** No key deletion. Verify built `WisperVoice.app/Contents/Info.plist` after `xcodebuild` shows `LSUIElement => false` via `plutil -p`. If `INFOPLIST_KEY_LSUIElement` in pbxproj ever flips to YES, plist value is still authoritative because `GENERATE_INFOPLIST_FILE=NO`, but keep both NO/false for consistency.
- Add optional `LSUIElement` comment for future readers: `<!-- LSUIElement false = Dock visible; hideDockIcon toggles accessory at runtime via NSApp.setActivationPolicy -->`.
- No other plist keys changed. Do not add `NSStatusItem` keys (none exist).

Verification:

```bash
plutil -p WisperVoice/Info.plist | grep LSUIElement   # => false
plutil -p WisperVoice.app/Contents/Info.plist | grep LSUIElement
```

### 3.4 `WisperVoice/Views/MenuBarView.swift`

**Current:** `MenuBarView` body at `MenuBarView.swift:11-48`, `header` + `mainCTA` + `historySection` + `footer` with `SettingsLink`.

**Change:**

- In `MenuBarView.footer` at `MenuBarView.swift:254-268`, the "Open App" button currently does `NSApp.activate(ignoringOtherApps:true); if let w ... { w.makeKey... } else { sendAction(...) }`. Keep but wrap with activationPolicy check (mirror AppDelegate.openMain) and post `openMainWindow` notification as fallback rather than private selector.

- In `permissionsBanner` at `MenuBarView.swift:151-172`, add hint row when icon hidden: `Label("If icon not beside VPN, check Bartender / Control Center → Menu Bar", systemImage: "questionmark.circle")` visible when `NSStatusBar.system.statusItem` count suggests crowding (heuristic: always show as footnote).

- In `header.statusDot` animation at `MenuBarView.swift:76-93`, ensure pulse does not trigger `MenuBarExtra` window to re-layout beside VPN.

- Add `onAppear { NSApp.activate(ignoringOtherApps:false) }` if needed to keep MenuBarExtra attached.

- No `MenuBarExtra` style change — keep `.menuBarExtraStyle(.window)` at `WisperVoiceApp.swift:23`. Do not add `.menuBarExtraAccessories`.

---

## 4. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `.fullScreenAuxiliary` causes pill to appear over Netflix/YouTube fullscreen where user doesn't want it | Medium | Low (pill auto-hides after 1.2s) | Keep `hide()` timer at `DictationManager.stopAndTranscribe` (§ `DictationManager.swift: showOverlay/updateOverlay/hideOverlay`). Pill only visible during `recording/transcribing/injecting`; idle = hidden. User can press `xmark.circle.fill` Close. |
| `.floating` still below Chrome PWA "Always on top" windows that also use `.floating` | Low | Medium | If QA reproduces, escalate overlay to `.popUpMenu` (101) gated by `UserDefaults("overlayLevelHigh")`. Do not default to `.statusBar`. |
| `orderFrontRegardless` without key breaks `⌘C` Copy in pill | Low | Medium | Keep `Copy` button click handler (works without key). Keyboard `⌘C` routed via `NSWindow.keyDown` override or `NSEvent.addLocalMonitorForEvents(.keyDown)` checking `keyWindow == OverlayWindow`. Alternatively rely on `keyboardShortcut("c", modifiers:.command)` at `OverlayView.swift:173` which works even when not key if window is `NSPanel`. Test. |
| Duplicate menu bar icons after sleep/wake | High (reproduced) | Low (cosmetic) | Make `ensureStatusItem` idempotent + `autosaveName` + `isVisible` check; remove duplicate `NSStatusBar.system.statusItem` if `statusItem?.button==nil` before creating new. |
| `NSApp.setActivationPolicy(.accessory)` hides Dock but also hides main Window behind Chrome | Medium | High | When `hideDockIcon=true`, keep `statusItem.isVisible=true` and ensure `openMain()` temporarily flips to `.regular` before `makeKeyAndOrderFront`. Document that Chrome fullscreen + Dock-hidden is unsupported for main Window (user must use pill/history only). |
| `canBecomeKey=false` prevents pill buttons from receiving click | Low | High | `NSButton` in `NSHostingView` inside `NSWindow` with `canBecomeKey=false` still receives mouse clicks (tested on macOS 14). Only keyboard focus is lost — acceptable. Verify `Button("Copy")` + `Button(xmark)` still fire. |
| `LSUIElement` plist vs `INFOPLIST_KEY_LSUIElement` drift after Xcode upgrade | Medium | High | Add CI check: `grep INFOPLIST_KEY_LSUIElement WisperVoice.xcodeproj/project.pbxproj` must be `NO`; `plutil -p WisperVoice/Info.plist | grep LSUIElement` must be `false`. Fail build if mismatch. |
| Bartender still hides icon despite `autosaveName` | Medium | Medium | Document manual pin: Bartender Settings → Menu Bar Items → WisperVoice → always show beside VPN. No code fix. |

---

## 5. Testing plan

### 5.1 Automated (must pass without project mod)

- `xcodebuild test -scheme WisperVoice -destination 'platform=macOS'` — existing 9 suites (`OverlayWindowTests`, `WisperVoiceAppTests`, etc.) must stay green. Add assertions (if tests exist, extend — don't modify pbxproj):
  - `OverlayWindowTests.testLevelIsFloating()` — `XCTAssertEqual(OverlayWindow.sharedInstance.level, .floating)`
  - `OverlayWindowTests.testCollectionBehaviorIncludesFullScreenAuxiliary()` — `XCTAssertTrue(OverlayWindow.sharedInstance.collectionBehavior.contains(.fullScreenAuxiliary))`
  - `OverlayWindowTests.testCanBecomeKeyIsFalse()` — `XCTAssertFalse(OverlayWindow.sharedInstance.canBecomeKey)`
  - `OverlayWindowTests.testHidesOnDeactivateIsFalse()` — `XCTAssertFalse(OverlayWindow.sharedInstance.hidesOnDeactivate)`
  - `WisperVoiceAppTests.testStatusItemAutosaveName()` — `XCTAssertEqual(AppDelegate().statusItem?.autosaveName, "WisperVoice")` after `ensureStatusItem`.
  - `WisperVoiceAppTests.testLSUIElementFalse()` — parse `WisperVoice/Info.plist` via `Bundle.main.infoDictionary["LSUIElement"] == false`.

- `plutil -lint WisperVoice/Info.plist` + `plutil -p WisperVoice.app/Contents/Info.plist | grep LSUIElement`.

### 5.2 Manual QA matrix (Chrome focus)

| Scenario | Steps | Expected |
|---|---|---|
| Chrome normal window | Launch WisperVoice → `⌥Space` → pill appears → switch to Chrome → pill stays above Chrome | Pill at level floating above Chrome; main Window behind Chrome unless `openMain`. |
| Chrome fullscreen video (YouTube) | Chrome → fullscreen video → `⌥Space` | Pill visible over fullscreen video (requires `.fullScreenAuxiliary`). If missing, escalate to `.popUpMenu`. |
| Chrome Meet screenshare | Share screen → dictate | Pill visible to local user only (not shared). |
| Multi-Space | Chrome on Space 2, WisperVoice main on Space 1 → `⌥Space` | Pill appears on active Space (Chrome's Space) via `.canJoinAllSpaces`. |
| Menu bar beside VPN | Boot → look at right menu bar near VPN/clock | One WisperVoice waveform icon beside VPN; click → `MenuBarView` popover (`.window` style). Right-click fallback shows Open/Settings/Quit. No duplicate. |
| Bartender overflow | Bartender hides icons → check Bartender Bar | Icon appears in Bartender Bar; pinning moves it beside VPN. |
| Sleep/wake | Sleep Mac → wake | Single icon remains; no duplicate after `screensDidWakeNotification`. |
| Dock hidden mode | Settings → Hide Dock icon ON → switch to Chrome | Dock icon disappears; menu bar icon stays; `openMain` from menu bar still brings main Window (temporarily `.regular`). |
| Chrome focus preservation | `⌥Space` → speak → `stopAndTranscribe` → auto-paste | Paste goes to Chrome's focused field, not WisperVoice. Pill never became key (verify via `NSApp.keyWindow != OverlayWindow`). |
| `⌘C` in pill | Pill with transcript → `⌘C` | Copies to pasteboard even though pill not key (via local monitor). |

### 5.3 Commands

```bash
# Build + test (no project mod)
xcodebuild -project WisperVoice.xcodeproj -scheme WisperVoice -destination 'platform=macOS' build
xcodebuild test -project WisperVoice.xcodeproj -scheme WisperVoice -destination 'platform=macOS' 2>&1 | tail -20

# Plist
plutil -p WisperVoice/Info.plist | grep LSUIElement
plutil -p WisperVoice.app/Contents/Info.plist | grep LSUIElement

# Runtime window level check (lldb or NSLog)
# In AppDelegate: NSLog(@"overlay level %ld behavior %lu key %d", (long)OverlayWindow.sharedInstance.level.rawValue, (unsigned long)OverlayWindow.sharedInstance.collectionBehavior.rawValue, OverlayWindow.sharedInstance.canBecomeKey)
```

---

## 6. File checklist & ownership

- [ ] `WisperVoice/WisperVoiceApp.swift` — AppDelegate fallback gating, activationPolicy toggle, openMain fix, Combine sync.
- [ ] `WisperVoice/Managers/OverlayWindow.swift` — level/collectionBehavior/hidesOnDeactivate/canBecomeKey/orderFrontRegardless.
- [ ] `WisperVoice/Info.plist` — keep `LSUIElement false` (no change beyond comment).
- [ ] `WisperVoice/Views/MenuBarView.swift` — footer/openMain parity, Bartender hint.
- [ ] `WisperVoice.xcodeproj/project.pbxproj` — **do not edit** (INFOPLIST_KEY_LSUIElement stays NO).
- [ ] `CTO_BUG2.md` + `/tmp/cto_bug2.md` — this doc.

---

## 7. Open decisions for next sprint

- If Chrome PWA "Always on top" still covers `.floating`, approve `.popUpMenu` behind `UserDefaults("overlayAlwaysOnTop")` toggle.
- Decide single-icon vs dual-icon strategy long-term: keep `MenuBarExtra` only and remove `NSStatusItem` fallback after macOS 15 adoption >90%, or keep fallback permanently for Bartender users.
- Add `Window` scene `@Environment(\.openWindow)` injection for `openMain` rather than `NotificationCenter` — requires iOS 16/macOS 13 `OpenWindowAction` plumbing.

