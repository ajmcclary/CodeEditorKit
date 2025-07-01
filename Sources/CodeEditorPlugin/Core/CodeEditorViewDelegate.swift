import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - CodeEditorViewDelegate

/// A set of optional methods that text view delegates can use to manage selection,
/// set text attributes and more.
@MainActor
public protocol CodeEditorViewDelegate: AnyObject {
    /// Returns the undo manager for the specified text view.
    ///
    /// This method provides the flexibility to return a custom undo manager for the text view.
    /// Although CodeEditorView implements undo and redo for changes to text,
    /// applications may need a custom undo manager to handle interactions between changes
    /// to text and changes to other items in the application.
    func undoManager(for textView: CodeEditorView) -> UndoManager?

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
        _ textView: CodeEditorView,
        shouldChangeTextIn affectedCharRange: NSTextRange,
        replacementString: String?
    ) -> Bool

    /// Sent when a text view will change text.
    func textView(_ textView: CodeEditorView, willChangeTextIn affectedCharRange: NSTextRange, replacementString: String)

    /// Sent when a text view did change text.
    func textView(_ textView: CodeEditorView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String)

    // MARK: Clicking and Pasting

    /// Sent after the user clicks a link.
    /// - Parameters:
    ///   - textView: The text view sending the message.
    ///   - link: The link that was clicked; the value of link is either URL or String.
    ///   - location: The location where the click occurred.
    /// - Returns: true if the click was handled; otherwise, false to allow the next responder to handle it.
    func textView(_ textView: CodeEditorView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool

    // MARK: Completion Support

    /// Allows customization of completion item insertion
    func textView(_ textView: CodeEditorView, insertCompletionItem item: any CompletionItem)

    /// Provides a custom completion view controller
    func textViewCompletionViewController(_ textView: CodeEditorView) -> any CompletionViewControllerProtocol

    /// Provides a custom insertion point view
    func textViewInsertionPointView(_ textView: CodeEditorView, frame: CGRect) -> (InsertionPointIndicatorProtocol)?

    // MARK: Attachment Support

    /// Sent after the user clicks an attachment.
    func textView(
        _ textView: CodeEditorView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool

    /// Asks whether the user should be allowed to interact with the specified attachment.
    func textView(
        _ textView: CodeEditorView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool
}

// MARK: - Default implementation

extension CodeEditorViewDelegate {
    func undoManager(for _: CodeEditorView) -> UndoManager? {
        nil
    }

    func textViewWillChangeText(_: Notification) {
        //
    }

    func textViewDidChangeText(_: Notification) {
        //
    }

    func textViewDidChangeSelection(_: Notification) {
        //
    }

    func textView(_: CodeEditorView, shouldChangeTextIn _: NSTextRange, replacementString _: String?) -> Bool {
        true
    }

    func textView(_: CodeEditorView, willChangeTextIn _: NSTextRange, replacementString _: String) {}

    func textView(_: CodeEditorView, didChangeTextIn _: NSTextRange, replacementString _: String) {}

    func textView(_: CodeEditorView, clickedOnLink _: Any, at _: any NSTextLocation) -> Bool {
        false
    }

    func textView(_: CodeEditorView, insertCompletionItem _: any CompletionItem) {
        // Default implementation
    }

    func textViewCompletionViewController(_: CodeEditorView) -> any CompletionViewControllerProtocol {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        CompletionViewController()
        #elseif canImport(UIKit)
        NoOpCompletionViewController()
        #else
        BasicCompletionViewController()
        #endif
    }

    func textViewInsertionPointView(_: CodeEditorView, frame _: CGRect) -> (InsertionPointIndicatorProtocol)? {
        nil
    }

    func textView(_: CodeEditorView, clickedOnAttachment _: NSTextAttachment, at _: any NSTextLocation) -> Bool {
        false
    }

    func textView(
        _: CodeEditorView,
        shouldAllowInteractionWith _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool {
        true
    }
}

#if canImport(UIKit)
@MainActor
private class NoOpCompletionViewController: UIViewController, CompletionViewControllerProtocol {
    var items: [any CompletionItem] = []
    weak var delegate: CompletionViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        view = UIView()
    }

    func showCompletions() {}
    func hideCompletions() {}
    func reloadData() {}
    
    var isVisible: Bool { false }
}
#endif
