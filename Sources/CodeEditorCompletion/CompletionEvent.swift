import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// One observation of a single completion provider's response to a request.
///
/// Published by `CompletionManager` after every `provider.completions(for:)`
/// call returns — success or failure. The event publishes *before* the
/// existing per-provider failure isolation swallows the error, so subscribers
/// see every fire even when `CompletionManager` proceeds with results from
/// the other providers.
///
/// Subscribe via `CompletionManager.events()` or
/// `EditorController.completionEvents()`.
public struct CompletionEvent: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let providerID: String
    public let language: Language
    public let triggerCharacter: String?
    /// `context.currentWord` truncated to ≤ 32 chars. Keeps events cheap
    /// to store/log and avoids leaking arbitrary buffer text.
    public let prefix: String
    public let durationMilliseconds: Double
    public let timestamp: Date
    public let outcome: Outcome

    public enum Outcome: Sendable, Hashable {
        case succeeded(itemCount: Int)
        case failed(SendableError)
    }

    public init(
        providerID: String,
        language: Language,
        triggerCharacter: String?,
        prefix: String,
        durationMilliseconds: Double,
        outcome: Outcome,
        id: UUID = UUID(),
        timestamp: Date = Date()
    ) {
        self.id = id
        self.providerID = providerID
        self.language = language
        self.triggerCharacter = triggerCharacter
        self.prefix = prefix
        self.durationMilliseconds = durationMilliseconds
        self.timestamp = timestamp
        self.outcome = outcome
    }

    /// Internal convenience used by `CompletionManager` to build an event
    /// directly from a request's context. Keeps the call sites in
    /// `collectResultsConcurrently` short and ensures the 32-char `prefix`
    /// truncation is applied in exactly one place.
    init(
        providerID: String,
        context: CompletionContextModel,
        durationMilliseconds: Double,
        outcome: Outcome
    ) {
        self.init(
            providerID: providerID,
            language: context.language,
            triggerCharacter: context.triggerCharacter,
            prefix: String(context.currentWord.prefix(32)),
            durationMilliseconds: durationMilliseconds,
            outcome: outcome
        )
    }
}
