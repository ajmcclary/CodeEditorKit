# Completion Ranking Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse `SmartCompletionEngine` (dead public API) and `CompletionManager` (production funnel) into a single engine on `CompletionManager`, replacing the coarse `sortAndDeduplicateItems` with a canonical six-tier `rankCombined` (sortText → priority → frequency → relevance → kind.defaultPriority → label) plus in-memory `recordSelection(_:)`/`clearLearnedPatterns()` learning. Delete the dead engine and its supporting public types.

**Architecture:** `CompletionManager` (`@MainActor public final class`) gains a private `LRUCache<String, FrequencyEntry>` (capacity 500), a private `lastContext: CompletionContextModel?`, and three new public members (`maxCompletions: Int`, `recordSelection(_:)`, `clearLearnedPatterns()`). A new private `rankCombined(_:context:)` runs dedup → six-tier sort → `prefix(maxCompletions)` and replaces the current `sortAndDeduplicateItems` inside `processAndCacheResults`. `EditorController` grows a forwarder `recordCompletionSelection(_:)`. `CodeEditorView`'s existing `completionViewController(_:complete:movement:)` delegate gains a single auto-call into the manager. `SmartCompletionEngine`, `CompletionError`, `CompletionSelection`, `CompletionFrequency`, `SmartCompletionSettings`, `CompletionMLModel`, and `NeuralCompletionRanker` are deleted; the two test-only callers are removed.

**Tech Stack:** Swift 6.3 (StrictConcurrency), `@MainActor` isolation, `LRUCache<Key, Value>` (existing utility), XCTest. Spec at `docs/superpowers/specs/2026-05-14-completion-ranking-unification-design.md` (commit `1c11702`).

---

## File Structure

**Framework — 1 deleted, 3 modified:**
- Delete: `Sources/CodeEditorPlugin/Completion/SmartCompletionEngine.swift` — orphan engine + supporting public types
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` — add `FrequencyEntry`, `frequencyCache`, `lastContext`, `maxCompletions`, `recordSelection(_:)`, `clearLearnedPatterns()`, `rankCombined(_:context:)`, `frequencyData(for:)`; replace `sortAndDeduplicateItems` call site
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift` — delete `CompletionMLModel` protocol + `NeuralCompletionRanker` struct (keep `CompletionRankingModel` itself untouched)
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift` — add `recordCompletionSelection(_:)` forwarder

**Editor view — 1 modified:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift` — `completionViewController(_:complete:movement:)` calls `completionManager.recordSelection(adapter.model)` before inserting text

**Tests — 3 added, 2 modified, 0 deleted:**
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift` — 7 cases on `recordSelection`/`clearLearnedPatterns` semantics (incl. recency-breaks-frequency-ties)
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionManagerRankingTests.swift` — 11 cases on the six-tier sort + dedup
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionViewWiringTests.swift` — 1 case asserting `completionViewController(_:complete:movement:)` records the selection into the attached manager
- Modify: `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift` — delete `testCompletionProvidersRegistration` and the `extension SmartCompletionEngine { hasCompletionProvider(...) }` helper
- Modify: `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift` — delete `testSmartCompletionEnginePerformance`

**Sample tests — 1 modified:**
- Modify: `Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift` — fix `returnsThreeItems` to match the 5-item snippet catalog (`FIXME:`, `MARK:`, `NOTE:`, `TODO:`, `WARNING:`)

**Docs — 1 modified:**
- Modify: `REVIEW.md` — add a status entry under the "What's left after this round" section marking the item landed

---

## Task 1: Foundation — add learning state + minimal `recordSelection`/`clearLearnedPatterns` (TDD)

**Files:**
- Test: `Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift` (create)
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` (add state + methods; replace `sortAndDeduplicateItems` call site comes in Task 3)

Add the in-memory frequency/recency state and the public `recordSelection(_:)` / `clearLearnedPatterns()` methods. Behavior is verified via two simple cases that do not depend on the new ranking pipeline; the remaining four learning cases land in Task 4 after `rankCombined` is wired into production.

- [ ] **Step 1: Create the test file with two foundational cases**

Create `Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the new test file — expect a compile failure**

```bash
swift test --filter CompletionManagerLearningTests
```

Expected: build error like `error: value of type 'CompletionManager' has no member 'recordSelection'` and `… has no member 'clearLearnedPatterns'`.

- [ ] **Step 3: Add the state + methods to `CompletionManager`**

Modify `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`.

Insert this new internal struct above the `CompletionManager` declaration (after the existing `// MARK: - Completion Manager` doc comment, immediately before `@MainActor public final class CompletionManager`):

```swift
// MARK: - Frequency Entry

/// In-memory frequency + recency record for a single label, scoped by
/// `"\(language.identifier):\(label)"`. Lives only inside `CompletionManager`'s
/// LRU; never published, never persisted in this round. See the spec's
/// "Follow-ups (deliberately deferred)" section for persistence design.
private struct FrequencyEntry: Sendable {
    var usageCount: Int
    var lastUsed: Date
}
```

Find the existing stored-property block (around `CompletionManager.swift:51-58`):

```swift
    private var providers: [String: any CompletionProvider] = [:]
    private var currentRequest: Task<CompletionResult, Error>?
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let cacheExpirationTime: TimeInterval
    private let enableCaching: Bool
    private let debouncer: CompletionDebouncer
    private let memoryMonitor: MemoryMonitor
    private let broadcaster = CompletionEventBroadcaster()
```

Replace it with:

```swift
    private var providers: [String: any CompletionProvider] = [:]
    private var currentRequest: Task<CompletionResult, Error>?
    private let cache: LRUCache<CompletionCacheKey, CachedCompletionResult>
    private let cacheExpirationTime: TimeInterval
    private let enableCaching: Bool
    private let debouncer: CompletionDebouncer
    private let memoryMonitor: MemoryMonitor
    private let broadcaster = CompletionEventBroadcaster()

    /// In-memory frequency/recency cache. Keyed by
    /// `"\(language.identifier):\(label)"`; capacity matches the legacy
    /// SmartCompletionEngine setting (500). Cleared on
    /// `clearLearnedPatterns()` and on the memory-monitor cleanup hook.
    /// Never persisted in this round; see spec follow-ups.
    private let frequencyCache: LRUCache<String, FrequencyEntry>

    /// Captured at the top of `requestCompletions(for:)` so
    /// `recordSelection(_:)` can scope the frequency key by language
    /// without forcing callers to thread the context through.
    private var lastContext: CompletionContextModel?

    private let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.plugin",
        category: "CompletionManager"
    )

    /// Maximum items returned from `requestCompletions(for:)`. Default 50.
    /// Mutable so hosts can tune per editor without sub-classing or DI.
    public var maxCompletions: Int = 50
```

Find the existing `init` body. Locate the line that assigns `self.cache = LRUCache(...)` (around `CompletionManager.swift:78`):

```swift
        self.cache = LRUCache(capacity: cacheSize, memoryMonitor: memoryMonitor)
```

Insert immediately after it:

```swift
        self.frequencyCache = LRUCache(capacity: 500, memoryMonitor: memoryMonitor)
```

Find the `// MARK: - Private Methods` block near `CompletionManager.swift:332`. Above the `sortAndDeduplicateItems` definition, insert the following new public + private members (we'll wire them into `processAndCacheResults` in Task 3):

```swift
    // MARK: - Learning API

    /// Record that the user accepted this item. Updates the in-memory
    /// frequency/recency cache used by the next `requestCompletions(for:)`
    /// call's ranking pass.
    ///
    /// - Note: No-op if no `requestCompletions(for:)` has fired yet (no
    ///   `lastContext`) or if it was cancelled via `cancelCurrentRequest()`.
    /// - SeeAlso: ``clearLearnedPatterns()``, ``maxCompletions``.
    public func recordSelection(_ item: CompletionItemModel) {
        guard let language = lastContext?.language else {
            logger.debug("recordSelection called with no lastContext; ignored")
            return
        }
        let key = "\(language.identifier):\(item.label)"
        var entry = frequencyCache.get(key) ?? FrequencyEntry(usageCount: 0, lastUsed: Date())
        entry.usageCount += 1
        entry.lastUsed = Date()
        frequencyCache.set(entry, forKey: key)
    }

    /// Clear in-memory frequency + recency state.
    ///
    /// The response cache and registered providers are unaffected — use
    /// ``clearCache()`` for the former and ``unregisterProvider(withId:)``
    /// for the latter.
    public func clearLearnedPatterns() {
        frequencyCache.removeAll()
    }
```

Note: `rankCombined` (Task 2) reads the cache inline; we deliberately do **not** add a `frequencyData(for:)` helper here. The reasons:

1. The snapshot needs both `usageCount` and `lastUsed` (for the recency tiebreaker within tier 3). A helper returning a single shape would leak both pieces and only be called from one place — cheaper to inline.
2. `LRUCache.get(_:)` promotes keys to MRU as a side effect. Building a snapshot via `get` inside a helper would reorder the linked list during snapshot construction, and the next `recordSelection` would have to fight that scrambling. Inlining keeps the side-effect surface contained.

If a third caller ever wants a frequency snapshot, extract it then.

- [ ] **Step 4: Run the test file — expect both cases to pass**

```bash
swift test --filter CompletionManagerLearningTests
```

Expected: PASS — `testRecordSelectionWithoutContextIsNoop` and `testClearLearnedPatternsIsIdempotent`.

- [ ] **Step 5: Build the rest of the framework — expect green**

```bash
swift build
```

Expected: build succeeds. (We haven't yet removed `SmartCompletionEngine`, which still compiles independently.)

- [ ] **Step 6: Run swiftlint — expect 0 violations**

```bash
swiftlint --fix && swiftlint
```

Expected: no violations.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionManager.swift Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift
git commit -m "CompletionManager: add in-memory frequency cache + recordSelection/clearLearnedPatterns"
```

---

## Task 2: Add `rankCombined` six-tier sort (TDD with 11 ranking cases)

**Files:**
- Test: `Tests/CodeEditorPluginTests/Completion/CompletionManagerRankingTests.swift` (create)
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` (add `rankCombined`, leave `sortAndDeduplicateItems` in place until Task 3)

Add the canonical sort as a pure private function. Tests call it via an `@testable` internal accessor so we don't need to wire it through `requestCompletions` yet — wiring happens in Task 3.

- [ ] **Step 1: Create the ranking test file**

Create `Tests/CodeEditorPluginTests/Completion/CompletionManagerRankingTests.swift`:

```swift
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

    // MARK: - sortText

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

    // MARK: - priority

    func testPriorityDescendingWhenNoSortText() {
        let manager = makeManager()
        let low = makeItem("alpha", priority: 1)
        let high = makeItem("beta", priority: 10)
        let ranked = manager.testOnly_rankCombined([low, high], context: makeContext())
        XCTAssertEqual(ranked.map(\.label), ["beta", "alpha"])
    }

    // MARK: - frequency

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

    // MARK: - relevance

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

    // MARK: - kind.defaultPriority

    func testKindDefaultPriorityTiebreaker() {
        let manager = makeManager()
        let snippet = makeItem("for_each", kind: .snippet)
        let keyword = makeItem("for", kind: .keyword)
        let ranked = manager.testOnly_rankCombined([snippet, keyword], context: makeContext())
        // .keyword (100) outranks .snippet (90) per CompletionItemKind.defaultPriority.
        XCTAssertEqual(ranked.map(\.label), ["for", "for_each"])
    }

    // MARK: - label

    func testLabelAlphabeticalFinalTiebreaker() {
        let manager = makeManager()
        let alpha = makeItem("alpha")
        let beta = makeItem("beta")
        let ranked = manager.testOnly_rankCombined([beta, alpha], context: makeContext())
        XCTAssertEqual(ranked.map(\.label), ["alpha", "beta"])
    }

    // MARK: - dedup

    func testDedupKeepsDistinctKindsWithSameLabel() {
        let manager = makeManager()
        let asClass = makeItem("Float", kind: .class)
        let asMethod = makeItem("Float", kind: .method)
        let ranked = manager.testOnly_rankCombined([asClass, asMethod], context: makeContext())
        XCTAssertEqual(ranked.count, 2)
    }

    func testDedupCollapsesIdenticalLabelAndKind() {
        let manager = makeManager()
        let a = makeItem("Float", kind: .class)
        let b = makeItem("Float", kind: .class)
        let ranked = manager.testOnly_rankCombined([a, b], context: makeContext())
        XCTAssertEqual(ranked.count, 1)
    }
}
```

- [ ] **Step 2: Run the file — expect a compile error**

```bash
swift test --filter CompletionManagerRankingTests
```

Expected: build error like `value of type 'CompletionManager' has no member 'testOnly_rankCombined'`.

- [ ] **Step 3: Add `rankCombined` + the two `testOnly_*` hooks to `CompletionManager`**

Modify `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`. Insert the new private method (and the two `internal` test hooks) inside the `// MARK: - Private Methods` block, immediately above the existing `sortAndDeduplicateItems` definition:

```swift
    // MARK: - Ranking

    /// Canonical six-tier sort applied to combined provider results.
    ///
    /// Tier order (each tier is a tiebreaker for the previous):
    /// 1. `sortText` ascending when both items have it; item-with-sortText
    ///    wins in mixed pairs; both-nil falls through.
    /// 2. `priority` descending.
    /// 3. session-frequency descending (`frequencyData[label]`).
    /// 4. `relevance(item:context:)` descending.
    /// 5. `kind.defaultPriority` descending.
    /// 6. `label.localizedCaseInsensitiveCompare` ascending.
    ///
    /// Dedup key is `"\(label):\(kind.rawValue)"` — kind-aware so
    /// `Float` (type) and `Float()` (initializer) both survive.
    private func rankCombined(
        _ items: [CompletionItemModel],
        context: CompletionContextModel
    ) -> [CompletionItemModel] {
        // Stage 1: dedup
        var seen = Set<String>()
        let unique = items.filter { item in
            let key = "\(item.label):\(item.kind.rawValue)"
            return seen.insert(key).inserted
        }

        // Stage 2: pre-compute the per-language frequency snapshot once.
        // Build both maps in a single walk — `usageCount` for tier 3a and
        // `lastUsed` for tier 3b (recency tiebreaker).
        //
        // Note: `LRUCache.get` promotes keys to MRU as a side effect. That's
        // fine here because we never use LRU position for ordering — `lastUsed`
        // captures recency explicitly. The promotion is harmless: it only
        // affects which key gets evicted next when the cache hits capacity.
        let prefix = "\(context.language.identifier):"
        var freq: [String: Int] = [:]
        var lastUsed: [String: Date] = [:]
        for key in frequencyCache.allKeys where key.hasPrefix(prefix) {
            guard let entry = frequencyCache.get(key) else { continue }
            let label = String(key.dropFirst(prefix.count))
            freq[label] = entry.usageCount
            lastUsed[label] = entry.lastUsed
        }

        // Stage 3: sort
        let sorted = unique.sorted { lhs, rhs in
            // 1. sortText asc — mixed pair: item with sortText wins.
            switch (lhs.sortText, rhs.sortText) {
            case let (lhsText?, rhsText?) where lhsText != rhsText:
                return lhsText < rhsText
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                break
            }

            // 2. priority desc
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }

            // 3a. frequency desc
            let lhsFreq = freq[lhs.label] ?? 0
            let rhsFreq = freq[rhs.label] ?? 0
            if lhsFreq != rhsFreq {
                return lhsFreq > rhsFreq
            }

            // 3b. recency desc when frequencies tie (and at least one item
            // has been selected before). Items that have never been selected
            // are equal at this sub-tier and fall through to relevance.
            if let lhsDate = lastUsed[lhs.label], let rhsDate = lastUsed[rhs.label], lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            if lastUsed[lhs.label] != nil && lastUsed[rhs.label] == nil {
                return true
            }
            if lastUsed[lhs.label] == nil && lastUsed[rhs.label] != nil {
                return false
            }

            // 4. relevance desc
            let lhsRelevance = relevance(for: lhs, context: context)
            let rhsRelevance = relevance(for: rhs, context: context)
            if lhsRelevance != rhsRelevance {
                return lhsRelevance > rhsRelevance
            }

            // 5. kind.defaultPriority desc
            if lhs.kind.defaultPriority != rhs.kind.defaultPriority {
                return lhs.kind.defaultPriority > rhs.kind.defaultPriority
            }

            // 6. label asc
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        // Stage 4: cap
        return Array(sorted.prefix(maxCompletions))
    }

    /// Additive of three relevance signals. Constants are duplicated from
    /// `CompletionRankingModel.RankingWeights` (a private nested enum, not
    /// accessible from outside that type). Drift between the two is
    /// intentional only if a future tier needs to diverge.
    private func relevance(
        for item: CompletionItemModel,
        context: CompletionContextModel
    ) -> Double {
        let word = context.currentWord.lowercased()
        let label = item.label.lowercased()
        var score = 0.0

        if !word.isEmpty {
            if label.hasPrefix(word) {
                score += 1.0
            }
            if label.contains(word) {
                score += 0.5
            }
        }

        // Kind-contextual heuristics.
        switch item.kind {
        case .method, .function:
            if context.lineText.contains("(") {
                score += 0.3
            }
        case .property, .variable:
            if context.lineText.contains(".") {
                score += 0.3
            }
        case .keyword:
            if context.lineTextBeforeCursor.trimmingCharacters(in: .whitespaces).isEmpty {
                score += 0.3
            }
        case .class, .struct, .enum:
            if context.lineText.contains(":") || context.lineText.contains("<") {
                score += 0.3
            }
        default:
            break
        }

        return score
    }

    // MARK: - Test Hooks

    /// Internal test hook — exposes `rankCombined` so unit tests can
    /// exercise the sort key in isolation from the request pipeline.
    /// Not part of the public API.
    internal func testOnly_rankCombined(
        _ items: [CompletionItemModel],
        context: CompletionContextModel
    ) -> [CompletionItemModel] {
        rankCombined(items, context: context)
    }

    /// Internal test hook — seeds `lastContext` without going through
    /// `requestCompletions(for:)`. Lets learning tests drive the frequency
    /// cache deterministically.
    internal func testOnly_setLastContext(_ context: CompletionContextModel) {
        lastContext = context
    }

```

- [ ] **Step 4: Run the ranking tests**

```bash
swift test --filter CompletionManagerRankingTests
```

Expected: all 11 cases pass.

- [ ] **Step 5: Run swiftlint and build**

```bash
swiftlint --fix && swiftlint && swift build
```

Expected: 0 violations, build green.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionManager.swift Tests/CodeEditorPluginTests/Completion/CompletionManagerRankingTests.swift
git commit -m "CompletionManager: add canonical six-tier rankCombined sort"
```

---

## Task 3: Wire `rankCombined` into the production pipeline + finish learning suite

**Files:**
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionManager.swift` (replace `sortAndDeduplicateItems` call with `rankCombined`, capture `lastContext` in `requestCompletions`, clear it in `cancelCurrentRequest`, delete the now-unused `sortAndDeduplicateItems`)
- Modify: `Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift` (add the remaining four behavioral cases)

Now `requestCompletions(for:)` ranks combined results via `rankCombined`, captures `lastContext` for `recordSelection`, and `cancelCurrentRequest` clears it. The four end-to-end learning cases verify the full loop.

- [ ] **Step 1: Add the four remaining learning cases**

Append the following to `Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift` inside the existing `final class CompletionManagerLearningTests: XCTestCase`. Add these tests after the existing two:

```swift
    // MARK: - Fixtures (additions)

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

    // MARK: - Behavioral tests

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
```

- [ ] **Step 2: Run the new cases — expect them to fail**

```bash
swift test --filter CompletionManagerLearningTests
```

Expected: at least `testRecordSelectionAfterRequestIncrementsFrequency`, `testRecordSelectionScopedByLanguage`, `testClearLearnedPatternsEmptiesState`, and `testCancelCurrentRequestClearsLastContext` fail because `requestCompletions(for:)` does not yet capture `lastContext` or apply `rankCombined`.

- [ ] **Step 3: Wire `lastContext` into `requestCompletions(for:)`**

Modify `Sources/CodeEditorPlugin/Completion/CompletionManager.swift`. Find `public func requestCompletions(for context: CompletionContextModel)` (around line 151). Replace the body's opening lines:

```swift
    public func requestCompletions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Cancel any existing request
        currentRequest?.cancel()

        // Check cache first if enabled
        if let cachedResult = getCachedResult(for: context) {
            return cachedResult
        }
```

with:

```swift
    public func requestCompletions(for context: CompletionContextModel) async throws -> CompletionResult {
        // Cancel any existing request
        currentRequest?.cancel()

        // Capture for recordSelection scoping; cleared on cancel.
        lastContext = context

        // Check cache first if enabled
        if let cachedResult = getCachedResult(for: context) {
            return cachedResult
        }
```

- [ ] **Step 4: Clear `lastContext` in `cancelCurrentRequest`**

In the same file, find `cancelCurrentRequest` (around line 321):

```swift
    public func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
        debouncer.cancelAllRequests()
    }
```

Replace with:

```swift
    public func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
        debouncer.cancelAllRequests()
        lastContext = nil
    }
```

- [ ] **Step 5: Replace `sortAndDeduplicateItems` with `rankCombined` in `processAndCacheResults`**

In the same file, find `processAndCacheResults` (around line 263). Locate:

```swift
        // Sort and deduplicate items
        let sortedItems = sortAndDeduplicateItems(allItems)
```

Replace with:

```swift
        // Apply the canonical six-tier rank (dedup + sort + maxCompletions cap).
        let sortedItems = rankCombined(allItems, context: context)
```

- [ ] **Step 6: Delete `sortAndDeduplicateItems`**

In the same file, find the entire method (around lines 334-356):

```swift
    private func sortAndDeduplicateItems(_ items: [CompletionItemModel]) -> [CompletionItemModel] {
        // Remove duplicates based on label and kind
        var seen = Set<String>()
        let unique = items.filter { item in
            let key = "\(item.label):\(item.kind.rawValue)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        // Sort by priority (desc), then by label (asc)
        return unique.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.kind.defaultPriority != rhs.kind.defaultPriority {
                return lhs.kind.defaultPriority > rhs.kind.defaultPriority
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

```

Delete it entirely (including the trailing blank line). `rankCombined` is now the sole final-stage sort.

- [ ] **Step 7: Run the full learning suite — expect all 7 cases to pass**

```bash
swift test --filter CompletionManagerLearningTests
```

Expected: PASS — 7 cases (`testRecordSelectionWithoutContextIsNoop`, `testClearLearnedPatternsIsIdempotent`, `testRecordSelectionAfterRequestIncrementsFrequency`, `testRecordSelectionScopedByLanguage`, `testClearLearnedPatternsEmptiesState`, `testCancelCurrentRequestClearsLastContext`, `testRecencyBreaksFrequencyTies`).

- [ ] **Step 8: Confirm ranking suite still passes**

```bash
swift test --filter CompletionManagerRankingTests
```

Expected: PASS — 11 cases.

- [ ] **Step 9: Build + lint**

```bash
swiftlint --fix && swiftlint && swift build
```

Expected: 0 violations, build green.

- [ ] **Step 10: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionManager.swift Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift
git commit -m "CompletionManager: route processAndCacheResults through rankCombined; track lastContext"
```

---

## Task 4: Add `EditorController.recordCompletionSelection(_:)` forwarder

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`

A thin forwarder that hosts can call directly. The editor-view auto-call (Task 5) is the primary path; this is the public surface for hosts that want to record selections from elsewhere (e.g., command-palette acceptance).

- [ ] **Step 1: Add the forwarder**

Modify `Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift`. Find the existing `completionEvents()` method (around line 60). Immediately after the existing closing brace of `completionEvents()` and before the final `}` of the extension, insert:

```swift

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
```

- [ ] **Step 2: Build + lint**

```bash
swiftlint --fix && swiftlint && swift build
```

Expected: 0 violations, build green.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift
git commit -m "EditorController: add recordCompletionSelection forwarder"
```

---

## Task 5: Wire the editor view's accept hook + add the wiring test

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift` (one-line insert inside `completionViewController(_:complete:movement:)`)
- Create: `Tests/CodeEditorPluginTests/Completion/CompletionViewWiringTests.swift`

When the user accepts a completion from the popup, the framework records the selection automatically. Verified behaviorally: drive the delegate method with a `CompletionItemAdapter`, then issue a follow-up request and assert the accepted label leads on frequency.

- [ ] **Step 1: Create the wiring test**

Create `Tests/CodeEditorPluginTests/Completion/CompletionViewWiringTests.swift`:

```swift
#if canImport(AppKit) || canImport(UIKit)
import Foundation
import XCTest

@testable import CodeEditorPlugin

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Asserts that `CodeEditorView.completionViewController(_:complete:movement:)`
/// auto-records the selection into the attached `CompletionManager`.
///
/// Spec: docs/superpowers/specs/2026-05-14-completion-ranking-unification-design.md.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class CompletionViewWiringTests: XCTestCase {
    struct StubProvider: CompletionProvider {
        let id = "wiring.stub"
        let supportedLanguages: [Language] = []
        let triggerCharacters: [String] = []
        let supportsSnippets = false
        let labels: [String]

        @MainActor
        func completions(for context: CompletionContextModel) async throws -> CompletionResult {
            let items = labels.map { label in
                CompletionItemModel(label: label, insertText: label, kind: .text)
            }
            return CompletionResult(items: items, context: context)
        }
    }

    /// Stand-in `CompletionViewControllerRepresentable` passed as the first
    /// argument to the delegate method. Never displayed; only needs to
    /// satisfy the protocol so the delegate-method call typechecks.
    ///
    /// `CompletionViewControllerRepresentable` refines `PlatformViewController`
    /// (`NSViewController` on macOS, `UIViewController` on iOS) and exposes
    /// `items` (mutable) + `delegate` (weak). See
    /// `Sources/CodeEditorPlugin/Completion/CompletionViewControllerRepresentable.swift`.
    final class DummyController: PlatformViewController, CompletionViewControllerRepresentable {
        var items: [any CompletionItemView] = []
        weak var delegate: CompletionViewControllerDelegate?
    }

    func testAcceptingItemRecordsSelectionOnManager() async throws {
        let view = CodeEditorView(frame: .zero)
        let manager = view.completionManager
        manager.registerProvider(StubProvider(labels: ["alpha", "beta"]))

        let ctx = CompletionContextModel(text: "", cursorPosition: 0, language: .swift)

        // First request seeds lastContext and proves the baseline order.
        let first = try await manager.requestCompletions(for: ctx)
        XCTAssertEqual(first.items.map(\.label), ["alpha", "beta"])

        // Drive the delegate twice with "beta" — same call path the
        // completion popup uses when the user presses return.
        let item = CompletionItemModel(label: "beta", insertText: "beta", kind: .text)
        let adapter = CompletionItemAdapter(item)
        let stub = DummyController()
        view.completionViewController(stub, complete: adapter, movement: .return)
        view.completionViewController(stub, complete: adapter, movement: .return)

        // Re-request; "beta" now leads on frequency.
        let second = try await manager.requestCompletions(for: ctx)
        XCTAssertEqual(second.items.map(\.label), ["beta", "alpha"])
    }
}
#endif
```

> Note: `NSViewController` / `UIViewController` subclass init must satisfy `init(nibName:bundle:)`. The default `init()` from the inherited initializer chain is sufficient here — Swift synthesizes it. If a build error appears about a missing designated initializer (rare in test contexts), add `override init(nibName: NSNib.Name? = nil, bundle: Bundle? = nil) { super.init(nibName: nibName, bundle: bundle) }` and `required init?(coder: NSCoder) { fatalError("DummyController coder init unused") }` inside the macOS branch, mirrored for iOS.

- [ ] **Step 2: Run the test — expect failure**

```bash
swift test --filter CompletionViewWiringTests
```

Expected: failure — the assertion `["beta", "alpha"]` fails because the delegate method doesn't yet call `recordSelection`.

- [ ] **Step 3: Add the `recordSelection` call to the delegate**

Modify `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift`. Find `completionViewController(_:complete:movement:)` (around line 174):

```swift
    public func completionViewController(
        _: some CompletionViewControllerRepresentable,
        complete item: any CompletionItemView,
        movement _: PlatformTextMovement
    ) {
        // Get the insert text based on the item type
        let textToInsert: String
        if let adapter = item as? CompletionItemAdapter {
            textToInsert = adapter.model.insertText
        } else {
            // Fallback - use a default or empty string
            textToInsert = ""
        }

        // Insert the completion text if not empty
        if !textToInsert.isEmpty {
            insertText(textToInsert)
        }

        // Hide the completion window
        hideCompletionPopup()
    }
```

Replace with:

```swift
    public func completionViewController(
        _: some CompletionViewControllerRepresentable,
        complete item: any CompletionItemView,
        movement _: PlatformTextMovement
    ) {
        // Get the insert text based on the item type
        let textToInsert: String
        if let adapter = item as? CompletionItemAdapter {
            textToInsert = adapter.model.insertText
            // Auto-record the acceptance so the manager's frequency cache
            // reflects user behavior without forcing the host to wire it up
            // manually. See spec 2026-05-14-completion-ranking-unification.
            completionManager.recordSelection(adapter.model)
        } else {
            // Fallback - use a default or empty string
            textToInsert = ""
        }

        // Insert the completion text if not empty
        if !textToInsert.isEmpty {
            insertText(textToInsert)
        }

        // Hide the completion window
        hideCompletionPopup()
    }
```

- [ ] **Step 4: Run the wiring test — expect pass**

```bash
swift test --filter CompletionViewWiringTests
```

Expected: PASS.

- [ ] **Step 5: Confirm prior suites still pass**

```bash
swift test --filter "Completion"
```

Expected: PASS — all ranking, learning, wiring, event-stream cases plus any sample-side tests under the Completion subdirectory.

- [ ] **Step 6: Build + lint**

```bash
swiftlint --fix && swiftlint && swift build
```

Expected: 0 violations, build green.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift Tests/CodeEditorPluginTests/Completion/CompletionViewWiringTests.swift
git commit -m "CodeEditorView: auto-record completion selection on accept"
```

---

## Task 6: Delete `SmartCompletionEngine` and the dead public types around it

**Files:**
- Delete: `Sources/CodeEditorPlugin/Completion/SmartCompletionEngine.swift`
- Modify: `Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift` (remove `CompletionMLModel` protocol + `NeuralCompletionRanker` struct)
- Modify: `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift` (delete `testCompletionProvidersRegistration` + the `extension SmartCompletionEngine { hasCompletionProvider(...) }` helper)
- Modify: `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift` (delete `testSmartCompletionEnginePerformance`)

`SmartCompletionEngine` has no production callers and its in-tree test references are easy to delete. `CompletionMLModel` + `NeuralCompletionRanker` are speculative public surface with zero conformers; they live inside `CompletionRankingModel.swift` and need to come out separately because the file itself stays.

- [ ] **Step 1: Delete the engine file**

```bash
git rm Sources/CodeEditorPlugin/Completion/SmartCompletionEngine.swift
```

- [ ] **Step 2: Remove `CompletionMLModel` + `NeuralCompletionRanker` from the ranking model file**

Modify `Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift`. Locate the trailing block starting around line 152 (`// MARK: - Machine Learning Integration` through end of file) — every line from `// MARK: - Machine Learning Integration` to the final closing brace (just the speculative ML types):

```swift
// MARK: - Machine Learning Integration

/// Protocol for future ML model integration
public protocol CompletionMLModel {
    /// Predict relevance scores for completion items
    /// - Parameters:
    ///   - items: The completion items
    ///   - context: The current context
    /// - Returns: Dictionary mapping item labels to predicted scores
    func predictScores(for items: [CompletionItemModel], context: CompletionContextModel) async -> [String: Double]
}

/// Placeholder for neural network-based ranking
public struct NeuralCompletionRanker: CompletionMLModel {
    public init() {}

    public func predictScores(for _: [CompletionItemModel], context _: CompletionContextModel) async -> [String: Double] {
        // TODO: Integrate with CoreML or CreateML model
        // For now, return empty scores
        [:]
    }
}
```

Delete that entire block. The file should now end immediately after the closing brace of `CompletionRankingModel`.

- [ ] **Step 3: Run `swift build` — expect compile failures in the two test files**

```bash
swift build
```

Expected: build succeeds (no production callers of the deleted types).

```bash
swift test --filter LanguageDetectionTests
```

Expected: build error like `cannot find 'SmartCompletionEngine' in scope` referencing `LanguageDetectionTests.swift`.

- [ ] **Step 4: Strip the dead pieces from `LanguageDetectionTests.swift`**

Modify `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift`. Find and delete the entire `testCompletionProvidersRegistration` method (around lines 194-232) — from the `// MARK: - Completion Provider Integration Tests` comment through the closing brace of the method.

In the same file, find and delete the trailing helper extension (around lines 444-452):

```swift
// MARK: - Test Helper Extensions

extension SmartCompletionEngine {
    func hasCompletionProvider(for _: String) -> Bool {
        // This is a simplified check - in a real implementation,
        // you might need to access internal state or provide a public method
        true // Assuming all registered providers are available
    }
}
```

Delete that block entirely (including the `// MARK: - Test Helper Extensions` comment if no other test helpers live below).

- [ ] **Step 5: Strip `testSmartCompletionEnginePerformance` from `ComprehensivePerformanceTests.swift`**

Modify `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift`. Find and delete (around lines 41-59):

```swift
    @MainActor
    func testSmartCompletionEnginePerformance() throws {
        // Test the fuzzy matcher component, which is a key part of SmartCompletionEngine.
        // The engine itself has complex async initialization that's hard to test in isolation.
        let fuzzyMatcher = OptimizedFuzzyMatcher()
        _ = SmartCompletionEngine(memoryMonitor: MemoryMonitor()) // Test that it can be instantiated

        // Generate test data
        let candidates = ["String", "StringProtocol", "Substring", "StaticString", "StringLiteralType"]
        let pattern = "Str"

        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<100 {
                let results = fuzzyMatcher.matchSequential(pattern: pattern, candidates: candidates)
                XCTAssertFalse(results.isEmpty)
            }
        }
    }
```

Replace it with an equivalent test that exercises only the surviving fuzzy matcher (since `OptimizedFuzzyMatcher` was the only thing the old test actually measured — the `SmartCompletionEngine` instantiation was a no-op):

```swift
    @MainActor
    func testOptimizedFuzzyMatcherShortPatternPerformance() throws {
        // Lifted from the previous testSmartCompletionEnginePerformance —
        // the engine instantiation was a no-op; the measurement was on
        // OptimizedFuzzyMatcher. Engine deleted in the completion-ranking
        // unification batch; this preserves the perf signal.
        let fuzzyMatcher = OptimizedFuzzyMatcher()
        let candidates = ["String", "StringProtocol", "Substring", "StaticString", "StringLiteralType"]
        let pattern = "Str"

        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<100 {
                let results = fuzzyMatcher.matchSequential(pattern: pattern, candidates: candidates)
                XCTAssertFalse(results.isEmpty)
            }
        }
    }
```

- [ ] **Step 6: Build + lint + run touched test suites**

```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build green, 0 violations.

```bash
swift test --filter "LanguageDetection|ComprehensivePerformance|Completion"
```

Expected: PASS for all touched suites.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift Tests/CodeEditorPluginTests/LanguageDetectionTests.swift Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift
git commit -m "Delete SmartCompletionEngine + speculative ML types; drop test references"
```

(The earlier `git rm` of `SmartCompletionEngine.swift` is included automatically in this commit because it was staged.)

---

## Task 7: Fix the red sample test `DemoCompletionProviderTests`

**Files:**
- Modify: `Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift`

The sample's `DemoCompletionProvider` was extended to a 5-item `SnippetTemplate` catalog in commit `db5c824`, but the test still asserts a 3-item subset. This has been red across multiple recent batches; clean it up while we're in the area.

- [ ] **Step 1: Verify the sample's current snippet labels**

```bash
grep -A 7 "private static let snippets" Sources/CodeEditorSample/App/Completion/DemoCompletionProvider.swift
```

Expected output includes the five labels: `TODO:`, `MARK:`, `FIXME:`, `NOTE:`, `WARNING:`.

- [ ] **Step 2: Update the test expectation**

Modify `Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift`. Locate (around line 10):

```swift
    @Test("returns three demo items on any language")
    func returnsThreeItems() async throws {
        let provider = DemoCompletionProvider()

        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .swift
        )
        let result = try await provider.completions(for: context)

        let labels = result.items.map(\.label).sorted()
        #expect(labels == ["FIXME:", "MARK:", "TODO:"])
    }
```

Replace with:

```swift
    @Test("returns the full snippet catalogue on any language")
    func returnsFullCatalogue() async throws {
        let provider = DemoCompletionProvider()

        let context = CompletionContextModel(
            text: "",
            cursorPosition: 0,
            language: .swift
        )
        let result = try await provider.completions(for: context)

        let labels = result.items.map(\.label).sorted()
        #expect(labels == ["FIXME:", "MARK:", "NOTE:", "TODO:", "WARNING:"])
    }
```

- [ ] **Step 3: Run the test**

```bash
swift test --filter DemoCompletionProvider
```

Expected: PASS.

- [ ] **Step 4: Build + lint**

```bash
swift build && swiftlint --fix && swiftlint
```

Expected: build green, 0 violations.

- [ ] **Step 5: Commit**

```bash
git add Tests/CodeEditorSampleTests/DemoCompletionProviderTests.swift
git commit -m "Sample test: align DemoCompletionProvider expectation with 5-item snippet catalogue"
```

---

## Task 8: Final verification + REVIEW.md status entry

**Files:**
- Modify: `REVIEW.md`

Run the full verification gate and update REVIEW.md to mark the unification landed.

- [ ] **Step 1: Targeted test pass**

```bash
swift test --filter "Completion"
```

Expected: PASS — `CompletionManagerRankingTests` (11), `CompletionManagerLearningTests` (7), `CompletionViewWiringTests` (1), `CompletionEventStreamTests` (existing 6), `DemoCompletionProviderTests` (3), and any other Completion-prefixed suites.

- [ ] **Step 2: Full parallel pass**

```bash
swift test --parallel
```

Expected: PASS except for the pre-existing failures documented in the spec's "Pre-existing failures" section:
- `RegexRangeHighlightProviderTests.testParsePerformance100KLines`
- `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`
- `EditorStatusBarSnapshots/*` parallel SIGSEGV/SIGBUS
- `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`
- `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`

Any failure outside that list is a regression — stop and triage. **Do not** mark the task complete with a regression in flight.

- [ ] **Step 3: Manual smoke test**

```bash
swift run CodeEditorSample
```

In the sample, with a Swift file open:

1. Trigger completion (e.g., `⌃ Space` or type a trigger character).
2. Accept the `TODO:` snippet from `DemoCompletionProvider`. Repeat: trigger completion and accept `TODO:` once more.
3. Trigger completion again with an empty prefix.

Expected: `TODO:` now ranks ahead of the four other equally-prioritized snippets, even though it's alphabetically third. Confirms `recordSelection` → `frequencyData` → `rankCombined` end-to-end in production.

Close the sample app cleanly (`⌘Q`).

- [ ] **Step 4: Add the REVIEW.md status entry**

Modify `REVIEW.md`. Find the "What's left after this round" subsection (around line 521). Locate the bullet:

```markdown
- **Three completion ranking pipelines disagree** — `CompletionManager.sortAndDeduplicateItems` vs `CompletionRankingModel.rank` vs `SmartCompletionEngine.rerank`. Pick one canonical scoring algorithm.
```

Replace it with:

```markdown
- ~~**Three completion ranking pipelines disagree** — `CompletionManager.sortAndDeduplicateItems` vs `CompletionRankingModel.rank` vs `SmartCompletionEngine.rerank`. Pick one canonical scoring algorithm.~~ ✅ Landed in the Completion ranking unification batch on 2026-05-14. `CompletionManager` is the single funnel; the new private `rankCombined` runs a six-tier sort (sortText → priority → frequency → relevance → kind.defaultPriority → label) on combined results; `recordSelection(_:)` / `clearLearnedPatterns()` provide in-memory learning (persistence deferred). `SmartCompletionEngine`, `CompletionError`, `CompletionSelection`, `CompletionFrequency`, `SmartCompletionSettings`, `CompletionMLModel`, and `NeuralCompletionRanker` deleted. Spec at `docs/superpowers/specs/2026-05-14-completion-ranking-unification-design.md`; plan at `docs/superpowers/plans/2026-05-14-completion-ranking-unification.md`.
```

(Match the surrounding formatting style — `~~struck-through original~~` then `✅ Landed in the …` plus a short summary, then the spec/plan paths. Other items in this section use the same pattern.)

- [ ] **Step 5: Commit the REVIEW.md update**

```bash
git add REVIEW.md
git commit -m "Update REVIEW.md: Completion ranking unification batch landed"
```

- [ ] **Step 6: Final summary check**

```bash
git log --oneline -10
```

Expected: 8 new commits on top of `b061127` covering — foundation state, rankCombined, production wiring, EditorController forwarder, editor-view wiring, deletion sweep, sample test fix, REVIEW.md update.

---

## Out of scope (deliberately deferred — do not implement)

These items are documented in the spec's "Follow-ups" section and require separate design conversations:

- Persistence of frequency/recency across launches (host-supplied `CompletionLearningStore` protocol).
- LSP-aware ranking improvements (clangd-style multi-step relevance).
- `CompletionMLModel` rewiring (deleted now, slotted in as Stage 4 override when neural scoring returns).
- `CompletionRankingModel.applyUsageBoosts` audit.
- LSP iOS coverage (separate item on the "What's left after this round" list).
