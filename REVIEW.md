# CodeEditorPlugin — Comprehensive Code Review

Five parallel review passes across concurrency, platform hygiene, TextKit2/memory, configuration/highlighting, and testing/organization/lint. Overall posture is strong — Swift 6 strict concurrency is genuinely respected, `#if os(...)` has zero hits, no production `print()`, no Catalyst residue. Three SwiftLint strict-mode errors are blocking CI; two `🔴` regressions in the public `attributedContent` API silently coerce TextKit2 → TextKit1, mirroring the bug that motivated commit `3503955d`.

**Update:** B-1 and B-2 fixed — `attributedContent` getter/setter now route through `textContentStorage?.textStorage` / `textKitBridge.replaceCharacters`, with `testAttributedContentRoundTripPreservesTK2Stack` covering the regression. Remaining 🔴: B-3, B-4, B-5.

---

## 🔴 Blocking findings (5 — 2 fixed, 3 remaining)

### ✅ B-1. `attributedContent` setter coerces TK2 → TK1 (public API regression) — FIXED
**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeEditorAPIExtensions.swift:20-44`
**Status:** Fixed. Setter now routes through `textKitBridge.replaceCharacters(in:with:)` (wrapped in `NSTextContentStorage.performEditingTransaction`) and rebuilds the line-geometry store. Regression test `testAttributedContentRoundTripPreservesTK2Stack` added in `CodeEditorViewTextKit2InitTests`.

### ✅ B-2. `attributedContent` getter also reads `textStorage` directly — FIXED
**File:** `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeEditorAPIExtensions.swift:20-44`
**Status:** Fixed. Getter now returns `textContentStorage?.textStorage` (TK2-safe accessor). Covered by the round-trip regression test alongside B-1.

### B-3. SwiftLint strict mode failing: `multiline_function_chains` (×2)
**File:** `Sources/CodeEditorPlugin/Utilities/CodeEditorRenderingDiagnostics.swift:399, 403`
```swift
return subviews.prefix(6).map { view in
    let className = String(describing: type(of: view))
    ...
    return "\(className):..."
}.joined(separator: "|")
```
**Fix:**
```swift
let descriptions = subviews.prefix(6).map { view in ... }
return descriptions.joined(separator: "|")
```
**Rationale:** `swiftlint --strict` exits 2; CI gate is red.

### B-4. SwiftLint strict mode failing: `xct_specific_matcher`
**File:** `Tests/CodeEditorPluginTests/Text/TextRenderingVisibilityTests.swift:14`
**Fix:** `XCTAssertTrue((viewportDelegate as AnyObject) === textView, ...)` → `XCTAssertIdentical(viewportDelegate as AnyObject, textView, ...)`

### B-5. Test references retired symbol `EditorConfigurationBuilder`
**File:** `Tests/CodeEditorPluginTests/SwiftUIModifierTests.swift:291`
```swift
let config = EditorConfigurationBuilder().wrapLines(true).fontSize(16).isMinimapVisible(false).build()
```
**Fix:** Rewrite using direct mutation on `EditorConfiguration()`. The symbol does not exist in `Sources/` — this either fails to compile or this file isn't in the active test target. Both states are problems.

---

## 🟡 Warnings (10)

### W-1. `TemporaryAttributesStore` mutates storage outside `performEditingTransaction`
**File:** `Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift:26-28, 34-35, 55-56`
Bare `storage.beginEditing() / addAttributes / endEditing` without outer `NSTextContentStorage.performEditingTransaction`. Triggers the exact race documented at `TextKitBridge.swift:55-59` (`NSTextContentStorageBreakOnEnumerateWhileEditing`). Visible in interactive find/replace flows. **Fix:** route through `TextKitBridge.addPersistentAttributes(_:range:)` or plumb the content storage through the store.

### W-2. `MemoryManagementCoordinator.deinit` leaks cleanup-handler slots
**File:** `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift:53-57`
Comment claims handlers auto-unregister when weak self goes nil; no such mechanism exists. Every closed editor leaves a dead handler in the shared `MemoryMonitor.cleanupHandlers` dictionary that fires every periodic cleanup. **Fix:** unregister explicitly:
```swift
deinit {
    if let identifier = cleanupIdentifier {
        let monitor = memoryMonitor
        Task { @MainActor in monitor.unregisterCleanupHandler(identifier: identifier) }
    }
}
```

### W-3. `RangeAttributeApplier.clearAttributes` computes negative length on stale ranges
**File:** `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift:96-99`
```swift
let clamped = NSRange(
    location: max(0, range.location),
    length: min(range.length, documentLength - range.location)  // negative if range.location > documentLength
)
```
**Fix:** use `bridge.clampedRange(...)` or compute upper bound explicitly.

### W-4. Test file violates `textView.delegate` ownership invariant
**File:** `Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift:339`
```swift
textView.delegate = coordinator
```
SwiftLint's `forbidden_text_view_delegate_assignment` is scoped to `Sources/.*`, so the test slips past. **Fix:** `textView.addDelegateParticipant(coordinator)` (or delete — the assertion only checks non-nil).

### W-5. `EditorConfiguration.Performance.unifiedPerformanceSystem` dropped on Codable round-trip
**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift:108, 175`
Field is excluded from `Codable` (decoded as `nil`) and from `Equatable`. `JSONEncoder` → `JSONDecoder` silently drops the system, and `cfg == cfg2` reports `true` despite the loss. **Fix:** either move to a documented non-`Codable` `PerformanceHooks` sub-struct, or make the field internal/`@MainActor`-only.

### W-6. `validate()` covers only 6 of 30+ numeric fields
**File:** `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:143-198`
Missing: `performance.maxVisibleLines`, `maxFileSize`, `maxEventsPerSecond`, `iOSLargeFileThreshold`, `iOSMaxHighlightingChunk`, `display.minimumFoldableLines`, layout/minimap/folding sizings, etc. `PlatformConstants.validHighlightingLengthRange = 0...Int.max` is a no-op. **Fix:** broaden `validate()` or document the gap as "platform-bounded inputs only; the rest clamp at apply-time."

### W-7. Free-standing TK1 stack in `TextMetricsCalculator`
**File:** `Sources/CodeEditorPlugin/Utilities/TextMetricsCalculator.swift:16`
```swift
let layoutManager = NSLayoutManager()
let textContainer = NSTextContainer()
let textStorage = NSTextStorage(...)
```
Only TK1 instantiation outside the `UITextView` protocol shim. Not on the `CodeEditorView` network so it doesn't trigger the view-coercion regression, but contradicts the "TK1 is retired" guarantee. **Fix:** replace with `font.ascender + abs(font.descender) + font.leading` or rename to an explicit `legacyDefaultLineHeight` helper if parity is required.

### W-8. `MinimapStyleRun` declares `@unchecked Sendable` over `var` reference field
**File:** `Sources/CodeEditorPlugin/Layout/MinimapStyleDataSource.swift:13-21`
`var color: PlatformColor` is mutable in principle; `@unchecked Sendable` promises caller discipline. **Fix:** make both fields `let`.

### W-9. `UncheckedEventShuttle` is unnecessary
**File:** `Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift:4-55`
The `NSEvent.addLocalMonitorForEvents` closure isn't `@Sendable`; the shuttle wraps `NSEvent` to satisfy a phantom `Sendable` boundary. **Fix:** drop the shuttle and capture `event` / `self` directly inside `MainActor.assumeIsolated { … }`.

### W-10. Test name + several test files reference retired symbols / lack `CleanupTestCase`
- `Tests/CodeEditorPluginTests/IntegrationTests.swift:244` — `testConfigurationHotReloadIntegration` references the retired `ConfigurationHotReload` term in the name only; body is fine. Rename.
- `ComprehensivePerformanceTests.swift`, `RangeBasedHighlightingIntegrationTests.swift`, `Core/CodeEditorViewTextKit2InitTests.swift` allocate `CodeEditorView` from plain `XCTestCase` — migrate to `CleanupTestCase`.

---

## 🔵 Informational (11)

- **`EditorEventPublisher.publishSync/subscribeSync/unsubscribeSync`** spawn unstructured `Task { }` — intentional cross-isolation bridges but Task creation order is scheduler-defined. Document as best-effort.
- **FeatureMatrix says 16 `@unchecked Sendable` sites; actual is 20.** New entries: `WarningCollector`, `AppearanceHolder`, `UncheckedEventShuttle`, `RegexIncrementalRangeQueryParser`. Update `docs/FeatureMatrix.md`.
- **Undocumented `DispatchQueue.main.async` in `CodeEditorView+LayoutExtensions.swift:285`** (`restoreScrollOriginAfterLayout`). Add a one-line comment or convert to `Task { @MainActor in … }`.
- **`MemoryMonitor.swift:220-241`** uses `nonisolated(unsafe)` for two `Task<Void, Never>?` fields. `Task` is unconditionally Sendable; bare `nonisolated` (no `(unsafe)`) suffices, matching `PerformanceObservation.swift`.
- **Comment stale: "SwiftSyntax is not compatible with iOS"** at `SyntaxHighlighting/SyntaxHighlightingCoordinator.swift:3`. SwiftSyntax has no platform gate in `Package.swift`. Delete.
- **Three different debounce defaults**: `AsyncSyntaxHighlighter` 300ms, `Performance.textChangeDebounceInterval` 100ms, `PlatformConstants.defaultHighlightingDebounceInterval` 100ms. Route through `PlatformConstants` or document the gap.
- **Duplicate font-size constants**: `PlatformConstants.minimumFontSize=8`/`maximumFontSize=72` vs `validFontSizeRange=6...100`. Align or drop the unused pair.
- **Two competing "range-based highlighting" flags**: `Performance.usesRangeBasedHighlighting` vs `Display.useRangeStoreHighlighting`. Consolidate or cross-reference doc-comments.
- **`CompletionCellTheme @unchecked Sendable`** over `let PlatformFont/Color` fields. Accepted convention; consider holding theme tokens and resolving on `@MainActor` later.
- **~20 pure-extension files use `+Topic.swift` instead of `+Extensions.swift`** (e.g., `EditorController+Completion.swift`, `LSPClient+Transport.swift`, `CodeEditorView+Theme.swift`). Style inconsistency, not lint-enforced. Pick one and document in `CLAUDE.md`.
- **`Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift:95`** uses `print(...)` (allowed by lint exclusion). Migrate to `CrossPlatformLogger` for parity.

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
| Concurrency | 0 | 2 | 4 |
| Platform | 0 | 1 | 0 |
| Configuration | 0 | 2 | 2 |
| TextKit2 | 0 (was 2) | 2 | 0 |
| Memory | 0 | 1 | 1 |
| Highlighting | 0 | 0 | 1 |
| Testing | 2 | 2 | 1 |
| Organization | 0 | 0 | 1 |
| Lint | 2 | 0 | 1 |
| **Total** | **3** (was 5) | **10** | **11** |

### Recommended fix order
1. ~~**B-1, B-2** — TK2 coercion in the public `attributedContent` API.~~ ✅ Fixed.
2. **B-3, B-4, B-5** — re-green `swiftlint --strict` and the broken test reference.
3. **W-1** — `TemporaryAttributesStore` transaction discipline (same fault family as B-1).
4. **W-2** — `MemoryManagementCoordinator` cleanup-handler leak.
5. The rest are quality/consistency cleanups; bundle as a hygiene PR.
