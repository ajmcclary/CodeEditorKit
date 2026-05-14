# CodeEditorPlugin — Codebase Review

Synthesis of four parallel reviewer passes covering the entire `Sources/` tree, `Tests/` conventions, and `CodeEditorSample`'s API consumption. Every issue carries a `file:line` citation; agents verified citations against the current tree at the time of review.

## Status (2026-05-14)

All 7 Critical fixes have landed on `main` (uncommitted). Build is green, SwiftLint clean (0 violations), `swift test` shows no regressions — the one observed failure (`AnnotationTests.testAnnotationTextKit2Integration: "TextKit2 layout manager not available"`) reproduces on bare `main` and is pre-existing. The `EditorStatusBarSnapshots` parallel-runner SIGSEGV/SIGBUS crashes also reproduce on bare `main` (Swift-Testing helper launching XCTest snapshot suites in parallel).

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
- `AnnotationTests.testAnnotationTextKit2Integration` fails with "TextKit2 layout manager not available" — XCTest setup issue.
- `EditorStatusBarSnapshots` crashes (signals 10/11) under `--parallel` — Swift-Testing helper spawning XCTest snapshot suites concurrently.



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
