# CodeEditorPlugin — Comprehensive Code Review

Five parallel review passes across concurrency, platform hygiene, TextKit2/memory, configuration/highlighting, and testing/organization/lint. Overall posture is strong — Swift 6 strict concurrency is genuinely respected, `#if os(...)` has zero hits, no production `print()`, no Catalyst residue. Three SwiftLint strict-mode errors are blocking CI; two `🔴` regressions in the public `attributedContent` API silently coerce TextKit2 → TextKit1, mirroring the bug that motivated commit `3503955d`.

**Update:** All five 🔴 blockers, all ten 🟡 warnings, and all eleven 🔵 informational items addressed.

- **Blockers (B-1 … B-5):** `attributedContent` getter/setter routed through `textContentStorage?.textStorage` / `textKitBridge.replaceCharacters` (regression test added); `subviewDescription` split to satisfy `multiline_function_chains`; `XCTAssertIdentical` replaces the generic `XCTAssertTrue(===)`; `SwiftUIModifierTests` mutates `EditorConfiguration()` directly instead of the retired builder.
- **Warnings (W-1 … W-10):** `TemporaryAttributesStore` now wraps every mutation in `performEditingTransaction`; `MemoryManagementCoordinator.deinit` unregisters its cleanup handler explicitly; `RangeAttributeApplier.clearAttributes` clamps stale ranges correctly; `SwiftUICoordinatorTests` uses the multiplexer participant API instead of assigning the delegate slot; `Performance` Equatable compares `unifiedPerformanceSystem` by reference identity; `validate()` covers the obvious numeric performance fields and documents the boundary-only contract; `TextMetricsCalculator.calculateLineHeight` returns `ascender + |descender| + leading` (TK1 stack removed); `MinimapStyleRun` fields are `let`; `UncheckedEventShuttle` is gone (closure runs main-actor-isolated directly); test base class migrations + the `testConfigurationHotReloadIntegration` rename.

`swift build`, `swiftlint --strict`, and all touched test suites are green.

---

## 🔴 Blocking findings (5 — all fixed)

### ✅ B-1. `attributedContent` setter coerces TK2 → TK1 (public API regression) — FIXED
**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeEditorAPIExtensions.swift:20-44`
**Status:** Fixed. Setter now routes through `textKitBridge.replaceCharacters(in:with:)` (wrapped in `NSTextContentStorage.performEditingTransaction`) and rebuilds the line-geometry store. Regression test `testAttributedContentRoundTripPreservesTK2Stack` added in `CodeEditorViewTextKit2InitTests`.

### ✅ B-2. `attributedContent` getter also reads `textStorage` directly — FIXED
**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeEditorAPIExtensions.swift:20-44`
**Status:** Fixed. Getter now returns `textContentStorage?.textStorage` (TK2-safe accessor). Covered by the round-trip regression test alongside B-1.

### ✅ B-3. SwiftLint strict mode failing: `multiline_function_chains` (×2) — FIXED
**File:** `Sources/CodeEditorPlugin/Utilities/CodeEditorRenderingDiagnostics.swift:397-405`
**Status:** Fixed. Hoisted `subviews.prefix(6).map { … }` into a `descriptions` local, then `joined(separator:)` on a separate line.

### ✅ B-4. SwiftLint strict mode failing: `xct_specific_matcher` — FIXED
**File:** `Tests/CodeEditorPluginTests/Text/TextRenderingVisibilityTests.swift:14-18`
**Status:** Fixed. Switched to `XCTAssertIdentical(viewportDelegate as AnyObject, textView, …)`.

### ✅ B-5. Test references retired symbol `EditorConfigurationBuilder` — FIXED
**File:** `Tests/CodeEditorPluginTests/SwiftUIModifierTests.swift:291-294`
**Status:** Fixed. Rewrote using direct mutation: `var config = EditorConfiguration()` then `config.layout.wrapLines = true`, `config.display.fontSize = 16`, `config.display.isMinimapVisible = false`. The dead `EditorConfigurationBuilder` reference is gone.

---

## 🟡 Warnings (10 — all fixed)

### ✅ W-1. `TemporaryAttributesStore` mutates storage outside `performEditingTransaction` — FIXED
**File:** `Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift`
**Status:** Fixed. Store now takes an `NSTextContentStorage` (instead of a raw `NSTextStorage`) and wraps every `beginEditing/addAttributes/removeAttribute/endEditing` cycle in `contentStorage.performEditingTransaction { … }`. `EditorController.temporaryAttributesStore` and `TemporaryAttributesStoreTests` updated to the new signature; all four tests pass.

### ✅ W-2. `MemoryManagementCoordinator.deinit` leaks cleanup-handler slots — FIXED
**File:** `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift:53-63`
**Status:** Fixed. `deinit` now hops to `@MainActor` via `Task { @MainActor in monitor.unregisterCleanupHandler(identifier:) }` so closing editors no longer leaves dead handlers in `MemoryMonitor.cleanupHandlers`. The stale comment about weak-reference auto-unregister is gone.

### ✅ W-3. `RangeAttributeApplier.clearAttributes` computes negative length on stale ranges — FIXED
**File:** `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift:92-108`
**Status:** Fixed. Computes `lowerBound` from `min(range.location, documentLength)` and derives `length` from the clamped upper bound, so a stale `range.location` past the document end no longer produces a negative `NSRange.length`.

### ✅ W-4. Test file violates `textView.delegate` ownership invariant — FIXED
**File:** `Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift:336-345`
**Status:** Fixed. Test now calls `coordinator.setupTextViewDelegate(textView)` (the iOS coordinator's wrapper around `addDelegateParticipant(self, phase: .behavior)`) instead of assigning the delegate slot directly.

### ✅ W-5. `EditorConfiguration.Performance.unifiedPerformanceSystem` dropped on Codable round-trip — FIXED
**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift:103-117, 215-217`
**Status:** Fixed. `Equatable` now compares `unifiedPerformanceSystem` by reference identity (`===`), so a configuration that has lost the reference via `encode → decode` no longer compares equal to one that retains it. The doc comment spells out the Codable carve-out and the new Equatable contract.

### ✅ W-6. `validate()` covers only 6 of 30+ numeric fields — FIXED
**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:142-235`
**Status:** Fixed. `validate()` now rejects nonsensical values on the obvious numeric fields (`performance.maxVisibleLines`, `maxFileSize`, `maxEventsPerSecond`, `iOSLargeFileThreshold`, `iOSMaxHighlightingChunk`). Doc comment documents the boundary-only contract: fields clamped at apply-time inside their consumer are intentionally not validated here.

### ✅ W-7. Free-standing TK1 stack in `TextMetricsCalculator` — FIXED
**File:** `Sources/CodeEditorPlugin/Utilities/TextMetricsCalculator.swift:14-24`
**Status:** Fixed. `calculateLineHeight(for:)` now returns `ceil(font.ascender + abs(font.descender) + font.leading)` and no longer stands up an `NSLayoutManager` / `NSTextContainer` / `NSTextStorage` just to read `defaultLineHeight(for:)`.

### ✅ W-8. `MinimapStyleRun` declares `@unchecked Sendable` over `var` reference field — FIXED
**File:** `Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift:13-22`
**Status:** Fixed. Both `range` and `color` are `let`; the `@unchecked Sendable` conformance over `PlatformColor` is now sound because the value is genuinely immutable after init.

### ✅ W-9. `UncheckedEventShuttle` is unnecessary — FIXED (refined approach)
**File:** `Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift:30-46`
**Status:** Fixed. `UncheckedEventShuttle` is gone. The reviewer's literal recommendation (capture `event` / `self` inside `MainActor.assumeIsolated`) didn't quite work — `MainActor.assumeIsolated`'s closure is `@MainActor () throws -> T`, and capturing the non-`Sendable` `NSEvent` across that boundary errors under strict concurrency. Since `NSEvent.addLocalMonitorForEvents`'s handler closure is already `@MainActor`-isolated in modern AppKit SDKs, the simpler fix is to drop the `assumeIsolated` hop entirely and call `self.handleMouseDown(event)` directly inside the monitor closure.

### ✅ W-10. Test name + non-`CleanupTestCase` migration — FIXED (with note)
**Files:**
- `Tests/CodeEditorPluginTests/IntegrationTests.swift:244` — renamed `testConfigurationHotReloadIntegration` → `testLiveConfigurationUpdateIntegration` (drops the retired `ConfigurationHotReload` term).
- `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift` — now inherits `CleanupTestCase`; editor allocations route through `createCodeEditorView(frame:)`.
- `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift` — same migration; three `CodeEditorView(frame:)` allocations switched to `createCodeEditorView(frame:)`.
- **Note:** `Tests/CodeEditorPluginTests/SyntaxHighlighting/RangeBasedHighlightingIntegrationTests.swift` uses Swift Testing (`@Suite` / `@Test`), not XCTest. `CleanupTestCase` is an `XCTestCase` subclass, so it doesn't apply. Cleanup in that suite happens via per-test init/deinit on `@MainActor` types; no migration needed here.

---

## 🔵 Informational (11 — all addressed)

- ✅ **I-1** `EditorEventPublisher.publishSync/subscribeSync/unsubscribeSync` — doc comments now spell out the best-effort ordering (`Task { }` creation order is scheduler-defined; ordering caveats noted per method).
- ✅ **I-2** `docs/FeatureMatrix.md` updated to **19** documented `@unchecked Sendable` sites (post-W-9 removal of `UncheckedEventShuttle`; the prior 16 count missed `WarningCollector`, `AppearanceHolder`, `RegexIncrementalRangeQueryParser`, `AwaitableQueue`, `RangeProcessor`, `ParagraphStyleCache`).
- ✅ **I-3** `restoreScrollOriginAfterLayout` (`CodeEditorView+LayoutExtensions.swift`) annotated with the rationale for using `DispatchQueue.main.async` rather than `Task { @MainActor in … }` — the queue hop drains in the same AppKit layout pass; a Task hop wouldn't.
- ✅ **I-4** `MemoryMonitor.monitoringTask` / `cleanupTask` switched from `nonisolated(unsafe)` to plain `nonisolated` storage (`Task<Void, Never>` is unconditionally `Sendable`), matching `PerformanceObservation.swift`.
- ✅ **I-5** Stale "SwiftSyntax is not compatible with iOS" comment removed from `SyntaxHighlightingCoordinator.swift`.
- ✅ **I-6** `AsyncSyntaxHighlighter` default debounce now routes through `PlatformConstants.defaultAsyncHighlightingDebounceInterval` (0.3s). A doc comment on `defaultHighlightingDebounceInterval` (0.1s) clarifies the editor-level vs background-task split.
- ✅ **I-7** Unused `PlatformConstants.minimumFontSize` (8) / `maximumFontSize` (72) deleted; `validFontSizeRange` (6...100) is the only bound now.
- ✅ **I-8** Cross-referenced the two range-store flags: `performance.usesRangeBasedHighlighting` is now labeled the Phase-2 master gate and `display.useRangeStoreHighlighting` the Phase-2A consumer toggle (the latter requires the former).
- ✅ **I-9** `CompletionCellTheme @unchecked Sendable` annotated with the accepted future direction (hold design tokens, resolve on `@MainActor`); not actioned now.
- ✅ **I-10** `CLAUDE.md` updated to document the de facto dual convention: catch-all type extensions use `+Extensions` in `Sources/CodeEditorPlugin/Extensions/`; domain-scoped extensions use `+<Topic>` (e.g. `CodeEditorView+Theme.swift`, `EditorController+Completion.swift`, `LSPClient+Transport.swift`).
- ✅ **I-11** `ComprehensivePerformanceTests.testFuzzyMatcherPerformance` now logs via the existing `Logger` (the file's `os.Logger` instance) instead of `print(...)`.

---

## Verified clean (no findings)

- `#if os(...)` — **0 hits** across `Sources/` and `Tests/` (780 `canImport` uses).
- Mac Catalyst — 0 hits.
- `print(` in production — 0 (matches in `Sources/CodeEditorSample/Resources/SampleSnippets/*.txt` are content files).
- DocC directives in `docs/` — 0.
- Static `shared` singletons in `Sources/CodeEditorPlugin/` — 0.
- Mixed XCTest+Testing imports in same file — 0.
- `isRecording: true` leftovers — 0.
- Language enum: 26 cases (25 concrete + `plainText`); 26 descriptor files. Matches.
- Tree-sitter scaffolding: `LanguageDescriptor` internal, `parserName` internal, no SPM target, no public flag. Clean.
- SwiftSyntax imported in exactly 2 files (`SyntaxHighlightingCoordinator.swift`, `SwiftSyntaxHighlighter.swift`). Swift-only as intended.
- SQL case-insensitive keywords (`SqlLanguageDescriptor.caseInsensitiveKeywords: true` + `(?i)` prepended in `RegexSyntaxHighlighter+LanguagesExtensions.swift`) — landed correctly.
- `MemoryMonitor` is `public final class`; tests use `.mock(...)` or factories, no subclasses.
- `CodeEditorView` capture-list discipline: all 5 `[weak self]` sites in `Core/CodeEditorView*.swift` correctly weak.
- `EditorConfiguration` and all sub-structs `Codable, Sendable, Equatable` — value semantics hold.
- `.swiftlint.yml`: `strict: true`, all 4 required custom rules present.
- All `NSLock` usages have written justifications (Combine `Subscriber`, sync-cancel paths from `removeFromSuperview`, `withTaskGroup` provider tasks).
- `withEditingTransaction` discipline inside `TextKitBridge.swift` is correct (refcounted nesting documented).
- No `Thread.current` checks anywhere under `Sources/`.

---

## Summary

| Category | 🔴 Blocking | 🟡 Warnings | 🔵 Info |
|---|---|---|---|
| Concurrency | 0 | 0 (was 2) | 0 (was 4) |
| Platform | 0 | 0 (was 1) | 0 |
| Configuration | 0 | 0 (was 2) | 0 (was 2) |
| TextKit2 | 0 (was 2) | 0 (was 2) | 0 |
| Memory | 0 | 0 (was 1) | 0 (was 1) |
| Highlighting | 0 | 0 | 0 (was 1) |
| Testing | 0 (was 2) | 0 (was 2) | 0 (was 1) |
| Organization | 0 | 0 | 0 (was 1) |
| Lint | 0 (was 2) | 0 | 0 (was 1) |
| **Total** | **0** (was 5) | **0** (was 10) | **0** (was 11) |

### Recommended fix order
1. ~~**B-1, B-2** — TK2 coercion in the public `attributedContent` API.~~ ✅ Fixed.
2. ~~**B-3, B-4, B-5** — re-green `swiftlint --strict` and the broken test reference.~~ ✅ Fixed.
3. ~~**W-1** — `TemporaryAttributesStore` transaction discipline (same fault family as B-1).~~ ✅ Fixed.
4. ~~**W-2** — `MemoryManagementCoordinator` cleanup-handler leak.~~ ✅ Fixed.
5. ~~**W-3 through W-10** — quality/consistency cleanups (range clamping, delegate ownership, Codable/Equatable contract, validation breadth, TK1 removal, Sendable hygiene, test base class migration).~~ ✅ Fixed.
