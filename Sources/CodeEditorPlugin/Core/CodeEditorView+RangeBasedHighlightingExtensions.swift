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
            // Check if Tree-sitter highlighting is enabled for this language
            let externalProvider: (any RangeHighlightProviding)?
            if configuration.behavior.useTreeSitterHighlighting {
                externalProvider = TreeSitterRangeHighlightProvider.makeSpikeProvider(for: language)
            } else {
                externalProvider = nil
            }

            rangeBasedHighlightingController = RangeBasedHighlightingController(
                textView: self,
                language: language,
                externalProvider: externalProvider
            )
        }

        containerView?.minimapDataProvider?.styleDataSource = rangeBasedHighlightingController?.styleDataSource
        rangeBasedHighlightingController?.refreshVisibleRange()
    }
}
