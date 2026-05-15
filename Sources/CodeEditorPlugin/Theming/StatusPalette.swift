import CodeEditorDesignTokens
import Foundation

/// Status palette covering five kinds (info/success/warning/error/conflict),
/// each with `base`, `background`, and `border` keys in Zed JSON.
public struct StatusPalette: Hashable, Sendable, Codable {
    /// One status entry — base color plus background/border tints.
    public struct Status: Hashable, Sendable, Codable {
        /// Foreground / accent color for the status.
        public let base: Tokens.Color
        /// Background fill for status badges/banners.
        public let background: Tokens.Color
        /// Border for status badges/banners.
        public let border: Tokens.Color

        /// Memberwise builder.
        public init(base: Tokens.Color, background: Tokens.Color, border: Tokens.Color) {
            self.base = base
            self.background = background
            self.border = border
        }
    }

    /// Informational status.
    public let info: Status
    /// Success status.
    public let success: Status
    /// Warning status.
    public let warning: Status
    /// Error status.
    public let error: Status
    /// Merge-conflict status.
    public let conflict: Status

    /// Memberwise builder.
    public init(info: Status, success: Status, warning: Status, error: Status, conflict: Status) {
        self.info = info
        self.success = success
        self.warning = warning
        self.error = error
        self.conflict = conflict
    }

    /// Build from a flat dictionary keyed by Zed dotted names. `appearance`
    /// selects between light and dark fallback colors when a key is missing.
    init(
        flat: [String: Tokens.Color],
        warnings: WarningCollector,
        path: String,
        appearance: Theme.Appearance
    ) {
        func make(
            _ kind: String, fallbackKind: ThemeFallbackPalette.StatusKind
        ) -> Status {
            let fallback = ThemeFallbackPalette.status(fallbackKind, appearance: appearance)
            let base = flat[kind]
                ?? warnings.missing(path: path, key: kind, fallback: fallback)
            let bgFallback = Tokens.Color(
                red: base.red, green: base.green, blue: base.blue, alpha: 0.15
            )
            let bg = flat["\(kind).background"]
                ?? warnings.missing(
                    path: path, key: "\(kind).background", fallback: bgFallback
                )
            let border = flat["\(kind).border"]
                ?? warnings.missing(path: path, key: "\(kind).border", fallback: base)
            return Status(base: base, background: bg, border: border)
        }
        self.info = make("info", fallbackKind: .info)
        self.success = make("success", fallbackKind: .success)
        self.warning = make("warning", fallbackKind: .warning)
        self.error = make("error", fallbackKind: .error)
        self.conflict = make("conflict", fallbackKind: .conflict)
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        for (kind, status) in [
            ("info", info), ("success", success), ("warning", warning),
            ("error", error), ("conflict", conflict)
        ] {
            dict[kind] = status.base
            dict["\(kind).background"] = status.background
            dict["\(kind).border"] = status.border
        }
    }
}
