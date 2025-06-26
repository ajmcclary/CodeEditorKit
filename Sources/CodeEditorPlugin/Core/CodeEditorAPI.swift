import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - CodeEditorAPI

/// Unified API for code editor functionality across platforms
public protocol CodeEditorAPI: AnyObject {
    // MARK: - Content Management
    
    /// The text content of the editor
    var content: String { get set }
    
    /// The attributed text content (if supported)
    var attributedContent: NSAttributedString? { get set }
    
    /// Current text selection as a Swift range
    var selection: Range<String.Index>? { get set }
    
    /// Current text selection as NSRange (for compatibility)
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
    
    /// Replace text in range
    func replaceText(in range: Range<String.Index>, with text: String)
    
    /// Delete text in range
    func deleteText(in range: Range<String.Index>)
    
    // MARK: - Selection Operations
    
    /// Select all text
    func selectAll()
    
    /// Move cursor to position
    func moveCursor(to position: String.Index)
    
    /// Move cursor by offset
    func moveCursor(by offset: Int)
    
    // MARK: - Search & Replace
    
    /// Find text in editor
    func find(_ text: String, options: FindOptions) -> [Range<String.Index>]
    
    /// Replace all occurrences
    func replaceAll(_ searchText: String, with replacement: String, options: FindOptions) -> Int
    
    // MARK: - Scrolling
    
    /// Scroll to make range visible
    func scrollToVisible(_ range: Range<String.Index>)
    
    /// Scroll to line number
    func scrollToLine(_ lineNumber: Int)
    
    /// Get currently visible range
    func visibleRange() -> Range<String.Index>?
    
    // MARK: - Annotations
    
    /// Add an annotation
    func addAnnotation(_ annotation: Annotation)
    
    /// Remove an annotation
    func removeAnnotation(withId id: String)
    
    /// Get all annotations
    var annotations: [Annotation] { get }
    
    // MARK: - Line Information
    
    /// Get line number for position
    func lineNumber(at position: String.Index) -> Int
    
    /// Get line range for line number
    func lineRange(for lineNumber: Int) -> Range<String.Index>?
    
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

// MARK: - FindOptions

/// Options for find operations
public struct FindOptions: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let caseInsensitive = Self(rawValue: 1 << 0)
    public static let wholeWords = Self(rawValue: 1 << 1)
    public static let regularExpression = Self(rawValue: 1 << 2)
    public static let wrapAround = Self(rawValue: 1 << 3)
    
    public static let `default`: FindOptions = []
}

// MARK: - CodeEditorAPI Extension

/// Default implementations for common functionality
public extension CodeEditorAPI {
    func subscribe(_ handler: EditorEventHandler) {
        eventPublisher.subscribe(handler)
    }
    
    func unsubscribe(_ handler: EditorEventHandler) {
        eventPublisher.unsubscribe(handler)
    }
    
    func moveCursor(by offset: Int) {
        guard let currentPosition = selection?.lowerBound else { return }
        let index = content.index(currentPosition, offsetBy: offset, limitedBy: content.endIndex) ?? content.endIndex
        moveCursor(to: index)
    }
    
    func scrollToLine(_ lineNumber: Int) {
        guard let range = lineRange(for: lineNumber) else { return }
        scrollToVisible(range)
    }
    
    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }
    
    func lineNumber(at position: String.Index) -> Int {
        let substring = content[..<position]
        return substring.components(separatedBy: .newlines).count
    }
    
    func lineRange(for lineNumber: Int) -> Range<String.Index>? {
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber > 0, lineNumber <= lines.count else { return nil }
        
        var currentIndex = content.startIndex
        for (index, line) in lines.enumerated() {
            if index == lineNumber - 1 {
                let endIndex = content.index(currentIndex, offsetBy: line.count)
                return currentIndex..<endIndex
            }
            currentIndex = content.index(currentIndex, offsetBy: line.count + 1) // +1 for newline
        }
        return nil
    }
}

// MARK: - Range Conversion Helpers

public extension CodeEditorAPI {
    /// Convert NSRange to Range<String.Index>
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard let range = Range(nsRange, in: content) else { return nil }
        return range
    }
    
    /// Convert Range<String.Index> to NSRange
    func nsRange(from range: Range<String.Index>) -> NSRange {
        NSRange(range, in: content)
    }
}

// MARK: - Convenience Extensions

public extension CodeEditorAPI {
    /// Set content and place cursor at end
    func setContent(_ text: String) {
        content = text
        moveCursor(to: content.endIndex)
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
        guard let range = selection else { return nil }
        return String(content[range])
    }
}
