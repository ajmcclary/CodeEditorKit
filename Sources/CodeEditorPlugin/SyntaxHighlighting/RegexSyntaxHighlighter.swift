import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// Use centralized platform color type
public typealias RegexHighlighterColor = PlatformColor

// MARK: - RegexSyntaxHighlighter

/// A pure Swift regex-based syntax highlighter for various programming languages
@MainActor
public final class RegexSyntaxHighlighter: @unchecked Sendable {
    // MARK: - Language Definitions

    public struct LanguageDefinition: Sendable {
        public let name: String
        public let fileExtensions: [String]
        public let rules: [HighlightRule]

        public init(name: String, fileExtensions: [String], rules: [HighlightRule]) {
            self.name = name
            self.fileExtensions = fileExtensions
            self.rules = rules
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

    let supportedLanguagesMap: [String: LanguageDefinition]

    // MARK: - Initialization

    public init() {
        supportedLanguagesMap = Self.createLanguageDefinitions()
    }

    // MARK: - Public Methods

    /// Get language definition by file extension
    public func languageDefinition(for fileExtension: String) -> LanguageDefinition? {
        supportedLanguagesMap.values.first { language in
            language.fileExtensions.contains(fileExtension.lowercased())
        }
    }

    /// Highlight source code using the specified language definition
    public func highlight(source: String, language: LanguageDefinition) -> [HighlightedToken] {
        guard !source.isEmpty else {
            return []
        }

        var tokens: [HighlightedToken] = []
        let range = NSRange(location: 0, length: source.utf16.count)

        // Sort rules by priority (higher priority first)
        let sortedRules = language.rules.sorted { $0.priority > $1.priority }

        var processedRanges: [NSRange] = []

        for rule in sortedRules {
            let matches = rule.pattern.matches(in: source, options: [], range: range)

            for match in matches {
                let matchRange = match.range

                // Skip if this range overlaps with already processed ranges
                if processedRanges.contains(where: { NSIntersectionRange($0, matchRange).length > 0 }) {
                    continue
                }

                let text = String(source[Range(matchRange, in: source)!])
                // Convert RegexSyntaxHighlighter.TokenType to SyntaxHighlightingCoordinator.TokenType
                // Convert from RegexTokenType to the global TokenType used by HighlightedToken
                let coordinatorTokenType: TokenType = {
                    switch rule.tokenType {
                    case .keyword: return .keyword
                    case .identifier: return .identifier
                    case .string: return .string
                    case .number: return .number
                    case .comment: return .comment
                    case .type: return .type
                    case .function: return .function
                    case .property: return .property
                    case .operator: return .operator
                    case .punctuation: return .punctuation
                    case .whitespace: return .whitespace
                    case .preprocessor: return .preprocessor
                    case .unknown: return .unknown
                    }
                }()
                tokens.append(HighlightedToken(range: matchRange, type: coordinatorTokenType, text: text))
                processedRanges.append(matchRange)
            }
        }

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    /// Apply highlighting to an attributed string
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

        return languages
    }

    private static func createJavaScriptDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            // Comments
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),

            // Strings
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"`(?:[^`\\]|\\.)*`"#, .string, 9),

            // Numbers
            rule(#"\b\d+\.?\d*\b"#, .number, 8),

            // Keywords
            rule(
                #"\b(const|let|var|function|class|if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|async|await|import|export|from|as|typeof|instanceof)\b"#,
                .keyword,
                7
            ),

            // Function calls
            rule(#"\b\w+(?=\s*\()"#, .function, 6),

            // Operators
            rule(#"[+\-*/%=<>!&|^~?:]+"#, .operator, 5)
        ].compactMap(\.self)

        return LanguageDefinition(name: "JavaScript", fileExtensions: ["js", "jsx", "mjs"], rules: rules)
    }

    private static func createTypeScriptDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            // Comments
            rule(#"//.*$"#, .comment, 10),
            rule(#"/\*[\s\S]*?\*/"#, .comment, 10),

            // Strings
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),
            rule(#"`(?:[^`\\]|\\.)*`"#, .string, 9),

            // Numbers
            rule(#"\b\d+\.?\d*\b"#, .number, 8),

            // Keywords (includes TypeScript-specific)
            rule(
                #"\b(const|let|var|function|class|interface|type|enum|namespace|if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|async|await|import|export|from|as|typeof|instanceof|public|private|protected|readonly|static)\b"#,
                .keyword,
                7
            ),

            // Types
            rule(
                #"\b(string|number|boolean|object|any|void|never|unknown)\b"#,
                .type,
                7
            ),

            // Function calls
            rule(#"\b\w+(?=\s*\()"#, .function, 6),

            // Operators
            rule(#"[+\-*/%=<>!&|^~?:]+"#, .operator, 5)
        ].compactMap(\.self)

        return LanguageDefinition(name: "TypeScript", fileExtensions: ["ts", "tsx"], rules: rules)
    }

    private static func createPythonDefinition() -> LanguageDefinition {
        let rules: [HighlightRule] = [
            // Comments
            rule(#"#.*$"#, .comment, 10),

            // Strings
            rule(#""""[\s\S]*?""""#, .string, 9),
            rule(#"'''[\s\S]*?'''"#, .string, 9),
            rule(#""(?:[^"\\]|\\.)*""#, .string, 9),
            rule(#"'(?:[^'\\]|\\.)*'"#, .string, 9),

            // Numbers
            rule(#"\b\d+\.?\d*\b"#, .number, 8),

            // Keywords
            rule(
                #"\b(def|class|if|elif|else|for|while|try|except|finally|with|as|import|from|return|yield|break|continue|pass|global|nonlocal|lambda|and|or|not|in|is|True|False|None)\b"#,
                .keyword,
                7
            ),

            // Function definitions
            rule(#"\bdef\s+(\w+)"#, .function, 6),

            // Function calls
            rule(#"\b\w+(?=\s*\()"#, .function, 6),

            // Operators
            rule(#"[+\-*/%=<>!&|^~]+"#, .operator, 5)
        ].compactMap(\.self)

        return LanguageDefinition(name: "Python", fileExtensions: ["py", "pyw"], rules: rules)
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
}

// Note: SyntaxHighlighter conformance is declared in LanguageRegistry.swift
