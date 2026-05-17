import CodeEditorPlugin
import CodeEditorTheming
import Observation

/// Active editor theme. First wrapper extracted in the AppState
/// decomposition (NEXT.md A.3 #1). Owns the `Theme` value and acts as
/// a future home for theme authoring (e.g., load Zed JSON from disk).
@MainActor
@Observable
final class ThemeModel {
    /// Currently active theme. Mirrored to `\.codeEditorTheme` and to
    /// `.preferredColorScheme` at the scene root.
    var current: Theme

    init(initial: Theme = ThemeCatalog.default) {
        self.current = initial
    }
}
