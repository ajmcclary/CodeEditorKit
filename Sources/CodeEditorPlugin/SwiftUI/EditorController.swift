#if canImport(SwiftUI)
@preconcurrency import Combine
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Host-facing handle for driving editor commands from SwiftUI code.
///
/// The SwiftUI `CodeEditor` wrapper owns a private `CodeEditorView`. A host
/// that wants to trigger find, fold-all, goto-line, install an annotations
/// data source, etc. needs a way to reach that view. `EditorController`
/// is that bridge: the host creates one (typically in its app-state
/// model), passes it via the `.editorController(_:)` modifier, and the
/// SwiftUI representable then weakly assigns the underlying view into
/// the controller on `make…`/`update…`/`dismantle…`.
///
/// All methods are no-ops while the controller is unattached, so a host
/// can call into them eagerly without lifecycle ceremony.
///
/// ## Example
///
/// ```swift
/// @State private var controller = EditorController()
///
/// var body: some View {
///     CodeEditor(text: $text)
///         .editorController(controller)
///
///     Button("Fold All") { controller.foldAll() }
/// }
/// ```
@available(macOS 13.0, iOS 16.0, *)
@MainActor
@Observable
public final class EditorController {
    // MARK: - Initialization

    /// Create a fresh, unattached controller. The host then passes it to
    /// `CodeEditor.editorController(_:)`; the SwiftUI representable
    /// performs the actual attach.
    public init() {}

    // MARK: - Internal wiring

    /// Set by `attach(to:)` from the SwiftUI representable. Held weakly
    /// so the controller never extends the editor view's lifetime.
    @ObservationIgnored
    weak var codeEditorView: CodeEditorView?

    @ObservationIgnored
    private lazy var symbolNavigator = SymbolNavigator()

    @ObservationIgnored
    private var symbolSubscription: AnyCancellable?

    // MARK: - Observable state

    /// Whether a `CodeEditorView` is currently attached. False until the
    /// SwiftUI view's `make…` runs; flips back to false on dismantle.
    public private(set) var isAttached: Bool = false

    /// Document symbols (functions, classes, etc.) discovered by the
    /// owned `SymbolNavigator`. Mirrors the navigator's `@Published`
    /// state so SwiftUI hosts can drive a symbol picker.
    public private(set) var symbols: [DocumentSymbol] = []

    /// Number of matches from the most recent `find` / `findNext` / `findPrevious`.
    public private(set) var matchCount: Int = 0

    /// Zero-based index of the current match within `matchCount`, or -1
    /// when there is no active search.
    public private(set) var currentMatchIndex: Int = -1

    // MARK: - Attach hook (called by the SwiftUI representable)

    /// Internal wiring hook — not for host use. Called from the SwiftUI
    /// representable on `make…`/`update…`/`dismantle…`.
    func attach(to view: CodeEditorView?) {
        codeEditorView = view
        if let view {
            symbolNavigator.attach(to: view)
            // Mirror the navigator's symbol list into our @Observable
            // property so hosts can bind through the controller without
            // also retaining the navigator.
            symbolSubscription = symbolNavigator.$symbols.sink { [weak self] newSymbols in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.symbols = newSymbols
                }
            }
            isAttached = true
        } else {
            symbolSubscription?.cancel()
            symbolSubscription = nil
            symbols = []
            matchCount = 0
            currentMatchIndex = -1
            isAttached = false
        }
    }

    // MARK: - Search / replace

    /// Run a full document search. Highlights matches and selects the
    /// first one. Updates `matchCount` and `currentMatchIndex`. Pass
    /// `nil` for `options` to use the engine's defaults.
    @discardableResult
    public func find(_ pattern: String, options: SearchOptions? = nil) async -> [SearchResult] {
        guard let view = codeEditorView, !pattern.isEmpty else {
            matchCount = 0
            currentMatchIndex = -1
            return []
        }
        let engine = view.searchEngine
        let results = await engine.findAll(pattern: pattern, options: options)
        matchCount = results.count
        currentMatchIndex = engine.currentSearchIndex
        return results
    }

    /// Advance to the next search result. Returns nil if no search has
    /// run or there are no more results (and wrap-around is disabled).
    @discardableResult
    public func findNext() -> SearchResult? {
        guard let view = codeEditorView else { return nil }
        let result = view.searchEngine.findNext(from: nil)
        currentMatchIndex = view.searchEngine.currentSearchIndex
        matchCount = view.searchEngine.currentSearchResults.count
        return result
    }

    /// Step back to the previous search result.
    @discardableResult
    public func findPrevious() -> SearchResult? {
        guard let view = codeEditorView else { return nil }
        let result = view.searchEngine.findPrevious(from: nil)
        currentMatchIndex = view.searchEngine.currentSearchIndex
        matchCount = view.searchEngine.currentSearchResults.count
        return result
    }

    /// Replace every match of `pattern` with `replacement`. Returns the
    /// number of replacements made. Pass `nil` for `options` to use the
    /// engine's defaults.
    @discardableResult
    public func replaceAll(
        _ pattern: String,
        with replacement: String,
        options: SearchOptions? = nil
    ) async -> Int {
        guard let view = codeEditorView, !pattern.isEmpty else { return 0 }
        let count = await view.searchEngine.replaceAll(
            pattern: pattern,
            with: replacement,
            options: options
        )
        matchCount = view.searchEngine.currentSearchResults.count
        currentMatchIndex = view.searchEngine.currentSearchIndex
        return count
    }

    /// Reset cached search state. Does not clear the editor's match
    /// highlights — call `view.searchEngine.findAll(pattern: "")` if you
    /// want highlights cleared.
    public func clearSearch() {
        matchCount = 0
        currentMatchIndex = -1
    }

    // MARK: - Navigation

    /// Move the caret to the start of `lineNumber` (1-based) and scroll
    /// the line into view.
    public func gotoLine(_ lineNumber: Int) {
        guard let view = codeEditorView, lineNumber >= 1 else { return }
        guard let stringRange = view.lineRange(for: lineNumber) else { return }
        let nsRange = NSRange(stringRange, in: view.content)
        let caret = NSRange(location: nsRange.location, length: 0)
        view.setSelectedRangeWithoutScrolling(caret)
        view.scrollRangeToVisible(caret)
    }

    /// Select the symbol's `selectionRange` and (if the configuration
    /// permits) scroll it into view. Updates the owned symbol
    /// navigator's `selectedSymbol`.
    public func gotoSymbol(_ symbol: DocumentSymbol) {
        symbolNavigator.navigate(to: symbol)
    }

    /// Re-run symbol detection against the current document.
    public func refreshSymbols() {
        symbolNavigator.updateSymbols()
    }

    // MARK: - Folding

    /// Toggle the fold state of the foldable region at `line` (1-based).
    public func toggleFold(atLine line: Int) {
        _ = codeEditorView?.toggleFold(at: line)
    }

    /// Fold the region at `line` (1-based), if any.
    public func fold(atLine line: Int) {
        _ = codeEditorView?.fold(at: line)
    }

    /// Unfold the region at `line` (1-based), if any.
    public func unfold(atLine line: Int) {
        _ = codeEditorView?.unfold(at: line)
    }

    /// Fold every foldable region in the document.
    public func foldAll() {
        codeEditorView?.foldAll()
    }

    /// Unfold every currently-folded region.
    public func unfoldAll() {
        codeEditorView?.unfoldAll()
    }

    // MARK: - Annotations

    /// Install a data source on the underlying `CodeEditorView` and
    /// trigger an annotation reload. The view holds the source weakly,
    /// so callers must keep their own strong reference.
    public func setAnnotationsDataSource(_ source: any AnnotationsDataSource) {
        codeEditorView?.annotationsDataSource = source
        codeEditorView?.reloadAnnotations()
    }

    /// Detach any previously-installed annotations data source.
    public func clearAnnotationsDataSource() {
        codeEditorView?.annotationsDataSource = nil
        codeEditorView?.reloadAnnotations()
    }

    /// Add a one-off inline annotation to the underlying view.
    public func addAnnotation(_ annotation: Annotation) {
        codeEditorView?.addAnnotation(annotation)
    }

    /// Remove every annotation (both inline and data-source-vended) from
    /// the underlying view.
    public func removeAllAnnotations() {
        codeEditorView?.removeAllAnnotations()
    }

    /// Ask the underlying view to re-query its annotations data source.
    public func reloadAnnotations() {
        codeEditorView?.reloadAnnotations()
    }

    // MARK: - Cursor / line introspection

    /// The 1-based line number the caret currently sits on, or nil when
    /// no view is attached or the selection is out of range.
    public var currentLineNumber: Int? {
        guard let view = codeEditorView else { return nil }
        let selection = view.selectedRange
        let content = view.content
        guard let stringRange = Range(selection, in: content) else { return nil }
        return view.lineNumber(at: stringRange.lowerBound)
    }

    /// Build an `NSTextRange` covering line `lineNumber` (1-based).
    /// Useful for constructing `Annotation` values from line numbers,
    /// either to pass to `addAnnotation(_:)` or to vend from an
    /// `AnnotationsDataSource`. Returns nil when no view is attached or
    /// the line number is out of range.
    public func textRange(forLine lineNumber: Int) -> NSTextRange? {
        guard let view = codeEditorView,
              let stringRange = view.lineRange(for: lineNumber),
              let storage = view.textContentStorage else { return nil }
        let nsRange = NSRange(stringRange, in: view.content)
        return RangeUtilities.convert(nsRange, in: storage)
    }

    /// Build a UTF-16 `NSRange` covering line `lineNumber` (1-based).
    /// This is the preferred range representation for `Annotation` storage.
    public func nsRange(forLine lineNumber: Int) -> NSRange? {
        guard let view = codeEditorView,
              let stringRange = view.lineRange(for: lineNumber) else { return nil }
        return NSRange(stringRange, in: view.content)
    }
}

#endif
