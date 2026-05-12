import Foundation

// MARK: - Language Definition Factory Methods

extension RegexSyntaxHighlighter {
    /// Constructs a HighlightRule, logging a fault and returning nil if the
    /// pattern fails to compile. In debug builds an `assertionFailure` surfaces
    /// the broken pattern so it gets fixed before shipping; in release the
    /// rule is dropped and highlighting continues with the remaining rules.
    internal static func rule(
        _ pattern: String,
        _ tokenType: RegexSyntaxTokenType,
        _ priority: Int = 0,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> RegexHighlightRule? {
        do {
            return try RegexHighlightRule(pattern: pattern, tokenType: tokenType, priority: priority)
        } catch {
            CrossPlatformLogger.logger().fault(
                "RegexSyntaxHighlighter: failed to compile pattern \"\(pattern)\": \(error.localizedDescription)"
            )
            assertionFailure(
                "RegexSyntaxHighlighter: failed to compile pattern \"\(pattern)\": \(error)",
                file: file,
                line: line
            )
            return nil
        }
    }

    internal static func createLanguageDefinitions() -> [String: RegexLanguageDefinition] {
        var languages: [String: RegexLanguageDefinition] = [:]

        // JavaScript/TypeScript
        languages["javascript"] = createJavaScriptDefinition()
        languages["typescript"] = createTypeScriptDefinition()

        // Python
        languages["python"] = createPythonDefinition()

        // C/C++
        languages["c"] = createCDefinition()
        languages["cpp"] = createCppDefinition()

        // Java
        languages["java"] = createJavaDefinition()

        // Rust
        languages["rust"] = createRustDefinition()

        // Go
        languages["go"] = createGoDefinition()

        // Ruby
        languages["ruby"] = createRubyDefinition()

        // PHP
        languages["php"] = createPHPDefinition()

        // CSS
        languages["css"] = createCSSDefinition()

        // HTML
        languages["html"] = createHTMLDefinition()

        // JSON
        languages["json"] = createJSONDefinition()

        // Markdown
        languages["markdown"] = createMarkdownDefinition()

        // YAML
        languages["yaml"] = createYAMLDefinition()

        // XML
        languages["xml"] = createXMLDefinition()

        // SQL
        languages["sql"] = createSQLDefinition()

        // Shell
        languages["shell"] = createShellDefinition()

        // Dockerfile
        languages["dockerfile"] = createDockerfileDefinition()

        // TOML
        languages["toml"] = createTOMLDefinition()

        // Lua
        languages["lua"] = createLuaDefinition()

        // C#
        languages["csharp"] = createCSharpDefinition()

        // Kotlin
        languages["kotlin"] = createKotlinDefinition()

        // Dart
        languages["dart"] = createDartDefinition()

        return languages
    }

    /// Create efficient Language enum to LanguageDefinition mapping
    internal static func createLanguageMap(from definitions: [String: RegexLanguageDefinition]) -> [Language: RegexLanguageDefinition] {
        var languageMap: [Language: RegexLanguageDefinition] = [:]

        // Map Language enum cases to their corresponding LanguageDefinitions
        for language in Language.allCases {
            switch language {
            case .swift:
                // Swift is handled by SwiftSyntaxHighlighter, not regex highlighter
                break

            case .python:
                languageMap[language] = definitions["python"]

            case .javascript:
                languageMap[language] = definitions["javascript"]

            case .typescript:
                languageMap[language] = definitions["typescript"]

            case .c:
                languageMap[language] = definitions["c"]

            case .cpp:
                languageMap[language] = definitions["cpp"]

            case .java:
                languageMap[language] = definitions["java"]

            case .rust:
                languageMap[language] = definitions["rust"]

            case .go:
                languageMap[language] = definitions["go"]

            case .ruby:
                languageMap[language] = definitions["ruby"]

            case .php:
                languageMap[language] = definitions["php"]

            case .html:
                languageMap[language] = definitions["html"]

            case .css:
                languageMap[language] = definitions["css"]

            case .json:
                languageMap[language] = definitions["json"]

            case .yaml:
                languageMap[language] = definitions["yaml"]

            case .xml:
                languageMap[language] = definitions["xml"]

            case .markdown:
                languageMap[language] = definitions["markdown"]

            case .sql:
                languageMap[language] = definitions["sql"]

            case .shell:
                languageMap[language] = definitions["shell"]

            case .dockerfile:
                languageMap[language] = definitions["dockerfile"]

            case .toml:
                languageMap[language] = definitions["toml"]

            case .lua:
                languageMap[language] = definitions["lua"]

            case .csharp:
                languageMap[language] = definitions["csharp"]

            case .kotlin:
                languageMap[language] = definitions["kotlin"]

            case .dart:
                languageMap[language] = definitions["dart"]

            case .plainText:
                // Plain text doesn't need highlighting
                break
            }
        }

        return languageMap
    }

    // MARK: - Individual Language Definitions

    private static func createJavaScriptDefinition() -> LanguageDefinition {
        let jsKeywords = [
            "const", "let", "var", "function", "class", "if", "else", "for", "while", "do",
            "switch", "case", "default", "break", "continue", "return", "try", "catch",
            "finally", "throw", "async", "await", "import", "export", "from", "as",
            "typeof", "instanceof"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            .addStrings(single: true, double: true, backtick: true)
            .addNumbers()
            .addKeywords(jsKeywords)
            .addFunctionCalls()
            .addOperators()
            .build(name: "JavaScript", fileExtensions: ["js", "jsx", "mjs"])
    }

    private static func createTypeScriptDefinition() -> LanguageDefinition {
        let tsKeywords = [
            "const", "let", "var", "function", "class", "interface", "type", "enum", "namespace",
            "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
            "return", "try", "catch", "finally", "throw", "async", "await", "import", "export",
            "from", "as", "typeof", "instanceof", "public", "private", "protected", "readonly", "static"
        ]

        let tsTypes = ["string", "number", "boolean", "object", "any", "void", "never", "unknown"]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            .addStrings(single: true, double: true, backtick: true)
            .addNumbers()
            .addKeywords(tsKeywords)
            .addCustomRule(pattern: #"\b("# + tsTypes.joined(separator: "|") + #")\b"#, type: .type, priority: 7)
            .addFunctionCalls()
            .addOperators()
            .build(name: "TypeScript", fileExtensions: ["ts", "tsx"])
    }

    private static func createPythonDefinition() -> LanguageDefinition {
        let pythonKeywords = [
            "def", "class", "if", "elif", "else", "for", "while", "try", "except", "finally",
            "with", "as", "import", "from", "return", "yield", "break", "continue", "pass",
            "global", "nonlocal", "lambda", "and", "or", "not", "in", "is", "True", "False", "None"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "#")
            .addCustomRule(pattern: #"\"\"\"[\s\S]*?\"\"\""#, type: .string, priority: 9) // Triple-quoted strings
            .addCustomRule(pattern: #"'''[\s\S]*?'''"#, type: .string, priority: 9)
            .addStrings(single: true, double: true)
            .addNumbers()
            .addKeywords(pythonKeywords)
            .addCustomRule(pattern: #"\bdef\s+(\w+)"#, type: .function, priority: 6) // Function definitions
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!&|^~]+"#)
            .build(name: "Python", fileExtensions: ["py", "pyw"])
    }

    private static func createCDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            // Comments
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),

            // Preprocessor
            rule(#"#\w+.*$"#, .preprocessor, 8),

            // Strings
            rule(#"R\"[A-Za-z0-9_]*\([\s\S]*?\)[A-Za-z0-9_]*\""#, .string, 9),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),

            // Numbers
            rule(#"\b\d+\.?\d*[fFlL]?\b"#, .number, 8),

            // Keywords
            rule(
                #"\b(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while)\b"#,
                .keyword,
                7
            ),

            // Types
            rule(
                #"\b(int|char|float|double|void|long|short|signed|unsigned)\b"#,
                .type,
                7
            ),

            // Function calls
            rule(#"\b\w+(?=\s*\()"#, .function, 6),

            // Operators
            rule(#"[+\-*/%=<>!&|^~?:]+"#, .operator, 5)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "C", fileExtensions: ["c", "h"], rules: rules)
    }

    private static func createCppDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            // Comments
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),

            // Preprocessor
            rule(#"#\w+.*$"#, .preprocessor, 8),

            // Strings
            rule(#"R\"[A-Za-z0-9_]*\([\s\S]*?\)[A-Za-z0-9_]*\""#, .string, 9),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),

            // Numbers
            rule(#"\b\d+\.?\d*[fFlL]?\b"#, .number, 8),

            // Keywords (includes C++ specific)
            rule(
                #"\b(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|class|namespace|public|private|protected|virtual|override|final|template|typename|try|catch|throw|new|delete|this|friend|inline|operator|explicit|mutable|constexpr|nullptr|decltype|noexcept)\b"#,
                .keyword,
                7
            ),

            // Types
            rule(
                #"\b(int|char|float|double|void|long|short|signed|unsigned|bool|string|vector|map|set|list|deque|stack|queue|priority_queue)\b"#,
                .type,
                7
            ),

            // Function calls
            rule(#"\b\w+(?=\s*\()"#, .function, 6),

            // Operators
            rule(#"[+\-*/%=<>!&|^~?:]+"#, .operator, 5)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "C++", fileExtensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx"], rules: rules)
    }

    private static func createJavaDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#"\"\"\"[\s\S]*?\"\"\""#, .string, 9),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)'"#, .string, 9),
            rule(#"\b\d+\.?\d*[fFlLdD]?\b"#, .number, 8),
            rule(
                #"\b(abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|void|volatile|while)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "Java", fileExtensions: ["java"], rules: rules)
    }

    private static func createRustDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(as|break|const|continue|crate|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while|async|await|dyn)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "Rust", fileExtensions: ["rs"], rules: rules)
    }

    private static func createGoDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"`[^`]*`"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "Go", fileExtensions: ["go"], rules: rules)
    }

    private static func createRubyDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"#.*$"#, .comment, 10),
            rule(#"(?m)^=begin[\s\S]*?^=end"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(alias|and|begin|break|case|class|def|defined|do|else|elsif|end|ensure|false|for|if|in|module|next|nil|not|or|redo|rescue|retry|return|self|super|then|true|undef|unless|until|when|while|yield)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "Ruby", fileExtensions: ["rb", "rbw"], rules: rules)
    }

    private static func createPHPDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#"#.*$"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|die|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|namespace|new|or|print|private|protected|public|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "PHP", fileExtensions: ["php", "phtml", "php3", "php4", "php5"], rules: rules)
    }

    private static func createCSSDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),
            rule(#"#[a-fA-F0-9]{3,6}\b"#, .number, 8),
            rule(
                #"\b\d+\.?\d*(px|em|rem|%|vh|vw|pt|pc|in|cm|mm|ex|ch|vmin|vmax|deg|rad|grad|turn|s|ms|Hz|kHz|dpi|dpcm|dppx)?\b"#,
                .number,
                8
            ),
            rule(#"[.#]?[a-zA-Z_][\w-]*(?=\s*\{)"#, .type, 7),
            rule(#"[a-zA-Z-]+(?=\s*:)"#, .property, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "CSS", fileExtensions: ["css", "scss", "sass", "less"], rules: rules)
    }

    private static func createHTMLDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"<!--[\s\S]*?-->"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),
            rule(#"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>"#, .keyword, 8),
            rule(#"\b[a-zA-Z-]+(?==)"#, .property, 7)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "HTML", fileExtensions: ["html", "htm", "xhtml"], rules: rules)
    }

    private static func createJSONDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(#"\b(true|false|null)\b"#, .keyword, 7),
            rule(#"[{}\[\],:]"#, .punctuation, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "JSON", fileExtensions: ["json", "jsonc"], rules: rules)
    }

    private static func createMarkdownDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"^#{1,6}\s+.*$"#, .keyword, 10),
            rule(#"`[^`]*`"#, .string, 9),
            rule(#"```[\s\S]*?```"#, .string, 9),
            rule(#"\*\*[^*]+\*\*"#, .keyword, 8),
            rule(#"__[^_]+__"#, .keyword, 8),
            rule(#"\*[^*]+\*"#, .type, 7),
            rule(#"_[^_]+_"#, .type, 7),
            rule(#"\[([^\]]+)\]\([^)]+\)"#, .function, 6)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "Markdown", fileExtensions: ["md", "markdown", "mdown", "mkd"], rules: rules)
    }

    private static func createYAMLDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"#.*$"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(#"\b(true|false|null|yes|no|on|off)\b"#, .keyword, 7),
            rule(#"^[a-zA-Z_][\w\-]*(?=\s*:)"#, .property, 6),
            rule(#"[:\-\[\]{}]"#, .punctuation, 5)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "YAML", fileExtensions: ["yaml", "yml"], rules: rules)
    }

    private static func createXMLDefinition() -> RegexLanguageDefinition {
        let rules: [RegexHighlightRule] = [
            rule(#"<!--[\s\S]*?-->"#, .comment, 10),
            rule(#"\"(?:[^\"\\\\]|\\\\.)*\""#, .string, 9),
            rule(#"'(?:[^'\\\\]|\\\\.)*'"#, .string, 9),
            rule(#"<\?[\s\S]*?\?>"#, .preprocessor, 8),
            rule(#"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>"#, .keyword, 8),
            rule(#"\b[a-zA-Z-]+(?==)"#, .property, 7)
        ].compactMap(\.self)

        return RegexLanguageDefinition(name: "XML", fileExtensions: ["xml", "xsl", "xslt", "svg"], rules: rules)
    }

    private static func createSQLDefinition() -> LanguageDefinition {
        let sqlKeywords = [
            "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP", "ALTER",
            "TABLE", "INDEX", "VIEW", "DATABASE", "SCHEMA", "CONSTRAINT", "PRIMARY", "FOREIGN",
            "KEY", "REFERENCES", "NOT", "NULL", "UNIQUE", "DEFAULT", "CHECK", "AND", "OR",
            "BETWEEN", "IN", "LIKE", "IS", "EXISTS", "JOIN", "INNER", "LEFT", "RIGHT", "FULL",
            "OUTER", "UNION", "GROUP", "BY", "HAVING", "ORDER", "ASC", "DESC", "LIMIT", "OFFSET"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "--", multiLineStart: "/*", multiLineEnd: "*/")
            .addStrings(single: true, double: true)
            .addNumbers()
            .addKeywords(sqlKeywords)
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!]+"#)
            .build(name: "SQL", fileExtensions: ["sql"])
    }

    private static func createShellDefinition() -> LanguageDefinition {
        let shellKeywords = [
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done",
            "function", "return", "break", "continue", "exit", "export", "local", "readonly", "declare",
            "typeset", "let", "eval", "exec", "shift", "set", "unset", "trap", "source", "alias", "unalias"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "#")
            .addStrings(single: true, double: true)
            .addNumbers()
            .addKeywords(shellKeywords)
            .addCustomRule(pattern: #"\$\{[^}]+\}"#, type: .identifier, priority: 8) // Variable substitution
            .addCustomRule(pattern: #"\$[a-zA-Z_][a-zA-Z0-9_]*"#, type: .identifier, priority: 8) // Variables
            .addCustomRule(pattern: #"\b\w+(?=\s*\()"#, type: .function, priority: 6) // Function calls
            .addOperators(pattern: #"[|&;<>()]+"#)
            .build(name: "Shell", fileExtensions: ["sh", "bash", "zsh", "fish"])
    }

    private static func createDockerfileDefinition() -> LanguageDefinition {
        LanguageDefinitionBuilder()
            .addComments(singleLine: "#")
            .addStrings(single: false, double: true)
            .addNumbers()
            // Dockerfile instructions as keywords (typically at line start)
            .addCustomRule(
                pattern: #"^\s*(FROM|RUN|CMD|ENTRYPOINT|COPY|ADD|WORKDIR|ENV|ARG|EXPOSE|VOLUME|USER|LABEL|MAINTAINER|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b"#,
                type: .keyword,
                priority: 10
            )
            // Multi-line continuation
            .addCustomRule(pattern: #"\\\s*$"#, type: .operator, priority: 6)
            // Variable substitution: ${VAR} and $VAR
            .addCustomRule(pattern: #"\$\{[^}]+\}"#, type: .identifier, priority: 8)
            .addCustomRule(pattern: #"\$[a-zA-Z_][a-zA-Z0-9_]*"#, type: .identifier, priority: 7)
            // Options like --from=, --chown=
            .addCustomRule(pattern: #"--[a-zA-Z][a-zA-Z-]*(?==)"#, type: .property, priority: 7)
            .build(name: "Dockerfile", fileExtensions: ["dockerfile"])
    }

    private static func createTOMLDefinition() -> LanguageDefinition {
        LanguageDefinitionBuilder()
            .addComments(singleLine: "#")
            .addStrings(single: true, double: true)
            .addNumbers()
            // Section headers: [section] or [[array]]
            .addCustomRule(pattern: #"^\[{1,2}[^\]]+\]{1,2}"#, type: .keyword, priority: 10)
            // Key-value pairs
            .addCustomRule(pattern: #"^[a-zA-Z_][a-zA-Z0-9_-]*(?=\s*=)"#, type: .property, priority: 8)
            .addCustomRule(pattern: #"\b(true|false)\b"#, type: .keyword, priority: 7)
            .build(name: "TOML", fileExtensions: ["toml"])
    }

    private static func createLuaDefinition() -> LanguageDefinition {
        let luaKeywords = [
            "and", "break", "do", "else", "elseif", "end", "false", "for",
            "function", "goto", "if", "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "--")
            .addCustomRule(pattern: #"--\[\[[\s\S]*?]]"#, type: .comment, priority: 10)
            .addStrings(single: true, double: true)
            .addCustomRule(pattern: #"\[\[[\s\S]*?]]"#, type: .string, priority: 9) // Long strings
            .addNumbers()
            .addKeywords(luaKeywords)
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!&|^~#]+"#)
            .build(name: "Lua", fileExtensions: ["lua"])
    }

    private static func createCSharpDefinition() -> LanguageDefinition {
        let csKeywords = [
            "abstract", "as", "base", "bool", "break", "byte", "case", "catch",
            "char", "checked", "class", "const", "continue", "decimal", "default",
            "delegate", "do", "double", "else", "enum", "event", "explicit", "extern",
            "false", "finally", "fixed", "float", "for", "foreach", "goto", "if",
            "implicit", "in", "int", "interface", "internal", "is", "lock", "long",
            "namespace", "new", "null", "object", "operator", "out", "override",
            "params", "private", "protected", "public", "readonly", "ref", "return",
            "sbyte", "sealed", "short", "sizeof", "stackalloc", "static", "string",
            "struct", "switch", "this", "throw", "true", "try", "typeof", "uint",
            "ulong", "unchecked", "unsafe", "ushort", "using", "var", "virtual",
            "void", "volatile", "while"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            .addStrings(single: true, double: true)
            .addCustomRule(pattern: #"\$\"[^\"]*\""#, type: .string, priority: 9) // Interpolated strings
            .addNumbers()
            .addKeywords(csKeywords)
            .addCustomRule(pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, type: .type, priority: 7) // PascalCase types
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!&|^~?:]+"#)
            .build(name: "C#", fileExtensions: ["cs"])
    }

    private static func createKotlinDefinition() -> LanguageDefinition {
        let ktKeywords = [
            "abstract", "annotation", "as", "break", "by", "catch", "class",
            "companion", "const", "constructor", "continue", "data", "do", "else",
            "enum", "false", "final", "finally", "for", "fun", "if", "import",
            "in", "init", "inner", "interface", "internal", "is", "lateinit",
            "null", "object", "open", "operator", "out", "override", "package",
            "private", "protected", "public", "return", "sealed", "super", "suspend",
            "this", "throw", "true", "try", "typealias", "val", "var", "vararg",
            "when", "while"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            .addStrings(single: true, double: true)
            .addCustomRule(pattern: #"\$\{[^}]+\}"#, type: .identifier, priority: 9) // String templates
            .addCustomRule(pattern: #"\$\w+"#, type: .identifier, priority: 8) // $variable
            .addNumbers()
            .addKeywords(ktKeywords)
            .addCustomRule(pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, type: .type, priority: 7) // PascalCase types
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!&|^~?:]+"#)
            .build(name: "Kotlin", fileExtensions: ["kt", "kts"])
    }

    private static func createDartDefinition() -> LanguageDefinition {
        let dartKeywords = [
            "abstract", "as", "assert", "async", "await", "break", "case", "catch",
            "class", "const", "continue", "default", "deferred", "do", "dynamic",
            "else", "enum", "export", "extends", "extension", "external", "factory",
            "false", "final", "finally", "for", "Function", "get", "hide", "if",
            "implements", "import", "in", "interface", "is", "late", "library",
            "mixin", "new", "null", "on", "operator", "part", "required", "rethrow",
            "return", "set", "show", "static", "super", "switch", "sync", "this",
            "throw", "true", "try", "typedef", "var", "void", "while", "with", "yield"
        ]

        return LanguageDefinitionBuilder()
            .addComments(singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            .addStrings(single: true, double: true)
            .addCustomRule(pattern: #"\$\{[^}]+\}"#, type: .identifier, priority: 9) // String interpolation
            .addNumbers()
            .addKeywords(dartKeywords)
            .addCustomRule(pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, type: .type, priority: 7) // PascalCase types
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!&|^~?:]+"#)
            .build(name: "Dart", fileExtensions: ["dart"])
    }
}
