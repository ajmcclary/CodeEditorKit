# CodeEditorPlugin ↔ CodeEditTextView — Cross-Repo Analysis

**Date**: 2026-05-10  
**Analyst**: DeepSeek (audit across both repositories)  
**Scope**: `CodeEditorPlugin` (this repo) vs `CodeEditTextView/Sources/CodeEditTextView` (external reference)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Repository Profiles](#2-repository-profiles)
3. [Architectural Comparison](#3-architectural-comparison)
4. [Strengths of Each Repository](#4-strengths-of-each-repository)
5. [Gap Analysis — What We're Missing](#5-gap-analysis--what-were-missing)
6. [What to Borrow and Why](#6-what-to-borrow-and-why)
7. [What Not to Borrow](#7-what-not-to-borrow)
8. [Detailed File-by-File Analysis](#8-detailed-file-by-file-analysis)
9. [Test Coverage Comparison](#9-test-coverage-comparison)
10. [Risk Assessment](#10-risk-assessment)
11. [Implementation Strategy](#11-implementation-strategy)

---

## 1. Executive Summary

**CodeEditorPlugin** is a cross-platform, feature-rich code editor framework built on TextKit2 with SwiftUI integration,
18-language syntax highlighting, LSP support, theming, code folding, and a comprehensive configuration system. It
inherits from `NSTextView`/`UITextView` and delegates text rendering to Apple's TextKit2 stack.

**CodeEditTextView** is a macOS-only, custom-rendered text surface that forgoes `NSTextView` entirely. It builds its
own red-black tree line storage, CoreText typesetting pipeline, visible-line-only rendering with view reuse, and a
full custom text input system.

The primary lesson is **not** to replace TextKit2 with a custom rendering stack. The high-value move is to adopt
CodeEditTextView's **incremental line geometry model** — a production-grade data structure for line lengths, heights,
and y-positions — while keeping TextKit2 for text rendering, input handling, and platform behavior. This would unlock
high-performance gutter rendering, minimap generation, fold geometry, scroll-position preservation, and viewport
prediction across all our features.

---

## 2. Repository Profiles

### 2.1 CodeEditorPlugin (This Repo)

| Attribute | Value |
|---|---|
| Platform | iOS, macOS, Mac Catalyst (via `#if canImport`) |
| Text Engine | TextKit2 (exclusively since 0.2.0) |
| Base Class | `PlatformTextView` (extending `NSTextView`/`UITextView`) |
| Source Files | ~438 Swift files across 18 directories |
| Languages | 18 (Swift, Python, JS, TS, Java, Go, Rust, C, PHP, Ruby, JSON, YAML, XML, Markdown, CSS, HTML, SQL, Shell) |
| Key Features | Syntax highlighting, code completion, LSP, theming, code folding, annotations, gutter, minimap, SwiftUI wrappers, adaptive performance, memory monitoring, event publishing |
| Test Targets | 3 (`CodeEditorPluginTests`, `CodeEditorDesignTokensTests`, `CodeEditorUITests`) |
| Concurrency | `StrictConcurrency` enabled, Swift 6.3 |
| Dependencies | swift-syntax, swift-dependencies, xctest-dynamic-overlay, swift-snapshot-testing |

### 2.2 CodeEditTextView (External Reference)

| Attribute | Value |
|---|---|
| Platform | macOS only (AppKit) |
| Text Engine | Custom — CoreText + explicit line storage + view reuse |
| Base Class | `NSView` (not `NSTextView`) |
| Source Files | ~60 Swift files across 11 directories + 1 ObjC target |
| Key Features | Red-black tree line storage, CoreText typesetting, visible-line-only rendering, multi-cursor selection, marked text, column selection, undo/redo, view reuse queue, cursor blinking |
| Test Targets | 1 (`CodeEditTextViewTests`) — ~10 test files |
| Dependencies | TextStory |

### 2.3 Relationship

These are sibling projects within the larger CodeEdit ecosystem. CodeEditTextView was built first as the rendering
engine for the CodeEdit IDE. CodeEditorPlugin is a later, broader framework that chose TextKit2 for cross-platform
reach and reduced maintenance burden. They share no direct code dependencies — they are alternative approaches to
the same problem space.

---

## 3. Architectural Comparison

### 3.1 Rendering Pipeline

**CodeEditTextView** — Custom rendering pipeline:

```
NSTextStorage (text source)
    → TextLayoutManager (layout coordinator)
        → TextLineStorage (red-black tree of line metadata)
            → TextLine (per-line typesetting)
                → Typesetter (CoreText line-breaking)
                → LineFragment (visual fragments)
        → LineFragmentView (NSView per fragment, reused)
            → LineFragmentRenderer (CGContext drawing)
    → TextSelectionManager (selection, cursors)
    → MarkedTextManager (IME composition)
```

**CodeEditorPlugin** — TextKit2 pipeline:

```
NSTextStorage (text source)
    → NSTextLayoutManager (TextKit2 layout engine)
        → NSTextViewportLayoutController (viewport management)
        → NSTextLayoutFragment (system-managed fragments)
    → SyntaxHighlightingCoordinator (highlighter)
    → GutterView (custom line number rendering)
    → LineIndexCache (simple offset array cache)
    → TextEditEventHub (edit broadcast)
```

**Key difference**: CodeEditTextView owns every step of layout. CodeEditorPlugin delegates layout to TextKit2 and
adds language intelligence on top.

### 3.2 Line Geometry Model

This is the single most important architectural difference.

**CodeEditTextView — `TextLineStorage`**: A red-black tree where each node carries:
- UTF-16 character length of the line
- Height in points
- Cumulative subtree offset, height, and node count (for O(log n) lookup by offset, index, or y-position)
- Built via balanced tree construction (`build(from:)`) for O(n) initial load
- Incremental updates via `insert(line:atOffset:length:height:)`, `update(atOffset:delta:deltaHeight:)`, `delete(lineAt:)`
- Lazy iterators for y-range and text-range queries
- Uses `Unmanaged` references internally to reduce retain/release overhead (~15% measured improvement)

**CodeEditorPlugin — `LineIndexCache`**: A flat array of character offsets to newline positions.
- Rebuilds the entire array on any text change (cache invalidation)
- O(n) rebuild, O(log n) binary search lookup
- Does **not** track line heights
- Does **not** support y-position → line lookup
- Does **not** support incremental update
- No height-aware iteration
- Intended for simple line number → character offset mapping

**CodeEditorPlugin — `OptimizedLineIndexCache`**: Referenced in NOTES.md but **does not exist on disk**.
The file path `Sources/CodeEditorPlugin/Text/OptimizedLineIndexCache.swift` is absent — it may have been planned
but never created, or was removed.

### 3.3 Edit Handling

**CodeEditTextView**: `TextLayoutManager+Edits.swift` consumes `NSTextStorageDelegate` notifications and performs
incremental line storage updates:
1. `removeLayoutLinesIn(range:)` — walks lines in reverse, splits/merges/deletes as needed
2. `insertNewLines(for:)` — parses inserted text for newlines, inserts new line records
3. Updates are O(m log n) where m = affected lines, n = total lines
4. Edits never rebuild the entire line index

**CodeEditorPlugin**: `TextEditEventHub` broadcasts canonical edit events, but `LineIndexCache` discards and
rebuilds the entire cache on any change. The `TextEditEventHub` is a well-designed observer pattern, but there
is no consumer that performs incremental line geometry updates — the cache just invalidates.

### 3.4 Viewport / Rendering Strategy

**CodeEditTextView**:
- `layoutLines(in:)` lazily iterates visible lines (plus vertical padding)
- Checks three signals to avoid re-layout: needs layout flag, was-previously-visible, fully-laid-out
- `ViewReuseQueue<View, Key>` manages a pool of `LineFragmentView`s
- Views are moved (not recreated) when line heights change
- `CATransaction` wraps all view mutations to prevent re-entrant layout
- Only visible line fragment views exist in the view hierarchy

**CodeEditorPlugin**:
- `TextKit2RenderingOptimizer` tracks visible range, caches fragments, and prefetches
- But it's more instrumentation than concrete rendering control — fragments are `NSTextParagraph`-based
- No view reuse queue — TextKit2 owns view management
- `performanceReport()` method suggests monitoring intent, not yet production-hardened

### 3.5 Selection Model

**CodeEditTextView — `TextSelectionManager`**:
- Supports multiple simultaneous selections (`[TextSelection]`)
- Range merging on add, duplicate elimination
- Cursor views with blink timer
- System cursor support (macOS 14+)
- `rectForOffset`, `rectsFor(range:)`, `roundedPathForRange` for selection geometry
- Vertical movement state tracking (`suggestedXPos`)
- Column selection mode

**CodeEditorPlugin**:
- Relies on `NSTextView.selectedRanges` (platform selection)
- No multi-cursor abstraction
- Cursor rendering is implicit via TextKit2
- No column selection support
- No custom selection geometry

### 3.6 Platform Strategy

**CodeEditTextView**: macOS-only. Uses AppKit directly, CoreText for typesetting, `CGContext` for drawing,
`CATransaction` for view updates, `NSTextInputClient` for IME. An ObjC target (`CodeEditTextViewObjC`) provides
the font-smoothing shim via `ContextSetHiddenSmoothingStyle`.

**CodeEditorPlugin**: Cross-platform via `#if canImport(AppKit)` etc. TextKit2 abstracts platform differences.
No ObjC dependencies. No platform-specific drawing hacks.

---

## 4. Strengths of Each Repository

### 4.1 CodeEditorPlugin Strengths

| Area | Detail |
|---|---|
| **Language Intelligence** | 18-language syntax highlighting, LSP integration, completion providers, SwiftSyntax parsing |
| **Theming** | Comprehensive theme system with design tokens, color tokens, appearance management |
| **Configuration** | `EditorConfiguration` with presets, validation, batch mutation, display/behavior/layout sub-configs |
| **SwiftUI** | First-class SwiftUI wrappers (`CodeEditor`), modifiers, bindings, environment integration |
| **Cross-Platform** | Runs on iOS, macOS, Catalyst from a single codebase |
| **Performance Monitoring** | `MemoryMonitor`, `TextKit2PerformanceMonitor`, `AdaptivePerformanceMode`, cleanup handlers |
| **Event System** | `EditorEventPublisher`, `TextEditEventHub` — well-structured observer patterns |
| **Code Folding** | `CodeFoldingEngine`, fold region detection, folding providers for multiple languages |
| **Annotations** | TODO/FIXME detection, custom annotation data source, annotation views |
| **Debugging** | Debug adapter integration, breakpoint management, evaluation support |
| **Search/Replace** | `SearchReplaceEngine` |
| **Minimap** | `MinimapView`, `MinimapViewModel`, range-based highlighting |
| **Test Coverage** | ~70+ test files across performance, integration, unit, snapshot, memory leak, and platform tests |
| **Dependency Injection** | `BusinessLogicServiceRegistry`, `CodeEditorDependencies` pattern |

### 4.2 CodeEditTextView Strengths

| Area | Detail |
|---|---|
| **Line Storage** | Red-black tree with O(log n) offset/index/y-position lookup; incremental updates; never rebuilds |
| **Rendering Control** | Owns every fragment — explicit view creation, reuse, movement, and removal |
| **Edit Performance** | Incremental line record updates — O(m log n) where m = affected lines |
| **Layout Efficiency** | Only visible lines plus padding are laid out; lazy iteration; `CATransaction` batching |
| **View Reuse** | `ViewReuseQueue` pools `LineFragmentView`s by fragment ID |
| **Selection** | Multi-cursor, range merging, column selection, cursor rect calculation, blink timer |
| **Typesetting** | Direct CoreText control — line breaking, attachment handling, invisible character rendering |
| **Drawing** | `CGContext`-level control — font smoothing, subpixel positioning, antialiasing |
| **Undo/Redo** | Custom `CEUndoManager` |
| **Marked Text** | Full IME composition support with `MarkedTextManager` |
| **Text Input** | `NSTextInputClient` conformance for system text behaviors |
| **Performance Benchmarks** | Insert/delete benchmark tests with `measure` blocks tracking real timing |
| **Memory Optimizations** | `Unmanaged` references for tree operations (~15% measured improvement) |

---

## 5. Gap Analysis — What We're Missing

### 5.1 Critical Gap: Line Geometry Model

**Current state**: `LineIndexCache` is a flat array of newline offsets. It is fundamentally incapable of:

1. **Line height tracking** — No per-line height data. Cannot answer "what is the y-position of line 5000?"
2. **Y-position → line lookup** — Cannot map a scroll position to a line number without TextKit2
3. **Incremental updates** — Rebuilds entire cache on any text change (O(n) per edit)
4. **Height-aware iteration** — Cannot iterate visible lines by y-range efficiently
5. **Folded line geometry** — Cannot represent hidden lines with zero or collapsed height

**Impact**: Every feature that needs line geometry (gutter, minimap, folding, scroll preservation, viewport
prediction) either uses TextKit2 traversal (slow for large files) or walks the string (O(n) per query).

**Contrast**: CodeEditTextView's `TextLineStorage` handles all of these in O(log n) with incremental updates.

### 5.2 Missing: Incremental Edit Path for Line Data

**Current state**: `TextEditEventHub` broadcasts edits, but `LineIndexCache` just invalidates and rebuilds.
The `TextEditEventHub` consumer pattern is well-designed, but no consumer performs incremental line updates.

**Contrast**: CodeEditTextView's `textStorage(_:didProcessEditing:range:changeInLength:)` splits, merges,
inserts, and deletes individual line records without rebuilding the tree.

### 5.3 Missing: View Reuse for Rendering

**Current state**: TextKit2 manages its own fragment views. We have no explicit view reuse pool.
`TextKit2RenderingOptimizer` has a `recycledFragments` array but creates `NSTextParagraph` stubs rather
than managing actual fragment views.

**Contrast**: CodeEditTextView's `ViewReuseQueue` pools actual `LineFragmentView` instances by fragment ID,
reducing allocation pressure during scrolling.

### 5.4 Missing: Performance Benchmarks for Line Operations

**Current state**: We have `LineIndexCacheTests.swift` and `LineCountingTests.swift`, but no performance
benchmarks with `measure` blocks for insert, delete, offset-to-line, y-to-line, or visible-range operations.

**Contrast**: CodeEditTextView has `test_insertPerformance`, `test_insertFastPerformance`, and
`test_iterationPerformance` with documented baseline timings.

### 5.5 Missing: Multi-Cursor / Column Selection

**Current state**: We rely on `NSTextView.selectedRanges`, which supports multiple ranges but not column
selection mode or multi-cursor visual feedback.

**Contrast**: CodeEditTextView's `TextSelectionManager` supports multiple `TextSelection` objects with
cursor views, column selection via `TextView+ColumnSelection.swift`, and `suggestedXPos` tracking.

### 5.6 Missing: IME / Marked Text Visibility

**Current state**: TextKit2 handles marked text at the system level. We don't expose control over marked
text rendering attributes or coordinates.

**Contrast**: CodeEditTextView's `MarkedTextManager` provides explicit marked range tracking, attribute
customization, and layout invalidation for composition ranges.

### 5.7 Stale Documentation

- `CodeEditorView.swift:20`: Doc comment says "TextKit2 integration with fallback to TextKit1"
- `TextKitSetupHelper.swift:8`: Reality says "TextKit2-only since 0.2.0"
- `NOTES.md` references `OptimizedLineIndexCache.swift` which does not exist on disk

### 5.8 `TextKit2RenderingOptimizer` — Intent vs Reality

The file is ~530 lines of instrumentation (statistics, performance reports, budget tracking) but only
~150 lines of actual rendering optimization logic. The fragment cache uses `NSTextParagraph` stubs rather
than real layout fragments. This is monitoring infrastructure waiting for an optimization strategy.

---

## 6. What to Borrow and Why

### 6.1 Priority 1: Incremental Line Geometry Store

**From**: `TextLineStorage.swift`, `TextLineStorage+Structs.swift`, `TextLineStorage+Iterator.swift`,
`TextLineStorage+NSTextStorage.swift`, `TextLineStorage+Node.swift`

**What**: A balanced tree (red-black or AVL) that stores per-line UTF-16 length, height, and cumulative
subtree metadata for fast lookup by offset, line index, and y-position.

**Why**:
- Gutter rendering currently walks TextKit2 layout fragments per scroll event — O(visible lines × fragment lookup)
- With a `LineGeometryStore`, the gutter can compute visible line numbers in O(log n + visible lines)
- Minimap can compute block positions without TextKit2 traversal
- Folding can represent collapsed lines as zero-height nodes
- Scroll preservation after edits becomes deterministic (delta height propagation)
- Viewport prediction can pre-compute visible ranges without TextKit2 queries

**Implementation notes**:
- Use Swift's native reference types (no `Unmanaged` needed initially — benchmark first)
- Subscribe to `TextEditEventHub` for incremental updates
- Track: UTF-16 length, height (or estimated height until laid out), fold state
- Support: `getLine(atOffset:)`, `getLine(atIndex:)`, `getLine(atPosition:)`, `linesInRange(_:)`, `linesStartingAt(_:until:)`
- Build from `NSTextStorage` on initial load using balanced construction

### 6.2 Priority 2: Incremental Edit Handling

**From**: `TextLayoutManager+Edits.swift`

**What**: An observer on `TextEditEventHub` that updates the line geometry store incrementally:
1. On character edits: split affected line(s), merge overlapping lines, update lengths/heights
2. On newline insertions: split the containing line, insert new line record
3. On newline deletions: merge adjacent lines, update the combined line record
4. On attribute-only changes: no line geometry change needed (pass through)

**Why**:
- Eliminates O(n) rebuild per keystroke
- Enables large-file editing without line-index thrashing
- Pairs with the line geometry store to maintain O(log n) query performance during edits

### 6.3 Priority 3: Performance Benchmarks

**From**: `TextLayoutLineStorageTests.swift`

**What**: XCTest `measure` blocks for:
- Building the line store from 100k / 500k / 1M line documents
- Inserting a line at random positions (10k iterations)
- Deleting a line at random positions (10k iterations)
- Offset → line lookup (100k iterations)
- Y-position → line lookup (100k iterations)
- Visible range calculation at various scroll positions
- Incremental edit simulation (insert/delete patterns)

**Why**:
- Establishes baseline performance before we begin migration
- Prevents regressions as we replace `LineIndexCache`
- Surfaces whether a red-black tree or a simpler structure is appropriate for our scale
- Provides evidence for optimization decisions

### 6.4 Priority 4: View Reuse Infrastructure

**From**: `ViewReuseQueue.swift`

**What**: A generic reuse queue for views keyed by identifier. Provides `getOrCreateView(forKey:factory:)`
and `enqueueViews(notInSet:)` for recycling fragment views during layout.

**Why**:
- Reduces allocation pressure during scrolling
- Our gutter could reuse `LineNumberView` instances instead of redrawing text
- Minimap could reuse block views
- General pattern useful for any scrollable view with repeated subviews

### 6.5 Priority 5: Rect/Selection Geometry

**From**: `TextLayoutManager+Public.swift` (specifically `rectForOffset`, `rectsForRange`, `roundedPathForRange`,
`textOffsetAtPoint`)

**What**: Helper methods for converting between text offsets and view coordinates, taking into account
line fragments, edge insets, and composed character sequences.

**Why**:
- Our cursor/viewport integration with minimap and gutter would benefit from reliable offset→rect conversion
- `roundedPathForRange` is useful for selection highlighting with smooth corners
- These are TextKit2-agnostic utilities that complement system-provided geometry

### 6.6 Priority 6: Layout Invalidation Patterns

**From**: `TextLayoutManager+Invalidation.swift`, `TextLayoutManager+Layout.swift`

**What**: The three-signal system for determining if a line needs re-layout:
1. Was it laid out under different width constraints?
2. Was it previously not visible?
3. Is it not entirely laid out (all fragments placed)?

**Why**:
- We don't control TextKit2's invalidation, but we can apply these signals to our gutter/minimap
- The `CATransaction` batching pattern prevents re-entrant layout calls
- The separation of `invalidateLayoutForRange` from actual layout execution is a clean pattern we should
  adopt in our rendering pipeline

### 6.7 Lower Priority: Selection and Cursor

**From**: `TextSelectionManager.swift`, `TextView+ColumnSelection.swift`, `CursorView.swift`

**What**: Multi-cursor selection management, cursor view lifecycle, blink timer, column selection mode.

**Why**:
- Multi-cursor editing is a power-user feature — lower priority than geometry/layout
- TextKit2 handles basic selection well; only adopt if we need multi-cursor specifically
- The `suggestedXPos` pattern for vertical movement is clean — worth adopting if we implement multi-cursor

---

## 7. What Not to Borrow

### 7.1 Custom AppKit Rendering Stack

**Why not**: CodeEditTextView's entire rendering pipeline (`Typesetter`, `LineFragmentView`, `LineFragmentRenderer`,
`LineFragment`) replaces TextKit2 drawing with CoreText + CGContext. This would:
- Be macOS-only — breaks our cross-platform guarantee
- Duplicate TextKit2's text input, accessibility, IME, bidirectional text, and attachment handling
- Require maintaining our own marked text, cursor, selection rendering, and undo stack
- Increase maintenance surface by ~15-20 files for functionality TextKit2 already provides

### 7.2 ObjC Font Smoothing Shim

**Why not**: `CodeEditTextViewObjC` calls `CGContextSetAllowsFontSmoothing` with a hidden `0x10` flag.
This is:
- Undocumented API usage — risk of App Store rejection or breakage
- macOS-only
- Not a policy-compatible tradeoff for a cross-platform framework

### 7.3 Full `NSTextInputClient` Replacement

**Why not**: TextKit2 provides `NSTextInputClient` conformance through `NSTextView`. CodeEditTextView
reimplements it because it's a raw `NSView`. We don't need to — TextKit2 handles IME, marked text,
and input method negotiation.

### 7.4 Custom Undo Manager

**Why not**: `NSTextView` has built-in undo support via `allowsUndo`. CodeEditTextView's `CEUndoManager` exists
because it's not an `NSTextView`. We don't need a custom undo stack.

### 7.5 Per-Fragment NSView Subclass

**Why not**: CodeEditTextView creates an `NSView` per line fragment (wrapped or unwrapped lines each get their
own view). TextKit2's `NSTextLayoutFragment` + `NSTextViewportLayoutController` handles this more efficiently
at the system level, including view recycling.

---

## 8. Detailed File-by-File Analysis

### 8.1 CodeEditorPlugin Key Files

| File | Lines | Role | Gap Assessment |
|---|---|---|---|
| `Core/CodeEditorView.swift` | ~310 | Central editor class; owns all subsystems | Dog comment says TextKit1 fallback; no `LineGeometryStore` property |
| `Core/TextKitSetupHelper.swift` | ~195 | TextKit2-only setup; platform config | Solid; correctly documents TextKit2-only stance |
| `Text/LineIndexCache.swift` | ~180 | Flat offset-array line cache | **Primary gap** — no heights, no incremental updates, no y-lookup |
| `Text/TextKit2RenderingOptimizer.swift` | ~530 | Fragment cache + performance reporting | Heavy instrumentation, light optimization; fragment cache uses stubs |
| `Text/TextEditEventHub.swift` | ~60 | Canonical edit event broadcast | Well-designed but no incremental line consumer |
| `Text/TextKitLineNumberHelper.swift` | ~300 | Wraps TextKit2 for line number queries | Uses `lineIndexCache` as fallback; good abstraction |
| `Text/ModernTextKitHelper.swift` | — | TextKit2 optimizations | Supplementary performance helpers |
| `Layout/GutterView.swift` | ~400 | Cross-platform line number rendering | Redraws entire gutter per scroll; no reuse pool |
| `Layout/GutterViewModel.swift` | ~440 | Gutter state management | Uses `lineNumberService` but no line height awareness |
| `Layout/MinimapView.swift` | — | Code minimap | Relies on TextKit2 for block positions |
| `Features/CodeFoldingEngine.swift` | — | Fold detection and state | No line-height-based fold geometry |
| `Features/LineFoldStorage.swift` | — | Fold state storage | Stores which lines are folded, but not height impact |
| `Features/FoldRegionAdapter.swift` | — | Bridge between folding and rendering | Could directly consume geometry store |
| `Core/CodeEditorView+SyntaxHighlightingExtensions.swift` | — | Syntax highlight application | Invalidates `lineIndexCache` per edit; rebuilds entire cache |

### 8.2 CodeEditTextView Key Files

| File | Lines | Role | Relevance |
|---|---|---|---|
| `TextLineStorage/TextLineStorage.swift` | ~460 | Red-black tree line storage | **Highest relevance** — model for `LineGeometryStore` |
| `TextLineStorage/TextLineStorage+Structs.swift` | ~75 | `TextLinePosition`, `NodePosition`, `BuildItem` | Public API model for line queries |
| `TextLineStorage/TextLineStorage+Iterator.swift` | ~145 | Lazy y-range and text-range iterators | Pattern for efficient visible-range iteration |
| `TextLineStorage/TextLineStorage+NSTextStorage.swift` | ~40 | Build tree from text storage | Balanced construction pattern |
| `TextLineStorage/TextLineStorage+Node.swift` | — | Node type definition | RB-tree node with subtree metadata |
| `TextLayoutManager/TextLayoutManager.swift` | ~215 | Layout coordinator | Delegation pattern; width/height estimation |
| `TextLayoutManager/TextLayoutManager+Layout.swift` | ~260 | Visible-line layout loop | Three-signal layout check; `CATransaction` batching |
| `TextLayoutManager/TextLayoutManager+Edits.swift` | ~120 | Incremental edit handling | Split/merge/insert/delete pattern for edits |
| `TextLayoutManager/TextLayoutManager+Invalidation.swift` | ~40 | Layout invalidation | Clean separation of invalidation from execution |
| `TextLayoutManager/TextLayoutManager+Public.swift` | ~290 | Offset/rect/position queries | `rectForOffset`, `rectsForRange`, `roundedPathForRange` |
| `TextLine/TextLine.swift` | ~100 | Per-line display data + typesetting | `DisplayData` struct; `needsLayout` flag pattern |
| `TextLine/Typesetter/Typesetter.swift` | ~230 | CoreText typesetting | Content run splitting; attachment handling; line breaking |
| `TextLine/LineFragment.swift` | ~145 | Line fragment data model | `FragmentContent`, `ContentPosition`, x/y lookup |
| `TextLine/LineFragmentView.swift` | ~85 | Reusable fragment view | `prepareForReuse`, `setLineFragment`, `draw` |
| `TextLine/LineFragmentRenderer.swift` | ~250 | CGContext drawing | Invisible chars, font smoothing, emphasis, replacements |
| `TextView/TextView.swift` | ~340 | Main NSView subclass | Ownership model: owns storage, layout, selection, undo |
| `TextSelectionManager/TextSelectionManager.swift` | ~280 | Multi-cursor selection | Range merging, cursor views, blink timer, rect calculation |
| `Utils/ViewReuseQueue.swift` | — | Generic view reuse pool | `getOrCreateView`, `enqueueViews` |

---

## 9. Test Coverage Comparison

### 9.1 CodeEditTextView Tests

| Test File | Coverage |
|---|---|
| `TextLayoutLineStorageTests.swift` | Insert, update, delete, iteration, metadata correctness — includes `measure` blocks |
| `TypesetterTests.swift` | Typesetting correctness |
| `TextSelectionManagerTests.swift` | Selection operations |
| `TextViewTests.swift` | Text view integration |
| `MarkedTextTests.swift` | IME composition |
| `LayoutManager/` | Layout manager tests |
| `KillRingTests.swift` | Undo/redo kill ring |
| `EmphasisManagerTests.swift` | Emphasis/selection rendering |
| `AccessibilityTests.swift` | VoiceOver support |

**Characteristic**: Tests are focused on data structure correctness and rendering behavior. Performance tests
have documented baseline timings that track regressions.

### 9.2 CodeEditorPlugin Tests

| Test File | Coverage |
|---|---|
| `LineIndexCacheTests.swift` | Basic cache operations |
| `LineCountingTests.swift` | Line number accuracy |
| `PerformanceBenchmarkTests.swift` | General performance |
| `ComprehensivePerformanceTests.swift` | Multi-scenario performance |
| `PerformanceRegressionTests.swift` | Regression tracking |
| `PerformanceStressTests.swift` | Stress testing |
| `LargeFilePerformanceTests.swift` | Large file behavior |
| `LargeFileHighlightingBenchmarkTests.swift` | Highlighting at scale |
| `SyntaxHighlightingPerformanceTests.swift` | Highlighting throughput |
| `TextKit2OptimizationTests.swift` | TextKit2 rendering |
| `CodeEditorSnapshotTests.swift` | Visual regression |
| `MemoryLeakTests.swift` | Leak detection |
| `ConcurrencyTests.swift` | Thread safety |
| `ScrollPositionPreservationTests.swift` | Scroll behavior |

**Characteristic**: Heavy emphasis on performance monitoring and regression testing. Covers a broader surface
area (highlighting, LSP, configuration, SwiftUI) but lacks data-structure-level benchmarks for line operations.
The `ScrollPositionPreservationTests.swift` file is especially relevant — it would directly benefit from a
line geometry store.

---

## 10. Risk Assessment

### 10.1 Risks of Adopting a Line Geometry Store

| Risk | Severity | Mitigation |
|---|---|---|
| Maintaining two sources of truth (our store + TextKit2) | Medium | Our store is *geometry only* — it doesn't replace text content. TextKit2 remains authoritative for text. Geometry divergences are self-correcting (layout pass reconciles). |
| Tree implementation complexity | Medium | Start with a simpler data structure (gap buffer + height array). Upgrade to RB-tree only if benchmarks show need. |
| Incremental update bugs (off-by-one in split/merge) | High | Exhaustive test suite modeled after CodeEditTextView's tests. Fuzz testing with random edit sequences against a known-correct rebuild. |
| Memory overhead for large files (1M+ lines) | Low | Node-per-line overhead: ~120 bytes/node. 1M lines = ~120 MB. Acceptable for editor use. Can add sparse/paged storage if needed. |
| Cross-platform compatibility | Low | Tree is pure Swift. No platform dependencies. |
| Concurrency (TextEditEventHub is @MainActor) | Low | All line geometry mutations happen on main actor. Background reads can use a COW snapshot if needed. |

### 10.2 Risks of NOT Adopting

| Risk | Severity | Detail |
|---|---|---|
| Gutter performance degrades with file size | High | Currently walks TextKit2 fragments per scroll event — O(visible lines × fragment lookup). Large files with complex wrapping are already slow. |
| Minimap cannot render efficiently | High | Without y-position → line mapping, minimap must traverse TextKit2 for every block. |
| Fold geometry is approximate | Medium | Without height-aware line data, fold collapse/expand cannot calculate accurate content height shifts. |
| Scroll preservation after edits is fragile | Medium | Without height deltas per line, scroll position correction after edits is heuristic. |
| Cannot implement smooth scroll-to-line | Low | Without y-position lookup, scroll-to-line requires TextKit2 traversal or binary search with TextKit2 calls. |

---

## 11. Implementation Strategy

The following is an outline for the *next phase* — creating a detailed implementation plan. This section identifies
the work streams and their dependencies.

### 11.1 Phase 0: Benchmark Baseline

- Add `measure` blocks to `LineIndexCacheTests` for insert, delete, offset-to-line, and visible-range operations
- Profile gutter rendering at 1k / 10k / 100k / 1M lines
- Profile minimap block calculation for large files
- Document current performance numbers as baseline

### 11.2 Phase 1: LineGeometryStore (Core Data Structure)

- Create `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`
- Implement a tree-based or gap-buffer-based store with:
  - Per-line: UTF-16 length, height (estimated until laid out), fold state
  - Cumulative subtree: total length, total height, line count
  - Lookup: by offset, by line index, by y-position
  - Iteration: by range, by y-range
  - Build from `NSTextStorage` (balanced construction)
  - Incremental mutations: insert, update, delete
- Write exhaustive unit tests with metadata correctness assertions
- Benchmark against baseline

### 11.3 Phase 2: Incremental Edit Integration

- Create `LineGeometryEditHandler` as a `TextEditEventObserving` consumer
- Implement split/merge/insert/delete logic for newline edits
- Wire into `CodeEditorView` setup (alongside existing `lineIndexCache`)
- Run side-by-side with `LineIndexCache` during transition period

### 11.4 Phase 3: Consumer Migration

- **Gutter**: Replace `lineIndexCache.lineNumber(at:)` calls with `lineGeometryStore.getLine(atOffset:)`
- **Gutter**: Use `linesStartingAt(_:until:)` for visible line iteration instead of TextKit2 traversal
- **Minimap**: Use `lineGeometryStore` for block positions instead of TextKit2 queries
- **Folding**: Store fold state directly in `LineGeometryStore` nodes; adjust heights on fold/unfold
- **Scroll preservation**: Use height deltas from store instead of heuristic calculations
- **Viewport prediction**: Pre-compute visible range from store geometry

### 11.5 Phase 4: Deprecation and Cleanup

- Remove `LineIndexCache` once all consumers migrated
- Remove reference to nonexistent `OptimizedLineIndexCache` from documentation
- Fix stale doc comment in `CodeEditorView.swift` (TextKit1 fallback mention)
- Update `TextKit2RenderingOptimizer` to use geometry store for viewport calculations

### 11.6 Phase 5: Optional Enhancements

- Multi-cursor selection model (lower priority)
- View reuse queue for gutter line number views
- Layout invalidation pattern adoption for gutter/minimap
- Cursor geometry helpers (`rectForOffset`, `roundedPathForRange`)

---

## Appendix A: File Existence Audit

During this analysis, the following file referenced in NOTES.md was found to be **absent** from disk:

- `Sources/CodeEditorPlugin/Text/OptimizedLineIndexCache.swift` — Does not exist. The NOTES.md reference to "OptimizedLineIndexCache" reads like an unfinished prototype may have been planned but never created.

## Appendix B: Stale Documentation

| Location | Issue |
|---|---|
| `CodeEditorView.swift:20` | "TextKit2 integration with fallback to TextKit1" — should read "TextKit2-only" |
| `NOTES.md` line referencing `OptimizedLineIndexCache.swift:1` | File does not exist |

## Appendix C: CodeEditTextView Files With Highest Adoption Value

Ranked by relevance to our gaps:

1. `TextLineStorage/TextLineStorage.swift` — Data structure (LineGeometryStore model)
2. `TextLayoutManager/TextLayoutManager+Edits.swift` — Incremental edit logic
3. `TextLineStorage/TextLineStorage+Iterator.swift` — Lazy iteration patterns
4. `TextLineStorage/TextLineStorage+Structs.swift` — Public API types
5. `TextLayoutManager/TextLayoutManager+Layout.swift` — Visible-line layout + CATransaction batching
6. `TextLayoutManager/TextLayoutManager+Public.swift` — Rect/geometry utilities
7. `Utils/ViewReuseQueue.swift` — View reuse infrastructure
8. `TextLayoutManager/TextLayoutManager+Invalidation.swift` — Invalidation pattern
9. `TextSelectionManager/TextSelectionManager.swift` — Multi-cursor model (lower priority)
10. `TextLine/LineFragment.swift` — Fragment content model (reference only)
