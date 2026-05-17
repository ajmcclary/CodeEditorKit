import CodeEditorTextModel
import Foundation
import XCTest

@testable import CodeEditorPlugin

/// Tests for `CompletionManager.rankCombined(_:context:)` — the canonical
/// six-tier sort (sortText asc -> priority desc -> frequency desc -> relevance
/// desc -> kind.defaultPriority desc -> label asc) plus dedup by
/// `label:kind.rawValue`.
///
/// Spec: docs/superpowers/specs/2026-05-14-completion-ranking-unification-design.md.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class CompletionManagerRankingTests: XCTestCase {
    // MARK: - Fixtures

    private func makeManager(maxCompletions: Int = 50) -> CompletionManager {
        let manager = CompletionManager(memoryMonitor: MemoryMonitor(), enableCaching: false)
        manager.maxCompletions = maxCompletions
        return manager
    }

    private func makeContext(
        currentWord: String = "",
        lineText: String = "",
        language: Language = .swift
    ) -> CompletionContextModel {
        let cursor = TextRangeUtilities.utf16Length(of: currentWord)
        let wordRange = currentWord.isEmpty
            ? nil
            : NSRange(location: 0, length: cursor)
        return CompletionContextModel(
            text: currentWord,
            cursorPosition: cursor,
            language: language,
            triggerKind: .manual,
            triggerCharacter: nil,
            lineText: lineText.isEmpty ? currentWord : lineText,
            wordRange: wordRange
        )
    }

    private func makeItem(
        _ label: String,
        kind: CompletionItemKind = .text,
        priority: Int = 0,
        sortText: String? = nil
    ) -> CompletionItemModel {
        CompletionItemModel(
            label: label,
            insertText: label,
            kind: kind,
            sortText: sortText,
            priority: priority
        )
    }

    // MARK: - SortText Tier

    func testSortTextWinsWhenBothPresent() {
        let manager = makeManager()
        let alpha = makeItem("z_label", sortText: "a")
        let beta = makeItem("a_label", sortText: "b")
        let ranked = manager.testOnly_rankCombined([beta, alpha], context: makeContext())
        XCTAssertEqual(ranked.map(\.label), ["z_label", "a_label"])
    }

    func testSortTextMixedPairWithSetWins() {
        let manager = makeManager()
        let withSortText = makeItem("z_label", sortText: "a")
        let withoutSortText = makeItem("a_label")
        let ranked = manager.testOnly_rankCombined([withoutSortText, withSortText], context: makeContext())
        XCTAssertEqual(ranked.map(\.label), ["z_label", "a_label"])
    }

    // MARK: - Priority Tier

    func testPriorityDescendingWhenNoSortText() {
        let manager = makeManager()
        let low = makeItem("alpha", priority: 1)
        let high = makeItem("beta", priority: 10)
        let ranked = manager.testOnly_rankCombined([low, high], context: makeContext())
        XCTAssertEqual(ranked.map(\.label), ["beta", "alpha"])
    }

    // MARK: - Frequency Tier

    func testFrequencyDescendingWhenPriorityEqual() async throws {
        let manager = makeManager()
        // Seed frequency: bump "alpha" twice via the public surface. Requires
        // a lastContext, so we issue a dummy request first.
        let ctx = makeContext()
        manager.testOnly_setLastContext(ctx)
        manager.recordSelection(makeItem("alpha"))
        manager.recordSelection(makeItem("alpha"))
        manager.recordSelection(makeItem("beta"))

        let alpha = makeItem("alpha")
        let beta = makeItem("beta")
        let ranked = manager.testOnly_rankCombined([beta, alpha], context: ctx)
        XCTAssertEqual(ranked.map(\.label), ["alpha", "beta"])
    }

    // MARK: - Relevance Tier

    func testRelevancePrefixMatchWins() {
        let manager = makeManager()
        let ctx = makeContext(currentWord: "req", lineText: "req")
        let prefix = makeItem("request")
        let other = makeItem("send")
        let ranked = manager.testOnly_rankCombined([other, prefix], context: ctx)
        XCTAssertEqual(ranked.map(\.label), ["request", "send"])
    }

    func testRelevanceKindContextualMethodInParen() {
        let manager = makeManager()
        let ctx = makeContext(lineText: "foo(")
        let method = makeItem("doStuff", kind: .method)
        let variable = makeItem("counter", kind: .variable)
        let ranked = manager.testOnly_rankCombined([variable, method], context: ctx)
        XCTAssertEqual(ranked.map(\.label), ["doStuff", "counter"])
    }

    func testRelevanceKindContextualTypeAfterColon() {
        let manager = makeManager()
        let ctx = makeContext(lineText: "let x:")
        let cls = makeItem("Widget", kind: .class)
        let method = makeItem("doStuff", kind: .method)
        let ranked = manager.testOnly_rankCombined([method, cls], context: ctx)
        XCTAssertEqual(ranked.map(\.label), ["Widget", "doStuff"])
    }

    // MARK: - Kind Default Priority Tier

    func testKindDefaultPriorityTiebreaker() {
        let manager = makeManager()
        let snippet = makeItem("for_each", kind: .snippet)
        let keyword = makeItem("for", kind: .keyword)
        let ranked = manager.testOnly_rankCombined([snippet, keyword], context: makeContext())
        // .keyword (100) outranks .snippet (90) per CompletionItemKind.defaultPriority.
        XCTAssertEqual(ranked.map(\.label), ["for", "for_each"])
    }

    // MARK: - Label Tier

    func testLabelAlphabeticalFinalTiebreaker() {
        let manager = makeManager()
        let alpha = makeItem("alpha")
        let beta = makeItem("beta")
        let ranked = manager.testOnly_rankCombined([beta, alpha], context: makeContext())
        XCTAssertEqual(ranked.map(\.label), ["alpha", "beta"])
    }

    // MARK: - Dedup

    func testDedupKeepsDistinctKindsWithSameLabel() {
        let manager = makeManager()
        let asClass = makeItem("Float", kind: .class)
        let asMethod = makeItem("Float", kind: .method)
        let ranked = manager.testOnly_rankCombined([asClass, asMethod], context: makeContext())
        XCTAssertEqual(ranked.count, 2)
    }

    func testDedupCollapsesIdenticalLabelAndKind() {
        let manager = makeManager()
        let first = makeItem("Float", kind: .class)
        let second = makeItem("Float", kind: .class)
        let ranked = manager.testOnly_rankCombined([first, second], context: makeContext())
        XCTAssertEqual(ranked.count, 1)
    }
}
