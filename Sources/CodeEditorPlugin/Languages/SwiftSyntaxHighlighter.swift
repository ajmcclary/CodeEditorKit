import Foundation

// SwiftSyntax is not compatible with Mac Catalyst
#if !targetEnvironment(macCatalyst)
import SwiftParser
import SwiftSyntax
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
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

// MARK: - SwiftSyntaxHighlighter

#if !targetEnvironment(macCatalyst)
/// A pure Swift syntax highlighter for Swift code using Apple's SwiftSyntax
public final class SwiftSyntaxHighlighter: Sendable {
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

#else
// Mac Catalyst fallback - provide compatible interface
public final class SwiftSyntaxHighlighter: Sendable {
    public init() {}
    
    // Use shared SwiftTokenType instead of duplicating
    public typealias TokenType = SwiftTokenType
    
    public func highlight(source: String) -> [HighlightedToken] {
        // Fallback to basic keyword-based highlighting on Mac Catalyst
        // Since RegexSyntaxHighlighter doesn't handle Swift, we'll do simple keyword matching
        performBasicSwiftHighlighting(source: source)
    }
    
    private func performBasicSwiftHighlighting(source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        
        // Add keywords
        tokens.append(contentsOf: highlightKeywords(in: source))
        
        // Add strings
        tokens.append(contentsOf: highlightStrings(in: source))
        
        // Add comments
        tokens.append(contentsOf: highlightComments(in: source))
        
        // Add numbers
        tokens.append(contentsOf: highlightNumbers(in: source))
        
        return tokens.sorted { $0.range.location < $1.range.location }
    }
    
    private func highlightKeywords(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        let keywords = [
            "let", "var", "func", "class", "struct", "enum", "protocol", "extension", 
            "import", "if", "else", "for", "while", "do", "try", "catch", "throw",
            "return", "break", "continue", "public", "private", "internal"
        ]
        
        for keyword in keywords {
            var searchStartIndex = source.startIndex
            
            while searchStartIndex < source.endIndex {
                guard let range = source.range(of: keyword, range: searchStartIndex..<source.endIndex) else { break }
                
                // Convert to NSRange for compatibility with existing highlighting system
                let nsRange = NSRange(range, in: source)
                
                // Check if it's a whole word (basic boundary check)
                let isWholeWord = checkWordBoundary(in: source, range: nsRange)
                
                if isWholeWord {
                    tokens.append(HighlightedToken(
                        range: nsRange,
                        type: .keyword,
                        text: keyword
                    ))
                }
                
                searchStartIndex = range.upperBound
            }
        }
        
        return tokens
    }
    
    private func highlightStrings(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        let utf16 = source.utf16
        var index = utf16.startIndex
        
        while index < utf16.endIndex {
            let char = utf16[index]
            
            // Check for string literals
            if char == UnicodeScalar("\"").value {
                let startIndex = index
                index = utf16.index(after: index)
                
                // Find the end of the string
                var foundEnd = false
                while index < utf16.endIndex {
                    let currentChar = utf16[index]
                    
                    if currentChar == UnicodeScalar("\"").value {
                        index = utf16.index(after: index)
                        foundEnd = true
                        break
                    } else if currentChar == UnicodeScalar("\\").value {
                        // Skip escaped character
                        index = utf16.index(after: index)
                        if index < utf16.endIndex {
                            index = utf16.index(after: index)
                        }
                    } else {
                        index = utf16.index(after: index)
                    }
                }
                
                if foundEnd {
                    let startOffset = utf16.distance(from: utf16.startIndex, to: startIndex)
                    let endOffset = utf16.distance(from: utf16.startIndex, to: index)
                    let nsRange = NSRange(location: startOffset, length: endOffset - startOffset)
                    
                    tokens.append(HighlightedToken(
                        range: nsRange,
                        type: .string,
                        text: String(source[source.index(source.startIndex, offsetBy: startOffset)..<source.index(source.startIndex, offsetBy: endOffset)])
                    ))
                }
            } else {
                index = utf16.index(after: index)
            }
        }
        
        return tokens
    }
    
    private func highlightComments(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        let lines = source.components(separatedBy: .newlines)
        var currentOffset = 0
        
        for line in lines {
            // Single-line comments
            if let range = line.range(of: "//") {
                let lineStartInSource = source.index(source.startIndex, offsetBy: currentOffset)
                let commentStartInLine = line.distance(from: line.startIndex, to: range.lowerBound)
                let commentStartInSource = source.index(lineStartInSource, offsetBy: commentStartInLine)
                let commentEndInSource = source.index(lineStartInSource, offsetBy: line.count)
                
                let nsRange = NSRange(commentStartInSource..<commentEndInSource, in: source)
                tokens.append(HighlightedToken(
                    range: nsRange,
                    type: .comment,
                    text: String(source[commentStartInSource..<commentEndInSource])
                ))
            }
            
            currentOffset += line.count + 1 // +1 for newline
        }
        
        // Multi-line comments
        var searchStartIndex = source.startIndex
        while searchStartIndex < source.endIndex {
            guard let startRange = source.range(of: "/*", range: searchStartIndex..<source.endIndex) else { break }
            guard let endRange = source.range(of: "*/", range: startRange.upperBound..<source.endIndex) else { break }
            
            let commentRange = startRange.lowerBound..<endRange.upperBound
            let nsRange = NSRange(commentRange, in: source)
            
            tokens.append(HighlightedToken(
                range: nsRange,
                type: .comment,
                text: String(source[commentRange])
            ))
            
            searchStartIndex = endRange.upperBound
        }
        
        return tokens
    }
    
    private func highlightNumbers(in source: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        
        // Simple number pattern matching
        let numberPattern = #"\b\d+\.?\d*\b"#
        guard let regex = try? NSRegularExpression(pattern: numberPattern) else { return tokens }
        
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: source.utf16.count))
        
        for match in matches {
            let text = String(source[Range(match.range, in: source)!])
            tokens.append(HighlightedToken(
                range: match.range,
                type: .number,
                text: text
            ))
        }
        
        return tokens
    }
    
    private func checkWordBoundary(in string: String, range: NSRange) -> Bool {
        let chars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let utf16 = string.utf16
        
        // Check character before
        if range.location > 0 {
            let beforeIndex = utf16.index(utf16.startIndex, offsetBy: range.location - 1)
            let beforeChar = utf16[beforeIndex]
            if let scalar = UnicodeScalar(beforeChar), chars.contains(scalar) {
                return false
            }
        }
        
        // Check character after
        let endLocation = range.location + range.length
        if endLocation < utf16.count {
            let afterIndex = utf16.index(utf16.startIndex, offsetBy: endLocation)
            let afterChar = utf16[afterIndex]
            if let scalar = UnicodeScalar(afterChar), chars.contains(scalar) {
                return false
            }
        }
        
        return true
    }
}
#endif
