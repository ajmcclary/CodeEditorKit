import Foundation

extension LanguageDescriptor {
    // ── Plain Text ─────────────────────────────────────────────────
    static let plainTextDescriptor = Self(
            language: .plainText,
            displayName: "Plain Text",
            fileExtensions: ["txt", "text", "log"],
            lspIdentifier: "plaintext",
            usesRegexHighlighter: false,
            lineComment: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: [],
            keywords: [],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            parserName: nil,
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
