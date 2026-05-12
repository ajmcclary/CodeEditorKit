# Phase 8: Custom Renderer Evaluation — Decision Document

**Date**: 2026-05-11  
**Status**: Evaluation complete — custom renderer **NOT justified**  
**Phases completed prior**: 0, 1, 2A, 2B, 3, 4, 5, 6, 7

---

## 1. Current Rendering Architecture

### TextKit2 Stack (sole rendering path since 0.2.0)

```
NSTextStorage (text model, UTF-16)
  → NSTextContentStorage (TextKit2 content bridge)
    → NSTextLayoutManager (line-breaking, glyph layout, fragment generation)
      → NSTextLayoutFragment (per-line fragment with geometry)
        → NSTextView.draw() / NSTextLayoutManager.drawGlyphs() (hardware rendering)
```

### Existing Optimizations

| Component | Role | Phase |
|-----------|------|-------|
| `LineGeometryStore` | O(log n) line→offset, y-position (red-black tree) | Phase 1 |
| `LineGeometryEditHandler` | Incremental O(m log n) updates on edits | Phase 1 |
| `RangeAttributeApplier` | Skip-equal attribute writes, beginEditing/endEditing batching | Phase 2A |
| `HighlightProviderState` | 4096-char chunked async highlighting | Existing |
| `RangeBasedHighlightingController` | Primary text-styling path (replaces legacy highlighter) | Phase 2B |
| `TextKit2RenderingOptimizer` | Monitors large files, adjusts rendering strategy | Existing |
| `ViewportManager` | Viewport-cached visible/prefetch ranges | Existing |
| `AdaptivePerformanceMode` | File-size-based performance tier switching | Existing |
| `TextLayoutFragmentView` | Reusable fragment view for custom drawing (available if needed) | Existing |
| `IOSLargeFileOptimizer` | iOS-specific chunked processing | Existing |

### Performance Metrics Infrastructure

- `PerformanceMonitor` — per-operation timing (layout, rendering, scrolling)
- `UnifiedPerformanceSystem` — metric collection + recommendations
- `ProductionPerformanceMetrics` — `HighlightingMetric`, `ScrollingMetric`, `MemoryMetric`
- `PerformanceBudget` — per-operation budget enforcement
- `PerformanceInsights` — real-time dashboard panel (SwiftUI)

---

## 2. Bottleneck Analysis

### Where bottlenecks actually are (from codebase inspection)

**Not in TextKit2:**

1. **Syntax highlighting** — Regex-based highlighting on large files is O(n) per full parse. Mitigated by:
   - 4096-char chunked queries (`HighlightProviderState`)
   - Async background highlighting (`BackgroundSyntaxHighlighter`)
   - Adaptive performance mode disables highlighting above threshold
   - Phase 3 bounded invalidation reduces re-parse scope

2. **Attribute application** — Applying `.foregroundColor` to `NSTextStorage` is O(runs) per edit region. Optimized by:
   - Skip-equal optimization in `RangeAttributeApplier`
   - `beginEditing`/`endEditing` batching suppresses intermediate notifications

3. **Line geometry updates** — Was O(n) full rebuild per edit. Now O(m log n) incremental (Phase 1).

4. **Document change notification overhead** — Multiple observers processing each edit. Minimized by:
   - `TextEditEventHub` single-publish pattern
   - Attribute-edit gate in legacy handler

### What TextKit2 does well

- **Glyph caching** — rendered glyphs cached at the fragment level; scrolling reuses cached fragments
- **Hardware acceleration** — Core Text + Metal rendering on Apple GPUs
- **Viewport optimization** — `NSTextLayoutManager` only lays out visible + prefetch fragments
- **Text encoding correctness** — built-in UTF-16/UTF-8 handling, surrogate pairs, composed characters

### What a custom renderer would need to replicate

| Feature | TextKit2 provides | Custom would need |
|---------|-------------------|-------------------|
| Unicode text layout | Core Text + `NSTextLayoutManager` | Custom shaping engine (HarfBuzz/CoreText bindings) |
| Glyph rendering | GPU-accelerated via Core Animation | Custom Metal/OpenGL shader pipeline |
| Line breaking | Unicode UAX #14 compliant | Reimplement algorithm |
| Bidirectional text | Full bidi support | Reimplement UAX #9 |
| Text selection | `NSTextSelectionNavigation` | Custom hit-testing + caret rendering |
| Accessibility | VoiceOver integration | Reimplement accessibility tree |
| Input methods | CJK IME, dictation | Custom marked-text handling |
| Emoji | Apple Color Emoji font rendering | Custom emoji rendering |
| Dark Mode | Automatic color adaptation | Custom color scheme management |

---

## 3. Decision

### Custom renderer is NOT justified.

**Reasoning:**

1. **Bottlenecks are in application code, not TextKit2.** The profiling infrastructure identifies highlighting (regex parsing, attribute application) and line geometry (now incremental) as the top costs. TextKit2 layout and rendering are not among the top 3 bottlenecks.

2. **TextKit2 is already optimized for the target use case.** Apple's `NSTextLayoutManager` uses viewport-cached fragment generation and GPU-accelerated glyph rendering. A custom renderer would compete with an Apple-maintained, hardware-optimized stack.

3. **The cost of a custom renderer is extreme.** Replicating Unicode text layout, bidi, CJK input methods, accessibility, and emoji rendering would require 6-12 months of dedicated engineering and would introduce a permanent maintenance burden for every macOS/iOS release.

4. **Existing optimization levers are not exhausted.** The codebase has multiple performance tiers (adaptive mode, large-file thresholds, chunked highlighting) that can be tuned before considering a custom renderer. If profiling reveals a specific TextKit2 bottleneck (e.g., `NSTextLayoutFragment` allocation pressure), a targeted optimization (fragment reuse pool, pre-warming) is cheaper than a full replacement.

5. **The `TextLayoutFragmentView` abstraction exists** as an escape hatch. If a specific rendering scenario (e.g., minimap, diff gutter) benefits from custom drawing, `TextLayoutFragmentView` provides per-fragment override points without replacing the entire stack.

---

## 4. Recommended Follow-On Actions

If profiling under Instruments reveals actionable bottlenecks:

1. **Fragment reuse pool** — Pre-allocate `NSTextLayoutFragment` instances for the visible viewport + 1 screen of scroll buffer
2. **Glyph cache warming** — Pre-render frequently-visible glyphs (keywords, common identifiers) on background threads
3. **Attribute diffing** — Instead of clearing and re-applying attributes on each edit, diff the new `mergedRuns` against current attributes and only apply changes
4. **Scroll prediction** — Use scroll velocity to pre-layout fragments in the scroll direction before they're needed
5. **`CATransaction` batching** — Group multiple attribute changes into a single `CATransaction` to reduce Core Animation overhead

These are incremental improvements to the existing TextKit2 stack — each is a 1-2 day effort rather than the multi-month custom renderer.

---

## 5. Conclusion

**Phase 8 result: Do not proceed with custom renderer.** The TextKit2 pipeline is performant, well-optimized, and integrated with platform accessibility and input systems. The 7 completed phases have addressed the known bottlenecks at the application level (incremental line geometry, async chunked highlighting, skip-equal attribute application, bounded tree-sitter invalidation). Any remaining performance concerns should be addressed through targeted profiling and incremental optimization of the existing stack.

This decision should be revisited only if:
- Instruments profiling shows TextKit2 layout/rendering consuming >50% of frame time on real-world files
- A specific TextKit2 limitation (e.g., maximum document size) blocks a critical use case
- Apple deprecates TextKit2 in a future OS release (unlikely given its central role)
