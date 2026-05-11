import Foundation

// MARK: - Tree-sitter Symbol Provider

/// Tree-sitter-backed document symbol provider.
///
/// Phase 6c architecture: conforms to `DocumentSymbolProvider` and `Sendable`
/// so it can be registered in `SymbolNavigator` alongside heuristic providers.
/// Currently delegates to the existing heuristic symbol providers for the spike.
/// Switches to `tags.scm` queries when the real C Tree-sitter parser is
/// integrated in Phase 6+.
internal struct TreeSitterSymbolProvider: DocumentSymbolProvider {
    private let language: Language

    init(language: Language) {
        self.language = language
    }

    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        // Delegate to the appropriate heuristic provider for the spike.
        // Real implementation uses `tags.scm` queries on the parse tree.
        switch language {
        case .swift:
            return await SwiftSymbolProvider().detectSymbols(in: text)

        case .javascript:
            return await JavaScriptSymbolProvider().detectSymbols(in: text)

        case .python:
            return await PythonSymbolProvider().detectSymbols(in: text)

        case .ruby:
            return await RubySymbolProvider().detectSymbols(in: text)

        case .php:
            return await PHPSymbolProvider().detectSymbols(in: text)

        case .html:
            return await HTMLSymbolProvider().detectSymbols(in: text)

        case .css:
            return await CSSSymbolProvider().detectSymbols(in: text)

        case .json:
            return await JSONSymbolProvider().detectSymbols(in: text)

        case .yaml:
            return await YAMLSymbolProvider().detectSymbols(in: text)

        case .xml:
            return await XMLSymbolProvider().detectSymbols(in: text)

        case .sql:
            return await SQLSymbolProvider().detectSymbols(in: text)

        case .shell:
            return await ShellSymbolProvider().detectSymbols(in: text)

        case .markdown:
            return await MarkdownSymbolProvider().detectSymbols(in: text)

        // C-style languages use the shared CStyleSymbolProvider
        case .c, .cpp, .java, .go, .rust, .typescript, .csharp, .kotlin, .dart:
            return await CStyleSymbolProvider().detectSymbols(in: text)

        default:
            return []
        }
    }
}
