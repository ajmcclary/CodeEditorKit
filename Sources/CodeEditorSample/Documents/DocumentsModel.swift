import CodeEditorCommon
import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorView
import Combine
import Foundation
import Observation

/// Documents + EditorController + I/O slice of AppState. Owns the
/// multi-tab `EditorDocuments` store, the framework's imperative
/// `EditorController` façade, the controller-onAttach token that wires
/// the AnnotationsHub data source, and the Save / Save-As / Open
/// orchestration (cross-platform, with iOS sheet state). Third slice of
/// the AppState decomposition (NEXT.md A.3 #1).
@MainActor
@Observable
final class DocumentsModel {
    /// Multi-tab document collection. Renamed from `documents` to
    /// `store` to avoid the awkward `appState.documents.documents`
    /// call shape after composition.
    let store = EditorDocuments()

    /// Imperative editor façade. Attached to the live `CodeEditor` via
    /// the `.editorController(_:)` modifier; sample features (find,
    /// goto, fold, annotations) all dispatch through this.
    let editorController = EditorController()

    /// Retains the `editorController.onAttach` subscription that wires
    /// the annotations data source after the SwiftUI representable
    /// attaches the underlying view. Dropping this would cancel the
    /// registration; kept for the model's lifetime.
    @ObservationIgnored
    private var attachToken: AnyCancellable?

    /// Closure returning the AppState-owned workspace root. Used as
    /// the default directory for save / open panels. Closure rather
    /// than stored URL so DocumentsModel doesn't have to mirror
    /// workspace state.
    @ObservationIgnored
    private let workspaceRootProvider: @MainActor () -> URL?

    #if !canImport(AppKit)
    /// State driving the iOS Save-As sheet. `IOSRootView` binds
    /// `.sheet(item: $appState.documents.pendingSaveAs)`; nil dismisses.
    var pendingSaveAs: SaveSheetState?

    /// State driving the iOS Open File… sheet. `IOSRootView` binds
    /// `.sheet(isPresented: $appState.documents.pendingOpenFile)`.
    var pendingOpenFile: Bool = false
    #endif

    init(workspaceRootProvider: @escaping @MainActor () -> URL?) {
        self.workspaceRootProvider = workspaceRootProvider
    }

    /// Wires the annotations data source onto the editor view once
    /// SwiftUI attaches it. Called by `AppState.init()` after both this
    /// model and the AnnotationsHub are constructed because the hub is
    /// not owned by this slice.
    func attachAnnotations(_ hub: AnnotationsHub) {
        attachToken = editorController.onAttach { [weak hub] ctrl in
            guard let hub else { return }
            ctrl.setAnnotationsDataSource(hub)
        }
    }

    /// Logs the result of a `EditorDocuments.save(_:)` call so the user
    /// sees feedback when ⌘S fires from the menu.
    func handleSaveOutcome(_ outcome: EditorDocuments.SaveOutcome) {
        let logger = CodeEditorLog.sample(category: "DocumentStore")
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

    /// `⌘S` command handler. Tries `store.save()`; if the active tab
    /// has no URL, transparently chains to `requestSaveAs()` so the
    /// user gets the save panel instead of a silent log entry.
    func requestSave() {
        let outcome = store.save()
        if case .untitled = outcome {
            requestSaveAs()
        } else {
            handleSaveOutcome(outcome)
        }
    }

    /// `⇧⌘S` command handler. Presents the platform save panel, then
    /// rebinds the active document to the chosen URL via
    /// `EditorDocuments.saveAs(to:)`.
    func requestSaveAs() {
        guard let active = store.active else {
            handleSaveOutcome(.noTab)
            return
        }
        #if canImport(AppKit)
        DocumentPicker.save(
            suggestedName: active.name,
            defaultDirectory: workspaceRootProvider() ?? active.url?.deletingLastPathComponent()
        ) { [self] url in
            let outcome = store.saveAs(to: url)
            handleSaveOutcome(outcome)
        }
        #else
        pendingSaveAs = prepareSaveAsTemporaryFile(for: active)
        #endif
    }

    /// `⇧⌘O` command handler. Presents the platform open panel and
    /// feeds the picked URL into `EditorDocuments.openFile(url:)`.
    func requestOpenFile() {
        #if canImport(AppKit)
        DocumentPicker.openFile(defaultDirectory: workspaceRootProvider()) { [self] url in
            store.openFile(url: url)
        }
        #else
        pendingOpenFile = true
        #endif
    }

    #if !canImport(AppKit)
    /// Writes the active document's text to
    /// `NSTemporaryDirectory()/<name>` so
    /// `UIDocumentPickerViewController(forExporting:asCopy: false)` has
    /// a file to move to the user's chosen destination.
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

    /// Invoked by `ExportDocumentSheet.onPick` after the user confirms
    /// the iOS document picker. Performs the rebind via
    /// `EditorDocuments.saveAs` and routes the outcome through the
    /// standard feedback channel.
    func finalizeSaveAs(to url: URL) {
        let outcome = store.saveAs(to: url)
        handleSaveOutcome(outcome)
    }
    #endif
}
