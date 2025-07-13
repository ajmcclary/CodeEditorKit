import Foundation

// MARK: - Text Parsing Utilities

/// Unified text parsing and pattern matching utilities
/// Consolidates and extends CompletionParsingHelpers with additional functionality
public enum TextParsingUtilities {
    // MARK: - Supporting Types
    
    public enum NotationType {
        case dot              // object.property
        case bracket          // object[property]
        case arrow            // object->property
        case doubleColon      // namespace::property
        case generic          // Type<Generic>
    }
    
    public enum LineEndingType: Sendable {
        case unix, windows, classic, mixed
        
        public var characters: String {
            switch self {
            case .unix: return "\n"
            case .windows: return "\r\n"
            case .classic: return "\r"
            case .mixed: return "\n" // Default fallback
            }
        }
    }
    
    public struct IndentationInfo {
        public let spaces: Int
        public let tabs: Int
        public let mixed: Bool
        public let level: Int
        public let indentationStyle: IndentationStyle
        
        public enum IndentationStyle {
            case spaces(width: Int)
            case tabs
            case mixed
        }
        
        public var totalIndentation: Int {
            spaces + (tabs * 4) // Assume 4-space tab width
        }
    }
    
    public struct TextToken {
        public let text: String
        public let range: NSRange
        public let type: TokenType
        public let language: Language?
        
        public enum TokenType {
            case identifier
            case keyword
            case string
            case number
            case comment
            case `operator`
            case punctuation
            case whitespace
            case newline
        }
    }
    
    public struct SyntaxNode {
        public let type: NodeType
        public let range: NSRange
        public let content: String
        public let children: [Self]
        
        public enum NodeType {
            case string(delimiter: Character)
            case comment(style: CommentStyle)
            case block(openChar: Character, closeChar: Character)
            case identifier
            
            public enum CommentStyle {
                case line(prefix: String)      // // or #
                case block(start: String, end: String)  // /* */
                case documentation(prefix: String)      // /// or ##
            }
        }
    }
    
    // MARK: - Pattern Extraction (Enhanced from CompletionParsingHelpers)
    
    /// Extracts target from various notation patterns
    /// Enhanced version of CompletionParsingHelpers.extractTarget
    public static func extractTarget(from text: String, notation: NotationType) -> String? {
        switch notation {
        case .dot:
            return extractDotNotationTarget(from: text)

        case .bracket:
            return extractBracketNotationTarget(from: text)

        case .arrow:
            return extractArrowNotationTarget(from: text)

        case .doubleColon:
            return extractDoubleColonTarget(from: text)

        case .generic:
            return extractGenericTarget(from: text)
        }
    }
    
    /// Extracts comment prefix for a given language
    public static func extractCommentPrefix(for language: Language) -> String? {
        switch language {
        case .swift, .javascript, .typescript, .rust, .go, .java, .c, .cpp:
            return "//"

        case .python, .shell, .yaml, .ruby:
            return "#"

        case .html, .xml:
            return "<!--"

        case .css:
            return "/*"

        default:
            return nil
        }
    }
    
    /// Extracts tokens matching a specific pattern
    public static func extractTokensMatching(pattern: String, in text: String, language: Language? = nil) -> [TextToken] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)
        
        return matches.compactMap { match in
            guard let stringRange = Range(match.range, in: text) else { return nil }
            let matchedText = String(text[stringRange])
            let tokenType = classifyToken(matchedText, language: language)
            
            return TextToken(
                text: matchedText,
                range: match.range,
                type: tokenType,
                language: language
            )
        }
    }
    
    // MARK: - New Consolidated Patterns
    
    /// Finds word boundaries in text with enhanced accuracy
    public static func findWordBoundaries(in text: String, mode: BoundaryMode = .standard) -> [Int] {
        var boundaries: [Int] = [0]
        var index = 0
        var previousCharType: CharacterType = .other
        
        for char in text {
            let currentCharType = classifyCharacterType(char)
            
            // Detect boundary based on character type transitions
            if shouldAddBoundary(previous: previousCharType, current: currentCharType, mode: mode) {
                boundaries.append(index)
            }
            
            previousCharType = currentCharType
            index += 1
        }
        
        if index > 0 {
            boundaries.append(index)
        }
        
        return boundaries
    }
    
    public enum BoundaryMode {
        case standard       // Standard word boundaries
        case camelCase     // Include camelCase boundaries
        case programming   // Programming-specific boundaries
    }
    
    /// Extracts line indentation with detailed analysis
    public static func extractLineIndentation(_ line: String, tabWidth: Int = 4) -> IndentationInfo {
        var spaces = 0
        var tabs = 0
        var mixed = false
        var hasSeenSpaces = false
        var hasSeenTabs = false
        
        for char in line {
            if char == " " {
                spaces += 1
                hasSeenSpaces = true
                if hasSeenTabs { mixed = true }
            } else if char == "\t" {
                tabs += 1
                hasSeenTabs = true
                if hasSeenSpaces { mixed = true }
            } else {
                break // First non-whitespace character
            }
        }
        
        let indentationStyle: IndentationInfo.IndentationStyle
        if mixed {
            indentationStyle = .mixed
        } else if tabs > 0 {
            indentationStyle = .tabs
        } else {
            indentationStyle = .spaces(width: tabWidth)
        }
        
        let level = mixed ? (spaces + tabs * tabWidth) / tabWidth : max(spaces / tabWidth, tabs)
        
        return IndentationInfo(
            spaces: spaces,
            tabs: tabs,
            mixed: mixed,
            level: level,
            indentationStyle: indentationStyle
        )
    }
    
    /// Normalizes line endings to specified format
    public static func normalizeLineEndings(in text: String, to format: LineEndingType) -> String {
        // First, normalize all line endings to \n
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        // Then convert to target format
        switch format {
        case .unix:
            return normalized

        case .windows:
            return normalized.replacingOccurrences(of: "\n", with: "\r\n")

        case .classic:
            return normalized.replacingOccurrences(of: "\n", with: "\r")

        case .mixed:
            return text // Keep original
        }
    }
    
    // MARK: - Syntax Analysis
    
    /// Detects programming language from content analysis
    public static func detectLanguageFromContent(_ text: String) -> Language? {
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        
        // Check for shebangs
        if firstLine.hasPrefix("#!") {
            if firstLine.contains("python") { return .python }
            if firstLine.contains("node") { return .javascript }
            if firstLine.contains("ruby") { return .ruby }
            if firstLine.contains("bash") || firstLine.contains("sh") { return .shell }
        }
        
        // Check for language-specific patterns
        let patterns: [(Language, [String])] = [
            (.swift, ["import Foundation", "import UIKit", "import SwiftUI", "func ", "var ", "let "]),
            (.javascript, ["function ", "const ", "let ", "var ", "=>", "require(", "import {"]),
            (.typescript, ["interface ", "type ", "export ", "import ", ": string", ": number"]),
            (.python, ["def ", "import ", "from ", "class ", "if __name__"]),
            (.rust, ["fn ", "let mut", "use ", "impl ", "struct ", "enum "]),
            (.go, ["package ", "func ", "import ", "var ", "type "]),
            (.java, ["public class", "import java", "public static void main"]),
            (.c, ["#include", "int main", "printf", "malloc"]),
            (.cpp, ["#include <iostream>", "using namespace", "std::", "cout"]),
            (.html, ["<!DOCTYPE", "<html", "<head", "<body", "</html>"]),
            (.css, ["{", ":", ";", "color:", "font-", "margin:"]),
            (.json, ["{", "}", "\":", "\",", "true", "false", "null"]),
            (.yaml, ["---", "- ", ": ", "  - "]),
            (.xml, ["<?xml", "<root", "</root", "xmlns"]),
            (.markdown, ["# ", "## ", "```", "[", "](", "**"]),
            (.shell, ["#!/bin/bash", "echo ", "if [", "for ", "while "]),
            (.sql, ["SELECT ", "FROM ", "WHERE ", "INSERT ", "UPDATE ", "DELETE "]),
            (.php, ["<?php", "function ", "$", "->", "echo "])
        ]
        
        for (language, keywords) in patterns {
            let matchCount = keywords.reduce(0) { count, keyword in
                count + text.components(separatedBy: keyword).count - 1
            }
            
            if matchCount > 2 { // Threshold for confidence
                return language
            }
        }
        
        return nil
    }
    
    /// Extracts string literals with proper escape handling
    public static func extractStringLiterals(from text: String, language: Language) -> [NSRange] {
        let delimiters = getStringDelimiters(for: language)
        var ranges: [NSRange] = []
        
        for delimiter in delimiters {
            ranges.append(contentsOf: findStringRanges(in: text, delimiter: delimiter))
        }
        
        return ranges.sorted { $0.location < $1.location }
    }
    
    /// Finds matching braces/brackets/parentheses
    public static func findMatchingBraces(in text: String, at position: Int) -> NSRange? {
        guard position < text.count else { return nil }
        
        let char = text[text.index(text.startIndex, offsetBy: position)]
        let bracePairs: [Character: Character] = [
            "(": ")", "[": "]", "{": "}",
            ")": "(", "]": "[", "}": "{"
        ]
        
        guard let matchingChar = bracePairs[char] else { return nil }
        
        let isClosing = [")", "]", "}"].contains(char)
        let searchDirection = isClosing ? -1 : 1
        let openChars = isClosing ? [matchingChar] : [char]
        let closeChars = isClosing ? [char] : [matchingChar]
        
        var depth = 1
        var searchIndex = position + searchDirection
        
        while searchIndex >= 0 && searchIndex < text.count {
            let currentChar = text[text.index(text.startIndex, offsetBy: searchIndex)]
            
            if openChars.contains(currentChar) {
                depth += isClosing ? -1 : 1
            } else if closeChars.contains(currentChar) {
                depth += isClosing ? 1 : -1
            }
            
            if depth == 0 {
                let startPos = min(position, searchIndex)
                let length = abs(searchIndex - position) + 1
                return NSRange(location: startPos, length: length)
            }
            
            searchIndex += searchDirection
        }
        
        return nil // No matching brace found
    }
    
    // MARK: - Advanced Parsing
    
    /// Parses text into a hierarchical syntax tree
    public static func parseIntoSyntaxTree(_ text: String, language: Language) -> [SyntaxNode] {
        var nodes: [SyntaxNode] = []
        var index = 0
        
        while index < text.count {
            if let node = parseNextNode(in: text, startingAt: &index, language: language) {
                nodes.append(node)
            } else {
                index += 1 // Skip unrecognized character
            }
        }
        
        return nodes
    }
    
    /// Extracts all identifiers from text
    public static func extractIdentifiers(from text: String, language: Language) -> [TextToken] {
        let identifierPattern = getIdentifierPattern(for: language)
        return extractTokensMatching(pattern: identifierPattern, in: text, language: language)
            .filter { $0.type == .identifier }
    }
}

// MARK: - Private Implementation

extension TextParsingUtilities {
    enum CharacterType {
        case letter, digit, underscore, whitespace, punctuation, other
    }
    
    static func classifyCharacterType(_ char: Character) -> CharacterType {
        if char.isLetter { return .letter }
        if char.isNumber { return .digit }
        if char == "_" { return .underscore }
        if char.isWhitespace { return .whitespace }
        if char.isPunctuation { return .punctuation }
        return .other
    }
    
    static func shouldAddBoundary(previous: CharacterType, current: CharacterType, mode: BoundaryMode) -> Bool {
        switch mode {
        case .standard:
            return (previous == .letter || previous == .digit) && current == .whitespace ||
                   previous == .whitespace && (current == .letter || current == .digit)

        case .camelCase:
            return (previous == .letter && current == .letter) || // Would need case checking
                   shouldAddBoundary(previous: previous, current: current, mode: .standard)

        case .programming:
            return previous != current ||
                   (previous == .letter && current == .underscore) ||
                   (previous == .underscore && current == .letter)
        }
    }
    
    static func extractDotNotationTarget(from text: String) -> String? {
        let components = text.components(separatedBy: ".")
        return components.count > 1 ? components.dropLast().joined(separator: ".") : nil
    }
    
    static func extractBracketNotationTarget(from text: String) -> String? {
        if let bracketIndex = text.lastIndex(of: "[") {
            return String(text[..<bracketIndex])
        }
        return nil
    }
    
    static func extractArrowNotationTarget(from text: String) -> String? {
        let components = text.components(separatedBy: "->")
        return components.count > 1 ? components.dropLast().joined(separator: "->") : nil
    }
    
    static func extractDoubleColonTarget(from text: String) -> String? {
        let components = text.components(separatedBy: "::")
        return components.count > 1 ? components.dropLast().joined(separator: "::") : nil
    }
    
    static func extractGenericTarget(from text: String) -> String? {
        if let angleIndex = text.lastIndex(of: "<") {
            return String(text[..<angleIndex])
        }
        return nil
    }
    
    static func classifyToken(_ text: String, language: Language?) -> TextToken.TokenType {
        // Simple token classification - could be enhanced with language-specific rules
        if text.allSatisfy({ $0.isWhitespace }) { return .whitespace }
        if text.allSatisfy({ $0.isNumber }) { return .number }
        if text.hasPrefix("\"") || text.hasPrefix("'") { return .string }
        if text.hasPrefix("//") || text.hasPrefix("#") { return .comment }
        if text.count == 1 && text.first!.isPunctuation { return .punctuation }
        
        // Check for keywords based on language
        if let language {
            let keywords = getKeywords(for: language)
            if keywords.contains(text) { return .keyword }
        }
        
        if text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return .identifier
        }
        
        return .`operator`
    }
    
    static func getKeywords(for language: Language) -> Set<String> {
        // This would ideally pull from the LanguageMetadataRegistry
        switch language {
        case .swift:
            return ["func", "var", "let", "class", "struct", "enum", "protocol", "import"]

        case .javascript:
            return ["function", "var", "let", "const", "class", "import", "export"]

        case .python:
            return ["def", "class", "import", "from", "if", "else", "for", "while"]

        default:
            return []
        }
    }
    
    static func getStringDelimiters(for language: Language) -> [Character] {
        switch language {
        case .swift, .javascript, .typescript, .java, .c, .cpp:
            return ["\"", "'"]

        case .python:
            return ["\"", "'", "`"] // Including triple quotes would need special handling
        default:
            return ["\"", "'"]
        }
    }
    
    static func findStringRanges(in text: String, delimiter: Character) -> [NSRange] {
        var ranges: [NSRange] = []
        var isInString = false
        var stringStart = 0
        var index = 0
        var isEscaped = false
        
        for char in text {
            if char == delimiter && !isEscaped {
                if isInString {
                    // End of string
                    ranges.append(NSRange(location: stringStart, length: index - stringStart + 1))
                    isInString = false
                } else {
                    // Start of string
                    stringStart = index
                    isInString = true
                }
            }
            
            isEscaped = char == "\\" && !isEscaped
            index += 1
        }
        
        return ranges
    }
    
    static func getIdentifierPattern(for language: Language) -> String {
        switch language {
        case .swift, .java, .c, .cpp:
            return "[a-zA-Z_][a-zA-Z0-9_]*"

        case .javascript, .typescript:
            return "[a-zA-Z_$][a-zA-Z0-9_$]*"

        case .python:
            return "[a-zA-Z_][a-zA-Z0-9_]*"

        default:
            return "[a-zA-Z_][a-zA-Z0-9_]*"
        }
    }
    
    static func parseNextNode(in text: String, startingAt index: inout Int, language _: Language) -> SyntaxNode? {
        // Simplified node parsing - would need more sophisticated implementation
        guard index < text.count else { return nil }
        
        let char = text[text.index(text.startIndex, offsetBy: index)]
        
        // Parse string literals
        if char == "\"" || char == "'" {
            return parseStringLiteral(in: text, startingAt: &index, delimiter: char)
        }
        
        // Parse comments
        if char == "/" && index + 1 < text.count {
            let nextChar = text[text.index(text.startIndex, offsetBy: index + 1)]
            if nextChar == "/" {
                return parseLineComment(in: text, startingAt: &index)
            } else if nextChar == "*" {
                return parseBlockComment(in: text, startingAt: &index)
            }
        }
        
        // Parse blocks
        if ["(", "[", "{"].contains(char) {
            return parseBlock(in: text, startingAt: &index, openChar: char)
        }
        
        return nil
    }
    
    static func parseStringLiteral(in text: String, startingAt index: inout Int, delimiter: Character) -> SyntaxNode? {
        let startIndex = index
        index += 1 // Skip opening delimiter
        
        while index < text.count {
            let char = text[text.index(text.startIndex, offsetBy: index)]
            if char == delimiter {
                index += 1 // Include closing delimiter
                let range = NSRange(location: startIndex, length: index - startIndex)
                let content = String(text[text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: index)])
                return SyntaxNode(type: .string(delimiter: delimiter), range: range, content: content, children: [])
            }
            if char == "\\" && index + 1 < text.count {
                index += 2 // Skip escaped character
            } else {
                index += 1
            }
        }
        
        return nil // Unterminated string
    }
    
    static func parseLineComment(in text: String, startingAt index: inout Int) -> SyntaxNode? {
        let startIndex = index
        
        // Find end of line
        while index < text.count {
            let char = text[text.index(text.startIndex, offsetBy: index)]
            if char == "\n" {
                break
            }
            index += 1
        }
        
        let range = NSRange(location: startIndex, length: index - startIndex)
        let content = String(text[text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: index)])
        return SyntaxNode(type: .comment(style: .line(prefix: "//")), range: range, content: content, children: [])
    }
    
    static func parseBlockComment(in text: String, startingAt index: inout Int) -> SyntaxNode? {
        let startIndex = index
        index += 2 // Skip /*
        
        while index + 1 < text.count {
            let char = text[text.index(text.startIndex, offsetBy: index)]
            let nextChar = text[text.index(text.startIndex, offsetBy: index + 1)]
            
            if char == "*" && nextChar == "/" {
                index += 2 // Include closing */
                let range = NSRange(location: startIndex, length: index - startIndex)
                let content = String(text[text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: index)])
                return SyntaxNode(type: .comment(style: .block(start: "/*", end: "*/")), range: range, content: content, children: [])
            }
            index += 1
        }
        
        return nil // Unterminated comment
    }
    
    static func parseBlock(in text: String, startingAt index: inout Int, openChar: Character) -> SyntaxNode? {
        let closeChar: Character
        switch openChar {
        case "(": closeChar = ")"
        case "[": closeChar = "]"
        case "{": closeChar = "}"
        default: return nil
        }
        
        let startIndex = index
        var depth = 1
        index += 1 // Skip opening character
        
        while index < text.count && depth > 0 {
            let char = text[text.index(text.startIndex, offsetBy: index)]
            if char == openChar {
                depth += 1
            } else if char == closeChar {
                depth -= 1
            }
            index += 1
        }
        
        if depth == 0 {
            let range = NSRange(location: startIndex, length: index - startIndex)
            let content = String(text[text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: index)])
            return SyntaxNode(type: .block(openChar: openChar, closeChar: closeChar), range: range, content: content, children: [])
        }
        
        return nil // Unmatched block
    }
}
