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
    /// Shared `MemoryMonitor` instance fed into both `lsp` and `performance`
    /// coordinators so the panel readouts and LSP coordination agree on a
    /// single source of memory truth.
    let memoryMonitor = MemoryMonitor()

    /// Shared `UnifiedPerformanceSystem` instance: installed on
    /// `configuration.performance.unifiedPerformanceSystem` so the framework's
    /// syntax highlighter records into it, and polled by `performance` for
    /// the `Last highlight` / `Highlight p95` panel readouts.
    let unifiedPerformanceSystem = UnifiedPerformanceSystem()

    /// Sample-side LSP coordinator. Owns the `LSPManager`, document
    /// mirroring, and the diagnostics bridge. macOS-only (process spawning
    /// is unavailable on iOS, so the LSP demo doesn't ship on that
    /// platform). The LSP wiring uses the existing god-object pattern in
    /// `AppState`; a future refactor may split it into feature-scoped
    /// models.
    let lsp: LSPSampleCoordinator

    /// Sample-side Performance Inspector coordinator. Owns the framework
    /// monitors and snapshots them on a 1Hz timer for
    /// `PerformanceInspectorPanel`. macOS-only.
    let performance: PerformanceSampleCoordinator

    /// Sample-side Completion Inspector coordinator. Registers built-in
    /// language providers (eight) plus a demo provider on attach, decorates
    /// each with telemetry, and snapshots controller stats on a 1Hz timer
    /// for `CompletionInspectorPanel`. macOS-only.
    let completion: CompletionSampleCoordinator
    #endif

    init() {
        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = editorController
        editorController.setAnnotationsDataSource(hub)
        #if canImport(AppKit)
        let coordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
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
        let controllerRef = editorController
        coordinator.onRequestOpen = { [weak documentsRef] url in
            documentsRef?.openFile(url: url)
        }
        coordinator.onRequestScroll = { [weak controllerRef] line in
            controllerRef?.gotoLine(line)
        }

        // Performance Inspector wiring. Assign `performance` BEFORE mutating
        // `configuration` so the @Observable macro doesn't trip on an
        // uninitialized stored property when writing through `self`.
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            unifiedPerformanceSystem: unifiedPerformanceSystem
        )
        perfCoordinator.attach(controller: editorController)
        self.performance = perfCoordinator

        let completionCoordinator = CompletionSampleCoordinator()
        self.completion = completionCoordinator

        // Both observable coordinators must be assigned before mutating
        // `configuration` through `self`; otherwise the @Observable macro
        // trips on an uninitialized stored property.
        self.configuration.performance.unifiedPerformanceSystem = unifiedPerformanceSystem
        completionCoordinator.attach(controller: editorController)
        #endif
    }
}
