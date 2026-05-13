#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("TelemetryCompletionProvider")
@MainActor
struct TelemetryCompletionProviderTests {
    @Test("success path records an entry and forwards the result")
    func successPathRecords() async throws {
        let recorded = Recorder()
        let wrapped = StubProvider(id: "stub", items: [
            CompletionItemModel(label: "foo"),
            CompletionItemModel(label: "bar")
        ])
        let telemetry = TelemetryCompletionProvider(wrapping: wrapped) { entry in
            recorded.add(entry)
        }

        let context = CompletionContextModel(
            text: "let x = ",
            cursorPosition: 8,
            language: .swift,
            triggerKind: .character,
            triggerCharacter: ".",
            lineText: "let x = "
        )
        let result = try await telemetry.completions(for: context)

        let entries = recorded.snapshot()
        #expect(result.items.count == 2)
        #expect(entries.count == 1)
        #expect(entries[0].providerId == "stub")
        #expect(entries[0].language == .swift)
        #expect(entries[0].triggerCharacter == ".")
        #expect(entries[0].itemCount == 2)
        #expect(entries[0].error == nil)
        #expect(entries[0].durationMs >= 0)
    }

    @Test("error path records an error entry and re-throws")
    func errorPathRecords() async {
        let recorded = Recorder()
        let wrapped = ThrowingStubProvider(id: "broken")
        let telemetry = TelemetryCompletionProvider(wrapping: wrapped) { entry in
            recorded.add(entry)
        }
        let context = CompletionContextModel(
            text: "", cursorPosition: 0, language: .swift
        )

        do {
            _ = try await telemetry.completions(for: context)
            #expect(Bool(false), "expected throw")
        } catch {
            // Expected.
        }
        let entries = recorded.snapshot()
        #expect(entries.count == 1)
        #expect(entries[0].error != nil)
        #expect(entries[0].itemCount == 0)
    }

    @Test("prefix is truncated to 32 chars")
    func prefixTruncation() async throws {
        let recorded = Recorder()
        let wrapped = StubProvider(id: "s", items: [])
        let telemetry = TelemetryCompletionProvider(wrapping: wrapped) { entry in
            recorded.add(entry)
        }
        let longPrefix = String(repeating: "a", count: 80)
        let context = CompletionContextModel(
            text: longPrefix,
            cursorPosition: longPrefix.count,
            language: .swift,
            wordRange: NSRange(location: 0, length: longPrefix.count)
        )

        _ = try await telemetry.completions(for: context)

        #expect(recorded.snapshot()[0].prefix.count <= 32)
    }
}

/// Thread-safe accumulator usable from `@Sendable` closures in tests.
private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [CompletionActivityEntry] = []

    func add(_ entry: CompletionActivityEntry) {
        lock.lock()
        entries.append(entry)
        lock.unlock()
    }

    func snapshot() -> [CompletionActivityEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}

private final class StubProvider: CompletionProvider, @unchecked Sendable {
    let id: String
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false
    let items: [CompletionItemModel]

    init(id: String, items: [CompletionItemModel]) {
        self.id = id
        self.items = items
    }

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        CompletionResult(items: items, context: context)
    }
}

private struct ProviderError: Error { let why: String }

private final class ThrowingStubProvider: CompletionProvider, @unchecked Sendable {
    let id: String
    let supportedLanguages: [Language] = []
    let triggerCharacters: [String] = []
    let supportsSnippets: Bool = false

    init(id: String) { self.id = id }

    @MainActor
    func completions(for _: CompletionContextModel) async throws -> CompletionResult {
        throw ProviderError(why: "boom")
    }
}
#endif
