import Foundation

/// Umbrella namespace for the CodeEditor design token system.
///
/// All static design values (typography, spacing, shape, opacity, animation,
/// size, fallback palette) live under this enum. Theme-dependent (semantic)
/// colors live in `CodeEditorPlugin`'s `Theme` type, not here.
public enum Tokens {
    /// Tokens schema version. Bumped on backwards-incompatible token changes.
    public static let schemaVersion = "1.0.0"
}
