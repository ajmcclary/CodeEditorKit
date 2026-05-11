import Foundation

// MARK: - Tree-sitter Folding Provider

/// Tree-sitter-backed code folding provider.
///
/// Phase 6c architecture: conforms to `CodeFoldingProvider` so it can be
/// registered in `FoldingProviderRegistry` alongside heuristic providers.
/// Currently delegates to the heuristic `BraceFoldingProvider` for brace-based
/// languages and `IndentationFoldingProvider` for indentation-based languages.
/// Switches to `folds.scm` queries when the real C Tree-sitter parser is
/// integrated in Phase 6+.
@MainActor
internal final class TreeSitterFoldProvider: CodeFoldingProvider {
    private let language: Language

    init(language: Language) {
        self.language = language
    }

    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        // Delegate to the appropriate heuristic provider for the spike.
        // Real implementation uses `folds.scm` queries on the parse tree.
        switch language {
        case .swift, .javascript, .typescript, .c, .cpp, .java, .go, .rust,
             .csharp, .kotlin, .dart, .css, .json, .php:
            return await BraceFoldingProvider().detectFoldableRegions(in: text)

        case .python, .yaml:
            return await IndentationFoldingProvider().detectFoldableRegions(in: text)

        case .html, .xml:
            return await XMLFoldingProvider().detectFoldableRegions(in: text)

        case .markdown:
            return await MarkdownFoldingProvider().detectFoldableRegions(in: text)

        case .ruby:
            return await RubyFoldingProvider().detectFoldableRegions(in: text)

        case .shell:
            return await ShellFoldingProvider().detectFoldableRegions(in: text)

        case .sql:
            return await SQLFoldingProvider().detectFoldableRegions(in: text)

        default:
            return []
        }
    }
}
