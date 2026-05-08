import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Tracks the currently visible character range of the text view.
///
/// The visible set is used by `HighlightProviderState` to determine
/// which invalid ranges are actually visible and need highlighting.
@MainActor
internal final class VisibleRangeProvider {
    private weak var textView: CodeEditorView?
    private var visibleSet = IndexSet()
    private var observerTokens: [NSObjectProtocol] = []
    var onVisibleSetChange: ((IndexSet) -> Void)?

    init(textView: CodeEditorView) {
        self.textView = textView
        setupObservers()
        updateVisibleSet()
    }

    /// The current visible character indices.
    var visibleIndices: IndexSet {
        visibleSet
    }

    /// Explicitly unregister notification observers.
    func stopObserving() {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observerTokens.removeAll()
    }

    /// Call when text changes — inserts the edited range into the visible set.
    func textDidChange(editedRange: NSRange, delta: Int) {
        if delta > 0 {
            let insertion = IndexSet(integersIn: editedRange.location..<(editedRange.location + delta))
            visibleSet.formUnion(insertion)
        }
        updateVisibleSet()
    }

    /// Recompute visible indices from the text view's visible range.
    func updateVisibleSet() {
        guard let textView else { return }
        let range: NSRange = textView.visibleRange()
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let storageLength = textView.textStorage?.length ?? 0
        #else
        let storageLength = textView.textStorage.length
        #endif
        let end = min(storageLength, range.location + range.length)
        guard range.location >= 0, end > range.location else { return }
        let updated = IndexSet(integersIn: range.location..<end)
        guard updated != visibleSet else { return }
        visibleSet = updated
        onVisibleSetChange?(updated)
    }

    // MARK: - Observers

    private func setupObservers() {
        let center = NotificationCenter.default
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let scrollView = textView?.enclosingScrollView {
            let tok1 = center.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateVisibleSet()
                }
            }
            observerTokens.append(tok1)
        }
        #endif
    }
}
