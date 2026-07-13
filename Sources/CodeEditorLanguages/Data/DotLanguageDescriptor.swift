import Foundation

extension LanguageDescriptor {
    // ── Graphviz DOT ───────────────────────────────────────────────
    static let dotDescriptor = Self(
            language: .dot,
            displayName: "Graphviz DOT",
            fileExtensions: ["dot", "gv"],
            lspIdentifier: "dot",
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            highlightingRules: [
                // Edge operators (->, --)
                .init(#"->|--"#, .operator, priority: 8)
            ],
            keywords: [
                "strict", "graph", "digraph", "subgraph", "node", "edge",
                "label", "color", "shape", "style", "rankdir", "fontname"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [" ", "="],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            parserName: nil,
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
