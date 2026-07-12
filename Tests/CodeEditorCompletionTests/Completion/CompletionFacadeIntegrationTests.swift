@testable import CodeEditorCompletion
import CodeEditorDiagnostics
import CodeEditorLanguages
import Testing

private actor FacadeProviderProbe {
    private(set) var requestCount = 0

    func recordRequest() {
        requestCount += 1
    }
}

private struct FacadeProvider: CompletionProvider {
    let id = "facade.provider"
    let supportedLanguages: [Language] = [.swift]
    let probe: FacadeProviderProbe

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        await probe.recordRequest()
        return CompletionResult(
            items: [CompletionItemModel(label: "provider", kind: .keyword)],
            context: context
        )
    }
}

@MainActor
@Suite("CompletionManager façade")
struct CompletionFacadeIntegrationTests {
    @Test("injected components retain ownership behind the public façade")
    func injectedComponentDelegation() async throws {
        let monitor = MemoryMonitor()
        let broadcaster = CompletionEventBroadcaster()
        let registry = CompletionProviderRegistry()
        let probe = FacadeProviderProbe()
        registry.register(FacadeProvider(probe: probe))
        let cache = CompletionResponseCache(
            capacity: 10,
            expirationTime: 60,
            isEnabled: true,
            memoryMonitor: monitor
        )
        let learning = CompletionLearningStore(
            capacity: 10,
            memoryMonitor: monitor
        )
        let coordinator = CompletionRequestCoordinator(eventSink: broadcaster)
        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .swift
        )
        cache.store(
            CompletionResult(
                items: [CompletionItemModel(label: "cached", kind: .keyword)],
                context: context
            ),
            for: context
        )
        let manager = CompletionManager(
            memoryMonitor: monitor,
            providerRegistry: registry,
            requestCoordinator: coordinator,
            responseCache: cache,
            learningStore: learning,
            ranker: CompletionRanker(),
            broadcaster: broadcaster
        )

        let cached = try await manager.requestCompletions(for: context)
        #expect(cached.items.map(\.label) == ["cached"])
        #expect(await probe.requestCount == 0)

        manager.clearCache()
        let requested = try await manager.requestCompletions(for: context)
        #expect(requested.items.map(\.label) == ["provider"])
        #expect(await probe.requestCount == 1)

        manager.recordSelection(CompletionItemModel(label: "provider", kind: .keyword))
        #expect(learning.snapshot(for: .swift).usageCounts["provider"] == 1)
        #expect(manager.registeredProviders.map(\.id) == ["facade.provider"])
    }
}
