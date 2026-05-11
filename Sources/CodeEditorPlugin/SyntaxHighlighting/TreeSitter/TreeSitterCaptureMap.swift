import Foundation

// MARK: - Tree-sitter Capture Map

/// Maps Tree-sitter capture names (from `highlights.scm` queries) to our
/// `TokenType` enum. One instance per language so the map can be tuned
/// for each grammar's naming conventions.
internal struct TreeSitterCaptureMap: Sendable {
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

    /// Standard capture map for the JavaScript grammar.
    ///
    /// Based on the `tree-sitter-javascript` `highlights.scm` capture names.
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
        "tag": .keyword,        // JSX tags
        "attribute": .property  // JSX attributes
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
        "label": .identifier
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
}
