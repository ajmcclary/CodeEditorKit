# Changelog

All notable changes to CodeEditorKit are documented in this file.

Entries dated before the 2026-07-25 rename deliberately keep the package's
former name, `CodeEditorPlugin` — they record what shipped at the time.

## [Unreleased]

### Fixed

- **A memory cleanup pass keeps the user's undo history.** The editor's
  cleanup handler discarded it on every pass (the window's whole stack
  before 0.1.0-beta.15), and passes are routine: `MemoryMonitor` compares
  the whole process's resident memory with its 100 MB threshold, which an
  app embedding the editor is always over. The default
  `MemoryManagementPolicy.live` no longer needs to be avoided for this.
- **Other cleanup handlers release only caches.** A pass no longer
  disconnects language servers or drops their configurations and open
  documents (`LSPManager`), cancels the completion request in flight
  (`CompletionManager`), cancels background highlighting requests
  (`BackgroundSyntaxHighlighter`), or, on iOS, discards undo history.
- **A pass keeps the learned completion ranking.** The learned selection
  counts lived in an `LRUCache` that every pass trimmed by a quarter (all of
  them when there were few), so the learned order reverted to alphabetical;
  they are no longer released by memory cleanup at all.

### Changed

- **Automatic cleanup is edge-triggered and rate-limited.** It runs when the
  footprint first goes above `memoryThresholdMB`; while it stays above, again
  only after growing by half the threshold or when the provider reports
  `.critical`, and never within the new
  `MemoryMonitor.minimumAutomaticCleanupInterval` (default 60 s) of the last
  automatic pass, including after a dip below the threshold re-arms it. It
  used to run on every 10 s check. `.critical` is not a system
  memory-pressure event: `SystemMemoryProvider` reports it when this
  process's resident memory is at least 85 % of physical RAM. The periodic
  pass (`enablePeriodicCleanup`, every 5 minutes) is unchanged.

## [0.1.0-beta.15] - 2026-11-13

This release remediates the 2026-11-12 full review of the package.

### Changed

- **Each editor owns its undo manager.** `CodeEditorView.undoManager` is the
  editor's own stack, not the window's, unless a delegate participant
  supplies one, and `EditorController.clearUndoHistory()` clears only that
  editor. When the host swaps the text (new text that is not an echo of the
  editor's own write), the editor's undo history is cleared, so undo can no
  longer reach into the previous document's text (it used to raise
  `NSRangeException`).
- **Undo and redo reach the host.** A TextKit 2 text view applies undo
  without calling `didChangeText`, so `onTextChange` and the text binding
  never saw an undo or a redo; the editor now announces them.
- **A host that rewrites the editor's write keeps undo.** A host that
  normalises what the editor sent (trimming, reformatting) has its rewrite
  applied as an undoable edit of the span that differs, and undo and redo
  take the rewrite and the edit it answered together (macOS). New host text
  that matches no outstanding write and shares less than half of the newest
  write is the host's own change: it replaces the text and discards undo.
- **A bound cursor is applied only when the host changes it.** The editor no
  longer pushes its own echoed cursor back into the view, which reordered
  typed characters (`hello` typed as `elloh`) and reset the selection on
  every re-render. A host that writes the same cursor value again to
  "re-apply" it no longer moves the caret.
- The text binding contract is now stated in the `CodeEditor` doc comment.
  Host text unchanged since the last render never overwrites newer typing,
  and up to four editor writes awaiting their echo are recognised, so a host
  that applies writes late keeps every keystroke.
- **Replace and Replace All go through the text view's change path**
  (`shouldChangeText`, one storage edit, `didChangeText`). Each is one undo
  step, reaches the host and honours the delegate's gating. Replace All
  keeps the selection where it was, adjusted for the edit, and is linear in
  the number of matches. Replace refuses a result that no longer matches
  under its search options.
- **Fold detection, Swift highlighting and Find run off the main thread**,
  on a snapshot of the text. A result computed for text that has changed
  since is dropped; Find re-runs, up to three times, and a newer Find cancels
  the older one.
- **`CodeFoldingProvider` is no longer `@MainActor` and requires
  `Sendable`.** This is the one non-additive API change. The requirement is
  unchanged; a conformer must be `Sendable` and must not rely on main-actor
  state, because detection now calls it off the main thread.
- **The LSP client holds a session with a real server.** It answers server
  requests (`null` for capability registration, progress creation and the
  refresh family, one `null` per item for `workspace/configuration`, the
  folders for `workspace/workspaceFolders`, `-32601` for anything else). Each
  of its own requests times out after 30 s (`LSPError.timeout`) and is
  cancelled with its task, sending `$/cancelRequest`. A `null` result decodes
  as absent (no hover, no definition, no symbols) instead of raising, and
  spec-optional, `Bool`-or-options and unknown enum values decode instead of
  failing the message. `decode(as:)` on a `null` result now throws
  `LSPError.decodingError`.
- **A language server that exits is reported, not restarted.** Pending
  requests fail with `.connectionFailed`, `connectionState` moves to
  `.error` and then `.disconnected`, and `serverExitedUnexpectedly` is set
  until the next successful connect. Nothing restarts the server; the
  `LSPManager` documentation no longer claims it does. A host can offer a
  restart from the new flag.
- `ClientCapabilities.default` no longer advertises `dynamicRegistration`
  (completion, hover, definition), `workspace.configuration` or
  `snippetSupport`.
- Document URIs sent to servers are percent-encoded file URLs, and
  `LSPClient.diagnostics` is keyed by that canonical form.
- `LSPManager.isDocumentOpen(filePath:)` is true while an open is in
  flight. Opening a document that is already open, or being opened, sends
  one `didOpen` and then changes; a close waits for an in-flight open.
- `WebSocketTransport` refuses a send while disconnected (`notConnected`)
  instead of queueing it and reporting success. With an owning `LSPClient`, a
  dropped socket ends the session instead of reconnecting silently to an
  uninitialised server.
- Completion: the popup filters as you type and is dismissed when the caret
  leaves the word, a non-word character is typed, nothing matches, scrolling
  starts or the editor loses focus. Return inserts the selected item,
  replacing the typed prefix (from the built-in list it inserted nothing).
  Snippet syntax is never inserted (`print()`, not `print($0)`).
- Limits on pathological input:
  - JSON nested deeper than 128 levels gets the line-by-line outline instead
    of a parsed one.
  - Swift nested deeper than 64 brackets, or with more than 16 `[` open at
    once, falls back to the keyword (regex) highlighter. Every SwiftSyntax
    parse runs on its own 16 MB-stack thread with a 128-level parser cap.
  - A document outline keeps at most 10,000 symbols and 64 nesting levels.
  - Fold detection is skipped for documents over 4M UTF-16 units. Brace and
    Markdown fold titles are at most about 120 UTF-16 units, and brace
    regions that open and close on one line are not reported.
- Project search: `column` is a 1-based UTF-16 column (it was a Character
  distance), and files over `maxFileSizeBytes` (8 MB by default) are skipped.
- Annotations: the data source is asked for views only on add,
  `reloadAnnotations()` or re-enabling, not on every layout pass; a host
  that changes annotation content must call `reloadAnnotations()`.
- `sizeThatFits` with an unspecified dimension returns an estimate instead
  of measuring every line, and the accessibility label no longer includes a
  word count.
- Requires ProcessKit 0.1.0-beta.6 and WorkspaceKit 0.1.0-beta.11.

### Added

- `HighlightProviderDeclined` (`CodeEditorHighlightingCore`): a
  `HighlightRangeProviding` conformer throws it from `highlights(in:of:)` to
  have the built-in highlighter answer that query. An empty array still
  means "no highlights". A provider's `CancellationError` is now asked again
  on the next pass instead of being reported as a failure.
- `FoldableRegion: Sendable` and `SearchResult: Sendable`.
- `LSPClient.serverExitedUnexpectedly` (`@Published`, read-only) and
  `LSPManager.serverExitedUnexpectedly(for:)`.
- `ProjectSearchOptions.maxFileSizeBytes`, with a defaulted `init`
  parameter.
- `LSPManager.isDocumentOpen(filePath:)`, `LSPResponse.decodeIfPresent(as:)`
  and `isNullResult`, `ServerCapabilities.semanticTokensLegend` (with a
  defaulted `init` parameter), and `LSPTransport.setDisconnectHandler(_:)`
  (default implementation does nothing; a custom transport should implement
  it to report that its peer closed).

### Fixed

- Editing: the caret survives a re-render in a CRLF document; a
  configuration change, or removing the editor, inside the binding debounce
  keeps the last keystroke; a host replacement leaves a valid caret; a
  re-parented editor keeps its delegate and features; re-attaching a
  controller to the view it holds is a no-op; `autoScrollToCursor` no longer
  pulls the view back to the caret on every scroll.
- Folding: chevrons are drawn on the 1-based line a region starts on (a
  region on line 1 gets one), toggling a line folds only the innermost region
  there, `isFolded(at:)` is true inside a folded region, regions appear in
  short documents and after typing, edits shift existing folds instead of
  dropping them, and unfolding restores the paragraph style and foreground.
  Gutter queries use a line index instead of rescanning the text; fold all
  and the fold-store rebuild are one update. Brace folding takes a region's
  type and title from its opening line and is linear on one long line (a
  200 KB minified JSON took 135 s); XML folding is linear, UTF-16 correct
  and the same for LF and CRLF; Lua folds CRLF files.
- Find and replace: Find scans in one pass (32,000 matches in about 0.3 s
  in a debug build), counts CRLF as one line break, finds regex matches of
  the empty string again, and highlights without a layout pass per match.
  The search flash is safe after Clear or an edit.
- Outline: a ~200 KB JSON document crashed the editor with a stack overflow
  in the symbol index, and deeply nested JSON or Swift crashed the parser.
  The symbol index is now balanced and iterative, the outline tree is built
  in one pass (it dropped grandchildren and was quadratic), and the JSON
  provider walks with an explicit stack.
- Highlighting: SwiftSyntax tokens and comments are placed at their own
  text, not their trivia; the Swift async highlighter parses an immutable
  snapshot; regex language definitions compile once per process and digit
  runs no longer backtrack; regex capture offsets map to UTF-8 in one pass;
  `FastJSONTokenizer` no longer serves a stale range-keyed cache.
- Language providers: a single-line CSS `@media` rule no longer traps, and
  carries its condition; XML symbols on a minified line are linear and
  UTF-16; the keyword completion provider filters by the word before the
  cursor; cached completions are keyed on the whole document.
- LSP: `Content-Length` must be all digits, a frame over 64 MiB fails the
  stream, and header names compare case-insensitively; semantic-token deltas
  apply against the original array and token types are named by the server
  legend; positions use the LSP line model (CRLF and lone CR); concurrent
  starts of one language share one attempt; `ProcessTransport` teardown
  reaps the child exactly once and a blocked write no longer blocks the
  transport; `LSPContentCoordinator` holds its manager weakly; a failed
  server start leaves the document closed and reopening re-sends the latest
  text.
- Per-keystroke and layout cost: re-applying the same theme no longer
  restamps the document, sizing and the accessibility label no longer walk
  the whole document, wrapped layout is invalidated only when the wrapping
  width changes, and DEBUG rendering diagnostics no longer force a
  full-document layout.
- Lifetimes and cleanup: a memory-pressure pass no longer unfolds the user's
  folds or clears other editors' undo; `LinkedLRU` no longer leaks every
  entry; observers and cleanup handlers are removed when their owners go;
  `BackgroundProcessor` cancels the real operation without corrupting its
  count; cancelling a `KeyedDebouncer.run` caller cancels its operation;
  `AsyncOperationManager` handles a zero batch size, cancelled schedules and
  shared throttled runs; the completion popup window is no longer
  over-released on dismissal.

## [0.1.0-beta.14] - 2026-11-12

### Changed

- `layout.textContainerInset` now takes effect on macOS, on all four edges.
  Each edge is **added to the editor's own text padding**: `lineNumberPadding`
  on the left and right (in full while line numbers are shown, halved while
  they are hidden, as before) and nothing above or below. So `top` and
  `bottom` are the whole vertical padding, and `left` and `right` are extra
  room beyond what `lineNumberPadding` already gives. `lineNumberPadding`
  keeps exactly the effect it had. `top` and `bottom` scroll with the
  document; `right` narrows the wrapping width when `wrapLines` is on and is
  the room after the longest line when it is off. Negative edges count as
  zero. iOS still does not apply the value.
- **The default inset is now zero** (`PlatformConstants.defaultTextContainerInset`
  and the `Codable` fallback for a missing key were 8 on every edge). The old
  default was never drawn on macOS (no vertical padding, `lineNumberPadding`
  horizontally), so zero is what makes a host that never sets the inset render
  exactly as it did. A host that persists `EditorConfiguration.Layout` through
  `Codable` has the old 8s in its saved data and will now see them as 8 points
  of extra padding on each edge; reset the stored inset to zero on upgrade to
  keep the previous rendering.
- `CodeEditorContainerView` now owns all four edges of its text view's inset.
  It used to set only the width and leave whatever height it found, so a host
  that set a vertical `textContainerInset` on the container's `NSTextView` by
  hand should move that value into `layout.textContainerInset`.
- `CodeEditorView.unifiedTextContainerInsets` and
  `setUnifiedTextContainerInsets(_:)` carry four independent edges on macOS.
  They used to collapse to `NSTextView`'s symmetric inset (`left` and `top`
  only). `NSTextView.textContainerInset` cannot hold four edges, so the view
  keeps the mean of each pair there and overrides `textContainerOrigin` to
  move the text by the difference; with equal edges the override returns
  AppKit's own value.

### Fixed

- Everything the editor places over its text on macOS now starts from
  `textContainerOrigin` instead of assuming it equals the symmetric inset (or
  assuming no vertical inset at all): inline annotation badges, the
  selected-line highlight, the completion popup, line positions and
  point-to-line lookups (`LineNumberCalculationService`,
  `TextKitLineNumberHelper`, and with them fold-control clicks in the
  gutter), the visible range (`TextKitBridge.visibleRange`) and the rendering
  diagnostics. With the default inset the only visible difference is the
  completion popup, which used to sit `lineNumberPadding` to the left of the
  text's left edge and is now aligned with it.

## [0.1.0-beta.13] - 2026-11-12

### Fixed

- Ten `EditorConfiguration` values that were stored, encoded and offered by
  host settings but never read by the editor now do what they say:
  - `behavior.autoCloseBrackets` and `behavior.autoCloseQuotes`: typing an
    opening bracket or a quote inserts its pair, typing a closer that is
    already there steps over it, and typing either over a selection wraps the
    selection. A bracket typed in front of a word, and an apostrophe inside
    one, are left alone. Both default to on, so **every host gets this
    behaviour unless it turns the values off**.
  - `behavior.isAutoIndentEnabled`: Return keeps the line's indentation, goes
    one level deeper after an opening bracket or a trailing colon, and between
    a bracket pair puts the closer on its own line. Defaults to on, with the
    same consequence for hosts.
  - `behavior.isAutomaticLinkDetectionEnabled`: applied to the text view
    (set-up used to force it off). Turning it off removes the links already
    detected.
  - `behavior.showInlineCompletionSuggestions`: off stops the system's inline
    predictions appearing in the editor; on (the default) follows the user's
    system-wide setting, as before.
  - `behavior.completionTriggerCharacters`: a configured set now replaces the
    language's own trigger characters. The default value
    (`Behavior.defaultCompletionTriggerCharacters`, new) stands for "use the
    language's own", so hosts that never set it see no change.
  - `layout.characterSpacing`: applied as kerning to the document and to
    typed text.
  - `layout.textContainerWidthFraction`: narrows the wrapping width when
    `wrapLines` is on, and follows the view as it is resized. It has no
    effect without wrapping.
  - `display.areInvisibleCharactersVisible`: spaces, tabs and line endings
    are drawn as marks (macOS). The marks come from the editor's own layout
    fragment, which is only installed while the setting is on; toggling it
    moves no text.
  - `display.areAnnotationsEnabled`: off hides annotation views without
    discarding the annotations.
- `display.visibleLines` and `layout.textContainerInset` are still not read
  by the macOS editor view; their documentation now says so instead of
  implying an effect. `visibleLines` is a sizing hint for hosts.

- A memory-cleanup pass no longer empties the editor's line geometry store.
  `MemoryManagementCoordinator` reset it as if it were a cache, but it is the
  editor's line index and nothing rebuilds it before the next character edit:
  after a cleanup every gutter line number read "1", and the active-line
  number, line-at-point, `lineNumber(at:)`, `lineRange(for:)`, `lineCount` and
  the minimap were wrong with it. Cleanup now leaves the store alone (and no
  longer reports "line geometry store" or its 0.5 MB estimate in the cleanup
  result). Hosts that set `memoryManagementPolicy: .disabled` only to avoid
  this can return to the default.
- Setting an editor's text no longer counts the document's lines twice. The
  text setters rebuild the line geometry store on the spot, and the edit
  event queued by the same assignment was then applied on top of it as an
  incremental edit: a five-line document ended with nine lines in the store,
  inflating `lineCount`, the total height and the minimap's line total. The
  store now records the edit generation its last full rebuild covers and the
  edit handler skips events at or before it.
- Editing past the first line no longer duplicates a line in the line
  geometry store. `LineGeometryEditHandler` rescanned from the start of the
  line before the edited one while replacing only the edited lines, so every
  such edit (each keystroke included) left a copy of the previous line
  behind: five characters typed on line 2 of a five-line document left ten
  lines in the store. `lineCount`, the total height and the minimap grew with
  every edit, and line lookups below the edit could land on the wrong line.
  The handler now replaces exactly the lines from the one holding the edit to
  the one holding the first character after it, and rebuilds the store
  instead when an event cannot be applied to it as it stands (several edits
  made before their events were delivered, or a CR joined to an LF across the
  edited region's edge). The handler's existing tests compared a freshly
  built store with the text and could not fail; they now check the store the
  handler maintains.

## [0.1.0-beta.12] - 2026-11-09

### Added

- `EditorController.refreshSearch` refreshes live matches without moving the
  selection or scroll position. Cancelled searches cannot publish stale results.
- Host APIs for clearing obsolete text undo, detecting editor focus, and anchoring
  a popover to a text range in visible viewport coordinates.

### Changed

- Requires DesignKit 3.0.1 for displayed contrast and readable foreground roles.


## [0.1.0-beta.11] - 2026-11-04

### Changed

- Requires DesignKit `3.0.0` (was `from: "3.0.0-beta.1"`). DesignKit 3.0.0 takes
  the window traffic-light colours from the design system (#FF5C60 / #FAC800 /
  #35C759), so the six `EditorTrafficLights` / `EditorTitleBar` image references
  were re-recorded (only the three circles' pixels differ), and the dark-theme
  structure dump gains `borders.strong` and `chrome.tertiaryBackground`.

### Fixed (tests only)

- The full test suite passes again (1057 XCTest + 368 Swift Testing), and CI
  runs all of it instead of a hand-picked subset.
  - 16 crashes (signal 11) in the TextKit 2 ruler, gutter, text-visibility and
    event fan-out tests: their programmatic `NSWindow`s defaulted to
    `isReleasedWhenClosed = true`, so `close()` over-released them.
  - Image snapshots no longer depend on the display scale of the machine that
    runs them (`NativeImageSnapshotting.swift`: fixed 2x rendering, ImageIO
    comparison with SnapshotTesting's precision semantics), and 48 references
    were re-recorded under macOS 27. They predated the 2026-07-12 DesignKit
    migration, whose theme values changed the title bar, tab strip, glass
    surfaces and other chrome colours.

## [0.1.0-beta.10] - 2026-11-04

### Fixed

- `.onTextHover` and `.onCommandClick` applied to a `CodeEditor` (the
  documented usage) never fired: they read `\.editorEventBus` from the
  environment above the editor, and `CodeEditor` only sets that key on its own
  content. The modifiers now hand their actions down the environment and
  `CodeEditor` delivers its controller's hover and ⌘-click events to them
  (`CodeEditorPointerActionTests`). Public API unchanged; a host that injects
  `\.editorEventBus` itself is still served directly.

### Changed

- DesignKit `3.0.0-beta.2` (active line distinct from selection); the
  active-line snapshot is re-recorded.

## [0.1.0-beta.8] - 2026-10-08

### Changed

- `swift-syntax` requirement widened from `from: "602.0.0"` (i.e.
  `602.x` only) to `"602.0.0"..<"605.0.0"`, so dependents on the Swift 6.4
  toolchain resolve the matching `604.0.0`. Only `SwiftParser`/`SwiftSyntax`
  are used (runtime highlighting); no source change.
- Package lockfile refreshed to the newest in-range Point-Free stack and
  `swift-snapshot-testing` 1.19.6 (tests only). No public API change.

## [0.1.0-beta.7] - 2026-07-25

### Changed

- Every target declares Swift 6 language mode per target (it already
  compiled cleanly under Swift 6 with strict concurrency; no source change).
- **Platform floor raised to macOS 27.0, and the iOS 26 claim is removed.**
  `CodeEditorWorkspace` re-exports WorkspaceKit, whose `WorkspaceFileSystem`
  uses FSEvents unguarded, so an iOS build fails; the claim had most likely
  been unbacked since 0.1.0-beta.5. Restoring iOS needs WorkspaceKit's
  FSEvents target platform-gated.
- Dependency floors: LanguageKit `.upToNextMinor(from: "0.2.0")`, DesignKit
  `from: "2.0.0"`.

## [0.1.0-beta.6] - 2026-07-25

### Changed

- **BREAKING: the package is renamed `CodeEditorPlugin` → `CodeEditorKit`.**
  The SwiftPM package identity, the umbrella library product, the umbrella
  target and Swift module, its source directory
  (`Sources/CodeEditorPlugin/` → `Sources/CodeEditorKit/`), its entry stub
  (`CodeEditorPlugin.swift` → `CodeEditorKit.swift`), its test target
  (`CodeEditorPluginTests` → `CodeEditorKitTests`) and the repository URL
  (`https://github.com/ajmcclary/CodeEditorKit.git`) all change together.
  No compatibility alias is provided: `import CodeEditorPlugin` becomes
  `import CodeEditorKit`, and dependents must update both the
  `.package(url:)`/`.package(path:)` entry and every
  `.product(name:package: "CodeEditorKit")` label. Every other product,
  target and public symbol is unchanged — this is a naming migration only.
- `ProcessTransport` reads pipes through ProcessKit's shared
  `ProcessPipeReader` (`installChunkReader` is removed).

## [0.1.0-beta.5] - 2026-07-15

### Changed

- `CodeEditorWorkspace` is now an `@_exported` re-export shim over the new
  top-level WorkspaceKit package (0.1.0-beta.1), which received the
  workspace file-tree contracts and `MacOSWorkspaceFileManager` verbatim.
  Existing `import CodeEditorWorkspace` code is unaffected. (Released as
  `CodeEditorPlugin`.)

## [0.1.0-beta.4] - 2026-07-14

### Changed

- **`ProcessTransport` runs on ProcessKit** (the promoted neutral process
  package — the "proof-of-two" with RepoPrompt). `ProcessLauncher` owns
  spawning (posix_spawnp), `FileHandleChunkChannel` preserves stdout/stderr
  byte-arrival order (the previous per-chunk `Task` dispatch never
  guaranteed start order), `ProcessTermination` owns SIGTERM→SIGKILL
  escalation and single reaping (replacing the 5-second
  `waitUntilExit`/`interrupt()` race), and `FDWriteSupport` handles framed
  stdin writes (EPIPE-safe). `LSPFrameCodec` still owns framing; the actor
  keeps only LSP orchestration. Public API and `LSPTransport` conformance
  are unchanged; new lifecycle tests cover EOF, broken stdin, and
  child-exit-before-disconnect.

- **`LSPClient` is transport-only.** Content-Length framing is owned by a
  single internal `LSPFrameCodec` (both `ProcessTransport` and
  `WebSocketTransport` encode through it; `LSPMessageHandler` decodes
  through it, keeping the malformed-framing recovery semantics pinned by
  `LSPMessageHandlerRecoveryTests`). The legacy
  `connect(configuration: ServerConfiguration)` overload no longer falls
  back to spawning a server process when no transport is configured — it
  throws `LSPError.transportNotConfigured` (previously it spawned the
  executable and then hung awaiting an initialize response). Local servers
  are reached via `ProcessTransport`, installed by
  `connect(configuration:languageId:)` or `init(transport:)`; no in-package
  or demo caller used the fallback. The internal `LSPProcessManager` was
  deleted; `ProcessTransport` gained a direct end-to-end framing test.
  (ProcessKit proof-of-two, steps 1–4.)

## [0.1.0-beta.3] - 2026-07-14

### Added

- **Public injection seam for external highlight providers.** A host can now
  install a value-oriented `HighlightRangeProviding` (from the view-free
  `CodeEditorHighlightingCore` contract) as the editor's primary syntax-highlight
  source through three parallel APIs:
  - `CodeEditorView.setExternalHighlightProvider(_:)` (view level, plus a
    matching `externalHighlightProvider` read accessor).
  - `EditorController.setExternalHighlightProvider(_:)` (SwiftUI host façade);
    the controller remembers the provider and re-applies it on every (re)attach,
    so it works even when set before the underlying view exists.
  - `.codeEditorHighlightProvider(_:)` SwiftUI view modifier.

  Injecting a provider *replaces* the built-in regex / SwiftSyntax highlighter as
  the primary source (it does not augment it — that remains the LSP
  supplemental-provider path). Passing `nil` restores the built-in highlighter.
  The provider paints once `performance.usesRangeBasedHighlighting` and
  `display.useRangeStoreHighlighting` are enabled. This exposes the previously
  internal `RangeBasedHighlightingController(externalProvider:)` seam that the
  `CodeEditorTreeSitter` package's `TreeSitterHighlightProvider` was written for.

### Changed

- **Platform floor lowered from macOS 26.3 / iOS 26.3 to macOS 26.0 / iOS 26.0.**
  The 26.3 floor was never a real API requirement: the package contains no
  26.3-gated declarations and the full package builds with availability
  checking at 26.0. Lowering the floor aligns CodeEditorPlugin with DesignKit
  (26.0) and RepoPrompt (26.0), removing the deployment-target obstacle to
  embedding the editor in RepoPrompt. Toolchain requirements are unchanged
  (Swift 6.3+, Xcode 26.3+).

## [0.1.0-beta.2] - 2026-07-13

Dependency hygiene and a target-graph split since beta.1.

- **Dependency hygiene:** the test-only `swift-snapshot-testing` dependency now
  points at upstream by version (`from: "1.19.3"`) instead of the branch-pinned
  `ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable` fork. Upstream
  1.19.3 builds cleanly under the Apple Swift 6.4 / Xcode 27 toolchain; the fork
  was only needed on the open-source `swift-6.3-RELEASE` toolchain. Removing the
  branch pin makes the package consumable by stable-version dependents (LanguageKit
  was already pinned by version in beta.1).
- **Target split (Task 6):** lightweight runtime instrumentation was split out of
  `CodeEditorDiagnostics` into a new `CodeEditorInstrumentation` product; the LSP
  editor bridge was extracted into `CodeEditorLSPIntegration`, dropping the
  `CodeEditorView → CodeEditorLSP` edge so LSP is genuinely optional; and a
  view-free `CodeEditorHighlightingCore` value contract was introduced as the
  external highlight seam. Product count grew accordingly (see the target table
  in `CLAUDE.md`).

## [0.1.0-beta.1] - 2026-07-13

First documented prerelease.

- TextKit2-based code editor framework for macOS and iOS/iPadOS, built with
  Swift 6.3 and Swift 6 strict concurrency; 16 SwiftPM library products
  (umbrella `CodeEditorPlugin` plus opt-in modules for annotations,
  completion, diagnostics, LSP, search, and workspace file-tree UI).
- Syntax highlighting for 30 concrete languages plus plain text (including
  five diagram DSLs — Mermaid, D2, Graphviz DOT, Structurizr DSL, PlantUML —
  added for DiagramKit's editor migration); language
  identity (display names, LSP identifiers, parser names, file extensions)
  is sourced from LanguageKit's `LanguageCatalog`, with two documented,
  intentional divergences (`tsx` mapped to TypeScript, Swift's grammar
  identifier suppressed) preserved via characterization tests.
- Theming via the shared DesignKit design system (`DesignKitThemes`:
  12 theme families, each with a light and a dark variant, default
  `.lcarsDark`); SwiftUI-native integration via `CodeEditor` with
  environment-based configuration.
- Language Server Protocol client support, with local server management on
  macOS and remote WebSocket clients on all supported platforms.
