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
            // Check if Tree-sitter highlighting is enabled for this language.
            // Gated behind CAN_IMPORT_TREE_SITTER (Phase 7 packaging) so the
            // core editor compiles without the Tree-sitter module.
            let externalProvider: (any RangeHighlightProviding)?
            #if CAN_IMPORT_TREE_SITTER
            if configuration.behavior.useTreeSitterHighlighting {
                externalProvider = TreeSitterRangeHighlightProvider.makeProvider(for: language)
            } else {
                externalProvider = nil
            }
            #else
            externalProvider = nil
            #endif

            rangeBasedHighlightingController = RangeBasedHighlightingController(
                textView: self,
                language: language,
                externalProvider: externalProvider
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
