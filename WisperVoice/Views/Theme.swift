import SwiftUI
import AppKit

extension Color {
    /// Adaptive color from separate light/dark values, mirroring how `designTokens.js`
    /// keeps a `light`/`dark` branch per token instead of one fixed hex.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}

/// The whole app's palette, in one place — mirrors `website/src/designTokens.js` so the app
/// and marketing site read as one product. Change `accent` or `alert` here and every surface
/// follows. Do not introduce new hues in views; if something needs emphasis, use weight, size,
/// or an SF Symbol rather than another color.
///
///   accent       — brand, interactive, selection, progress, success/active (ink, adaptive)
///   violetAccent — legacy/secondary brand hue, used sparingly for one-off "brand moments"
///   alert        — recording, errors, missing permissions, destructive (app-only, no web equivalent)
///   neutral      — .primary / .secondary / .tertiary + system materials
enum Theme {
    /// The site's ink-neutral, adaptive: `#111113` in light, `#f1f1f3` in dark — see
    /// `designTokens.js` `colors.light.ink[900]` / `colors.dark.bodyText`.
    static let accent = Color(
        light: Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x13 / 255),
        dark: Color(red: 0xf1 / 255, green: 0xf1 / 255, blue: 0xf3 / 255)
    )
    /// Content sitting on an `accent`-filled surface. Ink flips light/dark, so this must
    /// flip the opposite way — plain `.white` disappears in dark mode.
    static let onAccent = Color(
        light: Color.white,
        dark: Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x13 / 255)
    )
    /// The site's former primary hue, now reserved for sparing "brand moment" accents —
    /// see `designTokens.js` `colors.light.violet[600]`. Not used for default interactive state.
    static let violetAccent = Color(red: 0.36, green: 0.35, blue: 0.84)
    /// The one attention hue. Recording, errors, problems, destructive actions.
    static let alert = Color(red: 0.85, green: 0.26, blue: 0.30)

    // MARK: Opacity tokens
    // Previously ~30 ad-hoc alpha values were doing the work of about six roles.
    /// Hairline borders and rims.
    static let hairline: Double = 0.08
    /// Tinted fills behind icons and banners.
    static let subtleFill: Double = 0.12
    /// Hover / pressed / selected fills.
    static let softFill: Double = 0.18
    /// Ambient elevation shadow.
    static let shadow: Double = 0.10

    // MARK: Shape tokens
    // Two steps only, mirroring `layout.radius.card`/`cardSm` scaled for native density —
    // views must not use literal corner radii.
    /// Card-level surfaces: popover body, onboarding cards, banners.
    static let radiusCard: CGFloat = 16
    /// Inline controls: fields, rows, small chips.
    static let radiusControl: CGFloat = 10

    // MARK: Motion
    /// The site's `ease.soft` `cubic-bezier(0.16,1,0.3,1)` at `duration.fast` (180 ms).
    static let motion = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.18)

    // MARK: Type tokens
    /// Transcript body text — was 12 / 12.5 / 13pt in three different files for one role.
    static let transcript = Font.system(size: 12.5, design: .rounded)
    /// Compact labels inside the pill and popover rows.
    static let compact = Font.system(size: 11.5, design: .rounded)

    // MARK: Type scale
    // Character here comes from weight/tracking/size contrast rather than a bundled
    // display face — a native menu-bar utility that ships its own font reads as foreign.
    /// Hero numerals and headline status text.
    static let display = Font.system(size: 30, weight: .semibold, design: .rounded)
    /// Small uppercase group label (applied with tracking by `SectionLabel`).
    static let sectionLabel = Font.system(size: 11, weight: .semibold)
    /// Card and row titles.
    static let rowTitle = Font.system(size: 13.5, weight: .semibold)
    /// Secondary line under a row title.
    static let rowMeta = Font.system(size: 11.5)
    /// Measurements, counts, sizes — always monospaced so digits don't jitter.
    static let numeral = Font.system(size: 12, weight: .medium, design: .monospaced)
    /// Large monospaced figure for stat tiles.
    static let statFigure = Font.system(size: 22, weight: .semibold, design: .rounded)

    // MARK: Surfaces
    /// Card fill — sits one step above the window background in both appearances.
    static let cardFill = Color(
        light: Color.white,
        dark: Color(red: 0.105, green: 0.105, blue: 0.115)
    )
    /// Inset wells inside a card (fields, code, transcript blocks).
    static let wellFill = Color(
        light: Color(red: 0.96, green: 0.96, blue: 0.97),
        dark: Color(red: 0.07, green: 0.07, blue: 0.08)
    )
    /// Hairline border color pair (the `hairline` constant above is the opacity token).
    static let border = Color.primary.opacity(0.09)

    // MARK: On-glass neutrals (the overlay pill is a fixed dark surface)
    static let onGlass = Color.white
    static let onGlassPrimary = Color.white.opacity(0.92)
    static let onGlassSecondary = Color.white.opacity(0.62)
    static let glassBody = Color.black.opacity(0.82)

    /// Single source of truth for what each dictation state looks like.
    /// Only two hues are in play — idle is neutral, recording is `alert`, and both working
    /// states are `accent`, told apart by their icon and label rather than by color.
    static func color(for state: DictationState) -> Color {
        switch state {
        case .idle: return .secondary
        case .recording: return alert
        case .transcribing, .injecting: return accent
        }
    }

    /// Same mapping for the overlay pill, which is a fixed dark surface where `.secondary`
    /// would be unreadable.
    static func onGlassColor(for state: DictationState) -> Color {
        state == .idle ? onGlassSecondary : color(for: state)
    }
}

// MARK: - Shared components
// These live in Theme.swift on purpose: the Xcode project lists sources explicitly, so a
// new file would need a pbxproj edit, and Theme is already compiled into both targets.

/// Small uppercase tracked label that opens a group of cards. Replaces default `Form`
/// section headers, which give every screen the same undifferentiated look.
struct SectionLabel: View {
    let title: String
    var systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(title.uppercased())
                .font(Theme.sectionLabel)
                .tracking(0.9)
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 2)
    }
}

/// The one container shape in the app: hairline-bordered surface at `radiusCard`.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

/// One line of a settings card: title (+ optional explanation) left, control right.
/// Fixes the ragged `Form` rows where a control could float far from its label.
struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.rowTitle)
                if let subtitle {
                    Text(subtitle).font(Theme.rowMeta).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            control
        }
        .padding(.vertical, 9)
    }
}

/// Hairline separator used between rows inside a card.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }
}

/// A single figure with a caption — used on the Dictate screen for real usage numbers.
struct StatTile: View {
    let figure: String
    let caption: String

    var body: some View {
        VStack(spacing: 3) {
            Text(figure).font(Theme.statFigure).contentTransition(.numericText())
            Text(caption.uppercased())
                .font(Theme.sectionLabel).tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Keyboard shortcut chip, e.g. ⌥ Space.
struct KeyChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.wellFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .foregroundStyle(.secondary)
    }
}

/// Standard page scaffold: section-labeled content on a measured column so the enlarged
/// window never stretches rows into thin ribbons.
struct Pane<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 24, weight: .semibold))
                    if let subtitle {
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 2)
                content
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
