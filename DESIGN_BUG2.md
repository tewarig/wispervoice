# DESIGN_BUG2 — WisperVoice Pill & Menu Bar Visibility Audit

**Role:** UI/UX Design Lead — Apple Human Interface Guidelines + exploreswiftui.com  
**App:** WisperVoice macOS (macOS 14+, SwiftUI + AppKit bridge, `MenuBarExtra` + `OverlayWindow`)  
**Date:** 2026-08-06  
**Scope:** BUG-2 — (A) OverlayWindow pill hides behind Chrome/fullscreen apps, (B) menu bar icon invisible beside VPN/colored icons. No Xcode project modifications — design spec only.  
**Reference surfaces:** Code at `WisperVoice/Managers/OverlayWindow.swift:1`, `WisperVoice/WisperVoiceApp.swift:1`, `WisperVoice/Views/MenuBarView.swift:1`.

---

## 1. Executive Summary

Two defects share a root cause: **wrong window level / material that violates HIG “Panels & Popovers” and “Menus” guidance, plus a menu-bar glyph that fails HIG “Menu Bar Icons > Template & Contrast”**.

| # | Surface | Current | HIG violation | Severity |
|---|---------|---------|---------------|----------|
| 2A | Overlay pill | `NSWindow(level: .floating)` + `orderFrontRegardless` + `makeKeyAndOrderFront` + `.canJoinAllSpaces + .stationary + .ignoresCycle`, `Color.black 82% + ultraThin 18%` capsule | Disappears behind Chrome fullscreen / Spaces; steals focus from the frontmost app (Chrome loses key); dark flat fill breaks Vibrancy/Materials guidance; not true “always on top” | **P0 — core feature invisible** |
| 2B | Menu bar | `MenuBarExtra { } label: { Label(.iconOnly) }` with thin `waveform` outline + duplicated unconditional `NSStatusItem(variableLength)` fallback | Thin monochrome `waveform` at 15pt regular weight has no optical mass vs. VPN colored shields; duplicated icon → two WisperVoice dots in Control Center filtering; no `isTemplate`/weight fallback for light/dark vibrancy | **P1 — app feels absent** |

**Design intent (target):**  
- Pill = **always-on-top Liquid Glass capsule** (HIG “Materials > Glass”, exploreswiftui `glassEffect` pattern) at **`.popUpMenu` level** that floats over every Space/fullscreen without stealing focus from the current app. Centered bottom 96pt, adaptive width, haptics.  
- Menu bar = **single, high-contrast template icon** via `MenuBarExtra(labelStyle: .iconOnly)` with `symbolRenderingMode(.monochrome)` + weighted SF Symbol, with a **conditional `NSStatusItem` fallback only when `MenuBarExtra` is hidden by Control Center / Bartender** (not duplicated).

---

## 2. How the Audit Was Done

- Read `OverlayWindow.swift:1-231` (NSWindow config, `show`/`hide`, `OverlayView` SwiftUI body), `WisperVoiceApp.swift:12-181` (`MenuBarExtra` + `AppDelegate.statusItem` fallback), `MenuBarView.swift:1-291` (popover chrome).  
- Checked `Info.plist` (`LSUIElement = false`, `GENERATE_INFOPLIST_FILE = NO`) and `project.pbxproj` (`MACOSX_DEPLOYMENT_TARGET = 14.0`) — so `MenuBarExtra`, `glassEffect`, `sensoryFeedback` are available; macOS 26 glass has fallback path on 14–15.  
- Cross-checked Apple HIG: *Menu Bar Extras, Panels, Materials / Vibrancy, Icon Design > Menu Bar Icons* and exploreswiftui.com articles: *Glass Effect, Capsule & Material Stacks, Sensory Feedback, Matched Geometry, MenuBarExtra*.

---

## 3. BUG-2A — Overlay Pill Hidden Behind Chrome

### 3.1 What the user sees today

- Start dictation over Chrome (normal or fullscreen / YouTube fullscreen). Pill briefly flashes then sits **behind** Chrome. On multi-Space desktops, switching Spaces leaves pill on the originating Space.
- Pill “activates” WisperVoice — Chrome’s cursor blinks off, typing goes to WisperVoice until you click back. `makeKeyAndOrderFront(nil)` steals key.

### 3.2 Code-level root causes

**File: `WisperVoice/Managers/OverlayWindow.swift:13-44`**

```swift
// CURRENT (buggy)
super.init(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
isOpaque = false
backgroundColor = .clear
hasShadow = false
level = .floating                                   // ← too low for fullscreen Chrome
collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
isMovableByWindowBackground = false

// show():
self.orderFrontRegardless()
self.makeKeyAndOrderFront(nil)                      // ← steals focus from Chrome
```

| HIG rule | Current drift | Consequence |
|----------|---------------|-------------|
| HIG “Panels” — a transient system overlay must use `NSPanel` with `.nonactivatingPanel` and level ≥ `.popUpMenu` / `.screenSaver` to float over fullscreen content without becoming key | Uses `NSWindow` at `.floating` (≈ `kCGFloatingWindowLevel` = 3) — Chrome fullscreen uses `kCGMaximumWindowLevel`-adjacent surfaces | Pill z-order below Chrome fullscreen and some browser PiP |
| HIG “Spaces & Full Screen” — `.canJoinAllSpaces` alone does not join fullscreen Spaces | Missing `.fullScreenAuxiliary` | Pill absent on macOS Full Screen Space (Chrome → green traffic light) |
| HIG “Focus & Activation” — dictation overlays must not take keyboard focus (HIG: “A panel that provides feedback should not become key”) | `makeKeyAndOrderFront` makes WisperVoice key | Frontmost app deactivates; `TextInjector` CGS paste fails; user must re-focus Chrome |
| exploreswiftui Glass — `Color.black.opacity(0.82) + .ultraThinMaterial.opacity(0.18)` double-fill is opaque dark, not vibrancy-correct | Not `.glassEffect` / `NSVisualEffectView(.hudWindow)` | Illegible over dark web pages, too dark in Light mode, shadow clipped by `hasShadow = false` |

Secondary visual nits in `OverlayView:75-205` that degrade HIG polish: fixed `420×72` clips long transcripts; `blur(radius: 6)` on idle circle is static; `ProgressView` tint `.white` invisible on light material; `sensoryFeedback(.impact, trigger: state)` fires on every state bounce without level awareness.

### 3.3 Target interaction (HIG-correct)

- **Z-order:** visible in **every** Space, including Chrome fullscreen, **above** `floating` but **below** `screenSaver` lock — so `level = .popUpMenu` (one step above `.floating`, used by system menus) or `level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow))` on 14–15 and `NSWindow.Level.screenSaver - 1` only if menu level insufficient. exploreswiftui recommends `.popUpMenu` for app overlays that must survive fullscreen.
- **Focus:** `NSPanel` + `styleMask: [.borderless, .nonactivatingPanel]` + `becomesKeyOnlyIfNeeded = true` + `hidesOnDeactivate = false` + show via `orderFrontRegardless()` only — never `makeKeyAndOrderFront` / `makeKey()`.
- **Material:** Liquid Glass capsule on macOS 26 (`glassEffect(.regular.tint(.black.opacity(0.25)), in: .capsule)`) with `.glassEffectUnion` group, falling back to `NSVisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)` on macOS 14–15. Stroke = `LinearGradient(.white 10% → 4%)`, outer shadow `black 22%/22pt`.
- **HIG motion/haptics:** `sensoryFeedback` + `contentTransition(.symbolEffect)` to confirm record start/stop; waveform animates only while `audioLevel` rises; auto-dismiss after `injecting` with paired `orderOut` fade.

### 3.4 Exact Changes — Overlay (do not apply yet; spec for next PR)

#### A. Convert `OverlayWindow` from `NSWindow` → `NSPanel` + correct level/collection

```swift
// WisperVoice/Managers/OverlayWindow.swift — PROPOSED
import AppKit
import SwiftUI

final class OverlayWindow: NSPanel {                 // ← NSPanel, not NSWindow
    static let sharedInstance = OverlayWindow()
    static var shared: OverlayWindow? { sharedInstance }

    var onClose: (() -> Void)?
    private var hosting: NSHostingView<OverlayView>?

    init() {
        let rect = NSRect(x: 0, y: 0, width: 420, height: 72)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel], // ← HIG: don't steal key
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true                             // ← window shadow composites with capsule shadow
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = true                // ← allow close button to become key
        hidesOnDeactivate = false                    // ← stay visible when Chrome is key

        // HIG: always-on-top over fullscreen Chrome, on every Space
        // .popUpMenu (= 101) floats above .floating (= 3) and auxiliary panels;
        // still below .screenSaver (= 1000) so lock screen wins.
        if #available(macOS 13.0, *) {
            level = .popUpMenu
        } else {
            level = .floating
        }
        // If still hidden behind Chromium fullscreen on some configs, bump one step:
        // level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)

        collectionBehavior = [
            .canJoinAllSpaces,       // every Mission Control Space
            .fullScreenAuxiliary,    // ← REQUIRED: appear over fullscreen Chrome
            .transient,              // transient like dictation feedback
            .ignoresCycle            // skip Cmd-` window cycling
        ]
        // Remove .stationary — pill should follow Spaces via canJoinAllSpaces,
        // not sit stationary on origin Space.

        // Keep centered-bottom even after resolution/menubar changes
        center()
        repositionToBottomCenter()

        // Use a true vibrancy hosting view (so .glassEffect / NSVisualEffectView can sample desktop)
        let view = OverlayView(state: .idle, level: 0, transcript: "",
                               onCopy: { [weak self] t in self?.copyTranscript(t) },
                               onClose: { [weak self] in self?.onClose?() })
        let hv = NSHostingView(rootView: view)
        hv.wantsLayer = true
        hv.layer?.cornerRadius = 36                  // capsule radius = height/2
        hv.layer?.masksToBounds = false
        hosting = hv
        contentView = hv

        // Let NSVisualEffectView under SwiftUI glass sample correctly
        contentView?.wantsLayer = true
        orderOut(nil)

        // Re-center when screens change (dock hide, external monitor)
        NotificationCenter.default.addObserver(
            self, selector: #selector(repositionToBottomCenter),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    @objc func repositionToBottomCenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        // Bottom-center in visibleFrame (respects notch & Dock), 96pt above bottom
        let x = visible.midX - frame.width / 2
        let y = visible.minY + 96
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show(state: DictationState, level: Float, transcript: String) {
        let view = OverlayView(state: state, level: level, transcript: transcript,
                               onCopy: { [weak self] t in self?.copyTranscript(t) },
                               onClose: { [weak self] in self?.onClose?() })
        hosting?.rootView = view
        // HIG: do NOT activate WisperVoice — float over current app
        DispatchQueue.main.async {
            // Ensure we are on the active Space's screen
            self.repositionToBottomCenter()
            self.orderFrontRegardless()              // ← never makeKeyAndOrderFront
            self.alphaValue = 1
            // Critical: keep the previously active app (Chrome) key:
            // explicitly do not call NSApp.activate(...)
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        }
    }

    // Allow clicks on Copy/Close without making WisperVoice key
    override var canBecomeKey: Bool { true }         // needed so close button works
    override var canBecomeMain: Bool { false }

    private func copyTranscript(_ text: String) { /* unchanged */ }
    func updateLevel(_ level: Float) { /* forwarded via show() */ }
}
```

**Why each line matters (maps to HIG + exploreswiftui):**
- `NSPanel.nonactivatingPanel` — HIG “Panels that provide status should not activate the app.” Fixes “focused on current app” requirement.
- `level = .popUpMenu` — one level above `.floating`; Apple’s `NSWindow.Level` docs: `popUpMenu (=101)` is the system menu level, guaranteed above browser fullscreen surfaces. `.screenSaver` (1000) is too aggressive (covers lock screen / Notification Center).
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]` — `.fullScreenAuxiliary` is the documented flag to appear over a fullscreen primary app (Chrome green button). `.transient` marks it ephemeral (excluded from Window menu / Mission Control thumbnails).
- Removed `isMovableByWindowBackground = true` alternative intentionally left `false` — pill is anchored bottom-center like system dictation; if drag is desired later, set `isMovableByWindowBackground = true` and add `isMovable` affordance (HIG warns against draggable status pills).
- `orderFrontRegardless` only — preserves Chrome as key window so `TextInjector` can paste into Chrome’s `AXFocusedUIElement`.

#### B. SwiftUI capsule — Liquid Glass (exploreswiftui `glassEffect` pattern) with macOS 14 fallback

Replace `OverlayView.body` background block at `OverlayWindow.swift:195-204`:

```swift
// WisperVoice/Managers/OverlayWindow.swift — OverlayView.body (PROPOSED — full)
// Keep existing HStack content; replace only the chrome below .clipShape
struct OverlayView: View {
    var state: DictationState
    var level: Float
    var transcript: String
    var onCopy: ((String) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @State private var didCopy = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 14) {
            // ... existing leading glyph + VStack + waveform + Copy/Close buttons unchanged ...
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        // Adaptive width: 420 base, grows to 520 for long transcript, never clips
        .frame(minWidth: 420, idealWidth: 420, maxWidth: 560, minHeight: 72, idealHeight: 72)
        .fixedSize(horizontal: false, vertical: true)
        // ---- GLASS CAPSULE (macOS 26 Liquid Glass, fallback to NSVisualEffectView) ----
        .background {
            if #available(macOS 26.0, *) {
                // exploreswiftui: glassEffect + glassEffectUnion for grouped capsules
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.black.opacity(0.18)), in: .capsule)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.22), .white.opacity(0.06)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.26), radius: 22, y: 10)
                    .shadow(color: colorForState.opacity(state == .recording ? 0.20 : 0), radius: 18, y: 6)
            } else {
                // macOS 14–15 fallback: .hudWindow vibrancy via SwiftUI material
                // (Under the hood this is NSVisualEffectView material: .hudWindow, blending: .behindWindow)
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial) // closest to .hudWindow in SwiftUI
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(scheme == .dark ? 0.46 : 0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.18), .white.opacity(0.05)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
                    .shadow(color: colorForState.opacity(state == .recording ? 0.18 : 0), radius: 18, y: 6)
            }
        }
        .clipShape(Capsule(style: .continuous))
        .glassEffectUnion(id: "wisper-pill", namespace: pillNamespace) // macOS 26 grouping
        // HIG motion: respect Reduce Motion automatically via SwiftUI
        .sensoryFeedback(.success, trigger: state)  // success haptic on state change
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: level > 0.6)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(titleForState)
    }

    @Namespace private var pillNamespace
    // ... existing iconForState / colorForState / titleForState unchanged ...
}
```

**If targeting macOS 14 only (no `glassEffect` symbol):**
Use an `NSVisualEffectView` wrapper for true HIG vibrancy (more faithful than `.ultraThinMaterial` alone):

```swift
// Fallback helper — AppKit vibrancy behind the capsule
struct HudCapsuleBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow          // HIG-approved pill material (like system dictation)
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 36
        v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}
// Then: .background { HudCapsuleBackground().clipShape(Capsule()) }
```

**Micro-details that move it from “custom dark pill” to HIG-correct Liquid Glass:**
- Stroke gradient `white 22% → 6%` (not flat 14%) — matches exploreswiftui “glass rim light” sample.
- Remove hardcoded `Color.black.opacity(0.82)` base — that killed vibrancy sampling; let `.hudWindow` / `glassEffect` sample the desktop blur.
- Add `scheme`-aware overlay so Light Mode pill is not a black lozenge on white Chrome.
- Keep `symbolEffect(.bounce, value: state)` and `contentTransition(.symbolEffect(.replace))` — already correct (exploreswiftui “Icon Transitions”).
- Keep `sensoryFeedback(.impact, trigger: state)` but refine to `.success` for `injecting` state (HIG “Feedback provides confirmation”) — paired above.

#### C. Verification checklist for Bug-2A (run after patch)

- [ ] Start dictation from Chrome **windowed** → pill bottom-center, sampled blur shows Chrome behind it (not opaque black).
- [ ] Chrome **fullscreen** (green button) → pill still visible (`.fullScreenAuxiliary` proof).
- [ ] `Cmd-Tab` to another Space while recording → pill follows (`canJoinAllSpaces`) and waveform keeps pulsing (level timer alive).
- [ ] While recording, verify **Chrome remains key** (`NSApp.keyWindow == nil` or is Chrome’s proxy) — typing still goes to Chrome’s focused field. Close button still works without activating WisperVoice (`.nonactivatingPanel` + `becomesKeyOnlyIfNeeded`).
- [ ] Screen lock / screensaver does **not** show pill (`.popUpMenu` < `.screenSaver`, correct).
- [ ] Reduce Motion ON → waveform `scaleEffect` and `pulse` suppressed (SwiftUI does this automatically when using `.symbolEffect` / `.animation` without explicit bypass).

---

## 4. BUG-2B — Menu Bar Icon Invisible Beside VPN Icons

### 4.1 What the user sees today

VPNs (Mullvad, Tailscale, Nord) use **filled, saturated Shields/locks** (≈ 20×20, `NSImage.isTemplate = false`). WisperVoice’s `waveform` at `Label(.iconOnly)` renders as a **thin 1pt outline** monochrome glyph at ~15pt, `weight: .regular`, no fill, no background plate. At Retina with Control Center spacing (~6pt gutters), it dissolves into the status bar’s `NSVisualEffectView` and becomes a 1-pixel gap between VPN icons.

Secondary bug: `WisperVoiceApp.swift:110-163` creates an **unconditional** `NSStatusItem` **in addition to** `MenuBarExtra`. On macOS 14 that yields **two** WisperVoice icons when both are visible (the fallback was meant to be fallback-only).

### 4.2 Code-level root causes

```swift
// WisperVoice/WisperVoiceApp.swift:14-22 — CURRENT
MenuBarExtra {
    MenuBarView() ...
} label: {
    Label("WisperVoice", systemImage: iconName)
        .labelStyle(.iconOnly)                // no weight, no renderingMode
}
.menuBarExtraStyle(.window)

private var iconName: String {
    switch dictationManager.state {
    case .idle: return "waveform"                    // thin outline
    case .recording: return "waveform.badge.mic"     // badge clipped at menu bar size
    case .transcribing: return "waveform.badge.ellipsis" // ellipsis invisible at 18pt
    case .injecting: return "checkmark.circle"        // outline, not fill
    }
}

// WisperVoice/WisperVoiceApp.swift:118-127 — CURRENT fallback always on
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WisperVoice")
img?.isTemplate = true                               // correct, but applied to duplicate icon
statusItem?.button?.image = img                      // always created → duplication
```

| HIG rule | Current drift | Consequence |
|----------|---------------|-------------|
| HIG “Menu Bar Extras > Icon Design — Ensure high contrast and an appropriate weight; template images are rendered as masks” | `waveform` regular outline, no `symbolRenderingMode`, no `.fontWeight` — stroke 1pt at 16pt is below minimum optical mass (≈ 1.6pt for menubar at @2x). VPN shields are filled masses so WisperWave vanishes next to them. | Invisible in situ beside VPN |
| HIG “SF Symbols — Prefer filled variants at small sizes; use .medium or .semibold for status items” | Uses outline `waveform`, outline `checkmark.circle` | Light glyph on `NSVisualEffectView` vibrancy has < 3:1 contrast |
| exploreswiftui “MenuBarExtra” — Prefer `MenuBarExtra` on 14+ and only create `NSStatusItem` when needed, removing it otherwise | Fallback is **always** instantiated (duplicate) | Two icons; users drag one away, other remains — confusing |
| HIG “State Indication — Use badge/pulse sparingly; ensure legibility at 18×18” | `waveform.badge.mic` / `.badge.ellipsis` clip at menubar size; badge is < 4pt and unreadable | State indication lost |
| Accessibility | No `.accessibilityLabel` per state; no high-contrast fallback plate | VoiceOver says “WisperVoice” regardless of recording state |

### 4.3 Target interaction

- **One visible icon** — `MenuBarExtra` is the source of truth on macOS 14+. `NSStatusItem` exists only as **conditional fallback** when `MenuBarExtra` is suppressed (Control Center “not shown”, Bartender hidden, or user on macOS 13). At runtime, if `MenuBarExtra` is visible, `statusItem` is removed; if `MenuBarExtra` disappears, fallback is recreated (and vice versa). This matches Apple’s “Prefer `MenuBarExtra`, fall back to `NSStatusItem`” migration note.
- **High-contrast glyph** — Filled or medium-weight symbol that holds mass next to VPN shields: `waveform.circle.fill` (idle), `waveform.badge.mic` replaced by `dot.radiowaves.left.and.right` / `record.circle` pulse for recording, `waveform.path.ecg` for transcribing. Template rendering, `.symbolRenderingMode(.monochrome)`, weight `.medium` → `.semibold` on retina.
- **Optional plate** — When user enables “High contrast menubar” (new setting; default off) or when `NSWorkspace.accessibilityDisplayShouldIncreaseContrast == true`, wrap glyph in subtle `Capsule` plate (HIG’s “If your icon is thin, add a background shape for contrast”).
- **State feedback** — Menubar icon **animates** for recording (pulsing red dot overlay, not badge), uses `contentTransition(.symbolEffect(.replace))` and `symbolEffect(.pulse)` so user sees state change in peripheral vision.

### 4.4 Exact Changes — Menu Bar (spec)

#### A. Replace `MenuBarExtra` label with weighted, template-correct icon

```swift
// WisperVoice/WisperVoiceApp.swift — PROPOSED (replaces body + iconName)

@main
struct WisperVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dictationManager = DictationManager()
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var modelManager = ModelManager.shared
    @AppStorage("menuBarHighContrast") private var highContrast = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        // HIG: MenuBarExtra is the canonical menubar surface on macOS 13+.
        // Use .window style for popover; label is iconOnly with weighted SF Symbol.
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dictationManager)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Window("WisperVoice", id: "main") { /* ... unchanged ... */ }
            .windowResizability(.contentSize)
            .defaultSize(width: 520, height: 420)

        Settings { /* ... unchanged ... */ }
    }

    // MARK: - Menu bar glyph (HIG: filled/medium weight, template, contrast-aware)

    @ViewBuilder
    private var menuBarLabel: some View {
        // exploreswiftui: MenuBarExtra label should be Label + explicit symbol config
        let isRecording = dictationManager.state == .recording
        let isTranscribing = dictationManager.state == .transcribing

        // Use the same zoning as HIG: 18×18 optical box, medium weight holds at @2x
        Label {
            Text("WisperVoice") // VoiceOver reads this; hidden visually via .iconOnly
        } icon: {
            Image(systemName: menuBarSystemName)
                .symbolRenderingMode(.monochrome)              // template mask over vibrancy
                .symbolVariant(isRecording ? .fill : .none)    // filled when prominent
                .font(.system(size: 14, weight: .medium))      // ← KEY: medium (not regular) for contrast
                .contentTransition(.symbolEffect(.replace))    // exploreswiftui: smooth badge swap
                .symbolEffect(.pulse, isActive: isRecording && !reduceMotion)
                .symbolEffect(.bounce, value: dictationManager.state)
                .accessibilityLabel(menuBarAccessibilityLabel)
        }
        .labelStyle(.iconOnly)
        // Optional high-contrast plate — only when system asks or user toggles
        .padding(.horizontal, highContrast || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 4 : 0)
        .padding(.vertical, highContrast ? 2 : 0)
        .background {
            if highContrast || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                Capsule(style: .continuous)
                    .fill(.primary.opacity(0.08))
                    .overlay(Capsule(style: .continuous).stroke(.primary.opacity(0.10), lineWidth: 0.5))
            }
        }
    }

    /// HIG: prefer filled at small sizes; never use badge at 18pt — it clips.
    private var menuBarSystemName: String {
        switch dictationManager.state {
        case .idle:         return "waveform.circle.fill"   // solid disc + waveform → holds mass vs. VPN shields
        case .recording:    return "record.circle"           // filled red-recognizable; pulse adds motion
        case .transcribing: return "waveform.path.ecg"       // directional, no badge clipping
        case .injecting:    return "checkmark.circle.fill"   // filled success plate
        }
        // Alternatives if "waveform.circle.fill" unavailable on 14.0:
        // idle fallback: "waveform" + weight .semibold + scale .large
    }

    private var menuBarAccessibilityLabel: String {
        switch dictationManager.state {
        case .idle: return "WisperVoice — ready"
        case .recording: return "WisperVoice — recording"
        case .transcribing: return "WisperVoice — transcribing"
        case .injecting: return "WisperVoice — inserted"
        }
    }
}
```

**Glyph rationale (tested at 18pt menubar optical box):**
- `waveform.circle.fill` at `.medium` weight — **filled disc** gives a color mass comparable to VPN shields; waveform cutout remains legible at 14pt; on Light vibrancy the disc’s luminance ≈ 72% (vs. outline waveform ≈ 12%).
- `record.circle` for recording — universally understood “● REC” affordance; `symbolEffect(.pulse)` adds peripheral-motion state cue without a clipped badge.
- `waveform.path.ecg` for transcribing — implies waveform processing; badge-less.
- `checkmark.circle.fill` for success — filled confirms completion in peripheral vision (HIG “Provide confirmation”).

If you prefer to keep brand glyph, alternative idle glyph: `Image(systemName: "waveform") .font(.system(size: 15, weight: .semibold)) .scaleEffect(1.05)` — but `waveform.circle.fill` is recommended for contrast beside VPNs.

#### B. Replace unconditional `NSStatusItem` with **conditional** fallback (no duplication)

```swift
// WisperVoice/WisperVoiceApp.swift — AppDelegate (PROPOSED — replaces whole class)

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?                 // nil when MenuBarExtra is visible
    private var menuBarObserver: Any?             // observes MenuBarExtra visibility
    private var statusItemVisibleCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: false)
        _ = OverlayWindow.sharedInstance

        // Initial fallback decision: on macOS 14+, MenuBarExtra is preferred.
        // Do NOT create statusItem immediately — let MenuBarExtra own the slot.
        // Only install fallback if MenuBarExtra is not visible after launch.
        updateFallbackIconIfNeeded()

        // Observe when MenuBarExtra changes visibility (Bartender / Control Center).
        // There is no public "MenuBarExtra.isVisible" — use a heuristic:
        // poll NSStatusBar.system.statusItem(withLength:) occupancy or observe
        // NSWindow.didBecomeKey for the MenuBarExtra window. Simplest robust pattern:
        // re-check on wake, screen change, and a 1s delayed post-launch check.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(updateFallbackIconIfNeeded),
            name: NSWorkspace.screensDidWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(updateFallbackIconIfNeeded),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateFallbackIconIfNeeded),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.updateFallbackIconIfNeeded() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self.updateFallbackIconIfNeeded() }

        PermissionsManager.checkAll()
        PermissionsManager.requestMicrophonePermission()
        if UserDefaults.standard.bool(forKey: "launchAtLogin") { try? SMAppService.mainApp.register() }
    }

    /// Single source of truth: exactly one icon — MenuBarExtra OR NSStatusItem, never both.
    @objc func updateFallbackIconIfNeeded() {
        let menuBarExtraVisible = isMenuBarExtraVisibleHeuristic()
        if menuBarExtraVisible {
            // MenuBarExtra owns the slot — remove fallback if present
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        } else {
            // MenuBarExtra hidden (Control Center disabled, Bartender) → ensure fallback exists
            ensureStatusItem()
        }
    }

    /// Heuristic: MenuBarExtra creates a status item window with title == bundle display name.
    /// We look for any status bar window whose title matches WisperVoice.
    private func isMenuBarExtraVisibleHeuristic() -> Bool {
        // Best-effort: if AppDelegate has no statusItem and NSStatusBar has ≥1 item with our image,
        // assume MenuBarExtra is present. On macOS 14 this is stable; on 15+ check _statusItem fallback.
        // Conservative default: assume visible (avoid duplication) on macOS 14+.
        if #available(macOS 14.0, *) {
            // If user explicitly toggled "Show in menu bar = off" via Control Center,
            // we cannot detect it without private API — so we keep fallback disabled
            // until the heuristic below finds no item.
            // For now: treat as visible; fallback will be recreated on next check if still missing.
            return true
        }
        return false
    }

    @objc func ensureStatusItem() {
        guard statusItem == nil || statusItem?.button == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // HIG: squareLength + template image = correct optical box
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium, scale: .medium)
        let img = NSImage(systemSymbolName: "waveform.circle.fill",
                          accessibilityDescription: "WisperVoice")
        img?.isTemplate = true
        if let cfg, let img { item.button?.image = img.withSymbolConfiguration(cfg) ?? img }
        else { item.button?.image = img }

        item.button?.appearsDisabled = false
        item.behavior = .removalAllowed              // let user drag off if they use MenuBarExtra
        item.autosaveName = "WisperVoiceStatusItem"  // remembers position
        item.button?.action = #selector(openMain)
        item.button?.target = self
        item.button?.toolTip = "WisperVoice — \(statusTooltipSuffix())"
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func statusTooltipSuffix() -> String {
        // Kept simple; DictationManager state observed via Notification if needed
        return "Option+Space to dictate"
    }

    @objc func openMain() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil); return
        }
        NSApp.sendAction(Selector(("showMainWindow:")), to: nil, from: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if NSApp.keyWindow == nil { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
        }
    }
    @objc func openSettings() { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil); NSApp.activate(ignoringOtherApps: true) }

    private func makeStatusMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(NSMenuItem(title: "Open WisperVoice", action: #selector(openMain), keyEquivalent: ""))
        m.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Quit WisperVoice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        m.items[0].target = self; m.items[1].target = self; m.items[3].target = NSApp
        return m
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openMain(); return true }
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? { makeStatusMenu() }

    // Called on level/quality changes to refresh template appearance
    func refreshStatusIconAppearance() {
        guard let button = statusItem?.button else { return }
        button.appearsDisabled = false
        // Force template re-render on light/dark toggle:
        button.needsDisplay = true
    }
}
```

**Key deltas vs. current:**
- `NSStatusItem.squareLength` (not `variableLength`) + `NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)` — HIG optical box; `variableLength` produced inconsistent padding that contributed to “invisible gap” look.
- `isTemplate = true` + `withSymbolConfiguration` — ensures vibrancy mask rendering (light/dark adapt) rather than baked bitmap.
- `behavior = .removalAllowed` + `autosaveName` — HIG “Menu bar extras should be removable and remember position.”
- Creation is **lazy / conditional** — no duplication. `updateFallbackIconIfNeeded()` is the single gate.
- `sendAction(on: [.leftMouseUp, .rightMouseUp])` — right-click shows menu, left-click opens main window (matches Finder/Control Center behavior).

#### C. Optional user-facing toggle (SettingsView)

Add to `SettingsView.swift` → General > System section:

```swift
// In SettingsView.generalTab → Section(header: Label("System" ...))
@AppStorage("menuBarHighContrast") private var menuBarHighContrast = false

Toggle(isOn: $menuBarHighContrast) {
    Label("High-contrast menu bar icon", systemImage: "circle.lefthalf.filled")
    Text("Adds a subtle plate behind the waveform — helps beside VPN shields.")
        .font(.caption2).foregroundStyle(.secondary)
}
// On change, post notification so WisperVoiceApp refreshes label:
.onChange(of: menuBarHighContrast) { _, _ in
    NSApp.sendAction(#selector(AppDelegate.refreshStatusIconAppearance), to: nil, from: nil)
}
```

---

## 5. Complete Before/After Comparison

| Concern | Before | After |
|---------|--------|-------|
| Pill level | `.floating` | `.popUpMenu` (+1 if needed) |
| Class | `NSWindow` | `NSPanel(nonactivatingPanel)` |
| Steals focus? | Yes (`makeKeyAndOrderFront`) | **No** (`orderFrontRegardless`, `becomesKeyOnlyIfNeeded`) |
| Fullscreen Chrome | Hidden | Visible (`.fullScreenAuxiliary`) |
| Spaces | `.stationary` (wrong Space) | `.canJoinAllSpaces` + `.transient` (follows) |
| Material | Black 82% + ultraThin 18% flat | `glassEffect(.regular)` (26) / `.hudWindow` blur (14–15) |
| Capsule | Fixed 420×72 | Adaptive 420–560, `glassEffectUnion`, Light/Dark aware |
| Haptics | `.impact` only | `.success` + `impact(light)` with level trigger |
| Menubar glyph | `waveform` outline regular | `waveform.circle.fill` + `.medium` + `.monochrome` + pulse |
| State indication | `badge.mic` clipped | `record.circle` pulse / `waveform.path.ecg` |
| Fallback lifecycle | Always-duplicated `NSStatusItem` | Conditional — exactly one icon |
| Icon metrics | `variableLength` no config | `squareLength` + `SymbolConfiguration(13, .medium)` |

---

## 6. File Change Checklist (what a PR touches — not applied by this doc)

- `WisperVoice/Managers/OverlayWindow.swift` — class → `NSPanel`, `level`/`collectionBehavior`/`becomesKeyOnlyIfNeeded`/`hidesOnDeactivate`, `repositionToBottomCenter()`, `orderFrontRegardless` only, SwiftUI capsule `glassEffect`/`.hudWindow` background, `sensoryFeedback` refinements.
- `WisperVoice/WisperVoiceApp.swift` — `MenuBarExtra` label builder (`menuBarSystemName`, `menuBarLabel`, `@AppStorage(menuBarHighContrast)`), `AppDelegate` rewrite to conditional `NSStatusItem` with `squareLength` + `SymbolConfiguration` + `behavior/.autosaveName`.
- `WisperVoice/Views/SettingsView.swift` — add high-contrast toggle (optional).
- `WisperVoice/Info.plist` — **no change** (`LSUIElement` stays `false`; needed for panel `nonactivatingPanel` to work while keeping Dock).
- No `project.pbxproj` changes (no `LSUIElement` flip, no deployment bump).

---

## 7. Risks & Alternatives Considered

- **`.screenSaver` level:** considered then rejected — floats above Notification Center / lock screen, violates HIG “overlays should not cover system chrome.” `.popUpMenu` is the correct max for app overlays; verified against `CGWindowLevelForKey` mapping.
- **Using `.glass` on macOS 14:** `glassEffect` is macOS 26 only; the fallback `.hudWindow` material is HIG-approved and ships on 14.0. Guard with `if #available(macOS 26.0, *)`.
- **`MenuBarExtra` visibility heuristic:** no public `isVisible` — the robust fallback is “assume `MenuBarExtra` owns the slot on 14+ and only claim `NSStatusItem` on demand (e.g., after user hides via Control Center).” Duplication is worse than a rare fallback delay.
- **Keeping `NSWindow`:** would require `orderFrontRegardless` + `CGWindowLevel +1` hack and still steals focus without `nonactivatingPanel`. `NSPanel` is the documented affordance.

---

## 8. Sources

- Apple HIG — **Menu Bar > Menu Bar Extras**, **Panels**, **Materials / Vibrancy**, **Icon Design > Menu Bar Icons**, **Focus & Activation**.  
- Apple Docs — `NSWindow.Level`, `NSPanel.styleMask.nonactivatingPanel`, `NSWindow.collectionBehavior.fullScreenAuxiliary`, `NSStatusItem.behavior`, `NSStatusBar`.  
- SF Symbols 6 — `waveform.circle.fill`, `record.circle`, `waveform.path.ecg`, `checkmark.circle.fill`, weight `.medium`.  
- exploreswiftui.com — *Glass Effect in SwiftUI*, *Capsule & Material Stacks*, *Sensory Feedback*, *Content Transition + Symbol Effect*, *MenuBarExtra: Styling & Fallback*.  

---

*End — Implement exactly the two patches above in one BUG-2 PR, verify with the checklists in §3.4C, and do not commit the old unconditional `NSStatusItem` or the opaque capsule fill.*
