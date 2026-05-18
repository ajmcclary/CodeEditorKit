import CodeEditorAnnotations
import CodeEditorConfiguration
import CodeEditorLanguages
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Unified API for code editor functionality across platforms.
///
/// `CodeEditorAPI` defines the core interface for interacting with the code editor,
/// providing a consistent API across native macOS and iOS / iPadOS. This protocol
/// abstracts platform-specific implementations while exposing all essential editor
/// functionality.
///
/// ## Overview
///
/// The API is organized into logical groups:
/// - **Content Management**: Text manipulation and retrieval
/// - **Configuration**: Editor settings and language modes
/// - **Events**: Reactive event handling with Combine
/// - **Text Operations**: Insertion, deletion, and replacement
/// - **Selection**: Cursor movement and text selection
/// - **Search & Replace**: Find and replace functionality
/// - **Scrolling**: Viewport control
/// - **Annotations**: Inline markers and warnings
/// - **Line Information**: Line-based navigation
/// - **Undo/Redo**: History management
///
/// ## Adopting the Protocol
///
/// `CodeEditorView` is the primary implementation of this protocol. You typically
/// don't need to implement this protocol yourself unless creating a custom editor.
///
/// ```swift
/// let editor: CodeEditorAPI = CodeEditorView()
/// 
/// // Configure the editor
/// editor.language = .swift
/// editor.configuration = .default
/// 
/// // Set content
/// editor.content = "func hello() {\n    print(\"Hello, World!\")\n}"
/// 
/// // Subscribe to events
/// editor.subscribe(MyEventHandler())
/// ```
///
/// ## Thread Safety
///
/// All methods and properties must be accessed on the main actor. The protocol
/// is marked with `@MainActor` to ensure UI operations happen on the main thread.
///
/// - SeeAlso: ``CodeEditorView``, ``EditorConfiguration``, ``Language``
@MainActor
public protocol CodeEditorAPI: AnyObject {
    // MARK: - Content Management

    /// The text content of the editor
    var content: String { get set }

    /// The attributed text content (if supported)
    var attributedContent: NSAttributedString? { get set }

    /// Current text selection as `NSRange`. This is the canonical selection
    /// representation used throughout the editor and TextKit.
    var selectedRange: NSRange { get set }

    // MARK: - Configuration

    /// Editor configuration
    var configuration: EditorConfiguration { get set }

    /// Programming language for syntax highlighting
    var language: Language { get set }

    // MARK: - Events

    /// Event publisher for unified event handling
    var eventPublisher: EditorEventPublisher { get }

    /// Subscribe to editor events
    func subscribe(_ handler: EditorEventHandler)

    /// Unsubscribe from editor events
    func unsubscribe(_ handler: EditorEventHandler)

    // MARK: - Text Operations

    /// Insert text at current cursor position
    func insertText(_ text: String)

    /// Replace text in the UTF-16 range
    func replaceText(in range: NSRange, with text: String)

    /// Delete text in the UTF-16 range
    func deleteText(in range: NSRange)

    // MARK: - Selection Operations

    /// Select all text
    func selectAll()

    /// Move cursor to a UTF-16 offset
    func moveCursor(to position: Int)

    /// Move cursor by offset
    func moveCursor(by offset: Int)

    // MARK: - Search & Replace

    /// Find text in editor, returning UTF-16 ranges
    func find(_ text: String, options: FindOptions) -> [NSRange]

    /// Replace all occurrences
    func replaceAll(_ searchText: String, with replacement: String, options: FindOptions) -> Int

    // MARK: - Scrolling

    /// Scroll to make UTF-16 range visible
    func scrollToVisible(_ range: NSRange)

    /// Scroll to line number
    func scrollToLine(_ lineNumber: Int)

    /// Get currently visible UTF-16 range. Returns an empty range when no layout
    /// has happened yet.
    func visibleRange() -> NSRange

    // MARK: - Annotations

    /// Add an annotation
    func addAnnotation(_ annotation: Annotation)

    /// Remove an annotation
    func removeAnnotation(withId id: String)

    /// Get all annotations
    var annotations: [Annotation] { get }

    // MARK: - Line Information

    /// Get line number for a UTF-16 offset
    func lineNumber(at position: Int) -> Int

    /// Get UTF-16 line range for line number
    func lineRange(for lineNumber: Int) -> NSRange?

    /// Total number of lines
    var lineCount: Int { get }

    // MARK: - Undo/Redo

    /// Check if can undo
    var canUndo: Bool { get }

    /// Check if can redo
    var canRedo: Bool { get }

    /// Perform undo
    func undo()

    /// Perform redo
    func redo()
}

/// Options for find and replace operations.
///
/// `FindOptions` is an option set that allows combining multiple search behaviors
/// for flexible text searching within the editor.
///
/// ## Example
///
/// ```swift
/// // Case-insensitive search
/// let matches = editor.find("hello", options: .caseInsensitive)
/// 
/// // Whole word search with wrap around
/// let matches = editor.find("var", options: [.wholeWords, .wrapAround])
/// 
/// // Regular expression search
/// let matches = editor.find("\\bfunc\\s+\\w+", options: .regularExpression)
/// ```
///
/// - SeeAlso: ``CodeEditorAPI/find(_:options:)``, ``CodeEditorAPI/replaceAll(_:with:options:)``
public struct FindOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Perform case-insensitive matching.
    ///
    /// When set, "Hello" will match "hello", "HELLO", and "HeLLo".
    public static let caseInsensitive = Self(rawValue: 1 << 0)

    /// Match whole words only.
    ///
    /// When set, searching for "var" won't match "variable" or "invariant".
    /// Word boundaries are determined by whitespace and punctuation.
    public static let wholeWords = Self(rawValue: 1 << 1)

    /// Treat the search string as a regular expression.
    ///
    /// When set, the search string is interpreted as a regular expression pattern.
    /// Supports standard regex syntax including capture groups and quantifiers.
    ///
    /// - Note: Invalid regex patterns will cause the search to fail silently.
    public static let regularExpression = Self(rawValue: 1 << 2)

    /// Continue searching from the beginning when reaching the end.
    ///
    /// When set, the search wraps around to the beginning of the document
    /// after reaching the end, ensuring all matches are found regardless
    /// of the current cursor position.
    public static let wrapAround = Self(rawValue: 1 << 3)

    /// Default options (empty set).
    ///
    /// Performs exact, case-sensitive matching without wrap-around.
    public static let `default`: FindOptions = []
}

/// Default implementations for common functionality
@MainActor
extension CodeEditorAPI {
    /// Subscribe to editor events with the default implementation.
    ///
    /// This default implementation provides a convenient way to subscribe
    /// to events using the synchronous API of the event publisher.
    ///
    /// - Parameter handler: The event handler to subscribe
    ///
    /// - Note: This is a default implementation. Types conforming to `CodeEditorAPI`
    ///   can override this method if they need custom subscription behavior.
    public func subscribe(_ handler: EditorEventHandler) {
        eventPublisher.subscribeSync(handler)
    }

    /// Unsubscribe from editor events with the default implementation.
    ///
    /// This default implementation provides a convenient way to unsubscribe
    /// from events using the synchronous API of the event publisher.
    ///
    /// - Parameter handler: The event handler to unsubscribe
    ///
    /// - Note: This is a default implementation. Types conforming to `CodeEditorAPI`
    ///   can override this method if they need custom unsubscription behavior.
    public func unsubscribe(_ handler: EditorEventHandler) {
        eventPublisher.unsubscribeSync(handler)
    }

    func moveCursor(by offset: Int) {
        // swiftlint:disable:next legacy_objc_type
        let utf16Length = (content as NSString).length
        let current = selectedRange.location
        let next = max(0, min(utf16Length, current + offset))
        moveCursor(to: next)
    }

    func scrollToLine(_ lineNumber: Int) {
        guard let range = lineRange(for: lineNumber) else { return }
        scrollToVisible(range)
    }

    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    func lineNumber(at position: Int) -> Int {
        // swiftlint:disable:next legacy_objc_type
        let nsString = content as NSString
        let clamped = max(0, min(nsString.length, position))
        var count = 1
        var index = 0
        while index < clamped {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: index, length: 0))
            if lineEnd > clamped { break }
            index = lineEnd
            if index <= clamped { count += 1 }
        }
        return count
    }

    func lineRange(for lineNumber: Int) -> NSRange? {
        guard lineNumber > 0 else { return nil }
        // swiftlint:disable:next legacy_objc_type
        let nsString = content as NSString
        var index = 0
        var line = 1
        while index < nsString.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: index, length: 0))
            if line == lineNumber {
                return NSRange(location: lineStart, length: contentsEnd - lineStart)
            }
            index = lineEnd
            line += 1
        }
        return nil
    }
}

@MainActor
extension CodeEditorAPI {
    /// Set content and place cursor at end
    func setContent(_ text: String) {
        content = text
        // swiftlint:disable:next legacy_objc_type
        moveCursor(to: (content as NSString).length)
    }

    /// Append text to end of content
    func appendText(_ text: String) {
        content.append(text)
    }

    /// Check if editor is empty
    var isEmpty: Bool {
        content.isEmpty
    }

    /// Get selected text
    var selectedText: String? {
        // swiftlint:disable:next legacy_objc_type
        let nsString = content as NSString
        guard selectedRange.location + selectedRange.length <= nsString.length else { return nil }
        return nsString.substring(with: selectedRange)
    }
}
