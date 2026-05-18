# CodeEditorWorkspace Extraction (§6.2.8f) — Design

Clean full extraction of the workspace file-tree types from the
`CodeEditorPlugin` umbrella target into a new `CodeEditorWorkspace`
SPM target. Two files move, zero stay behind, zero `Core/Workspace/`
relocation bucket needed. First clean full extraction (no carve-out,
no umbrella relocations, no type-erasure refactor) since §6.2.5
`CodeEditorTheming`.

The chunk was selected after discovering that the original §10
"next session" candidate — `CodeEditorSmartEditing` (§6.2.8c) — is
fundamentally blocked by `CodeEditorView` coupling: all 5 SmartEditing
files take `CodeEditorView` as a parameter on every public entry point,
yielding an empty target after carve-out. Workspace is the cleanest of
the remaining §6.2.8 candidates: 2 files, zero `CodeEditorView`
references, zero internal SPM deps.

## Goals

1. Lift the workspace file-tree surface — `WorkspaceFileNode`,
   `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching`,
   and the macOS adapter `MacOSWorkspaceFileManager` — into their own
   SPM target. Workspace changes stop rebuilding the umbrella.
2. Honor §6.3's "Optional / opt-in" intent for `CodeEditorWorkspace`.
   Expose the new target as a `.library` product. Do NOT add it to
   the umbrella `CodeEditorPlugin`'s `dependencies:`. Consumers opt
   in explicitly via `import CodeEditorWorkspace`.
3. Set a precedent for the rest of §6.2.8: when an engine has zero
   `CodeEditorView` coupling, prefer a clean full extraction over a
   ceremonial carve-out scaffold.

## Non-goals

- Not implementing an iOS / UIKit workspace file manager. The new
  target builds on iOS and exposes the protocols but the concrete
  manager (`MacOSWorkspaceFileManager`) is `#if canImport(AppKit)`
  end-to-end. A future `UIWorkspaceFileManager.swift` is a separate
  session.
- Not migrating `MacOSWorkspaceFileManager` to FSEvents. The current
  implementation polls modification dates every 2 seconds
  (`MacOSWorkspaceFileManager.swift:96`) and the file's inline TODO
  flags FSEvents as a future optimization. Out of scope for the
  extraction.
- Not splitting `Features/` directory. `SearchReplaceEngine.swift`,
  `SmartEditing/`, `Annotations/`, `Debugger*.swift`, and the
  Completion sources stay put; their extractions follow in §6.2.8
  remaining sub-steps.
- Not creating a `CodeEditorWorkspaceTests` target. The three existing
  tests that touch Workspace types
  (`WorkspaceModelTests`,
  `WorkspaceSidebarSnapshotTests`,
  `Support/StubWorkspaceFileTree`) live in
  `CodeEditorSampleTests` and exercise the sample's
  `WorkspaceModel` / `FilePanelView` — not the Workspace types
  themselves. Per-target test split is deferred to §6.2.15.
- Not renaming the package or moving to `~/Workspace/packages/`.
  §6.2.14 / §6.2.16 territory.
- Not extracting SmartEditing (§6.2.8c). Blocked by `CodeEditorView`
  coupling. Defer until after §6.2.12 Core split.

## Target shape & dependency edges

New target at `Sources/CodeEditorWorkspace/`. Direct dependencies
derived from the import survey across the 2 moving files: **none**.
Both files import only `Foundation` (and `MacOSWorkspaceFileManager`
adds conditional `AppKit` inside the `#if canImport(AppKit)` block).

```swift
.target(
    name: "CodeEditorWorkspace",
    swiftSettings: swiftSettings
)
```

Notably **not** included (no moving file imports them):
`CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`,
`CodeEditorConfiguration`, `CodeEditorTheming`,
`CodeEditorDesignTokens`, `CodeEditorLanguages`,
`CodeEditorSyntaxHighlighting`, `CodeEditorDiagnostics`,
`CodeEditorFolding`, `CodeEditorSymbols`. Tighter than every prior
phase-4 extraction.

**Productized.** New `.library` product entry alongside the existing
`CodeEditorDiagnostics` product:

```swift
.library(name: "CodeEditorWorkspace", targets: ["CodeEditorWorkspace"]),
```

Matches NEXT.md §6.3's explicit listing of `CodeEditorWorkspace` as
opt-in. Matches the Diagnostics precedent (§6.2.10) for productizing
opt-in targets.

Phase 4 (feature engines) as the *semantic* label. Build-graph reality
is "parallel to phase 0" since the target has no internal deps —
documented but not treated as a problem.

Umbrella target `Package.swift` changes:

- **Do NOT** add `"CodeEditorWorkspace"` to `CodeEditorPlugin`'s
  `dependencies:`. The umbrella has no internal consumer of Workspace
  types (confirmed: zero `grep` hits in `Sources/CodeEditorPlugin/`
  outside `Workspace/` itself). Opt-in semantics require the umbrella
  to stay independent.
- Add `"Workspace"` to `CodeEditorPlugin`'s `exclude:` array
  (defensive; the source directory `Sources/CodeEditorPlugin/Workspace/`
  is empty after `git mv`).
- Add `"CodeEditorWorkspace"` to `CodeEditorSample`'s `dependencies:`.
- Add `"CodeEditorWorkspace"` to `CodeEditorSampleTests`'s
  `dependencies:`.
- No `CodeEditorUI` / `CodeEditorPluginTests` / `CodeEditorUITests` /
  `CodeEditorDesignTokensTests` dep changes (zero file changes in
  those targets).

## File-by-file moves

| Source path | Destination path | Notes |
|---|---|---|
| `Sources/CodeEditorPlugin/Workspace/WorkspaceFileProtocols.swift` | `Sources/CodeEditorWorkspace/WorkspaceFileProtocols.swift` | 74 lines. `WorkspaceFileNode` struct, `WorkspaceFileEvent` enum, `WorkspaceFileTree` + `WorkspaceFileWatching` protocols. All `public`. Foundation only. |
| `Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift` | `Sources/CodeEditorWorkspace/MacOSWorkspaceFileManager.swift` | 187 lines. `MacOSWorkspaceFileManager` final class conforming to both protocols. Foundation only, wrapped end-to-end in `#if canImport(AppKit)`. |

No file splits. No mid-extraction extractions of bundled types (unlike
§6.2.7's `RangeQueryParser` or §6.2.8b's `SymbolRangeIndex`). The two
files are already well-shaped.

No `Core/Workspace/` relocation bucket. No umbrella files reference
the Workspace types directly — verified by grep.

## Access modifier promotions

**None required.** All five top-level types are already `public`:

| Type | File | Kind | Access |
|---|---|---|---|
| `WorkspaceFileNode` | `WorkspaceFileProtocols.swift:6` | struct | `public` |
| `WorkspaceFileEvent` | `WorkspaceFileProtocols.swift:30` | enum | `public` |
| `WorkspaceFileTree` | `WorkspaceFileProtocols.swift:44` | protocol | `public` |
| `WorkspaceFileWatching` | `WorkspaceFileProtocols.swift:65` | protocol | `public` |
| `MacOSWorkspaceFileManager` | `MacOSWorkspaceFileManager.swift:14` | class | `public` |

All `init`s, methods, and stored properties exposed externally are
explicitly `public`. The `private` members (cache dictionary,
FileManager handle, AsyncStream continuation, polling helpers,
nested `CacheEntry` struct) stay `private` — file-local
implementation, no cross-target need.

No synthesised-init backfill (the gotcha that §6.2.8b discovered with
`SymbolNavigationConfiguration` / `BreadcrumbItem`). Both moving
files declare explicit `public init` for every type whose init is
called outside its source file.

This is the smallest promotion surface in the restructure series:

| Extraction | Promotions |
|---|---|
| §6.2.7 SyntaxHighlighting | ~107 |
| §6.2.8a Folding | ~5 |
| §6.2.8b Symbols | 7 (5 package + 2 public init) |
| **§6.2.8f Workspace** | **0** |

## Consumer ripple

Six files gain a new `import CodeEditorWorkspace`. All six currently
reach Workspace types via their existing `import CodeEditorPlugin`
(transitive — Workspace types live in the umbrella today). Each
file keeps `import CodeEditorPlugin` (still needed for unrelated
umbrella types) and adds the new import alongside.

| Target | File | Workspace types used |
|---|---|---|
| `CodeEditorSample` | `App/AppState.swift` | `WorkspaceFileWatching` (doc comment + property) |
| `CodeEditorSample` | `Workspace/WorkspaceModel.swift` | `MacOSWorkspaceFileManager`, `WorkspaceFileNode`, `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching` |
| `CodeEditorSample` | `Workspace/FilePanelView.swift` | `WorkspaceFileNode` |
| `CodeEditorSampleTests` | `WorkspaceSidebarSnapshotTests.swift` | `WorkspaceFileNode`, `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching` |
| `CodeEditorSampleTests` | `WorkspaceModelTests.swift` | `WorkspaceFileNode` |
| `CodeEditorSampleTests` | `Support/StubWorkspaceFileTree.swift` | `WorkspaceFileNode`, `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching` |

**Targets with zero file changes:** `CodeEditorPlugin` (umbrella),
`CodeEditorUI`, `CodeEditorPluginTests`, `CodeEditorUITests`,
`CodeEditorDesignTokensTests`.

**Public-API surface tightening.** Before extraction, a consumer doing
`import CodeEditorPlugin` gets transitive access to Workspace types.
After extraction, they do not. The only confirmed consumer of this
surface is `CodeEditorSample` (in-tree). External consumers were not
identified in this workspace; cross-package consumers should be
verified before §6.2.16 (move to `~/Workspace/packages/`). Acceptable
per §6.3's opt-in intent.

## Validation plan

Matches the §6.2.8a / §6.2.8b cadence, simplified by the no-carve-out
shape (one commit instead of two — no umbrella-relocation pre-commit
required).

1. **Pre-flight.** Confirm clean working tree on `main` at the
   starting SHA. Run `swift build && swift test --parallel` for the
   baseline. Capture the SHA (NEXT.md cross-reference will be added
   in a follow-up SHA-update commit, matching the §6.2.8a / §6.2.8b
   pattern).
2. **Step 1 — target + product scaffolding.** Add the new
   `CodeEditorWorkspace` target and `.library` product to
   `Package.swift`. Create `Sources/CodeEditorWorkspace/` directory.
   Add `"Workspace"` to umbrella `exclude:`. Without the file moves,
   the build fails (empty target). This step is folded into Step 2
   in practice — no intermediate commit.
3. **Step 2 — file move.** `git mv` both files from
   `Sources/CodeEditorPlugin/Workspace/` to
   `Sources/CodeEditorWorkspace/`. Remove the now-empty
   `Sources/CodeEditorPlugin/Workspace/` directory. Run
   `swift build --target CodeEditorWorkspace` to confirm the new
   target compiles in isolation.
4. **Step 3 — consumer rewire.** Add `import CodeEditorWorkspace` to
   the 6 consumer files. Add `"CodeEditorWorkspace"` to
   `CodeEditorSample.dependencies` and
   `CodeEditorSampleTests.dependencies`. Run
   `swift build --target CodeEditorSample` and
   `swift build --target CodeEditorSampleTests` separately to localize
   any missed import.
5. **Step 4 — full build.** `swift build`. Should be green.
6. **Step 5 — targeted tests.** `swift test --filter WorkspaceModelTests`
   and `swift test --filter WorkspaceSidebarSnapshotTests`. These
   are the only tests that exercise the moved types.
7. **Step 6 — skip full suite per memory.** Per
   `feedback_test_confirmations.md`: this is an additive-only
   restructure with the build green, so skip
   `swift test --parallel`. The targeted tests in Step 5 cover the
   surface that actually moved.
8. **Step 7 — lint + commit.** `swiftlint --fix && swiftlint`. Single
   commit with subject following the §6.2.8a / §6.2.8b pattern:
   `Extract CodeEditorWorkspace target (§6.2.8f)`. Update NEXT.md
   §6.0 status table in a follow-up commit once the extraction SHA
   is known (matches §6.2.8a / §6.2.8b cadence).

## Deviations from NEXT.md

1. **§4.1 dependency claim wrong.** NEXT.md §4.1 says
   `CodeEditorWorkspace` depends on `TextModel`. Reality from imports:
   zero internal deps. Spec corrects this — the new target has no
   `dependencies:` array entries.
2. **§6.3 honored.** Productized as `.library(name: "CodeEditorWorkspace",
   …)`. Umbrella does NOT depend on or re-export it. Matches the §6.3
   "Optional / opt-in" listing and the Diagnostics precedent.
3. **No carve-out.** First clean full extraction since §6.2.5
   `CodeEditorTheming`. Pattern departure from §6.2.6 / §6.2.7 /
   §6.2.8a / §6.2.8b / §6.2.10 which all needed either umbrella
   relocations, mid-move file re-homing, or carve-out. NEXT.md
   §6.2.8 should be updated to reflect that §6.2.8f Workspace
   landed as a clean extraction.
4. **No promotions.** Smallest surface in the series. Worth noting
   in NEXT.md §6.0 deviations subsection — the access-modifier
   promotion sweep that §6.2.7+ entries normalize on is genuinely
   not needed here.
5. **Phase 4 semantic label vs build-graph reality.** §4.1 labels
   Workspace as phase 4 (feature engines). With no internal deps,
   the build graph treats it as parallel to phase 0. Spec keeps the
   phase 4 *semantic* label (it's a feature, not foundational infra)
   but notes the build-graph reality in NEXT.md §6.0 once landed.
6. **iOS coverage asymmetry.** `MacOSWorkspaceFileManager` is
   AppKit-only; the iOS branch of the target ships only the
   protocols. §6.3 lists `CodeEditorWorkspace` as opt-in without
   noting this asymmetry — flag for the next iOS feature session.
7. **SmartEditing reordering.** NEXT.md §6.2.8 suggested ordering
   `Folding → Symbols → SmartEditing → Search → Annotations →
   Workspace → Completion`. SmartEditing is blocked by
   `CodeEditorView` coupling (see "Risks" below); Workspace runs
   first instead. NEXT.md §6.0 should record the reordering and
   spell out the blocker for future readers attempting SmartEditing
   before §6.2.12 Core split.

## Risks

- **R1 — Sample build breakage from missed import.** 6 files need the
  new import. Mitigation: per-target build invocations in Step 4
  (`swift build --target CodeEditorSample` separate from
  `--target CodeEditorSampleTests`) localize the error.
- **R2 — Cross-package consumer surprise.** Public-API surface
  tightening means external consumers of `import CodeEditorPlugin`
  that touch Workspace types will fail to compile. The only confirmed
  consumer is the in-tree sample (no other consumers in
  `~/Workspace/products/` or sibling packages identified). Mitigation
  flagged for §6.2.16 (the `~/Workspace/packages/` move) — verify
  again at move time.
- **R3 — Doc-comment drift.** `App/AppState.swift:42` and
  `Workspace/WorkspaceModel.swift:5` reference `WorkspaceFileWatching`
  in prose. Imports are added; the prose stays accurate. No fix
  needed, but worth a re-read during Step 7 lint pass.

## SmartEditing — why it's deferred

NEXT.md §10 lists SmartEditing as the next §6.2.8 candidate. Audit
during this brainstorming session found that all 5 SmartEditing files
(`SmartEditingEngine.swift`,
`SmartEditing/AutoBracketingEngine.swift`,
`SmartEditing/MultiCursorEditor.swift`,
`SmartEditing/SmartIndentationEngine.swift`,
`SmartEditing/SmartSelectionExpander.swift`) take `CodeEditorView` as
a parameter on every public entry point. A carve-out yields an empty
target.

Three plausible unblock paths, all rejected for this session:

- **Refactor to `CodeEditorViewProtocol`.** §6.2.7 SyntaxHighlighting
  explicitly noted "`CodeEditorViewProtocol` was not promoted"; same
  precedent applies. NEXT.md §9 "Not rewriting any code paths" tilts
  this further out of scope.
- **Wait for §6.2.12 Core split.** This is the §10-blessed answer.
  The Core split is also the riskiest single step in the restructure
  and gets its own dedicated session.
- **Empty target scaffold.** Land an empty `CodeEditorSmartEditing`
  target now, migrate the files later. Churn without payoff.

SmartEditing extraction will be re-spec'd after §6.2.12 lands. The
NEXT.md §6.0 status table and §10 next-session list should record
this so the next reader does not redo the audit.
