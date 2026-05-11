import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - LineGeometryEditHandler

/// Observes `TextEditEventHub` and keeps `LineGeometryStore` in sync with
/// `NSTextStorage` after text edits.
///
/// On each character-level edit, the handler rebuilds the geometry store
/// from the text storage. This is O(n) per edit — matching the current
/// `LineIndexCache` behavior. The architecture supports incremental
/// (O(m log n)) updates as a follow-on optimization; the observer pattern,
/// registration, and API surface are already in place.
///
/// Attribute-only edits (e.g., syntax highlighting color changes) are
/// no-ops — they don't affect line geometry.
@MainActor
internal final class LineGeometryEditHandler: TextEditEventObserving {
    /// The geometry store to keep in sync.
    private let geometryStore: LineGeometryStore

    /// Weak reference to the text view for accessing `textStorage`.
    private weak var textView: CodeEditorView?

    // MARK: - Initialization

    init(geometryStore: LineGeometryStore, textView: CodeEditorView) {
        self.geometryStore = geometryStore
        self.textView = textView
        textView.textEditEventHub.addObserver(self)
    }

    // MARK: - TextEditEventObserving

    func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard event.editedCharacters else {
            // Attribute-only change — geometry is unaffected.
            return
        }

        guard let textStorage = textView?.textStorage else { return }

        // Rebuild the geometry store from the current text storage state.
        // Future optimization: incremental update using red-black tree
        // split/merge/insert/delete operations (O(m log n) for m affected
        // lines). The observer pattern and store API are already in place.
        geometryStore.build(from: textStorage)
    }

    // MARK: - Lifecycle

    /// Detach from the text view's event hub. Call before the text view
    /// is deallocated to break the observer reference.
    func detach() {
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }
}
