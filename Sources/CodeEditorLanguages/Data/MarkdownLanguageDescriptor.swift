import Foundation

extension LanguageDescriptor {
    // ── Markdown ───────────────────────────────────────────────────
    static let markdownDescriptor = Self(
            language: .markdown,
            displayName: "Markdown",
            fileExtensions: ["md", "markdown", "mdown", "mkd"],
            lspIdentifier: "markdown",
            usesRegexHighlighter: true,
            lineComment: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: [],
            highlightingRules: [
                .init(#"^#{1,6}\s+.*$"#, .keyword, priority: 10),
                .init(#"`[^`]*`"#, .string, priority: 9),
                .init(#"```[\s\S]*?```"#, .string, priority: 9),
                .init(#"\*\*[^*]+\*\*"#, .keyword, priority: 8),
                .init(#"__[^_]+__"#, .keyword, priority: 8),
                .init(#"\*[^*]+\*"#, .type, priority: 7),
                .init(#"_[^_]+_"#, .type, priority: 7),
                .init(#"\[([^\]]+)\]\([^)]+\)"#, .function, priority: 6)
            ],
            keywords: [],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: ["[", "(", " "],
            snippets: MarkdownCompletionData.snippets,
            memberCompletions: nil,
            commonModules: [],
            parserName: "markdown",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
