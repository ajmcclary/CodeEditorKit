import Foundation

extension LanguageDescriptor {
    // ── TypeScript ─────────────────────────────────────────────────
    static let typescriptDescriptor = Self(
            language: .typescript,
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_$][a-zA-Z0-9_$]*",
            stringDelimiters: ["\"", "'", "`"],
            keywords: [
                "const", "let", "var", "function", "class", "if", "else", "for", "while", "do",
                "switch", "case", "default", "break", "continue", "return", "try", "catch",
                "finally", "throw", "async", "await", "import", "export", "from", "as", "typeof",
                "instanceof", "new", "this", "super", "static", "extends", "constructor", "get",
                "set", "of", "in", "delete", "void", "yield", "debugger", "type", "interface",
                "enum", "namespace", "module", "declare", "readonly", "abstract", "implements",
                "keyof", "never", "unknown", "any", "private", "protected", "public"
            ],
            types: [
                "string", "number", "boolean", "object", "undefined", "null", "void", "never",
                "unknown", "any", "Array", "Object", "Function", "Date", "RegExp", "Promise",
                "Map", "Set", "Record", "Partial", "Required", "Pick", "Omit", "Exclude",
                "Extract", "NonNullable", "ReturnType", "Parameters"
            ],
            functions: [
                "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
                "setTimeout", "clearTimeout", "setInterval", "clearInterval", "fetch",
                "console.log", "console.error", "JSON.parse", "JSON.stringify"
            ],
            literals: [
                "true", "false", "null", "undefined", "NaN", "Infinity", "this", "super"
            ],
            triggerCharacters: [".", "(", "[", "{", " ", ":", "<"],
            snippets: TypeScriptSnippets.all,
            memberCompletions: TypeScriptMemberCompletions(),
            commonModules: [
                "react", "vue", "angular", "express", "lodash", "axios", "typescript", "webpack",
                "jest", "mocha", "eslint", "prettier", "nodemon", "dotenv", "cors", "bcrypt"
            ]
        )
}
