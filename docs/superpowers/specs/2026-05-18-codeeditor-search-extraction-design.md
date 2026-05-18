# §6.2.8d CodeEditorSearch extraction — design

**Status:** spec for the next session.
**NEXT.md back-reference:** §6.2.8 (feature engines) → `CodeEditorSearch` row.
**Predecessor in series:** §6.2.8f `CodeEditorWorkspace` (`c1739137`).
**Date:** 2026-05-18.

---

## 1. Architecture & target shape

The §6.2.8d extraction carves the project-wide search surface (`Search/`) into its own SPM target while leaving the in-document find/replace engine (`Features/SearchReplaceEngine.swift`) in the umbrella. The new target is productized as opt-in per NEXT.md §6.3; the umbrella does **not** depend on it.

### New SPM target

`Sources/CodeEditorSearch/` — 1 file:

- `ProjectSearchProvider.swift` (moved from `Sources/CodeEditorPlugin/Search/`).

Surface (all already `public`):

- `ProjectSearchOptions` (request DTO)
- `ProjectSearchResult` (response DTO)
- `ProjectSearchProvider` protocol
- `PortableProjectSearchAdapter` concrete file-walking implementation

### `Package.swift` declarations

```swift
.library(
    name: "CodeEditorSearch",
    targets: ["CodeEditorSearch"]
),
```

```swift
.target(
    name: "CodeEditorSearch",
    swiftSettings: swiftSettings
),
```

No `dependencies:` line — Foundation-only. Mirrors `CodeEditorWorkspace`'s minimal declaration. Productized as a `.library` for opt-in linking (NEXT.md §6.3, "Optional / opt-in" category).

### Inside the umbrella, simultaneously

Relocate `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` to `Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift`. The file's import list is unchanged — it already targets `CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTextModel`, plus AppKit/UIKit. Pure `git mv`. New `Core/Search/` joins the existing F3 buckets: `Core/Configuration/`, `Core/Documents/`, `Core/Folding/`, `Core/Platform/`, `Core/Symbols/`, `Core/SyntaxHighlighting/`, `Core/Text/`.

Why `SearchReplaceEngine.swift` stays in the umbrella: it stores `private weak var textView: CodeEditorView?`, takes `attach(to textView: CodeEditorView)` as its public entry, reads `textView.string`/`.text`/`.selectedRange`/`.textKitBridge`/`.configuration`, and calls `textView.replaceCharacters`/`.scrollRangeToVisible`. Same `CodeEditorView` coupling shape that deferred §6.2.8c `CodeEditorSmartEditing` — every public entry point takes/uses `CodeEditorView`. Extraction is blocked on §6.2.12 Core split. NEXT.md §4.1's `CodeEditorSearch = Features/SearchReplaceEngine.swift + Search/` claim was wrong; only the project-wide piece can move today.

### Public-API removal

`Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift` migrates **out of the umbrella into the sample**, becoming `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`. This removes `EditorController.selectMatch(_ result: ProjectSearchResult)` from the umbrella's public API surface. External consumers — if any — reimplement via the still-public `EditorController.nsLocation(forLSPLine:character:)` + `EditorController.selectRange(_:scroll:)` primitives. The replacement is a 4-line compose; the codebase's convention per `CLAUDE.md` is "delete completely" over backwards-compatibility shims.

### Phase label

Phase 4 ("feature engine"), parallel to Workspace. Build-graph reality: zero deps, so it builds in parallel with phase 0. Semantic-vs-build-graph asymmetry preserved (same as Workspace).

### What this buys

- Hosts that want project-wide find-in-folder without pulling the editor framework can `import CodeEditorSearch` alone.
- The in-document `SearchReplaceEngine` stays adjacent to its `CodeEditorView` owner and travels with the §6.2.12 Core split.
- Umbrella stops shipping a public API that took a `ProjectSearchResult` parameter, removing the cross-target coupling that would otherwise force `import CodeEditorSearch` on every umbrella consumer.

---

## 2. Files in detail

### Moving into `Sources/CodeEditorSearch/` (1 file)

| From | To |
|---|---|
| `Sources/CodeEditorPlugin/Search/ProjectSearchProvider.swift` | `Sources/CodeEditorSearch/ProjectSearchProvider.swift` |

After the move, `Sources/CodeEditorPlugin/Search/` is empty and removed (`git rm -r` after the `git mv`).

### Relocating inside the umbrella (1 file)

| From | To |
|---|---|
| `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` | `Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift` |

The file's imports/code do not change. `git mv` only. Mirrors `Core/Folding/`, `Core/Symbols/` precedents.

### Migrating out of umbrella into sample (1 file)

| From | To |
|---|---|
| `Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift` | `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift` |

In its new home it gains `import CodeEditorPlugin` (for `EditorController`, `selectRange`, `nsLocation`) and `import CodeEditorSearch` (for `ProjectSearchResult`). Keeps the `#if canImport(AppKit)` guard. The `public` keyword on `selectMatch(_:)` is preserved so external consumers can call it on a sample-derived target if they choose.

### Access-modifier promotions: zero predicted

Every symbol in `ProjectSearchProvider.swift` is already `public`:

- `ProjectSearchOptions` struct + all fields + `init` + `static let default`
- `ProjectSearchResult` struct + all fields + `init`
- `ProjectSearchProvider` protocol + all requirements
- `PortableProjectSearchAdapter` final class + all `public func`s + `public init`

Ties §6.2.8f Workspace as the smallest promotion surface in the restructure series.

### `Package.swift` `exclude:` lists

- Umbrella `exclude:` is currently `["Info.plist", "Languages"]`. After this extraction, the umbrella source tree no longer contains `Search/` (the directory is genuinely gone), so the `exclude:` list does **not** change. No defensive exclude needed.
- New `CodeEditorSearch` target has no `exclude:` — single-file root, nothing to exclude.

### Scaffold trap from §6.2.8f

When creating `Sources/CodeEditorSearch/`, the directory needs at least one `.swift` file before SwiftPM accepts a target with a `.library` product. Because `ProjectSearchProvider.swift` moves in the same commit, no placeholder is needed. (Versus Workspace, where the moves happened in a separate task and required both a `.gitkeep` and a placeholder `.swift`.) Single-commit move avoids the trap.

---

## 3. Consumer ripple

### Umbrella (`Sources/CodeEditorPlugin/`)

Zero new dependencies. `ProjectSearch*` references drop to zero after `EditorController+SelectMatch.swift` moves to the sample. The umbrella never imports `CodeEditorSearch`.

### `CodeEditorSample` target (`Package.swift`)

- Add `"CodeEditorSearch"` to `dependencies:`.
- Files that gain `import CodeEditorSearch` (3 confirmed, 1 conditional):
  - `Workspace/ProjectSearchModel.swift` (constructs `PortableProjectSearchAdapter`, conforms to `ProjectSearchProvider`)
  - `Workspace/ProjectSearchPanelView.swift` (consumes `ProjectSearchResult` in `groupedResults`, `resultRow(for:)`, `openResult(_:)`)
  - `EditorActions/EditorController+SelectMatch.swift` (newly relocated)
  - `App/AppState.swift` — **conditional, verify during execution**. `AppState.swift:47` only references `PortableProjectSearchAdapter` in a doc comment; doc comments do not require the import. Expected: no import needed (mirrors §6.2.8f Workspace's "spec over-counted import additions" finding for the analogous doc-comment-only reference). Confirmed sample-imports count: **3**.

### `CodeEditorSampleTests` target (`Package.swift`)

- Add `"CodeEditorSearch"` to `dependencies:`.
- Files that gain `import CodeEditorSearch` (4):
  - `Support/StubProjectSearchProvider.swift` (conforms to `ProjectSearchProvider`)
  - `ProjectSearchModelTests.swift`
  - `WorkspaceSidebarSnapshotTests.swift`
  - `EditorControllerSelectMatchTests.swift`

### `CodeEditorPluginTests` target (`Package.swift`)

- Add `"CodeEditorSearch"` to `dependencies:`.
- `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift` swaps `@testable import CodeEditorPlugin` for `import CodeEditorSearch`. The `@testable` was unnecessary — every symbol it references is already `public`.

### Net new imports across all targets

~8 files (umbrella: 0, sample sources: 3 confirmed + 1 conditional, sample tests: 4, umbrella tests: 1). Slightly larger ripple than §6.2.8f Workspace (~5), driven by the umbrella-out migration of `EditorController+SelectMatch.swift`. SwiftLint's `sorted_imports` rule will reorder to alphabetical module-name order; do not hand-order imports.

### Breaking change for external consumers

`EditorController.selectMatch(_ result: ProjectSearchResult)` disappears from the umbrella public API. Replacement recipe for external consumers:

```swift
let line = result.lineNumber - 1
let character = result.column - 1
if let location = controller.nsLocation(forLSPLine: line, character: character) {
    let range = NSRange(location: location, length: result.matchedText.utf16.count)
    controller.selectRange(range, scroll: true)
}
```

Worth a CHANGELOG-style callout in NEXT.md §6.0 deviations.

---

## 4. Tests

Consistent with §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8f precedents — **no new test target**. The per-library test-target split in NEXT.md §7 is explicitly deferred to §6.2.15 (`CodeEditorTestSupport`); committing to it now is premature.

### `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift`

Stays put. Edits:
- Line 1: `@testable import CodeEditorPlugin` → `import CodeEditorSearch`.

### `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`

Stays in the sample-tests target. Edits depend on its current import set — likely gains `import CodeEditorSearch` and may need to swap `@testable import CodeEditorPlugin` for `@testable import CodeEditorSample` (because the extension being tested now lives in the sample target). Confirmed during execution.

### Other tests

`ProjectSearchModelTests`, `WorkspaceSidebarSnapshotTests`, `Support/StubProjectSearchProvider` stay in `CodeEditorSampleTests` — they're sample-wrapper tests, already there. Imports updated as listed in §3.

### Snapshot tests

None touch Search. Nothing to record.

### Test count delta

Zero. Same tests run in the same targets, just with updated imports.

### Verification

Per CLAUDE.md and the §6.2.8x cadence:

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Targeted re-runs while iterating: `swift test --filter ProjectSearchProvider`, `swift test --filter EditorControllerSelectMatch`.

---

## 5. NEXT.md / CLAUDE.md updates

### NEXT.md

1. **§4.1 phase table.** Update the `CodeEditorSearch` row:
   - "Sources today" column: `Search/` (was: `Features/SearchReplaceEngine.swift`, `Search/`).
   - Append the standard SmartEditing-style footnote that `SearchReplaceEngine` stays in umbrella per §6.2.8d.

2. **§6.0 status table.** Add a new row:
   - Target: `CodeEditorSearch`
   - Commit: `<post-commit SHA>`
   - What landed: 1 file moved to new target (`ProjectSearchProvider.swift`); 1 file relocated inside umbrella to `Core/Search/` (`SearchReplaceEngine.swift`); 1 file migrated to sample (`EditorController+SelectMatch.swift`)
   - Direct deps: (none)

3. **§6.0 — new "Deviations during §6.2.8d `CodeEditorSearch`" subsection.** Document:
   - **Carve-out shape**, mirroring §6.2.8a/b plus one umbrella-out migration. 1 file into new target, 1 file relocated inside umbrella, 1 file migrated to sample.
   - **NEXT.md §4.1's `Search = Features/SearchReplaceEngine.swift + Search/` claim was wrong.** `SearchReplaceEngine` is heavily `CodeEditorView`-coupled (same blocker as SmartEditing). Cannot extract until §6.2.12. New target ships only the project-wide piece.
   - **Productized opt-in** as `.library(name: "CodeEditorSearch", ...)`. Matches Workspace/Diagnostics precedent. §6.3's "Optional / opt-in" list expands.
   - **Umbrella does NOT depend on `CodeEditorSearch`.** Preserved by migrating `EditorController+SelectMatch.swift` to the sample.
   - **Breaking public-API change**: `EditorController.selectMatch(_ result: ProjectSearchResult)` removed from the umbrella. External consumers reimplement via still-public primitives. First cross-restructure public-API removal — note for future contributors that this is a precedent for the §6.2.9 LSP/Debugger extractions, which may also need to thin the umbrella's public surface.
   - **Zero access-modifier promotions.** Ties §6.2.8f Workspace.
   - **Target deps narrower than §6.2.8f baseline.** Pure Foundation, no `#if canImport` (Workspace had AppKit-conditional code inside `MacOSWorkspaceFileManager`).
   - **Phase 4 semantic label vs build-graph reality** preserved.
   - **Test placement** follows §6.2.7/§6.2.8a/§6.2.8b/§6.2.8f precedent — no new test target.

4. **§6.2.8 step list.** Add a `[done — carve-out, see §6.0]` bullet for §6.2.8d with the "1 file moved + 1 relocated + 1 umbrella-out migration" framing.

5. **§6.3 Products to expose.** Add `CodeEditorSearch` to the "Optional / opt-in" line. The spec currently omits it from §6.3's catalog; this extraction is the trigger to add it.

6. **§10 Suggested next session.** Remove Search from the remaining list. Remaining engines become: Annotations, Completion (SmartEditing still deferred on §6.2.12).

7. **§6.0 status header.** Update "Phases 0–4 done; phase 3.5 (SH) carved out" prefix sentence to reflect the additional §6.2.8d landing.

### CLAUDE.md

1. **"Source Tree" ASCII tree.** Remove the `Search/` line entirely. Note that `Core/` now also has a `Core/Search/` sub-bucket (add to the parenthetical list of F3 buckets).

2. **"9 top-level directories … 311 Swift source files"** numbers. Recompute and update during execution. Expected net change:
   - Top-level dirs in umbrella: `9 → 8` (`Search/` removed).
   - Umbrella source files: `311 → 309` (net 2 leave umbrella: `ProjectSearchProvider.swift` → `CodeEditorSearch`, `EditorController+SelectMatch.swift` → sample; `SearchReplaceEngine.swift` moves *within* the umbrella so does not decrement).

3. **"Other source roots" bullet list.** Add `Sources/CodeEditorSearch/` row:
   > `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter (phase 4; new in §6.2.8d). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`).

### Commit pattern

Four commits mirror §6.2.8f Workspace's flow:

1. `Add §6.2.8d CodeEditorSearch extraction design` (this file)
2. `Add §6.2.8d CodeEditorSearch extraction plan` (the to-be-written plan)
3. `Extract CodeEditorSearch target (§6.2.8d)` (the extraction itself, incl. all NEXT.md / CLAUDE.md updates)
4. `Update NEXT.md SHA back-reference for §6.2.8d`

---

## 6. Risks & open questions

### Risks

1. **Breaking public API.** Removing `EditorController.selectMatch(_ result: ProjectSearchResult)` is the first cross-restructure public-API removal. Previous extractions only moved symbols across module boundaries; nothing was lost. External consumers — if any — that depended on this would need to reimplement via the still-public `nsLocation(forLSPLine:character:)` + `selectRange(_:scroll:)` primitives. Cost: low (4-line replacement). Per `CLAUDE.md` preference: delete completely over backwards-compatibility shims. No deprecation shim.

2. **Hidden umbrella consumer.** The grep covered `Sources/` and `Tests/` but if any other in-tree caller of `ProjectSearchResult`/`ProjectSearchOptions`/`PortableProjectSearchAdapter` exists outside those roots (e.g., in `Scripts/`, an Xcode scheme reference, etc.), it would surprise us. Pre-flight task in the implementation plan: exhaustive `git grep` before extraction.

3. **`AppState.swift` doc-comment-only reference.** Line 47 says `/// Project-wide search state + PortableProjectSearchAdapter for the`. This is a doc comment; the type isn't used in the code. Verify whether the import is required (likely **not** — doc comments don't require imports). Mirror §6.2.8f Workspace's "spec over-counted import additions" finding; expect ~3 sample imports, not 4.

4. **Test imports — `@testable` semantics.** `EditorControllerSelectMatchTests.swift` currently does `@testable import CodeEditorPlugin` (presumed). After the move, the extension lives in `CodeEditorSample`. It likely needs `@testable import CodeEditorSample` instead — and possibly drops the `@testable` qualifier if `selectMatch` stays `public` in the sample (which it should, so external consumers can mirror the integration if they pull the sample as a reference target). Confirm during execution.

### Open questions (resolve before writing the plan, not blocking the spec)

1. **Should `ProjectSearchProviderTests` move to `CodeEditorSampleTests` instead of staying in `CodeEditorPluginTests`?** Argument *for moving*: the tested types now live in `CodeEditorSearch`, not the umbrella; testing them via the umbrella's test target is conceptually off. Argument *against*: every prior extraction left target-tests in the umbrella's test target; the per-target-test split is deferred to §6.2.15. **Recommendation: stay in `CodeEditorPluginTests`** (consistent precedent).

2. **Is `EditorController+SelectMatch.swift`'s new sample home `EditorActions/`?** The sample's `EditorActions/` directory already holds `FindReplaceControlling`, `FindReplaceOptions`, `FindReplaceColors`, `FindReplaceModel` — find/replace is the closest cluster. **Recommendation: `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`.**

3. **Resolve the `AppState.swift` import question** during plan execution. Two-line difference; not blocking.

### Non-risks (could *seem* risky, but aren't)

- **`SearchReplaceEngine`'s `import CodeEditorTextModel`.** It already imports the right targets; relocation to `Core/Search/` doesn't change anything about its compile graph.
- **iOS coverage.** `ProjectSearchProvider.swift` is fully cross-platform (no `#if canImport`). Both AppKit and UIKit hosts get the same surface. Cleaner than §6.2.8f Workspace's macOS-only `MacOSWorkspaceFileManager`.
- **Snapshot tests.** None touch Search.
- **Phase 4 vs build-graph asymmetry.** Same semantic-vs-graph mismatch as Workspace; the label is preserved because Search is a feature, not foundational infra.

---

## 7. Non-goals

Per NEXT.md §9, restated for this extraction:

- **No refactoring of `SearchReplaceEngine`.** Its `CodeEditorView` coupling is acknowledged and left for §6.2.12. We do not promote a `SearchableTextView` protocol or thin the engine's dependency surface in this session.
- **No new `CodeEditorSearchTests` target.** Per-target-test split is §6.2.15's call.
- **No symbol renames.** `ProjectSearchOptions`/`Result`/`Provider`/`PortableProjectSearchAdapter` keep their names. The opportunity to rename for clarity (e.g., dropping "Project" since the type is opt-in) is not taken.
- **No new `.library` product for SearchReplaceEngine.** The in-document engine stays as part of the umbrella's surface.
