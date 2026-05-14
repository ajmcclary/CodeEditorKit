import Foundation

extension LanguageDescriptor {
    // ── Java ───────────────────────────────────────────────────────
    static let javaDescriptor = Self(
            language: .java,
            displayName: "Java",
            fileExtensions: ["java"],
            lspIdentifier: "java",
            usesRegexHighlighter: true,
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_$][a-zA-Z0-9_$]*",
            stringDelimiters: ["\""],
            highlightingRules: [
                .init(#"\"\"\"[\s\S]*?\"\"\""#, .string, priority: 9),
                .init(#"'(?:[^'\\]|\\.)'"#, .string, priority: 9)
            ],
            keywords: [
                "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
                "class", "const", "continue", "default", "do", "double", "else", "enum",
                "extends", "final", "finally", "float", "for", "goto", "if", "implements",
                "import", "instanceof", "int", "interface", "long", "native", "new", "package",
                "private", "protected", "public", "return", "short", "static", "strictfp",
                "super", "switch", "synchronized", "this", "throw", "throws", "transient",
                "try", "void", "volatile", "while", "var", "record", "sealed", "permits", "yield"
            ],
            types: [
                "String", "Integer", "Long", "Double", "Float", "Boolean", "Character", "Byte",
                "Short", "Object", "Class", "ArrayList", "HashMap", "HashSet", "LinkedList",
                "TreeMap", "TreeSet", "Optional", "Stream", "List", "Map", "Set", "Collection"
            ],
            functions: [
                "System.out.println", "System.out.print", "System.err.println", "String.valueOf",
                "Integer.parseInt", "Double.parseDouble", "Arrays.asList", "Collections.sort",
                "Objects.equals", "Objects.requireNonNull"
            ],
            literals: [
                "true", "false", "null", "this", "super"
            ],
            triggerCharacters: [".", "(", " ", "@"],
            snippets: DescriptorSnippetData.java,
            memberCompletions: JavaMemberCompletions(),
            commonModules: [],
            parserName: "java",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
