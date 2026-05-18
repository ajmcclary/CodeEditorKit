import Foundation

// MARK: - Will-Edit Event (pre-mutation)

/// Published before `NSTextStorage` applies an edit. Captures state that
/// is destroyed by the mutation — the old range content, the replacement
/// text, and the pre-edit line/column bounds.
///
/// Downstream consumers (LSP coordinator, range highlight providers) read this
/// event to compute incremental diffs without reconstructing deleted text
/// from the post-edit state.
package struct WillEditEvent: Sendable {
    /// The range that will be replaced (UTF-16, pre-edit coordinates).
    package var preEditRange: NSRange

    /// The text that will be inserted in place of `preEditRange`.
    package var replacementText: String

    /// The line numbers affected by this edit before the mutation.
    /// `lowerBound` is the first line touched; `upperBound` is the last.
    package var preEditLineRange: ClosedRange<Int>

    /// An optional snapshot of the old source string spanning the affected
    /// region. Providers that need byte-range translation
    /// capture this lazily — only when a subscriber requests it.
    package var preEditSource: String?

    package init(
        preEditRange: NSRange,
        replacementText: String,
        preEditLineRange: ClosedRange<Int>,
        preEditSource: String? = nil
    ) {
        self.preEditRange = preEditRange
        self.replacementText = replacementText
        self.preEditLineRange = preEditLineRange
        self.preEditSource = preEditSource
    }
}

// MARK: - Post-Edit Event

/// A canonical edit event published when `NSTextStorage` finishes processing
/// an edit. Consumers (highlighting, folding, gutter) subscribe to avoid
/// duplicating edit-detection logic.
package struct TextEditEvent: Sendable, Equatable {
    /// The replaced character range in the pre-edit document (UTF-16 code units).
    package var editedRange: NSRange

    /// The delta between the new length and the old length of the edited range.
    /// Positive for insertions, negative for deletions.
    package var changeInLength: Int

    /// The total document length after the edit.
    package var documentLength: Int

    /// `true` when the edit changed characters (as opposed to attributes only).
    package var editedCharacters: Bool

    package init(
        editedRange: NSRange,
        changeInLength: Int,
        documentLength: Int,
        editedCharacters: Bool
    ) {
        self.editedRange = editedRange
        self.changeInLength = changeInLength
        self.documentLength = documentLength
        self.editedCharacters = editedCharacters
    }
}

// MARK: - Observer protocols

/// Objects that want to react to text-editing events *before* the mutation.
@MainActor
package protocol WillEditEventObserving: AnyObject {
    /// Called on the main actor before the text storage applies an edit.
    func textStorageWillApplyEdit(_ event: WillEditEvent)
}

/// Objects that want to react to text-editing events *after* the mutation.
@MainActor
package protocol TextEditEventObserving: AnyObject {
    /// Called on the main actor after the text storage has processed an edit.
    func textStorageDidApplyEdit(_ event: TextEditEvent)
}

// MARK: - Hub

/// Owned by `CodeEditorView`. Maintains two observer sets — will-edit and
/// did-edit — so consumers can choose whether they need pre-mutation state.
/// Observers are notified in registration order within each set.
@MainActor
package final class TextEditEventHub {
    private var didEditObservers: [WeakDidEditObserver] = []
    private var willEditObservers: [WeakWillEditObserver] = []

    package init() {}

    // MARK: - Registration (did-edit)

    package func addObserver(_ observer: any TextEditEventObserving) {
        pruneDidEdit()
        guard !didEditObservers.contains(where: { $0.value === observer }) else { return }
        didEditObservers.append(WeakDidEditObserver(value: observer))
    }

    package func removeObserver(_ observer: any TextEditEventObserving) {
        pruneDidEdit()
        didEditObservers.removeAll { $0.value === observer }
    }

    // MARK: - Registration (will-edit)

    package func addWillEditObserver(_ observer: any WillEditEventObserving) {
        pruneWillEdit()
        guard !willEditObservers.contains(where: { $0.value === observer }) else { return }
        willEditObservers.append(WeakWillEditObserver(value: observer))
    }

    package func removeWillEditObserver(_ observer: any WillEditEventObserving) {
        pruneWillEdit()
        willEditObservers.removeAll { $0.value === observer }
    }

    // MARK: - Publishing

    /// Publish a pre-mutation event to all will-edit observers.
    package func willPublish(_ event: WillEditEvent) {
        pruneWillEdit()
        for entry in willEditObservers {
            entry.value?.textStorageWillApplyEdit(event)
        }
    }

    /// Publish a post-mutation event to all did-edit observers.
    package func publish(_ event: TextEditEvent) {
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
