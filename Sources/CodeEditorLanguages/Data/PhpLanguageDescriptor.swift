import Foundation

extension LanguageDescriptor {
    // ── PHP ────────────────────────────────────────────────────────
    static let phpDescriptor = Self(
            language: .php,
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_\\x80-\\xff][a-zA-Z0-9_\\x80-\\xff]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class",
                "clone", "const", "continue", "declare", "default", "die", "do", "echo", "else",
                "elseif", "empty", "enddeclare", "endfor", "endforeach", "endif", "endswitch",
                "endwhile", "eval", "exit", "extends", "final", "finally", "fn", "for", "foreach",
                "function", "global", "goto", "if", "implements", "include", "include_once",
                "instanceof", "insteadof", "interface", "isset", "list", "match", "namespace",
                "new", "or", "print", "private", "protected", "public", "require", "require_once",
                "return", "static", "switch", "throw", "trait", "try", "unset", "use", "var",
                "while", "xor", "yield"
            ],
            types: [
                "string", "int", "float", "bool", "array", "object", "callable", "iterable",
                "void", "null", "mixed", "never"
            ],
            functions: [
                "echo", "print", "var_dump", "print_r", "isset", "empty", "unset", "strlen",
                "substr", "str_replace", "strpos", "explode", "implode", "array_push",
                "array_pop", "array_shift", "array_unshift", "array_merge", "array_map",
                "array_filter", "array_reduce", "count", "sizeof", "in_array", "array_key_exists"
            ],
            literals: ["true", "false", "null", "$this", "self", "parent"],
            triggerCharacters: [".", "->", "::", "$", " "],
            snippets: DescriptorSnippetData.php,
            memberCompletions: nil,
            commonModules: []
        )
}
