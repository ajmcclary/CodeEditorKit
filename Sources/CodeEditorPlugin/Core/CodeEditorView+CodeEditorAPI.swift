import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - CodeEditorAPI Conformance

extension CodeEditorView: CodeEditorAPI {
    // MARK: - Content Management
    
    /// The text content of the editor
    public var content: String {
        get { text ?? "" }
        set { text = newValue }
    }
    
    /// The attributed text content (if supported)
    public var attributedContent: NSAttributedString? {
        get { 
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return textStorage
            #else
            return attributedText
            #endif
        }
        set { 
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textStorage?.setAttributedString(newValue ?? NSAttributedString())
            #else
            attributedText = newValue
            #endif
        }
    }
    
    /// Current text selection as a Swift range
    public var selection: Range<String.Index>? {
        get {
            let nsRange = selectedRange
            return Range(nsRange, in: content)
        }
        set {
            if let range = newValue {
                selectedRange = NSRange(range, in: content)
            }
        }
    }
    
    // selectedRange is already implemented in CodeEditorView
    
    // MARK: - Configuration
    
    // configuration property is already implemented in CodeEditorView
    // language property is already implemented in CodeEditorView
    
    // MARK: - Events
    
    // eventPublisher is already implemented in CodeEditorView
    
    // MARK: - Text Operations
    
    /// Insert text at current cursor position
    public func insertText(_ text: String) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        super.insertText(text, replacementRange: selectedRange)
        #else
        super.insertText(text)
        #endif
    }
    
    /// Replace text in range
    public func replaceText(in range: Range<String.Index>, with text: String) {
        let nsRange = NSRange(range, in: content)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        insertText(text, replacementRange: nsRange)
        #else
        // For UIKit, we need to replace the text differently
        if let textRange = self.textRange(from: self.position(from: self.beginningOfDocument, offset: nsRange.location) ?? self.beginningOfDocument,
                                          to: self.position(from: self.beginningOfDocument, offset: nsRange.location + nsRange.length) ?? self.beginningOfDocument) {
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
        let nsRange = NSRange(range, in: content)
        scrollRangeToVisible(nsRange)
    }
    
    /// Scroll to line number
    public func scrollToLine(_ lineNumber: Int) {
        if let range = lineRange(for: lineNumber) {
            scrollToVisible(range)
        }
    }
    
    /// Get currently visible range
    public func visibleRange() -> Range<String.Index>? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleRect = visibleRect
        guard let textContainer,
              let layoutManager else { return nil }
        #else
        let visibleRect = bounds
        let textContainer = self.textContainer
        let layoutManager = self.layoutManager
        #endif
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        return Range(characterRange, in: content)
    }
    
    // MARK: - Annotations
    
    // annotations property is already implemented in CodeEditorView with public private(set)
    // addAnnotation(_:) and removeAnnotation(withId:) are already implemented in CodeEditorView
    
    // MARK: - Line Information
    
    /// Get line number for position
    public func lineNumber(at position: String.Index) -> Int {
        let substring = content[..<position]
        return substring.components(separatedBy: .newlines).count
    }
    
    /// Get line range for line number
    public func lineRange(for lineNumber: Int) -> Range<String.Index>? {
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber > 0, lineNumber <= lines.count else { return nil }
        
        var currentIndex = content.startIndex
        for (index, line) in lines.enumerated() {
            if index == lineNumber - 1 {
                let endIndex = content.index(currentIndex, offsetBy: line.count)
                return currentIndex..<endIndex
            }
            // Move past the line and the newline character
            if currentIndex < content.endIndex {
                currentIndex = content.index(currentIndex, offsetBy: line.count)
                if currentIndex < content.endIndex {
                    currentIndex = content.index(after: currentIndex) // Skip newline
                }
            }
        }
        return nil
    }
    
    /// Total number of lines
    public var lineCount: Int {
        content.components(separatedBy: .newlines).count
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
