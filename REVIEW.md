# CodeEditorPlugin — Complete Code Review

Scope: 563 Swift files in `Sources/` + 225 test files (~33.7K LOC). Dispatched 8 parallel review agents covering Core/Text/Highlighting/Layout/Theming/LSP/Sample/Tests.

## Executive summary

The codebase is structurally sound and convention-compliant at the level lint catches: no `print()`, no `!` force-unwraps, no `#if os(macOS)`, no TextKit1 surface that lint should care about. But the review surfaced **a handful of real correctness bugs** and **substantial dead/aspirational infrastructure** that inflates the surface area without earning its keep. The two highest-leverage themes:

1. **TextKit2 invariants are well-guarded in the *new* code but contradicted by older "fallback" branches and a latent landmine (`ModernTextKit2Bridge`).**
2. **Tests pass too easily.** ~25–30 tests are tautological or have their assertions commented out — including the four "memory leak" tests that print warnings instead of failing.

---

## Critical (correctness bugs — fix before shipping)

### TextKit2 / Text pipeline
- **`Text/ModernTextKit2Bridge.swift:44-45`** — Sets `textLayoutManager.delegate = self` and `textViewportLayoutController.delegate = self`. This is exactly the bug `f3ce3358` fixed and the user-memory invariant forbids. The class is unreferenced; **delete it** or it will get re-enabled by mistake.
- **`Text/TextKitBridge.swift:134-148, 167-218, 282-287, 351-357`** — Five mutation methods call `beginEditing`/`endEditing` without wrapping in `NSTextContentManager.performEditingTransaction`. Will fire `NSTextContentStorageBreakOnEnumerateWhileEditing` if invoked during viewport layout or highlight enumeration.
- **`Text/LineGeometryEditHandler.swift:60-70`** — For pure insertions (`editedRange.length == 0`), computes `lineIndex` from `location - 1` (previous line). Geometry desyncs from text after insert-at-line-boundary.
- **`Core/CodeEditorView.swift:643`** — `delegate = nil` in `removeFromSuperview()` evades the `forbidden_text_view_delegate_assignment` SwiftLint rule (which matches `textView.delegate =` literally). View reuse breaks typing.

### Syntax highlighting
- **`SyntaxHighlighting/RegexSyntaxHighlighter+BuilderExtensions.swift:35,41,47`** — String/char/backtick regex patterns use `\\\\` inside `#"..."#` raw strings. Because raw strings don't process escapes, `NSRegularExpression` receives literal `\\\\.` (two backslashes + any char) instead of `\\.` (escape sequence). **Every language that uses `addStrings(double:true)` is silently broken.** Inputs like `"hello \"world\""` match only the empty `""` between the opening quote and first escape.
- **`Languages/Data/SqlLanguageDescriptor.swift:16-23`** — Keywords are uppercase but the matching rule is case-sensitive. Lowercase SQL (the common case) gets zero keyword highlighting.
- **`SyntaxHighlighting/BackgroundHighlightingActor.swift:23-82`** — Fallback path uses case-insensitive substring search with no word boundaries. `int` matches inside `printf`, `if` inside `notify`. Reachable via `MemoryManagementCoordinator.createAsyncHighlighter`.

### Features
- **`Features/SmartEditing/MultiCursorEditor.swift:49,53,65,94,102`** — `NSRange(location:0, length: text.count)` uses Swift Character count where NSRange requires UTF-16. Wrong for any document containing emoji / non-BMP characters.
- **`Features/CodeFoldingEngine.swift:40-45`** — `LineFoldStorage.storageUpdated` is called with `editedRange.length + changeInLength`. NSTextStorage's `editedRange.length` is already post-edit; adding `changeInLength` double-counts. Folds drift after edits.
- **`Layout/CodeEditorContainerView.swift:213-225`** — Unreachable `else` branch on a `@MainActor` class would infinite-loop into `self.layout()` via Task.
- **`Features/SearchReplaceEngine.swift:54-57, 289-299, 469-471`** — Per-call `options` overwrite engine defaults; `searchBackward` plain-text branch reverses results without reversing the search start; replacing the current match decrements `currentSearchIndex` incorrectly, causing findNext to skip ahead by two.

### LSP / completion / annotations
- **`LSP/LSPCompletionProvider.swift:360-386`** — `convertLSPRangeToNSRange` accumulates `Character` count where UTF-16 is required by LSP spec. Inverse function (`convertPositionToLineCharacter:217-224`) correctly uses UTF-16. Asymmetric → completion edits land at wrong offsets in files with emoji.
- **`LSP/Transport/ProcessTransport.swift:121-165 + deinit 269-276`** — On SIGTERM ignored, escalates to SIGINT but never to SIGKILL and doesn't `waitUntilExit()`. Orphans misbehaving servers.
- **`LSP/Transport/WebSocketTransport.swift:70-89`** — `RemoteLSPConfiguration.enterpriseServer` configures pinning, minimum TLS 1.3, certificate validation, OCSP — **none are applied**. URLSession uses system defaults with no delegate. **Security correctness bug.**
- **`LSP/Transport/WebSocketTransport.swift:281-312`** — `attemptReconnection` recurses without bound; with `maxReconnectAttempts=10` (enterprise) the actor's stack grows proportionally.
- **`LSP/LSPProcessManager.swift:106-122`** — Busy-polls stdout at 1ms (1000 wake-ups/sec/server).
- **`Annotations/AnnotationsContentView.swift:96`** — Casts `Annotation` (struct) to `LineAnnotation` (protocol with `set` requirement). The cast always fails; the badge view is never instantiated.
- **`Annotations/Annotation.swift:97`** — Silently substitutes `NSRange(location: NSNotFound, length: 0)` when conversion fails. Downstream consumers will crash on layout math.

### Theming
- **All sub-palette decoders (`Theming/{EditorColors,BorderColors,ChromeColors,ElementStates,HintColors,IconLevels,PredictiveColors,ScrollbarColors,StatusPalette,TextLevels,VCSPalette}.swift`)** — Every leaf hard-codes `let appearance: Theme.Appearance = .dark` before pulling fallback colors. **Light themes that omit any key get the dark fallback color.** The 11 bundled light variants in `Resources/` are all at risk.
- **`Core/CodeEditorView+Theme.swift:53-54`** — Indexes `theme.style.players[0]` without checking emptiness. `ThemeStyle.init` decodes `players` with `try? ... ?? []`, so an empty list traps on every `apply(theme:)`.

### Tests
- **`Tests/CodeEditorPluginTests/MemoryLeakTests.swift:44-49, 79-82, 110-113, 199-201, 223-226`** — Four "memory leak" tests **print warnings instead of asserting**. The XCTAssert is even commented out. The four most important leak detectors in the suite are guaranteed-green.
- **`Tests/CodeEditorPluginTests/TestMemoryOptimizer.swift:6-21`** — `@unchecked Sendable` singleton with mutable dict, no lock. Unsafe under `--parallel` test runs.
- **`SwiftUIEnvironmentConfigurationTests.swift`** — ~14 tests whose only assertion is `XCTAssertNotNil(editor)` where `editor` is a non-optional value. Compile-time pass-through.

---

## High (design / API ergonomics — worth addressing)

### Pipeline duplication / dead architecture
- **Two parallel document systems** (`Core/Actors/DocumentStateActor` vs `Documents/EditorDocuments`) tracking text/language/dirty independently.
- **Three highlighting pipelines** (`HighlightingStrategyExecutor`, `RegexIncrementalRangeQueryParser`, `BackgroundHighlightingActor`/`HighlightingActor`) each carrying their own `RegexSyntaxHighlighter` and keyword tables. `LanguageRegistry.swift:193-443` defines 10 `*LanguageProvider` structs that **are never registered**.
- **Two range validation pipelines** in `Text/` (`SinglePhaseRangeValidator`, `ThreePhaseRangeValidator`) both wired to a placeholder `TokenSystemValidator` that returns `.success` unconditionally (`Text/TokenSystemValidator.swift:25-31`).
- **`Text/TextKit2RenderingOptimizer.swift:13-19`** — Self-described "placeholder fragments / simulated work" exposed via `@Published` metrics through `MemoryManagementCoordinator`.

### Broken-by-design utilities
- **`Utilities/AsyncOperationManager+DebouncingExtensions.swift:41-86`** — Every debounced caller `await`s the result; the next call clears the result dict. Only the *last* caller in a burst gets a value, the rest throw `noResult`.
- **`Utilities/AsyncOperationManager+SchedulingExtensions.swift:43-80`** — Priority queue is metadata-only; busy-waits on actor; doesn't actually cancel running tasks.
- **`Utilities/AsyncOperationManager+ThrottlingExtensions.swift:42-67`** — Shares `debounceResults` keys with the debouncer; same-key collisions silently clobber.
- **`Utilities/CoordinateSystemHelper.swift:148,160,185,207`** — Reads `textView.layoutManager` and `textView.textContainer`, which coerces the view to TK1 mode (the TK1 trap documented in `CodeEditorView.swift:207-213`). Unreferenced; **delete**.

### API surface issues
- **`Configuration/EditorConfiguration+PerformanceExtensions.swift:108`** — `Performance` is declared `Sendable` but stores a non-`Sendable` `@MainActor` class. Strict-concurrency violation. Also wrong location: runtime services belong in `EditorRuntimeDependencies`.
- **`Core/AsyncOperationErrors.swift:404-472`** — 5 of 7 `RecoveryStrategy.Action` cases just `throw error`. API promises rich recovery, delivers retry-or-rethrow.
- **`Core/Actors/CacheCoordinatorActor.swift:36-37, 98`** — `currentMemoryUsageMB` is never incremented; the global-eviction threshold is dead.
- **`Core/EditorRuntime.swift:97-100`** — `update(dependencies:)` destroys `featureDependencies` unconditionally.
- **`Documents/EditorDocuments.swift:175-191`** — `tabsBinding` setter discards mutations to `TabModel` fields (only preserves identity).
- **`LSP/LSPManagerTypes.swift:198-206`** — `id: String { "\(languageId)-\(UUID().uuidString)" }` — fresh UUID per read. Defeats SwiftUI list diffing.
- **Sample-app signals re framework gaps:** `AnnotationsDataSource` should be `@MainActor`; `.onTextChange`/`.onCommandClick` callbacks should be statically `@MainActor` so consumers don't need `MainActor.assumeIsolated` (`Sample/App/WindowBody.swift:58-66`); `EditorController` should expose `selectMatch(_: ProjectSearchResult)` natively (`Sample/Workspace/EditorController+SelectMatch.swift:11`); `display.useRangeStoreHighlighting` and `performance.usesRangeBasedHighlighting` collide (`Sample/KnobPanels/{Display,Performance}KnobsSection.swift`).

### Performance
- **`Theming/Internal/SyntaxColorLookup.swift:17`** — Per-token dotted-suffix-stripping loop with no memoization, called from the highlight hot path. Cache per `(themeID, tokenName)`.
- **`Utilities/TextMetricsCalculator.swift:14-28`** — Builds a throwaway `NSLayoutManager + NSTextContainer + NSTextStorage` for every `calculateLineHeight` call. Used by gutter, minimap, bridge, line-number helper.
- **`SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift:32-51`** — Language map rebuilt per highlighter init; multiple components each construct their own. Make it `static let`.
- **`Text/TextKitBridge.swift:386-427`** — `visibleRange` enumerates fragments from document start instead of from `textViewportLayoutController.viewportRange.location`. Per-keystroke gutter update is O(document).
- **`Text/Parsing/{LanguagePatternDetector,SyntaxTreeParser,BracketMatcher,WordBoundaryFinder}.swift`** — All use `text.index(text.startIndex, offsetBy:)` per step → O(n²); also emit NSRanges using Character offsets where UTF-16 is required.
- **`Workspace/MacOSWorkspaceFileManager.swift:89-99`** — Polls workspace every 2s with recursive `enumerateFiles`. Should be FSEvents-driven (the comment admits this).
- **`Completion/CompletionDebouncer.swift:287-357`** — `@Published` mutations on every typing event, even with no UI observer.

---

## Medium (smells, conventions, dead code)

- **TextKit1 commentary contradicts CLAUDE.md.** `TextKitBridge.swift` headers proclaim TK2-only but document three live TK1 fallback paths triggered by NSRulerView coercion (lines 74-81). Either prove coercion can no longer happen and delete the branches, or update CLAUDE.md.
- **CSS/HTML/Dockerfile keywords are misclassified** as `keywords` (property/tag names treated as language keywords), beating the property-position rules due to descending priority sort.
- **Python descriptor** declares `"""` as block comment markers (it's a string literal); duplicated in `highlightingRules`. HTML and other languages also duplicate comment rules.
- **JS extension drift:** `SyntaxHighlightingCoordinator.swift:230` documents `["js","mjs","cjs"]`; descriptor returns `["js","jsx","mjs"]`. `.h` is silently routed to C, not C++.
- **iOS gaps:**
  - `PlatformAnimationTransaction.disableAnimations` is a no-op on UIKit (`Platform/PlatformAnimation.swift:190-204`).
  - `CodeEditorView+Theme.swift:80-81` discards `selectionColor` on iOS (`_ = selectionColor`).
  - `Layout/CodeEditorContainerView+Keyboard.swift:10-41` registers block-based observers but `deinit` calls `removeObserver(self)` (block observers require token-keyed removal).
  - Sample: no workspace tree or LSP on iOS (`Sample/App/AppState.swift:43-48`); `PerformanceSampleCoordinator.swift:62` uses deprecated `UIScreen.main`.
- **`Layout/ContentView.swift`** (~340 LOC) and `Layout/EditorContentView` are allocated but never installed in the view tree. Vestigial.
- **`Annotations/AnnotationsContentView` + `Annotation`** dead-code chain (from Critical) implies the entire annotation rendering surface is unused at runtime — worth confirming.
- **`Features/SmartEditing/{AutoBracketingEngine,SmartIndentationEngine,SmartSelectionExpander}.swift`** — config keys (`autoInsertQuotes`, `wrapSelection`) silently ignored; `"case"` indent rule matches inside `useCase`; word→line→bracket selection expansion doesn't actually progress.
- **`Core/Actors/FileSystemActor.swift:92-96`** — rename notification reports `renamed(from: url.path, to: url.path)` — both ends identical.
- **`Core/EditorEventPublisher.swift:120-127`** — Task chain holds strong reference to previous task; unbounded growth under heavy publish.
- **`Configuration/CodableColor.swift:30-34`** — Fallback alpha `0.1` (almost invisible) where `1.0` is intended.
- **`Configuration/EditorConfiguration+BehaviorExtensions.swift:138`** — `Set<Character>` encoded as `String(set)`; iteration order non-deterministic.
- **`Extensions/String+Extensions.swift:18-42`** — `data(at:limit:using:chunkSize:)` always divides byte offset by 2; only correct for UTF-16 but accepts `.utf8`.
- **`PlatformColors.swift:169,310`** — `NSColor.controlAccentColor.withAlphaComponent(0.15)` without `.usingColorSpace(.sRGB)` — catalog colors don't round-trip alpha cleanly.
- **`Platform/ObserverStore.swift:32-36`** — `cleanup()` defined but never called from deinit.
- **`Platform/PlatformServiceExtensions.swift`** — Filename violates `+Extensions` convention.
- **`LSP/RemoteLSPConfiguration` + `LSPClientRegistry.setupDefaultConfigurations`** — Global default registrations fire on every host even when LSP is disabled.
- **Performance test prints (`PerformanceRegressionTests.swift`, `ComprehensivePerformanceTests.swift`, `LargeFileHighlightingBenchmarkTests.swift`)** — multiple `print()` calls that should be `CrossPlatformLogger`.
- **Sleep-based test waits** — `IntegrationTests.swift` has 8 `Task.sleep`s; `SwiftUICoordinatorTests.swift:259-264` uses 1.5–2s sleeps. Replace with `XCTestExpectation`/event-driven waits.

---

## Low / nits

- `Text/LineIndexCache.swift` — whole file deprecated, zero callers; delete.
- `SyntaxHighlighting/LanguageRegistry.swift:205-207` — `#if true … #endif`.
- `Layout/CodeEditorContainerView+Configuration.swift:157-166` — same `#if true` scaffold.
- `Platform/module.swift` — two-line dead comment file.
- `SyntaxHighlighting/RegexSyntaxHighlighter.swift:136-138` — empty `deinit`.
- `Models/FoldableRegion.swift` — redundant `internal` keywords.
- Several `@preconcurrency import AppKit/UIKit` (e.g. `CodeEditor+CoordinatorsExtensions.swift:4-7`) likely hide real Swift 6 warnings.
- `Tests/CodeEditorPluginTests/CodeEditorContainerViewTests.swift` — 16 tests guarded with `XCTSkip` based on a non-failable initializer; skip ladder is theatre.
- `Tests/CodeEditorPluginTests/PerformanceBenchmarkTests.swift:11-22, 73-77` — 3 tests permanently `XCTSkip`. `PerformanceConfigurationTests.swift:182-185` — same pattern.

---

## Cross-cutting observations

- **Conventions are well-enforced** for what lint catches: zero `print()` calls in production, zero `!` force-unwraps, zero `#if os(macOS)` regressions, all extension files use `+Extensions`. The custom `no_print_statements` rule's `///` exemption is intact. This is genuinely good hygiene at scale.
- **The TextKit2 + theming work in recent commits is correct.** `CodeEditorView+Theme.swift`'s "stamp themed foreground onto storage" pattern is the right TextKit2 architecture. `f3ce3358`'s viewport-delegate fix is well-tested by `TextRenderingVisibilityTests`. The risks are in older code that hasn't been deleted (`ModernTextKit2Bridge`, TK1 fallbacks) and in the symmetric test that doesn't exist (`textLayoutManager.delegate === textView`).
- **The test suite is significantly weaker than its file count suggests.** Conservative count of always-green tests: ~25–30. Recommended single biggest win: a SwiftLint custom rule rejecting `XCTAssertNotNil(<non-optional>)`.
- **Aspirational infrastructure is the dominant source of risk.** `AsyncOperationManager` (debounce/throttle/schedule/batch all broken), `CoordinateSystemHelper`, `TextMetricsCalculator` advanced APIs, `ModernTextKit2Bridge`, `LanguageRegistry` providers, `TokenSystemValidator`, `TextKit2RenderingOptimizer`, two-of-three highlighting pipelines, dual document systems, dual range validators — all reachable as public API, all either unused or returning placeholder values. **A pruning pass would meaningfully reduce both risk and maintenance burden** without losing any working functionality.
- **iOS support is real for editing, partial for theming, stub for LSP/workspace.** The single-file `iOS/` directory in the sample understates the cross-platform code in `Documents/`, `EditorActions/`, `KnobPanels/`, etc. — but iOS gaps in selection color, animation transactions, keyboard-observer cleanup, and workspace/LSP support are noticeable.

---

## Suggested first 10 fixes (impact × cost)

1. Fix the regex string-pattern escapes in `RegexSyntaxHighlighter+BuilderExtensions.swift:35,41,47` — silently broken in most languages.
2. Thread `appearance` through theme palette fallbacks — light themes are silently dark on any missing key.
3. Apply TLS pinning / min-TLS settings in `WebSocketTransport` — security correctness.
4. Restore real assertions in `MemoryLeakTests.swift`.
5. Fix `LSPCompletionProvider.convertLSPRangeToNSRange` UTF-16 math.
6. Delete `ModernTextKit2Bridge.swift` (latent regression of `f3ce3358`).
7. Lowercase keyword variants or `.caseInsensitive` flag for SQL.
8. Wrap `TextKitBridge` mutations in `performEditingTransaction`.
9. Replace `LSPProcessManager` 1ms poll with `readabilityHandler`.
10. Add `selectMatch(_:)` to `EditorController` and make data-source protocols `@MainActor` — direct API-ergonomics signal from the sample.
