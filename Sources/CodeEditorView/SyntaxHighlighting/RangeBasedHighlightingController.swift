import CodeEditorHighlightingCore
import CodeEditorLanguages
import CodeEditorLayout
import CodeEditorPlatform
import CodeEditorSyntaxHighlighting
import CodeEditorTextModel
import Foundation

/// Owns the range-store-backed highlighting pipeline for a single editor view.
///
/// This controller currently feeds minimap style data and visible-range
/// invalidation. It does not replace the legacy attributed-text highlighter.
@MainActor
package final class RangeBasedHighlightingController: TextEditEventObserving {
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

    /// Supplemental providers, such as LSP semantic tokens, keyed by object
    /// identity so they can be registered after the controller is created.
    private var supplementalProviders: [ObjectIdentifier: any RangeHighlightProviding] = [:]
    private var supplementalProviderStates: [ObjectIdentifier: HighlightProviderState] = [:]
    private var supplementalProviderIDs: [ObjectIdentifier: Int] = [:]

    /// Bridges keyed by the identity of the value-oriented provider they wrap,
    /// so `HighlightRangeProviding` supplemental providers can be
    /// unregistered/invalidated by the same object the caller registered.
    private var valueProviderBridges: [ObjectIdentifier: SnapshotHighlightProviderBridge] = [:]

    /// Primary initializer.
    ///
    /// - Parameters:
    ///   - textView: The editor view to observe.
    ///   - language: The language to highlight.
    ///   - externalProvider: An optional `RangeHighlightProviding` to use
    ///     instead of the default regex-backed adapter. When non-nil, it is
    ///     used directly.
    ///     When nil, the standard `SyntaxHighlighterRangeAdapter` is used.
    internal init(
        textView: CodeEditorView,
        language: Language,
        externalProvider: (any RangeHighlightProviding)? = nil
    ) {
        self.textView = textView
        self.language = language

        let documentLength = textView.textKitBridge.documentLength

        let container = StyledRangeContainer(documentLength: documentLength)
        let providerID = container.registerProvider(priority: 0)

        // Use external provider if supplied, otherwise fall back
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
        self.styleDataSource = StyledMinimapStyleDataSource(container: container) { [weak textView] capture in
            if let theme = textView?.appliedTheme {
                return SyntaxColorScheme.color(forCapture: capture, in: theme)
            }
            if let tokenType = TokenType(rawValue: capture) {
                return SyntaxColorScheme.default.color(for: tokenType)
            }
            return SyntaxColorScheme.default.plain
        }
        self.applier = RangeAttributeApplier(textView: textView, container: container)
        self.previousSourceSnapshot = Self.sourceString(from: textView)

        provider.setUp(textView: textView, language: language)
        visibleRangeProvider.onVisibleSetChange = { [weak self] visible in
            guard let self else { return }
            self.providerState.updateVisibleSet(visible)
            for state in self.supplementalProviderStates.values {
                state.updateVisibleSet(visible)
            }
        }
        providerState.onRangeHighlighted = { [weak self] range in
            self?.applier.applyAttributes(for: range)
        }

        textView.textEditEventHub.addObserver(self)
        providerState.updateVisibleSet(visibleRangeProvider.visibleIndices)
    }

    /// Creates a controller whose primary provider is a value-oriented
    /// ``HighlightRangeProviding``. The provider is bridged onto the internal
    /// range mechanics via ``SnapshotHighlightProviderBridge`` so it never
    /// touches the editor view directly.
    package convenience init(
        textView: CodeEditorView,
        language: Language,
        valueProvider: any HighlightRangeProviding
    ) {
        self.init(
            textView: textView,
            language: language,
            externalProvider: SnapshotHighlightProviderBridge(valueProvider: valueProvider)
        )
    }

    internal var currentLanguage: Language {
        language
    }

    /// Registers an additional highlight provider in the shared style
    /// container. Lower numeric priority wins over higher numeric priority.
    internal func registerSupplementalProvider(_ supplementalProvider: any RangeHighlightProviding, priority: Int) {
        guard let textView else { return }
        let identity = ObjectIdentifier(supplementalProvider)
        guard supplementalProviderStates[identity] == nil else { return }
        supplementalProviders[identity] = supplementalProvider

        let documentLength = textView.textKitBridge.documentLength

        let providerID = container.registerProvider(priority: priority)
        supplementalProviderIDs[identity] = providerID
        let state = HighlightProviderState(
            provider: supplementalProvider,
            providerID: providerID,
            container: container,
            textView: textView,
            documentLength: documentLength
        )
        supplementalProvider.setUp(textView: textView, language: language)
        state.onRangeHighlighted = { [weak self] range in
            self?.applier.applyAttributes(for: range)
        }
        supplementalProviderStates[identity] = state
        state.updateVisibleSet(visibleRangeProvider.visibleIndices)
    }

    /// Removes a supplemental provider and its stored highlight runs.
    internal func unregisterSupplementalProvider(_ supplementalProvider: any RangeHighlightProviding) {
        let identity = ObjectIdentifier(supplementalProvider)
        supplementalProviderStates.removeValue(forKey: identity)?.cancel()
        supplementalProviders.removeValue(forKey: identity)
        if let providerID = supplementalProviderIDs.removeValue(forKey: identity) {
            container.removeProvider(id: providerID)
        }
    }

    /// Invalidates and re-queries a supplemental provider after its backing
    /// data changes outside the normal text-edit path, e.g. after LSP semantic
    /// tokens refresh from the server.
    internal func invalidateSupplementalProvider(
        _ supplementalProvider: any RangeHighlightProviding,
        indices: IndexSet
    ) {
        let identity = ObjectIdentifier(supplementalProvider)
        guard let state = supplementalProviderStates[identity] else { return }
        state.invalidate(indices)
        Task {
            await state.highlightInvalidRanges()
        }
    }

    // MARK: - Value-oriented supplemental providers

    /// Registers a value-oriented ``HighlightRangeProviding`` supplemental
    /// provider. The provider is wrapped in a
    /// ``SnapshotHighlightProviderBridge`` so external adapters plug in
    /// without depending on the editor view or the internal provider protocol.
    package func registerSupplementalProvider(
        _ valueProvider: any HighlightRangeProviding,
        priority: Int
    ) {
        let identity = ObjectIdentifier(valueProvider)
        guard valueProviderBridges[identity] == nil else { return }
        let bridge = SnapshotHighlightProviderBridge(valueProvider: valueProvider)
        valueProviderBridges[identity] = bridge
        registerSupplementalProvider(bridge, priority: priority)
    }

    /// Removes a previously registered value-oriented supplemental provider.
    package func unregisterSupplementalProvider(_ valueProvider: any HighlightRangeProviding) {
        let identity = ObjectIdentifier(valueProvider)
        guard let bridge = valueProviderBridges.removeValue(forKey: identity) else { return }
        unregisterSupplementalProvider(bridge)
    }

    /// Invalidates and re-queries a value-oriented supplemental provider after
    /// its backing data changes out of band (e.g. an LSP semantic-token push).
    package func invalidateSupplementalProvider(
        _ valueProvider: any HighlightRangeProviding,
        indices: IndexSet
    ) {
        let identity = ObjectIdentifier(valueProvider)
        guard let bridge = valueProviderBridges[identity] else { return }
        invalidateSupplementalProvider(bridge, indices: indices)
    }

    internal func refreshVisibleRange() {
        visibleRangeProvider.updateVisibleSet()
    }

    internal func detach() {
        providerState.cancel()
        for state in supplementalProviderStates.values {
            state.cancel()
        }
        supplementalProviderStates.removeAll()
        supplementalProviders.removeAll()
        supplementalProviderIDs.removeAll()
        valueProviderBridges.removeAll()
        visibleRangeProvider.stopObserving()
        applier.detach()
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }

    package func textStorageDidApplyEdit(_ event: TextEditEvent) {
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
        for supplementalProvider in supplementalProviders.values {
            if let previousSourceSnapshot {
                supplementalProvider.willApplyEdit(
                    textView: textView,
                    source: previousSourceSnapshot,
                    range: event.editedRange
                )
            } else {
                supplementalProvider.willApplyEdit(textView: textView, range: event.editedRange)
            }
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
        for state in supplementalProviderStates.values {
            state.storageDidUpdate(
                range: event.editedRange,
                delta: event.changeInLength
            )
        }
    }

    private static func sourceString(from textView: CodeEditorView) -> String {
        textView.textKitBridge.documentString
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
