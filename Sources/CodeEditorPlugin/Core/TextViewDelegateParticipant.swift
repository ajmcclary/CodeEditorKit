import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Phase

/// The ordering bucket a `TextViewDelegateParticipant` registers in.
///
/// `.gating` participants run first for veto-style methods
/// (`shouldChangeTextIn`). A `.gating` participant returning `false`
/// short-circuits before any `.behavior` participant is consulted, so
/// behavioural side-effects (e.g. `SmartEditingEngine`'s auto-indent
/// writing to `textStorage`) never fire on a host-vetoed edit.
///
/// For every other delegate method, phase determines only iteration
/// order (`.gating` first, then `.behavior`) — the per-method semantics
/// (fan-out, first-non-nil-wins, first-handler-wins, all-must-agree)
/// are identical across phases.
@MainActor
internal enum TextViewDelegatePhase {
    /// Host gating, `isEditable` checks, read-only regions.
    case gating
    /// Smart-editing interception, scroll forwarding, SwiftUI coordinator
    /// state mirroring.
    case behavior
}

// MARK: - Participant protocol

/// An object that participates in the framework's delegate multiplexer.
///
/// Internal-only. Hosts continue to use `CodeEditorViewDelegate` via
/// `CodeEditorView.textDelegate`; only framework-internal types adopt
/// this protocol to plug into `TextViewDelegateMultiplexer`.
///
/// Every method has a default implementation that returns the
/// AppKit/UIKit "allow / no-op / nil / false" default, so participants
/// only implement the methods they care about.
@MainActor
internal protocol TextViewDelegateParticipant: AnyObject {
    // Veto chain — default true (allow).
    func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn range: NSRange,
        replacementString: String?
    ) -> Bool

    // Fan-out notifications — default no-op.
    func textViewWillChangeText(_ textView: CodeEditorView)
    func textViewDidChangeText(_ textView: CodeEditorView)
    func textViewDidChangeSelection(_ textView: CodeEditorView)

    // First-non-nil-wins — default nil.
    func undoManager(for textView: CodeEditorView) -> UndoManager?
    func completionViewController(for textView: CodeEditorView)
        -> (any CompletionViewControllerRepresentable)?
    func insertionPointView(
        for textView: CodeEditorView,
        frame: CGRect
    ) -> (any InsertionPointIndicating)?

    // First-handler-wins — default false.
    func textView(
        _ textView: CodeEditorView,
        clickedOnLink link: Any,
        at location: any NSTextLocation
    ) -> Bool
    func textView(
        _ textView: CodeEditorView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool

    // All-must-agree — default true.
    func textView(
        _ textView: CodeEditorView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool

    #if canImport(UIKit)
    // Fan-out scroll callbacks — default no-op.
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    #endif
}

// MARK: - Default implementations

internal extension TextViewDelegateParticipant {
    func textView(
        _: CodeEditorView,
        shouldChangeTextIn _: NSRange,
        replacementString _: String?
    ) -> Bool { true }

    func textViewWillChangeText(_: CodeEditorView) {}
    func textViewDidChangeText(_: CodeEditorView) {}
    func textViewDidChangeSelection(_: CodeEditorView) {}

    func undoManager(for _: CodeEditorView) -> UndoManager? { nil }

    func completionViewController(
        for _: CodeEditorView
    ) -> (any CompletionViewControllerRepresentable)? { nil }

    func insertionPointView(
        for _: CodeEditorView,
        frame _: CGRect
    ) -> (any InsertionPointIndicating)? { nil }

    func textView(
        _: CodeEditorView,
        clickedOnLink _: Any,
        at _: any NSTextLocation
    ) -> Bool { false }

    func textView(
        _: CodeEditorView,
        clickedOnAttachment _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool { false }

    func textView(
        _: CodeEditorView,
        shouldAllowInteractionWith _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool { true }

    #if canImport(UIKit)
    func scrollViewDidScroll(_: UIScrollView) {}
    func scrollViewWillBeginDragging(_: UIScrollView) {}
    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {}
    func scrollViewDidEndDecelerating(_: UIScrollView) {}
    #endif
}
