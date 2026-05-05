import CodeEditorDesignTokens
import Foundation

/// Stub namespace for the public `Theme` type. The full type lands in
/// Task 7 of the theme rewrite plan as a `struct`; here we ship only the
/// `Appearance` enum (held inside a caseless `enum Theme` namespace) so
/// leaf sub-struct files can reference `Theme.Appearance` during their
/// own task implementations without needing the full struct yet.
public enum Theme {
    /// Whether a theme is intended for dark or light environments.
    public enum Appearance: String, Sendable, Hashable, Codable {
        /// Dark-environment theme.
        case dark
        /// Light-environment theme.
        case light
    }
}
