import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - CodeEditorViewDelegate

/// A protocol that defines optional methods for customizing text view behavior and responding to editing events.
///
/// The `CodeEditorViewDelegate` protocol extends the standard text view delegation pattern with
/// additional methods specific to code editing scenarios. All methods are optional with default
/// implementations provided.
///
/// ## Adopting the Protocol
///
/// ```swift
/// class MyEditorDelegate: CodeEditorViewDelegate {
///     func textViewDidChangeText(_ notification: Notification) {
///         guard let textView = notification.object as? CodeEditorView else { return }
///         // Handle text changes
///         updateWordCount(for: textView.string)
///         markDocumentAsModified()
///     }
///     
///     func textView(_ textView: CodeEditorView,
///                   shouldChangeTextIn range: NSTextRange,
///                   replacementString: String?) -> Bool {
///         // Validate changes before they occur
///         return isValidReplacement(string: replacementString)
///     }
///     
///     func textView(_ textView: CodeEditorView,
///                   insertCompletionItem item: any CompletionItem) {
///         // Customize completion insertion
///         insertWithSnippetExpansion(item)
///     }
/// }
/// ```
///
/// ## Delegate Methods Categories
///
/// ### Text Change Notifications
/// - `textViewWillChangeText(_:)` - Before text changes
/// - `textViewDidChangeText(_:)` - After text changes
/// - `textViewDidChangeSelection(_:)` - Selection changes
///
/// ### Text Validation
/// - `textView(_:shouldChangeTextIn:replacementString:)` - Validate changes
/// - `textView(_:willChangeTextIn:replacementString:)` - Pre-change hook
/// - `textView(_:didChangeTextIn:replacementString:)` - Post-change hook
///
/// ### User Interaction
/// - `textView(_:clickedOnLink:at:)` - Handle link clicks
/// - `textView(_:clickedOnAttachment:at:)` - Handle attachment clicks
///
/// ### Customization
/// - `undoManager(for:)` - Custom undo manager
/// - `textViewCompletionViewController(_:)` - Custom completion UI
/// - `textViewInsertionPointView(_:frame:)` - Custom cursor
///
/// - SeeAlso: `CodeEditorView.textDelegate`
@MainActor
public protocol CodeEditorViewDelegate: AnyObject {
    /// Returns the undo manager for the specified text view.
    ///
    /// This method provides the flexibility to return a custom undo manager for the text view.
    /// Although CodeEditorView implements undo and redo for changes to text,
    /// applications may need a custom undo manager to handle interactions between changes
    /// to text and changes to other items in the application.
    func undoManager(for textView: CodeEditorView) -> UndoManager?

    /// Called before the text view's content is about to change.
    ///
    /// This method is called before any text modification, whether from keyboard input,
    /// paste operations, or programmatic changes. Use this to prepare for changes or
    /// update UI state.
    ///
    /// - Parameter notification: The notification containing the text view as its object
    ///
    /// ## Example
    ///
    /// ```swift
    /// func textViewWillChangeText(_ notification: Notification) {
    ///     // Save current state for comparison
    ///     previousText = textView.string
    ///     
    ///     // Prepare for text change
    ///     beginUndoGrouping()
    /// }
    /// ```
    ///
    /// - Note: This is called for every keystroke during typing
    func textViewWillChangeText(_ notification: Notification)

    /// Called after the text view's content has changed.
    ///
    /// This method is called after any successful text modification. Use this to update
    /// dependent UI, perform syntax highlighting, validate content, or trigger auto-save.
    ///
    /// - Parameter notification: The notification containing the text view as its object
    ///
    /// ## Example
    ///
    /// ```swift
    /// func textViewDidChangeText(_ notification: Notification) {
    ///     guard let textView = notification.object as? CodeEditorView else { return }
    ///     
    ///     // Update UI
    ///     updateCharacterCount(textView.string.count)
    ///     setDocumentModified(true)
    ///     
    ///     // Schedule auto-save
    ///     autoSaveTimer?.invalidate()
    ///     autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
    ///         self.saveDocument()
    ///     }
    /// }
    /// ```
    ///
    /// - Important: This is called frequently during typing. Consider debouncing expensive operations.
    func textViewDidChangeText(_ notification: Notification)

    /// Called when the text selection or cursor position changes.
    ///
    /// This method is called whenever the user moves the cursor or changes the selection,
    /// either through mouse clicks, keyboard navigation, or programmatic changes.
    /// Use the text view's `selectedRange` property to get the new selection.
    ///
    /// - Parameter notification: The notification containing the text view as its object
    ///
    /// ## Example
    ///
    /// ```swift
    /// func textViewDidChangeSelection(_ notification: Notification) {
    ///     guard let textView = notification.object as? CodeEditorView else { return }
    ///     
    ///     let range = textView.selectedRange
    ///     let (line, column) = textView.lineAndColumn(for: range.location)
    ///     
    ///     // Update status bar
    ///     statusLabel.stringValue = "Line \(line), Column \(column)"
    ///     
    ///     // Update context-sensitive UI
    ///     updateToolbarForSelection(range)
    ///     
    ///     // Show relevant documentation
    ///     if range.length == 0 {
    ///         showQuickHelpForCursor(at: range.location)
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This is called frequently during text selection dragging
    func textViewDidChangeSelection(_ notification: Notification)

    /// Asks whether the specified text should be replaced in the text view.
    ///
    /// Implement this method to validate text changes before they occur. Return `false`
    /// to prevent the change, or `true` to allow it. This is useful for implementing
    /// read-only regions, input validation, or custom text filters.
    ///
    /// - Parameters:
    ///   - textView: The text view requesting validation
    ///   - affectedCharRange: The range of text to be replaced
    ///   - replacementString: The string to insert, or nil for deletion
    /// - Returns: `true` to allow the change, `false` to prevent it
    ///
    /// ## Example
    ///
    /// ```swift
    /// func textView(_ textView: CodeEditorView,
    ///               shouldChangeTextIn range: NSTextRange,
    ///               replacementString: String?) -> Bool {
    ///     // Prevent editing in read-only regions
    ///     if isReadOnlyRange(range) {
    ///         return false
    ///     }
    ///     
    ///     // Validate input
    ///     if let string = replacementString {
    ///         // Prevent non-ASCII characters in certain contexts
    ///         if requiresASCII && !string.isASCII {
    ///             showError("Only ASCII characters allowed")
    ///             return false
    ///         }
    ///     }
    ///     
    ///     return true
    /// }
    /// ```
    ///
    /// - Note: This is called before `textView(_:willChangeTextIn:replacementString:)`
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
    func textView(_ textView: CodeEditorView, insertCompletionItem item: any CompletionItemView)

    /// Provides a custom completion view controller
    func textViewCompletionViewController(_ textView: CodeEditorView) -> any CompletionViewControllerRepresentable

    /// Provides a custom insertion point view
    func textViewInsertionPointView(_ textView: CodeEditorView, frame: CGRect) -> (InsertionPointIndicating)?

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

    func textView(_: CodeEditorView, insertCompletionItem _: any CompletionItemView) {
        // Default implementation
    }

    func textViewCompletionViewController(_: CodeEditorView) -> any CompletionViewControllerRepresentable {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        CompletionViewController()
        #elseif canImport(UIKit)
        NoOpCompletionViewController()
        #else
        BasicCompletionViewController()
        #endif
    }

    func textViewInsertionPointView(_: CodeEditorView, frame _: CGRect) -> (InsertionPointIndicating)? {
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
private class NoOpCompletionViewController: UIViewController, CompletionViewControllerRepresentable {
    var items: [any CompletionItemView] = []
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
