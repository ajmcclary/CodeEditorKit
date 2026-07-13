import CodeEditorLSP
import CodeEditorView
import Foundation

/// Teardown surface for document-scoped LSP coordination.
@MainActor
protocol LSPContentCoordinating: AnyObject {
    /// Stops observing edits and cancels pending document synchronization.
    func detach()
}

extension LSPContentCoordinator: LSPContentCoordinating {}

/// Owns document-scoped LSP synchronization for a single editor view without
/// owning the shared manager.
///
/// This controller lives in the `CodeEditorLSPIntegration` product. It reaches
/// the editor only through package-visible seams (the value-oriented
/// supplemental-provider API on the range-based highlighting controller and
/// the text-edit event hub), so `CodeEditorView` carries no LSP dependency.
@MainActor
final class LSPDocumentController {
    private weak var attachedView: CodeEditorView?
    private var contentCoordinator: (any LSPContentCoordinating)?
    private var semanticTokenProvider: LSPSemanticTokenProvider?
    private(set) var isAttached = false

    init() {}

    func attach(to view: CodeEditorView) {
        guard isAttached == false || attachedView !== view else { return }

        detach()
        attachedView = view
        isAttached = true
    }

    func detach() {
        guard isAttached else { return }

        if let semanticTokenProvider {
            attachedView?.rangeBasedHighlightingController?
                .unregisterSupplementalProvider(semanticTokenProvider)
            semanticTokenProvider.onTokensUpdated = nil
        }
        semanticTokenProvider = nil
        contentCoordinator?.detach()
        contentCoordinator = nil
        attachedView = nil
        isAttached = false
    }

    /// Installs a document content coordinator directly, replacing any
    /// existing one. Primarily used by tests to inject a spy coordinator.
    func install(contentCoordinator: any LSPContentCoordinating) {
        self.contentCoordinator?.detach()
        self.contentCoordinator = contentCoordinator
    }

    func configure(
        manager: LSPManager,
        filePath: String,
        languageId: String
    ) {
        guard let view = attachedView else { return }

        contentCoordinator?.detach()
        if let semanticTokenProvider {
            view.rangeBasedHighlightingController?
                .unregisterSupplementalProvider(semanticTokenProvider)
            semanticTokenProvider.onTokensUpdated = nil
        }

        let coordinator = LSPContentCoordinator(
            textView: view,
            lspManager: manager,
            filePath: filePath,
            languageId: languageId
        )
        contentCoordinator = coordinator

        let provider = LSPSemanticTokenProvider(
            lspManager: manager,
            filePath: filePath
        )
        semanticTokenProvider = provider
        provider.onTokensUpdated = { [weak view, weak provider] indices in
            guard let view, let provider else { return }
            view.rangeBasedHighlightingController?
                .invalidateSupplementalProvider(provider, indices: indices)
        }
        coordinator.onBatchFlushed = { [weak provider] in
            provider?.refreshAfterBatch()
        }

        view.rangeBasedHighlightingController?
            .registerSupplementalProvider(provider, priority: -1)
    }
}
