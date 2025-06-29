import Foundation
import SwiftParser
import SwiftSyntax

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - SwiftSyntaxHighlighter

/// A pure Swift syntax highlighter for Swift code using Apple's SwiftSyntax
@MainActor
public final class SwiftSyntaxHighlighter: @unchecked Sendable {
    // MARK: - Performance Constants
    
    /// Optimized keyword lookup set for O(1) performance
    static let keywords: Set<String> = [
        "let", "var", "func", "class", "struct", "if", "else", "for", "while", 
        "return", "import", "public", "private", "internal", "enum", "protocol",
        "extension", "case", "default", "switch", "do", "try", "catch", "throw",
        "throws", "async", "await", "actor", "init", "deinit", "override",
        "final", "static", "lazy", "weak", "unowned", "mutating", "nonmutating",
        "convenience", "required", "optional", "dynamic", "inout", "associatedtype",
        "typealias", "where", "self", "Self", "super", "nil", "true", "false"
    ]
    
    /// Optimized operator character set
    static let operators: Set<Character> = ["+", "-", "*", "/", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":"]
    
    /// Optimized punctuation character set
    static let punctuation: Set<Character> = ["(", ")", "{", "}", "[", "]", ",", ".", ";", ":"]

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

        public var color: PlatformColor {
            switch self {
            case .keyword:
                PlatformColors.systemPurple

            case .identifier:
                PlatformColors.label

            case .string:
                PlatformColors.systemRed

            case .number:
                PlatformColors.systemBlue

            case .comment:
                PlatformColors.systemGreen

            case .type:
                PlatformColors.systemTeal

            case .function:
                PlatformColors.systemIndigo

            case .property:
                PlatformColors.systemOrange

            case .operator:
                PlatformColors.systemPink

            case .punctuation:
                PlatformColors.secondaryLabel

            case .whitespace:
                PlatformColors.clear

            case .unknown:
                PlatformColors.label
            }
        }
    }

    // Note: HighlightedToken is defined in SyntaxHighlightingCoordinator.swift

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
    private(set) var tokens: [HighlightedToken] = []
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

        tokens.append(HighlightedToken(range: range, type: TokenType(fromSwiftType: type), text: text))
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

        tokens.append(HighlightedToken(range: range, type: TokenType(fromSwiftType: type), text: text))
    }
    
    // MARK: - Token Classification (Performance optimized inline)

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

        // Simple token classification - inline optimization for performance
        let tokenText = node.text
        let tokenType: SwiftSyntaxHighlighter.TokenType = {
            // Use inline optimized classification
            if ["let", "var", "func", "class", "struct", "if", "else", "for", "while", "return", "import", "public", "private", "internal"].contains(tokenText) {
                return .keyword
            } else if tokenText.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) && tokenText.first?.isLetter == true {
                return .identifier
            } else if tokenText.hasPrefix("\"") || tokenText.hasPrefix("'") {
                return .string
            } else if tokenText.allSatisfy({ $0.isNumber || $0 == "." }) && !tokenText.isEmpty {
                return .number
            } else if tokenText.hasPrefix("//") || tokenText.hasPrefix("/*") {
                return .comment
            } else if "+-*/=<>!&|^~?:".contains(tokenText) && tokenText.count == 1 {
                return .operator
            } else if "(){}[],.;:".contains(tokenText) && tokenText.count == 1 {
                return .punctuation
            } else {
                return .unknown
            }
        }()

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

// Note: SyntaxHighlighter conformance is declared in LanguageRegistry.swift
