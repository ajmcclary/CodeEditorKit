import Foundation

extension LanguageDescriptor {
    // ── TOML ───────────────────────────────────────────────────────
    static let tomlDescriptor = Self(
            language: .toml,
            displayName: "TOML",
            fileExtensions: ["toml"],
            lspIdentifier: "toml",
            usesRegexHighlighter: true,
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_-]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"^\[{1,2}[^\]]+\]{1,2}"#, .keyword, priority: 10),
                .init(#"^[a-zA-Z_][a-zA-Z0-9_-]*(?=\s*=)"#, .property, priority: 8)
            ],
            keywords: [],
            types: [],
            functions: [],
            literals: ["true", "false"],
            triggerCharacters: ["=", " ", "[", "\"", "'"],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            parserName: "toml",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
