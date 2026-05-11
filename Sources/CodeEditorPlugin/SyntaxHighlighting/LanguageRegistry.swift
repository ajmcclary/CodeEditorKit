import Foundation

// MARK: - LanguageProvider

/// Protocol for providing language-specific functionality
@MainActor
public protocol LanguageProvider: Sendable {
    /// Unique identifier for the language
    var identifier: String { get }

    /// Display name for the language
    var displayName: String { get }

    /// File extensions associated with this language
    var fileExtensions: [String] { get }

    /// Create a syntax highlighter for this language
    @MainActor
    func createHighlighter() -> any SyntaxHighlighter

    /// Optional: Provide code completion items
    nonisolated func completionKeywords() -> [String]

    /// Optional: Provide documentation URL
    nonisolated var documentationURL: URL? { get }
}

// Default implementations
extension LanguageProvider {
    nonisolated func completionKeywords() -> [String] { [] }

    nonisolated var documentationURL: URL? { nil }
}

// MARK: - SyntaxHighlighter Protocol

/// Protocol for syntax highlighters
@MainActor
public protocol SyntaxHighlighter {
    /// Highlight the given source code.
    ///
    /// Returned `HighlightedToken.range` values must be UTF-16 `NSRange`
    /// offsets relative to the provided `source`, matching `NSTextStorage`
    /// and the rest of TextKit.
    func highlight(source: String) -> [HighlightedToken]

    /// Check if incremental highlighting is supported
    var supportsIncrementalHighlighting: Bool { get }

    /// Perform incremental highlighting (optional)
    func highlightIncremental(source: String, changeRange: NSRange) -> [HighlightedToken]
}

// Default implementation
extension SyntaxHighlighter {
    /// Whether the highlighter supports incremental highlighting
    public var supportsIncrementalHighlighting: Bool { false }

    /// Perform incremental highlighting for a changed range
    ///
    /// - Parameters:
    ///   - source: The complete source text
    ///   - changeRange: The range that changed in the source
    /// - Returns: Array of highlighted tokens for the changed range
    public func highlightIncremental(source: String, changeRange _: NSRange) -> [HighlightedToken] {
        // Fall back to full highlighting
        highlight(source: source)
    }
}

// MARK: - LanguageRegistry

/// Registry for managing language providers
@MainActor
public final class LanguageRegistry {
    // MARK: - Properties

    private var providers: [String: any LanguageProvider] = [:]
    private var extensionMap: [String: String] = [:] // extension -> identifier

    // MARK: - Initialization

    /// Creates a new language registry instance.
    /// - Parameter includeBuiltInLanguages: Whether to automatically register built-in languages (default: true)
    public init(includeBuiltInLanguages: Bool = true) {
        if includeBuiltInLanguages {
            registerBuiltInLanguages()
        }
    }

    // MARK: - Registration

    /// Register a language provider
    public func register(_ provider: any LanguageProvider) {
        providers[provider.identifier] = provider

        // Update extension map
        for ext in provider.fileExtensions {
            extensionMap[ext.lowercased()] = provider.identifier
        }
    }

    /// Unregister a language provider
    public func unregister(identifier: String) {
        guard let provider = providers[identifier] else { return }

        // Remove from providers
        providers.removeValue(forKey: identifier)

        // Remove from extension map
        for ext in provider.fileExtensions {
            extensionMap.removeValue(forKey: ext.lowercased())
        }
    }

    // MARK: - Lookup

    /// Get language provider by identifier
    public func provider(for identifier: String) -> (any LanguageProvider)? {
        providers[identifier]
    }

    /// Get language provider by file extension
    public func provider(forFileExtension fileExtension: String) -> (any LanguageProvider)? {
        guard let identifier = extensionMap[fileExtension.lowercased()] else { return nil }
        return providers[identifier]
    }

    /// Get all registered languages
    public var allLanguages: [any LanguageProvider] {
        Array(providers.values).sorted { $0.displayName < $1.displayName }
    }

    /// Get all supported file extensions
    public var allFileExtensions: [String] {
        Array(extensionMap.keys).sorted()
    }

    // MARK: - Built-in Languages

    private func registerBuiltInLanguages() {
        for language in Language.allCases {
            guard let descriptor = LanguageDescriptor.descriptor(for: language) else { continue }
            register(DescriptorLanguageProvider(descriptor: descriptor))
        }
    }
}

// MARK: - Built-in Language Providers

/// Descriptor-backed provider for the canonical built-in language catalog.
struct DescriptorLanguageProvider: LanguageProvider {
    let descriptor: LanguageDescriptor

    var identifier: String {
        descriptor.language.identifier
    }

    var displayName: String {
        descriptor.displayName
    }

    var fileExtensions: [String] {
        descriptor.fileExtensions
    }

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        switch descriptor.language {
        case .swift:
            return SwiftSyntaxHighlighter()

        case .plainText:
            return PlainTextHighlighter()

        default:
            let regexHighlighter = RegexSyntaxHighlighter()
            if let definition = regexHighlighter.languageDefinition(for: descriptor.language) {
                return RegexSyntaxHighlighter(customLanguage: definition)
            }
            return PlainTextHighlighter()
        }
    }

    nonisolated func completionKeywords() -> [String] {
        descriptor.keywords
    }
}

/// Swift language provider
struct SwiftLanguageProvider: LanguageProvider {
    let identifier = "swift"
    let displayName = "Swift"
    let fileExtensions = ["swift"]

    var documentationURL: URL? {
        URL(string: "https://docs.swift.org/swift-book/")
    }

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        #if true
        return SwiftSyntaxHighlighter()
        #endif
    }

    func completionKeywords() -> [String] {
        ["func", "var", "let", "class", "struct", "enum", "protocol", "import", "if", "else", "for", "while", "return"]
    }
}

/// Python language provider
struct PythonLanguageProvider: LanguageProvider {
    let identifier = "python"
    let displayName = "Python"
    let fileExtensions = ["py", "pyw"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("#.*$", .comment, 10),
            RegexSyntaxHighlighter.rule("\"\"\"[\\s\\S]*?\"\"\"", .string, 9),
            RegexSyntaxHighlighter.rule("'''[\\s\\S]*?'''", .string, 9),
            RegexSyntaxHighlighter.rule("\"(?:[^\"\\\\]|\\\\.)*\"", .string, 8),
            RegexSyntaxHighlighter.rule("'(?:[^'\\\\]|\\\\.)*'", .string, 8),
            RegexSyntaxHighlighter.rule("\\b\\d+\\.?\\d*\\b", .number, 7),
            RegexSyntaxHighlighter.rule("\\b(def|class|if|elif|else|for|while|try|except|finally|with|as|import|from|return|yield|break|continue|pass|global|nonlocal|lambda|and|or|not|in|is|True|False|None)\\b", .keyword, 6)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// JavaScript language provider
struct JavaScriptLanguageProvider: LanguageProvider {
    let identifier = "javascript"
    let displayName = "JavaScript"
    let fileExtensions = ["js", "jsx", "mjs"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("//.*$", .comment, 10),
            RegexSyntaxHighlighter.rule("/\\*[\\s\\S]*?\\*/", .comment, 10),
            RegexSyntaxHighlighter.rule("\"(?:[^\"\\\\]|\\\\.)*\"", .string, 9),
            RegexSyntaxHighlighter.rule("'(?:[^'\\\\]|\\\\.)*'", .string, 9),
            RegexSyntaxHighlighter.rule("`(?:[^`\\\\]|\\\\.)*`", .string, 9),
            RegexSyntaxHighlighter.rule("\\b\\d+\\.?\\d*\\b", .number, 8),
            RegexSyntaxHighlighter.rule("\\b(const|let|var|function|class|if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|async|await|import|export|from|as|typeof|instanceof|new|this|super)\\b", .keyword, 7)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// JSON language provider
struct JSONLanguageProvider: LanguageProvider {
    let identifier = "json"
    let displayName = "JSON"
    let fileExtensions = ["json", "jsonc"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("\"(?:[^\"\\\\]|\\\\.)*\"", .string, 9),
            RegexSyntaxHighlighter.rule("\\b-?\\d+\\.?\\d*([eE][+-]?\\d+)?\\b", .number, 8),
            RegexSyntaxHighlighter.rule("\\b(true|false|null)\\b", .keyword, 7),
            RegexSyntaxHighlighter.rule("[{}\\[\\],:]", .punctuation, 6)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// HTML language provider
struct HTMLLanguageProvider: LanguageProvider {
    let identifier = "html"
    let displayName = "HTML"
    let fileExtensions = ["html", "htm", "xhtml"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("<!--[\\s\\S]*?-->", .comment, 10),
            RegexSyntaxHighlighter.rule("</?\\w+", .keyword, 8),
            RegexSyntaxHighlighter.rule("\\w+(?==)", .property, 7),
            RegexSyntaxHighlighter.rule("\"[^\"]*\"", .string, 6),
            RegexSyntaxHighlighter.rule("'[^']*'", .string, 6)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// CSS language provider
struct CSSLanguageProvider: LanguageProvider {
    let identifier = "css"
    let displayName = "CSS"
    let fileExtensions = ["css", "scss", "sass", "less"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("/\\*[\\s\\S]*?\\*/", .comment, 10),
            RegexSyntaxHighlighter.rule("//.*$", .comment, 10),
            RegexSyntaxHighlighter.rule("[.#]?[a-zA-Z][\\w-]*(?=\\s*\\{)", .type, 8),
            RegexSyntaxHighlighter.rule("[a-zA-Z-]+(?=\\s*:)", .property, 7),
            RegexSyntaxHighlighter.rule("\"[^\"]*\"", .string, 6),
            RegexSyntaxHighlighter.rule("'[^']*'", .string, 6),
            RegexSyntaxHighlighter.rule("\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw)?\\b", .number, 5)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// Markdown language provider
struct MarkdownLanguageProvider: LanguageProvider {
    let identifier = "markdown"
    let displayName = "Markdown"
    let fileExtensions = ["md", "markdown", "mdown"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("^#{1,6}\\s.*$", .keyword, 10),
            RegexSyntaxHighlighter.rule("\\*\\*[^*]+\\*\\*", .keyword, 8),
            RegexSyntaxHighlighter.rule("__[^_]+__", .keyword, 8),
            RegexSyntaxHighlighter.rule("\\*[^*]+\\*", .property, 7),
            RegexSyntaxHighlighter.rule("_[^_]+_", .property, 7),
            RegexSyntaxHighlighter.rule("`[^`]+`", .string, 9),
            RegexSyntaxHighlighter.rule("```[\\s\\S]*?```", .string, 10),
            RegexSyntaxHighlighter.rule("\\[[^\\]]+\\]\\([^)]+\\)", .function, 6)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// XML language provider
struct XMLLanguageProvider: LanguageProvider {
    let identifier = "xml"
    let displayName = "XML"
    let fileExtensions = ["xml", "xsl", "xslt", "svg"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("<!--[\\s\\S]*?-->", .comment, 10),
            RegexSyntaxHighlighter.rule("</?\\w+", .keyword, 8),
            RegexSyntaxHighlighter.rule("\\w+(?==)", .property, 7),
            RegexSyntaxHighlighter.rule("\"[^\"]*\"", .string, 6),
            RegexSyntaxHighlighter.rule("'[^']*'", .string, 6)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// YAML language provider
struct YAMLLanguageProvider: LanguageProvider {
    let identifier = "yaml"
    let displayName = "YAML"
    let fileExtensions = ["yaml", "yml"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        let rules: [RegexSyntaxHighlighter.HighlightRule] = [
            RegexSyntaxHighlighter.rule("#.*$", .comment, 10),
            RegexSyntaxHighlighter.rule("^\\s*[\\w-]+(?=:)", .property, 8),
            RegexSyntaxHighlighter.rule("\"[^\"]*\"", .string, 7),
            RegexSyntaxHighlighter.rule("'[^']*'", .string, 7),
            RegexSyntaxHighlighter.rule("\\b(true|false|null|yes|no|on|off)\\b", .keyword, 6),
            RegexSyntaxHighlighter.rule("\\b\\d+\\.?\\d*\\b", .number, 5)
        ].compactMap { $0 }

        let definition = RegexSyntaxHighlighter.LanguageDefinition(
            name: displayName,
            fileExtensions: fileExtensions,
            rules: rules
        )

        return RegexSyntaxHighlighter(customLanguage: definition)
    }
}

/// Plain text language provider
struct PlainTextLanguageProvider: LanguageProvider {
    let identifier = "plaintext"
    let displayName = "Plain Text"
    let fileExtensions = ["txt", "text", "log"]

    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        // Return a no-op highlighter for plain text
        PlainTextHighlighter()
    }
}

/// No-op highlighter for plain text
struct PlainTextHighlighter: SyntaxHighlighter {
    func highlight(source _: String) -> [HighlightedToken] {
        [] // No highlighting for plain text
    }
}

// MARK: - RegexSyntaxHighlighter Extension

extension RegexSyntaxHighlighter: SyntaxHighlighter {
    public convenience init(customLanguage language: LanguageDefinition) {
        self.init(defaultLanguage: language)
    }

    public func highlight(source: String) -> [HighlightedToken] {
        guard let language = defaultLanguage else {
            // No language defined — return empty (plain text, no tokens).
            return []
        }
        return highlight(source: source, language: language)
    }
}

// MARK: - SwiftSyntaxHighlighter Extension

extension SwiftSyntaxHighlighter: SyntaxHighlighter {
    // SwiftSyntaxHighlighter already has the correct highlight(source:) method signature
    // so it automatically conforms to SyntaxHighlighter
}
