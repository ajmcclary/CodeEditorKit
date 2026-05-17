import CodeEditorDesignTokens
import Foundation

/// Internal substitution table used when a Zed JSON omits a known color key.
/// Values are tuned for visual sanity rather than exact match to any
/// particular external theme — when a real theme value is missing, we want
/// the editor to render *something readable*, not crash. Split by appearance
/// because dark/light themes need different substitutes.
///
/// Functions take a `Theme.Appearance` to keep call sites short. When the
/// caller doesn't have an appearance handy yet (e.g., during the first pass
/// of a leaf sub-struct decode, before the `Theme` wrapper is built), passing
/// `.dark` is fine — Zed Trek's variants are predominantly dark and the
/// substitute will be replaced by a real value in well-formed JSON.
enum ThemeFallbackPalette {
    static func textBase(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0xDF_E7_F1) : Tokens.Color(hex: 0x1C_1C_1E)
    }
    static func textMuted(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x8B_99_AB) : Tokens.Color(hex: 0x6E_6E_73)
    }
    static func textPlaceholder(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x68_77_8C) : Tokens.Color(hex: 0x9E_9E_A3)
    }
    static func textDisabled(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x4F_5D_70) : Tokens.Color(hex: 0xC7_C7_CC)
    }
    static func textAccent(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Palette.Accent.dark : Tokens.Palette.Accent.light
    }

    static func iconBase(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0xC5_D1_DF) : Tokens.Color(hex: 0x3A_3A_3C)
    }
    static func iconMuted(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x76_86_99) : Tokens.Color(hex: 0x8E_8E_93)
    }
    static func iconAccent(_ appearance: Theme.Appearance) -> Tokens.Color {
        textAccent(appearance)
    }
    static func iconDisabled(_ appearance: Theme.Appearance) -> Tokens.Color {
        textDisabled(appearance)
    }
    static func iconPlaceholder(_ appearance: Theme.Appearance) -> Tokens.Color {
        textPlaceholder(appearance)
    }

    package static func background(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x02_02_04) : Tokens.Color(hex: 0xFF_FF_FF)
    }
    package static func surface(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x07_09_0F) : Tokens.Color(hex: 0xF2_F2_F7)
    }
    package static func border(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x1A_22_32) : Tokens.Color(hex: 0xD1_D1_D6)
    }
    static func dropTarget(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark
            ? Tokens.Color(red: 0x7E, green: 0xC8, blue: 0xDE, alpha: 0.15)
            : Tokens.Color(red: 0x00, green: 0x7A, blue: 0xFF, alpha: 0.15)
    }
    package static func clear() -> Tokens.Color { Tokens.Color(hex: 0x00_00_00, alpha: 0) }

    enum StatusKind { case info, success, warning, error, conflict }

    package static func status(_ kind: StatusKind, appearance: Theme.Appearance) -> Tokens.Color {
        switch (kind, appearance) {
        case (.info, .dark):     return Tokens.Palette.Status.infoDark
        case (.info, .light):    return Tokens.Palette.Status.infoLight
        case (.success, .dark):  return Tokens.Palette.Status.successDark
        case (.success, .light): return Tokens.Palette.Status.successLight
        case (.warning, .dark):  return Tokens.Palette.Status.warningDark
        case (.warning, .light): return Tokens.Palette.Status.warningLight
        case (.error, .dark):    return Tokens.Palette.Status.errorDark
        case (.error, .light):   return Tokens.Palette.Status.errorLight
        case (.conflict, .dark): return Tokens.Palette.Status.warningDark
        case (.conflict, .light): return Tokens.Palette.Status.warningLight
        }
    }
}
