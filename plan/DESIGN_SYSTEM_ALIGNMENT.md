# Design System Alignment — Website → App

**Decision (confirmed 2026-08-07):** the app adopts the website's palette as primary — ink-neutral (near-black/white) as the dominant accent, violet demoted to a secondary/legacy hue, matching `website/src/designTokens.js` exactly. Native idioms (SF font, system materials, `Form(.grouped)`) are kept; only the *token values* move, not the SwiftUI architecture.

## 1. Source of truth

`website/src/designTokens.js` is canonical. `WisperVoice/Views/Theme.swift` is rewritten to be its SwiftUI mirror — same roles, same values, translated to `Color`/`Font`/`CGFloat`.

## 2. Token mapping

| Role | Web token (`designTokens.js`) | New `Theme.swift` value |
|---|---|---|
| Primary accent (light) | `ink.900 #111113` | `Theme.accent` (light) = `#111113` |
| Primary accent (dark) | `bodyText #f1f1f3` (inverted ink) | `Theme.accent` (dark) = `#f1f1f3` |
| Secondary/legacy hue | `violet.600 #6d5aff` | `Theme.violetAccent` — used only where today's code leans on saturated color for meaning (recording waveform accent, onboarding "granted" tick), not as the default interactive color |
| Alert / recording | *(app-only, no web equivalent — website has no destructive/recording state)* | Keep `Theme.alert` as-is (`#d94349`-ish red), unchanged — this is app-specific semantics the site doesn't need |
| Neutral scale | `ink.50…950` | New `Theme.ink` scale (10 stops), replacing ad-hoc `.secondary`/`.tertiary`/opacity stacking where a specific step is meant |
| Hairline / border | `border.light.line #e8e8ec`, `border.dark.line #2e2e32` | `Theme.hairline` becomes a color pair, not just an opacity — keep the opacity-on-`.primary` fallback for places pulling from system content color |
| Radius — pill | `layout.radius.pill 9999` | already `Capsule()` — no change needed |
| Radius — card | `layout.radius.card 24px` / `cardSm 16px` | Views currently use 16/12/10/9/18 inconsistently → consolidate to two steps: `Theme.radiusCard = 16`, `Theme.radiusControl = 10` (native controls sit smaller than web cards; 24pt is too large for a menu-bar popover) |
| Motion | `duration.fast 180ms`, `ease.soft cubic-bezier(0.16,1,0.3,1)` | `Theme.motion` — `Animation.timingCurve(0.16,1,0.3,1, duration: 0.18)`, used in place of default `.easeInOut` calls |
| Typography | Inter / SF Pro Display, `hero/h2/body/small` scale | **Not ported 1:1.** Keep San Francisco (`.system`/`.rounded`) — HIG expects it, and the site's `hero`/`h2` scale is web-marketing-specific. Only the *rounded vs. non-rounded* usage gets an explicit rule (see §4). |

## 3. Dark mode parity

Website dark mode: pitch black body (`#000000`), elevated cards `#18181b`, borders `#2e2e32`, no shadows (flat). App today relies on system materials (`.ultraThinMaterial`, `.windowBackgroundColor`) which already adapt automatically and look correct in native dark mode — **do not flatten these to literal black**, since that fights macOS system appearance (vibrancy, translucency) and would look broken next to every other menu-bar app. Alignment here means: match the *elevation logic* (surface vs. card vs. border-on-dark) conceptually, not the literal hex values.

## 4. Concrete file changes

1. **`Theme.swift`** — rewrite:
   - Replace single `accent` with `accent` (ink, adaptive light/dark via `Color(light:dark:)` init or asset catalog color set) + `violetAccent` (secondary).
   - Add `ink` scale (at least 100/400/600/900 stops used elsewhere) to replace bare `.opacity()` stacking.
   - Add `radiusCard`/`radiusControl` constants; sweep views to use them instead of literal 9/10/12/16/18.
   - Add `motion` easing constant.
   - Keep `alert`, opacity tokens, `transcript`/`compact` fonts as-is — these are app-specific and have no web counterpart.
2. **Color asset catalog** — add `AccentInk` and `AccentViolet` color sets in `Assets.xcassets` with light/dark variants, so `Theme.swift` reads from the catalog (single place designers can tweak without recompiling logic) rather than hardcoding both branches in Swift.
3. **View sweep** (`MenuBarView`, `OnboardingView`, `SettingsView`, `ClipboardHistoryView`, `OverlayWindow`/`OverlayView`):
   - Everywhere `Theme.accent` is used for default interactive/active state (buttons, active picker rows, progress), it now resolves to ink instead of violet — verify nothing reads as "broken" without the color (SF Symbol + weight should still carry meaning, matching the site's low-chroma restraint).
   - Reserve `Theme.violetAccent` for the 1–2 spots that want a "brand moment" pop (e.g., onboarding success checkmark, or the pill's idle-to-recording transition glow) — mirrors how the site now uses violet sparingly as legacy/accent, not everywhere.
   - Replace literal `cornerRadius:` values with `Theme.radiusCard`/`Theme.radiusControl`.
4. **`OverlayWindow`/`OverlayView`** (the floating pill — closest native equivalent to the site's hero "cloud" pill) — check its glass capsule radius/shadow against `components.pill` token (`radius: 9999, padding: 12`) for padding parity; this is the one surface most users compare directly against the marketing site screenshots.

## 5. Verification

- `xcodebuild build -project WisperVoice.xcodeproj -scheme WisperVoice -derivedDataPath /tmp/wisper_build2 -quiet` after each file's edit.
- Manual pass: launch app in both System Settings → Appearance (light/dark), open menu bar popover, Settings window, onboarding flow, and trigger the pill (`⌥Space`) — compare side-by-side with `website` (`npm run dev`, light/dark toggle) for the ink/violet balance and radius feel.
- No automated visual regression exists for the app; note in `agents/AGENTS.md` after the pass that this was a manual side-by-side check, not a snapshot test.

## 6. Non-goals

- Not porting Inter/web fonts into the native app.
- Not flattening native materials/shadows to match the site's literal flat-black dark mode.
- Not touching `plan/CTO_PLAN.md`/`PM_PLAN.md` scope — this is a design-token pass, not a feature.
- Not building a shared codegen pipeline between `designTokens.js` and `Theme.swift` (considered, deferred — revisit only if the two drift again after this pass).

## 7. Sequencing

1. Add color assets + rewrite `Theme.swift` tokens (no view changes yet) → build must still succeed since call sites are unchanged (`Theme.accent` still resolves, just to a new value).
2. Sweep views for the new `violetAccent` reservations + radius constants, one file at a time, building after each.
3. Manual light/dark/pill verification pass (§5).
4. Update `agents/AGENTS.md` "What's Done" table with the pass and file list, per repo convention.
