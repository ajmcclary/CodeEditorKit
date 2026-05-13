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

    /// Workspace root for runtime-only LSP/file integrations.
    var workspaceRoot: URL?

    /// Multi-tab document store backing `EditorTabStrip` and the editor
    /// pane. Lives here (rather than as `@State` inside `RootWindow`) so
    /// the Settings window can observe and mutate the active language.
    let documents = DocumentStore()

    /// Imperative editor façade. Attached to the live `CodeEditor` via
    /// the `.editorController(_:)` modifier; sample features (find,
    /// goto, fold, annotations) all dispatch through this.
    let editorController = EditorController()

    /// Annotations data source backing both the breakpoint-toggle demo
    /// and the TODO/FIXME knobs. Held strongly here because
    /// `CodeEditorView.annotationsDataSource` is `weak`.
    let annotationsHub: AnnotationsHub

    /// Whether the find/replace overlay is pinned to the top of the
    /// editor pane.
    var findOverlayVisible: Bool = false

    /// Persisted find query — survives palette/overlay toggles.
    var findText: String = ""

    /// Persisted replace string.
    var replaceText: String = ""

    /// Whether the "Go to Line…" sheet is presented.
    var gotoLineSheetVisible: Bool = false

    /// Whether the "Go to Symbol…" sheet is presented.
    var gotoSymbolSheetVisible: Bool = false

    /// Whether the command palette overlay is visible. Owned here (not
    /// as `@State` on `RootWindow`) so the scene-level `.commands`
    /// shortcut can flip it without coordinating through a separate
    /// FocusedValue channel.
    var paletteVisible: Bool = false

    #if canImport(AppKit)
    /// Sample-side LSP coordinator. Owns the `LSPManager`, document
    /// mirroring, and the diagnostics bridge. macOS-only (process spawning
    /// is unavailable on iOS, so the LSP demo doesn't ship on that
    /// platform). Adding it to AppState contradicts the deferred refactor
    /// in `docs/superpowers/specs/2026-05-13-sample-app-lsp-integration-design.md`
    /// (splitting AppState into feature-scoped models); the LSP wiring
    /// uses the existing god-object pattern for now.
    let lsp: LSPSampleCoordinator
    #endif

    init() {
        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = editorController
        editorController.setAnnotationsDataSource(hub)
        #if canImport(AppKit)
        let coordinator = LSPSampleCoordinator(memoryMonitor: MemoryMonitor())
        self.lsp = coordinator
        let documentsRef = documents
        coordinator.attach(
            controller: editorController,
            hub: hub
        ) { [weak coordinator, weak documentsRef] in
            guard let coordinator,
                  let documents = documentsRef,
                  let activeID = documents.activeTabID,
                  let url = coordinator.mirrorURL(for: activeID) else { return nil }
            return "file://" + url.path
        }
        #endif
    }
}
