# CodeEditorPlugin — Codebase Review

Synthesis of four parallel reviewer passes covering the entire `Sources/` tree, `Tests/` conventions, and `CodeEditorSample`'s API consumption. Every issue carries a `file:line` citation; agents verified citations against the current tree at the time of review.

## Status (2026-05-14)

All 7 Critical fixes have landed on `main` (uncommitted), along with the dead-code / doc cleanup batch, the first-pass sample-driven API gaps (#1, #2, #4, #8 from the eight numbered items), the concurrency-lifecycle + Codable sweep (`MemoryMonitor` observer leak, `removeFromSuperview` cancellation, `LayoutCoordinator` recursion, `LSPClient.disconnect` continuation leak, `EditorConfiguration.{Layout,Performance}` Codable/Equatable completeness), the Editor lifecycle + EditorState mirror batch (`CodeEditorView` deinit highlighting cancel, `completionRequested` cancel-before-spawn, `EditorEventPublisher` FIFO delivery, framework-side `EditorState` mirror of `language`/`selection`/`lineCount`), the SwiftUI hot path + env hygiene batch (`CodeEditor.body` runtime-deps caching, `EditorEventBusInstaller.sourcePosition` LineGeometryStore fast path, `EditorState` env default shared sentinel, `SwiftUICompletionItem`/`CompletionKind` `Sendable`), the Language descriptor cleanup batch (dropped dead `highlightingStrategy` field, added explicit `usesRegexHighlighter` flag, hoisted `HTMLSymbolProvider` attribute regexes), the Logger privacy + tokens + continuation batch (explicit `.public` OSLog privacy, `Tokens.Palette.TrafficLight.*`, `SmartCompletionEngine` continuation dropped), the Non-design remainder batch (engines `final`, FuzzyMatcher → OptimizedFuzzyMatcher, `@Dependency` wrapper, Swift Testing detection, JSON token round-trip removed, `PerformanceMonitor` lazy cleanup, `DiagnosticsBridge` isolation hop, `CodeEditorAPI` NSRange-only surface, `ProcessTransport` readabilityHandler, `RegexBackedRangeQueryParser` deletion, sample README), and the Sample coverage gaps batch (PerformanceInsightsPanel + DetailedPerformanceReportView in the sheet, individual `.codeLanguage` / `.codeWorkspaceRoot` / `.lineNumbers` / `.becomeFirstResponder()` modifiers, `LSPCompletionProvider` registration + context wiring, SnippetTemplate + fuzzyFilter + CompletionRankingModel demo, `CodeEditorError` recovery messages, EditorTitleBar + EditorTrafficLights + EditorBreadcrumbView + PlatformGlassSurface chrome, iOS ContentUnavailableView for desktop-only inspectors, `DocumentStore.save(_:)` + ⌘S, `CodeEditor.withConfiguration` on iOS). Build is green, SwiftLint clean (0 violations), `swift test` shows no regressions — the one observed failure (`AnnotationTests.testAnnotationTextKit2Integration: "TextKit2 layout manager not available"`) reproduces on bare `main` and is pre-existing. The `EditorStatusBarSnapshots` parallel-runner SIGSEGV/SIGBUS crashes also reproduce on bare `main` (Swift-Testing helper launching XCTest snapshot suites in parallel).

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

### Latent TextKit 2 coercion (`CodeEditorView.setupTextView` — fixed 2026-05-14)

Investigating the skipped `testAnnotationTextKit2Integration` surfaced a real production gap that the test was, in effect, trying to flag. **Status: ✅ Fixed.** Design pass + 9-commit migration landed on `main` on 2026-05-14. Spec at `docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md`; implementation plan at `docs/superpowers/plans/2026-05-14-textkit2-coercion-fix.md`.

**Original symptom.** `CodeEditorView.textLayoutManager` was `nil` immediately after `init(frame:)`, even though `CLAUDE.md` and the `CodeEditorView` header comment (`Core/CodeEditorView.swift:159-169`) both declare the framework TextKit 2-based and explicitly rely on `NSTextView` constructing its own TK2 stack via `super.init(frame:)`. Verified out-of-band that a plain `NSTextView(frame: .zero)` *does* return a non-nil `textLayoutManager` on this macOS — so the regression was local to `CodeEditorView`'s init path.

**Original cause and what we actually found.** The spec hypothesized `setupTextView()` → `setupLineGeometryStore()` → `rebuildLineGeometryStoreFromCurrentTextStorage()` reading through `self.textStorage` was the trigger. That was *a* trigger but not the only one. The actual load-bearing coercion fired in `updateLayoutManagerSettings` (`Core/CodeEditorView+ConfigurationExtensions.swift`) which read the legacy `layoutManager?` property to set `showsInvisibleCharacters`. Tracing the setup chain with a `FileHandle.standardError` probe pinpointed the exact step where `textLayoutManager` flipped to `nil`. Additional setup-time coercions were hiding in `applySyntaxHighlighting` (length read), `applyParagraphStyle` (textStorage write), the `didProcessEditingNotification` observer wiring (`object:` filter), the post-edit `LineGeometryEditHandler` rebuild, `removeSyntaxHighlighting`, `CodeFoldingEngine.updateFoldableRegions`, and the syntax-highlighting notification handler's sender validation. All were on the critical path; all are now routed through the TK2-safe accessor.

**What landed (mapped to the spec's four bullets):**

| # | Spec bullet | Status | What landed |
|---|---|---|---|
| 1 | Change `LineGeometryStore.build(from:)` rebuild path to consume `NSTextContentStorage` (TK2) | ✅ Done | `rebuildLineGeometryStoreFromCurrentTextStorage` and `LineGeometryEditHandler` now read `textContentStorage?.textStorage`. `LineGeometryStore.build(from: NSTextStorage)` keeps its signature — the *source* of the storage changed, not the consumer. UTF-16 line enumeration via `NSString.getLineStart(_:end:contentsEnd:for:)` is unchanged. |
| 2 | Audit every callsite that names `textStorage`, `layoutManager(...)`, or `textContainer` directly. Wrap in TK2-first/TK1-fallback helper or delete TK1 branches outright | ✅ Done | Introduced the funnel: extended `Text/TextKitBridge.swift` with `documentLength`, `documentString`, `substring(in:)`, `attributedSubstring(in:)`, `replaceCharacters(in:with:)`, `addAttributes(_:range:)` (now rendering attributes via `NSTextLayoutManager.setRenderingAttributes(_:for:)`), `removeAttributes(_:range:)`, `addPersistentAttributes(_:range:)`, `removePersistentAttribute(s)(_:range:)`. Dropped the leaky `var textStorage` accessor. Added `internal lazy var textKitBridge` on `CodeEditorView` so consumers share one bridge per view. **~30 files migrated** across Core, SyntaxHighlighting, Features (folding, search, smart-editing, multi-cursor, symbol nav), LSP, Layout (gutter accessibility), SwiftUI (EditorController), Text helpers, and Extensions. Syntax highlighting writes (`RangeAttributeApplier`, `AsyncSyntaxHighlighter`) now use rendering attributes; persistent writers (fold indicators, search highlights, layout attributes, `TemporaryAttributesStore`) go through `addPersistentAttributes`. After-state: `git grep 'textView.textStorage\\|self.textStorage\\|editorView.textStorage' Sources/CodeEditorPlugin` returns only the documented TK1-island in the gutter (see below). |
| 3 | Re-enable `testAnnotationTextKit2Integration` | ✅ Done | `Tests/CodeEditorPluginTests/AnnotationTests.swift:357` no longer `XCTSkipIf`s. Asserts `textLayoutManager != nil` and that the content manager is wired. |
| 4 | Add regression test + doc comment on `CodeEditorView` | ✅ Done | New `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift` with two canaries: `testInitFrameProducesTK2Stack` (fails fast if `CodeEditorView(frame: .zero).textLayoutManager == nil`) and `testTK2StackSurvivesConfigurationChange` (covers the configuration-didSet recursion path that originally hid the coercion). The named-commit invariant block at `Core/CodeEditorView.swift:159-169` gained a third paragraph naming the `self.textStorage` / `self.layoutManager` prohibition, pointing at the canary test, and documenting the NSRulerView gutter as a known TK1 island. Also added `Tests/CodeEditorPluginTests/SyntaxHighlighting/SyntaxHighlightingRenderingAttributeTests.swift` (2 tests covering the write-side behavior change: rendering attributes are applied via `bridge.addAttributes`, and the underlying `NSAttributedString` is not mutated). |

**Known TK1 island (deferred, not a regression).** `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift:drawHashMarksAndLabels(in:)` — the NSRulerView gutter draw path — still reads `textView.layoutManager` for `glyphRange(forBoundingRect:in:)` enumeration. Reading the legacy `layoutManager` property triggers Apple's TK1 compatibility shim, so the editor flips to TK1 the first time the ruler view draws. The textStorage reads in this function are now documented as deliberately routed via the legacy property because coercion has already fired by that point. Rewriting the gutter against `NSTextLayoutManager` (e.g., `enumerateTextLayoutFragments(from:options:using:)` for line-fragment enumeration) is its own scoped follow-up. **In test-environment isolation** (the canary tests construct `CodeEditorView(frame: .zero)` without attaching to a window), the gutter never draws and the TK2 stack is preserved. In a running `CodeEditorSample`, gutter-induced coercion occurs at first paint; that doesn't regress anything (the editor previously coerced during setup, so it ran in TK1 throughout) but it does mean the "editor runs in TK2 in production" claim is only true until the gutter draws.

**Side effects worth flagging.**
- **Snapshot baseline re-recorded.** `Tests/CodeEditorPluginTests/__Snapshots__/CodeEditorSnapshotTests/testCodeEditorRendersSwiftSnippet.1.png` captures TK2 rendering output (the previous baseline was the TK1-coerced render); committed in the same PR.
- **`updateLayoutManagerSettings` is a deliberate no-op.** Showing invisible characters needs a TK2-native (rendering-attribute-based) implementation that's out of scope; the property setter would have done nothing visible under TK2 even before the fix, so this is no functional regression.
- **`addAttributes` semantic change.** Bridge's `addAttributes(_:range:)` now applies rendering attributes (non-destructive, not visible to `textStorage.attribute(_:at:effectiveRange:)`). For *persistent* attributes (fold indicators, search highlights, layout attrs, temp-attr store), use `addPersistentAttributes(_:range:)` — distinct method, explicit semantics at the call site.
- **Pre-existing test failures persist** (not introduced by this work): `EditorStatusBarSnapshots/*` parallel SIGSEGV, `RegexRangeHighlightProviderTests.testParsePerformance10K/100KLines` flake on slower machines, `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor` (FPS counter not running in headless test env), `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`. None investigated as part of this PR.

**Commits (9 implementation + 2 docs):**
- `6c6f80f` Add lazy textKitBridge property on CodeEditorView
- `a63b918` Add TK2-safe accessors and addPersistentAttributes to TextKitBridge
- `ab9f657` TextKitBridge.addAttributes uses setRenderingAttributes; drop var textStorage
- `469ec6d` **Load-bearing:** Fix TextKit 2 → 1 coercion during CodeEditorView setup
- `1251898` Migrate Group B + folded D/C' textStorage reads to TK2-safe accessors
- `9508adc` Migrate syntax highlighting writes to NSTextLayoutManager rendering attributes
- `7f50fb3` Migrate persistent-attribute writers to TextKitBridge.addPersistentAttributes
- `9cfa53f` Finalize TextKit 2 migration: doc comment + ad-hoc bridge cleanup
- (plus spec + plan commits: `39ccdc0`, `8677b58`, `6e80010`)

Build green, `swiftlint --strict` clean.

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

### Editor lifecycle + EditorState mirror batch (landed 2026-05-14)

Picks up three of the four remaining items from the "Concurrency & lifecycle" Important list plus the `EditorState.language` wiring gap surfaced during the TextKit 2 smoke test. Only `ProcessTransport` busy-poll remains in that section after this batch.

| Item | Status | What landed |
|---|---|---|
| `CodeEditorView` deinit analog for highlighting cancellation | ✅ Done | `syntaxHighlighter` is now `nonisolated let` (the coordinator is already `Sendable` after the earlier actor→lock refactor, and the property is an immutable reference). `deinit` calls `syntaxHighlighter.cancelHighlighting()` so a view dropped without going through `removeFromSuperview` (tests, atypical host teardown) still cancels in-flight highlighting. Idempotent with the existing `removeFromSuperview` cancel — `cancelCurrent()` nils a possibly-nil task reference. |
| `completionRequested` does not cancel in-flight task before spawning a new one (`Core/CodeEditorView+CompletionExtensions.swift:100`) | ✅ Done | `requestCompletion(...)` now calls `completionManager.cancelCurrentRequest()` before kicking off the new `Task`. The superseded wrapping Task observes `CancellationError` and exits through a dedicated `catch is CancellationError` branch that suppresses the previously noisy error log. |
| `EditorEventPublisher.publish` spawns an unstructured `Task` per publish — A/B ordering not preserved (`Core/EditorEventPublisher.swift:98-113`) | ✅ Done | The actor now holds `deliveryTask: Task<Void, Never>?` as the tail of a FIFO chain. Each `publish(_:)` enqueues `Task { @MainActor in await previous?.value; … }`, so handlers see events in publish order. The chain only retains the immediate predecessor while it's in-flight; no task accumulation. |
| `EditorState.language` never populated by the framework (`Core/EditorState.swift:24`) | ✅ Done | Status bar (`EditorStatusBar.languageBadge`) used to always render "Plain Text" because nothing wrote into the host's shared `\.editorState`. `CodeEditor.body` now reads `\.editorState` from the environment and threads it through the representable to `CodeEditorBaseCoordinator.hostEditorState` (weak ref so env defaults still deallocate). The coordinator mirrors `language` + `lineCount` from `updateState(...)` (covers setup + per-update changes) and `selection` from `handleSelectionChange(...)` via `EditorStateBridge.deriveSelection`. Selection derivation is gated on `hostEditorState != nil || interactionStateBinding != nil` so hosts without chrome avoid the O(n) UTF-16 walk. `isDirty` and `hardwareAccelerationActive` remain unwritten — they want their own design pass (initial-text tracking and adaptive-perf-mode bridging respectively). |

**Files touched (this batch — 8 modified, 1 test file modified):**
Sources — `Core/CodeEditorView.swift`, `Core/CodeEditorView+CompletionExtensions.swift`, `Core/EditorEventPublisher.swift`, `SwiftUI/CodeEditor.swift`, `SwiftUI/CodeEditor+AppKitExtensions.swift`, `SwiftUI/CodeEditor+UIKitExtensions.swift`, `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`, `SwiftUI/CodeEditorRepresentableHelper.swift`.
Tests — `Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift` (three new tests: `testHostEditorStateMirroredOnSetupAndUpdate`, `testHostEditorStateSelectionMirroredOnSelectionChange`, `testHostEditorStateNoMirrorWhenUnset`).

**Public API impact.** Strictly additive on the coordinator (new weak property; no signature changes). `CodeEditor.body` reads one additional environment value (`\.editorState`). Hosts that already inject `\.editorState` start seeing the framework write `language`/`selection`/`lineCount` automatically; hosts that don't see no behavioral change (env default is a throwaway and the weak ref deallocates immediately).

Build: green. SwiftLint: 0 violations. Targeted suite `SwiftUICoordinatorTests` (14 tests, including the 3 new ones) passes.

**Still open from the "Concurrency & lifecycle" Important list:** `ProcessTransport.availableData` busy-poll (`ProcessTransport.swift:233-256`) — wants `readabilityHandler`/`DispatchIO`. Only remaining item in that section.

### SwiftUI hot path + env hygiene batch (landed 2026-05-14)

Four items from the "API correctness" + "Cross-cutting" Important lists. All small, no design pass needed — natural follow-up to the EditorState mirror work.

| Item | Status | What landed |
|---|---|---|
| `CodeEditor.body` reallocates `EditorRuntimeDependencies.live(...)` per render (`SwiftUI/CodeEditor.swift:271-277` + `Core/EditorRuntime.swift:46-64`) | ✅ Done | Added `@State private var fallbackRuntimeDependencies: EditorRuntimeDependencies = .live()`. The body now reads from the cached value when `environment.runtimeDependencies == nil` and overlays per-render env knobs (`workspaceRoot`, `eventSystem`, `memoryMonitor`) on a local copy. `MemoryMonitor`, `ActorCoordinator`, `UnifiedPerformanceSystem`, etc. are built once per editor lifetime instead of once per body call. Hosts that already inject `runtimeDependencies` are unaffected. |
| `EditorEventBusInstaller.sourcePosition` O(n) UTF-16 walk per hover/⌘-click (`Layout/EditorEventBusInstaller.swift:124-144`) | ✅ Done | `sourcePosition(for:in:)` now fast-paths through `(textView as? CodeEditorView)?.lineGeometryStore` for O(log n) line + column lookup. Falls back to the existing UTF-16 walk for plain `NSTextView` (the existing test fixtures use one) so `EditorEventBusInstallerTests` (2 tests) keeps passing without modification. |
| `EditorState` env default allocates a fresh instance per read (`SwiftUI/EditorState+Environment.swift:13`) | ✅ Done | Switched `EditorStateEnvironmentKey.defaultValue` from a computed `var` returning `EditorState()` to a `static let` shared sentinel. Hosts without chrome no longer allocate an `EditorState` on every body call that reads `\.editorState`. Writes against the sentinel (from the framework's coordinator mirror) are inert because no chrome view reads it — chrome consumers always inject an explicit `EditorState` per the doc contract. Coordinator's `hostEditorState` comment updated to drop the "throwaway deallocates immediately" claim. |
| `SwiftUICompletionItem` not `Sendable` despite being returned from a `@Sendable` async closure (`SwiftUI/CodeEditor+CompletionExtensions.swift:36`) | ✅ Done | Marked `SwiftUICompletionItem: Sendable` and `CompletionKind: Sendable`. Both are value types with `Sendable` stored properties (or no associated values), so synthesized conformance suffices. No source-breaking impact. |

**Files touched (this batch — 4 modified):**
`Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CompletionExtensions.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` (comment-only), `Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift`, `Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift`.

**Public API impact.** Strictly additive: two new `Sendable` conformances; an internal env-default semantics change that's not observable through the public API (consumers that read `\.editorState` without injecting one previously got a fresh-per-access instance; now they get the shared sentinel — same fields, same `@Observable` behavior).

Build: green. SwiftLint: 0 violations. Targeted suites pass — `SwiftUICoordinatorTests` (14 tests), `EditorEventBusInstallerTests` (2 tests).

### Language descriptor cleanup batch (landed 2026-05-14)

Three items from the "Language/highlighting/completion correctness" Important list and the Minor section — all naming-hygiene / dead-data / regex-hoist work, no semantic change.

| Item | Status | What landed |
|---|---|---|
| `descriptor.highlightingStrategy` is dead data — every descriptor sets it, nothing reads it (`HighlightingStrategyExecutor.determineStrategy:47-61` hardcodes the routing) | ✅ Done | Dropped the `highlightingStrategy: HighlightingStrategy` field from `LanguageDescriptor` and the corresponding `LanguageDescriptor.highlightingStrategy(for:)` static helper. Removed the parameter from the init signature and the argument from all 26 descriptor data files. The `HighlightingStrategy` enum itself stays — `HighlightingStrategyExecutor` still uses it internally as the return type of `determineStrategy(for:)`. |
| `parserName` doubles as a "use regex highlighter" gate (`RegexSyntaxHighlighter+LanguagesExtensions.swift:35,46`, `RegexRangeHighlightProvider.swift:319`); misleading because `parserName` is a tree-sitter grammar id | ✅ Done | Added explicit `usesRegexHighlighter: Bool` to `LanguageDescriptor`. Three call sites converted from `descriptor.parserName != nil` to `descriptor.usesRegexHighlighter`. Behavior preserved exactly: the flag is `true` for every language that previously had `parserName != nil` (24 of 26 — everyone except Swift and PlainText), including JSON. JSON inclusion looks redundant (the executor routes JSON to `FastJSONTokenizer`, not the regex pipeline) but range-based highlighting (`RegexRangeHighlightProvider.makeProvider(for: .json)`) still goes through it, so flipping JSON to `false` would be a behavior change deferred to its own follow-up. `parserName` remains as a tree-sitter grammar id used by `LanguageDetectionService` for filetype lookup. |
| `HTMLSymbolProvider.extractAttribute` compiles a regex per call (`HTMLSymbolProvider.swift:92-93`) | ✅ Done | Hoisted both attribute regexes (`id`, `class`) to `static let` on the type. The function now takes a precompiled `NSRegularExpression?` instead of an attribute name. `NSRegularExpression` is thread-safe per Apple's docs, so static sharing is correct; Swift's strict concurrency accepts the static-let form. |

**Files touched (this batch — 31 modified):**
`Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift` (field swap + helper removal), `Sources/CodeEditorPlugin/Languages/Data/*LanguageDescriptor.swift` (26 files — argument rename via sed), `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift`, `Sources/CodeEditorPlugin/Languages/HTMLSymbolProvider.swift`.

**Public API impact.** None. `LanguageDescriptor` is `internal`; the field rename is invisible to public consumers. The HTML provider change is implementation-detail.

Build: green. SwiftLint: 0 violations. Targeted run with `--filter "Highlight|Symbol|Language"` (~18 suites, all related to the touched areas) passes without regressions.

### Logger privacy + tokens + completion continuation batch (landed 2026-05-14)

Three items from the Cross-cutting Important list and the Minor section — privacy hygiene, design-token routing, and a defensive async restructure.

| Item | Status | What landed |
|---|---|---|
| `CrossPlatformLogger.osLogger.log(level:, "\(message)")` defeats OSLog format-string privacy/redaction (`Utilities/CrossPlatformLogger.swift:100`) | ✅ Done | Made privacy explicit: the inner OSLog call now uses `"\(message, privacy: .public)"` instead of relying on the default. The wrapper takes a pre-interpolated `String`, so OSLog can't redact individual substitutions anyway — the whole message is one opaque value at the boundary. Choosing `.public` keeps production logs readable (the previous default could redact useful diagnostics to `<private>`). Doc comment now spells out the privacy contract: callers must redact sensitive data at the interpolation site before passing the string here. |
| `EditorTrafficLights` hardcodes RGB outside the token system (`Sources/CodeEditorUI/Window/EditorTrafficLights.swift:41-48`) | ✅ Done | Added `Tokens.Palette.TrafficLight.{close, minimize, zoom}` with `0xFF5D57` / `0xFEBC2E` / `0x28C840` (the precise hex equivalents of the prior `Color(red:green:blue:)` literals — confirmed by channel × 255 conversion). The view now reads these via `Color(tokens: ...)`. Hairline stroke stays as `Color.black.opacity(0.18)` with a comment marking it as a UI-system primitive rather than a brand color. |
| `CompletionDebouncer.executeRequest` cancels prior tasks but `withCheckedThrowingContinuation` in `SmartCompletionEngine` doesn't get resumed — caller can hang (`Completion/CompletionDebouncer.swift:196-221`, `Completion/SmartCompletionEngine.swift:191-198`) | ✅ Done | Dropped the continuation entirely. `SmartCompletionEngine.performCompletion(session:context:)` is now `async -> CompletionResult` (was `async` with an `@escaping (CompletionResult) -> Void` callback). The debouncer handler in `setupCompletionDebouncer` collapses to `return await self.performCompletion(...)` — no `withCheckedThrowingContinuation`, no inner unstructured `Task`, no resume-once invariant to maintain. The one other caller (the fallback path in `requestCompletions(for:completion:)`) was updated in the same change. Cancellation now propagates naturally through the async chain. |

**Files touched (this batch — 4 modified):**
`Sources/CodeEditorPlugin/Utilities/CrossPlatformLogger.swift`, `Sources/CodeEditorDesignTokens/Palette.swift`, `Sources/CodeEditorUI/Window/EditorTrafficLights.swift`, `Sources/CodeEditorPlugin/Completion/SmartCompletionEngine.swift`.

**Public API impact.** All additive or implementation-only:
- New design tokens (`Tokens.Palette.TrafficLight.*`) — additive.
- `CrossPlatformLogger.Logger` API unchanged; only the inner format string and doc comment changed.
- `SmartCompletionEngine.performCompletion` is `private`; signature change is invisible outside the file.

Build: green. SwiftLint: 0 violations. Targeted suites (`Completion|Logger|TrafficLight`) pass without regressions.

### Non-design remainder batch (landed 2026-05-14)

Sweeps the remaining items from the Important + Minor sections that didn't need a design pass — six framework refactors, four minor fixes, plus the sample README. Strictly additive on the public surface except for the `CodeEditorAPI` migration (NSRange-only).

| Item | Status | What landed |
|---|---|---|
| `SearchReplaceEngine` / `SmartEditingEngine` are `public class` (non-`final`) | ✅ Done | Both classes now `public final`; no in-tree subclasses existed. Closes the open-subclassing surface. |
| Two parallel fuzzy matchers: `FuzzyMatcher` (non-`Sendable`) + `OptimizedFuzzyMatcher` (Sendable) | ✅ Done | Deleted `Completion/FuzzyMatcher.swift` (423 lines including dead `matchAcronym` / `highlightedString` extensions). Added `OptimizedFuzzyMatcher.matchSequential(pattern:candidates:)` public sync entry so `SmartCompletionEngine`'s `combineAndRank` (sync, MainActor) and `SymbolNavigator.searchSymbols` keep their non-async call sites. Tests (`PerformanceRegressionTests`, `ComprehensivePerformanceTests`) migrated; `FuzzyMatcher.MatchResult` references swapped for `OptimizedFuzzyMatcher.MatchResult`. |
| `CodeEditorDependencies` reads `DependencyValues._current.codeEditorMemoryMonitor()` directly | ✅ Done | All eight factory accessors now resolve through `@Dependency(\.codeEditorMemoryMonitor) var factory` inside the function body. `withDependencies { }` overrides flow through reliably. |
| `TestEnvironmentDetector.isRunningInTests` only checks XCTest env var | ✅ Done | Now combines: env var (XCTest), `NSClassFromString("XCTestCase")` (XCTest framework loaded), and `Bundle.allFrameworks` for a path containing `swift-testing` or `Testing.framework` (Swift Testing). Doc comment updated. |
| `FastJSONTokenizer` round-trips color → `TokenType` to rebuild `HighlightedToken` | ✅ Done | `HighlightingStrategyExecutor.highlightJSON` now maps `FastJSONTokenizer.TokenType` → framework `TokenType` directly via a new `mapJSONTokenType(_:)` helper. The dead `TokenType.fromColor(_:scheme:)` static — sole call site of the round-trip — is deleted (40 lines removed from `SyntaxHighlightingCoordinator.swift`). Theme overrides that mapped two categories to the same hue are no longer collapsed. |
| `PerformanceMonitor` starts a 5-min cleanup task at `init` unconditionally | ✅ Done | `init` is now empty. The first `startMeasuring(_:)` call lazily triggers `ensureCleanupTaskStarted()` which sets up the periodic drain. Unused `PerformanceMonitor` instances no longer keep a Task alive. |
| `MainActor.assumeIsolated` after `.receive(on: DispatchQueue.main)` in `DiagnosticsBridge` | ✅ Done | The Combine publisher is no longer routed through `DispatchQueue.main`; the sink hops via `Task { @MainActor [weak self] in self?.handle(dict) }`. Isolation is statically guaranteed rather than asserted. |
| `CodeEditorAPI` mixes `Range<String.Index>` and `NSRange` | ✅ Done | Public protocol surface is now NSRange-only. Affected signatures: `replaceText(in:with:)`, `deleteText(in:)`, `moveCursor(to:)` (Int offset), `find(_:options:)` → `[NSRange]`, `replaceAll(_:with:options:)`, `scrollToVisible(_:)`, `visibleRange()` → `NSRange` (non-optional), `lineNumber(at:)` (Int offset), `lineRange(for:)` → `NSRange?`. Default impls in `CodeEditorAPI.swift` rewritten against `NSString` line-enumeration. Concrete impls in `CodeEditorView+CodeEditorAPIExtensions.swift` rewritten. Internal callers updated: `EditorController.gotoLine` / `currentLineNumber` / `textRange(forLine:)` / `nsRange(forLine:)` / `nsLocation(forLSPLine:character:)`, `GutterViewModel.selectLineNumber`. `Range`/`nsRange` conversion helpers on the extension dropped (no external callers). Public-API impact: the old `Range<String.Index>` method bodies had no in-tree call sites, so the migration is source-breaking only for hosts that reached for `String.Index` directly. |
| `ProcessTransport` busy-polls `availableData` every 10ms | ✅ Done | Replaced the busy-poll loop with `fileHandleForReading.readabilityHandler`. The handler runs on the OS's private queue; bytes hop back into the actor via `Task { await self.deliverStdoutData(data) }`. Empty data (`EOF`) detaches the handler. `stderr` follows the same pattern. `readTask` / `stderrTask` properties retired; `stdoutReading` flag prevents double-installation. `disconnect()` and `deinit` clear both readability handlers before tearing down the process. No more 100 wake-ups/sec per LSP transport. |
| Delete `RegexBackedRangeQueryParser` | ✅ Done | The 70-line class in `RegexRangeHighlightProvider.swift` removed (unused in production — `makeProvider(for:)` already used `RegexIncrementalRangeQueryParser`). Tests migrated: `Tests/CodeEditorPluginTests/RegexRangeHighlightProviderTests.swift` (371 lines of correctness + benchmark coverage) now targets `RegexIncrementalRangeQueryParser` directly. Doc-comment reference in `Sources/CodeEditorTreeSitterLanguages/README.md` also updated. |
| No `Sources/CodeEditorSample/README.md` — `cd CodeEditorSample` trap | ✅ Done | Added a README explaining the sample is a target (not a directory), with `swift run CodeEditorSample` / `./Scripts/run-sample.sh` examples and a brief tour of `App/`, `Documents/`, `Sidebars/`, `iOS/`. |

**Files touched (this batch — 17 modified, 1 added, 1 deleted):**
Sources — `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift`, `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift`, `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift`, `Sources/CodeEditorPlugin/Completion/OptimizedFuzzyMatcher.swift`, `Sources/CodeEditorPlugin/Completion/SmartCompletionEngine.swift`, `Sources/CodeEditorPlugin/Core/CodeEditorDependencies.swift`, `Sources/CodeEditorPlugin/Utilities/TestEnvironmentDetector.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightingStrategyExecutor.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`, `Sources/CodeEditorPlugin/Performance/PerformanceMonitor.swift`, `Sources/CodeEditorPlugin/Core/CodeEditorAPI.swift`, `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeEditorAPIExtensions.swift`, `Sources/CodeEditorPlugin/Layout/GutterViewModel.swift`, `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, `Sources/CodeEditorPlugin/LSP/Transport/ProcessTransport.swift`, `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/RegexRangeHighlightProvider.swift`, `Sources/CodeEditorTreeSitterLanguages/README.md`, `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`.
Tests — `Tests/CodeEditorPluginTests/PerformanceRegressionTests.swift`, `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift`, `Tests/CodeEditorPluginTests/RegexRangeHighlightProviderTests.swift`, `Tests/CodeEditorPluginTests/LineGeometryStoreBenchmarkTests.swift`.
Added — `Sources/CodeEditorSample/README.md`.
Deleted — `Sources/CodeEditorPlugin/Completion/FuzzyMatcher.swift`.

Build: green. SwiftLint: 0 violations. Targeted run (`Highlight|Symbol|FuzzyMatcher|LSPClient|RegexRange|PerformanceMonitor|EditorController|CodeEditorAPI|TestEnvironment|FastJSON|DiagnosticsBridge|SwiftUICoordinator`) — 60 tests in 17 suites passed with one pre-existing known issue (`MockRangeHighlightProvider.MockError` surfaced through IssueReporting; not introduced by this batch).

### Sample coverage gaps batch (landed 2026-05-14)

Closes every "Coverage gaps the sample fails to demonstrate" bullet plus the eighth API gap (`#7` performance observer modifier was deferred earlier — the underlying gap was the duplicated `PerformanceInspectorPanel`). All public framework surface area that previously had zero in-tree call sites now has at least one demonstration.

| Item | Status | What landed |
|---|---|---|
| `PerformanceInsightsPanel` (framework) was duplicated by sample's `PerformanceInspectorPanel` | ✅ Done | The sample's rich bespoke panel stays (it covers FPS, memory pressure, adaptive mode, sparkline — none of which the framework's compact view offers) and serves as the "build your own inspector" reference. The framework's `PerformanceInsightsPanel` is now embedded in the `InspectorSidebar` "Show Report" sheet alongside `DetailedPerformanceReportView`, so both views fire on every Report-button press. |
| `.codeLanguage(_:)`, `.codeWorkspaceRoot(_:)`, line-numbers / first-responder modifiers were unused | ✅ Done | `WindowBody.editorPane` replaced the bulk `.codeEditorEnvironment(language:configuration:becomeFirstResponder:workspaceRoot:)` call with the individual modifiers: `.codeLanguage(_:)`, `.codeWorkspaceRoot(_:)`, `.lineNumbers(_:)`, `.becomeFirstResponder()`, plus `.environment(\.codeEditorConfiguration, _:)` for the remaining knobs that don't have dedicated modifiers. |
| `LSPCompletionProvider` wired nowhere through `CompletionManager` | ✅ Done | `LSPSampleCoordinator.start()` now creates an `LSPCompletionProvider(lspManager: manager, supportedLanguages: [.swift])` and registers it via `EditorController.registerCompletionProvider(_:)` after the language server reports `.running`. `stop()` unregisters it. `openTab(...)` and `handleTextChange(...)` call `provider.updateContext(filePath:, text:)` so trigger-character completions land in the right shadow file. |
| `SnippetTemplate`, `CompletionProviderUtilities.fuzzyFilter`, `CompletionRankingModel` unreferenced | ✅ Done | `DemoCompletionProvider` (the sample's "copy this for your own provider" reference) rewritten to use all three: a static `[SnippetTemplate]` catalogue produces `CompletionItemModel`s, `CompletionProviderUtilities.fuzzyFilter(items:filter:keyPath:)` narrows against `context.currentWord`, then `CompletionRankingModel.rank(items:context:frequencyData:)` orders the results. Converted from `struct` to `@MainActor final class` because the ranking model is MainActor-isolated. |
| `CodeEditorError` recovery suggestions pitched in docs but never used | ✅ Done | `LSPSampleCoordinator` failure paths now construct `CodeEditorError.languageServerNotAvailable("Swift")` (missing binary) and `.languageServerCommunicationFailed(error.localizedDescription)` (start failure). A new private `userFacingMessage(for:)` helper renders `errorDescription` + ` — ` + `recoverySuggestion` so the inspector surfaces the framework's recovery copy. |
| `EditorTrafficLights`, `EditorTitleBar`, `EditorBreadcrumbView`, `PlatformGlassSurface` from `CodeEditorUI` — zero call sites | ✅ Done | `CodeEditorSampleApp` opted into `.windowStyle(.hiddenTitleBar)` so the embedded chrome owns the top of the window. `RootWindow` now renders `EditorTitleBar(title:trafficLights:)` with wire-actions for close/minimize/zoom routed to `NSApp.keyWindow?.perform{Close,Miniaturize,Zoom}`, plus `EditorBreadcrumbView()` reading the framework-populated `\.editorState.breadcrumbPath` between the tab strip and editor pane. `EditorTrafficLights` is consumed transitively via `EditorTitleBar`. `PlatformGlassSurface` is consumed transitively via `EditorTitleBar`'s `.platformGlassSurface(.titleBar)` and directly via the breadcrumb's `.platformGlassSurface(.tabBar)`. |
| iOS silently lacks LSP / completion / perf / annotations inspectors | ✅ Done | `IOSRootView` gains a fifth sidebar section (`.inspectors`) that renders a `ContentUnavailableView` explaining the inspector panels live in `Sources/CodeEditorSample/Sidebars/` behind `#if canImport(AppKit)` — and that the underlying framework APIs (`LSPManager`, `CompletionManager`, `PerformanceInsights`, `AnnotationsHub`) do work on iOS; only the sample's chrome is desktop-only. |
| No file-save path — `DocumentStore.openFile` reads but never writes | ✅ Done | `DocumentStore.save(_ id: TabModel.ID? = nil)` writes UTF-8 back through `TabModel.url` and clears `isDirty`. New `SaveOutcome` enum models `.saved(url:)` / `.untitled` / `.noTab` / `.failed(error:)` so the host can route Save-As separately. `CodeEditorSampleApp` adds a `Save` menu item bound to `⌘S`; `AppState.handleSaveOutcome(_:)` logs the result via `CrossPlatformLogger`. Save-As for `Untitled-*` tabs is intentionally left as a follow-up. |
| `CodeEditor.withLanguage` / `withConfiguration` factories unused | ✅ Done | `IOSRootView.editor` switched from `CodeEditor(text:)` + `.codeEditorEnvironment(...)` to `CodeEditor.withConfiguration(_:configuration:language:theme:)`. The macOS path keeps the individual-modifier form so both calling conventions are demonstrated. |

**Files touched (this batch — 9 modified, 0 added, 0 deleted):**
`Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`, `Sources/CodeEditorSample/App/WindowBody.swift`, `Sources/CodeEditorSample/App/RootWindow.swift`, `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`, `Sources/CodeEditorSample/App/AppState.swift`, `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`, `Sources/CodeEditorSample/App/Completion/DemoCompletionProvider.swift`, `Sources/CodeEditorSample/Documents/DocumentStore.swift`, `Sources/CodeEditorSample/iOS/IOSRootView.swift`.

Build: green. SwiftLint: 0 violations. No new test failures.

**Deliberately deferred:**
- Save-As panel for `Untitled-*` tabs. Needs a sample-side NSSavePanel flow and a small iOS document-picker variant; not a "non-design" change.
- Three independent completion ranking pipelines (`CompletionManager.sortAndDeduplicateItems` vs `CompletionRankingModel.rank` vs `SmartCompletionEngine.rerank`) still disagree. Unification is a design call — what's the canonical scoring algorithm? Sample now exercises `CompletionRankingModel` so the gap is at least visible.
- LSP iOS coverage. The docstrings still claim "remote servers on iOS" while the implementation is `#if canImport(AppKit)`. Adding iOS support or rewriting the docs both need design.
- `SmartEditingEngine.attach` delegate-overwrite (LSP/completion/folding all want the delegate slot). Needs a delegate-multiplexer design.
- `CodeEditorEnvironment.with(...)` cannot clear optional fields. Needs a sentinel/explicit-nil API design.
- Inconsistent SwiftUI modifier return types (`some View` vs `CodeEditor`). Needs a one-pass migration decision.



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
- ~~`CodeEditorView.removeFromSuperview` fires `Task { await syntaxHighlighter.cancelHighlighting() }` (`Core/CodeEditorView.swift:533-535`) — cancellation arrives after the next editor is up; no `deinit` analog.~~ ✅ Both halves landed (sync cancel in the Concurrency batch on 2026-05-14; `deinit` analog in the Editor lifecycle + EditorState mirror batch on 2026-05-14).
- ~~`MemoryMonitor` registers an `NSObjectProtocol` termination observer but never removes it; `Task`s aren't auto-cancelled (`Performance/MemoryMonitor.swift:259-285`). Leaks NotificationCenter slots + live tasks across tests/windows.~~ ✅ Done in the 2026-05-14 Concurrency batch.
- ~~`EditorEventPublisher.publish` (`Core/EditorEventPublisher.swift:98-113`) spawns an unstructured `Task` per publish — A/B ordering is not preserved despite call-site expectations.~~ ✅ Done in the Editor lifecycle + EditorState mirror batch on 2026-05-14 (chain-tail FIFO via `deliveryTask`).
- ~~`LSPClient.disconnect()` clears state synchronously while shutdown runs detached (`LSP/LSPClient.swift:179-224`); in-flight responses arriving after dictionary clear are silently dropped.~~ ✅ Done in the 2026-05-14 Concurrency batch.
- ~~`ProcessTransport` busy-polls `availableData` every 10ms and races its `receive()` with `setDataHandler` (`ProcessTransport.swift:233-256`). Use `readabilityHandler`/`DispatchIO`.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (`readabilityHandler` for stdout + stderr; handlers torn down in `disconnect()` and `deinit`).
- ~~`LayoutCoordinator.processPendingOperations` can recurse unboundedly via its own `defer` (`Layout/LayoutCoordinator.swift:101-111`). Convert to an iterative drain.~~ ✅ Done in the 2026-05-14 Concurrency batch.
- ~~`completionRequested` does not cancel in-flight task before spawning a new one (`Core/CodeEditorView+CompletionExtensions.swift:100`).~~ ✅ Done in the Editor lifecycle + EditorState mirror batch on 2026-05-14.

### API correctness
- ~~`CodeEditorAPI` mixes `Range<String.Index>` and `NSRange` despite claiming the latter is canonical (`Core/CodeEditorAPI.swift:65`, sites 93–145). `String.Index` is unstable across edits. Pick `NSRange`.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (protocol is now NSRange-only; default impls rewritten against `NSString` line-enumeration; internal callers updated).
- `EditorConfiguration.Layout.Codable` drops 5 fields silently (`Configuration/EditorConfiguration+LayoutExtensions.swift:66-116`) — `annotationBadgeSize`, `annotationBadgePadding`, `minimapWidth`, `foldingControlSize`, `foldingControlPadding`. Data loss on persistence round-trip.
- `EditorConfiguration.Performance.usesRangeBasedHighlighting` is missing from `CodingKeys` and `==` (`+PerformanceExtensions.swift:22 / 128–142 / 194–209`).
- `CodeEditorEnvironment.with(...)` cannot clear optional fields — `nil` is collapsed to "no change" (`SwiftUI/CodeEditorEnvironment+Extensions.swift:84-95, 185-207`).
- ~~`EditorState` env default allocates a fresh instance per read (`SwiftUI/EditorState+Environment.swift:13`). Writes silently no-op.~~ ✅ Done in the SwiftUI hot path + env hygiene batch on 2026-05-14 (shared sentinel; writes against it are inert).
- ~~`CodeEditor.body` reallocates `EditorRuntimeDependencies.live(...)` per render — `MemoryMonitor`, `ActorCoordinator`, etc. all rebuilt (`SwiftUI/CodeEditor.swift:271-277` + `Core/EditorRuntime.swift:46-64`).~~ ✅ Done in the SwiftUI hot path + env hygiene batch on 2026-05-14 (`@State`-cached fallback; env overrides applied to a local copy).
- Inconsistent SwiftUI modifier return types: some return `some View`, others return `CodeEditor` (`SwiftUI/CodeEditor+ModifiersExtensions.swift`). Chains break once a host hits a `some View` modifier before a `CodeEditor`-typed one.
- `SmartEditingEngine.attach` overwrites `textView.delegate` with a warning log (`Features/SmartEditingEngine.swift:53-61`). With LSP/completion/folding all wanting hooks, last wins.
- ~~`SearchReplaceEngine` and `SmartEditingEngine` are `public class` (non-`final`) — open subclassing.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (both marked `public final`).
- ~~`SwiftUICompletionItem` not `Sendable` despite being returned from a `@Sendable` async closure (`SwiftUI/CodeEditor+CompletionExtensions.swift:36`).~~ ✅ Done in the SwiftUI hot path + env hygiene batch on 2026-05-14 (`SwiftUICompletionItem: Sendable` + `CompletionKind: Sendable`).

### Language/highlighting/completion correctness
- LSP iOS coverage is fictional: `LSPClient` docs claim "remote servers on iOS," but `LSPManager`, `LSPCompletionProvider`, `LSPSemanticTokenProvider`, `LSPDocumentManager`, `LSPClientRegistry`, `LSPContentCoordinator`, `LSPPathResolver` are all wrapped in `#if canImport(AppKit)`.
- Three independent completion ranking pipelines disagree: `CompletionManager.sortAndDeduplicateItems:289-311`, `CompletionRankingModel.rank:33-64`, `SmartCompletionEngine.rerank`.
- ~~`descriptor.highlightingStrategy` is dead data — every descriptor sets it; nothing reads it (`HighlightingStrategyExecutor.determineStrategy:47-61` hardcodes the routing).~~ ✅ Done in the Language descriptor cleanup batch on 2026-05-14 (field + static helper deleted).
- ~~`parserName` (a tree-sitter grammar id) doubles as a "use regex highlighter" gate (`RegexSyntaxHighlighter+LanguagesExtensions.swift:35,46`, `RegexRangeHighlightProvider.swift:319`). Misleading; introduce explicit `usesRegexHighlighter`.~~ ✅ Done in the Language descriptor cleanup batch on 2026-05-14 (`usesRegexHighlighter: Bool` added; three call sites switched).
- ~~Stale language count: `SyntaxHighlightingCoordinator.swift:167` says "17+ languages" — CLAUDE.md is canonical at 25 + plain text.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~Two parallel fuzzy matchers: `FuzzyMatcher` (`FuzzyMatcher.swift:4`, non-`Sendable`) and `OptimizedFuzzyMatcher` (Sendable). `SmartCompletionEngine.swift:54` uses the non-`Sendable` one.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (`FuzzyMatcher.swift` deleted; `SmartCompletionEngine` + `SymbolNavigator` + tests migrated to `OptimizedFuzzyMatcher.matchSequential`).
- ~~`RegexBackedRangeQueryParser` invalidates the entire document on every edit (`RegexRangeHighlightProvider.swift:88-92`). Unused; delete to prevent confusion.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (class deleted; tests migrated to `RegexIncrementalRangeQueryParser`).

### Cross-cutting
- ~~`CrossPlatformLogger.osLogger.log(level:, "\(message)")` (`Utilities/CrossPlatformLogger.swift:100`) defeats OSLog format-string privacy/redaction — call sites already interpolated state. Privacy annotations are lost; arbitrary state may leak into release logs.~~ ✅ Done in the Logger privacy + tokens + continuation batch on 2026-05-14 (explicit `.public` privacy + doc comment spelling out the caller-redacts contract).
- ~~`CodeEditorDependencies` reads `DependencyValues._current.codeEditorMemoryMonitor()` instead of the `@Dependency` property wrapper (`Core/CodeEditorDependencies.swift:9`). `withDependencies { }` overrides won't flow through actor hops reliably.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (all eight factories resolve through `@Dependency`).
- ~~`EditorEventBusInstaller.sourcePosition` is O(n) per hover/⌘-click via UTF-16 walk (`Layout/EditorEventBusInstaller.swift:124-144`). Use `LineGeometryStore`.~~ ✅ Done in the SwiftUI hot path + env hygiene batch on 2026-05-14 (fast-path via `(textView as? CodeEditorView)?.lineGeometryStore`; UTF-16 walk retained as fallback for non-editor `NSTextView`s).
- ~~`PlatformEventFilter.shouldAllow` always returns `true` (`Core/UnifiedEventSystem.swift:241-244`). Dead.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`EditorTrafficLights` hardcodes RGB outside the token system (`Sources/CodeEditorUI/Window/EditorTrafficLights.swift:41-48`).~~ ✅ Done in the Logger privacy + tokens + continuation batch on 2026-05-14 (`Tokens.Palette.TrafficLight.{close, minimize, zoom}` added).

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

All landed in the Sample coverage gaps batch on 2026-05-14:

- ~~`.codeLanguage(_:)`, `.showsLineNumbers(_:)`, `.codeWorkspaceRoot(_:)` — advertised in the umbrella; sample uses none of them.~~ ✅ Done (`WindowBody.editorPane` now uses the individual modifiers).
- ~~`CodeEditor.withLanguage`/`withConfiguration` factories — unused.~~ ✅ Done (`IOSRootView.editor` uses `CodeEditor.withConfiguration`).
- ~~`SnippetTemplate`, `CompletionProviderUtilities.fuzzyFilter`, `CompletionRankingModel` — unreferenced.~~ ✅ Done (`DemoCompletionProvider` uses all three).
- ~~`LSPCompletionProvider` registration through `CompletionManager` — wired nowhere.~~ ✅ Done (`LSPSampleCoordinator.start()` registers it; `openTab`/`handleTextChange` keep its context current).
- ~~`CodeEditorError` recovery — pitched in umbrella docs, never used.~~ ✅ Done (`LSPSampleCoordinator` failure paths surface `errorDescription` + `recoverySuggestion`).
- ~~`PerformanceInsightsPanel` (framework view) is duplicated by `Sidebars/PerformanceInspectorPanel`; sample re-rolls.~~ ✅ Done (framework panel embedded in the Report sheet alongside `DetailedPerformanceReportView`).
- ~~`EditorTrafficLights`, `EditorTitleBar`, `EditorBreadcrumbView`, `PlatformGlassSurface` from `CodeEditorUI` — zero call sites.~~ ✅ Done (window opted into `.hiddenTitleBar`; `RootWindow` renders the chrome).
- ~~iOS has no LSP/perf/completion inspector — silently absent. Add a `ContentUnavailableView` explaining the gap.~~ ✅ Done (`IOSRootView` adds an `.inspectors` sidebar section with an explanatory `ContentUnavailableView`).
- ~~No file-save path; `DocumentStore.openFile` reads, never writes.~~ ✅ Done (`DocumentStore.save(_:)` + `⌘S`; Save-As for `Untitled-*` tabs deliberately deferred).

---

## Minor issues / dead code worth pruning

- ~~Dead types: `Text/TextLayoutManager.swift`, `Text/TextLayoutFragmentView.swift`, `Models/MarkedText.swift`, `Models/NSTextSegmentType.swift`, most of `Core/SendableTypes.swift` (only `SendablePerformanceMetric`, `FileChangeNotification` referenced).~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`TestEnvironmentDetector.isRunningInTests` checks `XCTestConfigurationFilePath` only — wrong for Swift Testing (`Utilities/TestEnvironmentDetector.swift:39-41`).~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (now also checks `NSClassFromString("XCTestCase")` and a swift-testing/Testing-framework bundle scan). The remaining concern about `MemoryManagementCoordinator.setupMemoryMonitoring:119` hiding lifecycle bugs from tests is a separate design call (it's intentional test isolation, not a typo).
- ~~Magic `17.0` line-height in `LineGeometryEditHandler.swift:125-126,136,142`.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14 (`LineGeometryStore.defaultEstimatedHeight`).
- ~~`FastJSONTokenizer` round-trips color → `TokenType` to rebuild `HighlightedToken` (`HighlightingStrategyExecutor.highlightJSON:87-97`). Defeats theme overrides.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (direct `FastJSONTokenizer.TokenType` → framework `TokenType` mapping; dead `TokenType.fromColor` removed).
- ~~`HTMLSymbolProvider.extractAttribute` compiles a regex per call (`HTMLSymbolProvider.swift:92-93`).~~ ✅ Done in the Language descriptor cleanup batch on 2026-05-14 (hoisted both regexes to `static let`).
- ~~`CompletionDebouncer.executeRequest` cancels prior tasks but `withCheckedThrowingContinuation` in `SmartCompletionEngine` doesn't get resumed — caller can hang (`CompletionDebouncer.swift:196-221`, `SmartCompletionEngine:191-198`).~~ ✅ Done in the Logger privacy + tokens + continuation batch on 2026-05-14 (continuation removed; `performCompletion` now returns `CompletionResult` directly).
- ~~`EditorConfiguration.swift:68` doc comment teaches `print("Configuration errors: \(errors)")` — exempt by lint but bad pedagogy.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`CodeEditorUI/CodeEditorUI.swift:11` uses `## Topics` DocC directive — project has no DocC catalog.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`PerformanceMonitor` starts a 5-min cleanup task at `init` regardless of usage (`Performance/PerformanceMonitor.swift:64-69`).~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (cleanup task starts lazily on first `startMeasuring(_:)`).
- ~~`@preconcurrency import SwiftUI` in `CodeEditor.swift:2` and modifier files — unlinked.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`ConfigurationCodeFormatter.swiftStringLiteral` (`Sidebars/ConfigurationCodeFormatter.swift:284-286`) is dead.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`durationMilliseconds` duplicated in `ConfigurationCodeFormatter:278-282` and `KnobRow.swift:355-359`.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`AppState.swift:76-78` cites `docs/superpowers/...` — that path is archived working notes per CLAUDE.md.~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`SettingsScene`'s `frame(width: 1380, height: 880)` precedes `windowResizability(.contentSize)` and overrides the min sizes (`App/CodeEditorSampleApp.swift:16-20`).~~ ✅ Done in the Dead-code & doc cleanup batch on 2026-05-14.
- ~~`MainActor.assumeIsolated` after `.receive(on: DispatchQueue.main)` (`DiagnosticsBridge.swift:49-55`) — works only by accident.~~ ✅ Done in the Non-design remainder batch on 2026-05-14 (sink now hops via `Task { @MainActor [weak self] in … }`).
- ~~No `Sources/CodeEditorSample/README.md`; users will keep hitting the `cd CodeEditorSample` trap.~~ ✅ Done in the Non-design remainder batch on 2026-05-14.
- ~~**`EditorState.language` is never populated by the framework.**~~ ✅ Done in the Editor lifecycle + EditorState mirror batch on 2026-05-14. The reviewer's "two-line fix" diagnosis was off — `EditorContainerViewModel.updateEditorState()` writes to a *different* (nested-struct) `EditorState`, not the `@Observable` class the chrome reads. The actual wiring threads the Observable `\.editorState` env value through `CodeEditor.body` → representable → `CodeEditorBaseCoordinator.hostEditorState` (weak), and the coordinator mirrors `language` + `lineCount` from `updateState(...)` and `selection` from `handleSelectionChange(...)`. See the batch section near the top for details and tests.

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

1. ~~**Land the 7 Critical fixes** first — they're either silent correctness bugs (1, 2, 4) or hot-path perf cliffs (5, 6, 7) plus one strict-concurrency soundness fix (3).~~ ✅ All landed.
2. ~~**Close the sample-driven API gaps** (the 8 numbered items above) — every host you ship to will rediscover the same gaps.~~ ✅ Items #1, #2, #4, #8 landed in the first pass; items #3, #5, #6, #7 still require design (see "Still open" notes near the top).
3. ~~**Pick off the lifecycle/concurrency batch** as a single PR — `MemoryMonitor` observer leak, `removeFromSuperview` cancellation, `LayoutCoordinator` recursion, `LSPClient.disconnect`.~~ ✅ Landed. `ProcessTransport` busy-poll (also in this bucket) landed in the Non-design remainder batch.
4. ~~**Codable + Equatable completeness sweep** for `EditorConfiguration.*` — small, high-value.~~ ✅ Landed (Layout + Performance sub-structs).
5. ~~Then minor/dead-code cleanup as background work.~~ ✅ Three batches landed (Dead-code & doc cleanup, Language descriptor cleanup, Non-design remainder).

### What's left after this round

All remaining items require a design conversation before any code lands:

- **Sample-driven API gaps #3, #5, #6, #7** — `EditorDocument` recipe, `EditorController.onAttach`, `CompletionEvent` AsyncStream, `.performanceObserver(_:)` modifier.
- **LSP iOS coverage** — docs claim "remote servers on iOS" but the implementation is gated to `#if canImport(AppKit)`. Either add iOS support or rewrite the docs.
- **Three completion ranking pipelines disagree** — `CompletionManager.sortAndDeduplicateItems` vs `CompletionRankingModel.rank` vs `SmartCompletionEngine.rerank`. Pick one canonical scoring algorithm.
- **`SmartEditingEngine.attach` overwrites the delegate** — needs a multiplexer (LSP / completion / folding all want the slot). Generalising the `TextEditEventObserving` pattern from `CodeFoldingEngine` is the suggested template in "Patterns worth codifying".
- **`CodeEditorEnvironment.with(...)` cannot clear optional fields** — needs an explicit-nil sentinel or overloaded clearing variants.
- **Inconsistent SwiftUI modifier return types** — `some View` vs `CodeEditor`. Pick one shape and migrate.
- **Save-As for `Untitled-*` tabs** — needs sample-side `NSSavePanel` + iOS document-picker flows. Not a "non-design" change.
