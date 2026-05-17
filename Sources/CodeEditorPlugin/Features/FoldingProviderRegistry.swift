import CodeEditorCommon
import Foundation

// MARK: - Folding Provider Registry

/// Registry for managing language-specific code folding providers
@MainActor
internal final class FoldingProviderRegistry {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "FoldingProviderRegistry")

    // MARK: - Properties

    private var providers: [Language: CodeFoldingProvider] = [:]

    // MARK: - Initialization

    init() {
        setupDefaultProviders()
    }

    // MARK: - Public Methods

    /// Register a folding provider for a language
    internal func registerProvider(_ provider: CodeFoldingProvider, for language: Language) {
        providers[language] = provider
        logger.info("Registered folding provider for \(language.name)")
    }

    /// Get provider for a specific language
    internal func provider(for language: Language) -> CodeFoldingProvider? {
        providers[language]
    }

    /// Check if a provider exists for a language
    internal func hasProvider(for language: Language) -> Bool {
        providers[language] != nil
    }

    /// Remove provider for a language
    internal func removeProvider(for language: Language) {
        providers.removeValue(forKey: language)
        logger.info("Removed folding provider for \(language.name)")
    }

    /// Get all registered languages
    internal var registeredLanguages: [Language] {
        Array(providers.keys)
    }

    // MARK: - Private Methods

    private func setupDefaultProviders() {
        // Register default providers for brace-based languages
        let braceProvider = BraceFoldingProvider()
        registerProvider(braceProvider, for: .swift)
        registerProvider(braceProvider, for: .javascript)
        registerProvider(braceProvider, for: .typescript)
        registerProvider(braceProvider, for: .c)
        registerProvider(braceProvider, for: .cpp)
        registerProvider(braceProvider, for: .java)
        registerProvider(braceProvider, for: .go)
        registerProvider(braceProvider, for: .rust)
        registerProvider(braceProvider, for: .css)
        registerProvider(braceProvider, for: .json)
        registerProvider(braceProvider, for: .php)

        // Delegating providers wire newly added brace-style languages into
        // the folding pipeline via `HeuristicFoldProvider`, which forwards
        // to `BraceFoldingProvider` for these cases.
        registerProvider(HeuristicFoldProvider(language: .csharp), for: .csharp)
        registerProvider(HeuristicFoldProvider(language: .kotlin), for: .kotlin)
        registerProvider(HeuristicFoldProvider(language: .dart), for: .dart)

        // Dedicated providers for languages whose folding doesn't fit the
        // brace/indent shape.
        registerProvider(DockerfileFoldingProvider(), for: .dockerfile)
        registerProvider(TomlFoldingProvider(), for: .toml)
        registerProvider(LuaFoldingProvider(), for: .lua)

        // Python and YAML use indentation-based folding
        let indentationProvider = IndentationFoldingProvider()
        registerProvider(indentationProvider, for: .python)
        registerProvider(indentationProvider, for: .yaml)

        // Markdown section folding
        registerProvider(MarkdownFoldingProvider(), for: .markdown)

        // XML/HTML tag folding
        let xmlProvider = XMLFoldingProvider()
        registerProvider(xmlProvider, for: .xml)
        registerProvider(xmlProvider, for: .html)

        // Specialized language providers
        registerProvider(ShellFoldingProvider(), for: .shell)
        registerProvider(SQLFoldingProvider(), for: .sql)
        registerProvider(RubyFoldingProvider(), for: .ruby)
    }
}
