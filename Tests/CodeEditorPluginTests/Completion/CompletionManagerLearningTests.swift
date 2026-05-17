import CodeEditorDiagnostics
import CodeEditorLanguages
import Foundation
import XCTest

@testable import CodeEditorPlugin

/// Tests for `CompletionManager.recordSelection(_:)` and
/// `clearLearnedPatterns()`. The behavioral cases that verify frequency
/// actually affects ranking land alongside the `rankCombined` wiring in a
/// later task; these two cover the standalone semantics.
///
/// Spec: docs/superpowers/specs/2026-05-14-completion-ranking-unification-design.md.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class CompletionManagerLearningTests: XCTestCase {
    // MARK: - Fixtures

    private func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor(), enableCaching: false)
    }

    private func makeItem(_ label: String, kind: CompletionItemKind = .text) -> CompletionItemModel {
        CompletionItemModel(label: label, insertText: label, kind: kind)
    }

    // MARK: - Tests

    func testRecordSelectionWithoutContextIsNoop() {
        let manager = makeManager()

        // No requestCompletions has been called yet, so lastContext is nil.
        // recordSelection must not throw or crash; clearLearnedPatterns
        // afterwards must also be safe.
        manager.recordSelection(makeItem("forEach"))
        manager.clearLearnedPatterns()

        // Reaching this point with no traps fired is the assertion.
        XCTAssertTrue(true)
    }

    func testClearLearnedPatternsIsIdempotent() {
        let manager = makeManager()

        manager.clearLearnedPatterns()
        manager.clearLearnedPatterns()

        XCTAssertTrue(true)
    }

    // MARK: - Behavioral Fixtures

    struct StubProvider: CompletionProvider {
        let id: String
        let supportedLanguages: [Language] = []
        let triggerCharacters: [String] = []
        let supportsSnippets: Bool = false
        let labels: [String]

        @MainActor
        func completions(for context: CompletionContextModel) async throws -> CompletionResult {
            let items = labels.map { label in
                CompletionItemModel(label: label, insertText: label, kind: .text)
            }
            return CompletionResult(items: items, context: context)
        }
    }

    private func swiftContext() -> CompletionContextModel {
        CompletionContextModel(text: "", cursorPosition: 0, language: .swift)
    }

    private func pythonContext() -> CompletionContextModel {
        CompletionContextModel(text: "", cursorPosition: 0, language: .python)
    }

    // MARK: - Behavioral Tests

    func testRecordSelectionAfterRequestIncrementsFrequency() async throws {
        let manager = makeManager()
        manager.registerProvider(StubProvider(id: "p1", labels: ["alpha", "beta"]))

        // First request: alphabetical tiebreak puts alpha first.
        let firstResult = try await manager.requestCompletions(for: swiftContext())
        XCTAssertEqual(firstResult.items.map(\.label), ["alpha", "beta"])

        // Bump beta twice.
        manager.recordSelection(makeItem("beta"))
        manager.recordSelection(makeItem("beta"))

        // Second request: beta now leads on frequency.
        let secondResult = try await manager.requestCompletions(for: swiftContext())
        XCTAssertEqual(secondResult.items.map(\.label), ["beta", "alpha"])
    }

    func testRecordSelectionScopedByLanguage() async throws {
        let manager = makeManager()
        manager.registerProvider(StubProvider(id: "p1", labels: ["alpha", "beta"]))

        // Bump "alpha" while context is Swift.
        _ = try await manager.requestCompletions(for: swiftContext())
        manager.recordSelection(makeItem("alpha"))
        manager.recordSelection(makeItem("alpha"))

        // Request for Python — Swift frequency must not leak through.
        let result = try await manager.requestCompletions(for: pythonContext())
        XCTAssertEqual(result.items.map(\.label), ["alpha", "beta"]) // alphabetical
    }

    func testClearLearnedPatternsEmptiesState() async throws {
        let manager = makeManager()
        manager.registerProvider(StubProvider(id: "p1", labels: ["alpha", "beta"]))

        _ = try await manager.requestCompletions(for: swiftContext())
        manager.recordSelection(makeItem("beta"))
        manager.recordSelection(makeItem("beta"))

        manager.clearLearnedPatterns()

        let result = try await manager.requestCompletions(for: swiftContext())
        // Back to alphabetical — frequency state is gone.
        XCTAssertEqual(result.items.map(\.label), ["alpha", "beta"])
    }

    func testCancelCurrentRequestClearsLastContext() async throws {
        let manager = makeManager()
        manager.registerProvider(StubProvider(id: "p1", labels: ["alpha", "beta"]))

        // Issue a request to populate lastContext, then cancel.
        _ = try await manager.requestCompletions(for: swiftContext())
        manager.cancelCurrentRequest()

        // recordSelection after cancel must be a no-op (lastContext is nil),
        // so "beta" stays unboosted.
        manager.recordSelection(makeItem("beta"))
        manager.recordSelection(makeItem("beta"))

        // Sanity contrast: without cancel, two recordSelection("beta") calls
        // would put "beta" ahead of "alpha" (see
        // testRecordSelectionAfterRequestIncrementsFrequency). Here we expect
        // alphabetical order because the cancel cleared lastContext before
        // recordSelection fired.
        let result = try await manager.requestCompletions(for: swiftContext())
        XCTAssertEqual(result.items.map(\.label), ["alpha", "beta"])
    }

    func testRecencyBreaksFrequencyTies() async throws {
        let manager = makeManager()
        manager.registerProvider(StubProvider(id: "p1", labels: ["alpha", "beta"]))

        // Tie both labels at usageCount = 2, but record "beta" last so
        // its lastUsed is more recent.
        _ = try await manager.requestCompletions(for: swiftContext())
        manager.recordSelection(makeItem("alpha"))
        manager.recordSelection(makeItem("alpha"))
        // A small sleep ensures `Date()` differs between alpha's and
        // beta's recordings. Two `Date()` calls back-to-back on the same
        // host can land in the same nanosecond on fast Apple hardware.
        try await Task.sleep(nanoseconds: 2_000_000) // 2 ms
        manager.recordSelection(makeItem("beta"))
        manager.recordSelection(makeItem("beta"))

        // Both have usageCount = 2; recency puts beta first.
        let result = try await manager.requestCompletions(for: swiftContext())
        XCTAssertEqual(result.items.map(\.label), ["beta", "alpha"])
    }
}
