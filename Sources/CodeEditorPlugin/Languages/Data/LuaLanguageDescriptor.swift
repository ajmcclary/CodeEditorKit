import Foundation

extension LanguageDescriptor {
    // ── Lua ────────────────────────────────────────────────────────
    static let luaDescriptor = Self(
            language: .lua,
            displayName: "Lua",
            fileExtensions: ["lua"],
            lspIdentifier: "lua",
            highlightingStrategy: .regex,
            lineComment: "--",
            blockCommentStart: "--[[",
            blockCommentEnd: "]]",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"--\[\[[\s\S]*?]]"#, .comment, priority: 10),
                .init(#"\[\[[\s\S]*?]]"#, .string, priority: 9)
            ],
            keywords: [
                "and", "break", "do", "else", "elseif", "end", "false", "for",
                "function", "goto", "if", "in", "local", "nil", "not", "or",
                "repeat", "return", "then", "true", "until", "while"
            ],
            types: [],
            functions: [
                "print", "assert", "error", "ipairs", "pairs", "next", "select",
                "tonumber", "tostring", "type", "rawget", "rawset", "rawequal",
                "setmetatable", "getmetatable", "require", "pcall", "xpcall"
            ],
            literals: ["true", "false", "nil"],
            triggerCharacters: [".", ":", "(", " "],
            snippets: [],
            memberCompletions: nil,
            commonModules: [],
            parserName: "lua",
            shebangIdentifiers: ["lua"],
            scriptAliases: ["lua"]
        )
}
