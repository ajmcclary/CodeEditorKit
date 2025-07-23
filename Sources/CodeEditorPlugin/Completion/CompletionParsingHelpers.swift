import Foundation

/// Shared parsing utilities for completion providers
/// This consolidates common text parsing patterns used across multiple language completion providers
public enum CompletionParsingHelpers {
    // MARK: - Target Type Extraction

    /// Extract target object from text before dot notation (e.g., "object.method")
    /// Common pattern used by multiple completion providers
    ///
    /// - Parameter text: The text to extract from
    /// - Returns: The object name before the dot, or nil if not found
    ///
    /// ## Examples
    /// ```swift
    /// extractTargetForDotNotation("myObject.") // Returns "myObject"
    /// extractTargetForDotNotation("array.filter.") // Returns "filter"
    /// extractTargetForDotNotation("no_dot_here") // Returns nil
    /// ```
    public static func extractTargetForDotNotation(from text: String) -> String? {
        // Extract the object before the dot
        let pattern = #"([\w$]+)\s*\.\s*$"#
        return extractWithPattern(pattern, from: text)
    }

    /// Extract target object from text before arrow notation (e.g., "object->method")
    /// Used by languages like C, C++, PHP
    ///
    /// - Parameter text: The text to extract from
    /// - Returns: The object name before the arrow, or nil if not found
    public static func extractTargetForArrowNotation(from text: String) -> String? {
        // Extract the object before ->
        let pattern = #"(\w+)\s*->\s*$"#
        return extractWithPattern(pattern, from: text)
    }

    /// Extract target object from text before scope resolution (e.g., "Namespace::class")
    /// Used by languages like C++, PHP
    ///
    /// - Parameter text: The text to extract from
    /// - Returns: The namespace or class name before ::, or nil if not found
    public static func extractTargetForScopeResolution(from text: String) -> String? {
        // Extract the namespace/class before ::
        let pattern = #"([\w:]+)::\s*$"#
        return extractWithPattern(pattern, from: text)
    }

    /// Extract target object for combined dot or arrow notation
    /// Used by languages that support both patterns like C++
    ///
    /// - Parameter text: The text to extract from
    /// - Returns: The object name before the dot or arrow, or nil if not found
    public static func extractTargetForDotOrArrowNotation(from text: String) -> String? {
        // Extract the object before . or ->
        let pattern = #"(\w+)\s*(?:\.|->)\s*$"#
        return extractWithPattern(pattern, from: text)
    }

    /// Extract target with custom separator pattern
    /// Allows completion providers to specify their own separators
    ///
    /// - Parameters:
    ///   - text: The text to extract from
    ///   - separator: The separator pattern (e.g., "\\.", "->", "::")
    /// - Returns: The object name before the separator, or nil if not found
    public static func extractTargetWithSeparator(from text: String, separator: String) -> String? {
        let pattern = #"(\w+)\s*"# + separator + #"\s*$"#
        return extractWithPattern(pattern, from: text)
    }

    // MARK: - Comment Prefix Extraction

    /// Extract comment prefix for a language
    /// Common pattern used for comment-related completion features
    ///
    /// - Parameter language: The programming language
    /// - Returns: The comment prefix for the language, or nil if not supported
    ///
    /// ## Examples
    /// ```swift
    /// getCommentPrefix(for: .swift) // Returns "//"
    /// getCommentPrefix(for: .python) // Returns "#"
    /// getCommentPrefix(for: .html) // Returns "<!--"
    /// ```
    public static func getCommentPrefix(for language: Language) -> String? {
        switch language {
        case .swift, .javascript, .typescript, .rust, .c, .cpp, .java, .go:
            return "//"

        case .python, .ruby, .shell, .yaml:
            return "#"

        case .html, .xml:
            return "<!--"

        case .css:
            return "/*"

        case .sql:
            return "--"

        default:
            return nil
        }
    }

    // MARK: - Current Word Extraction

    /// Extract the current word being typed from text
    /// Common pattern for filtering completions
    ///
    /// - Parameter text: The text to extract from
    /// - Returns: The current word being typed, or empty string if none
    public static func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).inverted)
        return components.last ?? ""
    }

    /// Extract the current identifier (word with underscores/dollars) from text
    /// Used for languages that support $ in identifiers
    ///
    /// - Parameter text: The text to extract from
    /// - Returns: The current identifier being typed, or empty string if none
    public static func extractCurrentIdentifier(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$")).inverted)
        return components.last ?? ""
    }

    // MARK: - Private Helper Methods

    /// Extract text using a regex pattern with safe Range handling
    /// Consolidates the common pattern of regex extraction with proper error handling
    ///
    /// - Parameters:
    ///   - pattern: The regex pattern to use
    ///   - text: The text to search in
    /// - Returns: The extracted string, or nil if not found or pattern invalid
    private static func extractWithPattern(_ pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}

// MARK: - Language-Specific Helpers

extension CompletionParsingHelpers {
    /// Get appropriate target extraction method for a language
    /// Provides language-specific target extraction based on syntax
    ///
    /// - Parameter language: The programming language
    /// - Returns: A closure that extracts targets for the language, or nil if not supported
    public static func targetExtractor(for language: Language) -> ((String) -> String?)? {
        switch language {
        case .swift, .javascript, .typescript, .python, .ruby, .java, .go, .rust:
            return extractTargetForDotNotation(from:)

        case .c, .cpp:
            return extractTargetForDotOrArrowNotation(from:)

        case .php:
            // PHP supports both -> for objects and :: for static methods
            return { text in
                extractTargetForArrowNotation(from: text) ?? extractTargetForScopeResolution(from: text)
            }

        default:
            return nil
        }
    }
}
