import Foundation

extension LanguageDescriptor {
    // ── Dart ───────────────────────────────────────────────────────
    static let dartDescriptor = Self(
            language: .dart,
            fileExtensions: ["dart"],
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_$][a-zA-Z0-9_$]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"\$\{[^}]+\}"#, .identifier, priority: 9),
                .init(#"\b[A-Z][a-zA-Z0-9]*\b"#, .type, priority: 7)
            ],
            keywords: [
                "abstract", "as", "assert", "async", "await", "break", "case", "catch",
                "class", "const", "continue", "default", "deferred", "do", "dynamic",
                "else", "enum", "export", "extends", "extension", "external", "factory",
                "false", "final", "finally", "for", "Function", "get", "hide", "if",
                "implements", "import", "in", "interface", "is", "late", "library",
                "mixin", "new", "null", "on", "operator", "part", "required", "rethrow",
                "return", "set", "show", "static", "super", "switch", "sync", "this",
                "throw", "true", "try", "typedef", "var", "void", "while", "with", "yield"
            ],
            types: [
                "String", "int", "double", "bool", "List", "Map", "Set", "Future",
                "Stream", "void", "dynamic", "Object", "Never", "Iterable", "num"
            ],
            functions: [
                "print", "toString", "main", "runApp", "setState", "build",
                "dispose", "initState", "then", "catchError", "whenComplete"
            ],
            literals: ["true", "false", "null", "this", "super"],
            triggerCharacters: [".", "(", "[", "<", " ", ":"],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
