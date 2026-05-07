# CodeEditorPlugin Editor-Core Improvement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Bring the strongest CodeEditSourceEditor architectural lessons into CodeEditorPlugin without breaking CodeEditorPlugin's cross-platform API, Swift 6 strict-concurrency posture, or existing service architecture.

**Architecture:** The migration is gated. First validate risky assumptions, then build shared range storage, then migrate highlighting, folding, minimap, and parser-backed features behind adapters and feature flags. CodeEditSourceEditor is a reference, not a source to copy wholesale.

**Tech Stack:** Swift 6.3, Swift Package Manager, TextKit/TextKit2, SwiftSyntax, optional SwiftTreeSitter evaluation, AppKit/UIKit conditional compilation, existing CodeEditorPlugin services.

---

## Current Corrections From Review

These corrections supersede the earlier version of this plan.

- `MinimapViewModel` and `MinimapView` live under `Sources/CodeEditorPlugin/Layout`, not `Sources/CodeEditorPlugin/Features`.
- There is no `TextStorageCoordinator`. Text edit observation currently flows through notification handlers such as `CodeEditorView.handleTextStorageDidProcessEditing(_:)`.
- CodeEditorPlugin does not have CodeEditTextView's `TextAttachment` base class or `layoutManager.attachments.add/remove` APIs. Folding placeholders require a local TextKit/TextKit2 strategy.
- Tree-sitter should be evaluated before finalizing highlighting and folding provider interfaces, because parser capabilities affect those protocols.
- `EditorInteractionState` should start as a separate state object. Do not put it directly into `EditorState` until lifecycle and feedback-loop behavior are proven.
- SwiftSyntax UTF-8 to UTF-16 conversion is an immediate correctness fix and should happen before the larger highlighting rewrite.

## Phase Dependency Graph

```text
Phase 0: Spike and Gates
  |-- Gate A: Range storage backend decision
  |-- Gate B: Tree-sitter viability decision
  |-- Gate C: Folding placeholder strategy decision
  |-- Gate D: Text edit event hub strategy decision
  |
  |-- Phase 1: Correctness and Stub Cleanup
  |
  |-- Phase 2: Shared Range Storage
        |
        |-- Phase 3: Highlighting Provider Overlay
              |
              |-- Phase 6: Syntax-Aware Minimap
        |
        |-- Phase 5: Folding Storage and Presentation
              |
              |-- Phase 7: Parser-Backed Providers
  |
  |-- Phase 4: EditorInteractionState
  |
  |-- Phase 8: Integration, Documentation, and Performance Verification
```

## Phase 0: Spike and Gates

**Goal:** Prove or reject the assumptions that would otherwise make later phases risky.

**Dependencies:** None.

**Success Criteria:**

- Each gate has a written decision: `go`, `no-go`, or `defer`.
- Later phases reference the selected decisions instead of assuming CodeEditSourceEditor internals are available.
- All spike code is either committed as tests/docs or removed.

### Task 0.1: Range Storage Backend Spike

**Question:** Can CodeEditorPlugin safely use `_RopeModule` from `swift-collections` under Swift 6.3 and all supported platforms?

**Files:**

- Inspect: `Package.swift`
- Optional spike only: `.spikes/range-store-rope/`
- Decision doc: `Documentation/Architecture/RangeStoreDecision.md`

**Steps:**

- [ ] Check whether `swift-collections` is already present in `Package.swift`.
- [ ] If not present, create a temporary local spike rather than modifying production targets first.
- [ ] Attempt to compile a minimal `_RopeModule.Rope` example under Swift 6.3.
- [ ] Run `swift build`.
- [ ] Record platform, concurrency, and API stability findings in `Documentation/Architecture/RangeStoreDecision.md`.
- [ ] Choose one backend:
  - `RopeRangeStore`: only if `_RopeModule` compiles cleanly and the instability is accepted.
  - `IntervalTreeRangeStore`: if private rope APIs are too risky.
  - `ArrayRunStore`: only as a simple baseline for tests and performance comparison.

**Risk:** Medium-high. `_RopeModule` is underscored API. Treat this as a decision gate, not a default.

### Task 0.2: Tree-sitter Viability Spike

**Question:** Is SwiftTreeSitter viable for CodeEditorPlugin's Swift 6.3, strict-concurrency, and platform requirements?

**Files:**

- Inspect: `Package.swift`
- Decision doc: `Documentation/Architecture/TreeSitterDecision.md`
- Optional spike only: `.spikes/tree-sitter/`

**Steps:**

- [ ] Evaluate current SwiftTreeSitter package compatibility with Swift 6.3.
- [ ] Verify parser loading for JavaScript, Python, and JSON.
- [ ] Measure parse time and memory for representative large files.
- [ ] Check whether current APIs expose parser reset without CodeEditSourceEditor's reflection workaround.
- [ ] Check availability of highlight and injection queries for the languages we support.
- [ ] Record a `go`, `no-go`, or `defer` decision in `Documentation/Architecture/TreeSitterDecision.md`.

**Risk:** Medium. This is intentionally research-only. Do not wire Tree-sitter into production code during this phase.

### Task 0.3: Folding Placeholder Strategy Spike

**Question:** Can we represent folded content with a non-destructive placeholder using local TextKit/TextKit2 APIs?

**Files:**

- Inspect: `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift`
- Inspect: `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift`
- Inspect: `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
- Decision doc: `Documentation/Architecture/FoldingPresentationDecision.md`

**Strategies to evaluate:**

- `attributeHidden`: current approach, retained as fallback.
- `textAttachmentReplacement`: replace folded text with an attachment while retaining original text elsewhere. High risk because it mutates document text unless carefully virtualized.
- `overlayPlaceholder`: draw a placeholder overlay without replacing storage. Higher UI complexity, lower document-integrity risk.
- `TextKit2RenderingAttributes`: use TextKit2 rendering attributes if they can hide/render without conflicting with syntax attributes.

**Steps:**

- [ ] Verify AppKit behavior.
- [ ] Verify UIKit/Catalyst behavior.
- [ ] Confirm whether the approach preserves the underlying document string.
- [ ] Confirm whether syntax highlighting can reapply without destroying fold presentation.
- [ ] Record the selected strategy in `Documentation/Architecture/FoldingPresentationDecision.md`.

**Risk:** High. Do not assume CodeEditTextView's attachment APIs exist here.

### Task 0.4: Text Edit Event Hub Strategy

**Question:** Where should shared range stores receive text edit notifications?

**Files:**

- Inspect: `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- Inspect: `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift`
- Candidate create: `Sources/CodeEditorPlugin/Text/TextEditEventHub.swift`
- Decision doc: `Documentation/Architecture/TextEditEventHubDecision.md`

**Steps:**

- [ ] Map all current `NSTextStorage.didProcessEditingNotification` observers.
- [ ] Decide whether `CodeEditorView` owns a `TextEditEventHub` property or whether the hub remains a service in `BusinessLogicServiceRegistry`.
- [ ] Define one canonical edit payload containing `editedRange`, `changeInLength`, `documentLength`, and edited mask.
- [ ] Record the selected owner and lifecycle in `Documentation/Architecture/TextEditEventHubDecision.md`.

**Risk:** Medium. A bad hub can duplicate work or create ordering bugs.

## Phase 1: Correctness and Stub Cleanup

**Goal:** Fix known correctness risks before reworking larger systems.

**Dependencies:** Phase 0 can run in parallel, but SwiftSyntax offset tests should start immediately.

### Task 1.1: Fix SwiftSyntax UTF-8 to UTF-16 Range Conversion

**Files:**

- Modify: `Sources/CodeEditorPlugin/Languages/SwiftSyntaxHighlighter.swift`
- Test: `Tests/CodeEditorPluginTests/Languages/SwiftSyntaxHighlighterTests.swift`

**Problem:** `SwiftSyntaxHighlighter` currently builds `NSRange` values from `syntax.position.utf8Offset`. `NSRange` over `NSTextStorage` is UTF-16 based.

**Steps:**

- [ ] Add tests with emoji, CJK, and accented characters before Swift tokens.
- [ ] Add a helper that converts UTF-8 offsets to UTF-16 offsets for a source string.
- [ ] Use the helper for syntax nodes and trivia.
- [ ] Run `swift test --filter SwiftSyntaxHighlighterTests`.
- [ ] Run `swift test --parallel`.

**Success Criteria:**

- Highlight ranges align correctly in Swift files containing multi-byte characters.
- No out-of-bounds ranges are produced.

### Task 1.2: Classify Performance Stubs

**Files:**

- Inspect: `Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift`
- Inspect: `Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift`
- Inspect: `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
- Inspect: `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift`
- Document: `Documentation/Architecture/PerformanceScaffoldingAudit.md`

**Steps:**

- [ ] For each simplified path, classify as `complete now`, `keep behind feature flag`, or `remove`.
- [ ] Remove misleading simulated behavior where it can affect runtime behavior.
- [ ] Preserve useful metrics types if they are read by UI or tests.
- [ ] Add focused tests for any behavior kept.

**Success Criteria:**

- Performance-critical files no longer contain runtime paths that pretend to do work but only simulate it.
- Any remaining simplified behavior is documented and gated.

### Task 1.3: Optimize `EditorStateBridge` Line Counting

**Files:**

- Modify: `Sources/CodeEditorPlugin/Core/EditorStateBridge.swift`
- Use: `Sources/CodeEditorPlugin/Text/LineIndexCache.swift`
- Test: `Tests/CodeEditorPluginTests/Core/EditorStateBridgeTests.swift`

**Steps:**

- [ ] Add tests for large text selection derivation.
- [ ] Add a cache-aware overload that accepts line offsets or a `LineIndexCache` result.
- [ ] Keep the existing simple API for small callers.
- [ ] Run `swift test --filter EditorStateBridgeTests`.

**Success Criteria:**

- Existing behavior is preserved.
- Large-file selection derivation avoids repeated full-string newline walks where a cache is available.

## Phase 2: Shared Range Storage

**Goal:** Introduce shared range-run storage for syntax styles, diagnostics, search, annotations, minimap runs, and fold metadata.

**Dependencies:** Phase 0 Gate A.

**Preferred location:**

- Create directory: `Sources/CodeEditorPlugin/Text/RangeStore/`
- Tests: `Tests/CodeEditorPluginTests/Text/RangeStoreTests.swift`

### Task 2.1: Define Public Internal Interfaces

**Files:**

- Create: `Sources/CodeEditorPlugin/Text/RangeStore/RangeStoreElement.swift`
- Create: `Sources/CodeEditorPlugin/Text/RangeStore/RangeStoreRun.swift`
- Create: `Sources/CodeEditorPlugin/Text/RangeStore/RangeStore.swift`

**Required API:**

```swift
internal protocol RangeStoreElement: Sendable, Equatable {
    var isEmpty: Bool { get }
}

internal struct RangeStoreRun<Element: RangeStoreElement>: Sendable, Equatable {
    internal var length: Int
    internal var value: Element?
}

internal struct RangeStore<Element: RangeStoreElement>: Sendable {
    internal init(documentLength: Int)
    internal var documentLength: Int { get }
    internal func runs(in range: Range<Int>) -> [RangeStoreRun<Element>]
    internal mutating func set(value: Element?, for range: Range<Int>)
    internal mutating func set(runs: [RangeStoreRun<Element>], for range: Range<Int>)
    internal mutating func storageUpdated(replacedCharactersIn range: Range<Int>, withCount newLength: Int)
}
```

**Steps:**

- [ ] Write tests for the API before implementation.
- [ ] Implement the selected backend from Gate A.
- [ ] Keep the public surface independent of the backend.
- [ ] Add tests for insertion, deletion, replacement, coalescing, clipping, repeated queries, and large documents.

**Success Criteria:**

- Consumers do not import `_RopeModule` or know which backend is used.
- Range operations are correct after edits.

### Task 2.2: Add Text Edit Event Hub

**Files:**

- Create: `Sources/CodeEditorPlugin/Text/TextEditEventHub.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- Test: `Tests/CodeEditorPluginTests/Text/TextEditEventHubTests.swift`

**Required API:**

```swift
internal struct TextEditEvent: Sendable, Equatable {
    internal var editedRange: NSRange
    internal var changeInLength: Int
    internal var documentLength: Int
    internal var editedCharacters: Bool
}

@MainActor
internal final class TextEditEventHub {
    internal func addObserver(_ observer: any TextEditEventObserving)
    internal func removeObserver(_ observer: any TextEditEventObserving)
    internal func publish(_ event: TextEditEvent)
}

@MainActor
internal protocol TextEditEventObserving: AnyObject {
    func textStorageDidApplyEdit(_ event: TextEditEvent)
}
```

**Steps:**

- [ ] Add tests for observer registration, removal, and event order.
- [ ] Publish from the existing `handleTextStorageDidProcessEditing(_:)` path after validating the notification belongs to this editor.
- [ ] Keep existing line cache, gutter, syntax highlighting, and completion behavior intact.

**Success Criteria:**

- Shared stores can subscribe to one canonical edit event.
- No duplicate highlight or gutter updates are introduced.

## Phase 3: Highlighting Provider Overlay

**Goal:** Move highlighting toward CodeEditSourceEditor's visible/valid/pending model while preserving existing `SyntaxHighlighter` providers and `SmartTokenCache`.

**Dependencies:** Phase 2.

**Feature flag:**

- Add an internal configuration flag first, for example `EditorConfiguration.Performance.usesRangeBasedHighlighting`.
- Default it to `false` until the new path passes parity tests.

### Task 3.1: Add Highlight Provider Adapter

**Files:**

- Create: `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift`
- Create: `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift`
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift` only if adapter construction needs registry support.
- Test: `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlighterRangeAdapterTests.swift`

**Required shape:**

```swift
@MainActor
internal protocol RangeHighlightProviding: AnyObject {
    func setUp(textView: CodeEditorView, language: Language)
    func willApplyEdit(textView: CodeEditorView, range: NSRange)
    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet
    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
}
```

**Steps:**

- [ ] Build an adapter from existing `SyntaxHighlighter`.
- [ ] For non-incremental highlighters, return invalidation covering the edited visible chunk rather than the full document where safe.
- [ ] Preserve existing token colors and `HighlightedToken` semantics.

**Success Criteria:**

- Existing language highlighters can run through the new protocol without changing every provider at once.

### Task 3.2: Add Visible Range Provider

**Files:**

- Create: `Sources/CodeEditorPlugin/SyntaxHighlighting/VisibleRangeProvider.swift`
- Use: `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
- Test: `Tests/CodeEditorPluginTests/SyntaxHighlighting/VisibleRangeProviderTests.swift`

**Steps:**

- [ ] Compute visible text range from `TextKitBridge.visibleRange`.
- [ ] Include minimap visible range only after Phase 6 exposes it through a data-source protocol.
- [ ] Listen to AppKit scroll/bounds notifications under `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`.
- [ ] Use UIKit scroll hooks where available; otherwise publish on text change and layout change.

**Success Criteria:**

- Newly visible text can be highlighted without highlighting the whole document.

### Task 3.3: Add Highlight Provider State

**Files:**

- Create: `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift`
- Test: `Tests/CodeEditorPluginTests/SyntaxHighlighting/HighlightProviderStateTests.swift`

**State model:**

- `validSet`: ranges with current results.
- `pendingSet`: ranges currently being queried.
- `visibleSet`: ranges that should be rendered.
- `documentSet`: current document length.

**Steps:**

- [ ] Add tests for `(document - valid) ∩ visible - pending`.
- [ ] Add chunking tests with 4096-character maximum chunks.
- [ ] Requeue cancelled operations.
- [ ] Update sets on text edit events from `TextEditEventHub`.

**Success Criteria:**

- Editing one visible character does not schedule a full-document rehighlight.
- Scrolling schedules only newly visible invalid ranges.

### Task 3.4: Add Styled Range Container

**Files:**

- Create: `Sources/CodeEditorPlugin/SyntaxHighlighting/StyleElement.swift`
- Create: `Sources/CodeEditorPlugin/SyntaxHighlighting/StyledRangeContainer.swift`
- Test: `Tests/CodeEditorPluginTests/SyntaxHighlighting/StyledRangeContainerTests.swift`

**Steps:**

- [ ] Store one `RangeStore<StyleElement>` per provider.
- [ ] Merge providers by priority on query.
- [ ] Preserve modifier union behavior.
- [ ] Convert merged style runs into attributes through the existing theme/color mapping.

**Success Criteria:**

- Multiple providers can overlap without corrupting one another.
- Higher-priority provider captures win while modifiers combine predictably.

### Task 3.5: Integrate Behind Feature Flag

**Files:**

- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift`
- Modify: `Sources/CodeEditorPlugin/Core/SyntaxHighlightingService.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- Test: `Tests/CodeEditorPluginTests/SyntaxHighlighting/RangeBasedHighlightingIntegrationTests.swift`

**Steps:**

- [ ] Keep the current highlighter as the default path.
- [ ] Route to range-based highlighting only when the feature flag is enabled.
- [ ] Preserve `SmartTokenCache` for provider tokenization where it still applies.
- [ ] Replace blunt circuit-breaker behavior with smaller chunks or temporary degradation.

**Success Criteria:**

- The new path can be enabled in tests.
- The default path remains unchanged until parity is proven.

## Phase 4: EditorInteractionState

**Goal:** Add typed, serializable interaction state without overloading `EditorState`.

**Dependencies:** None. Can run after Phase 1.

### Task 4.1: Add Data Types

**Files:**

- Create: `Sources/CodeEditorPlugin/Core/EditorInteractionState.swift`
- Test: `Tests/CodeEditorPluginTests/Core/EditorInteractionStateTests.swift`

**Required shape:**

```swift
public struct EditorInteractionState: Equatable, Hashable, Sendable, Codable {
    public var cursorPositions: [EditorCursorPosition]?
    public var scrollPosition: CGPoint?
    public var findText: String?
    public var replaceText: String?
    public var findPanelVisible: Bool?
    public var collapsedFoldIDs: Set<String>?
}

public struct EditorCursorPosition: Equatable, Hashable, Sendable, Codable {
    public var line: Int
    public var column: Int
}
```

**Steps:**

- [ ] Add JSON round-trip tests.
- [ ] Keep every field optional to support partial state restoration.
- [ ] Do not add it to `EditorState` yet.

**Success Criteria:**

- Hosts can persist and restore interaction state independently from editor chrome state.

### Task 4.2: Add Opt-In Binding Surface

**Files:**

- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`
- Test: `Tests/CodeEditorPluginTests/SwiftUI/EditorInteractionStateBindingTests.swift`

**Steps:**

- [ ] Add an optional binding or callback surface for `EditorInteractionState`.
- [ ] Avoid feedback loops by applying only changed fields.
- [ ] Add tests for cursor and scroll restore when possible.

**Success Criteria:**

- Existing `CodeEditor` initializers keep working.
- Interaction state is opt-in.

## Phase 5: Folding Storage and Presentation

**Goal:** Separate fold detection, fold storage, and fold presentation. Do not assume attachment APIs until Gate C chooses a strategy.

**Dependencies:** Phase 2, Phase 0 Gate C.

### Task 5.1: Add Fold Storage

**Files:**

- Create: `Sources/CodeEditorPlugin/Features/LineFoldStorage.swift`
- Test: `Tests/CodeEditorPluginTests/Features/LineFoldStorageTests.swift`

**Steps:**

- [ ] Store fold metadata in `RangeStore<FoldStoreElement>`.
- [ ] Preserve stable fold IDs across recalculation using depth and start offset.
- [ ] Preserve collapsed state across edits where ranges still map cleanly.
- [ ] Query folds by visible range.

**Success Criteria:**

- Fold metadata no longer depends on text attributes.

### Task 5.2: Add Fold Calculation Adapter

**Files:**

- Create: `Sources/CodeEditorPlugin/Features/LineFoldProvider.swift`
- Create: `Sources/CodeEditorPlugin/Features/FoldRegionAdapter.swift`
- Modify: `Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift`
- Test: `Tests/CodeEditorPluginTests/Features/FoldRegionAdapterTests.swift`

**Steps:**

- [ ] Keep existing `CodeFoldingProvider.detectFoldableRegions(in:)` providers.
- [ ] Adapt `[FoldableRegion]` into `LineFoldStorage` raw fold ranges.
- [ ] Do not rewrite all language providers in this phase.

**Success Criteria:**

- Existing providers can feed the new storage without changing their detection logic.

### Task 5.3: Add Fold Presentation Strategy

**Files:**

- Create: `Sources/CodeEditorPlugin/Features/FoldPresentationStrategy.swift`
- Modify: `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift`
- Test: `Tests/CodeEditorPluginTests/Features/FoldPresentationStrategyTests.swift`

**Required shape:**

```swift
@MainActor
internal protocol FoldPresentationStrategy: AnyObject {
    func collapse(_ fold: FoldableRegion, in textView: CodeEditorView)
    func expand(_ fold: FoldableRegion, in textView: CodeEditorView)
}
```

**Steps:**

- [ ] Keep current attribute-hiding as `AttributeFoldPresentationStrategy`.
- [ ] Add the selected strategy from Gate C as a second implementation.
- [ ] Route through configuration so the old strategy remains available during migration.

**Success Criteria:**

- Folding presentation can change without changing fold detection or storage.

### Task 5.4: Refactor CodeFoldingEngine as Facade

**Files:**

- Modify: `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift`
- Modify: `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift`
- Test: `Tests/CodeEditorPluginTests/Features/CodeFoldingEngineTests.swift`

**Steps:**

- [ ] Keep public behavior stable.
- [ ] Move storage concerns into `LineFoldStorage`.
- [ ] Move visual collapse/expand into `FoldPresentationStrategy`.
- [ ] Keep existing provider registry.

**Success Criteria:**

- The engine orchestrates providers, storage, and presentation instead of owning all concerns directly.

## Phase 6: Syntax-Aware Minimap

**Goal:** Make minimap rendering consume style runs without coupling it directly to highlighting internals.

**Dependencies:** Phase 3 for style runs.

### Task 6.1: Add Minimap Style Data Source

**Files:**

- Create: `Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/MinimapViewModel.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/MinimapStyleDataSourceTests.swift`

**Required shape:**

```swift
@MainActor
internal protocol MinimapStyleDataSource: AnyObject {
    func styleRuns(in range: NSRange) -> [MinimapStyleRun]
}

internal struct MinimapStyleRun: Sendable, Equatable {
    internal var range: NSRange
    internal var color: PlatformColor
}
```

**Steps:**

- [ ] Add a default no-op data source.
- [ ] Add a styled data source backed by `StyledRangeContainer`.
- [ ] Keep raw text minimap rendering as fallback.

**Success Criteria:**

- Minimap can render from style runs without knowing about highlight providers.

### Task 6.2: Render Syntax Bars

**Files:**

- Modify: `Sources/CodeEditorPlugin/Layout/MinimapView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/MinimapViewModel.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/MinimapRenderingTests.swift`

**Steps:**

- [ ] Render non-whitespace style segments as compact bars.
- [ ] Throttle style-run recomputation to the existing minimap update cadence.
- [ ] Preserve viewport indicator behavior.
- [ ] Keep current text-based rendering behind fallback configuration.

**Success Criteria:**

- Minimap shows syntax-colored structure for highlighted documents.
- Large files avoid drawing tiny glyphs for every character.

## Phase 7: Parser-Backed Providers

**Goal:** Use Tree-sitter only if Gate B chooses `go`.

**Dependencies:** Phase 0 Gate B, Phase 3, Phase 5.

### Task 7.1: Add Tree-sitter Provider Behind Feature Flag

**Files:**

- Create only if Gate B is `go`: `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterHighlightProvider.swift`
- Create only if Gate B is `go`: `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterExecutor.swift`
- Create only if Gate B is `go`: `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/LanguageLayer.swift`
- Test: `Tests/CodeEditorPluginTests/SyntaxHighlighting/TreeSitterHighlightProviderTests.swift`

**Steps:**

- [ ] Keep SwiftSyntax as the Swift default unless measured data shows otherwise.
- [ ] Start with JavaScript, Python, and JSON.
- [ ] Use the `RangeHighlightProviding` adapter surface.
- [ ] Do not expose Tree-sitter as public API in the first implementation.

**Success Criteria:**

- Tree-sitter can be enabled for selected non-Swift languages without changing the public editor API.

### Task 7.2: Add Parser-Backed Fold Provider

**Files:**

- Create only if Gate B is `go`: `Sources/CodeEditorPlugin/Features/TreeSitterFoldProvider.swift`
- Modify: `Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift`
- Test: `Tests/CodeEditorPluginTests/Features/TreeSitterFoldProviderTests.swift`

**Steps:**

- [ ] Prefer parser-backed folds for languages with reliable fold queries.
- [ ] Fall back to existing providers where no fold query exists.
- [ ] Add tests that braces inside strings/comments do not create folds.
- [ ] Add XML/HTML nested same-name tag tests if Tree-sitter covers those languages.

**Success Criteria:**

- Parser-backed folds eliminate known false positives for at least three languages.

## Phase 8: Integration, Documentation, and Performance Verification

**Goal:** Prove the new architecture is correct, measurable, and maintainable.

**Dependencies:** All implemented phases.

### Task 8.1: Integration Test Matrix

**Commands:**

```bash
swift build
swift test --parallel
swiftlint
```

**Additional targeted tests:**

```bash
swift test --filter SwiftSyntaxHighlighterTests
swift test --filter RangeStoreTests
swift test --filter HighlightProviderStateTests
swift test --filter StyledRangeContainerTests
swift test --filter CodeFoldingEngineTests
swift test --filter Minimap
```

**Success Criteria:**

- Build passes without warnings introduced by the migration.
- SwiftLint remains clean.
- Tests cover multi-byte Swift highlighting, range-store edit sync, visible highlighting, fold preservation, and minimap style rendering.

### Task 8.2: Documentation

**Files:**

- Update: `NOTES.md`
- Create/update: `Documentation/Architecture/RangeStoreDecision.md`
- Create/update: `Documentation/Architecture/TreeSitterDecision.md`
- Create/update: `Documentation/Architecture/FoldingPresentationDecision.md`
- Create/update: `Documentation/Architecture/TextEditEventHubDecision.md`
- Update relevant DocC pages under `Sources/CodeEditorPlugin/Documentation.docc/`

**Success Criteria:**

- Each architectural decision has rationale, rejected alternatives, and follow-up work.
- Public behavior changes are documented.

### Task 8.3: Performance Benchmarks

**Scenarios:**

- 10K-line Swift file with multi-byte characters.
- 100K-line JavaScript file.
- Large JSON file.
- Rapid typing in visible viewport.
- Fast scroll through unhighlighted content.
- Folding/unfolding nested regions.
- Minimap enabled and disabled.

**Metrics:**

- Time to first highlight in viewport.
- Time per visible-range rehighlight.
- Main-thread blocking during scroll.
- Memory growth after repeated edits.
- Fold recalculation time.

**Success Criteria:**

- New feature flags can be enabled without regressions in default behavior.
- Large-file behavior improves or remains neutral before flags become default.

## Risk Matrix

| Area | Risk | Mitigation |
| --- | --- | --- |
| `_RopeModule` | High | Gate A; backend abstraction; fallback interval tree |
| Tree-sitter | Medium-high | Gate B; research-only first; feature flag |
| Folding placeholders | High | Gate C; keep current attribute strategy as fallback |
| Highlighting rewrite | Medium-high | Adapter layer; feature flag; preserve current path |
| Minimap coupling | Medium | Data-source protocol; no direct coordinator dependency |
| Interaction state | Low-medium | Opt-in binding; keep separate from `EditorState` first |
| SwiftSyntax offsets | High correctness risk | Fix before larger rewrite; multibyte tests |
| Performance stubs | Medium | Classify early; remove misleading simulated work |

## Updated Effort Estimate

| Phase | Estimate | Notes |
| --- | ---: | --- |
| Phase 0: Spike and Gates | 3-6 days | Required before large rewrites |
| Phase 1: Correctness and Stub Cleanup | 3-6 days | Pulls urgent correctness forward |
| Phase 2: Shared Range Storage | 4-8 days | Backend choice affects duration |
| Phase 3: Highlighting Provider Overlay | 8-14 days | Feature-flagged migration |
| Phase 4: EditorInteractionState | 2-4 days | Can run in parallel |
| Phase 5: Folding Storage and Presentation | 8-16 days | Highest TextKit risk |
| Phase 6: Syntax-Aware Minimap | 4-7 days | Depends on style runs |
| Phase 7: Parser-Backed Providers | 6-14 days | Only if Tree-sitter gate is `go` |
| Phase 8: Integration and Verification | 4-8 days | Depends on selected phases |

## Recommended Execution Order

```text
Sprint 1:
  Phase 0 gates
  Phase 1.1 SwiftSyntax offset fix

Sprint 2:
  Phase 1 stub cleanup
  Phase 2 RangeStore API and tests
  Phase 4 EditorInteractionState can run in parallel

Sprint 3:
  Phase 2 TextEditEventHub
  Phase 3 provider adapter and visible range provider

Sprint 4:
  Phase 3 provider state, styled container, feature-flagged integration

Sprint 5:
  Phase 5 fold storage and fold provider adapter

Sprint 6:
  Phase 5 fold presentation strategy and CodeFoldingEngine facade
  Phase 6 minimap data source begins

Sprint 7:
  Phase 6 syntax-aware minimap
  Phase 7 begins only if Tree-sitter gate is go

Sprint 8:
  Phase 8 integration, benchmarks, documentation, and default-flag decisions
```

## Default-Flag Policy

New architecture paths should start disabled unless they are pure correctness fixes.

- SwiftSyntax UTF-8/UTF-16 fix: enabled immediately after tests pass.
- RangeStore: internal only until a consumer uses it.
- Range-based highlighting: disabled by default until parity and performance are proven.
- New fold presentation: disabled by default until document integrity and syntax-highlighting interaction are proven.
- Syntax-aware minimap: can be enabled by default only if large-file benchmarks pass.
- Tree-sitter: disabled by default until dependency and platform behavior are proven.

## Final Acceptance Criteria

- `swift build` passes.
- `swift test --parallel` passes.
- `swiftlint` passes.
- Multi-byte Swift highlighting is correct.
- Shared range storage has edit-sync and stress tests.
- Highlighting can operate on visible invalid ranges behind a feature flag.
- Folding storage is separate from fold presentation.
- Existing folding behavior remains available as fallback.
- Minimap can consume style runs through a data-source protocol.
- Tree-sitter has a documented decision before any production implementation.
- Architecture decisions are documented under `Documentation/Architecture/`.
