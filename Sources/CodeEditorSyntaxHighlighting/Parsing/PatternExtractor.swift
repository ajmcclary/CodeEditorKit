import CodeEditorLanguages
import Foundation

// MARK: - Pattern Extractor

/// Extracts programming language notation patterns from text.
/// Handles dot notation, bracket notation, arrow notation, and more.
public enum PatternExtractor {
    // MARK: - Public API

    /// Extracts target from various notation patterns
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

    /// Extracts target from dot notation (object.property)
    public static func extractDotNotationTarget(from text: String) -> String? {
        let components = text.components(separatedBy: ".")
        return components.count > 1 ? components.dropLast().joined(separator: ".") : nil
    }

    /// Extracts target from bracket notation (object[property])
    public static func extractBracketNotationTarget(from text: String) -> String? {
        if let bracketIndex = text.lastIndex(of: "[") {
            return String(text[..<bracketIndex])
        }
        return nil
    }

    /// Extracts target from arrow notation (object->property)
    public static func extractArrowNotationTarget(from text: String) -> String? {
        let components = text.components(separatedBy: "->")
        return components.count > 1 ? components.dropLast().joined(separator: "->") : nil
    }

    /// Extracts target from double colon notation (namespace::property)
    public static func extractDoubleColonTarget(from text: String) -> String? {
        let components = text.components(separatedBy: "::")
        return components.count > 1 ? components.dropLast().joined(separator: "::") : nil
    }

    /// Extracts target from generic notation (Type<Generic>)
    public static func extractGenericTarget(from text: String) -> String? {
        if let angleIndex = text.lastIndex(of: "<") {
            return String(text[..<angleIndex])
        }
        return nil
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

    // MARK: - Types

    /// Types of notation patterns for extracting programming language constructs.
    public enum NotationType {
        /// Dot notation for object property access (object.property).
        case dot
        /// Bracket notation for array or object access (object[property]).
        case bracket
        /// Arrow notation for pointer dereferencing (object->property).
        case arrow
        /// Double colon notation for namespace access (namespace::property).
        case doubleColon
        /// Generic type notation (Type<Generic>).
        case generic
    }
}
