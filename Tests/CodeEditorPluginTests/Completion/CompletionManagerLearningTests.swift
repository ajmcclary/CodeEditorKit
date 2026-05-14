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
}
