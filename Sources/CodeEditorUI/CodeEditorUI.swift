import Foundation

/// Umbrella namespace for the `CodeEditorUI` target.
///
/// Holds a stable module identifier so consumers can verify the module
/// loaded; otherwise purely metadata. All concrete API — chrome views,
/// styles, the glass surface — lives in sibling files under `Window/`,
/// `TabStrip/`, `StatusBar/`, `Sidebar/`, `Breadcrumb/`,
/// `CommandPalette/`, and `Glass/`.
///
/// ## Topics
///
/// ### Window chrome
///
/// - ``EditorTrafficLights``
/// - ``TrafficLightsConfiguration``
/// - ``EditorTitleBar``
///
/// ### Tab strip
///
/// - ``EditorTabStrip``
/// - ``EditorTab``
/// - ``EditorTabStripStyle``
/// - ``EditorTabStripStyleConfiguration``
/// - ``DefaultEditorTabStripStyle``
/// - ``CompactEditorTabStripStyle``
///
/// ### Status bar & breadcrumb
///
/// - ``EditorStatusBar``
/// - ``EditorBreadcrumbView``
///
/// ### Sidebar
///
/// - ``EditorSidebarShell``
///
/// ### Command palette
///
/// - ``EditorCommandPalette``
/// - ``EditorCommandPaletteRow``
/// - ``EditorCommandPaletteStyle``
/// - ``EditorCommandPaletteStyleConfiguration``
/// - ``DefaultEditorCommandPaletteStyle``
/// - ``CommandPaletteItem``
///
/// ### Liquid Glass
///
/// - ``PlatformGlassSurface``
public enum CodeEditorUI {
    /// Stable module identifier. Useful as a probe in tests and as a
    /// stamp in any per-target diagnostics.
    public static let identifier: String = "CodeEditorUI"
}
