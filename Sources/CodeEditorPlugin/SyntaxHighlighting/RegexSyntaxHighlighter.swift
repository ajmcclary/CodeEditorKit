import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - RegexSyntaxHighlighter

/// A pure Swift regex-based syntax highlighter for various programming languages
public final class RegexSyntaxHighlighter: Sendable {
    // MARK: - Performance Constants
    
    /// Optimized token type mapping for O(1) conversion
    static let tokenTypeMap: [RegexSyntaxTokenType: TokenType] = [
        .keyword: .keyword,
        .identifier: .identifier,
        .string: .string,
        .number: .number,
        .comment: .comment,
        .type: .type,
        .function: .function,
        .property: .property,
        .operator: .operator,
        .punctuation: .punctuation,
        .whitespace: .whitespace,
        .preprocessor: .preprocessor,
        .unknown: .unknown
    ]
    
    // MARK: - Properties

    public let supportedLanguages: [String: RegexLanguageDefinition]
    
    // Direct language mapping for efficient lookup
    private let languageMap: [Language: RegexLanguageDefinition]

    // MARK: - Initialization

    public init() {
        supportedLanguages = Self.createLanguageDefinitions()
        languageMap = Self.createLanguageMap(from: supportedLanguages)
    }

    // MARK: - Public Methods

    /// Get language definition by file extension (legacy method)
    public func languageDefinition(for fileExtension: String) -> RegexLanguageDefinition? {
        supportedLanguages.values.first { language in
            language.fileExtensions.contains(fileExtension.lowercased())
        }
    }
    
    /// Get language definition by Language enum case (preferred method)
    public func languageDefinition(for language: Language) -> RegexLanguageDefinition? {
        languageMap[language]
    }

    /// Highlight source code using the specified language definition
    public func highlight(source: String, language: RegexLanguageDefinition) -> [HighlightedToken] {
        guard !source.isEmpty else {
            return []
        }

        // Pre-allocate collections with estimated capacity for better performance
        var tokens: [HighlightedToken] = []
        tokens.reserveCapacity(min(source.count / 20, 1_000))
        
        let range = NSRange(location: 0, length: source.utf16.count)

        // Use IntervalTree for O(log n) overlap checking instead of O(n)
        var processedIntervals = IntervalTree()

        // Rules are already pre-sorted by priority in LanguageDefinition
        for rule in language.rules {
            let matches = rule.pattern.matches(in: source, options: [], range: range)

            for match in matches {
                let matchRange = match.range

                // O(log n) overlap check using interval tree
                if processedIntervals.hasOverlap(with: matchRange) {
                    continue
                }

                // Convert token type efficiently using lookup instead of switch
                let coordinatorTokenType = mapTokenType(rule.tokenType)
                
                // Only create substring when we actually need the text content
                guard let stringRange = Range(matchRange, in: source) else {
                    continue
                }
                let text = String(source[stringRange])
                tokens.append(HighlightedToken(range: matchRange, type: coordinatorTokenType, text: text))
                
                // Insert into interval tree for future overlap checks
                processedIntervals.insert(matchRange)
            }
        }

        // Sort tokens by location for consistent output
        tokens.sort { $0.range.location < $1.range.location }
        return tokens
    }
    
    /// Efficiently map RegexTokenType to TokenType using lookup table
    private func mapTokenType(_ regexTokenType: RegexSyntaxTokenType) -> TokenType {
        // Use class-level lookup table for O(1) token type conversion
        Self.tokenTypeMap[regexTokenType] ?? .unknown
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

// MARK: - Convenience Type Aliases for External Access

/// Public alias for LanguageDefinition
public typealias LanguageDefinition = RegexLanguageDefinition

/// Public alias for HighlightRule
public typealias HighlightRule = RegexHighlightRule

/// Public alias for RegexTokenType
public typealias RegexTokenType = RegexSyntaxTokenType

// MARK: - Extension for Nested Type Access

extension RegexSyntaxHighlighter {
    /// Nested LanguageDefinition for backward compatibility
    public typealias LanguageDefinition = RegexLanguageDefinition
    
    /// Nested HighlightRule for backward compatibility
    public typealias HighlightRule = RegexHighlightRule
    
    /// Nested RegexTokenType for backward compatibility
    public typealias RegexTokenType = RegexSyntaxTokenType
}
