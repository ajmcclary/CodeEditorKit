# CodeEditorPlugin Review

Review date: 2026-05-16

Scope covered: repository-wide static scans, targeted source reads across the requested architecture areas, and the requested build, lint, test, and sample-build commands.

## Validation

| Command | Result | Notes |
|---|---:|---|
| `swift build` | Passed | Build completed. Compiler emitted deprecation warnings for TLS 1.0/1.1 mapping in `RemoteLSPConfiguration`. |
| `swiftlint --fix && swiftlint` | Passed | `swiftlint` reported 0 violations. Worktree was unchanged after the lint pass. |
| `swift test --parallel` | Failed | Swift Testing reported 455 tests in 114 suites with 1 failing issue plus 1 known issue. Failing test: `PerformanceObservation.stop cancels the refresh task`. |
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

### H1. `swift test --parallel` fails because `PerformanceObservation.stop()` can still allow a refresh

Files:

- `Sources/CodeEditorPlugin/Performance/PerformanceObservation.swift:101-120`
- `Tests/CodeEditorPluginTests/Performance/PerformanceObservationTests.swift:45-53`

What's wrong:

`start()` launches a refresh loop that checks cancellation before sleeping, but it calls `self?.refresh()` immediately after `Task.sleep(for:)` returns. There is no second cancellation or ownership check between the sleep boundary and the refresh. The requested full test command failed with `refreshCount` increasing from `0` to `1` after `stop()`.

Why it matters:

The public stop contract is not reliable. Hosts can still observe performance snapshots after stopping an inspector or tearing down an observer, and the repository's required full test command is currently red.

Concrete fix:

After `Task.sleep`, check cancellation again before calling `refresh()`. For stronger correctness, add a loop generation token that `start()` captures and `stop()` invalidates, then require the captured generation to still match before each refresh. Keep the regression test, but make it assert no post-stop tick after at least one deterministic pre-stop tick.

### H2. Public `textViewWillChangeText` delegate callbacks are never delivered

Files:

- `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegate.swift:74-95`
- `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift:100-132`
- `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift:52-55`
- `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift` has counters for this path but no assertion that it fires

What's wrong:

`CodeEditorViewDelegate` documents `textViewWillChangeText(_:)` as firing before every text modification, and the proxy implements the participant hook. The multiplexer `shouldChangeText` path only asks gating and behavior participants for vetoes, publishes `WillEditEvent`, and returns `true`; it never calls `participant.textViewWillChangeText(...)`.

Why it matters:

This breaks a public delegate contract. Hosts relying on the pre-edit hook for undo grouping, autosave snapshots, dirty-state comparison, or UI preparation never receive the callback.

Concrete fix:

Once all veto participants allow the edit, snapshot the active participants and call `textViewWillChangeText(codeEditorView)` before publishing the will-edit event. Add tests for allow and veto paths: allowed edits should call the hook once in phase order; vetoed edits should not call it.

### H3. `LSPClient.disconnect()` can hang forever waiting for shutdown

Files:

- `Sources/CodeEditorPlugin/LSP/LSPClient.swift:191-243`
- `Sources/CodeEditorPlugin/LSP/LSPClient.swift:446-473`
- `Sources/CodeEditorPlugin/LSP/LSPConnectionManager.swift:90-95`

What's wrong:

For initialized clients, `disconnect()` sets `.shuttingDown` and awaits `LSPConnectionManager.sendShutdownRequest`. That helper sends a normal `shutdown` request through `sendRequest`, which stores a checked continuation in `pendingRequests` with no timeout. If the language server is wedged or has stopped reading, the shutdown request never completes, so the teardown after line 235 does not run.

Why it matters:

A bad or dead LSP server can leave the client stuck in `.shuttingDown`, with transport/process cleanup delayed indefinitely. That is a user-visible shutdown hang and can leak the server process or socket.

Concrete fix:

Make shutdown best-effort and bounded. Wrap the shutdown request in a short timeout, then always close the transport/process in a `defer` or unconditional cleanup path. Also fail any pending request created during shutdown, not just the pending requests captured before shutdown starts.

### H4. Viewport highlighting caches partial tokens under a full-document key

Files:

- `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift:121-175`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/OptimizedSyntaxHighlightingCoordinator.swift:236-284`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SmartTokenCache.swift:96-130`

What's wrong:

For large files with a visible range, `highlight(...)` calls `highlightViewport(...)`, which returns tokens only for an expanded viewport slice. Those partial tokens are then cached under `CacheKey(text:language:version:)`, which does not include viewport identity or cache completeness. Later calls for a different viewport filter that same partial token array, and a later full-document request can return the partial viewport tokens as if they represented the whole document.

Why it matters:

Large-file highlighting can silently miss tokens outside the first cached viewport. This is exactly the kind of cache correctness bug that presents as inconsistent coloring while scrolling.

Concrete fix:

Model cache completeness explicitly. Either include viewport range in the cache key, or store entries as `fullDocument` versus `viewport(range:)` and reject incompatible cache hits. Never satisfy a full-document request from a viewport-only cache entry. Add a regression that highlights viewport A, then viewport B, then the full document, and verifies tokens outside A are present.

## Medium

### M1. Minimap notification observers leak because block observer tokens are discarded

Files:

- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Minimap.swift:31-65`
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView.swift:288-291`

What's wrong:

`setupMinimap()` installs block-based `NotificationCenter` observers and ignores the returned tokens. `deinit` calls `removeObserver(self)`, but block observers are removed by their returned token, not by `self`.

Why it matters:

Each container that sets up a minimap leaves stale observer records behind. `[weak self]` avoids retaining the container, but `NotificationCenter` still retains the closure/token and will keep evaluating dead observers over time.

Concrete fix:

Store the returned `NSObjectProtocol` tokens on the container, remove them during cleanup/deinit, and clear them before re-running minimap setup. Consider reusing the existing observer-token storage pattern used elsewhere in the codebase.

### M2. Folding minimum-line filtering compares line count to UTF-16 length

Files:

- `Sources/CodeEditorPlugin/Models/FoldableRegion.swift:39-44`
- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift:333-340`

What's wrong:

`CodeFoldingConfiguration.minimumLineCount` is a line-count setting, but `processFolding` filters regions with `region.range.length >= configuration.minimumLineCount`. `NSRange.length` is UTF-16 length, not line span.

Why it matters:

Short one-line or two-line brace regions can pass the minimum-line filter if they contain at least three UTF-16 code units. That makes folding controls appear for regions the configuration says should be too small.

Concrete fix:

Compute start and end line numbers using the existing text range utilities or `LineGeometryStore`, then compare the line span to `minimumLineCount`. Add tests for one-line, two-line, and three-line regions.

### M3. Folding providers are registered for Dockerfile, TOML, and Lua but return no folds

Files:

- `Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift:66-73`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexQuery/HeuristicFoldProvider.swift:14-40`
- `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift:333-338`

What's wrong:

The registry installs `HeuristicFoldProvider` for `.dockerfile`, `.toml`, and `.lua`, but `HeuristicFoldProvider` falls through to `default: return []` for those languages. The test only verifies a provider exists, not that it detects folds.

Why it matters:

The feature surface claims folding support for these languages while the implementation is effectively a no-op.

Concrete fix:

Either implement real heuristics for those languages or stop registering providers for them. Replace the current presence-only test with sample input assertions that require at least one expected fold per advertised language.

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

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 4 |
| Medium | 6 |
| Low | 2 |

Overall health: yellow. The codebase builds and lint passes, and several hard conventions are well enforced. The main concern is correctness under lifecycle and cache boundaries: the full test suite is red, LSP disconnect can hang on unresponsive servers, and large-file viewport highlighting can return incomplete cached results.

Most impactful fixes first:

1. Fix `PerformanceObservation` stop semantics so `swift test --parallel` is green again.
2. Make `LSPClient.disconnect()` bounded and cleanup-guaranteed.
3. Correct viewport-token cache completeness and add scrolling/full-document cache regression tests.
