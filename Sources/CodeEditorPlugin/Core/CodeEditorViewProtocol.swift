#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - CodeEditorViewProtocol

/// A common interface for TextView implementations across platforms.
///
/// This protocol uses the `package` access modifier (introduced in Swift 5.9) to make it
/// visible within the CodeEditorPlugin package but not to external consumers. This design
/// choice allows internal components to share a common interface while keeping implementation
/// details private from the public API.
///
/// External users should interact with the concrete `CodeEditorView` type rather than this
/// protocol directly.
///
/// - Note: The `package` modifier provides better encapsulation than `public` while being
///   more flexible than `internal` for multi-module projects.
package protocol CodeEditorViewProtocol {
    associatedtype GutterView

    @available(*, deprecated, renamed: "isInvisibleCharactersEnabled", message: "Use isInvisibleCharactersEnabled for consistent naming")
    var showsInvisibleCharacters: Bool { get set }

    var isInvisibleCharactersEnabled: Bool { get set }

    associatedtype Color
    associatedtype Font
    associatedtype Delegate

    static var didChangeSelectionNotification: Notification.Name { get }
    static var textWillChangeNotification: Notification.Name { get }
    static var textDidChangeNotification: Notification.Name { get }

    var textLayoutManager: NSTextLayoutManager { get }
    var textContentManager: NSTextContentManager { get }
    var textContainer: NSTextContainer { get set }

    var widthTracksTextView: Bool { get set }
    var isHorizontallyResizable: Bool { get set }
    var heightTracksTextView: Bool { get set }
    var isVerticallyResizable: Bool { get set }

    var highlightSelectedLine: Bool { get set }
    var selectedLineHighlightColor: Color { get set }

    @available(*, deprecated, renamed: "isLineNumbersEnabled", message: "Use isLineNumbersEnabled for consistent naming")
    var showsLineNumbers: Bool { get set }

    var isLineNumbersEnabled: Bool { get set }

    var font: Font { get set }
    var textColor: Color { get set }
    var defaultParagraphStyle: NSParagraphStyle { get set }

    var typingAttributes: [NSAttributedString.Key: Any] { get }

    var text: String? { get set }
    var attributedText: NSAttributedString? { get set }

    var isEditable: Bool { get set }
    var isSelectable: Bool { get set }
    var allowsUndo: Bool { get set }

    var textDelegate: Delegate? { get set }

    var gutterView: GutterView? { get }

    func toggleRuler(_ sender: Any?)

    var textSelection: NSRange { get set }

    func addAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange)
    func setAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange)
    func removeAttribute(_ attribute: NSAttributedString.Key, range: NSRange)

    func shouldChangeText(in affectedTextRange: NSTextRange, replacementString: String?) -> Bool
    func replaceCharacters(in range: NSTextRange, with string: String)
    func insertText(_ string: Any, replacementRange: NSRange)
}
