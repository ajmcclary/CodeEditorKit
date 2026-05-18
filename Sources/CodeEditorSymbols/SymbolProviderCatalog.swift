import CodeEditorLanguages
import CodeEditorSyntaxHighlighting
import Foundation

/// Catalog of document-symbol providers keyed by language.
public struct SymbolProviderCatalog: Sendable {
    private var providers: [Language: any DocumentSymbolProvider]

    public init(providers: [Language: any DocumentSymbolProvider] = [:]) {
        self.providers = providers
    }

    public static var `default`: Self {
        var catalog = Self()
        catalog.registerDefaultProviders()
        return catalog
    }

    public func provider(for language: Language) -> (any DocumentSymbolProvider)? {
        providers[language]
    }

    public func hasProvider(for language: Language) -> Bool {
        providers[language] != nil
    }

    public mutating func registerProvider(_ provider: any DocumentSymbolProvider, for language: Language) {
        providers[language] = provider
    }

    private mutating func registerDefaultProviders() {
        registerProvider(SwiftSymbolProvider(), for: .swift)
        registerProvider(JavaScriptSymbolProvider(), for: .javascript)
        registerProvider(JavaScriptSymbolProvider(), for: .typescript)

        let cStyleProvider = CStyleSymbolProvider()
        for language in [Language.c, .cpp, .java, .go, .rust, .csharp, .kotlin, .dart] {
            registerProvider(cStyleProvider, for: language)
        }

        registerProvider(PythonSymbolProvider(), for: .python)
        registerProvider(MarkdownSymbolProvider(), for: .markdown)
        registerProvider(HTMLSymbolProvider(), for: .html)
        registerProvider(CSSSymbolProvider(), for: .css)
        registerProvider(JSONSymbolProvider(), for: .json)
        registerProvider(YAMLSymbolProvider(), for: .yaml)
        registerProvider(XMLSymbolProvider(), for: .xml)
        registerProvider(SQLSymbolProvider(), for: .sql)
        registerProvider(RubySymbolProvider(), for: .ruby)
        registerProvider(PHPSymbolProvider(), for: .php)
        registerProvider(ShellSymbolProvider(), for: .shell)

        registerProvider(HeuristicSymbolProviderFacade(language: .dockerfile), for: .dockerfile)
        registerProvider(HeuristicSymbolProviderFacade(language: .toml), for: .toml)
        registerProvider(HeuristicSymbolProviderFacade(language: .lua), for: .lua)
        registerProvider(EmptySymbolProvider(), for: .plainText)
    }
}

private struct EmptySymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in _: String) async -> [DocumentSymbol] {
        []
    }
}
