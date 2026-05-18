import CodeEditorConfiguration
import CodeEditorPlugin
import CodeEditorSwiftUI
import Observation

/// Active editor configuration. Bound directly from the knob panels;
/// flows into the editor via `\.codeEditorConfiguration`. Second slice
/// of the AppState decomposition (NEXT.md A.3 #1) — future home for
/// JSON import/export and validation (NEXT.md A.3 #5).
@MainActor
@Observable
final class ConfigurationModel {
    /// Currently active editor configuration. Read by the chrome and
    /// every knob panel.
    var current: EditorConfiguration

    init(initial: EditorConfiguration = PresetCatalog.default.configuration) {
        self.current = initial
    }
}
