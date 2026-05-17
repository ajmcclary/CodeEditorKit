import CodeEditorLanguages
import Foundation

// MARK: - Heuristic Folding Provider

/// Delegating code folding provider for languages without a dedicated provider.
@MainActor
internal final class HeuristicFoldProvider: CodeFoldingProvider {
    private let language: Language

    init(language: Language) {
        self.language = language
    }

    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
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
