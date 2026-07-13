import Foundation

extension LanguageDescriptor {
    // ── PlantUML ───────────────────────────────────────────────────
    static let plantumlDescriptor = Self(
            language: .plantuml,
            usesRegexHighlighter: true,
            lineComment: "'",
            blockCommentStart: "/'",
            blockCommentEnd: "'/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            highlightingRules: [
                // @startuml / @enduml and other @-directives
                .init(#"@\w+"#, .preprocessor, priority: 10),
                // Relationship arrows (-->, ..>, <|--, *--, o--, …)
                .init(#"<\|?[.-]+\|?>|<\|[.-]+|[.-]+\|>|[*o]?[.-]{1,}>|<[.-]{1,}[*o]?|[.-]{2,}"#, .operator, priority: 8),
                // <<…>> stereotypes
                .init(#"<<[^>]+>>"#, .property, priority: 9)
            ],
            keywords: [
                "startuml", "enduml", "class", "interface", "enum", "actor",
                "participant", "state", "activity", "mindmap", "gantt",
                "title", "package", "note", "as", "skinparam"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [" ", "@"],
            snippets: [],
            memberCompletions: nil,
            commonModules: []
        )
}
