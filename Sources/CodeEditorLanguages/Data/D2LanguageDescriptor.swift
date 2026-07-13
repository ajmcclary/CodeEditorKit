import Foundation

extension LanguageDescriptor {
    // ── D2 ─────────────────────────────────────────────────────────
    static let d2Descriptor = Self(
            language: .d2,
            fileExtensions: ["d2"],
            usesRegexHighlighter: true,
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_-]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                // Connection arrows (<->, ->, <-, --)
                .init(#"<->|->|<-|--"#, .operator, priority: 8)
            ],
            keywords: [
                "direction", "shape", "style", "class", "classes", "near",
                "label", "tooltip", "link", "icon", "width", "height"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [" ", "."],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
