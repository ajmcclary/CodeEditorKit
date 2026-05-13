import Foundation

extension LanguageDescriptor {
    // ── XML ────────────────────────────────────────────────────────
    static let xmlDescriptor = Self(
            language: .xml,
            displayName: "XML",
            fileExtensions: ["xml", "xsl", "xslt", "svg"],
            lspIdentifier: "xml",
            highlightingStrategy: .regex,
            lineComment: nil,
            blockCommentStart: "<!--",
            blockCommentEnd: "-->",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_:-]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"<!--[\s\S]*?-->"#, .comment, priority: 10),
                .init(#"<\?[\s\S]*?\?>"#, .preprocessor, priority: 8),
                .init(#"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>"#, .keyword, priority: 8),
                .init(#"\b[a-zA-Z-]+(?==)"#, .property, priority: 7)
            ],
            keywords: [],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: ["<", " ", "=", "\"", "'"],
            snippets: DescriptorSnippetData.xml,
            memberCompletions: nil,
            commonModules: [],
            parserName: "xml",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
