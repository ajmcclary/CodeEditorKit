import Foundation
import SwiftParser
import SwiftSyntax

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - SwiftSyntaxHighlighter

/// A pure Swift syntax highlighter for Swift code using Apple's SwiftSyntax
@MainActor
public final class SwiftSyntaxHighlighter: @unchecked Sendable {
    // MARK: - Token Types

    public enum TokenType: String, CaseIterable {
        case keyword
        case identifier
        case string
        case number
        case comment
        case type
        case function
        case property
        case `operator`
        case punctuation
        case whitespace
        case unknown

        public var color: NSColor {
            switch self {
            case .keyword:
                NSColor.systemPurple

            case .identifier:
                #if canImport(AppKit)
                NSColor.labelColor
                #else
                UIColor.label
                #endif

            case .string:
                NSColor.systemRed

            case .number:
                NSColor.systemBlue

            case .comment:
                NSColor.systemGreen

            case .type:
                NSColor.systemTeal

            case .function:
                NSColor.systemIndigo

            case .property:
                NSColor.systemOrange

            case .operator:
                NSColor.systemBrown

            case .punctuation:
                #if canImport(AppKit)
                NSColor.secondaryLabelColor
                #else
                UIColor.secondaryLabel
                #endif

            case .whitespace:
                NSColor.clear

            case .unknown:
                #if canImport(AppKit)
                NSColor.labelColor
                #else
                UIColor.label
                #endif
            }
        }
    }

    // MARK: - Highlighted Token

    public struct HighlightedToken {
        public let range: NSRange
        public let type: TokenType
        public let text: String

        public init(range: NSRange, type: TokenType, text: String) {
            self.range = range
            self.type = type
            self.text = text
        }
    }

    // MARK: - Properties

    // Parser is now a static method in SwiftSyntax 510

    // MARK: - Initialization

    public init() {
        // No initialization needed
    }

    // MARK: - Public Methods

    /// Highlight Swift source code and return tokens with their types
    public func highlight(source: String) -> [HighlightedToken] {
        guard !source.isEmpty else {
            return []
        }

        let sourceFile = Parser.parse(source: source)
        let visitor = SyntaxHighlightVisitor(source: source)
        visitor.walk(sourceFile)
        return visitor.tokens
    }

    /// Apply highlighting to an attributed string
    public func applyHighlighting(to attributedString: NSMutableAttributedString, tokens: [HighlightedToken]) {
        // Remove existing syntax highlighting
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.removeAttribute(.foregroundColor, range: range)

        // Apply new highlighting
        for token in tokens {
            guard token.range.location + token.range.length <= attributedString.length else {
                continue
            }
            attributedString.addAttribute(.foregroundColor, value: token.type.color, range: token.range)
        }
    }

    deinit {
        // Cleanup if needed
    }
}

// MARK: - SyntaxHighlightVisitor

private final class SyntaxHighlightVisitor: SyntaxVisitor {
    let source: String
    private(set) var tokens: [SwiftSyntaxHighlighter.HighlightedToken] = []
    private var processedRanges: Set<NSRange> = []

    init(source: String) {
        self.source = source
        super.init(viewMode: .sourceAccurate)
    }

    private func addToken(for syntax: some SyntaxProtocol, type: SwiftSyntaxHighlighter.TokenType) {
        let startOffset = syntax.position.utf8Offset
        let endOffset = syntax.endPosition.utf8Offset
        let length = endOffset - startOffset

        // Skip empty tokens
        guard length > 0 else {
            return
        }

        let range = NSRange(location: startOffset, length: length)

        // Skip if we've already processed this range
        guard !processedRanges.contains(range) else {
            return
        }
        processedRanges.insert(range)

        // Extract text from the syntax node
        let text = syntax.description

        tokens.append(SwiftSyntaxHighlighter.HighlightedToken(range: range, type: type, text: text))
    }

    private func addTriviaToken(piece: TriviaPiece, node: TokenSyntax, type: SwiftSyntaxHighlighter.TokenType) {
        let offset = node.position.utf8Offset - node.leadingTriviaLength.utf8Length
        let length = piece.sourceLength.utf8Length
        let range = NSRange(location: offset, length: length)

        // Extract text from trivia piece
        let text: String = switch piece {
        case let .lineComment(comment):
            comment

        case let .blockComment(comment):
            comment

        default:
            ""
        }

        tokens.append(SwiftSyntaxHighlighter.HighlightedToken(range: range, type: type, text: text))
    }

    // MARK: - Visitor Methods

    override func visit(_ node: TokenSyntax) -> SyntaxVisitorContinueKind {
        // Handle comments in trivia
        for piece in node.leadingTrivia {
            switch piece {
            case .lineComment:
                addTriviaToken(piece: piece, node: node, type: .comment)

            case .blockComment:
                addTriviaToken(piece: piece, node: node, type: .comment)

            default:
                break
            }
        }

        // Map token kinds to our token types
        // In SwiftSyntax 510, we need to check token text for classification
        let tokenText = node.text
        let tokenType: SwiftSyntaxHighlighter.TokenType

            // Simple token classification based on text
            = if [
                "let",
                "var",
                "func",
                "class",
                "struct",
                "if",
                "else",
                "for",
                "while",
                "return",
                "import",
                "public",
                "private",
                "internal"
            ].contains(tokenText) {
            .keyword
        } else if tokenText.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) && tokenText.first?
            .isLetter == true {
            .identifier
        } else if tokenText.hasPrefix("\"") || tokenText.hasPrefix("'") {
            .string
        } else if tokenText.allSatisfy({ $0.isNumber || $0 == "." }) && !tokenText.isEmpty {
            .number
        } else if tokenText.hasPrefix("//") || tokenText.hasPrefix("/*") {
            .comment
        } else if "+-*/=<>!&|^~?:".contains(tokenText), tokenText.count == 1 {
            .operator
        } else if "(){}[],.;:".contains(tokenText), tokenText.count == 1 {
            .punctuation
        } else {
            .unknown
        }

        addToken(for: node, type: tokenType)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        addToken(for: node.name, type: .function)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Mark variable names as properties
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                addToken(for: pattern.identifier, type: .property)
            }
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        addToken(for: node.name, type: .type)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        addToken(for: node.name, type: .type)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        addToken(for: node.name, type: .type)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        addToken(for: node.name, type: .type)
        return .visitChildren
    }

    deinit {
        // Cleanup if needed
    }
}

// MARK: - Extensions

extension TokenKind {
    private var isComment: Bool {
        // In SwiftSyntax 510, comments are handled differently
        false
    }

    private var isWhitespace: Bool {
        // In SwiftSyntax 510, whitespace is handled differently
        false
    }
}

extension NSRange {
    private init(_ range: Range<String.Index>, in string: some StringProtocol) {
        let utf16Range = range.lowerBound ..< range.upperBound
        let start = string.utf16.distance(from: string.utf16.startIndex, to: utf16Range.lowerBound)
        let length = string.utf16.distance(from: utf16Range.lowerBound, to: utf16Range.upperBound)
        self.init(location: start, length: length)
    }
}
