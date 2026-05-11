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
    private var previousSourceSnapshot: String?

    internal let styleDataSource: StyledMinimapStyleDataSource

    /// Applies merged `StyledRangeContainer` runs to `NSTextStorage`
    /// attributes. Created alongside this controller and detached together.
    internal let applier: RangeAttributeApplier

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
        self.applier = RangeAttributeApplier(textView: textView, container: container)
        self.previousSourceSnapshot = Self.sourceString(from: textView)

        provider.setUp(textView: textView, language: language)
        let state = providerState
        visibleRangeProvider.onVisibleSetChange = { [weak state] visible in
            state?.updateVisibleSet(visible)
        }
        providerState.onRangeHighlighted = { [weak self] range in
            self?.applier.applyAttributes(for: range)
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
        applier.detach()
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }

    internal func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard let textView else { return }
        defer {
            previousSourceSnapshot = Self.sourceString(from: textView)
        }
        guard event.editedCharacters else { return }
        if let previousSourceSnapshot {
            provider.willApplyEdit(
                textView: textView,
                source: previousSourceSnapshot,
                range: event.editedRange
            )
        } else {
            provider.willApplyEdit(textView: textView, range: event.editedRange)
        }
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

    private static func sourceString(from textView: CodeEditorView) -> String {
        #if canImport(AppKit)
        textView.textStorage?.string ?? ""
        #else
        textView.textStorage.string
        #endif
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
