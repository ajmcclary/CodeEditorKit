import Foundation

extension CodeEditorView {
    internal func updateRangeBasedHighlightingConfiguration() {
        guard configuration.performance.usesRangeBasedHighlighting else {
            rangeBasedHighlightingController?.detach()
            rangeBasedHighlightingController = nil
            containerView?.minimapDataProvider?.styleDataSource = nil
            return
        }

        if rangeBasedHighlightingController?.currentLanguage != language {
            rangeBasedHighlightingController?.detach()
            rangeBasedHighlightingController = nil
        }

        if rangeBasedHighlightingController == nil {
            rangeBasedHighlightingController = RangeBasedHighlightingController(
                textView: self,
                language: language,
                externalProvider: nil
            )
        }

        #if canImport(AppKit)
        registerSemanticTokenProviderIfAvailable()
        #endif

        containerView?.minimapDataProvider?.styleDataSource = rangeBasedHighlightingController?.styleDataSource
        rangeBasedHighlightingController?.refreshVisibleRange()
    }

    #if canImport(AppKit)
    internal func registerSemanticTokenProviderIfAvailable() {
        guard let stp = lspSemanticTokenProvider,
              let controller = rangeBasedHighlightingController else {
            return
        }
        stp.onTokensUpdated = { [weak self, weak stp] indices in
            guard let self, let stp else { return }
            self.rangeBasedHighlightingController?.invalidateSupplementalProvider(stp, indices: indices)
        }
        controller.registerSupplementalProvider(stp, priority: -1)
    }
    #endif
}
