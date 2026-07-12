import CodeEditorCompletion

/// Reconciles the SwiftUI completion modifier with a manager registration.
@MainActor
final class CompletionModifierRegistry {
    typealias CompletionClosure = @Sendable (
        SwiftUICompletionContext
    ) async -> [SwiftUICompletionItem]

    private var adapter: SwiftUIClosureCompletionProvider?

    func reconcile(
        on manager: CompletionManager,
        closure: CompletionClosure?
    ) {
        switch (closure, adapter) {
        case let (.some(newClosure), .some(currentAdapter)):
            currentAdapter.closure = newClosure

        case let (.some(newClosure), .none):
            let currentAdapter = SwiftUIClosureCompletionProvider()
            currentAdapter.closure = newClosure
            adapter = currentAdapter
            manager.registerProvider(currentAdapter)

        case (.none, .some):
            manager.unregisterProvider(withId: "swiftui-modifier")
            adapter = nil

        case (.none, .none):
            break
        }
    }
}
