import Foundation

// SwiftSyntax is not compatible with iOS
import SwiftParser
import SwiftSyntax

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Shared TokenType (Available for all platforms)

/// Token types for Swift syntax highlighting
public enum SwiftTokenType: String, CaseIterable {
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

    /// Returns the appropriate color for this token type
    public var color: PlatformColor {
        SyntaxColorScheme.default.color(for: self)
    }
}

// MARK: - SwiftSyntaxHighlighter

/// A pure Swift syntax highlighter for Swift code using Apple's SwiftSyntax
public final class SwiftSyntaxHighlighter: Sendable {
    // MARK: - Performance Constants

    /// Optimized keyword lookup set for O(1) performance (shared with fallback implementation)
    static let keywords = SwiftHighlightingUtilities.keywords

    /// Optimized operator character set
    static let operators: Set<Character> = ["+", "-", "*", "/", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":"]

    /// Optimized punctuation character set
    static let punctuation: Set<Character> = ["(", ")", "{", "}", "[", "]", ",", ".", ";", ":"]

    // Note: Using shared SwiftTokenType instead of nested TokenType
    public typealias TokenType = SwiftTokenType

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
    @MainActor
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

    /// Precomputed UTF-8 to UTF-16 offset mapping for token-boundary lookups.
    private let utf8ToUTF16Offsets: [Int: Int]

    init(source: String) {
        self.source = source
        self.utf8ToUTF16Offsets = Self.computeUTF8ToUTF16Offsets(for: source)
        super.init(viewMode: .sourceAccurate)
    }

    /// Builds a direct map from UTF-8 byte offsets to UTF-16 code-unit offsets.
    /// SwiftSyntax positions are UTF-8 offsets, while TextKit consumes UTF-16.
    private static func computeUTF8ToUTF16Offsets(for source: String) -> [Int: Int] {
        var offsets: [Int: Int] = [:]
        offsets.reserveCapacity(source.utf16.count + 1)
        var utf8Offset = 0
        var utf16Offset = 0
        offsets[utf8Offset] = utf16Offset

        for char in source {
            utf8Offset += char.utf8.count
            utf16Offset += char.utf16.count
            offsets[utf8Offset] = utf16Offset
        }

        return offsets
    }

    /// Converts a UTF-8 offset to a UTF-16 offset using the precomputed table.
    /// Falls back to walking the string if the offset is beyond the table.
    private func utf16Offset(forUTF8Offset utf8Offset: Int) -> Int {
        if let offset = utf8ToUTF16Offsets[utf8Offset] {
            return offset
        }

        // Fallback for unexpected offsets that land inside a multi-byte scalar.
        var utf8Count = 0
        var utf16Count = 0
        for char in source {
            if utf8Count >= utf8Offset { break }
            utf8Count += char.utf8.count
            utf16Count += char.utf16.count
        }
        return utf16Count
    }

    private func addToken(for syntax: some SyntaxProtocol, type: SwiftSyntaxHighlighter.TokenType) {
        let utf8Start = syntax.position.utf8Offset
        let utf8End = syntax.endPosition.utf8Offset
        let length = utf8End - utf8Start

        guard length > 0 else {
            return
        }

        let utf16Start = utf16Offset(forUTF8Offset: utf8Start)
        let utf16Length = utf16Offset(forUTF8Offset: utf8End) - utf16Start
        guard utf16Length > 0 else { return }

        let range = NSRange(location: utf16Start, length: utf16Length)

        guard !processedRanges.contains(range) else {
            return
        }
        processedRanges.insert(range)

        let text = syntax.description

        tokens.append(HighlightedToken(range: range, type: TokenType(fromSwiftType: type), text: text))
    }

    private func addTriviaToken(piece: TriviaPiece, node: TokenSyntax, type: SwiftSyntaxHighlighter.TokenType) {
        let utf8Offset = node.position.utf8Offset - node.leadingTriviaLength.utf8Length
        let utf8Length = piece.sourceLength.utf8Length

        let utf16Start = utf16Offset(forUTF8Offset: utf8Offset)
        let utf16End = utf16Offset(forUTF8Offset: utf8Offset + utf8Length)
        let utf16Length = utf16End - utf16Start
        guard utf16Length > 0 else { return }

        let range = NSRange(location: utf16Start, length: utf16Length)

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
