import Foundation

extension LanguageDescriptor {
    // ── Go ─────────────────────────────────────────────────────────
    static let goDescriptor = Self(
            language: .go,
            fileExtensions: ["go"],
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "`"],
            keywords: [
                "break", "case", "chan", "const", "continue", "default", "defer", "else",
                "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                "package", "range", "return", "select", "struct", "switch", "type", "var"
            ],
            types: [
                "bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int",
                "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16",
                "uint32", "uint64", "uintptr"
            ],
            functions: [
                "make", "new", "append", "copy", "delete", "len", "cap", "close", "panic",
                "recover", "print", "println", "complex", "real", "imag", "min", "max"
            ],
            literals: [
                "true", "false", "iota", "nil"
            ],
            triggerCharacters: [".", "(", "[", " ", ":"],
            snippets: GoSnippets.all,
            memberCompletions: GoMemberCompletions(),
            commonModules: [
                "fmt", "os", "io", "net/http", "encoding/json", "time", "strings", "strconv",
                "context", "sync", "log", "errors", "bufio", "path/filepath", "regexp"
            ],
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
