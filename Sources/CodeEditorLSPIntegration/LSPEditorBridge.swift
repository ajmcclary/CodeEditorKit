import CodeEditorLSP
import CodeEditorView
import Foundation

/// Opt-in bridge that wires Language Server Protocol integration onto a
/// `CodeEditorView`.
///
/// LSP is no longer baked into `CodeEditorView`'s default session — the editor
/// target carries no dependency on `CodeEditorLSP`. Hosts that want language
/// server features depend on the `CodeEditorLSPIntegration` product and create
/// an `LSPEditorBridge` for a view:
///
/// ```swift
/// let bridge = LSPEditorBridge(view: editorView, workspaceRoot: root)
/// bridge.setUpDocument(filePath: path, languageId: "swift")
/// // … later …
/// bridge.detach()
/// ```
///
/// The bridge owns the `LSPManager` (previously created by the editor's memory
/// coordinator) and the document-scoped synchronization that feeds
/// `textDocument/didChange` notifications and semantic-token highlights back
/// into the editor.
@MainActor
public final class LSPEditorBridge {
    /// The language-server manager owned by this bridge.
    public let lspManager: LSPManager

    private weak var view: CodeEditorView?
    private let documentController = LSPDocumentController()

    /// Creates a bridge and attaches it to `view`.
    ///
    /// - Parameters:
    ///   - view: The editor to integrate with.
    ///   - workspaceRoot: Optional workspace root advertised to language servers.
    public init(view: CodeEditorView, workspaceRoot: URL? = nil) {
        self.view = view
        self.lspManager = LSPManager(
            memoryMonitor: view.memoryMonitor,
            workspaceRoot: workspaceRoot
        )
        documentController.attach(to: view)
    }

    /// Begins document-scoped LSP synchronization for the given file.
    ///
    /// Call after opening the document on a server via
    /// ``lspManager``. Edits are batched to `textDocument/didChange` and the
    /// editor's semantic-token highlights refresh once the server acknowledges
    /// each batch.
    ///
    /// - Parameters:
    ///   - filePath: Absolute path to the file being edited.
    ///   - languageId: LSP language identifier (e.g. `"swift"`).
    public func setUpDocument(filePath: String, languageId: String) {
        documentController.configure(
            manager: lspManager,
            filePath: filePath,
            languageId: languageId
        )
    }

    /// Stops all document-scoped LSP coordination and detaches from the view.
    public func detach() {
        documentController.detach()
    }
}
