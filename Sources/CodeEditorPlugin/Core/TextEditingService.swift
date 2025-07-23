import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - TextEditingService

/// Service responsible for text editing and manipulation business logic
/// Separates text editing operations from UI implementation
@MainActor
public final class TextEditingService {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "TextEditingService")

    // MARK: - Initialization

    /// Creates a new text editing service
    public init() {}

    // MARK: - Text Validation

    /// Validates if text can be safely set
    public func validateTextChange(newText: String?, maxLength: Int) -> TextValidationResult {
        guard let text = newText else {
            return .valid(sanitizedText: "")
        }

        // Check for binary content
        if containsBinaryContent(text) {
            return .invalid(reason: .binaryContent)
        }

        // Check length
        if text.count > maxLength {
            return .invalid(reason: .exceedsMaxLength(maxLength))
        }

        // Sanitize null characters
        let sanitized = text.replacingOccurrences(of: "\0", with: "")
        if sanitized != text {
            logger.warning("Removed null characters from text")
        }

        return .valid(sanitizedText: sanitized)
    }

    /// Checks if text contains binary content
    public func containsBinaryContent(_ text: String) -> Bool {
        // Check for common binary indicators
        let binaryIndicators: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x0B, 0x0E, 0x0F,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
        ]

        let data = text.data(using: .utf8) ?? Data()
        let threshold = min(1_000, data.count) // Check first 1KB

        var binaryCount = 0
        for index in 0..<threshold where binaryIndicators.contains(data[index]) {
            binaryCount += 1
            if binaryCount > 10 { // More than 10 binary characters in first 1KB
                return true
            }
        }

        return false
    }

    // MARK: - Text Operations

    /// Calculates the range for inserting text at a given location
    public func calculateInsertionRange(at location: Int, textLength: Int) -> NSRange? {
        guard location >= 0 && location <= textLength else {
            logger.warning("Invalid insertion location: \(location) for text length: \(textLength)")
            return nil
        }

        return NSRange(location: location, length: 0)
    }

    /// Calculates the range for replacing text
    public func calculateReplacementRange(selectedRange: NSRange, textLength: Int) -> NSRange? {
        guard selectedRange.location >= 0,
              selectedRange.location + selectedRange.length <= textLength else {
            logger.warning("Invalid replacement range: \(selectedRange) for text length: \(textLength)")
            return nil
        }

        return selectedRange
    }

    /// Sanitizes text for safe insertion
    public func sanitizeTextForInsertion(_ text: String) -> String {
        // Remove null characters
        var sanitized = text.replacingOccurrences(of: "\0", with: "")

        // Normalize line endings to \n
        sanitized = sanitized.replacingOccurrences(of: "\r\n", with: "\n")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: "\n")

        return sanitized
    }

    // MARK: - Indentation

    /// Calculates indentation for a new line based on the previous line
    public func calculateIndentation(
        forNewLineAfter previousLine: String,
        configuration: EditorConfiguration
    ) -> String {
        guard configuration.behavior.autoIndent else {
            return ""
        }

        // Calculate leading whitespace from previous line
        let leadingWhitespace = previousLine.prefix { $0.isWhitespace }
        var indentation = String(leadingWhitespace)

        // Check if we should increase indentation
        let trimmedLine = previousLine.trimmingCharacters(in: .whitespaces)
        if shouldIncreaseIndentation(for: trimmedLine) {
            if configuration.layout.insertSpacesForTabs {
                indentation += String(repeating: " ", count: configuration.layout.tabWidth)
            } else {
                indentation += "\t"
            }
        }

        return indentation
    }

    /// Determines if indentation should be increased based on line content
    public func shouldIncreaseIndentation(for line: String) -> Bool {
        // Common patterns that increase indentation
        let increasePatterns = [
            "\\{\\s*$",           // Opening brace at end
            ":\\s*$",             // Colon at end (Swift, Python)
            "\\(\\s*$",           // Opening parenthesis at end
            "\\[\\s*$",           // Opening bracket at end
            "->\\s*$",            // Arrow at end (Swift)
            "=>\\s*$",            // Arrow at end (JavaScript)
            "\\bif\\b.*\\bthen\\s*$", // if-then (various languages)
            "\\bdo\\s*$",         // do block
            "\\bbegin\\s*$"       // begin block
        ]

        for pattern in increasePatterns where line.range(of: pattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    // MARK: - Smart Editing

    /// Handles smart bracket/quote insertion
    public func getSmartInsertionPair(for character: Character) -> String? {
        let pairs: [Character: String] = [
            "(": ")",
            "[": "]",
            "{": "}",
            "\"": "\"",
            "'": "'",
            "`": "`"
        ]

        return pairs[character]
    }

    /// Checks if a character should trigger smart insertion
    public func shouldPerformSmartInsertion(
        for character: Character,
        configuration: EditorConfiguration
    ) -> Bool {
        guard configuration.behavior.autoIndent else {
            return false
        }

        let smartCharacters: Set<Character> = ["(", "[", "{", "\"", "'", "`"]
        return smartCharacters.contains(character)
    }

    // MARK: - Line Operations

    /// Extracts the current line from text at a given location
    public func getCurrentLine(at location: Int, in text: String) -> (line: String, range: NSRange)? {
        guard location >= 0 && location <= text.count else {
            return nil
        }

        // Convert location to String.Index
        guard let targetIndex = text.index(text.startIndex, offsetBy: location, limitedBy: text.endIndex) else {
            return nil
        }

        // Find line start
        var lineStart = targetIndex
        while lineStart > text.startIndex {
            let prevIndex = text.index(before: lineStart)
            if text[prevIndex].isNewline {
                break
            }
            lineStart = prevIndex
        }

        // Find line end (excluding newline)
        var lineEnd = targetIndex
        while lineEnd < text.endIndex && !text[lineEnd].isNewline {
            lineEnd = text.index(after: lineEnd)
        }

        // Extract line
        let line = String(text[lineStart..<lineEnd])

        // Calculate NSRange
        let startOffset = text.distance(from: text.startIndex, to: lineStart)
        let length = text.distance(from: lineStart, to: lineEnd)
        let lineRange = NSRange(location: startOffset, length: length)

        return (line, lineRange)
    }

    /// Counts lines in text
    public func countLines(in text: String) -> Int {
        guard !text.isEmpty else { return 1 }

        var lineCount = 0
        text.enumerateLines { _, _ in
            lineCount += 1
        }

        // If text ends with newline, add one more line
        if text.hasSuffix("\n") {
            lineCount += 1
        }

        return max(1, lineCount)
    }

    // MARK: - Selection

    /// Validates and adjusts selection range
    public func validateSelectionRange(_ range: NSRange, textLength: Int) -> NSRange {
        let location = max(0, min(range.location, textLength))
        let length = max(0, min(range.length, textLength - location))
        return NSRange(location: location, length: length)
    }

    /// Calculates word boundaries at a given location
    public func getWordBoundaries(at location: Int, in text: String) -> NSRange? {
        guard location >= 0 && location <= text.count else {
            return nil
        }

        // Convert location to String.Index
        guard let targetIndex = text.index(text.startIndex, offsetBy: location, limitedBy: text.endIndex) else {
            return nil
        }

        // Helper to check if character is part of a word
        func isWordCharacter(_ char: Character) -> Bool {
            char.isLetter || char.isNumber || char == "_"
        }

        // Find word start
        var wordStart = targetIndex
        while wordStart > text.startIndex {
            let prevIndex = text.index(before: wordStart)
            if !isWordCharacter(text[prevIndex]) {
                break
            }
            wordStart = prevIndex
        }

        // Find word end
        var wordEnd = targetIndex
        while wordEnd < text.endIndex && isWordCharacter(text[wordEnd]) {
            wordEnd = text.index(after: wordEnd)
        }

        // Calculate NSRange
        let startOffset = text.distance(from: text.startIndex, to: wordStart)
        let length = text.distance(from: wordStart, to: wordEnd)

        if length > 0 {
            return NSRange(location: startOffset, length: length)
        }

        return nil
    }
}

// MARK: - Supporting Types

/// Result of text validation operation
public enum TextValidationResult {
    /// Text is valid and safe to use
    case valid(sanitizedText: String)
    /// Text is invalid for the given reason
    case invalid(reason: TextValidationError)
}

/// Reasons why text validation might fail
public enum TextValidationError {
    /// Text contains binary content that cannot be displayed
    case binaryContent
    /// Text exceeds the maximum allowed length
    case exceedsMaxLength(Int)
    /// Text has invalid encoding
    case invalidEncoding
}
