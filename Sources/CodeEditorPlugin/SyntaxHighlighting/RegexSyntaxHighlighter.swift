import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// Use centralized platform color type
public typealias RegexHighlighterColor = PlatformColor

// MARK: - RegexSyntaxHighlighter

/// A pure Swift regex-based syntax highlighter for various programming languages
public final class RegexSyntaxHighlighter: Sendable {
    // MARK: - Performance Constants
    
    /// Optimized token type mapping for O(1) conversion
    static let tokenTypeMap: [RegexTokenType: TokenType] = [
        .keyword: .keyword,
        .identifier: .identifier,
        .string: .string,
        .number: .number,
        .comment: .comment,
        .type: .type,
        .function: .function,
        .property: .property,
        .operator: .operator,
        .punctuation: .punctuation,
        .whitespace: .whitespace,
        .preprocessor: .preprocessor,
        .unknown: .unknown
    ]
    
    // MARK: - Language Definitions

    public struct LanguageDefinition: Sendable {
        public let name: String
        public let fileExtensions: [String]
        public let rules: [HighlightRule]

        public init(name: String, fileExtensions: [String], rules: [HighlightRule]) {
            self.name = name
            self.fileExtensions = fileExtensions
            // Pre-sort rules by priority once during initialization
            self.rules = rules.sorted { $0.priority > $1.priority }
        }
    }

    public struct HighlightRule: Sendable {
        public let pattern: NSRegularExpression
        public let tokenType: RegexTokenType
        public let priority: Int

        public init(pattern: String, tokenType: RegexTokenType, priority: Int = 0) throws {
            self.pattern = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            self.tokenType = tokenType
            self.priority = priority
        }
    }

    // MARK: - Token Types

    public enum RegexTokenType: String, CaseIterable, Sendable {
        case keyword
        case identifier
        case string
        case number
        case comment
        case type
        case function
        case property
        case `operator`
        case punctuation
        case whitespace
        case preprocessor
        case unknown

        public var color: RegexHighlighterColor {
            switch self {
            case .keyword:
                PlatformColors.systemPurple

            case .identifier:
                PlatformColors.label

            case .string:
                PlatformColors.systemRed

            case .number:
                PlatformColors.systemBlue

            case .comment:
                PlatformColors.systemGreen

            case .type:
                PlatformColors.systemTeal

            case .function:
                PlatformColors.systemIndigo

            case .property:
                PlatformColors.systemOrange

            case .operator:
                PlatformColors.systemBrown

            case .punctuation:
                PlatformColors.secondaryLabel

            case .whitespace:
                PlatformColors.clear

            case .preprocessor:
                PlatformColors.systemPink

            case .unknown:
                PlatformColors.label
            }
        }
    }

    // Note: HighlightedToken and TokenType are defined in SyntaxHighlightingCoordinator.swift
// We'll need to explicitly qualify the TokenType to avoid naming conflicts

    // MARK: - Properties

    public let supportedLanguages: [String: LanguageDefinition]
    
    // Direct language mapping for efficient lookup
    private let languageMap: [Language: LanguageDefinition]

    // MARK: - Initialization

    public init() {
        supportedLanguages = Self.createLanguageDefinitions()
        languageMap = Self.createLanguageMap(from: supportedLanguages)
    }

    // MARK: - Public Methods

    /// Get language definition by file extension (legacy method)
    public func languageDefinition(for fileExtension: String) -> LanguageDefinition? {
        supportedLanguages.values.first { language in
            language.fileExtensions.contains(fileExtension.lowercased())
        }
    }
    
    /// Get language definition by Language enum case (preferred method)
    public func languageDefinition(for language: Language) -> LanguageDefinition? {
        languageMap[language]
    }

    /// Highlight source code using the specified language definition
    public func highlight(source: String, language: LanguageDefinition) -> [HighlightedToken] {
        guard !source.isEmpty else {
            return []
        }

        // Pre-allocate collections with estimated capacity for better performance
        var tokens: [HighlightedToken] = []
        tokens.reserveCapacity(min(source.count / 20, 1_000))
        
        let range = NSRange(location: 0, length: source.utf16.count)

        // Use sorted array for processed ranges to enable binary search optimization
        var processedRanges: [NSRange] = []
        processedRanges.reserveCapacity(min(source.count / 20, 1_000))

        // Rules are already pre-sorted by priority in LanguageDefinition
        for rule in language.rules {
            let matches = rule.pattern.matches(in: source, options: [], range: range)

            for match in matches {
                let matchRange = match.range

                // Optimized overlap checking with early termination
                // Since processedRanges is kept sorted, we can break early
                var hasOverlap = false
                for existingRange in processedRanges {
                    // Early termination: if existing range starts after this match ends, no more overlaps possible
                    if existingRange.location >= NSMaxRange(matchRange) {
                        break
                    }
                    // Check for actual overlap
                    if NSIntersectionRange(existingRange, matchRange).length > 0 {
                        hasOverlap = true
                        break
                    }
                }
                
                if hasOverlap {
                    continue
                }

                // Convert token type efficiently using lookup instead of switch
                let coordinatorTokenType = mapTokenType(rule.tokenType)
                
                // Only create substring when we actually need the text content
                guard let stringRange = Range(matchRange, in: source) else {
                    continue
                }
                let text = String(source[stringRange])
                tokens.append(HighlightedToken(range: matchRange, type: coordinatorTokenType, text: text))
                
                // Insert range in sorted order to maintain invariant for early termination
                let insertIndex = processedRanges.firstIndex { $0.location > matchRange.location } ?? processedRanges.count
                processedRanges.insert(matchRange, at: insertIndex)
            }
        }

        // Already sorted due to our insertion strategy
        return tokens
    }
    
    /// Efficiently map RegexTokenType to TokenType using lookup table
    private func mapTokenType(_ regexTokenType: RegexTokenType) -> TokenType {
        // Use class-level lookup table for O(1) token type conversion
        Self.tokenTypeMap[regexTokenType] ?? .unknown
    }

    /// Apply highlighting to an attributed string
    @MainActor
    public func applyHighlighting(to attributedString: NSMutableAttributedString, tokens: [HighlightedToken]) {
        // Remove existing syntax highlighting
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.removeAttribute(.foregroundColor, range: range)

        // Apply new highlighting
        for token in tokens {
            guard token.range.location + token.range.length <= attributedString.length else {
                continue
            }
            attributedString.addAttribute(.foregroundColor, value: token.type.color, range: token.range)
        }
    }

    deinit {
        // Cleanup if needed
    }

    // MARK: - Language Definitions

    /// Safely creates a HighlightRule, returning nil if the pattern is invalid
    private static func rule(_ pattern: String, _ tokenType: RegexTokenType, _ priority: Int = 0) -> HighlightRule? {
        try? HighlightRule(pattern: pattern, tokenType: tokenType, priority: priority)
    }

    private static func createLanguageDefinitions() -> [String: LanguageDefinition] {
        var languages: [String: LanguageDefinition] = [:]

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

        return languages
    }
    
    /// Create efficient Language enum to LanguageDefinition mapping
    private static func createLanguageMap(from definitions: [String: LanguageDefinition]) -> [Language: LanguageDefinition] {
        var languageMap: [Language: LanguageDefinition] = [:]
        
        // Map Language enum cases to their corresponding LanguageDefinitions
        for language in Language.allCases {
            switch language {
            case .swift:
                // Swift is handled by SwiftSyntaxHighlighter, not regex highlighter
                break

            case .javascript:
                languageMap[language] = definitions["javascript"]

            case .typescript:
                languageMap[language] = definitions["typescript"]

            case .python:
                languageMap[language] = definitions["python"]

            case .go:
                languageMap[language] = definitions["go"]

            case .rust:
                languageMap[language] = definitions["rust"]

            case .c:
                languageMap[language] = definitions["c"]

            case .cpp:
                languageMap[language] = definitions["cpp"]

            case .java:
                languageMap[language] = definitions["java"]

            case .html:
                languageMap[language] = definitions["html"]

            case .css:
                languageMap[language] = definitions["css"]

            case .json:
                languageMap[language] = definitions["json"]

            case .markdown:
                languageMap[language] = definitions["markdown"]

            case .yaml:
                languageMap[language] = definitions["yaml"]

            case .xml:
                languageMap[language] = definitions["xml"]

            case .sql:
                languageMap[language] = definitions["sql"]

            case .ruby:
                languageMap[language] = definitions["ruby"]

            case .php:
                languageMap[language] = definitions["php"]

            case .shell:
                languageMap[language] = definitions["shell"]

            case .plainText:
                // Plain text doesn't need syntax highlighting
                break
            }
        }
        
        return languageMap
    }
    
    // MARK: - Language Definition Builder
    
    /// A builder class to reduce boilerplate when creating language definitions
    private struct LanguageDefinitionBuilder {
        private var rules: [HighlightRule] = []
        
        /// Add comment patterns for the language
        func addComments(singleLine: String? = nil, multiLineStart: String? = nil, multiLineEnd: String? = nil) -> Self {
            var newRules = rules
            
            if let singleLine {
                if let rule = Self.rule(singleLine + #".*$"#, .comment, 10) {
                    newRules.append(rule)
                }
            }
            
            if let start = multiLineStart, let end = multiLineEnd {
                let pattern = NSRegularExpression.escapedPattern(for: start) + #"[\s\S]*?"# + NSRegularExpression.escapedPattern(for: end)
                if let rule = Self.rule(pattern, .comment, 10) {
                    newRules.append(rule)
                }
            }
            
            return Self(rules: newRules)
        }
        
        /// Add string patterns for the language
        func addStrings(single: Bool = true, double: Bool = true, backtick: Bool = false) -> Self {
            var newRules = rules
            
            if double {
                if let rule = Self.rule(#""(?:[^"\\]|\\.)*""#, .string, 9) {
                    newRules.append(rule)
                }
            }
            
            if single {
                if let rule = Self.rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9) {
                    newRules.append(rule)
                }
            }
            
            if backtick {
                if let rule = Self.rule(#"`(?:[^`\\]|\\.)*`"#, .string, 9) {
                    newRules.append(rule)
                }
            }
            
            return Self(rules: newRules)
        }
        
        /// Add number patterns for the language
        func addNumbers(pattern: String = #"\b\d+\.?\d*\b"#) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, .number, 8) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }
        
        /// Add keywords for the language
        func addKeywords(_ keywords: [String]) -> Self {
            var newRules = rules
            let keywordPattern = #"\b("# + keywords.joined(separator: "|") + #")\b"#
            if let rule = Self.rule(keywordPattern, .keyword, 7) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }
        
        /// Add function call patterns
        func addFunctionCalls(pattern: String = #"\b\w+(?=\s*\()"#) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, .function, 6) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }
        
        /// Add operator patterns
        func addOperators(pattern: String = #"[+\-*/%=<>!&|^~?:]+"#) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, .operator, 5) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }
        
        /// Add a custom rule
        func addCustomRule(pattern: String, type: RegexTokenType, priority: Int) -> Self {
            var newRules = rules
            if let rule = Self.rule(pattern, type, priority) {
                newRules.append(rule)
            }
            return Self(rules: newRules)
        }
        
        /// Build the final language definition
        func build(name: String, fileExtensions: [String]) -> LanguageDefinition {
            LanguageDefinition(name: name, fileExtensions: fileExtensions, rules: rules)
        }
        
        /// Helper method to create rules (same as the outer rule method)
        private static func rule(_ pattern: String, _ tokenType: RegexTokenType, _ priority: Int) -> HighlightRule? {
            do {
                return try HighlightRule(pattern: pattern, tokenType: tokenType, priority: priority)
            } catch {
                // Silently fail - invalid regex patterns should not crash
                // In production, this would be logged by the caller
                return nil
            }
        }
    }

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
            .addCustomRule(pattern: #""""[\s\S]*?""""#, type: .string, priority: 9) // Triple-quoted strings
            .addCustomRule(pattern: #"'''[\s\S]*?'''"#, type: .string, priority: 9)
            .addStrings(single: true, double: true)
            .addNumbers()
            .addKeywords(pythonKeywords)
            .addCustomRule(pattern: #"\bdef\s+(\w+)"#, type: .function, priority: 6) // Function definitions
            .addFunctionCalls()
            .addOperators(pattern: #"[+\-*/%=<>!&|^~]+"#)
            .build(name: "Python", fileExtensions: ["py", "pyw"])
    }

    private static func createCDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            // Comments
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),

            // Preprocessor
            rule(#"#\w+.*$"#, .preprocessor, 10),

            // Strings
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),

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

        return LanguageDefinition(name: "C", fileExtensions: ["c", "h"], rules: rules)
    }

    private static func createCppDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            // Comments
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),

            // Preprocessor
            rule(#"#\w+.*$"#, .preprocessor, 10),

            // Strings
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),

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

        return LanguageDefinition(name: "C++", fileExtensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx"], rules: rules)
    }

    // Additional language definitions would continue here...
    // For brevity, I'm including just a few representative examples

    private static func createJavaDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"\b\d+\.?\d*[fFlLdD]?\b"#, .number, 8),
            rule(
                #"\b(abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|void|volatile|while)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "Java", fileExtensions: ["java"], rules: rules)
    }

    private static func createRustDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(as|break|const|continue|crate|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while|async|await|dyn)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "Rust", fileExtensions: ["rs"], rules: rules)
    }

    private static func createGoDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"`[^`]*`"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "Go", fileExtensions: ["go"], rules: rules)
    }

    private static func createRubyDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"#.*$"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(alias|and|begin|break|case|class|def|defined|do|else|elsif|end|ensure|false|for|if|in|module|next|nil|not|or|redo|rescue|retry|return|self|super|then|true|undef|unless|until|when|while|yield)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "Ruby", fileExtensions: ["rb", "rbw"], rules: rules)
    }

    private static func createPHPDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#"#.*$"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(
                #"\b(abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|die|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|namespace|new|or|print|private|protected|public|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield)\b"#,
                .keyword,
                7
            ),
            rule(#"\b\w+(?=\s*\()"#, .function, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "PHP", fileExtensions: ["php", "phtml", "php3", "php4", "php5"], rules: rules)
    }

    private static func createCSSDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"#[a-fA-F0-9]{3,6}\b"#, .number, 8),
            rule(
                #"\b\d+\.?\d*(px|em|rem|%|vh|vw|pt|pc|in|cm|mm|ex|ch|vmin|vmax|deg|rad|grad|turn|s|ms|Hz|kHz|dpi|dpcm|dppx)?\b"#,
                .number,
                8
            ),
            rule(#"[.#]?[a-zA-Z_][\w-]*(?=\s*\{)"#, .type, 7),
            rule(#"[a-zA-Z-]+(?=\s*:)"#, .property, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "CSS", fileExtensions: ["css", "scss", "sass", "less"], rules: rules)
    }

    private static func createHTMLDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"<!--[\s\S]*?-->"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>"#, .keyword, 8),
            rule(#"\b[a-zA-Z-]+(?==)"#, .property, 7)
        ].compactMap(\.self)

        return LanguageDefinition(name: "HTML", fileExtensions: ["html", "htm", "xhtml"], rules: rules)
    }

    private static func createJSONDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(#"\b(true|false|null)\b"#, .keyword, 7),
            rule(#"[{}\[\],:]"#, .punctuation, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "JSON", fileExtensions: ["json", "jsonc"], rules: rules)
    }

    private static func createMarkdownDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"^#{1,6}\s+.*$"#, .keyword, 10),
            rule(#"`[^`]*`"#, .string, 9),
            rule(#"```[\s\S]*?```"#, .string, 9),
            rule(#"\*\*[^*]+\*\*"#, .keyword, 8),
            rule(#"__[^_]+__"#, .keyword, 8),
            rule(#"\*[^*]+\*"#, .type, 7),
            rule(#"_[^_]+_"#, .type, 7),
            rule(#"\[([^\]]+)\]\([^)]+\)"#, .function, 6)
        ].compactMap(\.self)

        return LanguageDefinition(name: "Markdown", fileExtensions: ["md", "markdown", "mdown", "mkd"], rules: rules)
    }
    
    private static func createYAMLDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"#.*$"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"\b\d+\.?\d*\b"#, .number, 8),
            rule(#"\b(true|false|null|yes|no|on|off)\b"#, .keyword, 7),
            rule(#"^[a-zA-Z_][\w\-]*(?=\s*:)"#, .property, 6),
            rule(#"[:\-\[\]{}]"#, .punctuation, 5)
        ].compactMap(\.self)

        return LanguageDefinition(name: "YAML", fileExtensions: ["yaml", "yml"], rules: rules)
    }
    
    private static func createXMLDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            rule(#"<!--[\s\S]*?-->"#, .comment, 10),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"<\?[\s\S]*?\?>"#, .preprocessor, 8),
            rule(#"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>"#, .keyword, 8),
            rule(#"\b[a-zA-Z-]+(?==)"#, .property, 7)
        ].compactMap(\.self)

        return LanguageDefinition(name: "XML", fileExtensions: ["xml", "xsl", "xslt", "svg"], rules: rules)
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
}

// Note: SyntaxHighlighter conformance is declared in LanguageRegistry.swift
