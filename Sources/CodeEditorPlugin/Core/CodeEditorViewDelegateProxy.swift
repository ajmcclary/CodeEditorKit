import CodeEditorCompletion
import CodeEditorPlatform
#if canImport(AppKit)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import CodeEditorCommon
import UIKit
#endif
import Foundation

/// Adapts the framework's host-facing `CodeEditorViewDelegate` to the
/// internal `TextViewDelegateParticipant` protocol consumed by
/// `TextViewDelegateMultiplexer`. Registered at `.gating` so host
/// vetoes short-circuit before any behavior participant fires.
///
/// `publishWillEditEvent` used to live in this proxy's `shouldChangeTextIn`
/// body. After the multiplexer migration the multiplexer handles that
/// as an intrinsic side-effect, so this type is now a pure forwarder.
@MainActor
final class CodeEditorViewDelegateProxy: NSObject {
    weak var source: CodeEditorViewDelegate?

    init(source: CodeEditorViewDelegate?) {
        self.source = source
    }
}

// MARK: - TextViewDelegateParticipant

extension CodeEditorViewDelegateProxy: TextViewDelegateParticipant {
    func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn range: NSRange,
        replacementString: String?
    ) -> Bool {
        guard textView.configuration.behavior.isEditable else { return false }

        let textRange: NSTextRange?
        if let textLayoutManager = textView.textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager {
            textRange = NSTextRange(range, provider: textContentManager)
        } else {
            textRange = NSTextRange(range)
        }
        guard let textRange else { return true }

        return source?.textView(
            textView,
            shouldChangeTextIn: textRange,
            replacementString: replacementString
        ) ?? true
    }

    func textViewWillChangeText(_ textView: CodeEditorView) {
        let notification = Notification(name: textChangeNotificationName, object: textView)
        source?.textViewWillChangeText(notification)
    }

    func textViewDidChangeText(_ textView: CodeEditorView) {
        let notification = Notification(name: textChangeNotificationName, object: textView)
        source?.textViewDidChangeText(notification)
    }

    func textViewDidChangeSelection(_ textView: CodeEditorView) {
        let notification = Notification(name: selectionChangeNotificationName, object: textView)
        source?.textViewDidChangeSelection(notification)
    }

    func undoManager(for textView: CodeEditorView) -> UndoManager? {
        source?.undoManager(for: textView)
    }

    func completionViewController(
        for textView: CodeEditorView
    ) -> (any CompletionViewControllerRepresentable)? {
        // Match the existing CodeEditorViewDelegate default-impl behavior:
        // if the host doesn't supply one, return nil so the multiplexer
        // falls through to its first-non-nil-wins default (nil),
        // matching today's surface where the host's default-impl
        // `textViewCompletionViewController(_:)` is what fires.
        source?.textViewCompletionViewController(textView)
    }

    func insertionPointView(
        for textView: CodeEditorView,
        frame: CGRect
    ) -> (any InsertionPointIndicating)? {
        source?.textViewInsertionPointView(textView, frame: frame)
    }

    func textView(
        _ textView: CodeEditorView,
        clickedOnLink link: Any,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, clickedOnLink: link, at: location) ?? false
    }

    func textView(
        _ textView: CodeEditorView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, clickedOnAttachment: attachment, at: location) ?? false
    }

    func textView(
        _ textView: CodeEditorView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, shouldAllowInteractionWith: attachment, at: location) ?? true
    }

    private var textChangeNotificationName: Notification.Name {
        #if canImport(AppKit)
        return NSText.didChangeNotification
        #else
        return UITextView.textDidChangeNotification
        #endif
    }

    private var selectionChangeNotificationName: Notification.Name {
        #if canImport(AppKit)
        return NSTextView.didChangeSelectionNotification
        #else
        return UITextView.textDidChangeNotification
        #endif
    }
}
