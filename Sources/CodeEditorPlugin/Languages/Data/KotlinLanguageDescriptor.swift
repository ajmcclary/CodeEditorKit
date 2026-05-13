import Foundation

extension LanguageDescriptor {
    // ── Kotlin ─────────────────────────────────────────────────────
    static let kotlinDescriptor = Self(
            language: .kotlin,
            displayName: "Kotlin",
            fileExtensions: ["kt", "kts"],
            lspIdentifier: "kotlin",
            highlightingStrategy: .regex,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"\$\{[^}]+\}"#, .identifier, priority: 9),
                .init(#"\$\w+"#, .identifier, priority: 8),
                .init(#"\b[A-Z][a-zA-Z0-9]*\b"#, .type, priority: 7)
            ],
            keywords: [
                "abstract", "annotation", "as", "break", "by", "catch", "class",
                "companion", "const", "constructor", "continue", "data", "do", "else",
                "enum", "false", "final", "finally", "for", "fun", "if", "import",
                "in", "init", "inner", "interface", "internal", "is", "lateinit",
                "null", "object", "open", "operator", "out", "override", "package",
                "private", "protected", "public", "return", "sealed", "super", "suspend",
                "this", "throw", "true", "try", "typealias", "val", "var", "vararg",
                "when", "while"
            ],
            types: [
                "String", "Int", "Long", "Float", "Double", "Boolean", "Char", "Byte",
                "Short", "Any", "Unit", "Nothing", "List", "MutableList", "Set",
                "MutableSet", "Map", "MutableMap", "Array", "Sequence"
            ],
            functions: [
                "println", "print", "readLine", "require", "check", "assert",
                "run", "let", "apply", "also", "with", "lazy", "use"
            ],
            literals: ["true", "false", "null", "this", "super"],
            triggerCharacters: [".", "(", "[", "<", " ", ":"],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            parserName: "kotlin",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
