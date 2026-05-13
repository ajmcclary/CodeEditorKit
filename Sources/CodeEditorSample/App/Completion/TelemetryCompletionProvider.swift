#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// Decorator that wraps any `CompletionProvider`, forwards each call to the
/// wrapped instance, and records timing + outcome into a recorder closure.
/// Used by `CompletionSampleCoordinator` to surface every fire — including
/// failures — in the inspector panel without framework-side event hooks.
///
/// Errors are NOT swallowed: an entry is recorded with `error != nil` and
/// the underlying error is re-thrown to `CompletionManager`, which already
/// isolates per-provider failures from the batch.
struct TelemetryCompletionProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language]
    let triggerCharacters: [String]
    let supportsSnippets: Bool

    private let wrapped: any CompletionProvider
    private let recorder: @Sendable (CompletionActivityEntry) -> Void

    init(
        wrapping provider: any CompletionProvider,
        recorder: @escaping @Sendable (CompletionActivityEntry) -> Void
    ) {
        self.id = provider.id
        self.supportedLanguages = provider.supportedLanguages
        self.triggerCharacters = provider.triggerCharacters
        self.supportsSnippets = provider.supportsSnippets
        self.wrapped = provider
        self.recorder = recorder
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let start = Date()
        do {
            let result = try await wrapped.completions(for: context)
            recorder(.init(
                providerId: wrapped.id,
                language: context.language,
                triggerCharacter: context.triggerCharacter,
                prefix: Self.truncatedPrefix(from: context),
                itemCount: result.items.count,
                durationMs: Date().timeIntervalSince(start) * 1_000,
                timestamp: Date(),
                error: nil
            ))
            return result
        } catch {
            recorder(.init(
                providerId: wrapped.id,
                language: context.language,
                triggerCharacter: context.triggerCharacter,
                prefix: Self.truncatedPrefix(from: context),
                itemCount: 0,
                durationMs: Date().timeIntervalSince(start) * 1_000,
                timestamp: Date(),
                error: String(describing: error)
            ))
            throw error
        }
    }

    private static func truncatedPrefix(from context: CompletionContextModel) -> String {
        String(context.currentWord.prefix(32))
    }
}
#endif
