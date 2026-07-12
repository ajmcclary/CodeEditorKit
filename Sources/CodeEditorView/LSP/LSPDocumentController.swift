import CodeEditorLSP

/// Teardown surface for document-scoped LSP coordination.
@MainActor
package protocol LSPContentCoordinating: AnyObject {
    /// Stops observing edits and cancels pending document synchronization.
    func detach()
}

extension LSPContentCoordinator: LSPContentCoordinating {}

/// Owns document-scoped LSP synchronization without owning the shared manager.
@MainActor
package final class LSPDocumentController: EditorFeatureController {
    private weak var attachedView: CodeEditorView?
    private var contentCoordinator: (any LSPContentCoordinating)?
    internal var semanticTokenProvider: LSPSemanticTokenProvider?
    package private(set) var isAttached = false

    package init() {}

    package func attach(to view: CodeEditorView) {
        guard isAttached == false || attachedView !== view else { return }

        detach()
        attachedView = view
        isAttached = true
    }

    package func detach() {
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

    package func install(contentCoordinator: any LSPContentCoordinating) {
        self.contentCoordinator?.detach()
        self.contentCoordinator = contentCoordinator
    }

    internal var concreteContentCoordinator: LSPContentCoordinator? {
        contentCoordinator as? LSPContentCoordinator
    }

    internal func configure(
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
        coordinator.onBatchFlushed = { [weak view, weak self] in
            guard let view, let provider = self?.semanticTokenProvider else { return }
            provider.refreshAfterBatch(textView: view)
        }

        #if canImport(AppKit)
        view.registerSemanticTokenProviderIfAvailable()
        #endif
    }
}
