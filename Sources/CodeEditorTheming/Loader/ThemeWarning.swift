import Foundation

/// A non-fatal issue encountered while decoding a theme. Accumulates in a
/// `WarningCollector` rather than throwing, so a single typo or missing key
/// doesn't block an otherwise-loadable theme.
public struct ThemeWarning: Hashable, Sendable, CustomStringConvertible {
    /// Categories of decode-time issues that can be recorded as warnings
    /// rather than thrown errors.
    public enum Kind: String, Sendable, Hashable, Codable {
        /// A required key was absent; a default was substituted.
        case missingKey = "missing_key"
        /// A hex string couldn't parse as `#rrggbb` or `#rrggbbaa`.
        case malformedColor = "malformed_color"
        /// A key under `platform.*` wasn't recognized; preserved in `extras`.
        case unknownPlatformKey = "unknown_platform_key"
        /// Defensive — the same key appeared more than once in source JSON.
        case duplicateKey = "duplicate_key"
    }

    /// What kind of issue this warning records.
    public let kind: Kind
    /// Dotted key path identifying where the issue occurred
    /// (e.g., `editor.gutter.background`, `syntax.keyword.color`).
    public let keyPath: String
    /// Optional supplemental detail — for `.malformedColor`, the raw input string.
    public let detail: String?

    /// Build a warning record.
    public init(kind: Kind, keyPath: String, detail: String? = nil) {
        self.kind = kind
        self.keyPath = keyPath
        self.detail = detail
    }

    public var description: String {
        if let detail {
            return "[\(kind.rawValue)] \(keyPath): \(detail)"
        }
        return "[\(kind.rawValue)] \(keyPath)"
    }
}
