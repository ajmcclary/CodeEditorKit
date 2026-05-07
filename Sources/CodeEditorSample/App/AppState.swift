import CodeEditorPlugin
import Foundation
import Observation

/// Top-level shared state for the sample app. Owned once by
/// `CodeEditorSampleApp` and injected into both the main window and the
/// Settings (cmd-,) window so changes made in either are reflected
/// instantly in the other.
@MainActor
@Observable
final class AppState {
    /// Active editor theme. Mirrored to `\.codeEditorTheme` and to
    /// `.preferredColorScheme` at the scene root.
    var theme: Theme = ThemeCatalog.default

    /// Active editor configuration. Bound directly from the knob panels;
    /// flows into the editor via `\.codeEditorConfiguration`.
    var configuration: EditorConfiguration = PresetCatalog.default.configuration

    /// Multi-tab document store backing `EditorTabStrip` and the editor
    /// pane. Lives here (rather than as `@State` inside `RootWindow`) so
    /// the Settings window can observe and mutate the active language.
    let documents: DocumentStore = DocumentStore()
}
