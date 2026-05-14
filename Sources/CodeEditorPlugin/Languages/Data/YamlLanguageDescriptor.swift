import Foundation

extension LanguageDescriptor {
    // ── YAML ───────────────────────────────────────────────────────
    static let yamlDescriptor = Self(
            language: .yaml,
            displayName: "YAML",
            fileExtensions: ["yaml", "yml"],
            lspIdentifier: "yaml",
            usesRegexHighlighter: true,
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"^[a-zA-Z_][\w\-]*(?=\s*:)"#, .property, priority: 6),
                .init(#"[:\-\[\]{}]"#, .punctuation, priority: 5)
            ],
            keywords: [],
            types: [],
            functions: [],
            literals: ["true", "false", "null", "yes", "no", "on", "off"],
            triggerCharacters: [":", " "],
            snippets: YAMLCompletionData.snippets,
            memberCompletions: nil,
            commonModules: [],
            parserName: "yaml",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
