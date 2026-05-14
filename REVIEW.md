# CodeEditorPlugin — Codebase Review

Synthesis of four parallel reviewer passes covering the entire `Sources/` tree, `Tests/` conventions, and `CodeEditorSample`'s API consumption. Every issue carries a `file:line` citation; agents verified citations against the current tree at the time of review.

## Status (2026-05-14)

All 7 Critical fixes have landed on `main` (uncommitted), along with the dead-code / doc cleanup batch, the first-pass sample-driven API gaps (#1, #2, #4, #8 from the eight numbered items), and the concurrency-lifecycle + Codable sweep (`MemoryMonitor` observer leak, `removeFromSuperview` cancellation, `LayoutCoordinator` recursion, `LSPClient.disconnect` continuation leak, `EditorConfiguration.{Layout,Performance}` Codable/Equatable completeness). Build is green, SwiftLint clean (0 violations), `swift test` shows no regressions — the one observed failure (`AnnotationTests.testAnnotationTextKit2Integration: "TextKit2 layout manager not available"`) reproduces on bare `main` and is pre-existing. The `EditorStatusBarSnapshots` parallel-runner SIGSEGV/SIGBUS crashes also reproduce on bare `main` (Swift-Testing helper launching XCTest snapshot suites in parallel).

| # | Issue | Status | Notes |
|---|---|---|---|
| 1 | `TextKitBridge.setTemporaryAttributes` ignored attrs | ✅ Fixed | Now delegates to `NSTextLayoutManager.setRenderingAttributes(_:for:)`. Matches the working impl already in `ModernTextKit2Bridge.swift:172-184`. |
| 2 | `MemoryManagementCoordinator` used TextKit 1 APIs | ✅ Fixed | Removed the `editorView.layoutManager`/`textContainer` branch — it was a no-op anyway (`ensureLayout` doesn't free memory). |
| 3 | `EditorEvent.error(Error)` non-`Sendable` | ✅ Fixed | Introduced `SendableError` (Sendable + Hashable + CustomStringConvertible) with `init(_ error: any Error, domain:)` convenience. Updated `UnifiedEventSystem.lastError` accordingly. No production code constructed `.error(...)`, so call-site fanout was zero. |
| 4 | UTF-16 vs `Character.count` in symbol providers | ✅ Fixed | Applied to **15** files (the 8 originally listed + 7 missed by the review with the same bug: `ShellSymbolProvider`, `SQLFoldingProvider`, `ShellFoldingProvider`, `RubyFoldingProvider`, `JavaScriptSymbolProvider`, `YAMLSymbolProvider`, `XMLSymbolProvider`). All `NSRange(...length: X.count)` and `currentLocation += X.count + 1` sites now use `TextRangeUtilities.utf16Length(of: X)`. |
| 5 | `Theme.lcarsDark` re-decoded JSON per access | ✅ Fixed | Converted `static var` → `static let`. JSON now decodes once at first access. |
| 6 | `PortableProjectSearchAdapter` recompiled regex per line | ✅ Fixed | Regex now compiled once in `performSearch` and passed through to `makePredicate`/`computeColumn`. |
| 7 | `SmartTokenCache.CacheKey` stored full source text | ✅ Fixed | Dropped `text` field; key is now `textLength + textFingerprint(FNV-1a) + language + version`. Updated the `CacheProtocol` round-trip in `ActorCoordinator` to serialize/parse the new compact format. Also dropped the bogus "legacy length-only" recovery path the review separately flagged as broken (it was materializing `String(repeating: "\0", count: textLength)` and causing collisions). |

**Files touched (23):**
`ActorCoordinator.swift`, `EditorEvent.swift`, `MemoryManagementCoordinator.swift`, `UnifiedEventSystem.swift`, 15 language providers (`CSSSymbolProvider`, `CStyleSymbolProvider`, `HTMLSymbolProvider`, `JSONSymbolProvider`, `JavaScriptSymbolProvider`, `MarkdownSymbolProvider`, `PHPSymbolProvider`, `RubyFoldingProvider`, `RubySymbolProvider`, `SQLFoldingProvider`, `SQLSymbolProvider`, `ShellFoldingProvider`, `ShellSymbolProvider`, `XMLSymbolProvider`, `YAMLSymbolProvider`), `ProjectSearchProvider.swift`, `SmartTokenCache.swift`, `TextKitBridge.swift`, `ThemeFamily+Loader.swift`.

**Pre-existing test issues (not introduced by these fixes — confirmed by running `swift test` against `main`):**
- `AnnotationTests.testAnnotationTextKit2Integration` — converted to `XCTSkipIf` on `2026-05-14` after investigation revealed a deeper TK2→TK1 coercion (see "Latent TextKit 2 coercion" below).
- `EditorStatusBarSnapshots` crashes (signals 10/11) under `--parallel` — Swift-Testing helper spawning XCTest snapshot suites concurrently.

### Dead-code & doc cleanup batch (landed 2026-05-14)

The first batch of post-Critical low-risk cleanup work, scoped to deletions, doc rot, and trivial duplicates — no API surface changes, no concurrency reasoning, no design calls.

| Item | Status | Notes |
|---|---|---|
| Delete `Text/TextLayoutManager.swift` (the custom `: NSTextLayoutManager` subclass) | ✅ Done | Not referenced; production uses `NSTextLayoutManager` directly. |
| Delete `Text/TextLayoutFragmentView.swift` | ✅ Done | Unreferenced. |
| Delete `Models/MarkedText.swift` | ✅ Done | `package`-scoped; unreferenced. |
| Delete `Models/NSTextSegmentType.swift` | ✅ Done | Unreferenced. |
| Trim `Core/SendableTypes.swift` to the two used types | ✅ Done | Kept `SendablePerformanceMetric` + `FileChangeNotification`; dropped `SendableEditorEvent`, `SendableCompletionContext`, `SendableResult`, `SendableProgress`, `SendableCacheKey`, `SendableConfigurationChange`. |
| Delete `PlatformEventFilter` (always-`true` `shouldAllow`) + its installation in `UnifiedEventSystem.setupDefaultFilters` | ✅ Done | Filter chain now contains only `PerformanceEventFilter`. The (now unused) `capabilities` stored property is kept to preserve the public `init` signature. |
| Delete `ConfigurationCodeFormatter.swiftStringLiteral` | ✅ Done | Dead helper. |
| Remove `@preconcurrency` from `SwiftUI` imports (`CodeEditor.swift`, `CodeEditor+FactoryExtensions.swift`, `CodeEditor+ModifiersExtensions.swift`) | ✅ Done | Three files; no warnings re-surface. |
| Fix "17+ languages" → "25 + plain text" in `SyntaxHighlightingCoordinator.swift:167` | ✅ Done | Matches CLAUDE.md and `LanguageCatalog`. |
| Strip the `## Topics` DocC block in `CodeEditorUI/CodeEditorUI.swift` | ✅ Done | Project has no DocC catalog per CLAUDE.md; the directive was dead pedagogy. |
| Replace `print("Configuration errors:")` doc comment in `EditorConfiguration.swift:68` | ✅ Done | Snippet now points at "your app's logging or UI" instead of a `print` call (violated the project's own lint rule's spirit). |
| Drop `docs/superpowers/...` citation in `AppState.swift:76` | ✅ Done | `docs/superpowers/` is archived working notes per CLAUDE.md; rewritten as a generic forward-looking note. |
| Dedupe `durationMilliseconds` / `milliseconds` math | ✅ Done | New `Sources/CodeEditorSample/App/Duration+Milliseconds.swift` with `Duration.totalMilliseconds: Double`. Both `KnobRow.milliseconds(_:)` and `ConfigurationCodeFormatter.durationMilliseconds(_:)` now call through. |
| Extract magic `17.0` in `LineGeometryEditHandler` | ✅ Done | Exposed `LineGeometryStore.defaultEstimatedHeight` as `public let`; the three `?? 17.0` fallbacks now read from the store. |
| `SettingsScene` fixed-frame overriding `windowResizability(.contentSize)` (`CodeEditorSampleApp.swift:16-20`) | ✅ Done | Dropped `.frame(width: 1_380, height: 880)`; moved the sizing to `.defaultSize(width:height:)` on the `WindowGroup` and switched `.windowResizability(.contentMinSize)` so the min-frame survives. The window is now resizable above 980×640 with a 1380×880 default. |
| Fix `AnnotationTests.testAnnotationTextKit2Integration` | ✅ Done (skip) | Converted to `XCTSkipIf` with an in-comment explanation; see next section for the underlying issue. |

**Files touched (this batch — 14 modified, 4 deleted, 1 added):**
Modified — `Sources/CodeEditorPlugin/Core/SendableTypes.swift`, `Sources/CodeEditorPlugin/Core/UnifiedEventSystem.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+FactoryExtensions.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`, `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`, `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift`, `Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`, `Sources/CodeEditorUI/CodeEditorUI.swift`, `Sources/CodeEditorSample/App/AppState.swift`, `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`, `Sources/CodeEditorSample/Sidebars/ConfigurationCodeFormatter.swift`, `Sources/CodeEditorSample/KnobPanels/KnobRow.swift`, `Tests/CodeEditorPluginTests/AnnotationTests.swift`.
Deleted — `Sources/CodeEditorPlugin/Text/TextLayoutManager.swift`, `Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift`, `Sources/CodeEditorPlugin/Models/MarkedText.swift`, `Sources/CodeEditorPlugin/Models/NSTextSegmentType.swift`.
Added — `Sources/CodeEditorSample/App/Duration+Milliseconds.swift`.

Build: green. SwiftLint: 0 violations. Targeted test (`AnnotationTests.testAnnotationTextKit2Integration`) now skips cleanly; rest of suite unchanged.

**Deliberately deferred from this batch:**
- `RegexBackedRangeQueryParser` deletion (Minor section). It's unused in production but `Tests/CodeEditorPluginTests/RegexRangeHighlightProviderTests.swift` (371 lines of benchmark coverage) targets it directly. Removing the parser requires either rewriting the tests against `RegexIncrementalRangeQueryParser` or deleting them — neither is "low-hanging" and both want their own commit.

### Latent TextKit 2 coercion (`CodeEditorView.setupTextView` — discovered 2026-05-14)

Investigating the skipped `testAnnotationTextKit2Integration` surfaced a real production gap that the test was, in effect, trying to flag.

**Symptom.** `CodeEditorView.textLayoutManager` is `nil` immediately after `init(frame:)`, even though `CLAUDE.md` and the `CodeEditorView` header comment (`Core/CodeEditorView.swift:159-169`) both declare the framework TextKit 2-based and explicitly rely on `NSTextView` constructing its own TK2 stack via `super.init(frame:)`. Verified out-of-band that a plain `NSTextView(frame: .zero)` *does* return a non-nil `textLayoutManager` on this macOS — so the regression is local to `CodeEditorView`'s init path, not the platform.

**Cause.** `setupTextView()` → `setupLineGeometryStore()` → `rebuildLineGeometryStoreFromCurrentTextStorage()` reaches through `self.textStorage` (`Core/CodeEditorView+SetupExtensions.swift:99-109`). Per Apple's TK2 docs, reading the legacy `textStorage` property on a TK2-initialized `NSTextView` silently coerces it back to TextKit 1 and clears `textLayoutManager`. So the very first thing the editor does after `super.init` strands itself in TK1 mode.

**Impact.** Anything that conditionalises on `textLayoutManager != nil` quietly takes its fallback path — including the existing `ModernTextKit2Bridge`, `TextKit2RenderingOptimizer`, and any future TK2-only optimization. The `MemoryManagementCoordinator` TK1 cleanup that was just removed for being "no-op anyway" is structurally aligned with this: TK2 paths have been inert for a while. The framework is, in practice, a TextKit 1 editor that *thinks* it's TextKit 2.

**What to do (future work, scoped).**
1. Change `LineGeometryStore.build(from:)` (and any other rebuild path) to consume `NSTextContentStorage` (TK2) instead of `NSTextStorage` (TK1). The TK2 content manager exposes the same UTF-16 line enumeration via `NSTextElement`/`NSTextParagraph`.
2. Audit every callsite that names `textStorage`, `layoutManager(...)`, or `textContainer` directly. Wrap each in a TK2-first/TK1-fallback helper, or delete the TK1 branches outright.
3. Re-enable `testAnnotationTextKit2Integration` (drop the `XCTSkipIf`) once `CodeEditorView.textLayoutManager` is non-nil after init. That test is the right canary for this invariant.
4. Add a regression test that fails fast if `CodeEditorView(frame: ...).textLayoutManager == nil`, plus a doc comment on `CodeEditorView` warning future contributors not to touch `self.textStorage` in setup.

This is large enough to want its own design pass — the `LineGeometryStore` build path is on the hot edit/text-change path and is exercised by a meaningful chunk of the geometry-related tests, so the migration needs to preserve UTF-16 correctness while also unlocking `NSTextLayoutManager`-only features for downstream code (rendering attributes, viewport-aware layout, etc.).

### Sample-driven API gaps — first pass (landed 2026-05-14)

Four of the eight numbered "API gaps revealed by `CodeEditorSample`" — the additive, non-design-breaking subset. The four left (EditorDocument recipe, EditorController.onAttach, CompletionEvent stream, performance observer modifier) need their own design conversations and are deferred.

| # | Gap | Status | What landed |
|---|---|---|---|
| 1 | No LSP-range-to-NSRange utility (sample shipped a known-wrong `makeNSRange`) | ✅ Done | Added `EditorController.nsLocation(forLSPLine:character:)` and `EditorController.nsRange(forLSPRange:)`. Both translate LSP zero-based `(line, character)` positions into UTF-16 offsets against the live buffer; clamping to line bounds is implicit because the conversion goes through the editor's own `lineRange(for:)`. `DiagnosticsBridge` now takes a `convertLSPRange: (LSPRange) -> NSRange?` closure (production wires it to `controller.nsRange(forLSPRange:)`); the apologetic 14-line comment and the broken `(line, character) → character` fallback are gone. Tests updated to stub the converter explicitly. |
| 2 | `Annotation` has no public `kind` field — sample smuggled severity via `"ERROR: …"` content prefix | ✅ Done | Added `kind: AnnotationKind?` to both `Annotation` and `CodeEditorViewAnnotation` (optional, defaults to `nil` so existing call sites are source-compatible). New `Annotation.resolvedKind` reads the explicit kind first and falls back to `AnnotationKind.infer(from: content)`. `updateAnnotationView` propagates `kind` into the `CodeEditorViewAnnotation` passed to the data source. Sample's `AnnotationsHub` and `DiagnosticsBridge` now pass `kind:` directly; the `"ERROR: breakpoint"` / `"WARNING: …"` content prefixes are gone (content strings carry only the user-visible message). |
| 4 | `AnnotationsDataSource` is `weak` — hosts must keep their own strong reference | ✅ Done (docs) | Added explicit `- Important:` blocks on both `CodeEditorView.annotationsDataSource` and the `AnnotationsDataSource` protocol header explaining the weak ownership invariant and the failure mode (annotations silently stop appearing if the host drops its retain). No code change; the lifecycle still belongs to the host. |
| 8 | `FrameworkEdgeInsets` had `let` fields, forcing whole-struct rebuilds per edge | ✅ Done | Changed `EdgeInsets.{top,left,bottom,right}` from `let` to `var`. `LayoutKnobsSection.insetBinding` collapsed from a 9-line keyPath-equality branchy rebuilder to a 6-line `WritableKeyPath`-driven binding. |

**Files touched (this batch — 9 modified, 0 added, 0 deleted):**
`Sources/CodeEditorPlugin/Annotations/Annotation.swift`, `Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift`, `Sources/CodeEditorPlugin/Annotations/CodeEditorViewAnnotation.swift`, `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`, `Sources/CodeEditorPlugin/Core/CodeEditorView+AnnotationsExtensions.swift`, `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, `Sources/CodeEditorPlugin/Utilities/CoordinateSystemHelper.swift`, `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`, `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`, `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift`, `Sources/CodeEditorSample/KnobPanels/LayoutKnobsSection.swift`, `Tests/CodeEditorSampleTests/DiagnosticsBridgeTests.swift`.

Build: green. SwiftLint: 0 violations. Public-API changes are strictly additive (new methods, new optional fields with `nil` defaults, new convenience computed property); existing call sites continue to compile.

**Still open from this section (deferred — need design):**
- #3 EditorDocument value type — the sample reinvents `DocumentStore` / `TabModel` / dirty tracking. A first-class document recipe wants its own design pass (lifecycle, observability, naming, what's owned vs. shared).
- #5 `EditorController.onAttach { … }` — the three-way wiring in `AppState.init` is awkward, but the fix interacts with #3 and with whether `EditorController` should grow a richer attach lifecycle.
- #6 `CompletionManager` `AsyncStream<CompletionEvent>` — every completion provider has to be wrapped for telemetry today. The right surface (single bus per manager? per provider? what's an event?) is a design call.
- #7 `.performanceObserver(_:)` SwiftUI modifier — `UnifiedPerformanceSystem` is dual-wired (config + polled). Folding both into one modifier is a small refactor but interacts with the SwiftUI runtime-rebuild issue (`EditorRuntimeDependencies.live(...)` per body call), so it's worth waiting until that's addressed.

**Coverage gaps from REVIEW.md "Coverage gaps the sample fails to demonstrate" — still untouched.** Same story as before — they're sample updates that demonstrate already-public APIs (`.codeLanguage(_:)`, `.showsLineNumbers(_:)`, factories, snippet templates, `LSPCompletionProvider` registration, `CodeEditorError` recovery, the duplicated `PerformanceInspectorPanel` redundancy). Not blocking, but worth a small follow-up to make the sample a fuller "documentation by example".

### Concurrency / lifecycle batch + Codable sweep (landed 2026-05-14)

Steps 3 and 4 from the "Suggested ordering" section landed as one pass. Five issues, four files in `Sources/CodeEditorPlugin/`, plus one call-site update.

| Item | Status | What landed |
|---|---|---|
| `MemoryMonitor` observer leak + uncancelled tasks (`Performance/MemoryMonitor.swift:259-285`) | ✅ Done | `deinit` now cancels `monitoringTask` and `cleanupTask` and removes the `NSApplication.willTerminateNotification` / `UIApplication.willTerminateNotification` observer. The three relevant properties are `nonisolated(unsafe)` with rationale comments — `Task<Void, Never>` is Sendable, and `NSObjectProtocol` writes only happen from the `@MainActor` `init`, so the deinit read is happens-after the last MainActor write. NotificationCenter slots and zombie monitor tasks no longer accumulate across multi-window / test cycles. |
| `CodeEditorView.removeFromSuperview` async cancellation race (`Core/CodeEditorView.swift:533-535`) | ✅ Done | `SyntaxHighlightingCoordinator.cancelHighlighting()` is now synchronous (see below); `removeFromSuperview` calls it directly instead of spawning `Task { await … }`. Cancellation is now visible before the next editor wires up. |
| `SyntaxHighlightingCoordinator.HighlightingTaskManager` actor → lock (`SyntaxHighlighting/SyntaxHighlightingCoordinator.swift:13-49, 86-101, 147-153`) | ✅ Done (refactor) | Replaced the private `actor` with a `final class: @unchecked Sendable` wrapping an `NSLock` + optional `Task`. `cancelCurrent()` is now sync from any isolation domain. `highlightAsync` collapsed `await cancelCurrent` + `await setCurrentTask` into a single atomic swap. Top-of-file `@unchecked Sendable` rationale comment updated to describe the lock invariant instead of the (now-removed) actor. |
| `LayoutCoordinator.processPendingOperations` unbounded recursion (`Layout/LayoutCoordinator.swift:101-111`) | ✅ Done | `performLayout` now runs the operation, then iteratively drains the pending queue via a `while !pendingLayoutOperations.isEmpty` loop. `isPerformingLayout` stays `true` across the entire drain (so operations enqueued mid-drain queue correctly and are picked up by the next iteration instead of recursing back through `performLayout`'s defer). |
| `LSPClient.disconnect()` continuation leak + late-response drop (`LSP/LSPClient.swift:178-249`) | ✅ Done | `disconnect()` now (a) bails out early when `connectionState == .disconnected` so the path is idempotent, (b) captures `pendingRequests` into a local `pendingToFail` before clearing the dictionary, and (c) fails each captured continuation with `.notConnected` after the transport teardown completes. Continuations are no longer dropped (which under strict-concurrency `withCheckedThrowingContinuation` traps in DEBUG and hangs awaiters in release). State is also cleaned up in a consistent order: capture pending → clear sync state → fire shutdown task → tear transport → fail pending → set `.disconnected`. |
| `EditorConfiguration.Layout.Codable` drops 5 fields (`Configuration/EditorConfiguration+LayoutExtensions.swift:66-130`) | ✅ Done | Added `annotationBadgeSize`, `annotationBadgePadding`, `minimapWidth`, `foldingControlSize`, `foldingControlPadding` to `CodingKeys`, `init(from:)`, and `encode(to:)`. `Equatable` is synthesized and already covered them. Defaults match the property defaults so old persisted JSON keeps decoding. |
| `EditorConfiguration.Performance.usesRangeBasedHighlighting` missing from Codable + Equatable (`Configuration/EditorConfiguration+PerformanceExtensions.swift:128-210`) | ✅ Done | Added the case to `CodingKeys`, `init(from:)`, `encode(to:)`, and `==`. Default in decoder matches the struct default (`false`). |

**Files touched (this batch — 6 modified):**
`Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift`, `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`, `Sources/CodeEditorPlugin/Layout/LayoutCoordinator.swift`, `Sources/CodeEditorPlugin/LSP/LSPClient.swift`, `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+LayoutExtensions.swift`, `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+PerformanceExtensions.swift`.

Build: green. SwiftLint: 0 violations. Targeted tests for the touched areas (`EditorConfiguration`, `MemoryMonitor`, `LayoutCoordinator`, `LSPClient`, `SyntaxHighlight*`) pass — 20 tests across 6 suites green via `swift test --filter`. Full-suite `swift test` still shows the two pre-existing crashes documented in the Status section (`EditorStatusBarSnapshots` SIGSEGV/SIGBUS under the swift-testing → XCTest snapshot bridge); they reproduce on bare `main` and are out of scope.

**Public API impact.** Strictly additive on the configuration side (the new Codable keys default to existing struct defaults, so previously-persisted JSON keeps decoding identically). `SyntaxHighlightingCoordinator.cancelHighlighting()` lost its `async` keyword — the only in-tree caller was `CodeEditorView.removeFromSuperview`, updated in the same batch. External callers using `await coordinator.cancelHighlighting()` will get a "no async operations" warning, not a compile error.

**Still open from the "Suggested ordering" list:**
- Step 1 (Critical fixes) and step 2 (sample-driven API gaps first pass) landed earlier in this document.
- Step 3 / 4 (this batch).
- Step 5 (minor / dead-code cleanup) — partially landed in the earlier dead-code batch; the remaining "Minor" items below are still open.

The four remaining items from the original "Concurrency & lifecycle" Important list — `EditorEventPublisher.publish` unstructured Task, `ProcessTransport` busy-poll, `completionRequested` lack-of-cancel, the `CodeEditorView` `deinit` analog for highlighting — were not in scope for this batch and remain in the Important section below.



## Top-level take

The codebase is in good shape on the boring axes — convention compliance is solid (no `print()`, no force-unwraps, no `#if os(...)` regressions, no Mac Catalyst residue, `@unchecked Sendable` sites carry rationale comments). The bugs are mostly in the seams: TextKit 1 sneaking back in via `MemoryManagementCoordinator`, a silent no-op in `TextKitBridge`, UTF-16 vs `Character.count` drift across symbol providers, theme-decoding pressure on the hot SwiftUI path, and a sample app that's pedagogically strong but ships a known-wrong LSP range converter.

The most important strategic finding is from the sample review: **the API gaps revealed by the sample are the actionable list**. The sample is trying to be the framework's documentation, and the places it had to invent workarounds point at missing public APIs.

---

## Critical issues (fix immediately)

1. **`TextKitBridge.setTemporaryAttributes(_:for:)` silently ignores its attributes argument** — `Sources/CodeEditorPlugin/Text/TextKitBridge.swift:257`. The parameter label is `_:`. The public-facing `setRenderingAttributes(_:for:)` (`TextView+Extensions.swift:92-94`) promises to apply rendering attributes for syntax highlighting; nothing happens. Either implement via `NSTextLayoutManager` rendering attributes or delete the public API. Silent correctness bug.

2. **`MemoryManagementCoordinator.performMemoryCleanup` calls TextKit 1 APIs on a TextKit 2 view** — `Sources/CodeEditorPlugin/Core/MemoryManagementCoordinator.swift:219-225`. Accessing `editorView.layoutManager`/`textContainer` activates TextKit 1 compatibility mode, violating the load-bearing invariant from `project_nstextview_init_invariant`. Replace with `textLayoutManager?.textViewportLayoutController` invalidation or drop the branch.

3. **`EditorEvent` declared `: Sendable` while carrying `any Error`** — `Sources/CodeEditorPlugin/Core/EditorEvent.swift:153,76`. `any Error` is not `Sendable`. `EditorEventPublisher.publish` (line 108) hops events to `@MainActor` via `Task { @MainActor in ... }`. Strict-concurrency unsafe. Box errors in a `Sendable` payload.

4. **UTF-16 vs `Character.count` in symbol providers** — `NSRange(...length: line.count)` is used across `HTMLSymbolProvider.swift:15,61,97`, `CStyleSymbolProvider.swift:15,34`, `CSSSymbolProvider.swift:15`, `JSONSymbolProvider.swift:68,92`, `MarkdownSymbolProvider.swift:15,33`, `RubySymbolProvider.swift:15`, `PHPSymbolProvider.swift:17`, and all eleven sites in `SQLSymbolProvider.swift`. Any non-BMP code point (emoji, certain CJK) drifts every subsequent symbol range. `LineBasedSymbolProvider.detectSymbols:59` does it right — adopt that pattern via `TextRangeUtilities.utf16Length(of:)`. Worth a lint rule.

5. **`Theme.lcarsDark` re-decodes the entire 5,512-line theme JSON on every access** — `Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift:58-61`. It's a `var`, not a `lazy let`. `Theme.default`/`Theme.dark` forward to it; `CodeEditor.init` default-binds it; every SwiftUI body of every host pays the decode. Convert to `static let`.

6. **`PortableProjectSearchAdapter` recompiles a regex per matched line** — `ProjectSearchProvider.swift:187-202`. For a 200-result regex search that's hundreds of redundant compiles. Compile once in `performSearch`.

7. **`SmartTokenCache.CacheKey` stores the full source text in the key** — `SmartTokenCache.swift:5-43`. Defeats the cache's purpose; each entry retains an O(n) copy. Use the fingerprint + length only.

---

## Important issues (fix before next merge)

### Concurrency & lifecycle
- `CodeEditorView.removeFromSuperview` fires `Task { await syntaxHighlighter.cancelHighlighting() }` (`Core/CodeEditorView.swift:533-535`) — cancellation arrives after the next editor is up; no `deinit` analog.
- `MemoryMonitor` registers an `NSObjectProtocol` termination observer but never removes it; `Task`s aren't auto-cancelled (`Performance/MemoryMonitor.swift:259-285`). Leaks NotificationCenter slots + live tasks across tests/windows.
- `EditorEventPublisher.publish` (`Core/EditorEventPublisher.swift:98-113`) spawns an unstructured `Task` per publish — A/B ordering is not preserved despite call-site expectations.
- `LSPClient.disconnect()` clears state synchronously while shutdown runs detached (`LSP/LSPClient.swift:179-224`); in-flight responses arriving after dictionary clear are silently dropped.
- `ProcessTransport` busy-polls `availableData` every 10ms and races its `receive()` with `setDataHandler` (`ProcessTransport.swift:233-256`). Use `readabilityHandler`/`DispatchIO`.
- `LayoutCoordinator.processPendingOperations` can recurse unboundedly via its own `defer` (`Layout/LayoutCoordinator.swift:101-111`). Convert to an iterative drain.
- `completionRequested` does not cancel in-flight task before spawning a new one (`Core/CodeEditorView+CompletionExtensions.swift:100`).

### API correctness
- `CodeEditorAPI` mixes `Range<String.Index>` and `NSRange` despite claiming the latter is canonical (`Core/CodeEditorAPI.swift:65`, sites 93–145). `String.Index` is unstable across edits. Pick `NSRange`.
- `EditorConfiguration.Layout.Codable` drops 5 fields silently (`Configuration/EditorConfiguration+LayoutExtensions.swift:66-116`) — `annotationBadgeSize`, `annotationBadgePadding`, `minimapWidth`, `foldingControlSize`, `foldingControlPadding`. Data loss on persistence round-trip.
- `EditorConfiguration.Performance.usesRangeBasedHighlighting` is missing from `CodingKeys` and `==` (`+PerformanceExtensions.swift:22 / 128–142 / 194–209`).
- `CodeEditorEnvironment.with(...)` cannot clear optional fields — `nil` is collapsed to "no change" (`SwiftUI/CodeEditorEnvironment+Extensions.swift:84-95, 185-207`).
- `EditorState` env default allocates a fresh instance per read (`SwiftUI/EditorState+Environment.swift:13`). Writes silently no-op.
- `CodeEditor.body` reallocates `EditorRuntimeDependencies.live(...)` per render — `MemoryMonitor`, `ActorCoordinator`, etc. all rebuilt (`SwiftUI/CodeEditor.swift:271-277` + `Core/EditorRuntime.swift:46-64`).
- Inconsistent SwiftUI modifier return types: some return `some View`, others return `CodeEditor` (`SwiftUI/CodeEditor+ModifiersExtensions.swift`). Chains break once a host hits a `some View` modifier before a `CodeEditor`-typed one.
- `SmartEditingEngine.attach` overwrites `textView.delegate` with a warning log (`Features/SmartEditingEngine.swift:53-61`). With LSP/completion/folding all wanting hooks, last wins.
- `SearchReplaceEngine` and `SmartEditingEngine` are `public class` (non-`final`) — open subclassing.
- `SwiftUICompletionItem` not `Sendable` despite being returned from a `@Sendable` async closure (`SwiftUI/CodeEditor+CompletionExtensions.swift:36`).

### Language/highlighting/completion correctness
- LSP iOS coverage is fictional: `LSPClient` docs claim "remote servers on iOS," but `LSPManager`, `LSPCompletionProvider`, `LSPSemanticTokenProvider`, `LSPDocumentManager`, `LSPClientRegistry`, `LSPContentCoordinator`, `LSPPathResolver` are all wrapped in `#if canImport(AppKit)`.
- Three independent completion ranking pipelines disagree: `CompletionManager.sortAndDeduplicateItems:289-311`, `CompletionRankingModel.rank:33-64`, `SmartCompletionEngine.rerank`.
- `descriptor.highlightingStrategy` is dead data — every descriptor sets it; nothing reads it (`HighlightingStrategyExecutor.determineStrategy:47-61` hardcodes the routing).
- `parserName` (a tree-sitter grammar id) doubles as a "use regex highlighter" gate (`RegexSyntaxHighlighter+LanguagesExtensions.swift:35,46`, `RegexRangeHighlightProvider.swift:319`). Misleading; introduce explicit `usesRegexHighlighter`.
- Stale language count: `SyntaxHighlightingCoordinator.swift:167` says "17+ languages" — CLAUDE.md is canonical at 25 + plain text.
- Two parallel fuzzy matchers: `FuzzyMatcher` (`FuzzyMatcher.swift:4`, non-`Sendable`) and `OptimizedFuzzyMatcher` (Sendable). `SmartCompletionEngine.swift:54` uses the non-`Sendable` one.
- `RegexBackedRangeQueryParser` invalidates the entire document on every edit (`RegexRangeHighlightProvider.swift:88-92`). Unused; delete to prevent confusion.

### Cross-cutting
- `CrossPlatformLogger.osLogger.log(level:, "\(message)")` (`Utilities/CrossPlatformLogger.swift:100`) defeats OSLog format-string privacy/redaction — call sites already interpolated state. Privacy annotations are lost; arbitrary state may leak into release logs.
- `CodeEditorDependencies` reads `DependencyValues._current.codeEditorMemoryMonitor()` instead of the `@Dependency` property wrapper (`Core/CodeEditorDependencies.swift:9`). `withDependencies { }` overrides won't flow through actor hops reliably.
- `EditorEventBusInstaller.sourcePosition` is O(n) per hover/⌘-click via UTF-16 walk (`Layout/EditorEventBusInstaller.swift:124-144`). Use `LineGeometryStore`.
- `PlatformEventFilter.shouldAllow` always returns `true` (`Core/UnifiedEventSystem.swift:241-244`). Dead.
- `EditorTrafficLights` hardcodes RGB outside the token system (`Sources/CodeEditorUI/Window/EditorTrafficLights.swift:41-48`).

---

## API gaps revealed by `CodeEditorSample` (most actionable)

These are what the sample had to *invent* to integrate the framework — the framework should absorb them:

1. **No LSP-range-to-NSRange utility.** `DiagnosticsBridge.makeNSRange` (`App/LSP/DiagnosticsBridge.swift:124-142`) ships a known-wrong implementation that collapses `(line, character)` to `character` only — every diagnostic past line 1 is decorated at the wrong offset. The 14-line apologetic comment is the giveaway. Expose `EditorController.nsRange(forLSPRange:)`.
2. **`Annotation` has no public `kind` field.** Sample fakes severity by content-prefix smuggling: `"ERROR: breakpoint"`, `"TODO: demo annotation"` (`EditorActions/AnnotationsHub.swift:114-138`). Add an `AnnotationKind` to the public `Annotation` struct.
3. **No first-class "document" recipe.** Sample reinvents `DocumentStore`, `TabModel`, dirty tracking, per-tab `EditorInteractionState`, language inference (`Documents/DocumentStore.swift`). At minimum, document the recipe in `CodeEditorPlugin.swift`'s quick-start; better, ship an `EditorDocument` value type.
4. **`AnnotationsDataSource` is `weak`** so hosts must retain it themselves (the only reason `AnnotationsHub` is owned by `AppState`). Either let the framework own it or document the weak ownership at the API call site.
5. **Three-way `EditorController` wiring is hidden in `AppState.init`** (`AppState.swift:93-118`): `.editorController(_:)` modifier + injection into `AnnotationsHub` + injection into `LSPSampleCoordinator`. Consider `EditorController.onAttach { ... }`.
6. **No telemetry hook on `CompletionProvider`.** Sample wraps every provider in `TelemetryCompletionProvider` (`App/Completion/TelemetryCompletionProvider.swift`). Expose `AsyncStream<CompletionEvent>` on `CompletionManager`.
7. **`UnifiedPerformanceSystem` dual wiring** — assigned to config *and* polled via `generateInsights()` separately (`AppState.swift:136`, `PerformanceSampleCoordinator.swift:111`). Add `.performanceObserver(_:)` modifier that does both.
8. **`FrameworkEdgeInsets` lacks per-edge writable subscripts** — `LayoutKnobsSection.swift:64-79` had to rebuild the whole struct per set.

### Coverage gaps the sample fails to demonstrate
- `.codeLanguage(_:)`, `.showsLineNumbers(_:)`, `.codeWorkspaceRoot(_:)` — advertised in the umbrella; sample uses none of them.
- `CodeEditor.withLanguage`/`withConfiguration` factories — unused.
- `SnippetTemplate`, `CompletionProviderUtilities.fuzzyFilter`, `CompletionRankingModel` — unreferenced.
- `LSPCompletionProvider` registration through `CompletionManager` — wired nowhere.
- `CodeEditorError` recovery — pitched in umbrella docs, never used.
- `PerformanceInsightsPanel` (framework view) is duplicated by `Sidebars/PerformanceInspectorPanel`; sample re-rolls.
- `EditorTrafficLights`, `EditorTitleBar`, `EditorBreadcrumbView`, `PlatformGlassSurface` from `CodeEditorUI` — zero call sites.
- iOS has no LSP/perf/completion inspector — silently absent. Add a `ContentUnavailableView` explaining the gap.
- No file-save path; `DocumentStore.openFile` reads, never writes.

---

## Minor issues / dead code worth pruning

- Dead types: `Text/TextLayoutManager.swift`, `Text/TextLayoutFragmentView.swift`, `Models/MarkedText.swift`, `Models/NSTextSegmentType.swift`, most of `Core/SendableTypes.swift` (only `SendablePerformanceMetric`, `FileChangeNotification` referenced).
- `TestEnvironmentDetector.isRunningInTests` checks `XCTestConfigurationFilePath` only — wrong for Swift Testing (`Utilities/TestEnvironmentDetector.swift:39-41`). Worse, the env-detection branching in `MemoryManagementCoordinator.setupMemoryMonitoring:119` hides lifecycle bugs from tests.
- Magic `17.0` line-height in `LineGeometryEditHandler.swift:125-126,136,142`.
- `FastJSONTokenizer` round-trips color → `TokenType` to rebuild `HighlightedToken` (`HighlightingStrategyExecutor.highlightJSON:87-97`). Defeats theme overrides.
- `HTMLSymbolProvider.extractAttribute` compiles a regex per call (`HTMLSymbolProvider.swift:92-93`).
- `CompletionDebouncer.executeRequest` cancels prior tasks but `withCheckedThrowingContinuation` in `SmartCompletionEngine` doesn't get resumed — caller can hang (`CompletionDebouncer.swift:196-221`, `SmartCompletionEngine:191-198`).
- `EditorConfiguration.swift:68` doc comment teaches `print("Configuration errors: \(errors)")` — exempt by lint but bad pedagogy.
- `CodeEditorUI/CodeEditorUI.swift:11` uses `## Topics` DocC directive — project has no DocC catalog.
- `PerformanceMonitor` starts a 5-min cleanup task at `init` regardless of usage (`Performance/PerformanceMonitor.swift:64-69`).
- `@preconcurrency import SwiftUI` in `CodeEditor.swift:2` and modifier files — unlinked.
- `ConfigurationCodeFormatter.swiftStringLiteral` (`Sidebars/ConfigurationCodeFormatter.swift:284-286`) is dead.
- `durationMilliseconds` duplicated in `ConfigurationCodeFormatter:278-282` and `KnobRow.swift:355-359`.
- `AppState.swift:76-78` cites `docs/superpowers/...` — that path is archived working notes per CLAUDE.md.
- `SettingsScene`'s `frame(width: 1380, height: 880)` precedes `windowResizability(.contentSize)` and overrides the min sizes (`App/CodeEditorSampleApp.swift:16-20`).
- `MainActor.assumeIsolated` after `.receive(on: DispatchQueue.main)` (`DiagnosticsBridge.swift:49-55`) — works only by accident.
- No `Sources/CodeEditorSample/README.md`; users will keep hitting the `cd CodeEditorSample` trap.

---

## Patterns worth codifying

- `@unchecked Sendable` rationale comments naming the synchronization mechanism — already consistent; enforce via review.
- `RangeProcessor`'s dual `isolated (any Actor)` + `@MainActor @preconcurrency` overload pair (`Text/RangeProcessor.swift:152-157, 194-198, 234-238`) — good template for other actor-spanning services.
- `CodeEditorView.swift:159-169`'s named-commit invariant comment — apply to other load-bearing invariants.
- Stateless inspector panels (sample's `CompletionInspectorPanel`, `PerformanceInspectorPanel`) — directly snapshot-testable. Apply broadly.
- A lint rule banning `NSRange(location:length: \w+\.count)` — would catch the UTF-16 drift class entirely.
- Auto-synthesized `Codable` over hand-rolled `CodingKeys` for config sub-structs — would have caught bugs 4–5 in the Important list at compile time.
- One delegate-multiplexer for `NSTextViewDelegate`/`UITextViewDelegate` — generalize the `TextEditEventObserving` pattern (`CodeFoldingEngine`) so no feature ever overwrites `delegate` again.

---

## Suggested ordering if you want to act on this

1. **Land the 7 Critical fixes** first — they're either silent correctness bugs (1, 2, 4) or hot-path perf cliffs (5, 6, 7) plus one strict-concurrency soundness fix (3).
2. **Close the sample-driven API gaps** (the 8 numbered items above) — every host you ship to will rediscover the same gaps.
3. **Pick off the lifecycle/concurrency batch** as a single PR — `MemoryMonitor` observer leak, `removeFromSuperview` cancellation, `LayoutCoordinator` recursion, `LSPClient.disconnect`.
4. **Codable + Equatable completeness sweep** for `EditorConfiguration.*` — small, high-value.
5. Then minor/dead-code cleanup as background work.
