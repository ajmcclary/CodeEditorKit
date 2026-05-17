#if canImport(AppKit) || canImport(UIKit)
import CodeEditorLanguages
import Foundation

@available(macOS 13.0, iOS 16.0, *)
extension EditorController {
    /// Registers a completion provider with the active editor.
    ///
    /// Re-registering with the same `id` replaces the existing provider.
    /// No-op if `attach(to:)` has not yet been called.
    ///
    /// Providers are matched against the current buffer's `Language` and the
    /// configured trigger characters. Use `requestCompletion(...)` to fire
    /// manually, or rely on automatic trigger-character firing once
    /// `EditorConfiguration.Behavior.isCodeCompletionEnabled` is `true`.
    public func registerCompletionProvider(_ provider: any CompletionProvider) {
        codeEditorView?.completionManager.registerProvider(provider)
    }

    /// Unregisters a completion provider previously installed via
    /// `registerCompletionProvider(_:)`. No-op if the provider is unknown
    /// or the controller is unattached.
    public func unregisterCompletionProvider(withId id: String) {
        codeEditorView?.completionManager.unregisterProvider(withId: id)
    }

    /// Live snapshot of providers currently registered with the editor.
    /// Empty when no editor is attached.
    public var registeredCompletionProviders: [any CompletionProvider] {
        codeEditorView?.completionManager.registeredProviders ?? []
    }

    /// Cache hit-rate, request count, and average processing time for the
    /// attached editor's completion manager. Returns a zero-state
    /// `CompletionStatistics` instance when no editor is attached.
    public var completionStatistics: CompletionStatistics {
        codeEditorView?.completionManager.statistics ?? CompletionStatistics()
    }

    /// Manually request completion at the cursor. Mirrors
    /// `CodeEditorView.requestCompletion(triggerKind:triggerCharacter:)` for
    /// hosts that only hold an `EditorController`.
    public func requestCompletion(
        triggerKind: CompletionTriggerKind = .manual,
        triggerCharacter: String? = nil
    ) {
        codeEditorView?.requestCompletion(
            triggerKind: triggerKind,
            triggerCharacter: triggerCharacter
        )
    }

    /// Returns an `AsyncStream` of per-provider completion events from the
    /// attached editor's completion manager.
    ///
    /// Returns an empty, immediately-terminating stream when no editor is
    /// attached. Each call returns an independent stream; multiple subscribers
    /// each receive every event.
    ///
    /// - SeeAlso: `CompletionManager.events()`
    public func completionEvents() -> AsyncStream<CompletionEvent> {
        guard let manager = codeEditorView?.completionManager else {
            return AsyncStream { $0.finish() }
        }
        return manager.events()
    }

    /// Records that the user accepted this completion item, updating the
    /// attached manager's in-memory frequency/recency state. No-op when no
    /// editor is attached.
    ///
    /// The framework automatically calls this when the user accepts a
    /// completion from the popup; hosts only need to call it themselves to
    /// record acceptances from custom UI (e.g., a command palette).
    ///
    /// - SeeAlso: `CompletionManager.recordSelection(_:)`
    public func recordCompletionSelection(_ item: CompletionItemModel) {
        codeEditorView?.completionManager.recordSelection(item)
    }
}
#endif
