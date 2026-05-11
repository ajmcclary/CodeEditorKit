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
    private let provider: any RangeHighlightProviding
    private let providerState: HighlightProviderState
    private let visibleRangeProvider: VisibleRangeProvider

    internal let styleDataSource: StyledMinimapStyleDataSource

    /// Primary initializer.
    ///
    /// - Parameters:
    ///   - textView: The editor view to observe.
    ///   - language: The language to highlight.
    ///   - externalProvider: An optional `RangeHighlightProviding` to use
    ///     instead of the default regex-backed adapter. When non-nil (e.g.
    ///     a `TreeSitterRangeHighlightProvider`), it is used directly.
    ///     When nil, the standard `SyntaxHighlighterRangeAdapter` is used.
    internal init(
        textView: CodeEditorView,
        language: Language,
        externalProvider: (any RangeHighlightProviding)? = nil
    ) {
        self.textView = textView
        self.language = language

        #if canImport(AppKit)
        let documentLength = textView.textStorage?.length ?? 0
        #else
        let documentLength = textView.textStorage.length
        #endif

        let container = StyledRangeContainer(documentLength: documentLength)
        let providerID = container.registerProvider(priority: 0)

        // Use external provider (Tree-sitter) if supplied, otherwise fall back
        // to the regex-backed SyntaxHighlighter adapter.
        let provider: any RangeHighlightProviding
        if let externalProvider {
            provider = externalProvider
        } else {
            let highlighter = Self.makeHighlighter(for: language)
            provider = SyntaxHighlighterRangeAdapter(highlighter: highlighter)
        }

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
        // Swift uses SwiftSyntax for AST-based highlighting
        if language == .swift {
            return SwiftSyntaxHighlighter()
        }

        // All other languages go through the canonical regex definitions
        let regexHighlighter = RegexSyntaxHighlighter()
        if let definition = regexHighlighter.languageDefinition(for: language) {
            return RegexSyntaxHighlighter(customLanguage: definition)
        }

        // Fallback for plain text or unrecognized languages
        return PlainTextHighlighter()
    }
}
