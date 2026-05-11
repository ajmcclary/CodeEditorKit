# CodeEdit Audit Notes

Date: 2026-05-11

Repositories compared:

- CodeEdit app: `/Users/ajmcclary/Dev/CodeEditor/CodeEdit`
- CodeEditorPlugin: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`
- Pinned CodeEdit editor packages inspected locally under `/tmp/codex-codeedit-deps/`

Baseline for this repo: CodeEditorPlugin remains Swift 6.3 with strict concurrency. Any CodeEdit ideas should be ported into that model, not used as a reason to loosen concurrency or package constraints.

## Executive Summary

CodeEdit is a full macOS IDE shell. Its most useful lessons for CodeEditorPlugin are not primarily in the app target, but in the pinned packages it delegates to:

- `CodeEditSourceEditor`
- `CodeEditTextView`
- `CodeEditLanguages`

The app-level CodeEdit code is still useful for NSDocument integration, LSP lifecycle, semantic tokens, workspace file trees, filesystem event handling, and SearchKit-backed project search.

CodeEditorPlugin is already stronger in several foundational areas:

- SwiftPM framework shape instead of app-only architecture
- Swift 6.3 strict concurrency
- Cross-platform AppKit/UIKit support
- Dependency injection through configuration and `swift-dependencies`
- TextKit2-first integration
- Design-token and SwiftUI package boundaries
- Existing range-store highlighting scaffold
- Existing line-geometry tree scaffold

The main gaps are maturity gaps:

- Tree-sitter is still a regex-backed spike.
- Range-store highlighting is opt-in and not the primary text attribute applier.
- Line geometry currently rebuilds on character edits.
- LSP document sync lacks an editor-owned batching coordinator.
- LSP semantic tokens and delta updates are not represented.
- Workspace/search are intentionally shallow in the package and sample.

## CodeEdit Architecture

CodeEdit's editor screen is a thin composition layer around `SourceEditor`. `CodeFileView` passes:

- `NSTextStorage`
- language
- `SourceEditorConfiguration`
- editor state
- highlight providers
- undo manager
- text view coordinators

Key file:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/Editor/Views/CodeFileView.swift`

This is a useful architectural pattern because it keeps the app-level editor surface declarative and lets features attach as providers or coordinators. CodeEditorPlugin has similar ingredients, but much of the wiring is owned directly by `CodeEditorView`.

CodeEdit also treats editor state as more than text. `EditorInstance` owns cursor positions, scroll position, find/replace state, and a `RangeTranslator`. That state is restored and synchronized separately from the document. This is worth copying conceptually for richer SwiftUI/editor state restoration.

## Text Storage And Documents

CodeEdit's `CodeFileDocument` keeps file content as `NSTextStorage` and explicitly does not mark it `@Published`. The comment explains that publishing text would make SwiftUI compare large strings on every content update, causing hangs on large files.

Key file:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift`

Lessons:

- Large text should stay in mutable text storage or a specialized document model.
- SwiftUI should observe lightweight state and events, not the full text buffer.
- Encoding preservation, external reload handling, and save/autosave policy belong at the document/app layer.

CodeEditorPlugin already aligns with this by being TextKit/TextKit2-first. The next step is to make the public SwiftUI API avoid forcing large `String` comparisons in high-frequency paths.

## Highlighting Architecture

CodeEditSourceEditor uses a provider model:

- `HighlightProviding`
- `HighlightProviderState`
- `VisibleRangeProvider`
- `StyledRangeContainer`
- `RangeStore`

The key state machine tracks:

- valid character indices
- pending character indices
- visible character indices

It computes work as:

```text
(document - validSet) intersect visibleSet - pendingSet
```

It chunks invalid visible ranges at 4096 characters.

Key files:

- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Highlighting/HighlightProviding/HighlightProviderState.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Highlighting/Highlighter.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/Highlighting/VisibleRangeProvider.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/RangeStore/RangeStore.swift`

CodeEditorPlugin already has a parallel design:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightProviderState.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/SyntaxHighlighting/VisibleRangeProvider.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Text/RangeStore/RangeStore.swift`

Differences:

- CodeEdit's `RangeStore` uses `swift-collections` rope storage and is suitable for larger run sets.
- CodeEditorPlugin's `RangeStore` is array-backed by design and documented as acceptable while runs are bounded by visible viewport output.
- CodeEdit's range pipeline applies editor highlights directly.
- CodeEditorPlugin's range pipeline currently feeds minimap style data and visible invalidation; legacy attributed-string highlighting remains active.

Recommendation:

Make CodeEditorPlugin's range-store path the primary highlighting backend once the attribute applier is ready. Keep the array-backed store until measurements show it is insufficient.

## Tree-Sitter Parsing

CodeEditSourceEditor has a real tree-sitter client. Important details:

- It owns parser state.
- It has primary and injected language layers.
- It performs incremental edits.
- It queries only visible or requested ranges.
- It uses sync or async execution based on edit size, document size, query size, and executor availability.
- It captures old edit endpoints before content changes.
- It supports cancellation and pending edit replay.

Useful constants from CodeEdit:

- `matchLimit = 256`
- `parserTimeout = 0.05`
- `maxSyncEditLength = 1024`
- `maxSyncContentLength = 1_000_000`
- `maxSyncQueryLength = 4096`
- `charsToReadInBlock = 4096`
- `longParseTimeout = 0.5s`
- `taskSleepDuration = 10ms`

Key files:

- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterClient.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterClient+Edit.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterClient+Highlight.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterState.swift`
- `/tmp/codex-codeedit-deps/CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/LanguageLayer.swift`

CodeEditorPlugin's current tree-sitter path is explicitly a spike:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/TreeSitterRangeHighlightProvider.swift`

It uses `RegexBackedTreeSitterParser` to prove the `RangeHighlightProviding` pipeline. It invalidates the entire document for parser edits and reparses source for highlight queries.

Recommendations:

- Replace the regex-backed spike with real tree-sitter parser state.
- Preserve CodeEditorPlugin's `RangeHighlightProviding` protocol.
- Add incremental edit support with old/new byte range translation.
- Add injection layer support for mixed-language documents.
- Use CodeEdit's thresholds as initial defaults, then tune with benchmarks.
- Implement this under Swift 6.3 strict concurrency rather than copying CodeEdit's executor style verbatim.

## Rendering And Layout

CodeEditTextView is a custom text renderer, not `NSTextView`. It has:

- custom `TextView`
- custom `TextLayoutManager`
- `TextLineStorage` red-black tree
- reusable `LineFragmentView`
- visible-line layout only
- vertical layout padding
- lazy line iteration
- layout reentry protection with a lock and `CATransaction`

Key files:

- `/tmp/codex-codeedit-deps/CodeEditTextView/Sources/CodeEditTextView/TextView/TextView.swift`
- `/tmp/codex-codeedit-deps/CodeEditTextView/Sources/CodeEditTextView/TextLayoutManager/TextLayoutManager.swift`
- `/tmp/codex-codeedit-deps/CodeEditTextView/Sources/CodeEditTextView/TextLayoutManager/TextLayoutManager+Layout.swift`
- `/tmp/codex-codeedit-deps/CodeEditTextView/Sources/CodeEditTextView/TextLineStorage/TextLineStorage.swift`

Important rendering ideas:

- Keep line geometry in a red-black tree.
- Store text offsets, line counts, and heights as subtree metadata.
- Lay out only visible lines plus a padding band.
- Reuse fragment views aggressively.
- Avoid reentering layout while mutating the view tree.
- Use measured heights to preserve scroll position when line heights change.

CodeEditorPlugin has a related `LineGeometryStore`:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Text/LineGeometryStore.swift`

But its edit handler still rebuilds the whole store on each character edit:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift`

Recommendation:

Do not rewrite CodeEditorPlugin around a custom renderer yet. TextKit2 keeps the package smaller and cross-platform. Instead, finish incremental line-geometry updates so our gutter, minimap, folding, and y-position lookups get the same asymptotic win without taking on a full custom text view.

## LSP Lifecycle And Sync

CodeEdit uses Chime's LSP stack:

- `LanguageClient`
- `LanguageServerProtocol`
- `JSONRPC`

The app has a workspace/language keyed LSP lifecycle. It starts servers per language and workspace, tracks open documents, and initializes with richer capabilities.

Key files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/Service/LSPService.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/LanguageServer/LanguageServer.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/LanguageServer/LanguageServerFileMap.swift`

Most important pattern: `LSPContentCoordinator`.

It:

- installs as a text view coordinator
- captures the LSP range before the edit changes text/layout
- yields edits into an `AsyncStream`
- chunks edits into 250ms groups with `swift-async-algorithms`
- sends grouped incremental changes to the language server

Key file:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/Features/DocumentSync/LSPContentCoordinator.swift`

CodeEditorPlugin has:

- `LSPManager`
- `LSPClientRegistry`
- `LSPDocumentManager`
- `LSPClient`
- process and remote transport support

Key files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/LSP/LSPManager.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/LSP/LSPClient.swift`

Gaps:

- No editor-owned LSP edit batching coordinator.
- Incremental changes can be passed in, but there is no integrated path from `TextEditEventHub`.
- Server capabilities are much thinner.
- Semantic tokens are not represented.

Recommendations:

- Add a `TextEditEventHub` backed LSP sync coordinator.
- Capture pre-edit range data before mutation where needed.
- Batch edits for roughly 250ms.
- Respect `textDocumentSync` full vs incremental server capability.
- Keep path resolution and remote LSP support; those are strengths in CodeEditorPlugin.

## Semantic Tokens

CodeEdit has a mature semantic-token path:

- advertises delta semantic token support during initialization
- maps server legends to editor capture names
- stores compressed LSP token arrays
- decodes tokens for range queries
- applies delta edits in reverse
- returns invalidated ranges for redraw

Key files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/Features/SemanticTokens/SemanticTokenHighlightProvider.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/Features/SemanticTokens/SemanticTokenStorage/SemanticTokenStorage.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/LSP/Features/SemanticTokens/SemanticTokenMap.swift`

CodeEditorPlugin currently has no semantic-token capability model in `LSPTypes`.

Recommendation:

Add semantic-token support as a `RangeHighlightProviding` implementation. The provider should write into `StyledRangeContainer` with higher priority than syntax tokens. This allows tree-sitter/regex highlighting to remain a baseline while LSP semantic tokens refine names, types, modifiers, and declarations.

## Workspace File Tree

CodeEdit's workspace file manager is intentionally lazy:

- only root children are loaded at workspace open
- deeper directories are materialized only when UI asks for them
- files are kept in a flattened dictionary plus a children map
- observers are weak
- FSEvents repair only already-cached directories
- source-control refresh is routed based on `.git` event paths

Key files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/CEWorkspace/Models/CEWorkspaceFileManager.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/CEWorkspace/Models/CEWorkspaceFileManager+DirectoryEvents.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/CEWorkspace/Models/DirectoryEventStream.swift`

CodeEditorPlugin currently treats workspace mostly as a configuration value:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorSample/KnobPanels/WorkspaceKnobsSection.swift`

Recommendation:

Keep workspace modeling out of the core editor target unless a specific API requires it. Add protocols for workspace file trees and file watching, then provide a macOS adapter and sample implementation. The CodeEdit lazy materialization model is the right shape for that adapter.

## Search And Indexing

CodeEdit uses SearchKit for project search:

- `SKIndex`
- progressive chunked search
- async streams for search results
- background indexing queues
- optional in-memory index

Key files:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/Documents/Indexer/SearchIndexer.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/Documents/Indexer/SearchIndexer+ProgressiveSearch.swift`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEdit/CodeEdit/Features/Documents/Indexer/SearchIndexer+AsyncController.swift`

Useful idea:

- Use a fast index to prefilter candidate files, then do exact regex/text matching on the narrowed set.

Caution:

- SearchKit is macOS-only.
- There are implementation rough edges in CodeEdit's async indexing code, so this should be treated as a pattern, not code to copy.

Recommendation:

Define a project-search protocol. Provide a macOS SearchKit adapter in sample/app-facing code and a portable fallback for package-level use.

## Dependency And Service Patterns

CodeEdit has useful app-level service organization, but it relies on global/shared patterns in several places.

Do not copy:

- singleton registries
- global service containers
- implicit fatal errors for missing services
- broad `@unchecked Sendable` as a convenience

Keep CodeEditorPlugin's direction:

- inject through `EditorConfiguration`
- use explicit initializers for services
- use `swift-dependencies` where appropriate
- keep MainActor isolation explicit for UI-bound services

## CodeEdit Risks And Rough Edges

These are observations from the audit, not blockers to learning from the repo:

- `CodeFileView` has two `TreeSitterClient` state properties, one of which appears unused.
- `SourceEditor.updateControllerWithState` compares `cursorPositions` to `state.cursorPositions`, which is the same value and likely a bug.
- Search index folder recursion appears to check the root URL instead of the enumerated file URL in one branch.
- Some app code uses globals/singletons that do not fit this package.
- The custom renderer is high leverage but high maintenance.
- `CodeEditLanguages` uses a binary language container that may not fit our cross-platform distribution requirements.

## Ranked Recommendations

### P0

Finish real tree-sitter integration.

- Replace `RegexBackedTreeSitterParser`.
- Keep `RangeHighlightProviding` as the integration point.
- Support incremental edits.
- Support injection layers.
- Preserve UTF-16/TextKit correctness at API boundaries.
- Use CodeEdit's thresholds as initial defaults only.

Add an LSP document-sync coordinator.

- Subscribe to `TextEditEventHub`.
- Capture pre-edit ranges.
- Batch edits around 250ms.
- Send full or incremental changes based on server capabilities.

### P1

Add semantic-token support.

- Extend LSP capabilities.
- Store compressed token data.
- Decode tokens for visible-range queries.
- Apply delta edits.
- Feed results through `StyledRangeContainer`.

Make line geometry incremental.

- Replace full rebuilds in `LineGeometryEditHandler`.
- Update affected line nodes only.
- Preserve measured heights and fold state.

Make range-store highlighting the primary text styling path.

- Keep legacy attributed highlighting until feature parity is proven.
- Add focused tests around visible invalidation, edits, and minimap data.

### P2

Add workspace protocols and a macOS file-watcher adapter.

- Use lazy materialization.
- Use weak observers.
- Repair only cached directories.
- Keep this out of core editor logic.

Add project-search protocols and an optional SearchKit adapter.

- Use SearchKit only where available.
- Keep a portable fallback.
- Use exact matching after index prefiltering.

### Later

Evaluate a custom renderer only if TextKit2 becomes the limiting factor after measuring.

CodeEditTextView proves the upside of custom rendering, but it is effectively a full editor engine. CodeEditorPlugin should finish its TextKit2 and range-store architecture before taking on that maintenance cost.

## Short Comparison Table

| Area | CodeEdit | CodeEditorPlugin | Takeaway |
| --- | --- | --- | --- |
| Package shape | macOS app plus editor packages | SwiftPM framework plus UI/sample | Keep our package boundaries |
| Text model | `NSTextStorage`, not published | TextKit2-first view | Same principle |
| Highlighting | provider state, visible invalidation, rope range store | similar scaffold, opt-in | Promote our range path |
| Tree-sitter | real parser, edits, injections | regex-backed spike | Highest priority gap |
| Rendering | custom line renderer and red-black line storage | TextKit2 plus line geometry store | Finish incremental geometry first |
| LSP sync | edit coordinator batches 250ms | manager can update docs, no editor sync coordinator | Add coordinator |
| Semantic tokens | full/delta storage and range queries | not present | Add provider |
| Workspace | lazy file tree and FSEvents repair | root URL only | Add protocols/adapters |
| Search | SearchKit progressive index | local editor search only | Optional macOS adapter |
| Services | app globals and shared managers | DI/config/dependencies | Keep our stricter approach |

## Bottom Line

The best path is not to copy CodeEdit. The best path is to port its proven editor-engine ideas into CodeEditorPlugin's stricter Swift 6.3, SwiftPM, cross-platform architecture:

1. real tree-sitter
2. batched LSP document sync
3. semantic-token deltas
4. incremental line geometry
5. range-store highlighting as the primary pipeline
6. optional workspace/search adapters outside the core editor
