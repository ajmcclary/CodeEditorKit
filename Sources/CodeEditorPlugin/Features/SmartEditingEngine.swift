import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import os.log

/// Smart editing engine for auto-brackets, multi-cursor, and other intelligent features
@MainActor
public class SmartEditingEngine: NSObject, ObservableObject, NSTextViewDelegate {
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "SmartEditingEngine")
    
    // MARK: - Published Properties
    
    @Published public var configuration = SmartEditingConfiguration()
    @Published public private(set) var cursors: [TextCursor] = []
    @Published public private(set) var isMultiCursorMode = false
    
    // MARK: - Properties
    
    private weak var textView: CodeEditorView?
    private var bracketPairs: [BracketPair] = []
    private var autoIndentRules: [AutoIndentRule] = []
    
    // MARK: - Initialization
    
    override public init() {
        super.init()
        setupDefaultRules()
    }
    
    /// Attach to a text view
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
        
        // Set self as delegate to intercept text changes
        if textView.delegate != nil {
            logger.warning("Replacing existing text view delegate")
        }
        textView.delegate = self
    }
    
    private func setupDefaultRules() {
        // Setup default bracket pairs
        bracketPairs = [
            BracketPair(open: "(", close: ")"),
            BracketPair(open: "[", close: "]"),
            BracketPair(open: "{", close: "}"),
            BracketPair(open: "\"", close: "\"", isQuote: true),
            BracketPair(open: "'", close: "'", isQuote: true),
            BracketPair(open: "`", close: "`", isQuote: true)
        ]
        
        // Setup auto-indent rules
        autoIndentRules = [
            AutoIndentRule(trigger: "{", action: .increaseIndent),
            AutoIndentRule(trigger: "}", action: .decreaseIndent),
            AutoIndentRule(trigger: ":", action: .increaseIndentNext), // Python
            AutoIndentRule(trigger: "case", action: .increaseIndent), // Switch statements
            AutoIndentRule(trigger: "default:", action: .maintainIndent)
        ]
    }
    
    // MARK: - Auto Bracket Insertion
    
    /// Handle character insertion for auto-bracket functionality
    private func handleCharacterInsertion(_ string: String, at range: NSRange) -> Bool {
        guard configuration.autoInsertBrackets else { return false }
        
        // Check if this is an opening bracket
        if let pair = bracketPairs.first(where: { $0.open == string }) {
            return handleOpeningBracket(pair, at: range)
        }
        
        // Check if this is a closing bracket
        if let pair = bracketPairs.first(where: { $0.close == string }) {
            return handleClosingBracket(pair, at: range)
        }
        
        return false
    }
    
    private func handleOpeningBracket(_ pair: BracketPair, at range: NSRange) -> Bool {
        guard let textView,
              let textStorage = textView.textStorage else { return false }
        
        // For quotes, check if we should auto-pair
        if pair.isQuote {
            // Don't auto-pair if there's already a matching quote
            if range.location < textStorage.length {
                let nextChar = textStorage.attributedSubstring(
                    from: NSRange(location: range.location, length: 1)
                ).string
                if nextChar == pair.close {
                    // Just move cursor past the quote
                    textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                    return true
                }
            }
            
            // Don't auto-pair inside words
            if range.location > 0 {
                let prevChar = textStorage.attributedSubstring(
                    from: NSRange(location: range.location - 1, length: 1)
                ).string
                if prevChar.rangeOfCharacter(from: .alphanumerics) != nil {
                    return false
                }
            }
        }
        
        // Insert both opening and closing brackets
        let insertString = pair.open + pair.close
        textStorage.replaceCharacters(in: range, with: insertString)
        
        // Position cursor between brackets
        textView.selectedRange = NSRange(location: range.location + 1, length: 0)
        
        return true
    }
    
    private func handleClosingBracket(_ pair: BracketPair, at range: NSRange) -> Bool {
        guard let textView,
              let textStorage = textView.textStorage else { return false }
        
        // Check if the next character is the same closing bracket
        if range.location < textStorage.length {
            let nextChar = textStorage.attributedSubstring(
                from: NSRange(location: range.location, length: 1)
            ).string
            
            if nextChar == pair.close {
                // Skip over the closing bracket
                textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Multi-Cursor Support
    
    /// Add a cursor at the specified location
    public func addCursor(at location: Int) {
        let newCursor = TextCursor(location: location)
        
        // Ensure cursor isn't duplicate
        if !cursors.contains(where: { $0.location == location }) {
            cursors.append(newCursor)
            cursors.sort { $0.location < $1.location }
            isMultiCursorMode = true
            
            updateCursorVisuals()
        }
    }
    
    /// Add cursors at all occurrences of selected text
    public func addCursorsAtOccurrences() {
        guard let textView,
              textView.selectedRange.length > 0,
              let selectedText = textView.textStorage?.attributedSubstring(
                from: textView.selectedRange
              ).string else { return }
        
        // Find all occurrences
        let text = textView.string
        var searchRange = NSRange(location: 0, length: text.count)
        
        cursors.removeAll()
        
        while searchRange.location < text.count {
            guard let swiftRange = Range(searchRange, in: text) else { break }
            let foundSwiftRange = text.range(of: selectedText, options: [], range: swiftRange)
            let foundRange = foundSwiftRange.map { NSRange($0, in: text) } ?? NSRange(location: NSNotFound, length: 0)
            
            if foundRange.location == NSNotFound {
                break
            }
            
            addCursor(at: foundRange.location)
            
            searchRange.location = NSMaxRange(foundRange)
            searchRange.length = text.count - searchRange.location
        }
        
        logger.info("Added \(self.cursors.count) cursors for occurrences of '\(selectedText)'")
    }
    
    /// Clear all extra cursors
    public func clearMultiCursors() {
        cursors.removeAll()
        isMultiCursorMode = false
        updateCursorVisuals()
    }
    
    /// Handle text input with multiple cursors
    private func handleMultiCursorInput(_ string: String) -> Bool {
        guard isMultiCursorMode,
              !cursors.isEmpty,
              let textStorage = textView?.textStorage else { return false }
        
        // Begin grouped editing
        textStorage.beginEditing()
        
        // Insert text at each cursor location (in reverse order to maintain positions)
        for cursor in cursors.reversed() {
            let range = NSRange(location: cursor.location, length: cursor.selection)
            textStorage.replaceCharacters(in: range, with: string)
            
            // Update cursor positions for remaining cursors
            let lengthChange = string.count - cursor.selection
            for index in 0..<cursors.count where cursors[index].location > cursor.location {
                cursors[index].location += lengthChange
            }
        }
        
        textStorage.endEditing()
        
        // Update cursor positions
        for index in 0..<cursors.count {
            cursors[index].location += string.count
            cursors[index].selection = 0
        }
        
        updateCursorVisuals()
        
        return true
    }
    
    private func updateCursorVisuals() {
        // This would update visual indicators for multiple cursors
        // Implementation depends on platform-specific drawing
    }
    
    // MARK: - Smart Indentation
    
    /// Calculate indentation for a new line
    private func calculateIndentation(at location: Int) -> String {
        guard let textStorage = textView?.textStorage,
              configuration.autoIndent else { return "" }
        
        // Get the current line
        let lineRange = RangeUtilities.lineRange(containing: location, in: textStorage.string)
        let currentLine = textStorage.attributedSubstring(from: lineRange).string
        
        // Extract current indentation
        let indentation = currentLine.prefix { $0 == " " || $0 == "\t" }
        var newIndentation = String(indentation)
        
        // Check auto-indent rules
        for rule in autoIndentRules where currentLine.contains(rule.trigger) {
                switch rule.action {
                case .increaseIndent:
                    newIndentation += configuration.insertSpacesForTabs ?
                        String(repeating: " ", count: configuration.tabWidth) : "\t"

                case .decreaseIndent:
                    // Remove one level of indentation
                    if configuration.insertSpacesForTabs {
                        for _ in 0..<configuration.tabWidth where newIndentation.hasSuffix(" ") {
                            newIndentation.removeLast()
                        }
                    } else if newIndentation.hasSuffix("\t") {
                        newIndentation.removeLast()
                    }

                case .increaseIndentNext:
                    // Will increase on next line
                    break

                case .maintainIndent:
                    break
                }
        }
        
        return newIndentation
    }
    
    // MARK: - Smart Selection
    
    /// Expand selection to logical boundaries
    public func expandSelection() {
        guard let textView else { return }
        
        let currentRange = textView.selectedRange
        
        // Try different expansion levels
        if let expandedRange = expandToWord(from: currentRange) {
            textView.selectedRange = expandedRange
        } else if let expandedRange = expandToLine(from: currentRange) {
            textView.selectedRange = expandedRange
        } else if let expandedRange = expandToBrackets(from: currentRange) {
            textView.selectedRange = expandedRange
        }
    }
    
    private func expandToWord(from range: NSRange) -> NSRange? {
        guard let text = textView?.string else { return nil }
        
        return RangeUtilities.wordRange(at: range.location, in: text)
    }
    
    private func expandToLine(from range: NSRange) -> NSRange? {
        guard let text = textView?.string else { return nil }
        
        return RangeUtilities.lineRange(containing: range.location, in: text)
    }
    
    private func expandToBrackets(from range: NSRange) -> NSRange? {
        guard let text = textView?.string else { return nil }
        
        // Find enclosing brackets
        var startPos = range.location
        var endPos = NSMaxRange(range)
        
        // Stack to track bracket pairs
        var bracketStack: [Character] = []
        
        // Search backward for opening bracket
        while startPos > 0 {
            startPos -= 1
            guard let charIndex = text.utf16.index(text.utf16.startIndex, offsetBy: startPos, limitedBy: text.utf16.endIndex) else { break }
            let char = text.utf16[charIndex]
            let unicodeChar = Character(UnicodeScalar(char)!)
            
            if [")", "]", "}"].contains(unicodeChar) {
                bracketStack.append(unicodeChar)
            } else if ["(", "[", "{"].contains(unicodeChar) {
                if bracketStack.isEmpty {
                    // Found unmatched opening bracket
                    break
                } else {
                    bracketStack.removeLast()
                }
            }
        }
        
        // Search forward for closing bracket
        bracketStack.removeAll()
        while endPos < text.utf16.count {
            guard let charIndex = text.utf16.index(text.utf16.startIndex, offsetBy: endPos, limitedBy: text.utf16.endIndex) else { break }
            let char = text.utf16[charIndex]
            let unicodeChar = Character(UnicodeScalar(char)!)
            
            if ["(", "[", "{"].contains(unicodeChar) {
                bracketStack.append(unicodeChar)
            } else if [")", "]", "}"].contains(unicodeChar) {
                if bracketStack.isEmpty {
                    // Found unmatched closing bracket
                    endPos += 1
                    break
                } else {
                    bracketStack.removeLast()
                }
            }
            endPos += 1
        }
        
        // Return expanded range if we found brackets
        if startPos < range.location && endPos > NSMaxRange(range) {
            return NSRange(location: startPos, length: endPos - startPos)
        }
        
        return nil
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Text View Delegate

@MainActor
extension SmartEditingEngine: CodeEditorViewDelegate {
    public func textView(_ textView: CodeEditorView, shouldChangeTextIn range: NSRange, replacementString string: String) -> Bool {
        // Handle multi-cursor input
        if isMultiCursorMode && !string.isEmpty {
            return !handleMultiCursorInput(string)
        }
        
        // Handle auto-bracket insertion
        if string.count == 1 {
            if handleCharacterInsertion(string, at: range) {
                return false
            }
        }
        
        // Handle enter key for auto-indentation
        if string == "\n" && configuration.autoIndent {
            let indentation = calculateIndentation(at: range.location)
            if !indentation.isEmpty {
                textView.textStorage?.replaceCharacters(
                    in: range,
                    with: "\n" + indentation
                )
                return false
            }
        }
        
        return true
    }
    
    public func textViewDidChangeSelection(_ textView: CodeEditorView) {
        // Update multi-cursor mode if needed
        if isMultiCursorMode && textView.selectedRange.length > 0 {
            // Selection made, might want to exit multi-cursor mode
            // or update cursor positions
        }
    }
    
    // MARK: - Other delegate methods with default implementations
    
    public func undoManager(for _: CodeEditorView) -> UndoManager? { nil }
    
    public func textViewWillChangeText(_: Notification) {}
    
    public func textViewDidChangeText(_: Notification) {}
    
    public func textViewDidChangeSelection(_: Notification) {}
    
    public func textView(_: CodeEditorView, shouldChangeTextIn _: NSTextRange, replacementString _: String?) -> Bool { true }
    
    public func textView(_: CodeEditorView, willChangeTextIn _: NSTextRange, replacementString _: String) {}
    
    public func textView(_: CodeEditorView, didChangeTextIn _: NSTextRange, replacementString _: String) {}
    
    public func textView(_: CodeEditorView, clickedOnLink _: Any, at _: any NSTextLocation) -> Bool { false }
    
    public func textView(_: CodeEditorView, insertCompletionItem _: any CompletionItem) {}
    
    public func textViewCompletionViewController(_: CodeEditorView) -> any CompletionViewControllerProtocol { 
        // SmartEditingEngine doesn't provide completion - return a default implementation
        CompletionViewController()
    }
    
    public func textViewInsertionPointView(_: CodeEditorView, frame _: CGRect) -> (InsertionPointIndicatorProtocol)? { nil }
    
    public func textView(_: CodeEditorView, clickedOnAttachment _: NSTextAttachment, at _: any NSTextLocation) -> Bool { false }
    
    public func textView(_: CodeEditorView, shouldAllowInteractionWith _: NSTextAttachment, at _: any NSTextLocation) -> Bool { false }
}

// MARK: - Supporting Types

/// Text cursor for multi-cursor editing
public struct TextCursor: Identifiable {
    public let id = UUID()
    public var location: Int
    public var selection: Int = 0
    
    public var range: NSRange {
        NSRange(location: location, length: selection)
    }
}

/// Bracket pair definition
public struct BracketPair {
    public let open: String
    public let close: String
    public let isQuote: Bool
    
    public init(open: String, close: String, isQuote: Bool = false) {
        self.open = open
        self.close = close
        self.isQuote = isQuote
    }
}

/// Auto-indent rule
public struct AutoIndentRule {
    public let trigger: String
    public let action: IndentAction
    
    public enum IndentAction {
        case increaseIndent
        case decreaseIndent
        case increaseIndentNext
        case maintainIndent
    }
}

/// Smart editing configuration
public struct SmartEditingConfiguration {
    // Auto-bracket insertion
    public var autoInsertBrackets = true
    public var autoInsertQuotes = true
    public var wrapSelection = true
    
    // Multi-cursor
    public var enableMultiCursor = true

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var multiCursorModifierKey: NSEvent.ModifierFlags = .option
    #else
    public var multiCursorModifierKey: UIKeyModifierFlags = .alternate
    #endif
    
    // Auto-indentation
    public var autoIndent = true
    public var insertSpacesForTabs = true
    public var tabWidth = 4
    public var detectIndentation = true
    
    // Smart selection
    public var enableSmartSelection = true
    public var expandSelectionStops: [SelectionStop] = [.word, .line, .scope, .all]
    
    public enum SelectionStop {
        case word
        case line
        case scope
        case all
    }
}

// MARK: - Convenience Extensions

extension CodeEditorView {
    /// Access the smart editing engine
    public var smartEditingEngine: SmartEditingEngine {
        // This would be stored as an associated object or property
        // For now, creating a new instance
        let engine = SmartEditingEngine()
        engine.attach(to: self)
        return engine
    }
}
