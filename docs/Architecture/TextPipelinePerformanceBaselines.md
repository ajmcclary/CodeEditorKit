# Text Pipeline Performance Baselines and Decisions

**Consolidates:** root notes `PHASE0_AUDIT.md`, `BASELINE.md`, and `PHASE8_EVALUATION.md`  
**Source dates:** 2026-05-10 through 2026-05-11  
**Status:** Historical benchmark baseline plus current implementation notes

This page records the editing, line-geometry, highlighting, Tree-sitter, and
rendering decisions that came out of the phase audits. Benchmark numbers are
single-run arm64 macOS baselines from the original notes; use the current
source and tests as implementation truth.

## Decision Summary

| Area | Decision | Current state |
|---|---|---|
| Edit events | Keep a two-phase edit model: `WillEditEvent` before mutation and `TextEditEvent` after mutation. | Implemented in `TextEditEventHub`. |
| Range providers | Keep the existing `RangeHighlightProviding` surface. | Adequate for range-query providers, LSP semantic tokens, spell-check, and AI suggestions. |
| Attribute edits | Gate legacy syntax highlighting to character edits only. | Implemented to avoid attribute-only highlight loops and double-apply work. |
| Line geometry | Use `LineGeometryStore` as the UTF-16-correct line and y-position index. | Implemented; `LineIndexCache` and `OptimizedLineIndexCache` are deprecated prior art. |
| Tree-sitter | Keep range-query highlighting behind a feature flag; defer real C grammar packaging. | Architecture is present; current parser backend is still regex-backed with bounded invalidation. |
| Renderer | Do not build a full custom text renderer. | TextKit2 remains the sole text rendering path. |

## Foundation Audit

### Gate Results

The phase-0 snapshot recorded this baseline:

| Gate | Result |
|---|---|
| `swift build` | Passed in 3.99s |
| `swiftlint --fix` | 638 files corrected |
| `swiftlint` strict mode | 0 violations across 638 files |
| `swift test --parallel` | Still running when the source note was captured |

These results are historical. Re-run the normal package gates for current
verification.

### Two-Phase Edit Events

`TextEditEventHub` owns two observer sets so consumers can subscribe to the
phase they need:

```swift
internal struct WillEditEvent: Sendable {
    internal var preEditRange: NSRange
    internal var replacementText: String
    internal var preEditLineRange: ClosedRange<Int>
    internal var preEditSource: String?
}

internal struct TextEditEvent: Sendable, Equatable {
    internal var editedRange: NSRange
    internal var changeInLength: Int
    internal var documentLength: Int
    internal var editedCharacters: Bool
}
```

`WillEditEvent` is published after edit validation succeeds and before
`NSTextStorage` applies the mutation. It captures state destroyed by the edit:
deleted text, replacement text, and pre-edit line bounds. LSP incremental sync
and Tree-sitter byte-range translation use this phase.

`TextEditEvent` remains the canonical post-edit event. It carries the replaced
range in pre-edit UTF-16 coordinates, length delta, post-edit document length,
and an `editedCharacters` flag so observers can skip attribute-only changes.

### RangeHighlightProviding Audit

The existing provider protocol was kept:

```swift
func setUp(textView: CodeEditorView, language: Language)
func willApplyEdit(textView: CodeEditorView, range: NSRange)
func willApplyEdit(textView: CodeEditorView, source: String, range: NSRange)
func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet
func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
```

No new protocol requirements were needed. The source-aware `willApplyEdit`
overload supports byte-range translation, `applyEdit` returns invalidation sets,
and `queryHighlights` supports both syntax and semantic-token style providers.

### Language Descriptor Audit

All concrete languages have `parserName` values where appropriate.

| Language | `parserName` | Note |
|---|---|---|
| Swift | `nil` | Uses SwiftSyntax, not Tree-sitter. |
| Shell | `bash` | Matches the canonical `tree-sitter-bash` grammar. |
| C# | `c_sharp` | Matches the canonical underscore spelling. |
| Plain text | `nil` | No highlighting. |
| Other concrete languages | Matching grammar names | No correction needed in the audit. |

The current package language catalog is 25 concrete languages plus plain text.

### Attribute-Edit Loop Prevention

The audit found that attribute-only writes from a future range applier would
re-enter the legacy syntax-highlighting path unless that path was gated. The
current implementation gates legacy highlighting on `.editedCharacters`:

```swift
if editedMask.contains(.editedCharacters),
   configuration.display.isSyntaxHighlightingEnabled {
    let editedRange = textStorage.editedRange
    if editedRange.location != NSNotFound {
        applySyntaxHighlighting(in: editedRange)
    }
}
```

`RangeAttributeApplier` adds defense in depth by batching writes with
`beginEditing()` / `endEditing()` and skipping already-correct attributes.
Attribute-only edit events are ignored by the applier and by line-geometry
maintenance.

## LineGeometryStore Baseline

### Implementation Summary

`LineGeometryStore` replaced the legacy line-index caches with a red-black tree
that tracks UTF-16 offsets, estimated and measured heights, y-positions, and
fold state.

| Phase | Status | Deliverable |
|---|---|---|
| 0 | Complete | Benchmark and correctness baseline. |
| 1 | Complete | `LineGeometryStore`. |
| 2 | Complete | `LineGeometryEditHandler`. |
| 3 | Complete | Consumer migration from `lineIndexCache`. |
| 4 | Complete | Deprecations and documentation updates. |
| 5 | Complete | View reuse and geometry helper APIs. |

Current key files:

| File | Role |
|---|---|
| `Sources/CodeEditorTextModel/Text/LineGeometryStore.swift` | Red-black tree with UTF-16 offsets, height tracking, y-position lookup, and fold state. |
| `Sources/CodeEditorView/Text/LineGeometryEditHandler.swift` | Keeps the store synchronized after character edits. |
| `Sources/CodeEditorTextModel/Text/LineGeometryStore+GeometryHelpers.swift` | Cursor, rect, visible range, and point-to-line helpers. |
| `Sources/CodeEditorPlatform/ViewReuseQueue.swift` | Generic view reuse pool for gutter and minimap optimizations. |
| `Tests/CodeEditorPluginTests/LineGeometryStoreBenchmarkTests.swift` | Reference, integration, performance, edit-handler, reuse, and geometry coverage. |

### Build Baseline

| Operation | Scale | NSString flat array | Sequential insert before | Balanced build after | Improvement |
|---|---:|---:|---:|---:|---:|
| Build offsets/tree | 10k lines, about 300 KB | 2.5 ms | 243 ms | 9.0 ms | 27x faster |
| Build offsets/tree | 100k lines, about 400 KB | 16.7 ms | 3,198 ms | 83.7 ms | 38x faster |

The optimized build constructs the tree directly from sorted line geometry in
O(n), using median-as-root recursion and a post-order coloring pass.

### Lookup Baseline

| Operation | Scale | NSString | Store before balanced build | Store after balanced build |
|---|---:|---:|---:|---:|
| Offset to line index | 100 queries, 10k lines | 25 us | 493 us | 443 us |
| Y-position to line index | 100 queries, 50k lines | N/A | 618 us | 530 us |

Lookup improved modestly because the balanced tree has shorter average paths and
better locality. The store is still slower than `NSString` for offset-only line
lookup, but it adds y-position, height, and fold-state capabilities the flat
array cache did not support.

### Trade-Offs

| Dimension | NSString / `LineIndexCache` | `LineGeometryStore` |
|---|---|---|
| Initial build speed | O(n), 16.7 ms at 100k lines | O(n), 83.7 ms at 100k lines after optimization |
| Offset to line lookup | O(log n), 25 us in the snapshot | O(log n), 443 us in the snapshot |
| Y-position lookup | Not supported | O(log n), 530 us in the snapshot |
| Height tracking | Not supported | Per-line estimated and measured heights |
| Fold state | Not supported | Collapsed lines have height 0 |
| Incremental edits | Rebuild-oriented cache behavior | Maintained by `LineGeometryEditHandler` |
| UTF-16 correctness | Character-offset bugs around emoji and surrogate pairs | Uses `NSString` line boundaries |

### Public Surface Used Internally

The store provides:

- Build/admin: `build(from:)`, `reset()`, `validateTree()`.
- Line lookup: `lineIndex(forUtf16Offset:)`, `utf16Offset(forLineIndex:)`, `lineGeometry(at:)`.
- Y lookup: `lineIndex(forYPosition:)`, `yPosition(forLineIndex:)`.
- Height/fold: `updateMeasuredHeight(_:forLineAt:)`, `setEstimatedHeight(_:)`, `setFolded(_:forLineAt:)`.
- Iteration: `lineGeometries(in:)`, `lineGeometries(inYRange:)`, `allLineGeometries`.
- Geometry helpers: `estimatedRect(forLineAt:containerWidth:)`, `visibleLineRange(for:padding:)`, `lineIndex(at:)`.

The original baseline recorded 64 focused tests across reference behavior,
store integration, edit handling, view reuse, and geometry helpers.

## Tree-Sitter Highlighting Baseline

### Implementation Summary

The phase baseline established the range-query range-provider path while
keeping regex highlighting as the backend.

| Phase | Deliverable |
|---|---|
| 1 | Fixed regex highlighter language selection; range controller uses canonical language definitions. |
| 2 | Consolidated `LanguageDescriptor` as the language metadata source of truth. |
| 3 | Added structural shebang parsing with `/usr/bin/env -S` support and Vim/Emacs modelines. |
| 4 | Added TOML, Lua, C#, Kotlin, and Dart to reach 25 concrete languages plus plain text. |
| 5 | Added `RegexRangeHighlightProvider`, capture maps, and the regex-backed parser spike. |

Current architecture:

```text
EditorConfiguration.performance.usesRangeBasedHighlighting
  -> CodeEditorView.updateRangeBasedHighlightingConfiguration()
       -> RangeBasedHighlightingController
            -> SyntaxHighlighterRangeAdapter
                 -> RegexSyntaxHighlighter backend
            -> StyledRangeContainer
            -> RangeAttributeApplier

RegexRangeHighlightProvider remains internal scaffolding until a real
companion package provides C grammar loading.
```

The current `RegexIncrementalRangeQueryParser` keeps actor-isolated parser state, translates
UTF-16 ranges to UTF-8 byte ranges, and uses bounded invalidation around edits.
It does not link real C grammar libraries yet.

### Phase-5 Benchmark Snapshot

JavaScript highlighting through the regex-backed range-query pipeline:

| Scale | Parse time | Query time | Captures | Baseline result |
|---|---:|---:|---:|---|
| 5k lines | 7.2 ms | 2.1 ms | about 12,000 | 1.3x slower than direct regex due to capture conversion. |
| 10k lines | 14.5 ms | 4.3 ms | about 24,000 | Under 500 ms target. |
| 100k lines | 1.18 s | 0.04 s | about 240,000 | Under 5 s target. |

### Remaining Tree-Sitter Work

- Replace the regex backend with real C Tree-sitter parser/query integration.
- Extract grammar binaries and query resources into the optional
  `CodeEditorTreeSitterLanguages` companion package.
- Keep the core editor lean; the feature flag remains a no-op when the optional
  grammar package is not present.
- Expand and tune capture maps, injections, folding, and symbol extraction with
  real grammar data.

## Custom Renderer Evaluation

### Current Rendering Stack

TextKit2 remains the rendering path:

```text
NSTextStorage
  -> NSTextContentStorage
    -> NSTextLayoutManager
      -> NSTextLayoutFragment
        -> NSTextView.draw() / NSTextLayoutManager.drawGlyphs()
```

Existing optimization points include:

| Component | Role |
|---|---|
| `LineGeometryStore` | O(log n) line-to-offset and y-position lookup. |
| `LineGeometryEditHandler` | Keeps line geometry synchronized after edits. |
| `RangeAttributeApplier` | Skip-equal attribute writes and batched attribute transactions. |
| `HighlightProviderState` | Chunked asynchronous highlighting. |
| `RangeBasedHighlightingController` | Primary range-based styling path. |
| `TextKit2RenderingOptimizer` | Large-file and fragment-cache optimization scaffolding. |
| `ViewportManager` | Visible and prefetch range caching. |
| `AdaptivePerformanceMode` | File-size-based performance tier switching. |
| `TextLayoutFragmentView` | Per-fragment custom drawing escape hatch. |
| `IOSLargeFileOptimizer` | iOS-specific chunk sizing and feature reduction. |

### Bottleneck Assessment

The phase-8 evaluation found the meaningful costs in application code rather
than TextKit2:

1. Syntax highlighting: regex parsing and capture conversion on large files.
2. Attribute application: foreground-color runs applied to `NSTextStorage`.
3. Line geometry: formerly rebuild-oriented, now isolated in `LineGeometryStore`
   and the edit handler.
4. Edit notifications: multiple consumers reacting to each edit, now routed
   through `TextEditEventHub`.

TextKit2 already provides glyph caching, hardware-accelerated drawing, viewport
layout, Unicode text layout, bidirectional text handling, input method support,
emoji rendering, and accessibility integration.

### Decision

Do not build a full custom renderer.

The evaluated bottlenecks were not in TextKit2 layout or glyph rendering, and a
custom renderer would need to recreate Unicode line breaking, shaping,
bidirectional text, hit-testing, selection navigation, accessibility, IME
marked-text handling, emoji, and platform color behavior. The projected cost was
multi-month engineering plus permanent OS-release maintenance.

Use incremental TextKit2 optimizations first. Reasonable follow-on work:

- Fragment reuse or pre-warming when Instruments shows fragment allocation cost.
- Attribute diffing before writes instead of clear-and-reapply behavior.
- Scroll-velocity prediction for pre-layout.
- `CATransaction` batching around related attribute changes.
- Targeted custom drawing through `TextLayoutFragmentView` for specific surfaces
  such as minimaps or diff gutters.

Revisit the no-go only if Instruments shows TextKit2 layout/rendering consuming
more than 50 percent of frame time on real-world files, a concrete TextKit2
limit blocks a critical use case, or Apple changes the platform text stack in a
way that invalidates the current architecture.
