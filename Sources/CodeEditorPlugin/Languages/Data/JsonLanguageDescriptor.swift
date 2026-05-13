import Foundation

extension LanguageDescriptor {
    // ── JSON ───────────────────────────────────────────────────────
    static let jsonDescriptor = Self(
            language: .json,
            displayName: "JSON",
            fileExtensions: ["json", "jsonc"],
            lspIdentifier: "json",
            highlightingStrategy: .fastJSON,
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
