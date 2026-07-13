import Foundation

extension LanguageDescriptor {
    // ── JavaScript ─────────────────────────────────────────────────
    static let javascriptDescriptor = Self(
            language: .javascript,
            fileExtensions: ["js", "jsx", "mjs"],
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
                "set", "of", "in", "delete", "void", "yield", "debugger", "with"
            ],
            types: [
                "Object", "Array", "String", "Number", "Boolean", "Function", "Symbol", "Date",
                "RegExp", "Error", "Math", "JSON", "console", "Promise", "Map", "Set", "WeakMap",
                "WeakSet", "Proxy", "Reflect", "BigInt"
            ],
            functions: [
                "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
                "encodeURIComponent", "decodeURIComponent", "eval", "setTimeout", "clearTimeout",
                "setInterval", "clearInterval", "fetch", "alert", "confirm", "prompt"
            ],
            literals: [
                "true", "false", "null", "undefined", "NaN", "Infinity", "globalThis", "window", "document"
            ],
            triggerCharacters: [".", "(", "[", "{", " ", ":"],
            snippets: DescriptorSnippetData.javascript,
            memberCompletions: JavaScriptMemberCompletions(),
            commonModules: [],
            shebangIdentifiers: ["node", "javascript"],
            scriptAliases: ["node", "js"]
        )
}
