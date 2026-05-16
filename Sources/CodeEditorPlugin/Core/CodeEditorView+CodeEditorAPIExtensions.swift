import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - CodeEditorAPI Conformance

extension CodeEditorView {
    // MARK: - Content Management

    /// The text content of the editor
    public var content: String {
        get { text ?? "" }
        set { text = newValue }
    }

    /// The attributed text content (if supported).
    ///
    /// On AppKit, reads and writes route through `textContentStorage?.textStorage`
    /// (the TK2-safe accessor). Reading `NSTextView.textStorage` directly
    /// triggers the TextKit 1 compatibility shim and clears `textLayoutManager`
    /// — see the invariant documented in `CodeEditorView.swift` and covered by
    /// `CodeEditorViewTextKit2InitTests`.
    public var attributedContent: NSAttributedString? {
        get {
            #if canImport(AppKit)
            return textContentStorage?.textStorage
            #else
            return attributedText
            #endif
        }
        set {
            #if canImport(AppKit)
            let fullRange = NSRange(location: 0, length: textKitBridge.documentLength)
            textKitBridge.replaceCharacters(in: fullRange, with: newValue ?? NSAttributedString())
            rebuildLineGeometryStoreFromCurrentTextStorage()
            #else
            attributedText = newValue
            #endif
        }
    }

    // selectedRange is already implemented in CodeEditorView. The previous
    // dual `selection: Range<String.Index>?` API was removed; convert through
    // `Range(selectedRange, in: content)` at call sites that need a Swift range.

    // MARK: - Configuration

    // configuration property is already implemented in CodeEditorView
    // language property is already implemented in CodeEditorView

    // MARK: - Events

    // eventPublisher is already implemented in CodeEditorView

    // MARK: - Text Operations

    /// Insert text at current cursor position (CodeEditorAPI implementation)
    #if canImport(UIKit)
    #else
    // On macOS, implement the protocol requirement
    /// Inserts text at the current cursor position.
    ///
    /// This method provides a simplified interface for text insertion, automatically
    /// inserting the text at the current cursor position or replacing the current selection.
    ///
    /// ## Behavior
    ///
    /// - If no text is selected: Inserts text at cursor position
    /// - If text is selected: Replaces selected text with new text
    /// - Triggers syntax highlighting updates if enabled
    /// - Respects editor configuration settings
    ///
    /// ## Parameters
    ///
    /// - Parameter text: The text to insert
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Insert text at cursor
    /// editor.insertText("func newFunction() {}")
    ///
    /// // This will replace any selected text
    /// editor.insertText("replacement text")
    /// ```
    ///
    /// - Note: This method is only available on macOS as part of CodeEditorAPI conformance
    public func insertText(_ text: String) {
        self.insertText(text as Any, replacementRange: selectedRange)
    }
    #endif

    /// Replace text in the UTF-16 range
    public func replaceText(in range: NSRange, with text: String) {
        #if canImport(AppKit)
        insertText(text, replacementRange: range)
        #else
        // For UIKit, we need to replace the text differently
        if let textRange = self.textRange(
            from: self.position(from: self.beginningOfDocument, offset: range.location) ?? self.beginningOfDocument,
            to: self.position(from: self.beginningOfDocument, offset: range.location + range.length) ?? self.beginningOfDocument
        ) {
            self.replace(textRange, withText: text)
        }
        #endif
    }

    /// Delete text in the UTF-16 range
    public func deleteText(in range: NSRange) {
        replaceText(in: range, with: "")
    }

    // MARK: - Selection Operations

    /// Select all text
    public func selectAll() {
        selectAll(nil)
    }

    /// Deselect all text (clear selection)
    public func deselectAll() {
        // Move cursor to current position with zero length selection
        let currentPosition = selectedRange.location
        selectedRange = NSRange(location: currentPosition, length: 0)
    }

    /// Move cursor to a UTF-16 offset
    public func moveCursor(to position: Int) {
        // swiftlint:disable:next legacy_objc_type
        let utf16Length = (content as NSString).length
        let clamped = max(0, min(utf16Length, position))
        selectedRange = NSRange(location: clamped, length: 0)
    }

    /// Move cursor by offset
    public func moveCursor(by offset: Int) {
        // swiftlint:disable:next legacy_objc_type
        let utf16Length = (content as NSString).length
        let currentPosition = selectedRange.location
        let newPosition = max(0, min(currentPosition + offset, utf16Length))
        selectedRange = NSRange(location: newPosition, length: 0)
    }

    // MARK: - Search & Replace

    /// Find text in editor, returning UTF-16 ranges
    public func find(_ text: String, options: FindOptions) -> [NSRange] {
        var ranges: [NSRange] = []
        // swiftlint:disable:next legacy_objc_type
        var searchOptions: NSString.CompareOptions = []

        if options.contains(.caseInsensitive) {
            searchOptions.insert(.caseInsensitive)
        }
        if options.contains(.regularExpression) {
            searchOptions.insert(.regularExpression)
        }

        // swiftlint:disable:next legacy_objc_type
        let nsContent = content as NSString
        var searchRange = NSRange(location: 0, length: nsContent.length)

        while searchRange.location < nsContent.length {
            let foundRange = nsContent.range(of: text, options: searchOptions, range: searchRange)

            if foundRange.location == NSNotFound {
                break
            }

            ranges.append(foundRange)

            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = nsContent.length - searchRange.location
        }

        return ranges
    }

    /// Replace all occurrences
    public func replaceAll(_ searchText: String, with replacement: String, options: FindOptions) -> Int {
        let ranges = find(searchText, options: options)

        // Replace from end to beginning to maintain valid ranges
        for range in ranges.reversed() {
            replaceText(in: range, with: replacement)
        }

        return ranges.count
    }

    // MARK: - Scrolling

    /// Scroll to make UTF-16 range visible
    public func scrollToVisible(_ range: NSRange) {
        // Only scroll if autoScrollToCursor is enabled
        guard configuration.behavior.autoScrollToCursor else { return }

        scrollRangeToVisible(range)
    }

    /// Scroll to line number
    public func scrollToLine(_ lineNumber: Int) {
        // Only scroll if autoScrollToCursor is enabled
        guard configuration.behavior.autoScrollToCursor else { return }

        if let range = lineRange(for: lineNumber) {
            scrollToVisible(range)
        }
    }

    // MARK: - Annotations

    // annotations property is already implemented in CodeEditorView with public private(set)
    // addAnnotation(_:) and removeAnnotation(withId:) are already implemented in CodeEditorView

    // MARK: - Line Information

    /// Get 1-based line number for a UTF-16 offset.
    public func lineNumber(at position: Int) -> Int {
        lineGeometryStore.lineIndex(forUtf16Offset: position) + 1
    }

    /// Get UTF-16 line range for a 1-based line number.
    public func lineRange(for lineNumber: Int) -> NSRange? {
        let idx = lineNumber - 1
        guard let geom = lineGeometryStore.lineGeometry(at: idx) else { return nil }
        let offset = lineGeometryStore.utf16Offset(forLineIndex: idx)
        return NSRange(location: offset, length: geom.utf16Length)
    }

    /// Total number of lines in the document.
    public var lineCount: Int {
        lineGeometryStore.lineCount
    }

    // MARK: - Undo/Redo

    /// Check if can undo
    public var canUndo: Bool {
        undoManager?.canUndo ?? false
    }

    /// Check if can redo
    public var canRedo: Bool {
        undoManager?.canRedo ?? false
    }

    /// Perform undo
    public func undo() {
        undoManager?.undo()
    }

    /// Perform redo
    public func redo() {
        undoManager?.redo()
    }
}
