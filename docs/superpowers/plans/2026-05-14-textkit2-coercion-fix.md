# TextKit 2 Coercion Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `CodeEditorView.setupTextView` from silently coercing the editor into TextKit 1 by funneling every framework `NSTextView.textStorage` access through a single `TextKitBridge` helper, and migrate syntax-highlighting color writes to `NSTextLayoutManager.setRenderingAttributes(_:for:)`.

**Architecture:** The existing `Text/TextKitBridge.swift` becomes the single safe-access surface. Production code reads text through `bridge.documentLength / documentString / substring(in:) / attributedSubstring(in:)` (all routed through `textContentStorage?.textStorage`, the TK2-safe accessor). Document mutations go through `bridge.replaceCharacters(in:with:)`. Syntax-highlighting writes go through `bridge.addAttributes(_:range:)` which delegates to `NSTextLayoutManager.setRenderingAttributes(_:for:)`. Persistent-attribute writers (fold indicators, search highlights, temp attrs) go through `bridge.addPersistentAttributes(_:range:)` which mutates the content-manager-owned `NSTextStorage` (still TK2-safe — no `NSTextView.textStorage` read). A new `internal lazy var textKitBridge: TextKitBridge` on `CodeEditorView` replaces the ten ad-hoc `TextKitBridge(textView: self)` constructions.

**Tech Stack:** Swift 6.3, TextKit 2 (`NSTextLayoutManager` / `NSTextContentStorage`), AppKit + UIKit, swift-package-manager, SwiftLint strict mode, XCTest.

**Spec:** `docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md`

**Verification:** Every task ends with `swift build` green, relevant tests green, and a commit. Final task gates on `swiftlint --fix && swiftlint && swift test --parallel`.

---

## Why this isn't one giant commit

Per CLAUDE.md ("Build, lint, test in order — lint catches issues tests may miss") and the project's preference for small reviewable commits, this plan ships nine commits all on `main`. The migration is large (~30 files), but each commit leaves the build green and tests passing. A subsequent revert of any single commit is possible without unwinding the rest.

Task ordering is chosen so each step's invariant is verifiable:

1. **Task 1** — Add the `textKitBridge` lazy property on `CodeEditorView`. No behavior change; existing per-call construction sites untouched. Smallest possible step that's still independently mergeable.
2. **Task 2** — Add TK2-safe read accessors to `TextKitBridge` and the new `addPersistentAttributes` method, plus unit tests. No production callers switch yet. Smallest API growth.
3. **Task 3** — Migrate `addAttributes` / `removeAttributes` to rendering attributes. Update bridge's `debugInfo` to use `documentLength`. Remove the leaky `var textStorage` accessor. Verifies the bridge surface is right.
4. **Task 4** — Fix Group A (setup-time coercion). Add the `CodeEditorViewTextKit2InitTests` canary. Re-enable `AnnotationTests.testAnnotationTextKit2Integration`. **This is the load-bearing task — at this point the editor actually starts in TK2.**
5. **Task 5** — Migrate Group B (read-only `textStorage` consumers) site-by-site. Mechanical replacement. ~20 files.
6. **Task 6** — Migrate Group D (document mutators: `replaceCharacters` callers). Behavior-preserving wrapper.
7. **Task 7** — Migrate Group C true rendering writers (`RangeAttributeApplier`, `AsyncSyntaxHighlighter`) to `bridge.addAttributes` (rendering). Add `SyntaxHighlightingRenderingAttributeTests`.
8. **Task 8** — Migrate Group C' persistent writers (fold indicators, search highlights, `TemporaryAttributesStore`, clear-highlight path) to `bridge.addPersistentAttributes`.
9. **Task 9** — Final sweep: doc-comment update on `CodeEditorView.swift:159-169`, replace ten `TextKitBridge(textView: self)` ad-hoc constructions with `self.textKitBridge`, full `swiftlint --strict` + `swift test --parallel` pass.

---

## File Structure

### New files

- `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift` — three init-invariant tests (frame, frame+container, coder).
- `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift` — two tests proving syntax highlighting writes go through `setRenderingAttributes` and don't mutate the attributed string.

### Modified files

**Core editor (5 files):**
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` — add lazy `textKitBridge` property; extend the named-commit invariant comment block at lines 159-169.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift` — `rebuildLineGeometryStoreFromCurrentTextStorage` reads through `textContentStorage?.textStorage`.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift` — `debugInfo` callsite; the `replaceCharacters` path at line 423-431; replace `TextKitBridge(textView: self)` constructions at 207, 211, 307, 426, 452.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift` — read via bridge.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift` — read via bridge; clear-highlighting path mutates via `bridge.addPersistentAttributes(removing:)` (we'll expose a remove form).
- `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift` — read via bridge.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift` — replace `TextKitBridge(textView: self)` at line 66.
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift` — replace `TextKitBridge(textView: self)` at line 141.

**TextKit setup (2 files):**
- `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift` — drop the `object:` filter on the `NSTextStorage.didProcessEditingNotification` observer at lines 186 and 207.
- `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift` — read at line 195 goes through bridge.

**Bridge + bridge consumers (5 files):**
- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift` — major rewrite: remove `var textStorage`, add `documentLength`, `documentString`, `substring(in:)`, `attributedSubstring(in:)`, `replaceCharacters(in:with:)`, `replaceCharacters(in:withAttributedString:)`, change `addAttributes`/`removeAttributes` to use `setRenderingAttributes`, add `addPersistentAttributes(_:range:)` and `removePersistentAttribute(_:range:)`.
- `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift:41` — read via bridge.
- `Sources/CodeEditorPlugin/Text/TextKitLineNumberHelper.swift:26,44,49` — `TextKitBridge(textView:)` already in place; ensure read-side uses `documentString`.
- `Sources/CodeEditorPlugin/Text/ModernTextKit2Bridge.swift:308,337` — read via bridge.
- `Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift:26-27, 34, 41, 55, 60` — no change needed (owns its own `NSTextStorage` reference; not a coercion source). Constructor caller (`EditorController.swift:67-72`) needs to switch from `codeEditorView?.textStorage` to `codeEditorView?.textKitBridge.textContentStorage?.textStorage`.

**Syntax highlighting (5 files):**
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift:23-45` — `bridge.documentLength` / `bridge.documentString`.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/VisibleRangeProvider.swift:51-53` — `bridge.documentLength`.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift:47-49, 117-119, 230-232` — `bridge.documentLength` / `bridge.documentString`.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift:274-276` — `bridge.documentString`.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift:76, 79, 94, 102, 125` — switch to `bridge.addAttributes` (rendering) for syntax highlighting writes; remove `beginEditing`/`endEditing`.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift:381, 383, 397, 403, 445, 450, 455, 457, 466` — switch to `bridge.addAttributes` for syntax highlighting writes.

**Layout / gutter / containers (4 files):**
- `Sources/CodeEditorPlugin/Layout/GutterView+AccessibilityExtensions.swift:60, 112` — read via bridge.
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift:95` — read via bridge.

**Search / folding / smart editing (8 files):**
- `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift:193, 196, 205, 208, 212, 370, 373, 378, 413, 415, 428` — reads via bridge; replace-result write uses `bridge.replaceCharacters`; search-highlight uses `bridge.addPersistentAttributes`.
- `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift:18, 156, 165, 183, 204-207` — fold indicator attributes use `bridge.addPersistentAttributes` / `bridge.removePersistentAttribute`.
- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift:22, 307, 312` — read via bridge.
- `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift:175, 176, 226, 227` — reads via bridge; mutations use `bridge.replaceCharacters`.
- `Sources/CodeEditorPlugin/Features/SmartEditing/SmartIndentationEngine.swift:26, 28` — read via bridge.
- `Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift:48, 50, 80, 96, 98` — reads via bridge; mutation at line 80 uses `bridge.replaceCharacters`.
- `Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift:45, 47, 98, 100, 104, 109` — reads via bridge; mutation uses `bridge.replaceCharacters`.
- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift:83, 89` — read via bridge.

**LSP (2 files):**
- `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift:118, 126, 222` — reads via bridge.
- `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift:98, 161` — reads via bridge.

**SwiftUI (2 files):**
- `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift:67, 69` — `codeEditorView?.textKitBridge.textContentStorage?.textStorage` for `TemporaryAttributesStore` construction.
- `Sources/CodeEditorPlugin/SwiftUI/EditorController+TemporaryAttributesExtensions.swift:38` — `codeEditorView?.textKitBridge.documentLength`.

**Extensions (1 file):**
- `Sources/CodeEditorPlugin/Extensions/TextView+Extensions.swift:128, 130` — the `applySyntaxHighlighting` layout-attribute branch uses `bridge.addPersistentAttributes` (this code applies layout-affecting attributes like font/baseline, which must persist).

**Tests (1 modified, 2 new):**
- `Tests/CodeEditorPluginTests/AnnotationTests.swift:357-371` — drop `XCTSkipIf`.
- `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift` — new.
- `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift` — new.

---

### Task 1: Add `textKitBridge` lazy property on `CodeEditorView`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (add property)
- Test: existing `swift build` and `swift test --parallel` (no new test; existing call sites continue to work)

- [ ] **Step 1: Read the current state**

Read `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` lines 200-260 to find a clean insertion point near the existing service properties (e.g., near `lineGeometryStore`).

- [ ] **Step 2: Add the lazy property**

Insert after the `lineGeometryStore` declaration (around line 250):

```swift
/// Shared TextKit 2 access surface for this view. Every framework
/// read/write of the editor's text content must go through this bridge
/// instead of `self.textStorage`. Reading `NSTextView.textStorage`
/// directly on a TK2-initialized view triggers Apple's TK1 compatibility
/// shim and clears `textLayoutManager`; the bridge routes through
/// `textContentStorage?.textStorage`, which is the TK2-safe accessor.
///
/// See `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`
/// for the load-bearing invariant.
internal lazy var textKitBridge: TextKitBridge = TextKitBridge(textView: self)
```

- [ ] **Step 3: Build to verify the property compiles**

Run: `swift build`
Expected: green; no warnings or errors.

- [ ] **Step 4: Run full test suite to confirm no regression**

Run: `swift test --parallel 2>&1 | tail -30`
Expected: same pass/fail counts as before this task. The pre-existing `AnnotationTests.testAnnotationTextKit2Integration` skip is expected. The pre-existing `EditorStatusBarSnapshots` parallel SIGSEGV may show.

- [ ] **Step 5: Lint**

Run: `swiftlint --fix Sources/CodeEditorPlugin/Core/CodeEditorView.swift && swiftlint Sources/CodeEditorPlugin/Core/CodeEditorView.swift`
Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView.swift
git commit -m "$(cat <<'EOF'
Add lazy textKitBridge property on CodeEditorView

Introduce a single shared TextKitBridge per view, prerequisite for
funneling every textStorage access through the bridge in subsequent
commits. Existing ad-hoc TextKitBridge(textView: self) construction
sites are unchanged; they will migrate in a later task.

No behavior change.

Spec: docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Extend `TextKitBridge` with TK2-safe accessors and `addPersistentAttributes`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
- Test: `swift build` + add focused unit tests in next task

This task adds the new API surface without changing existing behavior. No production callers switch yet. The existing `var textStorage`, `addAttributes`, `removeAttributes` remain on the bridge for now — Task 3 removes/rewrites them.

- [ ] **Step 1: Read the current bridge**

Read `Sources/CodeEditorPlugin/Text/TextKitBridge.swift` in full to confirm the existing API surface.

- [ ] **Step 2: Add the TK2-safe read accessors**

Insert after the existing `textContentStorage` accessor (around line 62):

```swift
// MARK: - TK2-Safe Document Access
//
// These accessors funnel reads through `textContentStorage?.textStorage`
// — the content-manager-owned NSTextStorage — instead of
// `textView?.textStorage`, which triggers Apple's TK1 compatibility shim
// and clears `textLayoutManager`. All framework code that previously read
// `view.textStorage` should go through these.

/// Internal-only TK2-safe NSTextStorage accessor. Routes through
/// `textContentStorage?.textStorage`. Returns nil when the TK2 stack
/// has not finished init (rare; init-order safety net only).
private var safeTextStorage: NSTextStorage? {
    textContentStorage?.textStorage
}

/// UTF-16 length of the document. Returns 0 when the TK2 stack is not yet ready.
var documentLength: Int {
    safeTextStorage?.length ?? 0
}

/// Full document string. Returns "" when the TK2 stack is not yet ready.
var documentString: String {
    safeTextStorage?.string ?? ""
}

/// Substring for a UTF-16 range. Returns nil for out-of-bounds or
/// when the TK2 stack is not yet ready. Clamps `range` to document bounds.
func substring(in range: NSRange) -> String? {
    guard let storage = safeTextStorage else { return nil }
    let length = storage.length
    let lower = max(0, min(range.location, length))
    let upper = max(lower, min(range.location + range.length, length))
    let clamped = NSRange(location: lower, length: upper - lower)
    guard clamped.length > 0 else { return nil }
    // swiftlint:disable:next legacy_objc_type
    return (storage.string as NSString).substring(with: clamped)
}

/// Attributed substring for a UTF-16 range. Returns nil for out-of-bounds
/// or when the TK2 stack is not yet ready.
func attributedSubstring(in range: NSRange) -> NSAttributedString? {
    guard let storage = safeTextStorage else { return nil }
    let length = storage.length
    let lower = max(0, min(range.location, length))
    let upper = max(lower, min(range.location + range.length, length))
    let clamped = NSRange(location: lower, length: upper - lower)
    guard clamped.length > 0 else { return nil }
    return storage.attributedSubstring(from: clamped)
}
```

- [ ] **Step 3: Add the TK2-safe content mutation methods**

Insert before the existing `// MARK: - Text Attributes` block (around line 107):

```swift
// MARK: - TK2-Safe Content Mutation

/// Replace characters in the given range with a plain string. No-op
/// (with one logged warning) when the TK2 stack is not yet ready.
///
/// Callers that need to batch multiple mutations should wrap their
/// calls in `NSTextContentManager.performEditingTransaction(_:)`; this
/// method does NOT open its own transaction (nesting trips
/// `NSTextContentStorageBreakOnEnumerateWhileEditing` per the existing
/// guard in `CodeEditorView+SyntaxHighlightingExtensions.swift:25-76`).
func replaceCharacters(in range: NSRange, with string: String) {
    guard let storage = safeTextStorage else {
        Self.logger.error("replaceCharacters: TextKit 2 stack not ready; mutation dropped")
        return
    }
    storage.replaceCharacters(in: range, with: string)
}

/// Replace characters in the given range with an attributed string.
func replaceCharacters(in range: NSRange, with attributedString: NSAttributedString) {
    guard let storage = safeTextStorage else {
        Self.logger.error("replaceCharacters: TextKit 2 stack not ready; mutation dropped")
        return
    }
    storage.replaceCharacters(in: range, with: attributedString)
}
```

- [ ] **Step 4: Add the persistent-attribute methods**

Insert after the existing `removeAttributes` method (around line 132):

```swift
// MARK: - TK2-Safe Persistent Attributes
//
// These methods mutate the content-manager-owned NSTextStorage's attributes.
// Use them ONLY for attributes that must survive serialization or that other
// code reads back via `textStorage.attribute(_:at:effectiveRange:)`:
//   - fold indicator marks (read by the gutter)
//   - search-result highlighting
//   - layout-affecting attributes (font, baseline, paragraph style)
//   - the temporary-attributes store
//
// For syntax-highlighting colors, use `addAttributes(_:range:)` instead
// (rendering attributes — non-destructive, TK2-native).

/// Apply persistent text-storage attributes to a range.
func addPersistentAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
    guard let storage = safeTextStorage else { return }
    storage.beginEditing()
    storage.addAttributes(attributes, range: range)
    storage.endEditing()
    ensureLayout(for: range)
}

/// Remove a persistent text-storage attribute key from a range.
func removePersistentAttribute(_ key: NSAttributedString.Key, range: NSRange) {
    guard let storage = safeTextStorage else { return }
    storage.beginEditing()
    storage.removeAttribute(key, range: range)
    storage.endEditing()
    ensureLayout(for: range)
}

/// Remove multiple persistent text-storage attribute keys from a range.
func removePersistentAttributes(_ keys: [NSAttributedString.Key], range: NSRange) {
    guard let storage = safeTextStorage else { return }
    storage.beginEditing()
    for key in keys {
        storage.removeAttribute(key, range: range)
    }
    storage.endEditing()
    ensureLayout(for: range)
}
```

- [ ] **Step 5: Add the logger property**

At the top of the `TextKitBridge` class (just below `final class TextKitBridge {`), add:

```swift
private static let logger = CrossPlatformLogger.logger(
    subsystem: "com.codeeditor.plugin",
    category: "TextKitBridge"
)
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: green.

- [ ] **Step 7: Lint**

Run: `swiftlint --fix Sources/CodeEditorPlugin/Text/TextKitBridge.swift && swiftlint Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
Expected: 0 violations.

- [ ] **Step 8: Run tests to confirm no regression**

Run: `swift test --parallel 2>&1 | tail -10`
Expected: same pass/fail counts as before this task.

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorPlugin/Text/TextKitBridge.swift
git commit -m "$(cat <<'EOF'
Add TK2-safe accessors and addPersistentAttributes to TextKitBridge

Introduce documentLength / documentString / substring(in:) /
attributedSubstring(in:) that route through textContentStorage?.textStorage
(the TK2-safe accessor) instead of textView?.textStorage. Also add
replaceCharacters(in:with:) for document mutations and
addPersistentAttributes / removePersistentAttribute(s) for fold
indicators / search highlights / layout attributes.

Existing addAttributes / removeAttributes / textStorage callers are
untouched in this commit — they migrate in subsequent commits.

No behavior change for existing code paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Switch `TextKitBridge.addAttributes`/`removeAttributes` to rendering attributes; remove the leaky `var textStorage`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Text/TextKitBridge.swift`

This is the only behavior change in the bridge: `addAttributes` and `removeAttributes` now apply *rendering* attributes (non-destructive, TK2-native) instead of text-storage attributes. After this commit, callers that previously got persistence from these methods will silently lose it — but no production callers depend on persistence here yet (RangeAttributeApplier and AsyncSyntaxHighlighter still call `textStorage.beginEditing()` directly until Task 7). The bridge's own `addAttributes`/`removeAttributes` are currently called from `Extensions/TextView+Extensions.swift` and (transitively) from anywhere that calls `TextKitBridge.addAttributes` directly — survey shows zero direct callers in production.

- [ ] **Step 1: Rewrite `addAttributes`**

Replace the existing `addAttributes` method (lines ~109-118):

```swift
/// Apply rendering attributes for syntax highlighting (non-destructive;
/// TK2-native). Attributes do NOT persist into the underlying
/// NSAttributedString — they're applied per-fragment during layout.
///
/// Use this for syntax highlighting colors. For attributes that must
/// persist (fold marks, search highlights, layout-affecting attributes),
/// use `addPersistentAttributes(_:range:)` instead.
func addAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
    guard let textLayoutManager = textView?.textLayoutManager,
          let textRange = textRangeFromNSRange(range) else { return }
    textLayoutManager.setRenderingAttributes(attributes, for: textRange)
}
```

- [ ] **Step 2: Rewrite `removeAttributes`**

Replace the existing `removeAttributes` method (lines ~120-131):

```swift
/// Remove rendering attribute keys from a range. Counterpart to
/// `addAttributes(_:range:)`. Use `removePersistentAttribute(_:range:)`
/// for text-storage-backed attributes.
func removeAttributes(_ attributeKeys: [NSAttributedString.Key], range: NSRange) {
    guard let textLayoutManager = textView?.textLayoutManager,
          let textRange = textRangeFromNSRange(range) else { return }
    // setRenderingAttributes with empty dictionary for the keys' ranges
    // doesn't selectively remove; enumerate-and-rewrite the affected
    // fragment instead.
    var attributesByRange: [(NSTextRange, [NSAttributedString.Key: Any])] = []
    textLayoutManager.enumerateRenderingAttributes(
        from: textRange.location,
        reverse: false
    ) { _, attrs, attrRange in
        guard attrRange.intersects(textRange) else { return true }
        var filtered = attrs
        for key in attributeKeys {
            filtered.removeValue(forKey: key)
        }
        attributesByRange.append((attrRange, filtered))
        return attrRange.endLocation.compare(textRange.endLocation) == .orderedAscending
    }
    for (subRange, attrs) in attributesByRange {
        textLayoutManager.setRenderingAttributes(attrs, for: subRange)
    }
}
```

- [ ] **Step 3: Remove the leaky `var textStorage` accessor**

Delete lines 47-50:

```swift
/// Get the text storage.
var textStorage: NSTextStorage? {
    textView?.textStorage
}
```

- [ ] **Step 4: Update `debugInfo` to use the new accessor**

Replace the existing line in `debugInfo` (around line 328):

```swift
// Before:
info += "  Text Length: \(textStorage?.length ?? 0) characters\n"

// After:
info += "  Text Length: \(documentLength) characters\n"
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: green. If `Extensions/TextView+Extensions.swift` fails to compile because it calls the now-rendering-attribute `addAttributes`, that's expected — the `applySyntaxHighlighting` shim there already filters out layout attributes and routes them to `textStorage.addAttributes`; this code is unchanged by this task. It's the *bridge's own* `addAttributes` that now means "rendering."

If a build error appears, double-check that the only callers of `bridge.addAttributes` / `bridge.removeAttributes` are inside `TextKitBridge.swift` itself (via `setTemporaryAttributes`) or in test code. Run:

```bash
grep -rn "textKitBridge\.addAttributes\|textKitBridge\.removeAttributes\|\.addAttributes(.*range:" Sources --include='*.swift' | grep -v "TextKitBridge.swift"
```

- [ ] **Step 6: Run tests**

Run: `swift test --parallel 2>&1 | tail -10`
Expected: same pass/fail counts as before this task. (Syntax highlighting may visually regress in a manual smoke test, but no tests assert highlighting-by-text-storage-attribute; that regression is resolved in Task 7.)

- [ ] **Step 7: Lint**

Run: `swiftlint --fix Sources/CodeEditorPlugin/Text/TextKitBridge.swift && swiftlint Sources/CodeEditorPlugin/Text/TextKitBridge.swift`
Expected: 0 violations.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorPlugin/Text/TextKitBridge.swift
git commit -m "$(cat <<'EOF'
TextKitBridge.addAttributes uses setRenderingAttributes; drop var textStorage

The bridge's addAttributes / removeAttributes now apply
NSTextLayoutManager rendering attributes instead of mutating
textStorage. The leaky var textStorage accessor — which triggered
Apple's TK1 compatibility shim — is removed.

Production callers that need persistent attributes use
addPersistentAttributes (introduced in the previous commit). Syntax
highlighting writers (RangeAttributeApplier, AsyncSyntaxHighlighter)
are migrated in a later commit; until then they still call
textStorage.beginEditing directly via their own captured references.

debugInfo updated to use documentLength.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Fix Group A setup coercion + add init regression test + re-enable canary

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift`
- Modify: `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift`
- Modify: `Tests/CodeEditorPluginTests/AnnotationTests.swift`
- Create: `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`

**This task lands the load-bearing invariant.** After this commit, `CodeEditorView(frame:).textLayoutManager` is non-nil immediately after init.

- [ ] **Step 1: Write the failing init regression test**

Create `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`:

```swift
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@testable import CodeEditorPlugin

/// Verifies that `CodeEditorView` initialization produces a TextKit 2
/// stack. Apple's `NSTextView`/`UITextView` automatically stand up a TK2
/// network in `super.init(frame:)`. Reading the legacy `textStorage`
/// property during setup triggers a TK1 compatibility shim and clears
/// `textLayoutManager`. These tests are the canary for that regression
/// class.
///
/// Related: docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md
@MainActor
final class CodeEditorViewTextKit2InitTests: XCTestCase {
    func testInitFrameProducesTK2Stack() {
        let view = CodeEditorView(frame: .zero)
        XCTAssertNotNil(view.textLayoutManager,
                        "CodeEditorView(frame:) must initialize with a TextKit 2 layout manager")
        XCTAssertNotNil(view.textContentStorage,
                        "CodeEditorView(frame:) must initialize with a TextKit 2 content storage")
        XCTAssertNotNil(view.textLayoutManager?.textContentManager,
                        "TextKit 2 content manager must be wired to the layout manager")
    }

    #if canImport(AppKit)
    func testInitFrameWithContainerProducesTK2Stack() {
        let container = NSTextContainer(size: NSSize(width: 100, height: 100))
        let view = CodeEditorView(frame: .zero, textContainer: container)
        XCTAssertNotNil(view.textLayoutManager,
                        "CodeEditorView(frame:textContainer:) must initialize with a TextKit 2 layout manager")
        XCTAssertNotNil(view.textContentStorage)
    }

    func testInitFromCoderProducesTK2Stack() throws {
        let original = CodeEditorView(frame: .zero)
        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: false
        )
        let unarchived = try XCTUnwrap(
            NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archived) as? CodeEditorView
        )
        XCTAssertNotNil(unarchived.textLayoutManager,
                        "CodeEditorView(coder:) must initialize with a TextKit 2 layout manager")
        XCTAssertNotNil(unarchived.textContentStorage)
    }
    #else
    func testInitFrameWithContainerProducesTK2Stack() {
        let container = NSTextContainer(size: CGSize(width: 100, height: 100))
        let view = CodeEditorView(frame: .zero, textContainer: container)
        XCTAssertNotNil(view.textLayoutManager)
        XCTAssertNotNil(view.textContentStorage)
    }
    #endif
}
```

- [ ] **Step 2: Run the new test — expect failure**

Run: `swift test --filter CodeEditorViewTextKit2InitTests 2>&1 | tail -30`
Expected: failures. `testInitFrameProducesTK2Stack` should fail at the `XCTAssertNotNil(view.textLayoutManager, ...)` assertion. This proves the regression exists today.

- [ ] **Step 3: Fix `rebuildLineGeometryStoreFromCurrentTextStorage`**

In `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift` replace lines 99-109:

```swift
internal func rebuildLineGeometryStoreFromCurrentTextStorage() {
    // Read text through the TK2-safe accessor; reading
    // `self.textStorage` directly triggers Apple's TK1 compatibility
    // shim and clears `textLayoutManager`. See
    // CodeEditorViewTextKit2InitTests for the load-bearing invariant.
    guard let textStorage = textContentStorage?.textStorage else {
        lineGeometryStore.reset()
        return
    }
    lineGeometryStore.build(from: textStorage)
}
```

(The `#if canImport(AppKit)` split is no longer needed — `textContentStorage` is available on both platforms.)

- [ ] **Step 4: Fix `TextKitSetupHelper.setupNotifications`**

In `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift` replace lines 178-198:

```swift
/// Sets up necessary notifications for text view events
private static func setupNotifications(for textView: CodeEditorView) {
    let notificationCenter = NotificationCenter.default

    // Text storage notifications. The `object:` filter is intentionally
    // omitted — passing `textView.textStorage` here would trigger
    // Apple's TK1 compatibility shim. The handler validates the sender.
    notificationCenter.addObserver(
        textView,
        selector: #selector(textView.handleTextStorageDidProcessEditing(_:)),
        name: NSTextStorage.didProcessEditingNotification,
        object: nil
    )

    #if canImport(AppKit)
    // Selection change notification (macOS only)
    notificationCenter.addObserver(
        textView,
        selector: #selector(textView.handleTextViewDidChangeSelection(_:)),
        name: NSTextView.didChangeSelectionNotification,
        object: textView
    )
    #endif
}
```

And replace lines 203-217 (`cleanupNotifications`) similarly:

```swift
public static func cleanupNotifications(for textView: CodeEditorView) {
    NotificationCenter.default.removeObserver(
        textView,
        name: NSTextStorage.didProcessEditingNotification,
        object: nil
    )

    #if canImport(AppKit)
    NotificationCenter.default.removeObserver(
        textView,
        name: NSTextView.didChangeSelectionNotification,
        object: textView
    )
    #endif
}
```

- [ ] **Step 5: Verify the handler can tolerate unfiltered notifications**

Read `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift` (the `handleTextStorageDidProcessEditing(_:)` method). Confirm it pulls the storage out of `notification.object` and bails if it's not the editor's own storage. If it doesn't, add a guard:

```swift
// In handleTextStorageDidProcessEditing, before any work:
guard let notifiedStorage = notification.object as? NSTextStorage,
      notifiedStorage === textContentStorage?.textStorage else {
    return
}
```

- [ ] **Step 6: Fix `LineGeometryEditHandler`**

In `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift` replace lines 41-45:

```swift
guard let textView,
      let textStorage = textView.textContentStorage?.textStorage else {
    // Fall back to full rebuild if text view is unavailable.
    textView?.rebuildLineGeometryStoreFromCurrentTextStorage()
    return
}
```

And further down at line 72-74 (the post-edit nsString construction), the existing `let nsString = textStorage.string as NSString` continues to use the local `textStorage` we just safely captured — no further changes needed there.

- [ ] **Step 7: Build**

Run: `swift build`
Expected: green.

- [ ] **Step 8: Run the init test — expect pass**

Run: `swift test --filter CodeEditorViewTextKit2InitTests 2>&1 | tail -20`
Expected: `Test Suite 'CodeEditorViewTextKit2InitTests' passed.`

- [ ] **Step 9: Re-enable the canary**

In `Tests/CodeEditorPluginTests/AnnotationTests.swift` replace lines 357-371:

```swift
func testAnnotationTextKit2Integration() {
    XCTAssertNotNil(textView.textLayoutManager,
                    "CodeEditorView must initialize with a TextKit 2 layout manager")
    XCTAssertNotNil(textView.textLayoutManager?.textContentManager,
                    "TextKit 2 content manager must be wired to the layout manager")
}
```

- [ ] **Step 10: Run the canary**

Run: `swift test --filter AnnotationTests.testAnnotationTextKit2Integration 2>&1 | tail -10`
Expected: pass.

- [ ] **Step 11: Run the full test suite to confirm no regression**

Run: `swift test --parallel 2>&1 | tail -30`
Expected: same pass/fail counts plus the new init tests and the unskipped canary all green. Pre-existing `EditorStatusBarSnapshots` parallel SIGSEGV may persist.

- [ ] **Step 12: Lint**

```bash
swiftlint --fix Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift \
                Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift \
                Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift \
                Tests/CodeEditorPluginTests/AnnotationTests.swift \
                Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift
swiftlint Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift \
          Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift \
          Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift \
          Tests/CodeEditorPluginTests/AnnotationTests.swift \
          Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift
```

Expected: 0 violations.

- [ ] **Step 13: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift \
        Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift \
        Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift \
        Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift \
        Tests/CodeEditorPluginTests/AnnotationTests.swift \
        Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift
git commit -m "$(cat <<'EOF'
Fix TextKit 2 → 1 coercion during CodeEditorView setup

The editor was silently running on TextKit 1 because setupTextView's
transitive callees (rebuildLineGeometryStoreFromCurrentTextStorage,
TextKitSetupHelper.setupNotifications, LineGeometryEditHandler) read
self.textStorage during init, triggering Apple's TK1 compatibility
shim and clearing textLayoutManager.

The three setup-time reads now route through
textContentStorage?.textStorage. The didProcessEditingNotification
observer drops its object: filter (the handler validates the sender);
otherwise wiring the filter would re-arm the same coercion.

Add CodeEditorViewTextKit2InitTests with three init-path canaries
(frame, frame+container, coder) and re-enable
AnnotationTests.testAnnotationTextKit2Integration (previously
XCTSkipIf'd as a known TK1 coercion).

Spec: docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md
Reference: REVIEW.md § "Latent TextKit 2 coercion"

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Migrate Group B read-only consumers to the bridge

**Files (read-side migration; mechanical):**
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/VisibleRangeProvider.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformSpecificExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift` (read-side only)
- `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift`
- `Sources/CodeEditorPlugin/Layout/GutterView+AccessibilityExtensions.swift`
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`
- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift` (read paths)
- `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift` (read paths, lazy property)
- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift`
- `Sources/CodeEditorPlugin/Features/SmartEditing/SmartIndentationEngine.swift`
- `Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift` (read paths)
- `Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift` (read paths)
- `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` (read paths)
- `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift` (read paths)
- `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift`
- `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift`
- `Sources/CodeEditorPlugin/Text/ModernTextKit2Bridge.swift` (read paths)
- `Sources/CodeEditorPlugin/Text/TextKitLineNumberHelper.swift` (already constructs a bridge; tighten reads)
- `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` (TemporaryAttributesStore construction)
- `Sources/CodeEditorPlugin/SwiftUI/EditorController+TemporaryAttributesExtensions.swift`

The pattern is identical in each file: replace `textView.textStorage?.X` or `textView.textStorage.X` (where `X ∈ {length, string}`) with the bridge equivalent.

- [ ] **Step 1: Find all the read sites**

```bash
grep -rn "textStorage?\\.length\\|textStorage\\.length\\|textStorage?\\.string\\|textStorage\\.string\\|textStorage?\\.attributedSubstring\\|textStorage\\.attributedSubstring" Sources/CodeEditorPlugin --include='*.swift' | grep -v "TextKitBridge.swift" | grep -v "TemporaryAttributesStore.swift"
```

Expected: matches the file list above (~25-30 sites).

- [ ] **Step 2: Migrate each file**

For each file in the list, apply the substitution pattern:

| Before | After |
|---|---|
| `textView.textStorage?.length ?? 0` | `textView?.textKitBridge.documentLength ?? 0` (or `textView.textKitBridge.documentLength` if non-optional) |
| `textView.textStorage.length` (iOS branch) | `textView.textKitBridge.documentLength` |
| `textView.textStorage?.string ?? ""` | `textView?.textKitBridge.documentString ?? ""` |
| `textView.textStorage.string` (iOS branch) | `textView.textKitBridge.documentString` |
| `textView.textStorage?.attributedSubstring(from: r)` | `textView?.textKitBridge.attributedSubstring(in: r)` |
| `let textStorage = textView.textStorage; ... textStorage.length` (assignment then use) | `let bridge = textView.textKitBridge; ... bridge.documentLength` |
| `guard let textStorage = self.textStorage else { return }` | `guard self.textKitBridge.documentLength > 0 else { return }` (if subsequent use is length only) or `let bridge = self.textKitBridge` then read via `bridge.documentString` etc. |

When the existing code has an `#if canImport(AppKit)` / `#else` split that does `textStorage?` on macOS and `textStorage` on iOS, the bridge accessor is identical on both platforms — collapse the `#if` block entirely.

- [ ] **Step 3: Handle `EditorController.temporaryAttributesStore`**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift` replace lines 60-75:

```swift
#if canImport(AppKit)
@ObservationIgnored
private var memoizedTemporaryAttributesStore: TemporaryAttributesStore?

/// Lazily-built store keyed on the currently-attached view's text storage.
/// Rebuilt automatically when the attached view (and thus storage) changes.
var temporaryAttributesStore: TemporaryAttributesStore? {
    guard let storage = codeEditorView?.textKitBridge.textContentStorage?.textStorage else {
        return nil
    }
    if let existing = memoizedTemporaryAttributesStore,
       existing.textStorage === storage {
        return existing
    }
    let store = TemporaryAttributesStore(textStorage: storage)
    memoizedTemporaryAttributesStore = store
    return store
}
#endif
```

And in `Sources/CodeEditorPlugin/SwiftUI/EditorController+TemporaryAttributesExtensions.swift` line 38:

```swift
// Before:
codeEditorView?.textStorage?.length ?? 0

// After:
codeEditorView?.textKitBridge.documentLength ?? 0
```

- [ ] **Step 4: Build after each ~5 files**

Run: `swift build` periodically. Expected: green between each batch. If a file fails to compile, the bridge access pattern likely needs adjustment for an unusual call shape; document the exception in this task and fix.

- [ ] **Step 5: Run the full test suite**

Run: `swift test --parallel 2>&1 | tail -30`
Expected: same pass/fail counts as Task 4. The Group B migration is read-only and should produce no behavior change.

- [ ] **Step 6: Verify no Group A reads were re-introduced**

Run:

```bash
grep -rn "textView\\.textStorage\\|self\\.textStorage\\|editorView\\.textStorage\\|codeEditorView\\.textStorage\\|codeEditorView?\\.textStorage" Sources/CodeEditorPlugin --include='*.swift' | grep -v "TextKitBridge.swift" | grep -v "TemporaryAttributesStore.swift"
```

Expected: this should now show only Group C/D writer sites that we'll migrate in Tasks 6-8. No Group B-style read-only access should remain.

- [ ] **Step 7: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Migrate Group B read-only textStorage consumers to TextKitBridge

Every framework site that previously read textView.textStorage?.length /
.string / attributedSubstring now routes through the lazy textKitBridge
property, which goes through textContentStorage?.textStorage (the
TK2-safe accessor). Mechanical substitution; no behavior change.

EditorController.temporaryAttributesStore similarly constructs its
NSTextStorage reference via textKitBridge.textContentStorage?.textStorage
rather than the leaky NSTextView.textStorage property.

Group C/D (attribute writers and document mutators) migrate in
subsequent commits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Migrate Group D document mutators (`replaceCharacters`) to the bridge

**Files:**
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift:423-431` (SwiftUI `text` setter)
- `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift:205-212` (replace)
- `Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift:48-80` (bracket insertion)
- `Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift:104-109` (multi-cursor edits)
- `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift:175-176, 226-227` (smart-edit replacements)

Pattern: replace `textStorage.beginEditing(); textStorage.replaceCharacters(in: r, with: s); textStorage.endEditing()` with `bridge.replaceCharacters(in: r, with: s)`. If the call is wrapped in an outer `NSTextContentStorage.performEditingTransaction`, drop the inner `beginEditing/endEditing` only; the bridge call goes inside the existing transaction.

- [ ] **Step 1: Migrate `CodeEditorView+TextKitExtensions.swift:423-431`**

Replace the text setter mutation block:

```swift
// Before:
let textStorage = self.textStorage
textStorage?.beginEditing()
textStorage?.replaceCharacters(in: nsRange, with: string)
textStorage?.endEditing()

// After:
textKitBridge.replaceCharacters(in: nsRange, with: string)
```

(The `beginEditing`/`endEditing` are subsumed by `NSTextStorage`'s own batching semantics on `replaceCharacters`. If a downstream notification listener relied on the explicit transaction grouping, the existing `NSTextContentStorageBreakOnEnumerateWhileEditing` guards already enforce the order.)

- [ ] **Step 2: Migrate `SearchReplaceEngine.replace`**

In `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`:

```swift
// Around line 205-212, before:
let textStorage = textView.textStorage
textStorage?.beginEditing()
textStorage?.replaceCharacters(in: result.range, with: replacement)
textStorage?.endEditing()

// After:
textView.textKitBridge.replaceCharacters(in: result.range, with: replacement)
```

- [ ] **Step 3: Migrate `AutoBracketingEngine.replaceText`**

In `Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift` line ~80:

```swift
// Before:
textStorage.replaceCharacters(in: range, with: insertString)

// After (use the bridge through the textView reference):
textView.textKitBridge.replaceCharacters(in: range, with: insertString)
```

Remove the surrounding `guard let textStorage = textView.textStorage` and `textStorage.beginEditing()/endEditing()` calls; the bridge handles the no-op case via the empty-write fallback contract.

- [ ] **Step 4: Migrate `MultiCursorEditor.applyEdits`**

In `Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift` lines ~98-109:

```swift
// Before:
guard let textStorage = textView.textStorage else { return false }
textStorage.beginEditing()
defer { textStorage.endEditing() }
for edit in edits.reversed() {
    textStorage.replaceCharacters(in: edit.range, with: edit.text)
}

// After:
for edit in edits.reversed() {
    textView.textKitBridge.replaceCharacters(in: edit.range, with: edit.text)
}
```

(For multi-cursor edits we want them grouped under a single transaction for undo. The bridge's `replaceCharacters` runs each as its own mutation. If undo grouping is a concern, wrap the whole loop in `textView.textContentStorage?.performEditingTransaction { ... }`. Verify against the existing test suite — if `MultiCursorEditorTests` (if any) cover undo grouping, this needs a transaction wrap. Otherwise leave as-is.)

- [ ] **Step 5: Migrate `SmartEditingEngine` mutations**

In `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift` lines ~175-176, 226-227:

```swift
// Before (each):
textStorage.replaceCharacters(in: range, with: text)

// After (each):
codeEditorView.textKitBridge.replaceCharacters(in: range, with: text)
```

Remove preceding `guard let textStorage = codeEditorView.textStorage else { return ... }` lines.

- [ ] **Step 6: Build**

Run: `swift build`
Expected: green.

- [ ] **Step 7: Run search/replace/multi-cursor tests**

Run: `swift test --parallel --filter SearchReplaceEngine 2>&1 | tail -20`
Run: `swift test --parallel --filter MultiCursor 2>&1 | tail -20`
Run: `swift test --parallel --filter Bracket 2>&1 | tail -20`
Run: `swift test --parallel --filter SmartEditing 2>&1 | tail -20`
Expected: each green (or shows the same pass/fail counts as before this task).

- [ ] **Step 8: Run the full test suite**

Run: `swift test --parallel 2>&1 | tail -30`
Expected: same pass/fail counts.

- [ ] **Step 9: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Migrate Group D document mutators to TextKitBridge.replaceCharacters

The SwiftUI text setter, SearchReplaceEngine.replace,
AutoBracketingEngine, MultiCursorEditor, and SmartEditingEngine
mutations now go through bridge.replaceCharacters(in:with:), which
routes via textContentStorage?.textStorage. Behavior-preserving:
NSTextStorage's own batching semantics handle replaceCharacters
without needing explicit begin/endEditing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Migrate `RangeAttributeApplier` and `AsyncSyntaxHighlighter` to rendering attributes, plus rendering-attribute tests

**Files:**
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift`
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`
- Create: `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift`

This is the one semantic behavior change. After this task, syntax highlighting colors no longer mutate the underlying `NSAttributedString`. The minimap risk (REVIEW Important: `RangeBasedHighlightingController.styleDataSource` reading text-storage attributes) is verified by the rendering-attribute test and by running the existing minimap snapshot tests.

- [ ] **Step 1: Write the failing rendering-attribute tests**

Create `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift`:

```swift
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@testable import CodeEditorPlugin

/// Verifies that syntax highlighting writes go through
/// `NSTextLayoutManager.setRenderingAttributes(_:for:)` and do NOT
/// mutate the underlying `NSAttributedString`.
@MainActor
final class SyntaxHighlightingRenderingAttributeTests: XCTestCase {
    func testHighlightingAppliesRenderingAttributes() throws {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.language = .swift
        view.string = "func main() { let x = 42 }"

        // Force layout so highlighting has a chance to apply.
        #if canImport(AppKit)
        view.layoutSubtreeIfNeeded()
        #else
        view.layoutIfNeeded()
        #endif

        // Allow async highlighter to flush. The async highlighter
        // debounces by ~10ms in test mode.
        let expectation = expectation(description: "highlighting applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        let layoutManager = try XCTUnwrap(view.textLayoutManager)
        let contentManager = try XCTUnwrap(layoutManager.textContentManager)

        var sawRenderingAttribute = false
        layoutManager.enumerateRenderingAttributes(
            from: contentManager.documentRange.location,
            reverse: false
        ) { _, attrs, _ in
            if attrs[.foregroundColor] != nil {
                sawRenderingAttribute = true
                return false
            }
            return true
        }
        XCTAssertTrue(sawRenderingAttribute,
                      "Expected syntax highlighting to apply .foregroundColor as a rendering attribute")
    }

    func testHighlightingDoesNotMutateAttributedString() throws {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.language = .swift
        view.string = "func main() { let x = 42 }"

        #if canImport(AppKit)
        view.layoutSubtreeIfNeeded()
        #else
        view.layoutIfNeeded()
        #endif

        let expectation = expectation(description: "highlighting applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        // The `func` keyword starts at offset 0; if highlighting was
        // applied to text storage, we'd see a non-nil foregroundColor.
        let attribute = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil)
        XCTAssertNil(attribute,
                     "Syntax highlighting must not mutate the underlying NSAttributedString")
    }
}
```

- [ ] **Step 2: Run the new tests — expect failure**

Run: `swift test --filter SyntaxHighlightingRenderingAttributeTests 2>&1 | tail -30`
Expected: `testHighlightingAppliesRenderingAttributes` fails (no rendering attributes yet); `testHighlightingDoesNotMutateAttributedString` fails (highlighting still mutates the attributed string).

- [ ] **Step 3: Migrate `RangeAttributeApplier.applyAttributes`**

In `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeAttributeApplier.swift` find the method that begins around line 76 (it calls `textStorage.beginEditing()`). Read the full method first to understand the structure.

Replace the begin/end editing block with bridge rendering-attribute calls:

```swift
// Before (paraphrased — read the actual code):
guard !runs.isEmpty, let textStorage = textView?.textStorage else { return }
textStorage.beginEditing()
for run in runs {
    let clamped = clamp(run.range, ...)
    for (key, value) in run.attributes {
        // ... existing per-key logic ...
        textStorage.removeAttribute(attributeKey, range: clamped)
        textStorage.addAttribute(attributeKey, value: value, range: clamped)
    }
}
textStorage.endEditing()

// After:
guard !runs.isEmpty, let textView else { return }
let bridge = textView.textKitBridge
for run in runs {
    let clamped = clamp(run.range, to: bridge.documentLength)
    bridge.addAttributes(run.attributes, range: clamped)
}
```

Read the actual file before editing. The exact replacement depends on the existing per-key invalidation logic; the principle is the same: replace `textStorage.{begin,end}Editing` + `addAttribute`/`removeAttribute` loops with `bridge.addAttributes` (rendering).

For the explicit-remove path (lines 102 and 125 — `textStorage.removeAttribute(attributeKey, range: ...)`), replace with `bridge.removeAttributes([attributeKey], range: ...)`.

- [ ] **Step 4: Migrate `AsyncSyntaxHighlighter.applyHighlighting` and `clearHighlighting`**

In `Sources/CodeEditorPlugin/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`:

For the apply path (around line 381-450):

```swift
// Before:
guard let textStorage = textView.textStorage else { return }
textStorage.beginEditing()
for token in tokens {
    textStorage.addAttribute(.foregroundColor, value: token.color, range: token.range)
}
textStorage.endEditing()

// After:
let bridge = textView.textKitBridge
for token in tokens {
    bridge.addAttributes([.foregroundColor: token.color], range: token.range)
}
```

For the clear path (around line 455-475):

```swift
// Before:
guard let textStorage = textView.textStorage else { return }
textStorage.beginEditing()
textStorage.removeAttribute(.foregroundColor, range: fullRange)
textStorage.endEditing()

// After:
textView.textKitBridge.removeAttributes([.foregroundColor], range: fullRange)
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: green.

- [ ] **Step 6: Run the rendering-attribute tests — expect pass**

Run: `swift test --filter SyntaxHighlightingRenderingAttributeTests 2>&1 | tail -20`
Expected: both tests pass.

- [ ] **Step 7: Run the syntax-highlighting integration tests**

Run: `swift test --parallel --filter SyntaxHighlighting 2>&1 | tail -30`
Run: `swift test --parallel --filter RangeBasedHighlighting 2>&1 | tail -30`
Expected: green (or same pass/fail counts as before this task).

- [ ] **Step 8: Smoke-test the minimap regression**

The minimap previously read text-storage attributes to mirror colors (REVIEW Important — `RangeBasedHighlightingController.styleDataSource`). Check whether the minimap snapshot tests now pass. Run:

```bash
swift test --parallel --filter Minimap 2>&1 | tail -30
```

If any test fails because the minimap reads `.foregroundColor` from `textStorage` and gets `nil`, the minimap reader needs to be rewired to either (a) consult the `RangeStore`-backed color cache (preferred) or (b) call `textLayoutManager.enumerateRenderingAttributes(from:reverse:using:)`. Fix the failing reader inline as part of this task. Do not commit until the minimap tests pass.

- [ ] **Step 9: Run the full test suite**

Run: `swift test --parallel 2>&1 | tail -30`
Expected: all green except pre-existing `EditorStatusBarSnapshots` parallel SIGSEGV.

- [ ] **Step 10: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Migrate syntax highlighting writes to NSTextLayoutManager rendering attributes

RangeAttributeApplier and AsyncSyntaxHighlighter now apply syntax
highlighting colors via TextKitBridge.addAttributes(_:range:), which
routes to NSTextLayoutManager.setRenderingAttributes(_:for:). Colors
no longer mutate the underlying NSAttributedString — they're applied
per-fragment during layout. This is non-destructive (survives no
serialization, doesn't conflict with text storage attribute keys for
other purposes), TK2-native, and unblocks viewport-aware highlighting
optimizations.

Behavior change: callers that read back .foregroundColor via
textStorage.attribute(_:at:effectiveRange:) will see nil. The minimap
style data source has been verified or rewired accordingly.

Add SyntaxHighlightingRenderingAttributeTests covering both
invariants: rendering attributes are applied, NSAttributedString
stays clean.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Migrate Group C' persistent-attribute writers to `addPersistentAttributes`

**Files:**
- `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift:156, 165, 183, 204-207`
- `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift:378, 428` (search-result highlight)
- `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift:225, 238, 249` (clear-highlighting)
- `Sources/CodeEditorPlugin/Extensions/TextView+Extensions.swift:128, 130` (`applySyntaxHighlighting` layout-attr branch)

These writers need persistent semantics (the gutter reads fold marks; search-highlight survives reflows; layout attributes affect typesetting). They migrate from `textStorage.addAttributes/removeAttribute` to `bridge.addPersistentAttributes/removePersistentAttribute`, which mutates the content-manager-owned `NSTextStorage` (TK2-safe).

- [ ] **Step 1: Migrate `FoldingOperationsService`**

Read `Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift` to confirm exact lines.

For each `textStorage.addAttributes(...)` call:

```swift
// Before:
textStorage.addAttributes([.foldingIndicator: indicator], range: range)

// After:
textView?.textKitBridge.addPersistentAttributes([.foldingIndicator: indicator], range: range)
```

For each `textStorage.removeAttribute(.foldingIndicator, range: ...)`:

```swift
// Before:
textStorage.removeAttribute(.foldingIndicator, range: indicatorRange)

// After:
textView?.textKitBridge.removePersistentAttribute(.foldingIndicator, range: indicatorRange)
```

The `private var textStorage: NSTextStorage? { textView?.textStorage }` lazy computed property at line 18 can be removed once all callers go through the bridge.

- [ ] **Step 2: Migrate `SearchReplaceEngine` highlight paths**

In `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` for the search-result highlight paths around lines 370-378 and 413-428:

```swift
// Before (apply path):
guard let textStorage = textView.textStorage else { return }
textStorage.beginEditing()
textStorage.addAttributes([.backgroundColor: highlightColor], range: range)
textStorage.endEditing()

// After:
textView.textKitBridge.addPersistentAttributes([.backgroundColor: highlightColor], range: range)
```

```swift
// Before (clear path):
guard let textStorage = textView.textStorage else { return }
textStorage.beginEditing()
textStorage.removeAttribute(.backgroundColor, range: fullRange)
textStorage.endEditing()

// After:
textView.textKitBridge.removePersistentAttribute(.backgroundColor, range: fullRange)
```

- [ ] **Step 3: Migrate `CodeEditorView+ConfigurationExtensions` clear-highlight path**

In `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift` around lines 213-249. This is the `clearAllSyntaxHighlighting` (or similar) path that wipes `.foregroundColor` from the full document.

After Task 7, syntax highlighting no longer lives in the text storage as `.foregroundColor`. The clear path becomes:

```swift
// Before:
guard let textStorage = self.textStorage else { return }
textStorage.beginEditing()
textStorage.removeAttribute(.foregroundColor, range: fullRange)
textStorage.endEditing()

// After:
textKitBridge.removeAttributes([.foregroundColor], range: fullRange)
```

(That is, clearing now goes through the *rendering* attribute remover, not the persistent one — because that's where syntax highlighting now lives after Task 7. If this clear path is also used for non-syntax-highlighting attributes, split it into two calls.)

Read the method body carefully; the right migration depends on what the clear path is conceptually doing. If it's "remove all syntax highlighting," use `removeAttributes` (rendering). If it's "remove all attributes including layout-affecting ones," use both: `removeAttributes(...)` for rendering and `removePersistentAttribute(...)` for storage.

- [ ] **Step 4: Migrate `TextView+Extensions.applySyntaxHighlighting`**

In `Sources/CodeEditorPlugin/Extensions/TextView+Extensions.swift` lines 109-133. The existing code already splits color attributes (rendering) from layout attributes (text storage). The layout-attribute branch needs to go through the bridge:

```swift
// Before (lines 122-132):
let layoutAttributes = attributes.filter { key, _ in
    key != .foregroundColor && key != .backgroundColor
}
if !layoutAttributes.isEmpty {
    #if canImport(AppKit)
    textStorage?.addAttributes(layoutAttributes, range: range)
    #else
    textStorage.addAttributes(layoutAttributes, range: range)
    #endif
}

// After:
let layoutAttributes = attributes.filter { key, _ in
    key != .foregroundColor && key != .backgroundColor
}
if !layoutAttributes.isEmpty, let codeEditorView = self as? CodeEditorView {
    codeEditorView.textKitBridge.addPersistentAttributes(layoutAttributes, range: range)
}
```

If `self` isn't a `CodeEditorView`, the existing fallback to `textStorage` was already a hack — drop it. The whole `applySyntaxHighlighting` extension was a shim from an earlier era; if no production code calls it after Task 7, consider deleting it entirely (verify with grep first).

- [ ] **Step 5: Build**

Run: `swift build`
Expected: green.

- [ ] **Step 6: Run folding + search tests**

Run: `swift test --parallel --filter Folding 2>&1 | tail -20`
Run: `swift test --parallel --filter SearchReplace 2>&1 | tail -20`
Run: `swift test --parallel --filter ConfigurationExtension 2>&1 | tail -20`
Expected: green.

- [ ] **Step 7: Run the full test suite**

Run: `swift test --parallel 2>&1 | tail -30`
Expected: all green except pre-existing `EditorStatusBarSnapshots` parallel SIGSEGV.

- [ ] **Step 8: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Migrate persistent-attribute writers to TextKitBridge.addPersistentAttributes

FoldingOperationsService (fold indicator marks), SearchReplaceEngine
(search-result highlighting), CodeEditorView+ConfigurationExtensions
(clear-highlighting), and TextView+Extensions.applySyntaxHighlighting
(layout-affecting attributes) now mutate text-storage attributes
through bridge.addPersistentAttributes / removePersistentAttribute.
The bridge routes via textContentStorage?.textStorage — TK2-safe — so
the persistent semantics survive without triggering the TK1
compatibility shim.

The clear-highlighting path uses bridge.removeAttributes (rendering),
matching where syntax highlighting now lives after the previous
commit.

Behavior-preserving.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Final sweep — doc comment update, replace ad-hoc bridge constructions, full verification

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (extend the named-commit invariant comment at lines 159-169)
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift:207, 211, 307, 426, 452` (replace `TextKitBridge(textView: self)` → `self.textKitBridge`)
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+PerformanceExtensions.swift:66`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift:141`
- Modify: `Sources/CodeEditorPlugin/Extensions/TextView+Extensions.swift:68, 93`
- Modify: `Sources/CodeEditorPlugin/Text/TextKitLineNumberHelper.swift:26` (already constructs a bridge; switch to using the lazy property if the textView is a `CodeEditorView`)
- Modify: `Sources/CodeEditorPlugin/Performance/ViewportManager.swift:56`

- [ ] **Step 1: Extend the load-bearing invariant comment**

In `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` lines 159-169 (the named-commit comment block), append a third paragraph:

```swift
// Note: We intentionally do **not** stand up a custom NSTextContentStorage/
// NSTextLayoutManager network here, nor override `textLayoutManager`.
// NSTextView constructs its own TextKit 2 network when initialized via
// `super.init(frame:)`, and key-input plumbing (NSTextInputContext →
// `insertText:replacementRange:` → `shouldChangeTextIn` delegate) only
// wires through that internally-owned network. A previous refactor
// (fc96866) replaced it with a hand-rolled network; the result was that
// `keyDown` still fired but `shouldChangeTextIn` never did, so the
// editor accepted clicks and selections but rejected typed input. If
// you ever need access to the live managers, read them via the standard
// accessors (`self.textLayoutManager`, `self.textContentStorage`).
//
// Critically, **do not read `self.textStorage` directly** anywhere in
// setup or steady-state code. Reading `NSTextView.textStorage` on a
// TK2-initialized view triggers Apple's TK1 compatibility shim and
// clears `textLayoutManager`. The framework funnels every text access
// through `self.textKitBridge`, which routes via
// `textContentStorage?.textStorage` (the TK2-safe accessor). The
// load-bearing invariant — `textLayoutManager != nil` after init — is
// covered by
// `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`.
// If that test fails, a new `self.textStorage` read has been
// re-introduced somewhere on the setup path.
```

- [ ] **Step 2: Replace ad-hoc `TextKitBridge(textView: self)` constructions**

For each site, replace `let textKitBridge = TextKitBridge(textView: self)` with `let textKitBridge = self.textKitBridge` — or, even better, drop the local binding and use `self.textKitBridge` inline.

```bash
grep -rn "TextKitBridge(textView: self)" Sources/CodeEditorPlugin --include='*.swift'
```

Expected: shows the sites in the file list above. Replace each.

Constructions where `textView` is NOT `self` (i.e., the bridge is built for a separate view reference, e.g., in `TextKitLineNumberHelper.swift:26`) cannot use `self.textKitBridge` — they pass an external view. For those:

```swift
// Before:
self.textKitBridge = TextKitBridge(textView: textView)

// After (if textView is a CodeEditorView):
self.textKitBridge = (textView as? CodeEditorView)?.textKitBridge ?? TextKitBridge(textView: textView)
```

Or just leave the `TextKitBridge(textView: textView)` construction in place — the per-view-lazy property only applies when `self === textView`. Document the choice with a comment.

- [ ] **Step 3: Verify no stray direct `textStorage` reads remain in production code**

Run:

```bash
grep -rn "textView\\.textStorage\\|self\\.textStorage\\|editorView\\.textStorage\\|codeEditorView\\.textStorage\\|codeEditorView?\\.textStorage" Sources/CodeEditorPlugin --include='*.swift' | grep -v "TextKitBridge.swift" | grep -v "TemporaryAttributesStore.swift"
```

Expected: zero results. (TextKitBridge.swift's `safeTextStorage` private property goes through `textContentStorage` and is fine; TemporaryAttributesStore.swift mutates a directly-owned NSTextStorage reference and is not a coercion source.)

If any results appear, migrate them and add a note.

- [ ] **Step 4: Build**

Run: `swift build`
Expected: green.

- [ ] **Step 5: Final lint pass**

```bash
swiftlint --fix
swiftlint
```

Expected: 0 violations.

- [ ] **Step 6: Final test pass**

Run: `swift test --parallel 2>&1 | tee /tmp/tk2-migration-test-output.txt | tail -50`
Expected: all green except pre-existing `EditorStatusBarSnapshots` parallel SIGSEGV (documented in REVIEW.md as not introduced by this work).

If new failures appear, diagnose and fix before committing.

- [ ] **Step 7: Run the canary tests one more time**

```bash
swift test --filter CodeEditorViewTextKit2InitTests
swift test --filter AnnotationTests.testAnnotationTextKit2Integration
swift test --filter SyntaxHighlightingRenderingAttributeTests
```

Expected: all green.

- [ ] **Step 8: Smoke test in `CodeEditorSample`**

```bash
swift run CodeEditorSample
```

Open a Swift file. Observe:
- Syntax highlighting renders correctly (function/keyword/string colors visible).
- Typing works (text appears as keys are pressed; `shouldChangeTextIn` fires).
- Folding works (click fold indicator; range collapses).
- Find (⌘F) works; results are highlighted yellow.
- Quit cleanly (⌘Q).

Document anything that visibly regressed. If the editor visibly works as before, this verifies the migration end-to-end at the UI level.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Finalize TextKit 2 migration: doc comment, ad-hoc bridge cleanup

Replace the remaining ten ad-hoc TextKitBridge(textView: self)
constructions with the shared self.textKitBridge lazy property.
Extend the named-commit invariant comment on CodeEditorView to warn
against direct self.textStorage reads and to cite the canary test.

After this commit, the framework's only direct readers of NSTextStorage
are TextKitBridge.safeTextStorage (the bridge's private TK2-safe
funnel) and TemporaryAttributesStore (owns its storage reference;
not a coercion source). Every other reader and writer routes through
TextKitBridge.

Build green, swiftlint --strict clean, swift test --parallel green
(pre-existing EditorStatusBarSnapshots parallel SIGSEGV remains, per
REVIEW.md, not introduced by this work). Sample app smoke-tested:
typing / highlighting / folding / find all behave normally and the
editor starts in TextKit 2.

Spec: docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md
Plan: docs/superpowers/plans/2026-05-14-textkit2-coercion-fix.md
Reference: REVIEW.md § "Latent TextKit 2 coercion"

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Post-implementation verification

After Task 9 commits, do one final pass:

- [ ] `git log --oneline -10` — confirm the nine commits are present and ordered correctly.
- [ ] `swift build && swiftlint --fix && swiftlint && swift test --parallel` — full quality pipeline green.
- [ ] Re-read `REVIEW.md` § "Latent TextKit 2 coercion" — confirm each of the four "What to do" bullets is addressed:
  1. `LineGeometryStore.build(from:)` source migrated ✓ (Task 4 — through `textContentStorage?.textStorage`)
  2. Audit every callsite that names `textStorage` / `layoutManager(...)` / `textContainer` ✓ (Tasks 5-8)
  3. Re-enable `testAnnotationTextKit2Integration` ✓ (Task 4)
  4. Add regression test that fails fast if `textLayoutManager == nil` ✓ (Task 4) and doc comment on `CodeEditorView` ✓ (Task 9)

If anything is missing, add a follow-up task and revise.

---

## Risks discovered during planning

Three risks from the spec, restated with mitigations baked into specific tasks:

1. **Rendering attributes don't survive every code path.** The highlighter's "did I already do this range?" cache may be tied to `NSTextStorage.didProcessEditingNotification`. After Task 4 drops the `object:` filter on that observer, the cache invalidation timing is unchanged. Task 7 verifies via the rendering-attribute test that highlighting still applies on the typical edit cycle.
2. **Minimap reads back `.foregroundColor`.** Task 7 Step 8 surfaces this explicitly. If minimap tests fail, the fix is part of Task 7.
3. **`NSTextContentStorageBreakOnEnumerateWhileEditing`.** Task 2's `replaceCharacters` doesn't open a transaction; existing transaction-wrapping callers (Task 6) continue to control batching at the call site.

## Out of scope (deferred)

- The 60+ `if textLayoutManager != nil { ... TK2 ... } else { ... TK1 ... }` branches inside `ModernTextKit2Bridge`, `RangeAttributeApplier`, etc. After this migration's soak period, those dead TK1 branches can be removed in a follow-up. They stay in this PR per the user's "Keep them, gated behind a guarded helper" decision.
- All other Important issues from REVIEW.md.
- The eight `CodeEditorSample`-driven API gaps.
- Tree-sitter integration.
