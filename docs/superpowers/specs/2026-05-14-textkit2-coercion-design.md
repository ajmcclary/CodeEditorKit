# TextKit 2 Coercion Fix — Design

**Status:** Draft, awaiting implementation plan
**Date:** 2026-05-14
**Owner:** ajmcclary
**Source:** `REVIEW.md` § "Latent TextKit 2 coercion (`CodeEditorView.setupTextView` — discovered 2026-05-14)"

## Problem

`CodeEditorView.textLayoutManager` is `nil` immediately after `init(frame:)`, even though the framework is documented as TextKit 2-based. A plain `NSTextView(frame: .zero)` on the same macOS returns a non-nil `textLayoutManager`, so the regression is local to `CodeEditorView`'s init path.

The trigger is `setupTextView()` → `setupLineGeometryStore()` → `rebuildLineGeometryStoreFromCurrentTextStorage()` reaching through `self.textStorage` at `Core/CodeEditorView+SetupExtensions.swift:99-109`. Per Apple's TextKit 2 documentation, reading the legacy `textStorage` property on a TextKit 2-initialised `NSTextView` silently coerces it back to TextKit 1 and clears `textLayoutManager`. The very first thing the editor does after `super.init` strands itself in TK1 mode.

A second coercion site fires earlier in the same call chain: `TextKitSetupHelper.setupNotifications` (`Core/TextKitSetupHelper.swift:184,187,207`) reads `textView.textStorage` to wire `NSTextStorage.didProcessEditingNotification`. The geometry rebuild is therefore not the *first* coercion — but it is on the same critical path and the test canary (`AnnotationTests.testAnnotationTextKit2Integration`) reproduces against it.

**Impact.** Every code path that conditionalises on `textLayoutManager != nil` silently takes its fallback path. `ModernTextKit2Bridge`, `TextKit2RenderingOptimizer`, and any future TK2-only optimisation are inert. The recently-removed `MemoryManagementCoordinator` TK1 cleanup (REVIEW Critical #2) was structurally aligned with this — TK2 paths have been dormant for a while. The framework is, in practice, a TextKit 1 editor that *thinks* it's TextKit 2.

## Goals

1. After any `CodeEditorView` init returns, `textLayoutManager` is non-nil and `textContentStorage` is non-nil. This is the load-bearing invariant for everything downstream.
2. No production code outside a single `TextKitBridge` file reads `NSTextView.textStorage` directly.
3. Syntax-highlighting attribute application uses `NSTextLayoutManager.setRenderingAttributes(_:for:)` instead of mutating `NSTextStorage` attributes, so highlighting becomes non-destructive rendering rather than document content.
4. Re-enable the canary test (`AnnotationTests.testAnnotationTextKit2Integration`) and add a fail-fast init regression test.
5. Land in a single PR on `main`. No staging across PRs.

## Non-goals

- Legacy-OS support: `Package.swift` requires macOS 26.3 / iOS 26.3, so TK2 is universally available at runtime. The fallback designed below is an init-order safety net, not a compatibility shim.
- Resolving the other Important issues in REVIEW.md (`MemoryMonitor` observer leak, `LSPClient.disconnect`, `LayoutCoordinator` recursion). Different bug class.
- Sample-driven API gaps (#3 EditorDocument, #5 `onAttach`, #6 `CompletionEvent`, #7 `.performanceObserver`). Different scope.
- Tree-sitter integration. Long-term TK2 enables this; the migration doesn't deliver it.
- A comprehensive TK2 invariant test matrix across every feature. Targeted invariants + critical-path coverage only.

## Architecture & invariant

The load-bearing invariant is single-sentence: **after any `CodeEditorView` init returns, `textLayoutManager` and `textContentStorage` are non-nil**.

Two mechanisms enforce it together:

1. **Never read `NSTextView.textStorage` directly during setup or steady-state code paths.** Go through `textContentStorage?.textStorage` — the content-manager-owned `NSTextStorage`. This accessor does not trigger Apple's TK1 compatibility shim.
2. **For the syntax-highlighting write path, stop calling `textStorage.beginEditing()/addAttributes(_:range:)/endEditing()` and call `NSTextLayoutManager.setRenderingAttributes(_:for:)` instead.** Rendering attributes are non-destructive (the underlying attributed string stays clean) and TK2-native.

The single funnel for both is the existing `TextKitBridge` (`Sources/CodeEditorPlugin/Text/TextKitBridge.swift`). It already wraps a weak `PlatformTextView` and already exposes `textContentStorage` and `setTemporaryAttributes(_:for:)`. The migration removes its current `var textStorage: NSTextStorage?` public surface (which is the leak), redirects its internal reads through `textContentStorage?.textStorage`, and rewrites its `addAttributes`/`removeAttributes` to use rendering attributes. After the migration, no production code outside `TextKitBridge` reads `NSTextView.textStorage` directly.

## `TextKitBridge` API surface after the migration

```swift
@MainActor
final class TextKitBridge {
    // Unchanged
    var textContentStorage: NSTextContentStorage? { ... }
    var version: Version { .textKit2 }
    func textRangeFromNSRange(_:) -> NSTextRange? { ... }
    func nsRangeFromTextRange(_:) -> NSRange? { ... }
    func ensureLayout(for:) { ... }
    func enumerateLineFragments(in:using:) { ... }
    func cursorRect(at:) -> CGRect? { ... }
    func boundingRect(for:) -> CGRect? { ... }
    var visibleRange: NSRange? { ... }
    var textContainerSize: CGSize { get set }
    var widthTracksTextView: Bool { get set }
    func optimizeForFileSize(_:) { ... }

    // NEW — TK2-safe content access
    var documentLength: Int { textContentStorage?.textStorage?.length ?? 0 }
    var documentString: String { textContentStorage?.textStorage?.string ?? "" }
    func attributedSubstring(in range: NSRange) -> NSAttributedString?
    func substring(in range: NSRange) -> String?

    // NEW — TK2-safe content mutation
    func replaceCharacters(in range: NSRange, with string: String)
    func replaceCharacters(in range: NSRange, with attributedString: NSAttributedString)

    // CHANGED — now use NSTextLayoutManager.setRenderingAttributes(_:for:)
    func addAttributes(_:range:)
    func removeAttributes(_:range:)
    func setTemporaryAttributes(_:for:)       // already correct (REVIEW Critical #1 fix)
    func removeTemporaryAttributes(for:)

    // REMOVED — the coercing accessor
    // var textStorage: NSTextStorage?   ← gone

    // PRIVATE — internal-only TK2-safe read, used by the bridge itself
    private var safeTextStorage: NSTextStorage? { textContentStorage?.textStorage }
}
```

### Contract notes

- **`addAttributes` semantics change.** Before, attributes persisted into the underlying `NSAttributedString` (visible via `attributedSubstring(from:)` and copy/paste). After, they're rendering-only and don't survive serialisation. For a code editor this is correct — syntax highlighting is rendering, not document content — but any caller that reads back its previously-applied colors via `textStorage.attribute(_:at:effectiveRange:)` will see nothing.
- **Single internal reader.** `private var safeTextStorage` is the only place in the framework that reads `textContentStorage?.textStorage`. Everything else goes through the bridge. After the migration, `git grep 'textStorage' Sources/CodeEditorPlugin` should show only `TextKitBridge.swift` and the few places where the framework genuinely owns an `NSTextStorage` (e.g., test fixtures).

## Migration sweep — who calls what, what changes

The current ~60 `textView.textStorage` callsites collapse against the new bridge as follows.

### Group A — Setup-time reads (the actual coercion source)

Three sites. Fixed first, smallest blast radius.

- `Core/CodeEditorView+SetupExtensions.swift:99-109` — `rebuildLineGeometryStoreFromCurrentTextStorage()` reads through `textContentStorage?.textStorage`. `LineGeometryStore.build(from: NSTextStorage)` keeps its existing signature; only the *source* of the storage changes.
- `Core/TextKitSetupHelper.swift:184,187,207` — notification observer wiring. Drop the `object:` filter on the `NSTextStorage.didProcessEditingNotification` observer; the handler already validates the sender, and text storage replacement is rare enough in this codebase that the filter does not earn its cost. Same change at the cleanup callsite (`:207`).
- `Text/LineGeometryEditHandler.swift:41` — post-edit rebuild fallback. Reads through `textView.textContentStorage?.textStorage`.

### Group B — Read-only consumers

~35 sites across `SyntaxHighlighterRangeAdapter`, `VisibleRangeProvider`, `RangeBasedHighlightingController`, `SearchReplaceEngine`, `SymbolNavigator`, `CodeFoldingEngine`, `AutoBracketingEngine`, `SmartIndentationEngine`, `MultiCursorEditor`, `LSPSemanticTokenProvider`, `LSPContentCoordinator`, `GutterView+AccessibilityExtensions`, `TextKitLineNumberHelper`, `CodeEditorContainerView+AppKitExtensions`. Each becomes:

- `textView.textStorage?.length ?? 0` → `bridge.documentLength`
- `textView.textStorage?.string ?? ""` → `bridge.documentString`
- `textView.textStorage?.attributedSubstring(from: r)` → `bridge.attributedSubstring(in: r)`
- `textView.textStorage?.string` substringing → `bridge.substring(in: r)`

Mechanical replacement; no semantic change. Each consumer already has a `CodeEditorView` (sometimes weak), so it can call `view.textKitBridge` lazily. Introduce a lazy `internal var textKitBridge: TextKitBridge` on `CodeEditorView` so callers don't construct one per call.

### Group C — Attribute writers (the highlighting hot path)

~6 sites: `SyntaxHighlighting/RangeAttributeApplier.swift:76,94`, `SyntaxHighlighting/AsyncSyntaxHighlighter.swift:381,455`, `SyntaxHighlighting/RangeBasedHighlightingController` (color application), `Text/ModernTextKit2Bridge.swift:308,337`. These currently call `textStorage.beginEditing()/addAttributes(_:range:)/endEditing()` for syntax highlighting. They become `bridge.addAttributes(_:range:)`, which under the hood calls `setRenderingAttributes(_:for:)`.

**This is the only group with a behaviour change** — colors no longer mutate the underlying attributed string. Plain-text color set at config time (font, foreground in `setupDefaultTheme`) stays on the text-storage path because it's document-level, not range-level highlighting; those go through `replaceCharacters` / `setupDefaultTheme` and aren't affected.

### Group D — Mutators that genuinely need NSTextStorage editing transactions

`SearchReplaceEngine.replace`, `MultiCursorEditor.applyEdits`, `AutoBracketingEngine.replaceText`, the SwiftUI `text` setter. These do `textStorage.replaceCharacters(in:with:)` — legitimate document mutation, not a coercion-causing read of the NSTextView property. They get wrapped in `bridge.replaceCharacters(in:with:)`, which internally goes through `textContentStorage?.textStorage` (TK2-safe). Semantically unchanged.

### Group E — Bridge-internal reads to delete

- `Text/TextKitBridge.swift:48-50` — the leaky `var textStorage` accessor. Removed.
- `Text/TextKitBridge.swift:328` — `debugInfo` callsite. Becomes `bridge.documentLength`.
- `Text/TextKitBridge.swift:110-118` — `addAttributes` mutates `textStorage` directly. Rewritten to `setRenderingAttributes`.
- `Text/TextKitBridge.swift:120-131` — `removeAttributes` mutates `textStorage` directly. Rewritten to `setRenderingAttributes`.

### Outside the framework target

`Sources/CodeEditorSample/...` has no direct `textStorage` reads against the editor view (it goes through `EditorController` and `controller.text`). No sample changes required.

## Fallback & error handling

`Package.swift` requires macOS 26.3 / iOS 26.3, so the TK2 stack is universally present at runtime. The fallback is narrowly an init-order safety net for the brief window where `super.init(frame:)` hasn't yet finished wiring `textLayoutManager`, plus the rare `init?(coder:)` path that goes through unarchiving.

- **Read paths.** `bridge.documentLength` / `documentString` / `substring(in:)` / `attributedSubstring(in:)` all funnel through `textContentStorage?.textStorage`. If `textContentStorage` is nil (init-order edge case), they return `0` / `""` / `nil` — the same shape callers already handle (`textStorage?.length ?? 0` is the prevailing idiom today). No `precondition`, no crash; the editor degrades to "empty document" until `textContentStorage` becomes available, which is one runloop turn away in practice.
- **Write paths.** `bridge.replaceCharacters` is a no-op when `textContentStorage` is nil and logs once at `.error` level via `CrossPlatformLogger` ("attempted text mutation before TextKit 2 stack was ready"). This catches genuine regressions without dropping data silently. `bridge.addAttributes` similarly no-ops with a single log.
- **No double-fallback to TK1.** The bridge does not reach for `textView.textStorage` if `textContentStorage` is nil. That's the whole point of the migration; the legacy property is what caused the coercion, and falling back to it would re-arm the bug. The user's "helper-gated fallback" choice means the bridge is the single fallback point — and the fallback is "return empty / log", not "use TK1".
- **`@unchecked Sendable` rationale.** The bridge stays `@MainActor`, so no concurrency-rationale comments need updating. The weak `textView` reference is unchanged.
- **Logging.** One new `CrossPlatformLogger` category, `TextKitBridge`, used for the two failure cases above.

### Caller contract

"If you previously expected `textStorage?.length ?? 0` to handle nil, the bridge handles it identically. If you previously assumed `textStorage` was non-nil and force-unwrapped, you now get `0`/`""`/`nil` instead and need to handle it — but force-unwraps are already banned by SwiftLint, so this should be a no-op in practice."

## Testing

Four additions, scoped to invariants and the critical path. No comprehensive TK2-mode matrix.

### `CodeEditorViewTextKit2InitTests` (new XCTest case, macOS + iOS)

Located at `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`.

- `testInitFrameProducesTK2Stack` — `let v = CodeEditorView(frame: .zero); XCTAssertNotNil(v.textLayoutManager); XCTAssertNotNil(v.textContentStorage)`. This is the canary that would have caught the original regression.
- `testInitWithContainerProducesTK2Stack` — same assertion for the `init(frame:textContainer:)` path.
- `testInitFromCoderProducesTK2Stack` — archive/unarchive round-trip; assert TK2 stack survives. Catches the `init?(coder:)` path mentioned in `CodeEditorView.swift:512`.

### Re-enable `AnnotationTests.testAnnotationTextKit2Integration`

`Tests/CodeEditorPluginTests/AnnotationTests.swift:357-371`. Drop the `XCTSkipIf`; the test becomes a plain `XCTAssertNotNil(textView.textLayoutManager?.textContentManager)`. This is the test the framework deliberately marked as a known gap on 2026-05-14; re-enabling it is the proof point that the gap is closed.

### `SyntaxHighlightingRenderingAttributeTests` (new XCTest case)

Located at `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift`.

- `testHighlightingAppliesRenderingAttributes` — set source to a known Swift snippet, trigger highlighting, enumerate the layout manager's rendering attributes via `textLayoutManager.enumerateRenderingAttributes(from:reverse:using:)`, and assert the expected attribute keys exist for keyword ranges. Proves the new write path works.
- `testHighlightingDoesNotMutateAttributedString` — same setup; assert `textContentStorage.textStorage?.attribute(.foregroundColor, at: keywordOffset, effectiveRange: nil) == nil`. This is the semantic-change contract: highlighting is rendering-only, the underlying attributed string stays clean.

### Existing suite must pass

`swift test --parallel` plus `swiftlint --strict`. Two pre-existing failures noted in REVIEW.md (`EditorStatusBarSnapshots` parallel SIGSEGV; the snapshot crash) remain; the migration does not fix them but verifies they don't get worse.

### Out of scope for testing

No per-feature TK2-mode suite, no rendering-output snapshot tests of highlighting colors across the 25 languages, no UI-level integration tests in `CodeEditorSample`.

## Risks & mitigations

1. **Rendering attributes don't survive every code path the highlighter relies on.** `setRenderingAttributes(_:for:)` is invalidated when the underlying text mutates in a way that crosses the attribute range — and the highlighter caches its applied state internally. If the cache thinks "I already highlighted lines 5-12 green" but the rendering attributes were silently dropped by an unrelated edit, lines 5-12 render uncolored until the next reflow.
   **Mitigation:** the highlighter's "did I already do this range?" logic invalidates on `NSTextLayoutManager.didChangeContents` rather than on the previous `NSTextStorage.didProcessEditingNotification` only. Verify the two notifications are compatible or wire the new one explicitly during the sweep.
2. **`addAttributes` semantic change breaks any consumer that reads back its applied highlighting.** Most likely victim: the minimap (`RangeBasedHighlightingController.styleDataSource`). If the minimap reads `textStorage.attribute(.foregroundColor, at:)` to mirror colors, after the migration it reads `nil`.
   **Mitigation:** explicit grep for `textStorage.attribute(` and `textStorage.attributes(` during the sweep; rewire any reader to consult the `RangeStore`-backed color cache or to query `textLayoutManager.renderingAttributes(in:)`.
3. **`replaceCharacters` write path's `NSTextContentStorageBreakOnEnumerateWhileEditing` invariant.** `Core/CodeEditorView+SyntaxHighlightingExtensions.swift:25-76` and `Core/CodeEditorView+ConfigurationExtensions.swift:108` already document this hazard — running editing transactions inside an outer `NSTextContentStorage.performEditingTransaction` trips the assert.
   **Mitigation:** the bridge's `replaceCharacters` does *not* wrap in `performEditingTransaction` itself; callers that need to batch use the existing `performEditingTransaction(_:)` extension on `NSTextContentManager`, and the bridge's edit is the inner call.

## Doc-comment update

`Core/CodeEditorView.swift:159-169` (the named-commit invariant block about not standing up a custom TK2 network) gets a third paragraph appended: a warning that `setupTextView()` must read text through `textContentStorage?.textStorage`, never `self.textStorage`, and a pointer to the canary regression test at `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`. Per CLAUDE.md "Patterns worth codifying," load-bearing invariants get named-commit comments — this one expands.

## Touch list (single PR estimate)

- **Modified (~30 files):**
  - `Sources/CodeEditorPlugin/Text/TextKitBridge.swift` (rewrite — API surface change, internal reads through `safeTextStorage`, mutators switch to rendering attributes)
  - `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (header comment, new lazy `textKitBridge` property)
  - `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
  - `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift` (debugInfo callsite)
  - `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift` (drop `object:` filter on the notification observer)
  - `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift`
  - Group B consumers (~14 files: `SyntaxHighlighterRangeAdapter`, `VisibleRangeProvider`, `RangeBasedHighlightingController`, `SearchReplaceEngine`, `SymbolNavigator`, `CodeFoldingEngine`, `AutoBracketingEngine`, `SmartIndentationEngine`, `MultiCursorEditor`, `LSPSemanticTokenProvider`, `LSPContentCoordinator`, `GutterView+AccessibilityExtensions`, `TextKitLineNumberHelper`, `CodeEditorContainerView+AppKitExtensions`)
  - Group C consumers (~4 files: `RangeAttributeApplier`, `AsyncSyntaxHighlighter`, `RangeBasedHighlightingController` color application, `ModernTextKit2Bridge`)
  - Group D consumers (~4 files: `SearchReplaceEngine` replace path, `MultiCursorEditor` apply path, `AutoBracketingEngine` replace path, SwiftUI `text` setter)
  - `Tests/CodeEditorPluginTests/AnnotationTests.swift` (drop `XCTSkipIf`)
- **Added (2 files):**
  - `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`
  - `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift`
- **Deleted:** none in this PR — the TK1 fallback branches stay in via the bridge's no-op-when-nil contract. (Future work: once the bridge has soaked, the dead `if textLayoutManager != nil { ... } else { TK1 }` branches inside `ModernTextKit2Bridge`, `RangeAttributeApplier`, etc., can be removed in a follow-up.)

Estimate: ~30 source files modified, 2 added, ~200-400 LOC net. Most of the LOC is mechanical accessor swaps; the substantive new code is in `TextKitBridge` and the two test files.

## Verification

- `swift build` — green.
- `swiftlint --fix && swiftlint --strict` — 0 violations.
- `swift test --parallel` — `CodeEditorViewTextKit2InitTests` green; `AnnotationTests.testAnnotationTextKit2Integration` green (no longer skipped); `SyntaxHighlightingRenderingAttributeTests` green; rest of suite unchanged. Pre-existing `EditorStatusBarSnapshots` parallel SIGSEGV may persist (not introduced by this work; documented in REVIEW.md).
- Smoke test in `CodeEditorSample`: open a Swift file, observe syntax highlighting renders correctly, confirm typing/folding/find work as before.

## Open questions

None blocking implementation. Implementation plan (next step via `writing-plans`) breaks the touch list into ordered tasks.
