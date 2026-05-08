import Foundation

/// Owns the range-store-backed highlighting pipeline for a single editor view.
///
/// This controller currently feeds minimap style data and visible-range
/// invalidation. It does not replace the legacy attributed-text highlighter.
@MainActor
internal final class RangeBasedHighlightingController: TextEditEventObserving {
    private weak var textView: CodeEditorView?
    private let language: Language
    private let container: StyledRangeContainer
    private let provider: SyntaxHighlighterRangeAdapter
    private let providerState: HighlightProviderState
    private let visibleRangeProvider: VisibleRangeProvider

    internal let styleDataSource: StyledMinimapStyleDataSource

    internal init(textView: CodeEditorView, language: Language) {
        self.textView = textView
        self.language = language

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let documentLength = textView.textStorage?.length ?? 0
        #else
        let documentLength = textView.textStorage.length
        #endif
        let highlighter = Self.makeHighlighter(for: language)
        let container = StyledRangeContainer(documentLength: documentLength)
        let providerID = container.registerProvider(priority: 0)
        let provider = SyntaxHighlighterRangeAdapter(highlighter: highlighter)

        self.container = container
        self.provider = provider
        self.providerState = HighlightProviderState(
            provider: provider,
            providerID: providerID,
            container: container,
            textView: textView,
            documentLength: documentLength
        )
        self.visibleRangeProvider = VisibleRangeProvider(textView: textView)
        self.styleDataSource = StyledMinimapStyleDataSource(container: container) { capture in
            TokenType(rawValue: capture)?.adaptiveColor ?? PlatformColors.label
        }

        provider.setUp(textView: textView, language: language)
        let state = providerState
        visibleRangeProvider.onVisibleSetChange = { [weak state] visible in
            state?.updateVisibleSet(visible)
        }
        textView.textEditEventHub.addObserver(self)
        providerState.updateVisibleSet(visibleRangeProvider.visibleIndices)
    }

    internal var currentLanguage: Language {
        language
    }

    internal func refreshVisibleRange() {
        visibleRangeProvider.updateVisibleSet()
    }

    internal func detach() {
        providerState.cancel()
        visibleRangeProvider.stopObserving()
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }

    internal func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard event.editedCharacters else { return }
        container.storageUpdated(
            editedRange: event.editedRange,
            changeInLength: event.changeInLength
        )
        visibleRangeProvider.textDidChange(
            editedRange: event.editedRange,
            delta: event.changeInLength
        )
        providerState.storageDidUpdate(
            range: event.editedRange,
            delta: event.changeInLength
        )
    }

    private static func makeHighlighter(for language: Language) -> any SyntaxHighlighter {
        let registry = LanguageRegistry()
        return registry.provider(for: language.rawValue)?.createHighlighter() ?? PlainTextHighlighter()
    }
}
