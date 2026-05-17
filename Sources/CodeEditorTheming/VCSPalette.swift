import CodeEditorDesignTokens
import Foundation

/// VCS-state palette covering seven kinds (created/modified/deleted/renamed/
/// ignored/hidden/unreachable), each with `base`, `background`, and `border`
/// keys in Zed JSON. Maps closely to git diff state.
public struct VCSPalette: Hashable, Sendable, Codable {
    /// One VCS entry — base color plus background/border tints.
    public struct VCS: Hashable, Sendable, Codable {
        /// Foreground / accent color for the VCS state.
        public let base: Tokens.Color
        /// Background fill for VCS-state regions.
        public let background: Tokens.Color
        /// Border for VCS-state regions.
        public let border: Tokens.Color

        /// Memberwise builder.
        public init(base: Tokens.Color, background: Tokens.Color, border: Tokens.Color) {
            self.base = base
            self.background = background
            self.border = border
        }
    }

    /// New file or addition.
    public let created: VCS
    /// Modified content.
    public let modified: VCS
    /// Deleted content.
    public let deleted: VCS
    /// Renamed file.
    public let renamed: VCS
    /// Ignored by VCS.
    public let ignored: VCS
    /// Hidden in tree.
    public let hidden: VCS
    /// Unreachable / unborn.
    public let unreachable: VCS

    /// Memberwise builder.
    public init(
        created: VCS,
        modified: VCS,
        deleted: VCS,
        renamed: VCS,
        ignored: VCS,
        hidden: VCS,
        unreachable: VCS
    ) {
        self.created = created
        self.modified = modified
        self.deleted = deleted
        self.renamed = renamed
        self.ignored = ignored
        self.hidden = hidden
        self.unreachable = unreachable
    }

    /// Build from a flat dictionary keyed by Zed dotted names. `appearance`
    /// selects between light and dark fallback colors when a key is missing.
    init(
        flat: [String: Tokens.Color],
        warnings: WarningCollector,
        path: String,
        appearance: Theme.Appearance
    ) {
        func make(_ kind: String, fallback: Tokens.Color) -> VCS {
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
            return VCS(base: base, background: bg, border: border)
        }
        self.created = make("created", fallback: ThemeFallbackPalette.status(.success, appearance: appearance))
        self.modified = make("modified", fallback: ThemeFallbackPalette.status(.info, appearance: appearance))
        self.deleted = make("deleted", fallback: ThemeFallbackPalette.status(.error, appearance: appearance))
        self.renamed = make("renamed", fallback: ThemeFallbackPalette.status(.info, appearance: appearance))
        self.ignored = make("ignored", fallback: ThemeFallbackPalette.textDisabled(appearance))
        self.hidden = make("hidden", fallback: ThemeFallbackPalette.textDisabled(appearance))
        self.unreachable = make("unreachable", fallback: ThemeFallbackPalette.textMuted(appearance))
    }

    /// Emit own keys back into a flat dictionary.
    package func flatten(into dict: inout [String: Tokens.Color]) {
        for (kind, vcs) in [
            ("created", created), ("modified", modified), ("deleted", deleted),
            ("renamed", renamed), ("ignored", ignored), ("hidden", hidden),
            ("unreachable", unreachable)
        ] {
            dict[kind] = vcs.base
            dict["\(kind).background"] = vcs.background
            dict["\(kind).border"] = vcs.border
        }
    }
}
