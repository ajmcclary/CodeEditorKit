#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// Demonstrates the `CompletionProvider` protocol end-to-end.
/// Returns three text-tag snippets (`TODO:`, `MARK:`, `FIXME:`) for every
/// manual completion request, regardless of language.
///
/// This is the type to copy from when writing your own provider — it shows
/// the minimum required to satisfy `CompletionProvider`:
///
/// 1. A unique `id`.
/// 2. `supportedLanguages: []` to apply to every buffer, or an explicit list.
/// 3. `triggerCharacters: []` for manual-only firing, or characters that
///    should auto-trigger.
/// 4. An async `completions(for:)` that returns `CompletionItemModel`s.
struct DemoCompletionProvider: CompletionProvider {
    let id = "sample.demo"
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = true

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let items: [CompletionItemModel] = [
            CompletionItemModel(label: "TODO:", kind: .text, detail: "Demo snippet"),
            CompletionItemModel(label: "MARK:", kind: .text, detail: "Demo snippet"),
            CompletionItemModel(label: "FIXME:", kind: .text, detail: "Demo snippet")
        ]
        return CompletionResult(items: items, context: context)
    }
}
#endif
