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

        containerView?.minimapDataProvider?.styleDataSource = rangeBasedHighlightingController?.styleDataSource
        rangeBasedHighlightingController?.refreshVisibleRange()
    }
}
