import CodeEditorLanguages
import Foundation

// MARK: - Syntax Tree Parser

/// Parses text into a hierarchical syntax tree structure.
public enum SyntaxTreeParser {
    // MARK: - Public API

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

    // MARK: - Internal Parsing

    static func parseNextNode(in text: String, startingAt index: inout Int, language _: Language) -> SyntaxNode? {
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
                let startIdx = text.index(text.startIndex, offsetBy: startIndex)
                let endIdx = text.index(text.startIndex, offsetBy: index)
                let content = String(text[startIdx..<endIdx])
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
        let startIdx = text.index(text.startIndex, offsetBy: startIndex)
        let endIdx = text.index(text.startIndex, offsetBy: index)
        let content = String(text[startIdx..<endIdx])
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
                let startIdx = text.index(text.startIndex, offsetBy: startIndex)
                let endIdx = text.index(text.startIndex, offsetBy: index)
                let content = String(text[startIdx..<endIdx])
                return SyntaxNode(
                    type: .comment(style: .block(start: "/*", end: "*/")),
                    range: range,
                    content: content,
                    children: []
                )
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
            let startIdx = text.index(text.startIndex, offsetBy: startIndex)
            let endIdx = text.index(text.startIndex, offsetBy: index)
            let content = String(text[startIdx..<endIdx])
            return SyntaxNode(
                type: .block(openChar: openChar, closeChar: closeChar),
                range: range,
                content: content,
                children: []
            )
        }

        return nil // Unmatched block
    }

    // MARK: - Types

    /// A hierarchical node in a parsed syntax tree with type information and content.
    public struct SyntaxNode {
        /// The classification type of this syntax node.
        public let type: NodeType
        /// The range of this node within the source text.
        public let range: NSRange
        /// The actual text content of this node.
        public let content: String
        /// Child nodes contained within this node.
        public let children: [Self]

        /// Categories for different types of syntax nodes in parsed text.
        public enum NodeType {
            /// String literals with their delimiter character.
            case string(delimiter: Character)
            /// Comments with style information.
            case comment(style: CommentStyle)
            /// Block structures with opening and closing characters.
            case block(openChar: Character, closeChar: Character)
            /// Programming language identifiers.
            case identifier

            /// Different styles of comments found in programming languages.
            public enum CommentStyle {
                /// Single-line comments with prefix (// or #).
                case line(prefix: String)
                /// Multi-line block comments with start and end delimiters (/* */).
                case block(start: String, end: String)
                /// Documentation comments with special prefix (/// or ##).
                case documentation(prefix: String)
            }
        }
    }
}
