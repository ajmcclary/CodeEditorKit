import Foundation
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - STTextViewDelegate

/// A set of optional methods that text view delegates can use to manage selection,
/// set text attributes and more.
public protocol STTextViewDelegate: AnyObject {
    /// Returns the undo manager for the specified text view.
    ///
    /// This method provides the flexibility to return a custom undo manager for the text view.
    /// Although STTextView implements undo and redo for changes to text,
    /// applications may need a custom undo manager to handle interactions between changes
    /// to text and changes to other items in the application.
    func undoManager(for textView: STTextView) -> UndoManager?

    /// Any keyDown or paste which changes the contents causes this
    func textViewWillChangeText(_ notification: Notification)

    /// Informs the delegate that the text object has changed its characters or formatting attributes.
    func textViewDidChangeText(_ notification: Notification)

    /// Sent when the selection changes in the text view.
    ///
    /// You can use the selectedRange property of the text view to get the new selection.
    func textViewDidChangeSelection(_ notification: Notification)

    /// Sent when a text view needs to determine if text in a specified range should be changed.
    func textView(
        _ textView: STTextView,
        shouldChangeTextIn affectedCharRange: NSTextRange,
        replacementString: String?
    ) -> Bool

    /// Sent when a text view will change text.
    func textView(_ textView: STTextView, willChangeTextIn affectedCharRange: NSTextRange, replacementString: String)

    /// Sent when a text view did change text.
    func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String)

    // MARK: Clicking and Pasting

    /// Sent after the user clicks a link.
    /// - Parameters:
    ///   - textView: The text view sending the message.
    ///   - link: The link that was clicked; the value of link is either URL or String.
    ///   - location: The location where the click occurred.
    /// - Returns: true if the click was handled; otherwise, false to allow the next responder to handle it.
    func textView(_ textView: STTextView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool

    // MARK: Completion Support

    /// Allows customization of completion item insertion
    func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem)

    /// Provides a custom completion view controller
    func textViewCompletionViewController(_ textView: STTextView) -> any STCompletionViewControllerProtocol

    /// Provides a custom insertion point view
    func textViewInsertionPointView(_ textView: STTextView, frame: CGRect) -> (STInsertionPointIndicatorProtocol)?

    // MARK: Attachment Support

    /// Sent after the user clicks an attachment.
    func textView(
        _ textView: STTextView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool

    /// Asks whether the user should be allowed to interact with the specified attachment.
    func textView(
        _ textView: STTextView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool
}

// MARK: - Default implementation

extension STTextViewDelegate {
    public func undoManager(for _: STTextView) -> UndoManager? {
        nil
    }

    public func textViewWillChangeText(_: Notification) {
        //
    }

    public func textViewDidChangeText(_: Notification) {
        //
    }

    public func textViewDidChangeSelection(_: Notification) {
        //
    }

    public func textView(_: STTextView, shouldChangeTextIn _: NSTextRange, replacementString _: String?) -> Bool {
        true
    }

    public func textView(_: STTextView, willChangeTextIn _: NSTextRange, replacementString _: String) {}

    public func textView(_: STTextView, didChangeTextIn _: NSTextRange, replacementString _: String) {}

    public func textView(_: STTextView, clickedOnLink _: Any, at _: any NSTextLocation) -> Bool {
        false
    }

    public func textView(_: STTextView, insertCompletionItem _: any STCompletionItem) {
        // Default implementation
    }

    @MainActor
    public func textViewCompletionViewController(_: STTextView) -> any STCompletionViewControllerProtocol {
        STCompletionViewController()
    }

    public func textViewInsertionPointView(_: STTextView, frame _: CGRect) -> (STInsertionPointIndicatorProtocol)? {
        nil
    }

    public func textView(_: STTextView, clickedOnAttachment _: NSTextAttachment, at _: any NSTextLocation) -> Bool {
        false
    }

    public func textView(
        _: STTextView,
        shouldAllowInteractionWith _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool {
        true
    }
}
