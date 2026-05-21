import Foundation

extension LanguageDescriptor {
    // ── JSON ───────────────────────────────────────────────────────
    static let jsonDescriptor = Self(
            language: .json,
            displayName: "JSON",
            fileExtensions: ["json", "jsonc"],
            lspIdentifier: "json",
            // JSON is routed to `FastJSONTokenizer` by `HighlightingStrategyExecutor`
            // and the regex pipeline never sees it. Mirrors Swift, which has
            // its own SwiftSyntax-backed strategy.
            usesRegexHighlighter: false,
            lineComment: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [],
            types: [],
            functions: [],
            literals: ["true", "false", "null"],
            triggerCharacters: [":", " ", "\""],
            snippets: JSONCompletionData.snippets,
            memberCompletions: nil,
            commonModules: [],
            parserName: "json",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
