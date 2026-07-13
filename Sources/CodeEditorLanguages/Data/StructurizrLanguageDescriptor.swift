import Foundation

extension LanguageDescriptor {
    // ── Structurizr DSL ────────────────────────────────────────────
    static let structurizrDescriptor = Self(
            language: .structurizr,
            fileExtensions: ["dsl"],
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            highlightingRules: [
                // Structurizr also allows # line comments
                .init(#"#.*$"#, .comment, priority: 9),
                // Relationship arrows (->)
                .init(#"->"#, .operator, priority: 8)
            ],
            keywords: [
                "workspace", "model", "views", "person", "softwareSystem",
                "container", "component", "deploymentEnvironment",
                "systemContext", "containerView", "dynamicView", "styles",
                "element", "relationship", "include", "description"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [" "],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
