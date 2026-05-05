import CodeEditorDesignTokens
import Foundation

/// Bridges between Zed's `"#rrggbb[aa]"` hex-string color format and
/// `Tokens.Color`. `Tokens.Color`'s synthesized `Codable` reads
/// `{red,green,blue,alpha}` objects — that's the right shape for our token
/// snapshots but the wrong shape for Zed JSON. This file is the single point
/// of translation.
enum ZedColorBridge {
    /// Parse a Zed-format hex string. Records a `.malformedColor` warning and
    /// returns nil on failure; the caller decides whether to substitute a
    /// fallback (and emit a corresponding `.missingKey`).
    static func parse(_ hex: String, path: String, warnings: WarningCollector) -> Tokens.Color? {
        if let color = Tokens.Color(hexString: hex) { return color }
        warnings.record(.init(kind: .malformedColor, keyPath: path, detail: hex))
        return nil
    }

    /// Encode a Tokens.Color as Zed-format hex. `#RRGGBB` when alpha == 1,
    /// `#RRGGBBAA` otherwise.
    static func encode(_ color: Tokens.Color) -> String {
        color.hexString
    }
}
