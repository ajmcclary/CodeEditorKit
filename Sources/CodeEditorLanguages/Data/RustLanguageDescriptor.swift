import Foundation

extension LanguageDescriptor {
    // ── Rust ───────────────────────────────────────────────────────
    static let rustDescriptor = Self(
            language: .rust,
            fileExtensions: ["rs"],
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
                "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop",
                "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static",
                "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"
            ],
            types: [
                "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128", "isize", "str",
                "u8", "u16", "u32", "u64", "u128", "usize", "String", "Vec", "HashMap", "HashSet",
                "Option", "Result", "Box", "Rc", "Arc", "RefCell", "Mutex", "RwLock", "Cell"
            ],
            functions: [
                "println!", "print!", "eprintln!", "eprint!", "format!", "write!", "writeln!",
                "panic!", "assert!", "assert_eq!", "assert_ne!", "debug_assert!", "vec!",
                "include!", "include_str!", "include_bytes!", "concat!", "env!", "todo!",
                "unimplemented!", "unreachable!", "dbg!"
            ],
            literals: [
                "true", "false", "None", "Some", "Ok", "Err"
            ],
            triggerCharacters: [".", "::", "(", "<", " ", "!"],
            snippets: DescriptorSnippetData.rust,
            memberCompletions: RustMemberCompletions(),
            commonModules: [],
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
