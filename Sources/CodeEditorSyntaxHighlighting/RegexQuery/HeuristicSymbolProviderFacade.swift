import CodeEditorLanguages
import Foundation

// MARK: - Heuristic Symbol Provider Facade

/// Document symbol provider that delegates to the current language-specific
/// heuristic providers. This intentionally does not claim grammar-backed
/// parsing.
package struct HeuristicSymbolProviderFacade: DocumentSymbolProvider {
    private let language: Language

    package init(language: Language) {
        self.language = language
    }

    package func detectSymbols(in text: String) async -> [DocumentSymbol] {
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

        case .c, .cpp, .java, .go, .rust, .typescript, .csharp, .kotlin, .dart:
            return await CStyleSymbolProvider().detectSymbols(in: text)

        default:
            return []
        }
    }
}
