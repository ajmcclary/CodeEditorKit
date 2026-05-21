# Code Review: CodeEditorPlugin

I dispatched parallel investigation agents across 7 dimensions, ran swiftlint directly, and verified the most consequential claims against source. Several agent findings were over-stated and have been downgraded or dropped after reading the code (notably the `WebSocketPinningDelegate` "Critical" cert-bypass and the `HighlightingTaskManager` "Critical" race — both turned out to be documented, intentional designs).

---

## 1. Concurrency Safety

**[High] `Sources/CodeEditorTextModel/Text/AwaitableQueue.swift:9-44` — `@unchecked Sendable` contract under-enforced** — ✅ **Resolved**

Explanation: Only `processingCompleted(isolation:)` takes an actor isolation parameter; `enqueue`, `next`, `handlePendingWaiters`, `pendingElements`, and `hasPendingEvents` are reachable from arbitrary contexts. The documented "all access happens from a caller-supplied actor" contract is therefore unenforced — a caller invoking `enqueue` from one actor while another is suspended in `processingCompleted` would race on `pendingElements`.

Suggestion: Add `isolation: isolated any Actor` parameters to every mutating method, or wrap `pendingElements` in an `NSLock`. Otherwise narrow visibility to package and add a comment naming the single owning actor.

Resolution: Backed `pendingEvents` with `OSAllocatedUnfairLock<[Event]>` (NSLock isn't async-safe under Swift 6); every read, write, and the `processingCompleted` check-then-append sequence now runs inside `withLock`. Waiter continuations are drained under the lock and resumed outside it to avoid re-entrancy. The queue is now unconditionally thread-safe, so `@unchecked Sendable` no longer depends on caller discipline; the rationale comment was updated to match.

---

**[High] `Sources/CodeEditorTextModel/Text/RangeProcessor.swift:~305` — Fire-and-forget `Task` with no cancellation tracking** — ✅ **Resolved**

Explanation: `Task { self.continueFillingIfNeeded(...); self.pendingEventQueue.handlePendingWaiters() }` is not stored, so it cannot be cancelled when the owning view/processor is torn down. On rapid open/close cycles this leaks work that can mutate state after the owner expects to be quiescent.

Suggestion: Store the `Task` in a property and cancel it in `deinit`/teardown, or make the call sites structured-async.

Resolution: `scheduleFilling` now captures `self` weakly (so a deinit during a rapid open/close can actually release the processor) and stores the resulting `Task<Void, Never>` in a new `fillTaskLock: OSAllocatedUnfairLock<Task<Void, Never>?>`. Each new schedule cancels the prior task; `deinit` cancels whatever is outstanding. Structured-async wasn't viable because both call sites (`processLocation(.optional)` and `completeContentChanged`) are sync methods that need to return immediately.

---

**[High] `Sources/CodeEditorLSP/LSPClient.swift:~260` — Untracked `Task` during disconnect race** — ✅ **Resolved**

Explanation: `Task { [weak self] in await transport.disconnect(); self?.connectionState = .disconnected; Self.failPending(pendingToFail) }` is unowned. If a second `connect()` races the disconnect, `connectionState` writes interleave.

Suggestion: Serialize transport lifecycle inside the actor (or `@MainActor`) and `await` disconnect rather than detaching it.

Resolution: Added a `disconnectTask: Task<Void, Never>?` property on `LSPClient` (already `@MainActor`, so the property is serialized by main-actor isolation). `disconnect()` now short-circuits when `disconnectTask != nil`, so a second call during teardown returns instead of spawning a parallel transport-tearing Task. Both branches (`wasInitialized` and the not-initialized fallback) store their spawned Task into `disconnectTask` and clear it from the Task body's tail. Kept `disconnect()` sync rather than making it `async` — that would have rippled through `LSPClientRegistry` / `LSPManager` public APIs and four downstream sync callers (sample + tests) for no extra correctness, since `@MainActor` already prevents writers from interleaving outside of `await` suspension, and the new `disconnectTask` guard covers the only suspension window.

---

**[Medium] `Sources/CodeEditorLSP/LSPCompletionProvider.swift:~122` — Fire-and-forget document sync `Task`**

Explanation: `Task { try await lspManager.updateDocument(...) }` issues `didChange` asynchronously without ordering guarantees against subsequent completion/hover requests, so completion can request against an older document version than what the server has.

Suggestion: Serialize document sync through `LSPManager` (use a single per-URI actor or async sequence) and await sync before issuing dependent requests.

---

**[Medium] `Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift` — Actor state mutation around `await`**

Explanation: `activeRecoveries[recoveryId] = … → try await attemptRecovery(...) → activeRecoveries.removeValue(...)`. Actor re-entrancy means a second `recover()` call can see the in-progress entry. That can be intentional (it allows cancellation), but it isn't documented.

Suggestion: Add a one-line comment noting why the suspension is safe (or guard against re-entry for the same `recoveryId`).

---

**[Low] `Sources/CodeEditorSyntaxHighlighting/SyntaxHighlightingCoordinator.swift:32-49` — Cancel-outside-lock is intentional but easy to misread**

Explanation: Verified the code and its rationale comment (lines 22–24). `Task.cancel()` is thread-safe and idempotent; previous is captured under the lock and retained on the stack, so the cancel cannot race against another mutation. This is **not a bug** — but it's a frequent source of false-positive review flags. (One agent flagged it as Critical; that finding is incorrect.)

Suggestion: No change needed. Optionally inline the rationale next to the cancel call.

---

**[Low] `Sources/CodeEditorLayout/Glass/CompletionCellComponents.swift` — `@unchecked Sendable` on all-`let` struct**

Explanation: If every stored property is `let` and `Sendable`, the compiler will synthesize `Sendable` without `@unchecked`. Marking it `@unchecked` removes the compile-time check unnecessarily.

Suggestion: Drop `@unchecked`.

---

## 2. Modularity & Dependency Direction

**[Medium] `Package.swift:149-156, 332-336` — `CodeEditorLanguages` target lives at `Sources/CodeEditorPlugin/Languages`** — ✅ **Resolved**

Explanation: `CodeEditorLanguages` is a sibling SPM target but its source path is `Sources/CodeEditorPlugin/Languages`, and the umbrella target excludes that directory. `CLAUDE.md` explains the history, but the layout is structurally confusing for newcomers and complicates future moves.

Suggestion: Move to `Sources/CodeEditorLanguages/`, drop the `path:` override and the umbrella exclude line. (Same applies to Layout if it's still excluded for the same reason.)

Resolution: `git mv` of 73 tracked files (74 incl. an untracked `.DS_Store`) from `Sources/CodeEditorPlugin/Languages/` to `Sources/CodeEditorLanguages/`. Dropped the `path:` override on the target — it now follows the SPM default. Dropped both `"Languages"` and `"Layout"` from the umbrella's `exclude:` — the Layout entry was already dead (Layout was extracted in §6.2.11 and the empty leftover dir contained only a `.DS_Store` and an empty `Glass/`); `rm -rf` cleaned that out. The umbrella source tree now contains exactly `CodeEditorPlugin.swift` + `Resources/Info.plist`. CLAUDE.md, `docs/FeatureMatrix.md`, and `docs/Features/syntax-highlighting.md` were updated to the new path; archived plans/specs under `docs/superpowers/` and `docs/archive/` were left alone per the "archived working notes" convention.

---

**[Medium] `Sources/CodeEditorPlugin/CodeEditorPlugin.swift` — Doc promises a single-import surface, code doesn't `@_exported import` sub-targets** — ✅ **Resolved**

Explanation: The file's docstring shows `import CodeEditorPlugin` and uses `CodeEditor`, `CodeEditorView`, `EditorConfiguration`, etc. Without `@_exported import`, Swift module re-export of dependent modules is incomplete — consumers will usually also need explicit `import CodeEditorSwiftUI` / `import CodeEditorView`. This contradicts the stated quick-start.

Suggestion: Either add `@_exported import CodeEditorView` / `CodeEditorSwiftUI` / `CodeEditorConfiguration` / `CodeEditorTheming` / `CodeEditorLanguages` in this file, or update the docstring to show the multi-import reality.

Resolution: Added six `@_exported import` declarations for the targets the Quick Start docstring visibly uses: `CodeEditorCommon` (for `CodeEditorError`), `CodeEditorConfiguration` (`EditorConfiguration`), `CodeEditorLanguages` (`Language`), `CodeEditorSwiftUI` (`CodeEditor` view), `CodeEditorTheming` (theme types), `CodeEditorView` (`CodeEditorView` class). Opt-in subsystems (`CodeEditorAnnotations` / `CodeEditorCompletion` / `CodeEditorLSP` / `CodeEditorSearch` / `CodeEditorWorkspace` / etc.) stay explicit-import on purpose so the umbrella's surface area matches what the docstring actually documents. Added `UmbrellaReExportTests` (2 tests) — the test file imports ONLY `CodeEditorPlugin` and references each promised type by name, so a future regression that drops an `@_exported import` stops compiling. Side note unrelated to imports: the docstring example `config.display.theme = .dark` references a property that doesn't exist on `EditorConfiguration.Display`; left for the matching docstring fix in section 12 (Misc.).

---

**[Low] `Sources/CodeEditorUI` — `CodeEditorPlugin` dependency not imported in any UI source**

Explanation: `CodeEditorUI` declares `CodeEditorPlugin` as a dep in `Package.swift:344` but no `.swift` file in the target imports it; UI references `CodeEditorView`, `CodeEditorSwiftUI`, `CodeEditorSymbols`, `CodeEditorTheming`, etc. directly. Over-declaration inflates build closure.

Suggestion: Remove `CodeEditorPlugin` from the `CodeEditorUI` dependency list, unless it's there for re-export purposes (in which case document it).

---

**[Low] `Sources/CodeEditorTreeSitterLanguages` — Staging directory with no SPM target**

Explanation: Contains only `.gitkeep` and a planning README. `CLAUDE.md` confirms it's pre-staging; not a defect, just noted for awareness during future cleanup.

Suggestion: Either gate behind an opt-in target stub, or move the planning README into `docs/` until a target is wired.

---

## 3. Platform Abstraction

> **This dimension is clean.**

**[Style] Cross-target — Generally compliant** ✓

Explanation: `0` `#if os(macOS)` / `#if os(iOS)` in `Sources/`. `0` macCatalyst references. `759` `#if canImport(...)` blocks. Raw `NSColor`/`UIColor`/`NSFont` use is confined to platform-bridge files (`CodableColor`, `_GlassSurface`, `CodeEditorRenderingDiagnostics`) inside `#if canImport` guards. `PlatformColor`/`PlatformFont` are used consistently elsewhere.

Suggestion: No action required. Worth keeping the `canImport` discipline note in `CLAUDE.md` visible to future contributors.

---

## 4. Error Handling

**[Medium] `Sources/CodeEditorSearch/ProjectSearchProvider.swift:~152` — Invalid regex silently produces empty results** — ✅ **Resolved**

Explanation: `let regex = options.useRegex ? try? NSRegularExpression(...) : nil` swallows pattern errors. A user who types `[abc` gets zero matches with no signal that the pattern was rejected.

Suggestion: Throw a typed `SearchError.invalidRegex(reason:)` and surface it in the UI.

Resolution: Added `ProjectSearchError: LocalizedError, Sendable` (new file `Sources/CodeEditorSearch/ProjectSearchError.swift`) with a `.invalidRegex(pattern:, underlying:)` case. `search(query:options:)` now compiles the regex up-front — *before* detaching the background search task — and throws `ProjectSearchError.invalidRegex` if the pattern is malformed. `performSearch` gained a `regex: NSRegularExpression?` parameter so the compiled object travels with the search instead of being recompiled inside the detached closure. The sample app's `ProjectSearchModel` already routes thrown errors into `status = .error(message: error.localizedDescription)`, so the user-facing message now reads "Invalid regex pattern \"[abc\": …" instead of silent zero-results. Added `searchSurfacesInvalidRegexError` to `ProjectSearchProviderTests` to pin the contract.

---

**[Medium] `Sources/CodeEditorSearch/ProjectSearchProvider.swift:~161` — Unreadable file silently skipped** — ✅ **Resolved**

Explanation: `guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }` hides permissions/encoding failures. Useful as a degraded mode but should at least log.

Suggestion: `do { … } catch { logger.warning("Skipping \(fileURL): \(error)"); continue }`.

Resolution: Replaced the `try?`/`guard` with explicit `do/catch`; the catch branch emits `Logger.warning("Skipping unreadable file <path>: <error>")` and continues. `Logger` is `os.Logger` via `#if canImport(os.log)` — kept `CodeEditorSearch` Foundation-only (no new dependency on `CodeEditorCommon`'s `CrossPlatformLogger`, matching the target's documented decoupled stance). Logger is a `private static let` on `PortableProjectSearchAdapter` (not top-level — the codebase's `prefixed_toplevel_constant` lint rejects unprefixed top-level constants). Used `Self.` reference inside the static `performSearch` call site (`prefer_self_in_static_references`). Added `searchSkipsUnreadableFiles` to `ProjectSearchProviderTests` — writes a binary file with invalid UTF-8 alongside a readable text file, indexes both, verifies the search returns the text match without aborting on the binary skip.

---

**[Medium] Public throwing APIs missing `- Throws:` doc comments** — ✅ **Resolved**

Explanation: `ProjectSearchProvider.indexFiles(urls:)` / `.search(query:options:)` and several LSP client requests lack `/// - Throws:` lines despite documenting other behavior.

Suggestion: Add the throws clause and enumerate cases.

Resolution: Added `/// - Throws:` lines naming the concrete error cases on the methods the reviewer flagged: `ProjectSearchProvider.indexFiles(urls:)` + `.search(query:options:)` (protocol and `PortableProjectSearchAdapter`'s implementations, including the `urls:extensions:` overload), and the eleven public throwing methods on `LSPClient` + the `LSPClient+Transport` convenience `connect(configuration:languageId:)` overload — `connect`, `openDocument`, `updateDocument`, `closeDocument`, `requestCompletion`, `requestHover`, `requestDefinition`, `requestDocumentSymbols`, `requestSemanticTokens`, `requestSemanticTokensDelta`, `requestSemanticTokensRange`. Each `- Throws:` clause names the LSPError cases the body produces; the semantic-token requests' "returns nil if not initialized" pre-throw behavior is documented explicitly so callers know not to wrap it in `do/catch` just for the not-ready state. `LSPLanguageFeatures.parse*` static helpers are throwing but are lower-level building blocks of the request methods rather than "LSP client requests," and so were left for a future broader doc pass.

---

**[Medium] `Sources/CodeEditorLSP/LSPClient.swift` — Bare `Error` caught and rethrown without recovery** — ✅ **Resolved**

Explanation: Several `catch`es log and rethrow the underlying `Error` without typing or wiring into `ErrorRecoveryCoordinator`. LSP transport errors are exactly the recoverable-with-backoff case the recovery infrastructure was built for, but it isn't used here.

Suggestion: Wrap network-facing operations in `ErrorRecoveryCoordinator.recover(strategy:)` with the existing `BackoffStrategy`.

Resolution: Made `LSPError` conform to `RecoverableAsyncError` (added an extension in `LSPProtocol.swift` after the existing `LocalizedError` conformance, imported `CodeEditorCommon` for the recovery types). The conformance categorizes each case: `.connectionFailed`, `.timeout`, and `.serverError` with codes in the JSON-RPC/LSP reserved internal band (-32603 plus -32099…-32000) are retryable; protocol-contract violations (`.invalidResponse`, `.decodingError`), state-machine misuses (`.notConnected`, `.alreadyConnected`), and config errors (`.transportNotConfigured`) are non-retryable. Retryable cases ship two strategies — `.retry(maxAttempts: 3, backoffStrategy: .exponential(initial: 1s, multiplier: 2, maxDelay: 30s))` at priority 20, then `.reportToUser` at 10. Non-retryable cases ship only `.reportToUser`. Did **not** wrap the bare `catch` blocks inside `LSPClient.connect()` because `LSPClientRegistry.startLanguageServer` already drives connect-level retries via `LSPRetryConfiguration` — adding a second recovery layer inside the client would compound retries. The conformance makes the *typed recovery surface reachable* from any future LSP-facing call site (per-request hosts, background-only services) without coupling `LSPClient` to `ErrorRecoveryCoordinator`. Added `LSPErrorRecoveryTests` (6 tests) covering the retryable/non-retryable classification per case, including a live end-to-end test that runs a fails-twice-then-succeeds operation through `ErrorRecoveryCoordinator.recover(from:operation:)` and asserts the operation was invoked three times (~3s runtime — exercises real exponential backoff).

---

**[Low] No `try!` and no force-unwraps detected in framework code** ✓

Explanation: Spot-grepped — clean. `fatalError`/`preconditionFailure` are confined to (a) `init?(coder:)` overrides marked `@available(*, unavailable)` and (b) one defensive `CodingUserInfoKey` init whose surrounding comment explains it's unreachable.

Suggestion: Keep current discipline.

---

## 5. Configuration System

Did not surface specific findings from this round; the agents that scoped to it didn't return defects. A targeted follow-up review would be needed to verify the boundary-validation contract for every nested struct (`Layout`, `Display`, `Behavior`, `Performance`).

---

## 6. Dependency Injection

**[Style] No singletons detected** ✓

Explanation: Spot-checked `ActorCoordinator.create()` factory pattern and `@Dependency` use; no `static let shared`.

Suggestion: No action.

---

## 7. Performance Patterns

**[High] `Sources/CodeEditorTextModel/ParagraphStyleCache.swift:~113` — O(n) LRU update per cache access** — ✅ **Resolved**

Explanation: `markAccessed(_:)` does `accessOrder.removeAll { $0 == key }` + `append`. Each cache hit is O(n) in cache size. Paragraph styles are looked up extremely frequently during layout, so this is a hot-path quadratic.

Suggestion: Replace `[CacheKey]` + `[CacheKey: Value]` with a proper LRU (e.g., doubly-linked list + dictionary). For a 50-entry cache, even moving to `OrderedDictionary` from `swift-collections` beats the current pattern.

Resolution: Replaced `[CacheKey: NSParagraphStyle]` + `[CacheKey]` with a doubly-linked-list LRU: a private `Node` class with `prev`/`next` pointers, plus `nodes: [CacheKey: Node]`, `head`, and `tail`. All operations (insert, hit/touch, evict) are now O(1) under the same `cacheQueue` serial dispatch queue. Kept the helper inline (not extracted to a shared type) — when the next issue (`LayoutCache` O(n) LRU) lands, if the pattern is identical I'll pull both into a shared `LRUCache` in `CodeEditorCommon`. Added `testLRUEvictsLeastRecentlyAccessed` to lock the eviction order — the existing tests only verified hit/miss identity, which a future regression that swapped eviction order would still pass.

---

**[High] `Sources/CodeEditorLayout/LayoutCache.swift:~75` — Same O(n) LRU pattern as `ParagraphStyleCache`** — ✅ **Resolved**

Explanation: Layout cache uses the same `accessOrder.removeAll { … }` pattern, hit per viewport update / bounds change.

Suggestion: Refactor both caches to share a tested LRU helper.

Resolution: Extracted a generic doubly-linked-list LRU as `LinkedLRU<Key, Value>` in `CodeEditorCommon` (deliberately distinct from the existing `CodeEditorDiagnostics.LRUCache` — that one is `@MainActor`, memory-monitor-aware, and Value-must-be-Sendable, none of which fits the layout-hot-path callers). Both `ParagraphStyleCache` and `LayoutCache` now wrap `LinkedLRU`; the cache classes themselves shrank to thin coordinators over the shared structure. Added a focused `LinkedLRUTests` suite (10 tests) covering hit/miss promotion, capacity eviction, mid-list removal, predicate-based bulk removal, and the post-`removeAll()` re-insert path. Existing `ParagraphStyleCacheTests` and downstream concurrency/highlighter suites all still pass.

---

**[High] `Sources/CodeEditorSyntaxHighlighting/SmartTokenCache.swift:~350` — `evictLeastValuableEntry` sorts the whole cache per eviction** — ✅ **Resolved**

Explanation: `cache.sorted { … }` is O(n log n) per eviction; the eviction loop can run many iterations under memory pressure.

Suggestion: Maintain a min-heap keyed by the "value" metric; eviction becomes O(log n) per entry.

Resolution: Two fixes in one pass: (1) `evictLeastValuableEntry` now uses `cache.min(by:)` — O(n) per eviction, no allocation; (2) deleted the `accessOrder` array entirely (declaration + 8 write sites): every reference was a write, nothing ever read it, so the cache was paying an O(n) `removeAll { $0 == key }` on every cache get/set/eviction to maintain dead state. Skipped the suggested min-heap because the score formula's `ageFactor` is time-volatile — every entry's score shifts each tick, which would require constant heap re-sifting and wipe out the asymptotic win at the default 50-entry capacity. Net per-eviction work drops from O(n log n) + O(n) (sort + accessOrder removeAll) to O(n) (single min scan); per-cache-access work drops by an O(n) `accessOrder.removeAll + append`. All existing `SmartTokenCacheCoverageTests` (5) and eviction-behavior coverage in `AsyncSyntaxHighlighterCacheTests` (12) still pass.

---

**[Medium] `Sources/CodeEditorSyntaxHighlighting/SmartTokenCache.swift` — Fingerprint may survive partial-range edits** — ✅ **Resolved (documentation path)**

Explanation: FNV-1a over the whole document plus length is reasonably collision-resistant but does not encode which range changed. An entry tied to a stale viewport-partial tokenization could survive a small edit that happens to keep the global fingerprint stable for that range.

Suggestion: Key entries by `(documentVersion, range)` and invalidate by `editedRange` directly on each edit. Document the `version` field rather than the `version: 0` placeholder.

Resolution: Took the smaller of the reviewer's two suggested paths — documentation, not architectural rework. Added a class-level docstring on `SmartTokenCache` that names the staleness model explicitly (FNV-1a is collision-resistant in aggregate but doesn't encode *where* an edit happened). Replaced the unannotated `package let version: Int` with a per-field docstring that names it as a placeholder hook: every in-tree call site passes `0`, so the fingerprint is the sole invalidation signal in practice; the slot is wired into the key on purpose so a future edit-driven-invalidation pass can thread a real monotonic version through `OptimizedSyntaxHighlightingCoordinator.highlight(...)` and the prefetch path without changing the type's shape. The companion `invalidate(editedRange:)` method the reviewer suggested was *not* added — it would be unused dead API by the local-fix-scope rule ("don't design for hypothetical future requirements"); the docstring records the intent, and any future plumbing PR will add the method with its first real caller. The architectural rework (`(documentVersion, range)` key + edit-range invalidation) requires touching upstream callers in `CodeEditorView` and is appropriately deferred to its own dedicated session.

---

**[Medium] `Sources/CodeEditorDiagnostics/MemoryMonitor.swift:~321` — Cleanup-handler API doesn't enforce weak capture** — ✅ **Resolved (documentation path)**

Explanation: `registerCleanupHandler(handler: @escaping @MainActor @Sendable () async -> CleanupResult)` strongly captures whatever the closure does; callers must remember `[weak self]`. Easy retain-cycle footgun.

Suggestion: Document the requirement prominently, or accept a `Weak<Owner>`-style wrapper and pass it to the closure.

Resolution: Took the documentation path of the reviewer's two options. The `Weak<Owner>` wrapper alternative would have added a typed overload that no caller exercises yet, violating the project's "don't design for hypothetical future requirements" rule. Replaced the bare three-line method docstring with a prominent `- Important:` block on `registerCleanupHandler` that names the failure mode in plain language ("the owner cannot deinit while the handler is registered"), lays out the two requirements every caller must meet (capture weakly **and** unregister in the owner's teardown path), and cross-references the canonical example in the class-level docstring. The `handler:` parameter doc now ends with **"Must capture any owner weakly."** so it's visible right at the call site in Xcode's signature popover. Verified the existing call sites (`IOSLargeFileOptimizer`, `MemoryManagementCoordinator`, `AsyncSyntaxHighlighter`, `CodeFoldingEngine`, `TextKit2RenderingOptimizer`, `CompletionManager`, `LRUCache`, `LSPManager`) all already use the `[weak self]` + unregister pattern — the existing 8 `MemoryLeakTests` pass.

---

**[Low] `Sources/CodeEditorView/IOSLargeFileOptimizer.swift:~18-24` — Hardcoded iOS thresholds without device-tier scaling**

Explanation: `optimizationThreshold = 1MB`, `maxHighlightingRange = 100KB`, `viewportExpansion = 0.5` — no rationale, no device scaling.

Suggestion: Derive from `ProcessInfo.processInfo.physicalMemory` or document the iPhone/iPad RAM tiers these were calibrated against.

---

## 8. LSP Integration

**[Medium] `Sources/CodeEditorLSP/Transport/WebSocketPinningDelegate.swift:46-51` — `validateSSLCertificates=false` is a hard bypass** — ✅ **Resolved**

Explanation: Verified the code. The bypass is intentional, gated by an explicit caller opt-in, logged as a warning, and documented in the surrounding comments — it is **not** a covert misconfiguration as one agent characterized it. However, the bypass is coarse (skips even system trust evaluation) and global per-session, which is a footgun.

Suggestion: Either (a) require a per-host allowlist (`allowSelfSigned: Set<String>`) instead of a global boolean, or (b) at minimum, evaluate system trust first and only skip the pinning policy on the flag — never skip system trust. The latter is a small refactor against the existing structure.

Resolution: Implemented option (b). `WebSocketPinningDelegate.urlSession(_:didReceive:completionHandler:)` now runs `SecTrustEvaluateWithError` **unconditionally** and rejects the challenge on failure — the `validateSSLCertificates` flag no longer bypasses platform trust. The flag's role narrows to: when `false` *and* `pinning` is configured, skip the pin check with a logged warning (the dev-time escape hatch for rotating pinned material without breaking running clients); when `false` with no pinning configured, the flag is now a no-op since system trust suffices on its own. The class-level docstring spells the new policy out in three numbered steps; the public `RemoteLSPConfiguration.validateSSLCertificates` field docstring is updated to flag that self-signed dev servers must now be added to the system keychain rather than papered over with a global boolean. **This is a behavior change for callers who relied on `validateSSLCertificates = false` to accept untrusted certs** — the original behavior was the footgun the reviewer flagged, so the change is the intended fix. The existing `WebSocketTransportSecurityTests` cover configuration plumbing (still all 4 passing); the new challenge-handling policy is documented inline because reliably exercising it from a unit test would require mocking `URLAuthenticationChallenge` (not viable without test infrastructure changes out of scope here).

---

**[Medium] `Sources/CodeEditorLSP/LSPMessageHandler.swift:~56-91` — Malformed `Content-Length` wipes the entire buffer** — ✅ **Resolved**

Explanation: On parse failure, `messageBuffer.removeAll()` is invoked, which discards any subsequent well-formed messages already in the buffer.

Suggestion: Find the next `\r\n\r\n` boundary and resume parsing from there, or terminate the connection and reconnect — but don't silently nuke pending messages.

Resolution: Replaced both `messageBuffer.removeAll()` calls (the header-decode-failure and Content-Length-parse-failure paths) with a new `recoverFromMalformedFraming(skipPast:)` helper that scans for the next `Content-Length:` marker starting after the malformed header's `\r\n\r\n` boundary and drops bytes up to (but not including) it. Only when no subsequent marker exists does the buffer fall back to the prior wipe behavior. Searched-for marker is the bare `Content-Length:` keyword (not `\r\nContent-Length:`) because LSP frames concatenate body-then-next-header with no separator — a leading-CRLF marker never matches at real message boundaries; accepted false-positive risk in the pathological case where a JSON body literally contains the string is documented in the helper's docstring. Also restructured `extractCompleteMessage()` into an internal `while true` loop so the recovery path's advance is immediately re-attempted instead of returning `nil` and waiting for the next transport callback — without that, recovery would advance the buffer but consumers wouldn't see the now-parseable message until more data arrived. Added `LSPMessageHandlerRecoveryTests` (4 tests): back-to-back-good ordering, bad-Content-Length recovers the next message, non-UTF-8 header bytes recover the next message, unrecoverable buffer clears as fallback and the handler stays usable for subsequent traffic. All 40 LSP suite tests pass.

---

**[Medium] `Sources/CodeEditorLSP/LSPMessageHandler.swift:~161` — String request IDs coerced to `Int`, non-numeric strings dropped** — ✅ **Resolved**

Explanation: LSP spec allows string IDs; this transport rejects them. Servers that emit UUID-style IDs (or future client code that uses them) will see their responses silently dropped, causing the caller to hang until timeout.

Suggestion: Use `enum RequestID: Hashable { case int(Int); case string(String) }` (or `AnyHashable`) as the pending-request key.

Resolution: The wire-level `RequestId` enum (already defined in `LSPTypes.swift` with `.string(String)` and `.number(Int)` cases for `Codable` round-tripping) gained `Hashable` conformance and is now used as the routing-layer key. `LSPClient.pendingRequests` switched from `[Int: LSPRequestCompletion]` to `[RequestId: LSPRequestCompletion]`; `handleResponse(id: Int, ...)` to `(id: RequestId, ...)`; `failPending(_:)` parameter type to match. `nextRequestId` stayed `Int` (it's a local counter — the wrapping into `.number(...)` happens at the send site, matching the spec's "you choose your own ID format" model). `LSPMessageHandler.onResponse` callback signature updated to `(RequestId, Result<...>) -> Void`; `extractRequestId(from: Any) -> RequestId?` now preserves string IDs verbatim (including numeric-looking ones like `"42"` — they stay `.string("42")`, never collapse to `.number(42)`, so a server can't accidentally collide a string ID with a pending numeric request). Added `testStringRequestIdResponseRoutesToInbox` and `testNumericStringRequestIdIsNotCoercedToInt` to `LSPMessageHandlerRecoveryTests`. 36 broader LSP tests still pass.

---

**[Medium] `Sources/CodeEditorLSP/LSPClient.swift` — `nextRequestId` overflow + thread-safety** — ✅ **Resolved**

Explanation: `Int` counter without overflow guard, mutated outside a clearly named isolation domain. Overflow is a theoretical concern for very long-lived sessions; thread-safety is the more immediate one.

Suggestion: Move into the actor and reset / use UUIDs.

Resolution: The thread-safety half of the concern was already covered — `LSPClient` is `@MainActor` (class declaration), so every access to `nextRequestId` is MainActor-isolated; the reviewer flagged this because the isolation wasn't documented at the field. Spelled out the @MainActor isolation directly in the field's docstring so future readers don't need to cross-reference the class header. Extracted a small `allocateRequestId() -> RequestId` helper that consolidates the read-then-increment policy in one place and adds the overflow guard: wraps to 1 when the counter would otherwise overflow at `Int.max`. The realistic risk of reaching that ceiling is zero (`Int64.max` requests at 100K req/s would take ~2.9 trillion years), but the explicit guard prevents trap behavior on pathological long-lived sessions; any pending entries from before the wrap will have completed long ago by definition. UUIDs (the reviewer's other suggestion) were considered and skipped — real-world LSP servers handle numeric IDs more uniformly than string ones, and the prior fix to preserve `RequestId.string` already lets servers send string IDs if they want; the *client*-generated counter staying numeric is the safer interop choice. `sendRequest` is now a one-liner against the helper. All 42 LSP suite tests still pass.

---

**[Medium] `Sources/CodeEditorLSP/Transport/ProcessTransport.swift` — `stderr` handler runs on dispatch queue without offloading** — ✅ **Resolved**

Explanation: `stderrPipe.readabilityHandler` logs synchronously on `FileHandle`'s dispatch queue while `stdout` handler dispatches to a `Task`. A chatty server emitting MB/s of `stderr` could starve `stdout` reads.

Suggestion: Mirror the `stdout` path — dispatch `stderr` drains into a `Task`.

Resolution: Restructured `attachStderrLogging()` to mirror the `startReading()` stdout path: `[weak self]` capture in the `readabilityHandler`, `Task { [data] in await self.deliverStderrData(data) }` bounce, plus a new private `deliverStderrData(_:)` async method that runs on actor isolation. The async hop is what gives the asymmetry-fix its teeth: stdout and stderr now share the FileHandle's private dispatch queue *only* long enough to grab the bytes, then both deliveries are serialized through the actor, so a chatty stderr can't backpressure the stdout reads. EOF semantics matched (empty data clears the handler). No new test — verifying the no-starvation property end-to-end would need an integration test with a real chatty server; the structural symmetry with the stdout path is the verification and the 30 broader LSP suite tests pass.

---

**[Low] `Sources/CodeEditorLSP/LSPClient.swift` — `deinit` cannot run async cleanup**

Explanation: Documented limitation — pending requests can outlive client release if `disconnect` wasn't called. Acceptable design, but should be enforced.

Suggestion: Add a `@MainActor`-callable `shutdown` method and assert at `deinit` time that pending requests are empty (or warn).

---

## 9. Code Organization, Naming, Docs

**[Medium] Public types missing top-level doc comments**

Explanation: Spot check found `CompletionManager`, `LanguageDetectionService`, and `MacOSWorkspaceFileManager` without `///` headers. These are publicly visible.

Suggestion: Add 1–3 line `///` headers describing role and ownership.

---

**[Low] Public getter methods with `get*` prefix violate Swift API Design Guidelines**

Explanation: Found ~10, including `getCachedCharacterWidth()`, `getCompletionTriggerCharacters()`, `getLineAndColumn()`, `getCurrentLine()`, `getRecentEvents()`, `getEvents<T>()`. Swift convention is property-style for parameter-less accessors, noun-style for parameterized ones.

Suggestion: Rename per call site; for public ones, deprecate the old names and add forwarding shims for a release.

---

**[Low] `Sources/CodeEditorView/Platform/ToolbarCoordinator.swift:464` — Bare `TODO` without tracking issue**

Explanation: `// TODO: Add keyboard shortcut support` with no issue reference. `CLAUDE.md` doesn't require issue refs, but this one's been around long enough to deserve one (or removal).

Suggestion: File an issue or delete the `TODO`.

---

## 10. SwiftLint Compliance & Custom Rules

**[Style] `swiftlint --strict` — 0 violations across 828 files** ✓

Explanation: Verified by running `swiftlint lint`. All custom rules (`no_print_statements`, `forbidden_text_view_delegate_assignment`, `forbidden_swiftui_extension_codeeditor`, `force_unwrapping`) pass.

Suggestion: None.

---

## 11. Testing

The dispatched investigations did not deep-dive testing; I did not run `swift test --parallel` as part of this review (the user requested review, not regression verification). A separate follow-up to assert that:

- Every `@unchecked Sendable` class has a concurrent-access test
- The LSP message parser has fragmentation tests (partial header, multiple messages per read)
- `MemoryMonitor` cleanup-handler retain cycles are tested

would meaningfully complement this review.

---

## 12. Miscellaneous

**[Low] `Sources/CodeEditorPlugin/CodeEditorPlugin.swift:32` — Demo code in doc comment uses `logger.debug(...)` as if `logger` were imported**

Explanation: The Quick Start snippet uses `logger.debug("Hello, World!")` with no surrounding context that would make `logger` resolvable. A first-time reader copy-pasting the snippet will get an error.

Suggestion: Use a string literal or define `logger` in the snippet's context.

---

**[Low] No `print()` in production code, no stale commented-out blocks** ✓

Explanation: Verified.

Suggestion: None.

---

## Summary

| Severity | Count |
|:---------|:------|
| Critical | 0 |
| High | 0 — 6 resolved (AwaitableQueue contract, RangeProcessor Task leak, LSPClient disconnect Task, ParagraphStyleCache LRU, LayoutCache LRU via shared `LinkedLRU`, SmartTokenCache eviction + dead `accessOrder`) |
| Medium | 0 — 13 resolved (Languages path + dead Layout exclude, umbrella re-export, search invalid-regex error, search unreadable-file logging, throwing-API doc comments, LSPError recovery conformance, WebSocket pinning bypass narrowed, LSP buffer recovery, LSP string request IDs, LSP nextRequestId overflow + isolation doc, ProcessTransport stderr offload, SmartTokenCache version docstring, MemoryMonitor cleanup-handler doc) |
| Low | 9 (cache scaling, getter naming, undocumented public types, etc.) |
| Style | 5+ (compliance confirmations) |

### Overall Assessment

Ship-ready, with a recommended pre-release sweep of:

1. **The three O(n) LRU caches in the hot path** — easy wins, real user-visible impact for large documents.
2. **The LSP transport hardening:** malformed-header recovery, string-ID support, system-trust-always-on, stderr offload.
3. **The `AwaitableQueue` `@unchecked Sendable` contract** (either enforce isolation in the API surface or lock the backing array).
4. **Add the missing `@_exported import`** in `CodeEditorPlugin.swift` or align the docstring with the actual multi-import surface.

The codebase is unusually disciplined for its size: zero SwiftLint violations under strict mode, zero `#if os()` violations, zero force-unwraps, zero `try!`, no detectable singletons, and consistent dependency layering across 18 SPM targets. The remaining issues are localized engineering tasks, not architectural rework.

Two agent claims I downgraded after verification: the `HighlightingTaskManager` cancel-outside-lock pattern is documented and correct (`cancel` is thread-safe + idempotent; the previous reference is retained on the stack), and the `WebSocketPinningDelegate` cert bypass is an explicit caller opt-in with a logged warning — not a covert defect, though the bypass is too coarse-grained.
