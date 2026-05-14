# Completion ranking unification — design

**Status:** Proposed (2026-05-14)
**Closes:** REVIEW.md "Three independent completion ranking pipelines disagree" — `CompletionManager.sortAndDeduplicateItems` vs `CompletionRankingModel.rank` vs `SmartCompletionEngine.rerank` (REVIEW.md:434, 527).

## Problem

The framework ships three apparently-parallel completion ranking surfaces:

1. `CompletionManager.sortAndDeduplicateItems` (`Sources/CodeEditorPlugin/Completion/CompletionManager.swift:334`) — production funnel. Sort key: `item.priority` desc → `kind.defaultPriority` desc → `label` asc. Dedup key: `label:kind.rawValue`. No fuzzy, no context, no frequency, no recency.
2. `CompletionRankingModel.rank` (`Sources/CodeEditorPlugin/Completion/CompletionRankingModel.swift:33`) — pluggable helper. Sort key: `sortText` asc → `frequencyData` desc → `calculateRelevance` (prefix/contains/kind-contextual) desc → `label` asc.
3. `SmartCompletionEngine.combineAndRank` (`Sources/CodeEditorPlugin/Completion/SmartCompletionEngine.swift:287`) — orphan engine. Runs fuzzy match → label-only dedup → delegates to `CompletionRankingModel.rank` (which discards the fuzzy ordering by re-sorting).

The "three pipelines disagree" framing is misleading. Two are intentionally layered: `CompletionRankingModel.rank` is the public per-provider recipe (sample's `DemoCompletionProvider:63` uses it that way), and `CompletionManager.sortAndDeduplicateItems` is the final combine step downstream. The third (`SmartCompletionEngine`) is a parallel orphan with no production callers — only `LanguageDetectionTests.swift:197` and `ComprehensivePerformanceTests.swift:47` instantiate it, neither asserting anything about ranking behavior. `SmartCompletionEngine.loadUserPatterns`/`saveUserPatterns` (lines 436–444) are empty stubs; the "learning" doesn't survive a process restart even when used.

The real problems are:

- **`SmartCompletionEngine` is dead public API** that duplicates `CompletionManager`'s role with a more sophisticated (but unused) algorithm.
- **`CompletionManager`'s combined-result sort is structurally weaker than its own per-provider helper.** Two providers that each pre-rank via `CompletionRankingModel` get their results re-sorted by the coarser `priority/kind/label` key when the manager combines them. There is no canonical ranking algorithm at the funnel.

## Goals

- Single completion engine in the framework. `CompletionManager` stays the canonical name (already wired into production via `EditorController.registerCompletionProvider`); `SmartCompletionEngine` is deleted.
- One canonical sort key applied at the funnel — incorporating `sortText`, explicit `priority`, in-session frequency, prefix/contains/kind-contextual relevance, kind default priority, and alphabetical tiebreak.
- Public `recordSelection(_:)` on `CompletionManager` (and forwarder on `EditorController`) so the framework can learn from accepted completions.
- In-memory only — no persistence in this round. Frequency/recency reset on process restart.
- Strictly additive on the surviving public API (`CompletionManager`, `EditorController`). All breakage is the deletion of dead-public-API supporting types around `SmartCompletionEngine`.

## Non-goals

- Persistence of frequency/recency across launches. Deferred — would want a host-supplied `CompletionLearningStore` protocol matching the framework's no-singletons convention. Documented as a follow-up.
- Re-introducing fuzzy matching at the manager layer. LSP and the sample's `DemoCompletionProvider` already filter inside `completions(for:)`; manager-side fuzzy would double-filter and discard server ordering.
- Reconciling per-provider ranking implementations across the ecosystem (e.g., clangd-style multi-step relevance). Out of scope.
- Reviving `CompletionMLModel` / `NeuralCompletionRanker`. Speculative public API with zero conformers; deleted with no replacement.
- Backward-compatibility shims for `SmartCompletionEngine`. The class has no production callers; clean deletion.

## Architecture

### Single funnel — keep `CompletionManager`

`CompletionManager` is the production type that every host already uses through `EditorController.registerCompletionProvider`. The "smart" semantics — frequency/recency cache, canonical ranking, selection recording — move onto it. `SmartCompletionEngine` is deleted along with its associated public types. `CompletionRankingModel` stays public because the sample's `DemoCompletionProvider:39,63` uses it as the documented per-provider ranking recipe; per-provider ranking and manager-side ranking remain *layered*, not collapsed. The manager has its own private `rankCombined(_:context:)` whose tier order is a superset of `CompletionRankingModel.rank`'s — it adds explicit `item.priority` and `kind.defaultPriority` tiers that the per-provider helper doesn't carry. The two paths share *intent* but not implementation; each is the right tool for its layer.

### Pipeline shape

```
provider.completions(for:)            (per provider — may pre-rank via CompletionRankingModel)
  └── CompletionManager.collectResultsConcurrently
       └── processAndCacheResults
            ├── flatten results
            ├── rankCombined(_:context:)          ← new canonical stage
            │   ├── dedupKeyed                    (label:kind.rawValue)
            │   ├── multi-tier sort               (sortText → priority → freq → relevance → kind → label)
            │   └── prefix(maxCompletions)
            └── cache + statistics
```

### Canonical sort key

Strict tier order; each tier is a tiebreaker for the previous.

1. **`sortText` ascending** — when both items have a non-nil `sortText`. Mixed pair (one has, one doesn't): item-with-sortText wins. Both nil: skip to next tier. (Preserves LSP server ordering.)
2. **`item.priority` descending** — explicit provider override (snippets bumping themselves above keywords, etc.).
3. **`frequencyData[label]` descending** — session-frequency boost. The frequency map is built per-request and scoped to `context.language`. Recency-within-frequency is implicit: the `LRUCache` returns keys in LRU order, so when two labels tie on `usageCount`, the more recent one ranks higher.
4. **`relevance(item:context:)` descending** — additive of three signals. Constants are duplicated from `CompletionRankingModel.RankingWeights` (a private nested enum, not accessible from outside that type); the manager keeps its own private constants. Drift between the two is intentional only if a future tier needs to diverge — flag in code review if the two get out of sync without reason.
   - `+1.0` if `label.lowercased().hasPrefix(context.currentWord.lowercased())`
   - `+0.5` if `label.lowercased().contains(context.currentWord.lowercased())`
   - `+0.3` kind-contextual:
     - `.method`/`.function` when `context.lineText` contains `(`
     - `.property`/`.variable` when `context.lineText` contains `.`
     - `.keyword` when `linePrefix.trimmingCharacters(in: .whitespaces)` is empty
     - `.class`/`.struct`/`.enum` when `context.lineText` contains `:` or `<`
5. **`kind.defaultPriority` descending** — snippet > keyword > etc.
6. **`label.localizedCaseInsensitiveCompare` ascending** — final stable tiebreaker.

### Dedup

Key: `"\(item.label):\(item.kind.rawValue)"`. Kind-aware so `Float` (type) and `Float()` (initializer) both survive. (Matches the existing `CompletionManager.sortAndDeduplicateItems:338` behavior. `SmartCompletionEngine.removeDuplicates`'s label-only dedup is rejected.)

### Frequency / recency state

`CompletionManager` gains:

```swift
private struct FrequencyEntry {
    var usageCount: Int
    var lastUsed: Date
}

private let frequencyCache: LRUCache<String, FrequencyEntry>  // capacity 500
private var lastContext: CompletionContextModel?
```

Key shape: `"\(language.identifier):\(label)"` (matches `SmartCompletionEngine`'s scheme).

- `requestCompletions(for:)` writes `self.lastContext = context` before fanning out.
- `cancelCurrentRequest()` clears `lastContext`.
- `recordSelection(_:)` reads `lastContext` (no-op if nil), constructs the key, and either inserts a new entry or increments the existing one (`usageCount += 1`, `lastUsed = Date()`). `LRUCache.set` moves the entry to MRU.
- `processAndCacheResults` builds a `[String: Int]` snapshot from `frequencyCache` keys whose prefix matches `context.language.identifier`, strips the prefix, and passes it to `rankCombined`. Same shape `CompletionRankingModel.rank` expects today.

Capacity 500 matches `SmartCompletionEngine`'s setting. No persistence in this round.

### `recordSelection` wiring path

The completion view controller delegate already exists. `CodeEditorView+PlatformSpecificExtensions.swift:174` — `completionViewController(_:complete:movement:)` — gains a single line before the existing `insertText`:

```swift
if let adapter = item as? CompletionItemAdapter {
    completionManager?.recordSelection(adapter.model)
}
```

`completionManager` is already plumbed through runtime dependencies; no new injection point.

### Concurrency

`CompletionManager` stays `@MainActor` (unchanged). `FrequencyEntry` is `Sendable` (value type with `Int` + `Date`). `lastContext` is mutated only on `@MainActor` paths. The new `frequencyCache` uses the same `LRUCache` slot pattern that already holds `CachedCompletionResult` — its synchronization story is unchanged.

## Public API delta

### Added on `CompletionManager`

```swift
/// Maximum items returned from requestCompletions. Default 50.
public var maxCompletions: Int

/// Record that the user accepted this item. Updates the in-memory
/// frequency/recency caches used by the next requestCompletions call's
/// ranking pass. No-op if no completion context is currently active.
public func recordSelection(_ item: CompletionItemModel)

/// Clear in-memory frequency + recency state. Cache and registered
/// providers are unaffected (use clearCache() / unregisterProvider for those).
public func clearLearnedPatterns()
```

### Added on `EditorController`

```swift
/// Record a completion acceptance. Forwards to the attached manager's
/// recordSelection. No-op when unattached or no manager is configured.
public func recordCompletionSelection(_ item: CompletionItemModel)
```

Lives in `EditorController+Completion.swift` next to `completionEvents()`.

### Unchanged public surface

- `CompletionManager.{requestCompletions, events, registerProvider, unregisterProvider, cancelCurrentRequest, clearCache, cacheStatistics, registeredProviders, debouncingConfiguration, requestCompletionsDebounced}` — no signature changes.
- `CompletionRankingModel` — fully retained as the documented per-provider ranking recipe.
- `CompletionContextModel`, `CompletionItemModel`, `CompletionResult`, `CompletionProvider`, `CompletionCacheKey`, `CompletionPriority`, `SnippetTemplate`, `CompletionProviderUtilities`, `CompletionEvent`, `CompletionEventBroadcaster` — untouched.

### Removed public surface (source-breaking)

| Symbol | File | Justification |
|---|---|---|
| `SmartCompletionEngine` | `SmartCompletionEngine.swift:18` | Test-only callers; no production wire-up |
| `CompletionError` | `SmartCompletionEngine.swift:8` | Only thrown by `SmartCompletionEngine` |
| `CompletionSelection` | `SmartCompletionEngine.swift:473` | Folded into private `FrequencyEntry` |
| `CompletionFrequency` | `SmartCompletionEngine.swift:461` | Folded into private `FrequencyEntry` |
| `SmartCompletionSettings` | `SmartCompletionEngine.swift:480` | `maxCompletions` migrates; rest drop (no consumers) |
| `CompletionMLModel` | `CompletionRankingModel.swift:155` | Speculative; zero conformers |
| `NeuralCompletionRanker` | `CompletionRankingModel.swift:165` | Same |

Members of `SmartCompletionEngine` (public methods like `getSmartSuggestions(for:)` and `recordSelection(_:context:)`, private helpers like `setupDefaultProviders`, `getPatternBasedSuggestions`, `getRecentlyUsedCompletions`, `getFrequentlyUsedCompletions`, `loadUserPatterns`/`saveUserPatterns`, and the private `CompletionSession` struct) are all deleted along with the class. None had production callers; the `recordSelection(_:context:)` shape is reborn as the simpler `CompletionManager.recordSelection(_:)` (no context parameter — uses captured `lastContext`).

`CompletionRankingModel.applyUsageBoosts` — currently unreferenced inside the framework. Keep public for parity with `rank`; document as "available for hosts that want to score outside the standard tier order." Re-evaluate in a follow-up.

## Migration

### In-tree consumers

| Site | Change |
|---|---|
| `Tests/CodeEditorPluginTests/LanguageDetectionTests.swift:197, 446` | Decide per-test: if the assertion is genuinely about the engine's behavior, migrate to `CompletionManager`; if it was only proving the engine instantiated, delete |
| `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift:43-47` | `testSmartCompletionEnginePerformance` only asserts instantiation. Delete |
| `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift:174` | Add the `recordSelection` call described in "Wiring path" above |

### Sample

`CompletionSampleCoordinator.attach(controller:)` does **not** need to call `controller.recordCompletionSelection` itself — the framework records the selection automatically when the view controller delegate fires. Document the automatic behavior in the existing inline comments. Hosts that want to surface "I'm tracking this" externally can call the public forwarder.

`Tests/CodeEditorSampleTests/DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage` — currently red (asserts 3 labels, source returns 5). Fix the count expectation in the same PR as a side-job. Not strictly part of the unification, but it's been red for several batches and this PR touches the area.

### Out-of-tree consumers

The deleted public types had no production callers in this tree, and the framework hasn't shipped externally yet, so the migration story for outside hosts is captured in the eventual REVIEW.md status entry rather than a deprecation cycle: delete imports of `SmartCompletionEngine`, `CompletionError`, `CompletionSelection`, `CompletionFrequency`, `SmartCompletionSettings`, `CompletionMLModel`, and `NeuralCompletionRanker`. Replace usage with `CompletionManager`.

## Testing

### New test suites

**`Tests/CodeEditorPluginTests/Completion/CompletionManagerRankingTests.swift`**
- `sortText_wins_when_both_present`
- `sortText_mixed_pair_with_set_wins`
- `priority_descending_when_no_sortText`
- `frequency_descending_when_priority_equal`
- `relevance_prefix_match_wins`
- `relevance_kind_contextual_method_in_paren`
- `relevance_kind_contextual_type_after_colon`
- `kind_default_priority_tiebreaker`
- `label_alphabetical_final_tiebreaker`
- `dedup_keeps_distinct_kinds_with_same_label`
- `dedup_collapses_identical_label_and_kind`

**`Tests/CodeEditorPluginTests/Completion/CompletionManagerLearningTests.swift`**
- `recordSelection_no_context_is_noop`
- `recordSelection_after_request_increments_frequency`
- `recordSelection_scoped_by_language`
- `clearLearnedPatterns_empties_state`
- `cancelCurrentRequest_clears_lastContext`
- `recency_lru_breaks_frequency_ties`

**Editor-view wiring** — extend existing completion tests under `Tests/CodeEditorPluginTests/Completion/`:
- `acceptingItem_records_selection_on_manager` — drive `completionViewController(_:complete:movement:)` with a `CompletionItemAdapter`; verify the manager's frequency state reflects the selection by issuing a follow-up `requestCompletions` and asserting the accepted label ranks ahead of an equally-prioritized peer. (`CompletionManager` is `final`, so verification is behavioral, not via a mock — the plan will work out the exact assertion shape.)

### Snapshot tests

`CompletionInspectorPanelSnapshotTests` — re-run after the migration. Expected stable (no UI changes). If a diff appears it's because the new ranking surfaces different items; re-record and commit.

### Pre-existing failures (must reproduce unchanged on `main`)

- `RegexRangeHighlightProviderTests.testParsePerformance100KLines` — flake.
- `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`.
- `EditorStatusBarSnapshots/*` — parallel SIGSEGV/SIGBUS.
- `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`.
- `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`.

### Verification gate

- `swift build` — green.
- `swiftlint --fix && swiftlint` — 0 violations.
- `swift test --filter "Completion"` — new ranking + learning suites, the editor-view wiring test, and the fixed `DemoCompletionProviderTests` all pass.
- `swift test --parallel` — no regressions beyond the pre-existing list above.
- Manual smoke test: `swift run CodeEditorSample`, request completions in a sample Swift file, accept one item twice, type its prefix again — verify the accepted item ranks first.

## Error handling

The new code is failure-free by construction:

- `rankCombined(_:context:)` — pure function over `[CompletionItemModel]`; total.
- `recordSelection(_:)` — `lastContext == nil` → no-op + `logger.debug`. Cache writes can't fail (in-memory LRU).
- `clearLearnedPatterns()` — synchronous cache clear; no failure mode.
- `FrequencyEntry` mutations — actor-isolated to `CompletionManager` (already `@MainActor`).

The deleted `CompletionError` enum had three cases (`engineUnavailable`, `contextInvalid`, `providerFailed`); none had production throwers. No replacement enum needed.

## Follow-ups (deliberately deferred)

- **Persistence of frequency/recency across launches.** Would need a host-supplied `CompletionLearningStore` protocol matching the framework's no-singletons convention (host owns I/O — UserDefaults, file, iCloud — through a Sendable interface). Spec it separately when there's a concrete demand.
- **LSP-aware ranking improvements.** Pure-Swift heuristics are good enough for now. clangd-style multi-step relevance (semantic kind, type-equality, signature compatibility) is its own design conversation.
- **`CompletionMLModel` rewiring.** If neural scoring comes back, it slots in as a Stage 4 override in front of the relevance stage — not as a peer engine. Deleted now; not blocked.
- **`CompletionRankingModel.applyUsageBoosts` audit.** Currently unreferenced. Keep public for parity with `rank` in this round; re-evaluate after the unification lands.
- **REVIEW.md note on the "What's left after this round" section.** Add a "✅ Landed" entry naming the deleted symbols and pointing at this spec.
