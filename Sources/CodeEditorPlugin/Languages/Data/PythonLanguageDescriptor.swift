import Foundation

extension LanguageDescriptor {
    // ── Python ─────────────────────────────────────────────────────
    static let pythonDescriptor = Self(
            language: .python,
            displayName: "Python",
            fileExtensions: ["py", "pyw"],
            lspIdentifier: "python",
            highlightingStrategy: .regex,
            lineComment: "#",
            blockCommentStart: "\"\"\"",
            blockCommentEnd: "\"\"\"",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"\"\"\"[\s\S]*?\"\"\""#, .string, priority: 11),
                .init(#"'''[\s\S]*?'''"#, .string, priority: 11),
                .init(#"\bdef\s+(\w+)"#, .function, priority: 6)
            ],
            keywords: [
                "def", "class", "if", "elif", "else", "for", "while", "try", "except", "finally",
                "with", "as", "import", "from", "return", "yield", "break", "continue", "pass",
                "global", "nonlocal", "lambda", "and", "or", "not", "in", "is", "del", "async",
                "await", "assert", "raise", "match", "case"
            ],
            types: [
                "int", "float", "str", "bool", "list", "tuple", "dict", "set", "frozenset",
                "bytes", "bytearray", "memoryview", "range", "complex", "type", "object",
                "property", "staticmethod", "classmethod", "super"
            ],
            functions: [
                "print", "input", "len", "range", "enumerate", "zip", "map", "filter", "sorted",
                "reversed", "sum", "min", "max", "any", "all", "abs", "round", "pow", "divmod",
                "isinstance", "issubclass", "hasattr", "getattr", "setattr", "delattr", "open",
                "format", "chr", "ord", "bin", "hex", "oct", "eval", "exec", "compile", "globals",
                "locals", "vars", "dir", "help", "id", "hash", "iter", "next", "callable", "repr"
            ],
            literals: [
                "True", "False", "None", "self", "cls", "__name__", "__main__", "__file__"
            ],
            triggerCharacters: [".", "(", "[", " ", ":"],
            snippets: DescriptorSnippetData.python,
            memberCompletions: PythonMemberCompletions(),
            commonModules: [],
            parserName: "python",
            shebangIdentifiers: ["python", "python2", "python3"],
            scriptAliases: ["python", "python2", "python3"]
        )
}
