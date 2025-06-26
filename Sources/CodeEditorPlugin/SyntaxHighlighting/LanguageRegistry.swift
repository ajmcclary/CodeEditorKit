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
public extension LanguageProvider {
    nonisolated func completionKeywords() -> [String] { [] }
    nonisolated var documentationURL: URL? { nil }
}

// MARK: - SyntaxHighlighter Protocol

/// Protocol for syntax highlighters
@MainActor
public protocol SyntaxHighlighter {
    /// Highlight the given source code
    func highlight(source: String) -> [HighlightedToken]
    
    /// Check if incremental highlighting is supported
    var supportsIncrementalHighlighting: Bool { get }
    
    /// Perform incremental highlighting (optional)
    func highlightIncremental(source: String, changeRange: NSRange) -> [HighlightedToken]
}

// Default implementation
public extension SyntaxHighlighter {
    var supportsIncrementalHighlighting: Bool { false }
    
    func highlightIncremental(source: String, changeRange _: NSRange) -> [HighlightedToken] {
        // Fall back to full highlighting
        highlight(source: source)
    }
}

// MARK: - LanguageRegistry

/// Registry for managing language providers
@MainActor
public final class LanguageRegistry {
    // MARK: - Singleton
    
    public static let shared = LanguageRegistry()
    
    // MARK: - Properties
    
    private var providers: [String: any LanguageProvider] = [:]
    private var extensionMap: [String: String] = [:] // extension -> identifier
    
    // MARK: - Initialization
    
    private init() {
        registerBuiltInLanguages()
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
    public func provider(forFileExtension extension: String) -> (any LanguageProvider)? {
        guard let identifier = extensionMap[`extension`.lowercased()] else { return nil }
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
        // Register Swift
        register(SwiftLanguageProvider())
        
        // Register other built-in languages
        register(PythonLanguageProvider())
        register(JavaScriptLanguageProvider())
        register(JSONLanguageProvider())
        register(HTMLLanguageProvider())
        register(CSSLanguageProvider())
        register(MarkdownLanguageProvider())
        register(XMLLanguageProvider())
        register(YAMLLanguageProvider())
        register(PlainTextLanguageProvider())
    }
}

// MARK: - Built-in Language Providers

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
        SwiftSyntaxHighlighter()
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "#.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(def|class|if|elif|else|for|while|try|except|finally|with|as|import|from|return|yield|break|continue|pass|global|nonlocal|lambda|and|or|not|in|is|True|False|None)\\b", tokenType: .keyword, priority: 6)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "//.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "`(?:[^`\\\\]|\\\\.)*`", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(const|let|var|function|class|if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|async|await|import|export|from|as|typeof|instanceof|new|this|super)\\b", tokenType: .keyword, priority: 7)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b-?\\d+\\.?\\d*([eE][+-]?\\d+)?\\b", tokenType: .number, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(true|false|null)\\b", tokenType: .keyword, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "[{}\\[\\],:]", tokenType: .punctuation, priority: 6)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "</?\\w+", tokenType: .keyword, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\w+(?==)", tokenType: .property, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"[^\"]*\"", tokenType: .string, priority: 6),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'[^']*'", tokenType: .string, priority: 6)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "/\\*[\\s\\S]*?\\*/", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "//.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "[.#]?[a-zA-Z][\\w-]*(?=\\s*\\{)", tokenType: .type, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "[a-zA-Z-]+(?=\\s*:)", tokenType: .property, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"[^\"]*\"", tokenType: .string, priority: 6),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'[^']*'", tokenType: .string, priority: 6),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw)?\\b", tokenType: .number, priority: 5)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "^#{1,6}\\s.*$", tokenType: .keyword, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\*\\*[^*]+\\*\\*", tokenType: .keyword, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "__[^_]+__", tokenType: .keyword, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\*[^*]+\\*", tokenType: .property, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "_[^_]+_", tokenType: .property, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "`[^`]+`", tokenType: .string, priority: 9),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "```[\\s\\S]*?```", tokenType: .string, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\[[^\\]]+\\]\\([^)]+\\)", tokenType: .function, priority: 6)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "</?\\w+", tokenType: .keyword, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\w+(?==)", tokenType: .property, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"[^\"]*\"", tokenType: .string, priority: 6),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'[^']*'", tokenType: .string, priority: 6)
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
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "#.*$", tokenType: .comment, priority: 10),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "^\\s*[\\w-]+(?=:)", tokenType: .property, priority: 8),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\"[^\"]*\"", tokenType: .string, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "'[^']*'", tokenType: .string, priority: 7),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b(true|false|null|yes|no|on|off)\\b", tokenType: .keyword, priority: 6),
            try? RegexSyntaxHighlighter.HighlightRule(pattern: "\\b\\d+\\.?\\d*\\b", tokenType: .number, priority: 5)
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
    public convenience init(customLanguage _: LanguageDefinition) {
        self.init()
        // The existing RegexSyntaxHighlighter will handle the language definition
    }
    
    public func highlight(source: String) -> [HighlightedToken] {
        // Use Swift language definition as default
        // Create a basic language definition for plain text highlighting
        let plainTextRules: [HighlightRule] = []
        let plainTextDef = LanguageDefinition(name: "Plain", fileExtensions: [], rules: plainTextRules)
        return highlight(source: source, language: plainTextDef)
    }
}

// MARK: - SwiftSyntaxHighlighter Extension

extension SwiftSyntaxHighlighter: SyntaxHighlighter {
    // SwiftSyntaxHighlighter already has the correct highlight(source:) method signature
    // so it automatically conforms to SyntaxHighlighter
}
