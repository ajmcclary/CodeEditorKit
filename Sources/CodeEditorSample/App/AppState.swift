import CodeEditorDiagnostics
import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorView
import Combine
import Foundation
import Observation

/// Top-level shared state for the sample app. Owned once by
/// `CodeEditorSampleApp` and injected into both the main window and the
/// Settings (cmd-,) window so changes made in either are reflected
/// instantly in the other.
@MainActor
@Observable
final class AppState {
    // MARK: - Slice models

    /// Active editor theme slice. First slice of the AppState
    /// decomposition (NEXT.md A.3 #1).
    let theme = ThemeModel()

    /// Active editor configuration slice. Second slice of the AppState
    /// decomposition (NEXT.md A.3 #1).
    let configuration = ConfigurationModel()

    /// Documents + EditorController + I/O slice. Third slice of the
    /// AppState decomposition (NEXT.md A.3 #1). IUO because its
    /// `workspaceRootProvider` closure must `[weak self]`-capture
    /// `self`, which Swift's definite-init analysis forbids during a
    /// `let` field assignment. Constructed once in `init()` and never
    /// reassigned thereafter — effectively a `let`. Not `private(set)`
    /// because the iOS root view's `.sheet(item: $appState.documents.X)`
    /// bindings need to project through this property on iOS, where
    /// strict-mode treats `IUO + private(set)` writes-through-class as
    /// requiring the parent's setter.
    var documents: DocumentsModel! // swiftlint:disable:this implicitly_unwrapped_optional

    // MARK: - Cross-cutting / un-extracted state

    /// Workspace root for runtime-only LSP/file integrations.
    var workspaceRoot: URL?

    #if canImport(AppKit)
    /// File-tree state + WorkspaceFileWatching subscription for the
    /// left-rail Files panel. macOS-only; iOS doesn't ship the
    /// workspace surface in the current sample.
    let workspaceModel = WorkspaceModel()

    /// Project-wide search state + PortableProjectSearchAdapter for the
    /// left-rail Search panel. macOS-only.
    let projectSearchModel = ProjectSearchModel()
    #endif

    /// Annotations data source backing both the breakpoint-toggle demo
    /// and the TODO/FIXME knobs. Held strongly here because
    /// `CodeEditorView.annotationsDataSource` is `weak`. IUO because
    /// `documents` (also IUO) is assigned first; Swift's
    /// definite-init analysis rejects `self.documents` access before
    /// all `let` properties are set, so both are written via `var`s.
    /// Set once in `init()` and never reassigned.
    private(set) var annotationsHub: AnnotationsHub! // swiftlint:disable:this implicitly_unwrapped_optional

    /// Shared `UnifiedEventSystem` for the sample. Wired into the
    /// editor view via `.eventSystem(_:)` in both `WindowBody` (macOS)
    /// and `IOSRootView` (iOS). The framework's
    /// `CodeEditorView.publishEvent(_:)` fans events into this instance.
    let eventSystem = UnifiedEventSystem()

    /// Cross-platform EventLog coordinator. Subscribes to `eventSystem`
    /// for framework-emitted EditorEvents and to
    /// `documents.editorController.completionEvents()` for completion
    /// activity.
    let eventLog = EventLogSampleCoordinator()

    /// Find / replace feature-scoped model. Owns query text, options,
    /// overlay visibility, debounce / clear lifecycle, and the derived
    /// match counters.
    let findReplace = FindReplaceModel()

    /// Whether the "Go to Line…" sheet is presented.
    var gotoLineSheetVisible: Bool = false

    /// Whether the "Go to Symbol…" sheet is presented.
    var gotoSymbolSheetVisible: Bool = false

    /// Whether the command palette overlay is visible. Owned here (not
    /// as `@State` on `RootWindow`) so the scene-level `.commands`
    /// shortcut can flip it without coordinating through a separate
    /// FocusedValue channel.
    var paletteVisible: Bool = false

    /// Shared `MemoryMonitor` instance fed into the `performance`
    /// coordinator (and into `lsp` on macOS) so memory readouts agree
    /// on a single source of truth.
    let memoryMonitor = MemoryMonitor()

    /// Shared `PerformanceObservation` instance. Installed onto the
    /// editor view via `.performanceObserver(_:)`.
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))

    /// Sample-side Performance Inspector coordinator. Cross-platform.
    /// IUO; see `documents` rationale.
    private(set) var performance: PerformanceSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional

    /// Sample-side Completion Inspector coordinator. Cross-platform.
    /// IUO; see `documents` rationale.
    private(set) var completion: CompletionSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional

    #if canImport(AppKit)
    /// Sample-side LSP coordinator. Owns the `LSPManager`, document
    /// mirroring, and the diagnostics bridge. macOS-only because
    /// `LSPManager` itself is AppKit-gated until B.1 iOS coverage lands.
    /// IUO; see `documents` rationale.
    private(set) var lsp: LSPSampleCoordinator! // swiftlint:disable:this implicitly_unwrapped_optional
    #endif

    init() {
        // DocumentsModel needs workspaceRoot for save/open default
        // directories. Weak self so the model never retains AppState.
        self.documents = DocumentsModel { [weak self] in self?.workspaceRoot }

        let hub = AnnotationsHub()
        self.annotationsHub = hub
        hub.controller = documents.editorController
        // The controller is freshly constructed inside DocumentsModel —
        // its codeEditorView is nil, so a direct call to
        // setAnnotationsDataSource(hub) here would be a silent no-op.
        // Defer the install until the SwiftUI representable attaches
        // the underlying view.
        documents.attachAnnotations(hub)

        #if canImport(AppKit)
        let coordinator = LSPSampleCoordinator(memoryMonitor: memoryMonitor)
        self.lsp = coordinator
        let storeRef = documents.store
        let editorControllerRef = documents.editorController
        coordinator.attach(
            controller: editorControllerRef,
            hub: hub
        ) { [weak coordinator, weak storeRef] in
            guard let coordinator,
                  let store = storeRef,
                  let activeID = store.activeID,
                  let url = coordinator.mirrorURL(for: activeID) else { return nil }
            return "file://" + url.path
        }
        coordinator.onRequestOpen = { [weak storeRef] url in
            storeRef?.openFile(url: url)
        }
        coordinator.onRequestScroll = { [weak editorControllerRef] line in
            editorControllerRef?.gotoLine(line)
        }
        #endif

        // Performance Inspector wiring. Cross-platform.
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            performanceObservation: performanceObservation,
            documentMetrics: ActiveDocumentMetricsProvider(documents: documents.store),
            textLayoutMetrics: EditorTextLayoutMetricsProvider(
                controller: documents.editorController
            )
        )
        perfCoordinator.attach(controller: documents.editorController)
        self.performance = perfCoordinator

        // Completion Inspector wiring. Cross-platform.
        let completionCoordinator = CompletionSampleCoordinator()
        self.completion = completionCoordinator
        completionCoordinator.attach(controller: documents.editorController)

        // EventLog coordinator wiring. Cross-platform.
        eventLog.attach(
            controller: documents.editorController,
            eventSystem: eventSystem
        )

        #if canImport(AppKit)
        // Workspace surface wiring. Picks up any initial workspaceRoot.
        // Subsequent changes (Open Folder… menu, knob section, etc.)
        // are routed through `.onChange(of: appState.workspaceRoot)`
        // on the `WorkspaceSidebar` host in `WindowBody`.
        workspaceModel.setRoot(workspaceRoot)
        let initialRoot = workspaceRoot
        Task { @MainActor [projectSearchModel] in
            await projectSearchModel.setRoot(initialRoot)
        }
        #endif
    }
}
