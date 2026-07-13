import Foundation

extension LanguageDescriptor {
    // ── C++ ────────────────────────────────────────────────────────
    static let cppDescriptor = Self(
            language: .cpp,
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
                "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor", "bool",
                "break", "case", "catch", "char", "char8_t", "char16_t", "char32_t", "class",
                "compl", "concept", "const", "consteval", "constexpr", "constinit", "const_cast",
                "continue", "co_await", "co_return", "co_yield", "decltype", "default", "delete",
                "do", "double", "dynamic_cast", "else", "enum", "explicit", "export", "extern",
                "false", "float", "for", "friend", "goto", "if", "inline", "int", "long",
                "mutable", "namespace", "new", "noexcept", "not", "not_eq", "nullptr", "operator",
                "or", "or_eq", "private", "protected", "public", "register", "reinterpret_cast",
                "requires", "return", "short", "signed", "sizeof", "static", "static_assert",
                "static_cast", "struct", "switch", "template", "this", "thread_local", "throw",
                "true", "try", "typedef", "typeid", "typename", "union", "unsigned", "using",
                "virtual", "void", "volatile", "wchar_t", "while", "xor", "xor_eq"
            ],
            types: [
                "string", "vector", "map", "set", "unordered_map", "unordered_set", "list",
                "deque", "queue", "stack", "array", "pair", "tuple", "optional", "variant",
                "any", "span", "string_view", "unique_ptr", "shared_ptr", "weak_ptr"
            ],
            functions: [
                "std::cout", "std::cin", "std::endl", "std::move", "std::forward", "std::make_unique",
                "std::make_shared", "std::swap", "std::sort", "std::find", "std::transform",
                "std::accumulate", "std::copy", "std::fill"
            ],
            literals: [
                "true", "false", "nullptr", "NULL", "this"
            ],
            triggerCharacters: [".", "->", "::", "(", "<", " "],
            snippets: DescriptorSnippetData.cLanguage,
            memberCompletions: CMemberCompletions(),
            commonModules: []
        )
}
