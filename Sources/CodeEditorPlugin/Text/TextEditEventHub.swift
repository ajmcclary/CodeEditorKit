import Foundation

// MARK: - Will-Edit Event (pre-mutation)

/// Published before `NSTextStorage` applies an edit. Captures state that
/// is destroyed by the mutation — the old range content, the replacement
/// text, and the pre-edit line/column bounds.
///
/// Downstream consumers (LSP coordinator, range highlight providers) read this
/// event to compute incremental diffs without reconstructing deleted text
/// from the post-edit state.
internal struct WillEditEvent: Sendable {
    /// The range that will be replaced (UTF-16, pre-edit coordinates).
    internal var preEditRange: NSRange

    /// The text that will be inserted in place of `preEditRange`.
    internal var replacementText: String

    /// The line numbers affected by this edit before the mutation.
    /// `lowerBound` is the first line touched; `upperBound` is the last.
    internal var preEditLineRange: ClosedRange<Int>

    /// An optional snapshot of the old source string spanning the affected
    /// region. Providers that need byte-range translation
    /// capture this lazily — only when a subscriber requests it.
    internal var preEditSource: String?
}

// MARK: - Post-Edit Event

/// A canonical edit event published when `NSTextStorage` finishes processing
/// an edit. Consumers (highlighting, folding, gutter) subscribe to avoid
/// duplicating edit-detection logic.
internal struct TextEditEvent: Sendable, Equatable {
    /// The replaced character range in the pre-edit document (UTF-16 code units).
    internal var editedRange: NSRange

    /// The delta between the new length and the old length of the edited range.
    /// Positive for insertions, negative for deletions.
    internal var changeInLength: Int

    /// The total document length after the edit.
    internal var documentLength: Int

    /// `true` when the edit changed characters (as opposed to attributes only).
    internal var editedCharacters: Bool
}

// MARK: - Observer protocols

/// Objects that want to react to text-editing events *before* the mutation.
@MainActor
internal protocol WillEditEventObserving: AnyObject {
    /// Called on the main actor before the text storage applies an edit.
    func textStorageWillApplyEdit(_ event: WillEditEvent)
}

/// Objects that want to react to text-editing events *after* the mutation.
@MainActor
internal protocol TextEditEventObserving: AnyObject {
    /// Called on the main actor after the text storage has processed an edit.
    func textStorageDidApplyEdit(_ event: TextEditEvent)
}

// MARK: - Hub

/// Owned by `CodeEditorView`. Maintains two observer sets — will-edit and
/// did-edit — so consumers can choose whether they need pre-mutation state.
/// Observers are notified in registration order within each set.
@MainActor
internal final class TextEditEventHub {
    private var didEditObservers: [WeakDidEditObserver] = []
    private var willEditObservers: [WeakWillEditObserver] = []

    // MARK: - Registration (did-edit)

    internal func addObserver(_ observer: any TextEditEventObserving) {
        pruneDidEdit()
        guard !didEditObservers.contains(where: { $0.value === observer }) else { return }
        didEditObservers.append(WeakDidEditObserver(value: observer))
    }

    internal func removeObserver(_ observer: any TextEditEventObserving) {
        pruneDidEdit()
        didEditObservers.removeAll { $0.value === observer }
    }

    // MARK: - Registration (will-edit)

    internal func addWillEditObserver(_ observer: any WillEditEventObserving) {
        pruneWillEdit()
        guard !willEditObservers.contains(where: { $0.value === observer }) else { return }
        willEditObservers.append(WeakWillEditObserver(value: observer))
    }

    internal func removeWillEditObserver(_ observer: any WillEditEventObserving) {
        pruneWillEdit()
        willEditObservers.removeAll { $0.value === observer }
    }

    // MARK: - Publishing

    /// Publish a pre-mutation event to all will-edit observers.
    internal func willPublish(_ event: WillEditEvent) {
        pruneWillEdit()
        for entry in willEditObservers {
            entry.value?.textStorageWillApplyEdit(event)
        }
    }

    /// Publish a post-mutation event to all did-edit observers.
    internal func publish(_ event: TextEditEvent) {
        pruneDidEdit()
        for entry in didEditObservers {
            entry.value?.textStorageDidApplyEdit(event)
        }
    }

    // MARK: - Helpers

    private func pruneDidEdit() {
        didEditObservers.removeAll { $0.value == nil }
    }

    private func pruneWillEdit() {
        willEditObservers.removeAll { $0.value == nil }
    }
}

private struct WeakDidEditObserver {
    weak var value: (any TextEditEventObserving)?

    init(value: any TextEditEventObserving) {
        self.value = value
    }
}

private struct WeakWillEditObserver {
    weak var value: (any WillEditEventObserving)?

    init(value: any WillEditEventObserving) {
        self.value = value
    }
}
