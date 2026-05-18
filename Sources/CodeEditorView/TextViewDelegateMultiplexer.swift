import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Multiplexer

/// The sole owner of `CodeEditorView`'s `textView.delegate` slot.
///
/// Every framework-internal feature that wants delegate hooks registers
/// as a `TextViewDelegateParticipant` at either `.gating` (host
/// gating / `isEditable` checks — exactly one participant: the
/// `CodeEditorViewDelegateProxy`) or `.behavior` (smart editing, scroll
/// forwarding, SwiftUI coordinator state mirroring).
///
/// Per-method semantics:
/// - `shouldChangeTextIn:`: veto chain. Any participant returning
///   `false` blocks the edit. `.gating` runs first; a gating veto
///   short-circuits before any `.behavior` participant fires.
/// - Notifications and iOS scroll callbacks: fan-out, registration
///   order, no early-out.
/// - `undoManager(for:)`, `completionViewController(for:)`,
///   `insertionPointView(for:frame:)`: first-non-nil-wins.
/// - `clickedOnLink` / `clickedOnAttachment`: first-handler-wins
///   (returns `true` at the first participant that returns `true`).
/// - `shouldAllowInteractionWith attachment:`: all-must-agree (any
///   `false` vetoes; default `true`).
///
/// After both phases vote allow on `shouldChangeTextIn:`, the
/// multiplexer publishes `WillEditEvent` to the
/// `TextEditEventHub` consumers as an intrinsic side-effect.
@MainActor
internal final class TextViewDelegateMultiplexer: NSObject {
    // MARK: - Storage

    private var gatingParticipants: [WeakParticipant] = []
    private var behaviorParticipants: [WeakParticipant] = []

    // MARK: - Registration

    /// Register a participant at the given phase. Identity-deduplicated
    /// (`===`) — registering the same participant twice is a no-op.
    /// Prunes dead weak slots as a side-effect.
    internal func addParticipant(
        _ participant: any TextViewDelegateParticipant,
        phase: TextViewDelegatePhase
    ) {
        switch phase {
        case .gating:
            pruneGating()
            guard !gatingParticipants.contains(where: { $0.value === participant }) else { return }
            gatingParticipants.append(WeakParticipant(value: participant))

        case .behavior:
            pruneBehavior()
            guard !behaviorParticipants.contains(where: { $0.value === participant }) else { return }
            behaviorParticipants.append(WeakParticipant(value: participant))
        }
    }

    /// Remove a participant from whichever phase contains it. Identity-
    /// matched (`===`). Prunes dead weak slots as a side-effect.
    internal func removeParticipant(_ participant: any TextViewDelegateParticipant) {
        pruneGating()
        pruneBehavior()
        gatingParticipants.removeAll { $0.value === participant }
        behaviorParticipants.removeAll { $0.value === participant }
    }

    // MARK: - Helpers

    private func pruneGating() {
        gatingParticipants.removeAll { $0.value == nil }
    }

    private func pruneBehavior() {
        behaviorParticipants.removeAll { $0.value == nil }
    }

    /// `gating` then `behavior`, in registration order. Used by every
    /// per-method impl other than `shouldChangeTextIn:` (which walks the
    /// two lists separately so a gating veto short-circuits).
    private func allParticipants() -> [any TextViewDelegateParticipant] {
        pruneGating()
        pruneBehavior()
        return gatingParticipants.compactMap(\.value) + behaviorParticipants.compactMap(\.value)
    }
}

// MARK: - Weak storage

private struct WeakParticipant {
    weak var value: (any TextViewDelegateParticipant)?
}

// MARK: - Shared Per-method Impls

extension TextViewDelegateMultiplexer {
    /// Veto chain for `shouldChangeTextIn:`. Walks `.gating` first; a
    /// gating veto short-circuits before any `.behavior` fires. After
    /// both phases vote allow, fans out `textViewWillChangeText` to all
    /// participants in phase order, then publishes `WillEditEvent` as
    /// the multiplexer's intrinsic side-effect, and finally returns
    /// `true`. The pre-edit hook fires only on allowed edits — a veto
    /// at either phase suppresses both the hook and the event.
    internal func shouldChangeText(
        in codeEditorView: CodeEditorView,
        range: NSRange,
        replacementString: String?
    ) -> Bool {
        pruneGating()
        for entry in gatingParticipants {
            let allowed = entry.value?.textView(
                codeEditorView,
                shouldChangeTextIn: range,
                replacementString: replacementString
            ) ?? true
            guard allowed else { return false }
        }
        pruneBehavior()
        for entry in behaviorParticipants {
            let allowed = entry.value?.textView(
                codeEditorView,
                shouldChangeTextIn: range,
                replacementString: replacementString
            ) ?? true
            guard allowed else { return false }
        }
        for entry in gatingParticipants {
            entry.value?.textViewWillChangeText(codeEditorView)
        }
        for entry in behaviorParticipants {
            entry.value?.textViewWillChangeText(codeEditorView)
        }
        codeEditorView.publishWillEditEvent(
            range: range,
            replacementText: replacementString ?? ""
        )
        return true
    }
}

// MARK: - MacOS Delegate Conformance

#if canImport(AppKit)
extension TextViewDelegateMultiplexer: NSTextViewDelegate {
    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let codeEditorView = textView as? CodeEditorView else { return true }
        return shouldChangeText(
            in: codeEditorView,
            range: affectedCharRange,
            replacementString: replacementString
        )
    }

    func textDidChange(_ notification: Notification) {
        guard let codeEditorView = notification.object as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeText(codeEditorView)
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let codeEditorView = notification.object as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeSelection(codeEditorView)
        }
    }

    func undoManager(for view: NSTextView) -> UndoManager? {
        guard let codeEditorView = view as? CodeEditorView else { return nil }
        for participant in allParticipants() {
            if let manager = participant.undoManager(for: codeEditorView) {
                return manager
            }
        }
        return nil
    }
}
#endif

// MARK: - IOS Delegate Conformance

#if canImport(UIKit)
extension TextViewDelegateMultiplexer: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let codeEditorView = textView as? CodeEditorView else { return true }
        return shouldChangeText(
            in: codeEditorView,
            range: range,
            replacementString: text
        )
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let codeEditorView = textView as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeText(codeEditorView)
        }
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard let codeEditorView = textView as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeSelection(codeEditorView)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        for participant in allParticipants() {
            participant.scrollViewDidScroll(scrollView)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for participant in allParticipants() {
            participant.scrollViewWillBeginDragging(scrollView)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        for participant in allParticipants() {
            participant.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        for participant in allParticipants() {
            participant.scrollViewDidEndDecelerating(scrollView)
        }
    }
}
#endif
