@testable import CodeEditorCompletion
import CodeEditorDiagnostics
import CodeEditorLanguages
import Testing

/// Lets a test hold a provider inside its request until it says so.
private actor RequestGate {
    private var didStart = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var isOpen = false
    private var openWaiter: CheckedContinuation<Void, Never>?

    func markStarted() {
        didStart = true
        startWaiter?.resume()
        startWaiter = nil
    }

    func waitUntilStarted() async {
        if didStart { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func waitUntilOpen() async {
        if isOpen { return }
        await withCheckedContinuation { openWaiter = $0 }
    }

    func open() {
        isOpen = true
        openWaiter?.resume()
        openWaiter = nil
    }
}

private struct GatedProvider: CompletionProvider {
    let id = "gated.provider"
    let supportedLanguages: [Language] = [.swift]
    let gate: RequestGate

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        await gate.markStarted()
        await gate.waitUntilOpen()
        return CompletionResult(items: [CompletionItemModel(label: "gated", kind: .keyword)], context: context)
    }
}

/// A memory cleanup pass is routine (the monitor runs one whenever the host
/// process is over its threshold), so it may drop the response cache but
/// must not cancel the completion the user is waiting for.
@MainActor
@Suite("Completion through a memory cleanup pass")
struct CompletionMemoryCleanupTests {
    @Test("a pass during a request lets it finish and still clears the cache")
    func aPassDoesNotCancelTheRequestInFlight() async throws {
        let monitor = MemoryMonitor.mock()
        let manager = CompletionManager(memoryMonitor: monitor)
        let gate = RequestGate()
        manager.registerProvider(GatedProvider(gate: gate))
        let context = CompletionContextModel(text: "", cursorPosition: 0, language: .swift)

        let request = Task { try await manager.requestCompletions(for: context) }
        await gate.waitUntilStarted()
        await monitor.performCleanup()
        await gate.open()

        let result = try await request.value
        #expect(result.items.map(\.label).contains("gated"))

        // The cache the pass is for is still released.
        #expect(manager.cacheStatistics.currentSize > 0)
        await monitor.performCleanup()
        #expect(manager.cacheStatistics.currentSize == 0)
    }
}
