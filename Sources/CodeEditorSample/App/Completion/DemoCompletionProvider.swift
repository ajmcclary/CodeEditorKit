import CodeEditorPlugin
import Foundation

/// Demonstrates the `CompletionProvider` protocol end-to-end *and* exercises
/// three otherwise-unused public completion utilities:
///
/// 1. `SnippetTemplate` — declaratively defines the items below.
/// 2. `CompletionProviderUtilities.fuzzyFilter` — narrows the snippet list
///    against `context.currentWord`.
/// 3. `CompletionRankingModel` — sorts the filtered items by relevance.
///
/// This is the type to copy from when writing your own provider — it shows
/// the minimum required to satisfy `CompletionProvider`:
///
/// 1. A unique `id`.
/// 2. `supportedLanguages: []` to apply to every buffer, or an explicit list.
/// 3. `triggerCharacters: []` for manual-only firing, or characters that
///    should auto-trigger.
/// 4. An async `completions(for:)` that returns `CompletionItemModel`s.
@MainActor
final class DemoCompletionProvider: CompletionProvider {
    let id = "sample.demo"
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = true

    /// Snippet catalog declared via the framework's `SnippetTemplate` value
    /// type. Hosts that ship their own snippets typically populate this from
    /// a JSON/YAML file or generate it from a language descriptor.
    private static let snippets: [SnippetTemplate] = [
        SnippetTemplate(label: "TODO:", insertText: "TODO: ", description: "Mark work to do"),
        SnippetTemplate(label: "MARK:", insertText: "MARK: ", description: "Source-navigator landmark"),
        SnippetTemplate(label: "FIXME:", insertText: "FIXME: ", description: "Mark a known bug"),
        SnippetTemplate(label: "NOTE:", insertText: "NOTE: ", description: "Inline annotation"),
        SnippetTemplate(label: "WARNING:", insertText: "WARNING: ", description: "Highlight a risk")
    ]

    private let rankingModel = CompletionRankingModel()

    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        // 1. Build items from the SnippetTemplate catalog.
        let items = Self.snippets.map { snippet in
            CompletionItemModel(
                label: snippet.label,
                insertText: snippet.insertText,
                kind: .snippet,
                detail: snippet.description
            )
        }

        // 2. Fuzzy-filter against the current word. When the user hasn't
        // typed anything yet, `fuzzyFilter` returns the full list.
        let filtered = CompletionProviderUtilities.fuzzyFilter(
            items: items,
            filter: context.currentWord,
            keyPath: \.label
        )

        // 3. Rank the filtered list with the framework's ranking model. The
        // sample doesn't track frequency data, so the dictionary is empty;
        // the model still applies prefix and recency heuristics.
        let ranked = rankingModel.rank(
            items: filtered,
            context: context,
            frequencyData: [:]
        )

        return CompletionResult(items: ranked, context: context)
    }
}
