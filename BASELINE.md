# LineGeometryStore — Implementation Baseline

**Date**: 2026-05-10  
**Source**: `Tests/CodeEditorPluginTests/LineGeometryStoreBenchmarkTests.swift`  
**Tests**: 69 tests, 0 failures (1 skipped — 1M-line benchmark)  
**Reference**: `NSString.getLineStart(_:end:contentsEnd:for:)` — UTF-16 correct ground truth

## Implementation Summary (Phases 0–5)

| Phase | Status | Files | Tests |
|---|---|---|---|
| 0 — Benchmark baseline | Complete | `LineGeometryStoreBenchmarkTests.swift` | 31 |
| 1 — LineGeometryStore | Complete | `Text/LineGeometryStore.swift` (~490 lines) | 19 |
| 2 — Edit handler | Complete | `Text/LineGeometryEditHandler.swift` (60 lines) | 5 |
| 3 — Consumer migration | Complete | 5 files migrated from `lineIndexCache` | — |
| 4 — Re-scope auxiliary code | Complete | Deprecations, doc updates | — |
| 5 — View reuse + geometry helpers | Complete | `Utilities/ViewReuseQueue.swift`, `Text/LineGeometryStore+GeometryHelpers.swift` | 9 |
| **Total** | | **8 files created/modified** | **64** |

## Performance Comparison (arm64 macOS, single-run measure blocks)

### Build (initial load from text)

| Operation | Scale | NSString (flat array) | Sequential insert (before) | Balanced build (after) | Improvement |
|---|---|---|---|---|---|
| Build offsets/tree | 10k lines (~300 KB) | 2.5 ms | 243 ms | **9.0 ms** | 27× faster |
| Build offsets/tree | 100k lines (~400 KB) | 16.7 ms | 3,198 ms | **83.7 ms** | 38× faster |

The original sequential insertion was O(n log n) with worst-case constants (each insert traversed from root; sorted input caused right-skew before fixup rebalanced). The balanced build constructs the tree directly from the sorted array in O(n) using median-as-root recursion, then applies a single post-order coloring pass. The coloring pass exploits the balanced BST property that any node's subtrees differ in height by at most 1 — when children have equal black-height the node stays black; when they differ by 1 the deeper child is recolored red (reducing its bh by exactly 1).

### Lookup

| Operation | Scale | NSString | LineGeometryStore (before) | LineGeometryStore (after) |
|---|---|---|---|---|
| Offset→line index | 100 queries, 10k lines | 25 µs | 493 µs | **443 µs** |
| Y-position→line index | 100 queries, 50k lines | N/A | 618 µs | **530 µs** |

Lookup improved modestly because the balanced tree has better cache locality and shorter average path lengths than the sequentially-built tree.

### Key tradeoff

| Dimension | NSString / LineIndexCache | LineGeometryStore |
|---|---|---|
| Build speed | O(n), 16.7 ms (100k) | O(n), **83.7 ms** (100k) — was 3,198 ms |
| Offset→line lookup | O(log n), 25 µs | O(log n), **443 µs** |
| Y-position→line lookup | ✗ Not supported | O(log n), **530 µs** |
| Height tracking | ✗ Not supported | ✓ Per-line estimated + measured |
| Fold state | ✗ Not supported | ✓ Collapsed lines = height 0 |
| Incremental edits | Rebuilds entire cache | Rebuilds via handler (O(n) balanced build) |
| UTF-16 correctness | ✗ Character offsets (bug) | ✓ NSString-based |

## New Files

| File | Role |
|---|---|
| `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift` | Red-black tree with UTF-16 offsets, height tracking, y-position lookup, fold state |
| `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift` | `TextEditEventObserving` consumer, rebuilds store on edits |
| `Sources/CodeEditorPlugin/Text/LineGeometryStore+GeometryHelpers.swift` | Cursor/rect geometry helpers (`estimatedRect`, `visibleLineRange`, `lineIndex(at:)`) |
| `Sources/CodeEditorPlugin/Utilities/ViewReuseQueue.swift` | Generic view reuse pool for gutter/minimap scrolling optimizations |
| `Tests/CodeEditorPluginTests/LineGeometryStoreBenchmarkTests.swift` | 64 tests (reference + integration + edit handler + view reuse + geometry) |
| `BASELINE.md` | This file |

## Deprecated / Re-scoped

| Class | Action |
|---|---|
| `LineIndexCache` | `@available(*, deprecated)` — all consumers migrated |
| `OptimizedLineIndexCache` | `@available(*, deprecated)` — archived prior art |
| `TextKit2RenderingOptimizer` | Doc update — clarified as metrics scaffolding |
| `EditorStateBridge.deriveSelection(from:in:lineIndexCache:)` | Deprecated, new `lineGeometryStore` overload added |

## Consumer Migration (Phase 3)

| Consumer | Lines changed | Detail |
|---|---|---|
| `TextKitLineNumberHelper` | 3 sites | `visibleLineInfo` → `lineGeometries`, `lineNumber` → `lineIndex+1`, `lineCount` → store property |
| `EditorStateBridge` | New overload | `deriveSelection(from:in:lineGeometryStore:)` with column computation |
| `CodeEditorView` API | 3 methods | `lineNumber(at:)`, `lineRange(for:)`, `lineCount` → `lineGeometryStore` |
| Syntax highlighting ext | 27 lines removed | Removed `invalidate()` and `preWarmCache()` — handler replaces |
| Memory cleanup | 1 site | `lineIndexCache.invalidate()` → `lineGeometryStore.reset()` |

## LineGeometryStore API

```
// Build
build(from: NSTextStorage)

// Lookup (all O(log n))
lineIndex(forUtf16Offset:) -> Int
utf16Offset(forLineIndex:) -> Int
lineGeometry(at:) -> LineGeometry?
lineGeometry(atUtf16Offset:) -> LineGeometry?
lineIndex(forYPosition:) -> Int
yPosition(forLineIndex:) -> CGFloat

// Height / fold
updateMeasuredHeight(_:forLineAt:)
setEstimatedHeight(_:)
setFolded(_:forLineAt:)

// Iteration
lineGeometries(in: NSRange) -> [LineGeometry]
lineGeometries(inYRange: ClosedRange<CGFloat>) -> [LineGeometry]
allLineGeometries -> [LineGeometry]

// Geometry helpers (Phase 5)
estimatedRect(forLineAt:containerWidth:) -> CGRect
estimatedRects(inYRange:containerWidth:) -> [CGRect]
estimatedRects(in:containerWidth:) -> [CGRect]
lineIndex(at: CGPoint) -> Int
visibleLineRange(for:padding:) -> ClosedRange<Int>

// Admin
reset()
validateTree() -> Bool
```

## ViewReuseQueue API (Phase 5)

```
getOrCreateView(forKey:factory:) -> View
enqueueView(_:forKey:)
enqueueViews(notInSet:)
clearPool()
reset()
totalCreated, pooledCount, activeCount
```

## Test Coverage (64 tests)

- **31** reference tests (Phase 0): ASCII, emoji, line endings, NSRange round-trips, performance, fuzz
- **19** integration tests (Phase 1): store vs reference for all input categories, geometry access, height, fold, y-position
- **5** edit handler tests (Phase 2): rebuild, no-op, sequential, detach, registration
- **4** view reuse tests (Phase 5): get/create, different keys, enqueue-not-in-set, reset
- **5** geometry helper tests (Phase 5): estimated rect, y-range rects, visible line range, padding, point-to-line

## Remaining Work (Phase 5 deferred)

- Incremental tree updates (O(m log n) split/merge/insert/delete) to replace rebuild-on-edit
- Multi-cursor selection model
- Column selection support
- Gutter view reuse integration (wiring `ViewReuseQueue` into `GutterView`)
- Layout invalidation pattern adoption for gutter/minimap
