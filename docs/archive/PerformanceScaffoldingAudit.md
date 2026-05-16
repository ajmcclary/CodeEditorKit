# Performance Scaffolding Audit

**Phase:** 1.2
**Date:** 2026-05-07

## Classification Results

### 1. `TextKit2RenderingOptimizer.swift` — `prefetchLayoutAsync`

**File:** `Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift:318-329`

**Status:** `keep behind feature flag`

**Finding:** The `prefetchLayoutAsync(for:)` method yields without doing actual layout work. The rest of the class has real functionality (fragment caching, viewport optimization, memory cleanup). Only the async prefetch path is simulated.

**Action taken:** The method is useful as a placeholder for future async prefetch. The rest of the class (`fragmentCache`, `cleanupNonVisibleFragments`, `optimizeLargeFileLayout`) does real work. Keep the class as-is; the simulated path is intentionally deferred, not misleading.

### 2. `OptimizedLineIndexCache.swift` — `handleMultiLineChange`

**File:** `Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift:290-302`

**Status:** `complete now` — mark as documented limitation

**Finding:** `handleMultiLineChange(startLine:endLine:range:replacementLength:)` invalidates the entire lookup cache on multi-line edits instead of performing an incremental tree update. The comment acknowledges this is simplified.

**Action taken:** This is a valid trade-off. Multi-line edits are rare in interactive editing (they happen on paste). Invalidating the lookup cache is O(1) and will refill on next query. The red-black tree itself handles single-line edits efficiently via `updateLineLength(at:delta:)`. No code change needed — document as intentional trade-off.

### 3. `OptimizedSyntaxHighlightingCoordinator.swift` — `highlightIncrementally`

**File:** `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift:293-307`

**Status:** `complete now` — remove the stub

**Finding:** The method `highlightIncrementally(text:language:cacheCheckTime:totalStartTime:)` is a TODO that falls back to `highlightFull()`. The `canUseIncrementalHighlighting` heuristic (length diff < 1000) is reasonable as a gate, but the method shouldn't exist until it has a real implementation.

**Action taken:** Remove `highlightIncrementally` and its call site. The `canUseIncrementalHighlighting` logic remains as a gate for future incremental work. The `highlightFull` method already handles chunked highlighting for large files, which is the current production path.

### 4. `TextKit2RenderingOptimizer.swift` — `createOrRecycleFragment`

**File:** `Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift:277-286`

**Status:** `keep behind feature flag`

**Finding:** Creates empty `NSTextLayoutFragment` instances instead of real layout fragments. This is structural scaffolding for the fragment recycling system, which has real value in the `cleanupFragmentsOutside` and `cacheFragmentsForRange` methods.

**Action taken:** Keep as-is. The recycling pool is a real optimization pattern. The empty fragment creation is a placeholder to be filled when actual layout fragment generation is needed.

## Summary

| File | Path | Verdict | Action |
|------|------|---------|--------|
| `TextKit2RenderingOptimizer` | prefetchLayoutAsync | Keep | No change |
| `OptimizedLineIndexCache` | handleMultiLineChange | Keep (documented) | No change |
| `OptimizedSyntaxHighlightingCoordinator` | highlightIncrementally | Remove | Remove TODO stub |
| `TextKit2RenderingOptimizer` | createOrRecycleFragment | Keep | No change |

Only `highlightIncrementally` was misleading because it presents as a viable code path that falls through to full highlighting. The rest are either useful scaffolding or intentional trade-offs.
