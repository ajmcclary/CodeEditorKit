import CodeEditorLayout
import Foundation

/// Cancellation boundary for highlighting implementations owned by a session.
@MainActor
package protocol HighlightingCancelling: AnyObject {
    /// Cancels active work and releases lifecycle-scoped resources.
    func cancelAll()
}

extension AsyncSyntaxHighlighter: HighlightingCancelling {
    package func cancelAll() {
        cancelAllHighlighting()
        cleanup()
    }
}

/// Owns syntax-highlighting attachment, cancellation, and range styling state.
@MainActor
package final class HighlightingController: EditorFeatureController {
    private weak var attachedView: CodeEditorView?
    private var cancellation: any HighlightingCancelling

    internal var rangeBasedController: RangeBasedHighlightingController?
    package private(set) var isAttached = false

    package init(cancellation: any HighlightingCancelling) {
        self.cancellation = cancellation
    }

    package func attach(to view: CodeEditorView) {
        guard isAttached == false || attachedView !== view else { return }

        detach()
        attachedView = view
        isAttached = true
    }

    package func detach() {
        guard isAttached else { return }

        cancellation.cancelAll()
        rangeBasedController?.detach()
        rangeBasedController = nil
        attachedView?.containerView?.minimapDataProvider?.styleDataSource = nil
        attachedView = nil
        isAttached = false
    }

    package func replaceCancellation(with newCancellation: any HighlightingCancelling) {
        guard ObjectIdentifier(cancellation) != ObjectIdentifier(newCancellation) else { return }

        if isAttached {
            cancellation.cancelAll()
        }
        cancellation = newCancellation
    }

    package var styleDataSource: (any MinimapStyleDataSource)? {
        rangeBasedController?.styleDataSource
    }

    package func applyFullDocument() {
        guard let view = attachedView else { return }

        view.updateRangeBasedHighlightingConfiguration()
        let syntaxService = view.featureDependencies.syntaxHighlightingService
        let textLength = view.textKitBridge.documentLength

        view.adaptivePerformanceMode.updateMode(
            for: textLength,
            language: view.language
        )

        var updatedConfiguration = view.configuration
        let lineNumbers = view.configuration.display.isLineNumbersEnabled
        let codeFolding = view.configuration.display.isCodeFoldingEnabled
        let syntaxHighlighting = view.configuration.display.isSyntaxHighlightingEnabled

        view.adaptivePerformanceMode.applyConfiguration(to: &updatedConfiguration)
        updatedConfiguration.display.isLineNumbersEnabled = lineNumbers
        updatedConfiguration.display.isCodeFoldingEnabled = codeFolding
        updatedConfiguration.display.isSyntaxHighlightingEnabled = syntaxHighlighting

        if view.configuration != updatedConfiguration {
            view.configuration = updatedConfiguration
        }

        guard syntaxService.shouldApplySyntaxHighlighting(
            isEnabled: view.isSyntaxHighlightingEnabled,
            textLength: textLength,
            maxLength: view.configuration.performance.maxSyntaxHighlightingLength
        ) else {
            syntaxService.cancelHighlighting(asyncHighlighter: view.asyncHighlighter)
            return
        }

        guard isRangeStorePrimary(for: view) == false else { return }
        syntaxService.scheduleHighlighting(
            asyncHighlighter: view.asyncHighlighter,
            textView: view,
            language: view.language,
            visibleRange: nil
        )
    }

    package func apply(in range: NSRange) {
        guard let view = attachedView,
              isRangeStorePrimary(for: view) == false else { return }

        let syntaxService = view.featureDependencies.syntaxHighlightingService
        let textLength = view.textKitBridge.documentLength
        guard syntaxService.isValidHighlightingRange(range, textLength: textLength),
              syntaxService.shouldApplySyntaxHighlighting(
                isEnabled: view.isSyntaxHighlightingEnabled,
                textLength: textLength,
                maxLength: view.configuration.performance.maxSyntaxHighlightingLength
              ) else { return }

        syntaxService.scheduleHighlighting(
            asyncHighlighter: view.asyncHighlighter,
            textView: view,
            language: view.language,
            visibleRange: range
        )
    }

    package func cancelActiveWork() {
        guard let view = attachedView else { return }
        view.featureDependencies.syntaxHighlightingService.cancelHighlighting(
            asyncHighlighter: view.asyncHighlighter
        )
    }

    private func isRangeStorePrimary(for view: CodeEditorView) -> Bool {
        view.configuration.display.useRangeStoreHighlighting
            && rangeBasedController != nil
    }
}
