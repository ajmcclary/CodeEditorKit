import CodeEditorDesignTokens
import Foundation

/// Accumulates `ThemeWarning`s during a decode pass. Lives on
/// `JSONDecoder.userInfo` under `.themeWarnings`, mutated by the various
/// sub-struct flat-init constructors as they encounter missing or malformed
/// keys. Single-threaded by the decoder contract — `JSONDecoder.decode` runs
/// synchronously on the calling thread, so no locking is required.
final class WarningCollector: @unchecked Sendable {
    /// Warnings recorded so far, in insertion order.
    private(set) var warnings: [ThemeWarning] = []

    /// Append a warning record.
    package func record(_ warning: ThemeWarning) {
        warnings.append(warning)
    }

    /// Convenience: record a `.missingKey` warning and return the supplied
    /// fallback so call sites can read as
    /// `self.muted = flat["text.muted"] ?? warnings.missing(path: ..., key: ..., fallback: ...)`.
    package func missing<T>(path _: String, key: String, fallback: T) -> T {
        warnings.append(.init(kind: .missingKey, keyPath: key, detail: nil))
        return fallback
    }
}

/// Mutable carrier for the current theme's `appearance` during decode. The
/// outer `Theme.init(from:)` decodes the `appearance` key before the nested
/// `style` decode runs, then writes it here so `ThemeStyle` and its leaf
/// palettes can pick light vs. dark fallback colors. `JSONDecoder.userInfo`
/// is itself a `let`, so we hang a class on it and mutate that.
final class AppearanceHolder: @unchecked Sendable {
    /// Appearance for the theme currently being decoded; defaults to `.dark`
    /// so that pre-pass reads (before `Theme.init(from:)` sets it) match the
    /// historical behavior.
    package var appearance: Theme.Appearance = .dark
}

extension CodingUserInfoKey {
    /// Slot for a `WarningCollector` on a configured `JSONDecoder.userInfo`.
    /// `CodingUserInfoKey(rawValue:)` is a failable initializer for purely
    /// defensive reasons; in practice it always succeeds on a non-empty
    /// string, so the guard is functionally unreachable.
    static let themeWarnings: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "themeWarnings") else {
            fatalError("CodingUserInfoKey rejected non-empty string literal")
        }
        return key
    }()

    /// Slot for an `AppearanceHolder` carrying the in-flight theme's
    /// appearance value across nested decoders.
    package static let themeAppearance: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "themeAppearance") else {
            fatalError("CodingUserInfoKey rejected non-empty string literal")
        }
        return key
    }()
}
