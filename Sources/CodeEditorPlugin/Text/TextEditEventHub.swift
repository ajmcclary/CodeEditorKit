import Foundation

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

// MARK: - Observer protocol

/// Objects that want to react to text-editing events.
@MainActor
internal protocol TextEditEventObserving: AnyObject {
    /// Called on the main actor after the text storage has processed an edit.
    func textStorageDidApplyEdit(_ event: TextEditEvent)
}

// MARK: - Hub

/// Owned by `CodeEditorView`. Observers are notified in registration order.
@MainActor
internal final class TextEditEventHub {
    private var observers: [WeakObserver] = []

    // MARK: - Registration

    internal func addObserver(_ observer: any TextEditEventObserving) {
        prune()
        guard !observers.contains(where: { $0.value === observer }) else { return }
        observers.append(WeakObserver(value: observer))
    }

    internal func removeObserver(_ observer: any TextEditEventObserving) {
        prune()
        observers.removeAll { $0.value === observer }
    }

    // MARK: - Publishing

    internal func publish(_ event: TextEditEvent) {
        prune()
        for entry in observers {
            entry.value?.textStorageDidApplyEdit(event)
        }
    }

    // MARK: - Helpers

    private func prune() {
        observers.removeAll { $0.value == nil }
    }
}

private struct WeakObserver {
    weak var value: (any TextEditEventObserving)?

    init(value: any TextEditEventObserving) {
        self.value = value
    }
}
