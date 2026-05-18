import CodeEditorAnnotations
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorLayout
import CodeEditorLSP
import CodeEditorPlatform
#if canImport(SwiftUI)
import CodeEditorTextModel
import CodeEditorView
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

    #if canImport(AppKit)
    @ObservationIgnored
    private var memoizedTemporaryAttributesStore: TemporaryAttributesStore?

    /// Lazily-built store keyed on the currently-attached view's content storage.
    /// Rebuilt automatically when the attached view (and thus content storage)
    /// changes. Passing the `NSTextContentStorage` (rather than the inner
    /// `NSTextStorage`) lets the store wrap its mutations in
    /// `performEditingTransaction`, which is required to avoid
    /// `NSTextContentStorageBreakOnEnumerateWhileEditing` during concurrent
    /// TextKit2 enumeration. Avoids `NSTextView.textStorage`, which fires
    /// Apple's TK1 compatibility shim.
    var temporaryAttributesStore: TemporaryAttributesStore? {
        guard let contentStorage = codeEditorView?.textContentStorage else { return nil }
        if let existing = memoizedTemporaryAttributesStore,
           existing.contentStorage === contentStorage {
            return existing
        }
        let store = TemporaryAttributesStore(contentStorage: contentStorage)
        memoizedTemporaryAttributesStore = store
        return store
    }

    /// Internal event bus carrying hover and ⌘-click events from the wrapped
    /// NSTextView. Surfaced into the SwiftUI environment by `CodeEditor` so
    /// the `.onTextHover` and `.onCommandClick` modifiers can subscribe.
    @ObservationIgnored
    let editorEventBus = EditorEventBus()

    @ObservationIgnored
    private var eventBusInstaller: EditorEventBusInstaller?
    #endif

    /// Handlers registered via `onAttach(_:)`. Stored as an array (rather
    /// than a dictionary) so registration order is preserved and
    /// iteration is deterministic. Typical sizes are 1–3 entries.
    @ObservationIgnored
    private var attachHandlers: [(id: UUID, closure: @MainActor (EditorController) -> Void)] = []

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

    // MARK: - Attach lifecycle hooks

    /// Register a handler that runs every time this controller becomes
    /// attached to a `CodeEditorView`. Use this to perform setup that
    /// requires a live view (installing a data source, scrolling to a
    /// caret position, applying initial decorations).
    ///
    /// Handlers fire on the main actor when the underlying view is
    /// first created and again every time SwiftUI re-creates it
    /// (e.g. parent identity change, sheet remount). Handlers MUST
    /// therefore be idempotent.
    ///
    /// Handlers are NOT invoked retroactively. If `onAttach` is called
    /// after the controller is already attached, the handler runs on
    /// the next attach. Hosts that want immediate-then-on-reattach
    /// semantics branch on `isAttached`:
    ///
    /// ```swift
    /// let token = controller.onAttach { ctrl in install(ctrl) }
    /// if controller.isAttached { install(controller) }
    /// ```
    ///
    /// - Parameter handler: Closure invoked on the main actor whenever
    ///   the controller becomes attached. The closure receives the
    ///   controller itself, so weak-self captures are unnecessary.
    /// - Returns: An `AnyCancellable` token. Drop or `cancel()` it to
    ///   remove the handler. Store it in `Set<AnyCancellable>` or as a
    ///   property to keep the subscription active.
    public func onAttach(
        _ handler: @MainActor @escaping (EditorController) -> Void
    ) -> AnyCancellable {
        let id = UUID()
        attachHandlers.append((id, handler))
        return AnyCancellable { [weak self] in
            // `AnyCancellable`'s cancel closure is not @MainActor-isolated
            // (Combine predates strict concurrency). Hop back to
            // MainActor to mutate `attachHandlers` safely.
            Task { @MainActor in
                self?.attachHandlers.removeAll { $0.id == id }
            }
        }
    }

    // MARK: - Attach hook (called by the SwiftUI representable)

    /// Internal wiring hook — not for host use. Called from the SwiftUI
    /// representable on `make…`/`update…`/`dismantle…`.
    func attach(to view: CodeEditorView?) {
        let previousView = codeEditorView
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
            #if canImport(AppKit)
            // Install hover/⌘-click monitoring on the wrapped text view.
            eventBusInstaller?.uninstall()
            let installer = EditorEventBusInstaller(bus: editorEventBus, textView: view)
            installer.install()
            eventBusInstaller = installer
            #endif

            // Fire registered onAttach handlers only on a real view
            // transition (nil → A, A → B, nil → A after detach). The
            // SwiftUI representable calls `attach(to: sameView)` on every
            // update, so skipping the same-view case keeps handlers from
            // firing on every keystroke.
            if view !== previousView {
                let snapshot = attachHandlers
                for (_, handler) in snapshot {
                    handler(self)
                }
            }
        } else {
            symbolSubscription?.cancel()
            symbolSubscription = nil
            symbols = []
            matchCount = 0
            currentMatchIndex = -1
            isAttached = false
            #if canImport(AppKit)
            eventBusInstaller?.uninstall()
            eventBusInstaller = nil
            #endif
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

    /// Replace the currently active match with `replacement` and advance
    /// to the next match. Returns true if a replacement happened. No-op
    /// when there is no current match. Compensates for the engine's
    /// existing index-decrement after `replace(at:with:)` so the UX
    /// matches Xcode / VS Code "replace then advance".
    @discardableResult
    public func replaceCurrent(with replacement: String) -> Bool {
        guard let view = codeEditorView else { return false }
        let engine = view.searchEngine
        let index = engine.currentSearchIndex
        guard engine.currentSearchResults.indices.contains(index) else { return false }

        let didReplace = engine.replace(at: index, with: replacement)
        guard didReplace else { return false }

        if !engine.currentSearchResults.isEmpty {
            _ = engine.findNext(from: nil)
        }
        matchCount = engine.currentSearchResults.count
        currentMatchIndex = engine.currentSearchIndex
        return true
    }

    /// Reset cached search state AND clear in-editor match highlights.
    public func clearSearch() {
        matchCount = 0
        currentMatchIndex = -1
        codeEditorView?.searchEngine.clearAll()
    }

    // MARK: - Dirty tracking

    /// Reset the framework's view-local dirty baseline. Hosts call this
    /// after a successful save (or any other moment when the current text
    /// should be treated as the new clean baseline). Writes
    /// `EditorState.isDirty = false`. No-op when the controller is
    /// unattached.
    ///
    /// Note: `EditorState.isDirty` is view-local — it tracks whether the
    /// editor view has observed an edit since its current bound content
    /// was installed. Hosts that track document-level dirty across tabs
    /// (e.g., the sample app's `TabModel.isDirty`) continue to do so
    /// independently.
    public func markClean() {
        codeEditorView?.applyMarkClean()
    }

    // MARK: - Navigation

    /// Move the caret to the start of `lineNumber` (1-based) and scroll
    /// the line into view.
    public func gotoLine(_ lineNumber: Int) {
        guard let view = codeEditorView, lineNumber >= 1 else { return }
        guard let nsRange = view.lineRange(for: lineNumber) else { return }
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

    /// Selects `range` in the attached view and (optionally) scrolls it
    /// into visible. No-op when no view is attached. Mirrors the
    /// select+scroll primitive used internally by `gotoSymbol(_:)`,
    /// without requiring a `DocumentSymbol`.
    public func selectRange(_ range: NSRange, scroll: Bool = true) {
        guard let view = codeEditorView else { return }
        view.setSelectedRangeWithoutScrolling(range)
        if scroll {
            view.scrollRangeToVisible(range)
        }
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
    ///
    /// - Important: This method is a no-op when the controller is
    ///   unattached (`isAttached == false`). To install a data source
    ///   from a host's `init` — before the SwiftUI representable has
    ///   created the underlying view — use `onAttach(_:)`:
    ///
    ///   ```swift
    ///   attachToken = controller.onAttach { [weak hub] ctrl in
    ///       guard let hub else { return }
    ///       ctrl.setAnnotationsDataSource(hub)
    ///   }
    ///   ```
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
        return view.lineNumber(at: view.selectedRange.location)
    }

    /// The editor's adaptive performance mode controller.
    ///
    /// Exposes the underlying `CodeEditorView`'s instance so observers see the same state
    /// the editor itself uses (file-size and memory-pressure driven transitions). Returns
    /// `nil` before the controller is attached to a view.
    public var adaptivePerformanceMode: AdaptivePerformanceMode? {
        codeEditorView?.adaptivePerformanceMode
    }

    /// Build an `NSTextRange` covering line `lineNumber` (1-based).
    /// Useful for constructing `Annotation` values from line numbers,
    /// either to pass to `addAnnotation(_:)` or to vend from an
    /// `AnnotationsDataSource`. Returns nil when no view is attached or
    /// the line number is out of range.
    public func textRange(forLine lineNumber: Int) -> NSTextRange? {
        guard let view = codeEditorView,
              let nsRange = view.lineRange(for: lineNumber),
              let storage = view.textContentStorage else { return nil }
        return TextRangeUtilities.convert(nsRange, in: storage)
    }

    /// Build a UTF-16 `NSRange` covering line `lineNumber` (1-based).
    /// This is the preferred range representation for `Annotation` storage.
    public func nsRange(forLine lineNumber: Int) -> NSRange? {
        codeEditorView?.lineRange(for: lineNumber)
    }

    // MARK: - LSP coordinate conversion

    /// Convert an LSP `(line, character)` position (zero-based, with
    /// `character` measured in UTF-16 code units per the LSP spec) into a
    /// UTF-16 offset in the editor's content. Returns nil when no view
    /// is attached, the line is out of range, or either input is negative.
    ///
    /// The returned offset is clamped to the line's UTF-16 length, so
    /// positions past the line's content land at the line break rather
    /// than overflowing into the next line.
    public func nsLocation(forLSPLine line: Int, character: Int) -> Int? {
        guard let view = codeEditorView,
              line >= 0,
              character >= 0 else { return nil }
        guard let lineNSRange = view.lineRange(for: line + 1) else { return nil }
        let candidate = lineNSRange.location + character
        return min(candidate, NSMaxRange(lineNSRange))
    }

    /// Convert an LSP range (a `(start, end)` pair of zero-based positions)
    /// into a UTF-16 `NSRange` in the editor's content. Returns nil when
    /// no view is attached or either endpoint is out of range.
    ///
    /// This is the supported way to convert LSP diagnostics, hover ranges,
    /// definitions, etc. into editor offsets — host code should not
    /// attempt to reimplement `(line, character)` arithmetic from the
    /// outside, since the buffer is the only source of truth for line
    /// boundaries.
    public func nsRange(forLSPRange lspRange: LSPRange) -> NSRange? {
        guard let start = nsLocation(
            forLSPLine: lspRange.start.line,
            character: lspRange.start.character
        ),
        let end = nsLocation(
            forLSPLine: lspRange.end.line,
            character: lspRange.end.character
        ) else { return nil }
        let length = max(0, end - start)
        return NSRange(location: start, length: length)
    }
}

#endif
