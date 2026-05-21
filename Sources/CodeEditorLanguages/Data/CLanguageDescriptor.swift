import Foundation

extension LanguageDescriptor {
    // ── C ──────────────────────────────────────────────────────────
    static let cDescriptor = Self(
            language: .c,
            displayName: "C",
            fileExtensions: ["c", "h"],
            lspIdentifier: "c",
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            highlightingRules: [
                .init(#"#\w+.*$"#, .preprocessor, priority: 8),
                .init(#"R\"[A-Za-z0-9_]*\([\s\S]*?\)[A-Za-z0-9_]*\""#, .string, priority: 9),
                .init(#"'(?:[^'\\]|\\.)'"#, .string, priority: 9)
            ],
            keywords: [
                "auto", "break", "case", "char", "const", "continue", "default", "do", "double",
                "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long",
                "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct",
                "switch", "typedef", "union", "unsigned", "void", "volatile", "while", "_Bool",
                "_Complex", "_Imaginary"
            ],
            types: [
                "int", "char", "float", "double", "void", "short", "long", "signed", "unsigned",
                "size_t", "ptrdiff_t", "intptr_t", "uintptr_t", "int8_t", "int16_t", "int32_t",
                "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool"
            ],
            functions: [
                "printf", "scanf", "malloc", "free", "realloc", "calloc", "memcpy", "memset",
                "strlen", "strcpy", "strcmp", "strcat", "fopen", "fclose", "fread", "fwrite",
                "fprintf", "fscanf", "exit", "abort", "assert"
            ],
            literals: [
                "NULL", "true", "false", "stdin", "stdout", "stderr"
            ],
            triggerCharacters: [".", "->", "(", " "],
            snippets: DescriptorSnippetData.cLanguage,
            memberCompletions: CMemberCompletions(),
            commonModules: [],
            parserName: "c",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
