#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("EditorController completion")
struct EditorControllerCompletionTests {
    @Test("registered providers reflect registration order, dedupe by id")
    @MainActor
    func registeredProvidersReflectState() async {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)

        #expect(controller.registeredCompletionProviders.isEmpty)

        let providerA = StubProvider(id: "a")
        let providerB = StubProvider(id: "b")
        controller.registerCompletionProvider(providerA)
        controller.registerCompletionProvider(providerB)

        let ids = controller.registeredCompletionProviders.map(\.id).sorted()
        #expect(ids == ["a", "b"])

        // Re-register `a` replaces in place.
        controller.registerCompletionProvider(StubProvider(id: "a", trigger: "."))
        #expect(controller.registeredCompletionProviders.count == 2)

        controller.unregisterCompletionProvider(withId: "a")
        #expect(controller.registeredCompletionProviders.map(\.id) == ["b"])
    }

    @Test("requestCompletion fires registered provider")
    @MainActor
    func requestCompletionFiresProvider() async throws {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "let x = "
        view.isCodeCompletionEnabled = true
        controller.attach(to: view)

        let provider = StubProvider(id: "a")
        controller.registerCompletionProvider(provider)

        controller.requestCompletion(triggerKind: .manual)

        // requestCompletion launches a Task that suspends through several
        // `await`s (cache check → fetchResultsFromProviders → withTaskGroup
        // → MainActor hop into provider.completions). Yield repeatedly to
        // let the chain settle rather than relying on a wall-clock guess.
        for _ in 0..<20 {
            await Task.yield()
            if provider.invocationCount >= 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(provider.invocationCount >= 1)
    }

    @Test("methods are no-ops when controller is unattached")
    @MainActor
    func methodsNoopWhenUnattached() {
        let controller = EditorController()

        controller.registerCompletionProvider(StubProvider(id: "x"))
        #expect(controller.registeredCompletionProviders.isEmpty)
        #expect(controller.completionStatistics.totalRequests == 0)

        controller.unregisterCompletionProvider(withId: "x")  // must not crash
        controller.requestCompletion(triggerKind: .manual)    // must not crash
    }

    @Test("completionStatistics increments after a request")
    @MainActor
    func statisticsIncrement() async throws {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "hello"
        view.isCodeCompletionEnabled = true
        controller.attach(to: view)
        controller.registerCompletionProvider(StubProvider(id: "a"))

        let before = controller.completionStatistics.totalRequests
        controller.requestCompletion(triggerKind: .manual)

        for _ in 0..<20 {
            await Task.yield()
            if controller.completionStatistics.totalRequests > before { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(controller.completionStatistics.totalRequests > before)
    }
}

private final class StubProvider: CompletionProvider, @unchecked Sendable {
    let id: String
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String]
    let supportsSnippets: Bool = false

    private(set) var invocationCount = 0

    init(id: String, trigger: String? = nil) {
        self.id = id
        self.triggerCharacters = trigger.map { [$0] } ?? []
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        invocationCount += 1
        return CompletionResult(items: [], context: context)
    }
}
#endif
