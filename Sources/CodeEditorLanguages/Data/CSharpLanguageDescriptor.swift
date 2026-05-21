import Foundation

extension LanguageDescriptor {
    // ── C# ─────────────────────────────────────────────────────────
    static let csharpDescriptor = Self(
            language: .csharp,
            displayName: "C#",
            fileExtensions: ["cs"],
            lspIdentifier: "csharp",
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"\$\"[^\"]*\""#, .string, priority: 9),
                .init(#"\b[A-Z][a-zA-Z0-9]*\b"#, .type, priority: 7)
            ],
            keywords: [
                "abstract", "as", "base", "bool", "break", "byte", "case", "catch",
                "char", "checked", "class", "const", "continue", "decimal", "default",
                "delegate", "do", "double", "else", "enum", "event", "explicit", "extern",
                "false", "finally", "fixed", "float", "for", "foreach", "goto", "if",
                "implicit", "in", "int", "interface", "internal", "is", "lock", "long",
                "namespace", "new", "null", "object", "operator", "out", "override",
                "params", "private", "protected", "public", "readonly", "ref", "return",
                "sbyte", "sealed", "short", "sizeof", "stackalloc", "static", "string",
                "struct", "switch", "this", "throw", "true", "try", "typeof", "uint",
                "ulong", "unchecked", "unsafe", "ushort", "using", "var", "virtual",
                "void", "volatile", "while"
            ],
            types: [
                "string", "int", "long", "float", "double", "decimal", "bool", "char",
                "byte", "object", "dynamic", "List", "Dictionary", "IEnumerable",
                "Task", "Stream", "HttpClient"
            ],
            functions: [
                "Console.WriteLine", "Console.ReadLine", "string.Format",
                "Convert.ToInt32", "Enumerable.Select", "Enumerable.Where",
                "Task.Run", "async", "await"
            ],
            literals: ["true", "false", "null", "this", "base"],
            triggerCharacters: [".", "(", "[", "<", " "],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            parserName: "c_sharp",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
