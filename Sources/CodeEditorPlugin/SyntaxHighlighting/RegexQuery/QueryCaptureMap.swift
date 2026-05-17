import CodeEditorLanguages
import Foundation

// MARK: - Query Capture Map

/// Maps parser capture names to our `TokenType` enum. One instance per
/// language lets the map be tuned for language-specific naming conventions.
internal struct QueryCaptureMap: Sendable {
    private let map: [String: TokenType]

    init(mappings: [String: TokenType]) {
        self.map = mappings
    }

    /// Resolve a capture name to a `TokenType`. Returns `.unknown` for
    /// unrecognized captures so the token is still tracked but gets
    /// default styling.
    func tokenType(for captureName: String) -> TokenType {
        // Strip the trailing period + scope suffix that some grammars use
        // e.g. "keyword.return" → "keyword"
        let base = captureName.split(separator: ".").first.map(String.init) ?? captureName
        return map[base] ?? map[captureName] ?? .unknown
    }

    // MARK: - Presets

    /// Default capture map covering the most common capture names.
    /// Used as the fallback for languages without a dedicated preset.
    static let `default` = Self(mappings: [
        "keyword": .keyword,
        "conditional": .keyword,
        "repeat": .keyword,
        "include": .keyword,
        "exception": .keyword,
        "constant": .keyword,
        "boolean": .keyword,
        "number": .number,
        "float": .number,
        "string": .string,
        "escape": .string,
        "comment": .comment,
        "function": .function,
        "method": .function,
        "constructor": .function,
        "property": .property,
        "type": .type,
        "type.builtin": .type,
        "operator": .operator,
        "punctuation": .punctuation,
        "delimiter": .punctuation,
        "bracket": .punctuation,
        "variable": .identifier,
        "variable.builtin": .identifier,
        "parameter": .identifier,
        "label": .identifier,
        "tag": .keyword,
        "attribute": .property,
        "namespace": .type,
        "module": .type,
        "decorator": .function,
        "preproc": .preprocessor,
        "define": .preprocessor,
        "macro": .preprocessor
    ])

    /// Standard capture map for the JavaScript grammar.
    static let javascript = Self(mappings: [
        "keyword": .keyword,
        "constant": .keyword,
        "number": .number,
        "string": .string,
        "escape": .string,
        "comment": .comment,
        "function": .function,
        "method": .function,
        "property": .property,
        "type": .type,
        "operator": .operator,
        "punctuation": .punctuation,
        "variable": .identifier,
        "parameter": .identifier,
        "label": .identifier,
        "tag": .keyword,
        "attribute": .property
    ])

    /// Standard capture map for the TypeScript grammar.
    static let typescript = Self(mappings: [
        "keyword": .keyword,
        "constant": .keyword,
        "number": .number,
        "string": .string,
        "escape": .string,
        "comment": .comment,
        "function": .function,
        "method": .function,
        "property": .property,
        "type": .type,
        "operator": .operator,
        "punctuation": .punctuation,
        "variable": .identifier,
        "parameter": .identifier,
        "label": .identifier,
        "tag": .keyword,
        "attribute": .property
    ])

    /// Standard capture map for the Python grammar.
    static let python = Self(mappings: [
        "keyword": .keyword,
        "number": .number,
        "string": .string,
        "escape": .string,
        "comment": .comment,
        "function": .function,
        "method": .function,
        "type": .type,
        "operator": .operator,
        "punctuation": .punctuation,
        "variable": .identifier,
        "parameter": .identifier,
        "decorator": .function
    ])

    /// C-family languages (C, C++, Java, C#, Kotlin, Dart, Go, Rust, Swift).
    static let cFamily = Self(mappings: [
        "keyword": .keyword,
        "type": .type,
        "type.builtin": .type,
        "string": .string,
        "escape": .string,
        "number": .number,
        "comment": .comment,
        "function": .function,
        "method": .function,
        "property": .property,
        "operator": .operator,
        "punctuation": .punctuation,
        "variable": .identifier,
        "parameter": .identifier,
        "preproc": .preprocessor,
        "include": .preprocessor,
        "macro": .preprocessor
    ])

    /// Ruby grammar preset.
    static let ruby = Self(mappings: [
        "keyword": .keyword,
        "number": .number,
        "string": .string,
        "escape": .string,
        "comment": .comment,
        "function": .function,
        "method": .function,
        "type": .type,
        "operator": .operator,
        "punctuation": .punctuation,
        "variable": .identifier,
        "parameter": .identifier,
        "symbol": .string,
        "constant": .keyword
    ])

    /// HTML/XML grammar preset.
    static let markup = Self(mappings: [
        "tag": .keyword,
        "attribute": .property,
        "string": .string,
        "comment": .comment,
        "text": .identifier,
        "doctype": .preprocessor,
        "entity": .string,
        "punctuation": .punctuation
    ])

    /// CSS grammar preset.
    static let css = Self(mappings: [
        "property": .property,
        "keyword": .keyword,
        "string": .string,
        "number": .number,
        "comment": .comment,
        "type": .type,
        "function": .function,
        "punctuation": .punctuation,
        "operator": .operator
    ])

    /// JSON grammar preset.
    static let json = Self(mappings: [
        "string": .string,
        "number": .number,
        "boolean": .keyword,
        "null": .keyword,
        "punctuation": .punctuation,
        "escape": .string
    ])

    /// Returns the appropriate capture map for a given language.
    ///
    /// Uses language-specific presets when available; falls back to
    /// ``default`` for languages without a dedicated preset.
    static func forLanguage(_ language: Language) -> Self {
        switch language {
        case .javascript: return .javascript
        case .typescript: return .typescript
        case .python: return .python

        case .c, .cpp, .java, .csharp, .kotlin, .dart, .go, .rust, .swift:
            return .cFamily

        case .ruby: return .ruby
        case .html, .xml: return .markup
        case .css: return .css
        case .json: return .json
        default: return .default
        }
    }
}
