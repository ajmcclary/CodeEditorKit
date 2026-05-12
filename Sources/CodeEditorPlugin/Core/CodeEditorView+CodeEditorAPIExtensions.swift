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

    /// The attributed text content (if supported)
    public var attributedContent: NSAttributedString? {
        get {
            #if canImport(AppKit)
            return textStorage
            #else
            return attributedText
            #endif
        }
        set {
            #if canImport(AppKit)
            textStorage?.setAttributedString(newValue ?? NSAttributedString())
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

    /// Replace text in range
    public func replaceText(in range: Range<String.Index>, with text: String) {
        let nsRange = NSRange(range, in: content)
        #if canImport(AppKit)
        insertText(text, replacementRange: nsRange)
        #else
        // For UIKit, we need to replace the text differently
        if let textRange = self.textRange(
            from: self.position(from: self.beginningOfDocument, offset: nsRange.location) ?? self.beginningOfDocument,
            to: self.position(from: self.beginningOfDocument, offset: nsRange.location + nsRange.length) ?? self.beginningOfDocument
        ) {
            self.replace(textRange, withText: text)
        }
        #endif
    }

    /// Delete text in range
    public func deleteText(in range: Range<String.Index>) {
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

    /// Move cursor to position
    public func moveCursor(to position: String.Index) {
        let location = content.distance(from: content.startIndex, to: position)
        selectedRange = NSRange(location: location, length: 0)
    }

    /// Move cursor by offset
    public func moveCursor(by offset: Int) {
        let currentPosition = selectedRange.location
        let newPosition = max(0, min(currentPosition + offset, content.count))
        selectedRange = NSRange(location: newPosition, length: 0)
    }

    // MARK: - Search & Replace

    /// Find text in editor
    public func find(_ text: String, options: FindOptions) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
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

            if let range = Range(foundRange, in: content) {
                ranges.append(range)
            }

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

    /// Scroll to make range visible
    public func scrollToVisible(_ range: Range<String.Index>) {
        // Only scroll if autoScrollToCursor is enabled
        guard configuration.behavior.autoScrollToCursor else { return }

        let nsRange = NSRange(range, in: content)
        scrollRangeToVisible(nsRange)
    }

    /// Scroll to line number
    public func scrollToLine(_ lineNumber: Int) {
        // Only scroll if autoScrollToCursor is enabled
        guard configuration.behavior.autoScrollToCursor else { return }

        if let range = lineRange(for: lineNumber) {
            scrollToVisible(range)
        }
    }

    /// Get currently visible range
    public func visibleRange() -> Range<String.Index>? {
        #if canImport(AppKit)
        let visibleRect = visibleRect
        guard let textContainer,
              let layoutManager else { return nil }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        return Range(characterRange, in: content)
        #else
        // iOS: Access layoutManager directly
        let visibleRect = bounds
        let textContainer = self.textContainer
        let layoutManager = self.layoutManager

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        return Range(characterRange, in: content)
        #endif
    }

    // MARK: - Annotations

    // annotations property is already implemented in CodeEditorView with public private(set)
    // addAnnotation(_:) and removeAnnotation(withId:) are already implemented in CodeEditorView

    // MARK: - Line Information

    /// Get 1-based line number for a String.Index position.
    public func lineNumber(at position: String.Index) -> Int {
        let offset = content.utf16.distance(from: content.utf16.startIndex, to: position)
        return lineGeometryStore.lineIndex(forUtf16Offset: offset) + 1
    }

    /// Get line range for a 1-based line number.
    public func lineRange(for lineNumber: Int) -> Range<String.Index>? {
        let idx = lineNumber - 1
        guard let geom = lineGeometryStore.lineGeometry(at: idx) else { return nil }
        let offset = lineGeometryStore.utf16Offset(forLineIndex: idx)
        let nsRange = NSRange(location: offset, length: geom.utf16Length)
        return Range(nsRange, in: content)
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
