I audited `/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView` against our `CodeEditorPlugin`. The short version: CodeEditTextView is a compact, custom AppKit text engine built around explicit line storage, CoreText typesetting, and visible-line rendering. Our editor is broader, cross-platform, TextKit2-based, and stronger in language services, theming, LSP, configuration, and SwiftUI integration. The main lesson is not “replace TextKit2”, but “adopt a real incremental line geometry model.”

**What CodeEditTextView Does Well**

CodeEditTextView’s core is a custom `NSView`, not an `NSTextView`. Its ownership model is very explicit: [TextView.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextView/TextView.swift:36) owns text storage, layout manager, line storage, selection manager, marked text, cursors, and fragment views. That gives it deterministic control over layout and rendering.

The strongest architectural piece is [TextLineStorage.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextLineStorage/TextLineStorage.swift:14): a red-black tree storing line length and height metadata. It supports fast lookup by character offset, line index, and y-position. It even uses `Unmanaged` internally after benchmarking retain/release overhead. This is exactly the kind of structure our current line indexing lacks.

Rendering is also very direct. [TextLayoutManager+Layout.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextLayoutManager/TextLayoutManager+Layout.swift:65) lays out only visible lines plus vertical padding, reuses `LineFragmentView`s, moves existing views after height changes, and separates invalidation from actual layout. [Typesetter.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextLine/Typesetter/Typesetter.swift:36) builds fragments with CoreText and attachments, while [LineFragmentRenderer.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextLine/LineFragmentRenderer.swift:46) controls text drawing, invisibles, font smoothing, and attachments at the CGContext level.

Its edit path is crisp: [TextLayoutManager+Edits.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextLayoutManager/TextLayoutManager+Edits.swift:32) consumes `NSTextStorageDelegate` edits, updates line records incrementally, invalidates affected layout, and handles newline splits/merges without rebuilding the whole line index.

**Where Our Repo Is Stronger**

Our architecture is much broader. [CodeEditorView.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Core/CodeEditorView.swift:117) sits on `PlatformTextView`/TextKit2 and integrates syntax highlighting, completion, LSP, folding, themes, annotations, SwiftUI, event publishing, and adaptive performance systems. CodeEditTextView is primarily a text surface; our package is an editor framework.

Our parsing/highlighting layer is more capable. We have SwiftSyntax-based Swift parsing, regex/token highlighting for many languages, async highlighting, token caching, range-based stores, LSP hooks, and configuration-driven theming. CodeEditTextView mostly focuses on text layout/rendering primitives and leaves language intelligence out of scope.

Our platform bet is also safer. [TextKitSetupHelper.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift:8) centralizes a TextKit2-only path across Apple platforms. That buys system input behavior, accessibility, IME handling, bidirectional text support, and less custom surface area. CodeEditTextView’s custom stack gives power, but also means it must own selection, marked text, cursors, undo, attachments, and drawing details itself.

**Main Gaps In Our Implementation**

Our `LineIndexCache` is offset-based and rebuild-oriented. It does not track line heights or support direct y-position lookup like CodeEditTextView’s tree. That limits high-performance gutter, minimap, visible range, folding geometry, and scroll preservation work.

We have since built [LineGeometryStore.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Text/LineGeometryStore.swift:1), a production red-black tree with UTF-16-correct offsets, height tracking, y-position lookup, and incremental edit support via `TextEditEventHub`. The earlier [OptimizedLineIndexCache.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Performance/OptimizedLineIndexCache.swift:1) was archived as prior art and never wired into production. [LineIndexCache.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Text/LineIndexCache.swift:1) is deprecated in favor of the new store.

Our [TextKit2RenderingOptimizer.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift:1) is more instrumentation and intent than concrete rendering control. By contrast, CodeEditTextView has a tangible reuse queue, visible-line layout loop, and fragment view lifecycle.

Doc comment fixed: `CodeEditorView.swift:20` now correctly states "TextKit2-only since 0.2.0".

**What We Should Borrow**

The highest-value move was executed: `LineGeometryStore` is now a production red-black tree (`Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`) with O(log n) lookup by offset, line index, and y-position. It receives incremental rebuilds via `LineGeometryEditHandler` subscribing to `TextEditEventHub`. `LineIndexCache` is deprecated; `OptimizedLineIndexCache` is archived as prior art. Remaining work: incremental tree updates (O(m log n) split/merge/insert/delete) to replace the current rebuild-on-edit path.

Second, make viewport performance measurable. Add benchmarks modeled after CodeEditTextView’s tests: large-file insert/delete, offset-to-line lookup, y-to-line lookup, visible range calculation, and scroll preservation after edits.

Third, keep TextKit2, but stop treating it as the only source of geometry truth. TextKit2 can still draw and handle input, while our own line geometry index powers gutters, minimaps, folding, highlighting windows, and viewport prediction.

Fourth, consider a separate selection model if we want multi-cursor editing. CodeEditTextView’s [TextSelectionManager.swift](/Users/ajmcclary/Dev/CodeEditor/CodeEditTextView/Sources/CodeEditTextView/TextSelectionManager/TextSelectionManager.swift:17) is a useful reference, especially its range merging, vertical movement state, cursor rect calculation, and marked text coordination.

**What Not To Borrow**

I would not copy the full custom AppKit rendering stack. It is macOS-only, more maintenance-heavy, and duplicates platform text behavior we currently get through TextKit2. I also would avoid the hidden font smoothing shim in the ObjC target; that is not a good portability or policy tradeoff for our framework.

The right path is selective adoption: keep our TextKit2 architecture and language-service breadth, but add CodeEditTextView-style incremental line geometry and harder performance tests. No files were changed for this audit.
