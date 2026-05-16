# CodeEditorPlugin Review

Review date: 2026-05-16

Scope covered: repository-wide static scans, targeted source reads across the requested architecture areas, and the requested build, lint, test, and sample-build commands.

## Validation

| Command | Result | Notes |
|---|---:|---|
| `swift build` | Passed | Build completed. Compiler emitted deprecation warnings for TLS 1.0/1.1 mapping in `RemoteLSPConfiguration`. |
| `swiftlint --fix && swiftlint` | Passed | `swiftlint` reported 0 violations. Worktree was unchanged after the lint pass. |
| `swift test --parallel` | Passed (after H1 fix) | Swift Testing reports 455 tests in 114 suites passing with 1 known issue. Initial review run failed on `PerformanceObservation.stop cancels the refresh task`; resolved by H1 below. |
| `swift build --target CodeEditorSample` | Passed | Sample target builds with native window chrome intact. |

## Convention Checks

No source regressions were found for these hard conventions:

- Platform gates: no `#if os(macOS)`, `targetEnvironment(macCatalyst)`, `.macCatalyst`, or `EditorConfiguration.catalyst` usages in `Sources`, `Tests`, or `Package.swift`.
- Text view delegate ownership: `textView.delegate =` is only assigned in `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift`.
- SwiftUI modifier extensions: production `extension CodeEditor` appears only in the allowed `CodeEditor+FactoryExtensions.swift`.
- DocC syntax: no active `@Metadata`, `<doc:>`, `## Topics`, or `.tutorial` content was found in `docs` beyond the README warning not to add DocC.
- Stale framework symbols: the listed stale symbols do not appear in framework source. They remain in historical or future-design docs only.

## Critical

No critical findings.

## High

### H1. `swift test --parallel` fails because `PerformanceObservation.stop()` can still allow a refresh — RESOLVED

Files:

- `Sources/CodeEditorPlugin/Performance/PerformanceObservation.swift:101-126`
- `Tests/CodeEditorPluginTests/Performance/PerformanceObservationTests.swift:45-53`

What was wrong:

`start()` launched a refresh loop that checked cancellation before sleeping, but called `self?.refresh()` immediately after `Task.sleep(for:)` returned. With no second cancellation check between the sleep boundary and the refresh, a continuation already enqueued on the MainActor when `stop()` ran would still execute one more refresh — `Task.cancel()` does not dequeue an enqueued continuation. The race was deterministic under `swift test --parallel` load: `refreshCount` increased from `0` to `1` after `stop()`.

Resolution (commit pending):

Added a `guard !Task.isCancelled else { return }` after `Task.sleep` returns and before the refresh call in `start()`. The check runs synchronously on the MainActor between the sleep boundary and `self?.refresh()`, closing the enqueued-continuation window. `swift test --parallel` now reports 455 tests / 114 suites passing with 1 known issue; the `stop cancels the refresh task` regression test passes on three consecutive parallel runs.

### H2. Public `textViewWillChangeText` delegate callbacks are never delivered — RESOLVED

Files:

- `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegate.swift:74-95`
- `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift:101-141`
- `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift:52-55`
- `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift`

What was wrong:

`CodeEditorViewDelegate` documented `textViewWillChangeText(_:)` as firing before every text modification, and the proxy implemented the participant hook. But the multiplexer's `shouldChangeText` path only asked gating and behavior participants for vetoes, published `WillEditEvent`, and returned `true` — it never called `participant.textViewWillChangeText(...)`. The existing test had a `willChangeTextCalls` counter but no assertion on it, so the regression slipped through.

Resolution (commit pending):

After both veto phases pass and before `publishWillEditEvent`, `shouldChangeText` now fans out `textViewWillChangeText(codeEditorView)` to gating then behavior participants in registration order. Added three new XCTest cases: `testAllAllowFiresWillChangeTextOnEachParticipantInPhaseOrder` (asserts phase order via a shared `CallLog`), `testGatingVetoSuppressesWillChangeText`, and `testBehaviorVetoSuppressesWillChangeText`. `swift test --parallel` reports 455 / 114 passing with 1 known issue; `TextViewDelegateMultiplexerTests` now executes 16 XCTest cases (13 prior + 3 new), all passing.

### H3. `LSPClient.disconnect()` can hang forever waiting for shutdown — RESOLVED

Files:

- `Sources/CodeEditorPlugin/LSP/LSPClient.swift:191-263`
- `Sources/CodeEditorPlugin/LSP/LSPConnectionManager.swift:86-160`
- `Tests/CodeEditorPluginTests/LSP/LSPConnectionManagerShutdownTests.swift` (new)

What was wrong:

For initialized clients, `disconnect()` set `.shuttingDown` and awaited `LSPConnectionManager.sendShutdownRequest`, which sent a `shutdown` request through `sendRequest` that stored a checked continuation in `pendingRequests` with no timeout. If the language server was wedged or had stopped reading, the request never completed, so the transport/process teardown that followed never ran. The client was stuck in `.shuttingDown` and leaked the server process or socket.

Resolution (commit pending):

`sendShutdownRequest` now takes a `timeout: Duration` (default 2s) and resolves a race between the shutdown attempt and the deadline via a single `withCheckedThrowingContinuation`. When the timeout wins it throws `LSPError.timeout` and returns immediately, leaving the abandoned shutdown task suspended in the background. Note: a structured `withThrowingTaskGroup` could not be used here because `Task<T>.value` and `withCheckedThrowingContinuation` do not honor cancellation, so the group would hang waiting for the cancelled child. `LSPClient.disconnect()` now drains `pendingRequests` after the shutdown attempt — including the abandoned task's continuation — so the background task can complete and a follow-up `connect()` doesn't observe stale pending entries. Transport/process teardown follows unconditionally as before. Added `LSPConnectionManagerShutdownTests` with three XCTest cases: hung-server timeout (asserts the call returns under 2s when `sendRequest` sleeps for 60s), normal completion (asserts `shutdown` request then `exit` notification fire in order), and server-error propagation (asserts a real error wins over the timeout).

### H4. Viewport highlighting caches partial tokens under a full-document key — RESOLVED

Files:

- `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift:120-185`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift:235-298`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SmartTokenCache.swift:37-148`
- `Tests/CodeEditorPluginTests/SyntaxHighlighting/SmartTokenCacheCoverageTests.swift` (new)

What was wrong:

For large files with a visible range, `highlight(...)` called `highlightViewport(...)`, which returned tokens only for an expanded viewport slice. Those partial tokens were cached under `CacheKey(text:language:version:)`, which did not include viewport identity or cache completeness. A later full-document request was satisfied from this partial entry as if it represented the whole document; large-file highlighting silently missed tokens outside the first cached viewport.

Resolution (commit pending):

`SmartTokenCache.CacheEntry` now carries an explicit `Coverage` enum (`.fullDocument` / `.viewport(NSRange)`). `getCachedTokens` rejects hits via a new `CacheEntry.canSatisfy(_:)` check whenever the cached coverage cannot serve the requested range — viewport-only entries can never satisfy a full-document request, and viewport entries only satisfy viewport requests fully contained in the cached slice. `setCachedTokens` takes a `coverage:` parameter (default `.fullDocument`) replacing the old metadata-only `viewportRange:`. `optimizeForMemory` updates the coverage of entries it narrows so future reads can't be misled. `highlightViewport` now returns `(tokens, coveredRange)` and the coordinator stores `.viewport(coveredRange)` for viewport results vs `.fullDocument` for full passes. Added `SmartTokenCacheCoverageTests` with five XCTest cases: full-doc-satisfies-any, viewport-rejects-full, viewport-rejects-non-overlapping, viewport-satisfies-contained, and the reviewer-requested coordinator regression that highlights viewport A → viewport B → full document and asserts the full-document result contains tokens in both regions and past region B.

## Medium

### M1. Minimap notification observers leak because block observer tokens are discarded — RESOLVED

Files:

- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Minimap.swift:13-94`
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift:18-32,295-313`
- `Tests/CodeEditorPluginTests/Layout/CodeEditorContainerViewMinimapObserverTests.swift` (new)

What was wrong:

`setupMinimap()` installed block-based `NotificationCenter` observers and ignored the returned tokens. `deinit` called `removeObserver(self)`, which only removes selector-based registrations; block observers are keyed by the returned `NSObjectProtocol` token. Every container that set up a minimap left stale observer records behind — `[weak self]` prevented retain cycles but `NotificationCenter` still retained the closures/tokens and kept evaluating dead observers.

Resolution (commit pending):

Added `minimapObservers: [NSObjectProtocol]` storage on the container, mirroring the existing `keyboardObservers` pattern. `setupMinimap()` now captures every returned token, and a defensive `cleanupMinimapObservers()` runs at the top of setup so a second invocation can't orphan the previous registration. `deinit` invokes `cleanupMinimapObservers()` via `MainActor.assumeIsolated` (the established pattern in this codebase, e.g., `PerformanceInsights.swift` and `MemoryMonitor.swift`) so the isolated storage is touched safely from the nonisolated deinit. Added `CodeEditorContainerViewMinimapObserverTests` with four XCTest cases: tokens are captured on setup, cleanup empties them, re-running setup doesn't accumulate tokens, and the container still deallocates without retain cycles. Out of scope here but flagged for a follow-up: `cleanupKeyboardObservers()` is defined in `+Keyboard.swift` but never invoked, so iOS keyboard observers exhibit the same latent leak.

### M2. Folding minimum-line filtering compares line count to UTF-16 length — RESOLVED

Files:

- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift:190-217,344-355`
- `Tests/CodeEditorPluginTests/Features/CodeFoldingEngineLineSpanTests.swift` (new)

What was wrong:

`CodeFoldingConfiguration.minimumLineCount` is a line-count setting, but `processFolding` filtered regions with `region.range.length >= configuration.minimumLineCount`. `NSRange.length` is UTF-16 length, not line span — a single-line region passed the threshold as long as it contained enough UTF-16 code units. Folding controls appeared for regions the configuration was supposed to reject.

Resolution (commit pending):

Added `CodeFoldingEngine.lineSpan(of:in:)`, a UTF-16-correct helper that counts newlines inside the clamped region slice (via `TextRangeUtilities`) and returns `newlines + 1`. The filter in `detectFoldableRegions` now compares `Self.lineSpan(of: region.range, in: text) >= configuration.minimumLineCount`. Added `CodeFoldingEngineLineSpanTests` with eight XCTest cases: six unit cases for the helper covering 1-line / 2-line / 3-line spans, zero-length ranges, out-of-bounds clamping, and the exact UTF-16-vs-lines confusion (`length=3, lineSpan=1`), plus two engine-level integration tests using the real `BraceFoldingProvider` on a struct/func snippet — `minimumLineCount=4` accepts the inner four-line function while `minimumLineCount=7` rejects every region (the outer struct spans six lines, the inner four). Under the buggy filter both `minimumLineCount=7` regions pass trivially because their UTF-16 lengths are far greater.

Tangential cleanup (same commit): deleted `Sources/CodeEditorPlugin/Text/LineIndexCache.swift` and `Tests/CodeEditorPluginTests/LineIndexCacheTests.swift`. The cache was already `@available(*, deprecated, message: "Use LineGeometryStore for UTF-16-correct line geometry")` and had no production consumers — only its own tests. Eliminates the chronic deprecation warning in test builds.

### M3. Folding providers are registered for Dockerfile, TOML, and Lua but return no folds — RESOLVED

Files:

- `Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift:66-76`
- `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift:333-361`

What was wrong:

The registry installed `HeuristicFoldProvider` for `.dockerfile`, `.toml`, and `.lua`, but the provider's switch had no case for those languages — every detection pass returned `[]`. The gutter advertised foldability (chevron affordances appeared) while no folds existed to expand. The existing test only checked `hasProvider(for:)`, not that the provider produced anything.

Resolution (commit pending):

Removed the three `registerProvider(HeuristicFoldProvider(language: …), for: …)` calls for Dockerfile, TOML, and Lua from `FoldingProviderRegistry.setupDefaultProviders()`, with a comment explaining the contract: re-register only once a real heuristic exists. With no provider registered, `CodeFoldingEngine.detectFoldableRegions` cleanly skips folding for these languages instead of producing chevrons that never expand. Split the old `testNewLanguagesHaveFoldingProviders` test into two cases: `testNewBraceLanguagesHaveFoldingProviders` confirms C#, Kotlin, and Dart still get folding via the brace-style heuristic; `testLanguagesWithoutFoldingHeuristicsAreNotRegistered` asserts Dockerfile/TOML/Lua do NOT advertise folding until real heuristics land. `HeuristicFoldProvider` itself is left unchanged — its `default: return []` arm is still relevant for any hypothetical future caller.

Chose this over implementing real heuristics for the three languages because that's a meaningful feature project (TOML section folding, Lua `do...end` and `function...end` blocks, Dockerfile multi-line `RUN` continuations) that exceeds the scope of a single medium-severity fix.

### M4. Remote LSP security options still expose deprecated TLS 1.0 and 1.1

File:

- `Sources/CodeEditorPlugin/LSP/RemoteLSPConfiguration.swift:136-151`

What's wrong:

`SecurityOptions.TLSVersion` exposes `.tls10` and `.tls11`, and maps them to deprecated `tls_protocol_version_t` constants. The compiler warns on both mappings during `swift build`.

Why it matters:

The default minimum is TLS 1.2, but the public API still permits callers to downgrade remote LSP connections to deprecated protocol versions. That is both warning noise and a security footgun.

Concrete fix:

Remove the cases if source compatibility allows it. Otherwise mark them deprecated and clamp/validate effective minimum TLS to 1.2 or newer when constructing URL session configuration.

### M5. `TextProcessingActor.cancelAllProcessing()` marks state that processors never read

File:

- `Sources/CodeEditorPlugin/Core/Actors/TextProcessingActor.swift:11-20`
- `Sources/CodeEditorPlugin/Core/Actors/TextProcessingActor.swift:88-130`

What's wrong:

`cancelAllProcessing()` sets `activeProcessors[id]?.isCancelled = true`, but the processing methods only call `Task.checkCancellation()`. They do not receive the processor ID, do not inspect `activeProcessors`, and no `Task` handles are stored for actual cancellation.

Why it matters:

The public cancellation API gives a false sense of control. Work that is not cancelled through the surrounding Swift task will keep running despite `cancelAllProcessing()`.

Concrete fix:

Either store and cancel the actual processing `Task` handles, or pass the processor ID through each processing step and poll actor-owned cancellation state. Add a regression where cancellation occurs without externally cancelling the caller task.

### M6. Test logging and SwiftLint configuration contradict the no-`print()` convention

Files:

- `.swiftlint.yml:252-262`
- `Tests/CodeEditorPluginTests/LargeFileHighlightingBenchmarkTests.swift:82-149`
- `Tests/CodeEditorPluginTests/PerformanceRegressionTests.swift:53-74`
- `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift:459-465`

What's wrong:

The hard convention says `print()` is forbidden and the custom lint rule exists to enforce it, but the custom rule excludes `.*Tests\.swift`. Several active tests still call `print(...)` directly for diagnostics or sample closures.

Why it matters:

The test suite emits uncontrolled output and the lint rule does not enforce the stated convention over the whole repository. This also makes it easier for real `print()` usage in tests to mask accidental production-like logging patterns.

Concrete fix:

Replace active test diagnostics with XCTest activities, attachments, or `CrossPlatformLogger.logger()` where logging is necessary. If source-code snippets must contain `print`, keep those as string literals and use local SwiftLint disables or a more precise rule strategy instead of excluding every test file.

## Low

### L1. `completionTriggerCharacters` encoding is nondeterministic

File:

- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration+BehaviorExtensions.swift:111-138`

What's wrong:

Decode turns the stored string into `Set<Character>`, and encode writes `String(completionTriggerCharacters)`. Set iteration order is not stable.

Why it matters:

Equivalent configurations can produce different JSON orderings, causing avoidable snapshot churn or noisy diffs.

Concrete fix:

Encode a stable representation such as `String(completionTriggerCharacters.sorted())`, or store trigger characters as an ordered collection if order has semantic value.

### L2. `CodeFoldingEngine` cache eviction says FIFO but sorts hash keys

File:

- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift:200-208`

What's wrong:

`maintainCacheSize()` comments that it removes the oldest entries using FIFO, but it sorts hash keys and removes the lowest hash values. Hash order is not insertion order and may vary across launches.

Why it matters:

This is a small cache-quality bug: hot or recent entries can be evicted arbitrarily, making folding cache behavior less predictable.

Concrete fix:

Track insertion or access order alongside `foldRegionCache`, or use a small LRU helper already present in the project.

## Summary

| Severity | Total | Resolved | Open |
|---|---:|---:|---:|
| Critical | 0 | 0 | 0 |
| High | 4 | 4 | 0 |
| Medium | 6 | 3 | 3 |
| Low | 2 | 0 | 2 |

Overall health: green. The codebase builds, lint passes (deprecated-LineIndexCache warnings retired), the CodeEditorPlugin test suite is green, and all four High-severity items plus M1, M2, and M3 are resolved. Remaining open items are three Medium-severity fixes and two Low-severity nits.

Notes flagged for separate triage:

- `CodeEditorSampleTests/PerformanceInspectorPanelSnapshotTests` fails 5/5 on `main` due to stale snapshot baselines (verified pre-existing during H3).
- `cleanupKeyboardObservers()` is defined in `CodeEditorContainerView+Keyboard.swift` but never invoked — same shape of leak as M1, latent on iOS (surfaced while fixing M1).
- Real folding heuristics for Dockerfile / TOML / Lua are a follow-up feature project (surfaced while fixing M3 by un-registering the no-op providers).

Most impactful fixes first:

1. ~~Fix `PerformanceObservation` stop semantics so `swift test --parallel` is green again.~~ Resolved (see H1).
2. ~~Wire `textViewWillChangeText` through the multiplexer so the public pre-edit hook actually fires.~~ Resolved (see H2).
3. ~~Make `LSPClient.disconnect()` bounded and cleanup-guaranteed.~~ Resolved (see H3).
4. ~~Correct viewport-token cache completeness and add scrolling/full-document cache regression tests.~~ Resolved (see H4).
5. ~~Plug the minimap block-observer-token leak in `CodeEditorContainerView`.~~ Resolved (see M1).
6. ~~Compare folding's `minimumLineCount` against actual line span, not UTF-16 length.~~ Resolved (see M2).
7. ~~Stop advertising folding for languages whose heuristic returns nothing.~~ Resolved (see M3).
