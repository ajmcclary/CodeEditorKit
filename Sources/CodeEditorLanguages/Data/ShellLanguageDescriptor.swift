import Foundation

extension LanguageDescriptor {
    // ── Shell ──────────────────────────────────────────────────────
    static let shellDescriptor = Self(
            language: .shell,
            usesRegexHighlighter: true,
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"\$\{[^}]+\}"#, .identifier, priority: 8),
                .init(#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, .identifier, priority: 8)
            ],
            keywords: [
                "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do",
                "done", "in", "function", "return", "local", "export", "readonly", "declare",
                "typeset", "unset", "shift", "source", "alias", "unalias", "true", "false",
                "break", "continue", "exit", "trap", "eval", "exec"
            ],
            types: [],
            functions: [
                "echo", "printf", "read", "cd", "pwd", "ls", "cat", "grep", "sed", "awk", "find",
                "xargs", "sort", "uniq", "wc", "head", "tail", "cut", "tr", "mkdir", "rm", "cp",
                "mv", "chmod", "chown", "test", "expr"
            ],
            literals: ["true", "false", "$HOME", "$USER", "$PATH", "$PWD", "$?", "$$", "$0"],
            triggerCharacters: [" ", "$", "-"],
            snippets: DescriptorSnippetData.shell,
            memberCompletions: nil,
            commonModules: []
        )
}
