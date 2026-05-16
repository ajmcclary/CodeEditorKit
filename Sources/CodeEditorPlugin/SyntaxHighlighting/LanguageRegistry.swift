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
            let normalizedExtension = ext.lowercased()
            if extensionMap[normalizedExtension] == nil {
                extensionMap[normalizedExtension] = provider.identifier
            }
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

// MARK: - Plain Text Highlighter

/// No-op highlighter used by `DescriptorLanguageProvider` for plain text.
struct PlainTextHighlighter: SyntaxHighlighter {
    func highlight(source _: String) -> [HighlightedToken] {
        []
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
