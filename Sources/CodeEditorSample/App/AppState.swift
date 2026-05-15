import CodeEditorPlugin
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
    /// Active editor theme. Mirrored to `\.codeEditorTheme` and to
    /// `.preferredColorScheme` at the scene root.
    var theme: Theme = ThemeCatalog.default

    /// Active editor configuration. Bound directly from the knob panels;
    /// flows into the editor via `\.codeEditorConfiguration`.
    var configuration: EditorConfiguration = PresetCatalog.default.configuration

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

    /// Multi-tab document collection backing `EditorTabStrip` and the
    /// editor pane. Lives here (rather than as `@State` inside
    /// `RootWindow`) so the Settings window can observe and mutate the
    /// active language. Framework type; sample-side file I/O and
    /// Untitled-N naming come from
    /// `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift`.
    let documents = EditorDocuments()

    /// Imperative editor façade. Attached to the live `CodeEditor` via
    /// the `.editorController(_:)` modifier; sample features (find,
    /// goto, fold, annotations) all dispatch through this.
    let editorController = EditorController()

    /// Retains the `editorController.onAttach` subscription that wires
    /// the annotations data source after the SwiftUI representable
    /// attaches the underlying view. Dropping this would cancel the
    /// registration; we keep it for the lifetime of `AppState`.
    @ObservationIgnored
    private var attachToken: AnyCancellable?

    /// Annotations data source backing both the breakpoint-toggle demo
    /// and the TODO/FIXME knobs. Held strongly here because
    /// `CodeEditorView.annotationsDataSource` is `weak`.
    let annotationsHub: AnnotationsHub

    /// Shared `UnifiedEventSystem` for the sample. Wired into the editor view
    /// via `.eventSystem(_:)` in both `WindowBody` (macOS) and `IOSRootView`
    /// (iOS). The framework's `CodeEditorView.publishEvent(_:)` fans events
    /// into this instance.
    let eventSystem = UnifiedEventSystem()

    /// Cross-platform EventLog coordinator. Subscribes to `eventSystem` for
    /// framework-emitted EditorEvents and to `editorController.completionEvents()`
    /// for completion activity.
    let eventLog = EventLogSampleCoordinator()

    /// Find / replace feature-scoped model. Owns query text, options,
    /// overlay visibility, debounce / clear lifecycle, and the
    /// derived match counters. First slice of the AppState
    /// decomposition tracked by NEXT.md A.3 #1.
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

    #if canImport(AppKit)
    /// Shared `MemoryMonitor` instance fed into both `lsp` and `performance`
    /// coordinators so the panel readouts and LSP coordination agree on a
    /// single source of memory truth.
    let memoryMonitor = MemoryMonitor()

    /// Shared `PerformanceObservation` instance. Installed onto the
    /// editor view via `.performanceObserver(_:)` (which wires its
    /// underlying `UnifiedPerformanceSystem` into the framework's
    /// effective configuration AND surfaces refresh snapshots through
    /// `lastInsights`). The sample's `performance` coordinator reads
    /// snapshots from `performanceObservation.lastInsights` rather than
    /// polling `generateInsights()` directly.
    let performanceObservation = PerformanceObservation(refreshInterval: .seconds(1))

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
        // The controller is freshly constructed above — its
        // codeEditorView is nil, so a direct call to
        // setAnnotationsDataSource here would be a silent no-op.
        // Defer the install until the SwiftUI representable attaches
        // the underlying view.
        attachToken = editorController.onAttach { [weak hub] ctrl in
            guard let hub else { return }
            ctrl.setAnnotationsDataSource(hub)
        }
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
                  let activeID = documents.activeID,
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

        // Performance Inspector wiring. The shared `performanceObservation`
        // is also passed to `.performanceObserver(_:)` on the editor view
        // in `WindowBody.editorPane`, which is what actually injects its
        // underlying system into the framework's effective configuration.
        let perfCoordinator = PerformanceSampleCoordinator(
            memoryMonitor: memoryMonitor,
            performanceObservation: performanceObservation
        )
        perfCoordinator.attach(controller: editorController)
        self.performance = perfCoordinator

        let completionCoordinator = CompletionSampleCoordinator()
        self.completion = completionCoordinator

        completionCoordinator.attach(controller: editorController)
        #endif

        // EventLog coordinator wiring. Cross-platform — wires the shared
        // UnifiedEventSystem and the controller's completionEvents() into the
        // unified ring buffer that `EventLogPanel` renders.
        eventLog.attach(controller: editorController, eventSystem: eventSystem)

        #if canImport(AppKit)
        // Workspace surface wiring. Picks up any initial workspaceRoot.
        // Subsequent changes (Open Folder… menu, knob section, etc.) are
        // routed through `.onChange(of: appState.workspaceRoot)` on the
        // `WorkspaceSidebar` host in `WindowBody`.
        workspaceModel.setRoot(workspaceRoot)
        let initialRoot = workspaceRoot
        Task { @MainActor [projectSearchModel] in
            await projectSearchModel.setRoot(initialRoot)
        }
        #endif
    }

    /// Logs the result of a `DocumentStore.save(_:)` call so the user sees
    /// feedback when ⌘S fires from the menu. Kept on `AppState` rather than
    /// `DocumentStore` so the document model stays free of CrossPlatformLogger
    /// (the store is consumed by tests that don't want platform logging
    /// pulled in).
    func handleSaveOutcome(_ outcome: EditorDocuments.SaveOutcome) {
        let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorSample", category: "DocumentStore")
        switch outcome {
        case let .saved(url):
            logger.info("Saved \(url.path)")

        case .untitled:
            logger.warning("Tab is untitled — Save-As is not implemented in the demo.")

        case .noTab:
            logger.warning("Save invoked with no active tab.")

        case let .failed(error):
            logger.error("Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Save / Open command orchestration

    /// `⌘S` command handler. Tries `documents.save()`; if the active tab
    /// has no URL, transparently chains to `requestSaveAs()` so the user
    /// gets the save panel instead of a silent log entry. All other
    /// outcomes route to `handleSaveOutcome`.
    @MainActor
    func requestSave() {
        let outcome = documents.save()
        if case .untitled = outcome {
            requestSaveAs()
        } else {
            handleSaveOutcome(outcome)
        }
    }

    /// `⇧⌘S` command handler. Presents the platform save panel, then
    /// rebinds the active document to the chosen URL via
    /// `EditorDocuments.saveAs(to:)`.
    @MainActor
    func requestSaveAs() {
        guard let active = documents.active else {
            handleSaveOutcome(.noTab)
            return
        }
        #if canImport(AppKit)
        DocumentPicker.save(
            suggestedName: active.name,
            defaultDirectory: workspaceRoot ?? active.url?.deletingLastPathComponent()
        ) { [self] url in
            let outcome = documents.saveAs(to: url)
            handleSaveOutcome(outcome)
        }
        #else
        pendingSaveAs = prepareSaveAsTemporaryFile(for: active)
        #endif
    }

    /// `⇧⌘O` command handler. Presents the platform open panel and feeds
    /// the picked URL into `EditorDocuments.openFile(url:)`. If the URL is
    /// already open, the existing tab is activated.
    @MainActor
    func requestOpenFile() {
        #if canImport(AppKit)
        DocumentPicker.openFile(defaultDirectory: workspaceRoot) { [self] url in
            documents.openFile(url: url)
        }
        #else
        pendingOpenFile = true
        #endif
    }

    // MARK: - Save/open sheet state (iOS)

    #if !canImport(AppKit)
    /// State driving the iOS Save-As sheet. `IOSRootView` binds
    /// `.sheet(item: $appState.pendingSaveAs)`; setting nil dismisses.
    var pendingSaveAs: SaveSheetState?

    /// State driving the iOS Open File… sheet. `IOSRootView` binds
    /// `.sheet(isPresented: $appState.pendingOpenFile)`.
    var pendingOpenFile: Bool = false

    /// Writes the active document's text to `NSTemporaryDirectory()/<name>`
    /// so `UIDocumentPickerViewController(forExporting:asCopy: false)` has
    /// a file to move to the user's chosen destination. Returns the
    /// `SaveSheetState` that drives the export sheet, or nil if the temp
    /// write fails (failure is reported through `handleSaveOutcome`).
    @MainActor
    private func prepareSaveAsTemporaryFile(for active: EditorDocument) -> SaveSheetState? {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(active.name)
        do {
            try active.text.write(to: tempURL, atomically: true, encoding: .utf8)
            return SaveSheetState(temporaryURL: tempURL, suggestedName: active.name)
        } catch {
            handleSaveOutcome(.failed(error: error))
            return nil
        }
    }

    /// Invoked by `ExportDocumentSheet.onPick` after the user confirms the
    /// iOS document picker. Performs the rebind via `EditorDocuments.saveAs`
    /// and routes the outcome through the standard feedback channel.
    @MainActor
    func finalizeSaveAs(to url: URL) {
        let outcome = documents.saveAs(to: url)
        handleSaveOutcome(outcome)
    }
    #endif
}
