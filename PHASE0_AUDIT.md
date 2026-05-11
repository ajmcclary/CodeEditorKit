# Phase 0: Foundation Audit — Findings & Decisions

**Date**: 2026-05-11
**Status**: Audit complete; attribute-edit gate fix applied; tests running.

---

## Step 1: Build / Lint / Test Baseline

| Gate | Result |
|------|--------|
| `swift build` | ✅ Passed (3.99s) |
| `swiftlint --fix` | ✅ 638 files corrected |
| `swiftlint` (strict) | ✅ 0 violations across 638 files |
| `swift test --parallel` | ⏳ Running... |

---

## Step 2: Pre-Edit Transaction Model Design

### Current State

- `TextEditEvent` is **post-edit only** — published from `handleTextStorageDidProcessEditing` after `NSTextStorage` has mutated.
- `TextEditEventHub` has only `publish(_:)` for post-edit events and a single observer protocol (`TextEditEventObserving` with `textStorageDidApplyEdit`).
- `RangeHighlightProviding` already defines `willApplyEdit` with two overloads, anticipating pre-edit snapshots.
- `RangeBasedHighlightingController` already captures pre-edit source snapshots (`previousSourceSnapshot`) and calls `provider.willApplyEdit()`.

### Design Decision

**New types to add** (in `TextEditEventHub.swift`):

```swift
/// Published before NSTextStorage applies an edit.
/// Captures state that is destroyed by the mutation.
internal struct WillEditEvent: Sendable {
    /// The range that will be replaced (UTF-16, pre-edit coordinates).
    internal var preEditRange: NSRange
    /// The text that will be inserted.
    internal var replacementText: String
    /// The affected line numbers before the edit.
    internal var preEditLineRange: ClosedRange<Int>
    /// Snapshot of the old source in the affected region. Nil when not needed.
    internal var preEditSource: String?
}

/// Observers notified before text storage applies an edit.
@MainActor
internal protocol WillEditEventObserving: AnyObject {
    func textStorageWillApplyEdit(_ event: WillEditEvent)
}
```

**Changes to `TextEditEventHub`**:
- Add parallel observer list for `WillEditEventObserving`
- Add `willPublish(_:)` method
- Add `addWillEditObserver(_:)` / `removeWillEditObserver(_:)`

**Integration point**: The `willPublish` call must happen inside `NSTextStorageDelegate.shouldChangeText(in:replacementString:)` or equivalent — this is the hook that fires *before* the storage mutation. Current `CodeEditorView+TextKitExtensions.swift` handles the `NSTextStorageDelegate` conformance; this is where the hook goes.

**Post-edit `TextEditEvent`** remains unchanged — consumers that only need post-edit state continue using `textStorageDidApplyEdit`.

---

## Step 3: RangeHighlightProviding Protocol Audit

### Current Surface

```swift
func setUp(textView: CodeEditorView, language: Language)
func willApplyEdit(textView: CodeEditorView, range: NSRange)                    // no source snapshot
func willApplyEdit(textView: CodeEditorView, source: String, range: NSRange)    // with source snapshot
func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet
func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
```

### Assessment

| Consumer | Needs met? | Notes |
|----------|-----------|-------|
| Real tree-sitter | ✅ | `willApplyEdit` with source snapshot enables byte-range translation; `applyEdit` returns invalidation set |
| LSP semantic tokens | ✅ | Can implement as a `RangeHighlightProviding` adapter; `queryHighlights` maps to token decode |
| Spell-check provider | ✅ | Extension points exist; default implementations on protocol extensions allow partial adoption |
| AI suggestions | ✅ | Same as spell-check — can implement subset of protocol |

**Recommendation**: No protocol changes needed. The surface is sufficient.

---

## Step 4: TextEditEvent Struct Audit

### Current Fields

```swift
internal struct TextEditEvent: Sendable, Equatable {
    internal var editedRange: NSRange       // pre-edit range (location + length of old text)
    internal var changeInLength: Int        // newLen - oldLen (positive for insertions)
    internal var documentLength: Int        // total length after edit
    internal var editedCharacters: Bool     // true if characters changed (vs attributes only)
}
```

### LSP Batching Assessment

For LSP `textDocument/didChange` incremental sync, we need:
- **Range start + old length** → `editedRange` provides both ✅
- **New text** → NOT in `TextEditEvent`; needs pre-edit snapshot from `WillEditEvent` (Phase 0 addition)
- **Document version** → managed by LSP coordinator, not needed in the event struct

**Recommendation**: `TextEditEvent` is adequate as-is. The missing "new text" field is intentionally captured on the `willApply` side via `WillEditEvent.replacementText` + `WillEditEvent.preEditSource`.

---

## Step 5: LanguageDescriptor Tree-Sitter Name Audit

All 26 entries (25 languages + plain text) have `treeSitterName` set. Key observations:

| Language | `treeSitterName` | Notes |
|----------|-----------------|-------|
| `.swift` | `nil` | Uses `SwiftSyntax`, not tree-sitter |
| `.shell` | `"bash"` | Canonical grammar is `tree-sitter-bash` |
| `.csharp` | `"c_sharp"` | Canonical grammar uses underscore |
| `.plainText` | `nil` | No highlighting — correct |
| All others | matching | Names align with canonical tree-sitter grammars |

**Recommendation**: No changes needed. All 25 language names are correct.

---

## Step 6: Attribute-Applier Gap Analysis

### Current Path (pre-fix)

```
handleTextStorageDidProcessEditing
  ├── publish TextEditEvent (all edits)
  ├── gutter invalidation (gated by possible line-count change)
  ├── applySyntaxHighlighting(in:) ← CALLED FOR ALL EDITS including .editedAttributes ❌
  ├── event publisher (.textDidChange)
  └── completion trigger check
```

### The Problem

When the future `RangeAttributeApplier` (Phase 2A) writes attributes to `NSTextStorage`, it triggers `NSTextStorageDidProcessEditingNotification` with `editedMask = .editedAttributes`. Without gating, the legacy `applySyntaxHighlighting` path re-runs, potentially:

1. **Looping**: applier writes attributes → notification fires → legacy highlighter runs → legacy highlighter overwrites applier's attributes → applier detects change → applier rewrites → repeat.
2. **Double-apply**: two highlighting systems racing on the same text, doubling CPU cost.

### Design: Loop Prevention (applied in Step 7)

1. **Gate `applySyntaxHighlighting` on `.editedCharacters`** — Step 7 change applied. Attribute-only edits skip the legacy highlighting path entirely.
2. **Future `RangeAttributeApplier`** uses `textStorage?.beginEditing()` / `endEditing()` to batch attribute applications within a single editing transaction, suppressing nested `.editedAttributes` notifications.
3. **Skip-equal optimization**: before applying an attribute, the applier reads the current `NSTextStorage` attribute at that range. If the value matches, skip the write — avoiding unnecessary mutation that would otherwise trigger notifications.

### Merge → Apply Path

```
StyledRangeContainer.mergedRuns(in:)
  → returns [RangeStoreRun<StyleElement>]
  → StyleElement.capture → TokenType(rawValue:).adaptiveColor
  → NSTextStorage.addAttributes(_:range:) / removeAttribute(_:range:)
    (inside beginEditing/endEditing transaction)
```

---

## Step 7: Attribute-Edit Gate Fix (IMPLEMENTED)

**File**: `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`

**Change**: `applySyntaxHighlighting(in:)` is now gated on `editedMask.contains(.editedCharacters)` in addition to `isSyntaxHighlightingEnabled`.

**Before**:
```swift
if configuration.display.isSyntaxHighlightingEnabled {
    let editedRange = textStorage.editedRange
    if editedRange.location != NSNotFound {
        applySyntaxHighlighting(in: editedRange)
    }
}
```

**After**:
```swift
if editedMask.contains(.editedCharacters),
   configuration.display.isSyntaxHighlightingEnabled
{
    let editedRange = textStorage.editedRange
    if editedRange.location != NSNotFound {
        applySyntaxHighlighting(in: editedRange)
    }
}
```

This is the prerequisite for the `RangeAttributeApplier` (Phase 2A) — without it, the applier's attribute writes would re-enter the legacy highlighting pipeline.

---

## Summary

Phase 0 audits are complete. One code change applied (attribute-edit gate fix). The pre-edit transaction model (`WillEditEvent` + `TextEditEventHub` extensions) is designed but not yet implemented — implementation belongs in Phase 0 proper (was scoped as "design" only in this audit pass; implementation is the next action item for Phase 0 completion).

**Next**: Wait for test suite to complete, then implement the pre-edit transaction model (`WillEditEvent`, protocol, hub extensions) in `TextEditEventHub.swift`.
