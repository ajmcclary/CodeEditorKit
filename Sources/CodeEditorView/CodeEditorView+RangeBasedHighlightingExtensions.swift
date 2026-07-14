import CodeEditorHighlightingCore
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
            if let externalProvider = highlightingController.externalHighlightProvider {
                // Host injected a value-oriented provider via the public seam
                // (`setExternalHighlightProvider(_:)` / `.codeEditorHighlightProvider(_:)`
                // / `EditorController.setExternalHighlightProvider(_:)`). It
                // becomes the controller's primary provider, replacing the
                // built-in regex/SwiftSyntax adapter.
                rangeBasedHighlightingController = RangeBasedHighlightingController(
                    textView: self,
                    language: language,
                    valueProvider: externalProvider
                )
            } else {
                rangeBasedHighlightingController = RangeBasedHighlightingController(
                    textView: self,
                    language: language,
                    externalProvider: nil
                )
            }
        }

        containerView?.minimapDataProvider?.styleDataSource = rangeBasedHighlightingController?.styleDataSource
        rangeBasedHighlightingController?.refreshVisibleRange()
    }
}
