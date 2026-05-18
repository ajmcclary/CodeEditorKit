import CodeEditorSwiftUI
import Foundation

/// Umbrella namespace for the `CodeEditorUI` target.
///
/// Holds a stable module identifier so consumers can verify the module
/// loaded; otherwise purely metadata. All concrete API — chrome views,
/// styles, the glass surface — lives in sibling files under `Window/`,
/// `TabStrip/`, `StatusBar/`, `Sidebar/`, `Breadcrumb/`,
/// `CommandPalette/`, and `Glass/`.
public enum CodeEditorUI {
    /// Stable module identifier. Useful as a probe in tests and as a
    /// stamp in any per-target diagnostics.
    public static let identifier: String = "CodeEditorUI"
}
