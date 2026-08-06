import SwiftUI

/// The whole app's palette, in one place.
///
/// Deliberately two chromatic colors and a neutral ramp — nothing else. Change `accent` or
/// `alert` here and every surface follows. Do not introduce new hues in views; if something
/// needs emphasis, use weight, size, or an SF Symbol rather than another color.
///
///   accent  — brand, interactive, selection, progress, success/active
///   alert   — recording, errors, missing permissions, destructive
///   neutral — .primary / .secondary / .tertiary + system materials
enum Theme {
    /// The one brand hue. Everything interactive or affirmative uses this.
    static let accent = Color(red: 0.36, green: 0.35, blue: 0.84)
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

    // MARK: Type tokens
    /// Transcript body text — was 12 / 12.5 / 13pt in three different files for one role.
    static let transcript = Font.system(size: 12.5, design: .rounded)
    /// Compact labels inside the pill and popover rows.
    static let compact = Font.system(size: 11.5, design: .rounded)

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
