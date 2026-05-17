# CodeEditorFolding Extraction (§6.2.8a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorFolding` SPM target containing the 4 pure fold-storage / provider-registry files; relocate the 4 `CodeEditorView`-coupled fold files inside the umbrella to `Core/Folding/`.

**Architecture:** Carve-out extraction matching §6.2.7 (SyntaxHighlighting) exactly: pure leaf files move to a new sibling target; umbrella-coupled glue is relocated under `Core/<Domain>/` to mark the F3 bucket explicitly. Two commits — pre-relocation (Task 3) and main extraction (Task 10) — mirroring §6.2.7's `818df5f6` → `f2798287` sequence.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target depends on `CodeEditorCommon`, `CodeEditorLanguages`, `CodeEditorSyntaxHighlighting`, `CodeEditorTextModel`. No new third-party deps.

**Spec:** `docs/superpowers/specs/2026-05-17-codeeditor-folding-extraction-design.md` (commit `4f0f8238`).

---

### Task 1: Pre-flight audit

**Files:**
- Read-only: no edits in this task.

- [ ] **Step 1: Confirm carry-set (4 files) and relocation-set (4 files)**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Features/{CodeFoldingEngine,FoldPresentationStrategy,FoldRegionAdapter,FoldStoreElement,FoldableRegion,FoldingOperationsService,FoldingProviderRegistry,LineFoldStorage}.swift
```
Expected: all 8 paths print with no error.

- [ ] **Step 2: Confirm no Sample/UI direct dependency on the 4 moving types**

Run:
```bash
grep -rn -E "FoldStoreElement|LineFoldStorage|FoldInfo\b|FoldRegionAdapter|FoldingProviderRegistry" Sources/CodeEditorSample Sources/CodeEditorUI 2>/dev/null
```
Expected: no output. If output appears, capture the file list — those targets will need `CodeEditorFolding` added as a dependency in Task 2.

- [ ] **Step 3: Enumerate exact umbrella consumer files (used in Task 5)**

Run:
```bash
grep -rln -E "FoldStoreElement|LineFoldStorage|FoldInfo\b|FoldRegionAdapter|FoldingProviderRegistry" Sources/CodeEditorPlugin Tests/CodeEditorPluginTests | sort -u
```
Expected: a list of paths. The 4 source files in `Sources/CodeEditorPlugin/Features/` that are about to move appear in this list — ignore them. The remaining entries are the import targets. Save this list verbatim for Task 5.

- [ ] **Step 4: Confirm `CodeEditorError.serviceUnavailable("CodeFoldingEngine")` identifier string is referenced by tests**

Run:
```bash
grep -n "CodeFoldingEngine\"" Tests/CodeEditorPluginTests/ReviewRemediationRegressionTests.swift
```
Expected: two hits at lines ~99 and ~142 referencing the string `"CodeFoldingEngine"`. The string must stay stable (no rename across this extraction).

- [ ] **Step 5: Capture baseline test pass count**

Run:
```bash
swift test --filter LineFoldStorage 2>&1 | tail -5
swift test --filter FoldingProviderOutput 2>&1 | tail -5
swift test --filter CodeFoldingEngine 2>&1 | tail -5
swift test --filter FeatureBehavior 2>&1 | tail -5
```
Expected: each prints pass count. Note them in a scratch buffer; Task 7 will verify identical counts.

- [ ] **Step 6: Verify clean working tree**

Run:
```bash
git status --short
```
Expected: no output (clean tree). If there are uncommitted changes, stop and ask the user.

---

### Task 2: Scaffold the `CodeEditorFolding` target

**Files:**
- Create: `Sources/CodeEditorFolding/.gitkeep`
- Modify: `Package.swift`

- [ ] **Step 1: Create the new source root with a placeholder**

Run:
```bash
mkdir -p Sources/CodeEditorFolding
touch Sources/CodeEditorFolding/.gitkeep
```

- [ ] **Step 2: Add the target stanza to `Package.swift`**

Open `Package.swift`. Locate the `CodeEditorDiagnostics` target stanza. Immediately after the `CodeEditorSyntaxHighlighting` target stanza (and before the `CodeEditorPlugin` umbrella target stanza), insert:

```swift
        .target(
            name: "CodeEditorFolding",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
```

- [ ] **Step 3: Add the dependency to `CodeEditorPlugin` umbrella target**

In `Package.swift`, locate the `CodeEditorPlugin` target stanza. In its `dependencies:` array, insert `"CodeEditorFolding"` alphabetically (between `"CodeEditorDiagnostics"` and `"CodeEditorLanguages"`):

```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            ...
```

- [ ] **Step 4: Add the dependency to `CodeEditorPluginTests` target**

In `Package.swift`, locate the `CodeEditorPluginTests` test target stanza. Add `"CodeEditorFolding"` alphabetically to its `dependencies:` array (right after `"CodeEditorDiagnostics"`).

- [ ] **Step 5: If Step 2 of Task 1 found Sample/UI references, add the dep there too**

If `CodeEditorSample` was in the output from Task 1 Step 2, add `"CodeEditorFolding"` to its `dependencies:` array alphabetically.

If `CodeEditorUI` was in the output, do the same for the `CodeEditorUI` target.

Otherwise, skip this step.

- [ ] **Step 6: Verify build is green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!` and no errors. The new target has only the `.gitkeep` so SPM compiles it as an empty module.

- [ ] **Step 7: Commit the scaffold**

This step intentionally has no commit — Task 3's commit bundles the scaffold + relocation together so the diff stays self-contained.

---

### Task 3: Pre-relocation commit — move 4 coupled files to `Core/Folding/`

Mirrors §6.2.7's `818df5f6`. After this task, all 8 fold source files still live in the umbrella target; only their paths change.

**Files:**
- Create directory: `Sources/CodeEditorPlugin/Core/Folding/`
- Move (git mv): 4 files from `Sources/CodeEditorPlugin/Features/` → `Sources/CodeEditorPlugin/Core/Folding/`
- Rename one of them: `FoldableRegion.swift` → `CodeFoldingConfiguration.swift`

- [ ] **Step 1: Create the `Core/Folding/` directory**

Run:
```bash
mkdir -p Sources/CodeEditorPlugin/Core/Folding
```

- [ ] **Step 2: `git mv` the 4 coupled files**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift           Sources/CodeEditorPlugin/Core/Folding/
git mv Sources/CodeEditorPlugin/Features/FoldingOperationsService.swift    Sources/CodeEditorPlugin/Core/Folding/
git mv Sources/CodeEditorPlugin/Features/FoldPresentationStrategy.swift    Sources/CodeEditorPlugin/Core/Folding/
git mv Sources/CodeEditorPlugin/Features/FoldableRegion.swift              Sources/CodeEditorPlugin/Core/Folding/CodeFoldingConfiguration.swift
```

The last command renames `FoldableRegion.swift` to `CodeFoldingConfiguration.swift` because the file only contains `CodeFoldingConfiguration` — the actual `FoldableRegion` struct lives in `CodeEditorLanguages` since §6.2.6.

- [ ] **Step 3: Verify build is still green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!`. All 8 files are still in the umbrella target; only paths changed.

- [ ] **Step 4: Verify tests still pass**

Run:
```bash
swift test --filter LineFoldStorage 2>&1 | tail -3
swift test --filter CodeFoldingEngine 2>&1 | tail -3
```
Expected: same pass counts as Task 1 Step 5.

- [ ] **Step 5: Commit the relocation**

Run:
```bash
git add Sources/CodeEditorPlugin/Core/Folding Sources/CodeEditorPlugin/Features Sources/CodeEditorFolding Package.swift
git commit -m "$(cat <<'EOF'
Relocate umbrella-coupled fold glue to Core/Folding/

CodeFoldingEngine, FoldingOperationsService,
FoldPresentationStrategy, and CodeFoldingConfiguration
(renamed from misnamed FoldableRegion.swift) move from
Features/ to Core/Folding/ as the explicit "umbrella-
coupled fold glue" sub-bucket. Mirrors §6.2.7's
Core/SyntaxHighlighting/ relocation in 818df5f6.

Also scaffolds the CodeEditorFolding target stanza in
Package.swift with an empty source root (placeholder
.gitkeep). Subsequent commit moves the 4 pure fold
files into the new target.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Verify commit landed cleanly**

Run:
```bash
git log -1 --stat | head -20
```
Expected: 5 file changes (4 renames + Package.swift + .gitkeep), no other files touched.

---

### Task 4: Move the 4 pure files into `Sources/CodeEditorFolding/`

After this task, the build is RED — the relocated files in `Core/Folding/` reference types that are now in a separate module. Tasks 5–6 restore green.

**Files:**
- Delete: `Sources/CodeEditorFolding/.gitkeep`
- Move (git mv): 4 files from `Sources/CodeEditorPlugin/Features/` → `Sources/CodeEditorFolding/`

- [ ] **Step 1: Delete the scaffold placeholder**

Run:
```bash
rm Sources/CodeEditorFolding/.gitkeep
```

- [ ] **Step 2: `git mv` the 4 pure files**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/FoldStoreElement.swift         Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/LineFoldStorage.swift          Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldRegionAdapter.swift        Sources/CodeEditorFolding/
git mv Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift  Sources/CodeEditorFolding/
```

- [ ] **Step 3: Build to capture the error wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```
Expected: build FAILS with errors of the form `cannot find 'FoldStoreElement' in scope`, `cannot find 'LineFoldStorage' in scope`, `cannot find 'FoldingProviderRegistry' in scope`, `cannot find 'FoldRegionAdapter' in scope`, `cannot find 'FoldInfo' in scope`. These are expected — Task 5 fixes them.

Capture the exact file paths flagged in the errors. They should match the list captured in Task 1 Step 3.

---

### Task 5: Add `import CodeEditorFolding` to umbrella + test callers

**Files:** based on Task 1 Step 3 + Task 4 Step 3 outputs. Expected list:

- `Sources/CodeEditorPlugin/Core/Folding/CodeFoldingEngine.swift`
- `Sources/CodeEditorPlugin/Core/Folding/FoldPresentationStrategy.swift`
- `Sources/CodeEditorPlugin/Core/Folding/FoldingOperationsService.swift` (verify — may not be needed)
- `Sources/CodeEditorPlugin/Core/CodeFoldingCoordinatorService.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeFoldingExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CoreExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+SyntaxHighlightingExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+ConfigurationExtensions.swift`
- `Sources/CodeEditorPlugin/Layout/GutterViewModel.swift`
- `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`
- `Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift`
- `Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift`
- `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`
- `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`
- `Tests/CodeEditorPluginTests/Features/LineFoldStorageTests.swift`
- `Tests/CodeEditorPluginTests/Features/FoldingProviderOutputTests.swift`
- (verify) `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift`
- (verify) `Tests/CodeEditorPluginTests/Features/CodeFoldingEngineLineSpanTests.swift`
- (verify) `Tests/CodeEditorPluginTests/Features/CodeFoldingEngineCacheEvictionTests.swift`

- [ ] **Step 1: For each file in the list above, add `import CodeEditorFolding`**

For each file, locate the existing import block at the top. Insert `import CodeEditorFolding` alphabetically among the other `CodeEditor*` imports.

Example (`Sources/CodeEditorPlugin/Layout/GutterViewModel.swift`):

Before:
```swift
import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
```

After:
```swift
import CodeEditorCommon
import CodeEditorFolding
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
```

Use `Edit` with the exact existing import-block string for the `old_string` argument. Do not use `replace_all`; each file's import block is unique.

- [ ] **Step 2: Build to capture the next error wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```
Expected: build still FAILS, but errors now shift to access-level errors of the form `'FoldStoreElement' is inaccessible due to 'internal' protection level` or `'FoldingProviderRegistry' is inaccessible due to 'internal' protection level`. Task 6 promotes them.

If you see lingering `cannot find` errors, return to Step 1 for the file that flagged them.

---

### Task 6: Promote access modifiers (`internal` → `package`)

**Files:** all four under `Sources/CodeEditorFolding/`.

- [ ] **Step 1: Promote `FoldStoreElement`**

Edit `Sources/CodeEditorFolding/FoldStoreElement.swift`. Replace each occurrence of `internal ` (with trailing space) with `package ` (with trailing space) on these lines: the struct declaration, every stored property, the `isEmpty` computed property, the `init`, and the `empty` static.

After edit, the file's top should read:

```swift
import CodeEditorLanguages
import CodeEditorTextModel
import Foundation

/// Fold metadata stored in a `RangeStore`.
///
/// Each run represents a fold at a given character range with a stable
/// identifier and collapse state. Adjacent empty runs (no fold) are
/// automatically coalesced by `RangeStore`.
package struct FoldStoreElement: RangeStoreElement, Sendable, Equatable {
    /// Stable identifier preserved across recalculations.
    package var id: String?

    /// Nesting depth (0 = top-level).
    package var depth: Int

    /// Whether the fold is currently collapsed.
    package var isCollapsed: Bool

    /// The fold type (function, block, comment, etc.).
    package var kind: FoldingType

    /// `true` when this element carries no fold data.
    package var isEmpty: Bool { id == nil }

    package init(id: String?, depth: Int, isCollapsed: Bool, kind: FoldingType) {
        self.id = id
        self.depth = depth
        self.isCollapsed = isCollapsed
        self.kind = kind
    }

    /// An empty element (gap between folds).
    package static var empty: Self {
        Self(id: nil, depth: 0, isCollapsed: false, kind: .region)
    }
}
```

- [ ] **Step 2: Promote `LineFoldStorage` and `FoldInfo`**

Edit `Sources/CodeEditorFolding/LineFoldStorage.swift`. Promote:

- The struct declaration `internal struct LineFoldStorage: Sendable` → `package struct LineFoldStorage: Sendable`
- The `internal init(documentLength:)` → `package init(documentLength:)`
- The `var documentLength: Int { store.documentLength }` line — change to `package var documentLength: Int { store.documentLength }` (it currently has no modifier and defaults to `internal`)
- Every `internal mutating func` or `internal func` → `package mutating func` / `package func`
- The `internal struct FoldInfo: Sendable, Equatable` declaration and its `internal var` fields → `package struct FoldInfo: Sendable, Equatable` and `package var` fields

Leave `private struct StoredFold`, `private var store`, `private var foldsByID`, `private mutating func rebuildStoreFromIndex()`, `private func transform(...)`, `private func intersects(...)` UNCHANGED. They are leaf helpers, not part of the public surface.

- [ ] **Step 3: Promote `FoldRegionAdapter`**

Edit `Sources/CodeEditorFolding/FoldRegionAdapter.swift`. Promote:

- `internal final class FoldRegionAdapter` → `package final class FoldRegionAdapter`
- `init(provider:)` (currently no modifier) → `package init(provider:)`
- `func buildStorage(from:existingStorage:)` (currently no modifier) → `package func buildStorage(from:existingStorage:)`
- `func applyEdit(to:editedRange:changeInLength:)` (currently no modifier) → `package func applyEdit(to:editedRange:changeInLength:)`

- [ ] **Step 4: Promote `FoldingProviderRegistry`**

Edit `Sources/CodeEditorFolding/FoldingProviderRegistry.swift`. Promote:

- `internal final class FoldingProviderRegistry` → `package final class FoldingProviderRegistry`
- `init()` (currently no modifier) → `package init()`
- Every `internal func registerProvider/provider/hasProvider/removeProvider` → `package func ...`
- `internal var registeredLanguages: [Language]` → `package var registeredLanguages: [Language]`

Leave `private func setupDefaultProviders()` UNCHANGED.

- [ ] **Step 5: Build until green**

Run:
```bash
swift build 2>&1 | tail -60
```

If the build still FAILS with access-level errors, the failing line shows the exact symbol. Promote it in its file (one of the 4 above) and re-run. Expect at most 2–3 iterations.

When it returns `Build complete!`, proceed.

---

### Task 7: Verification

**Files:** none modified.

- [ ] **Step 1: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```
Expected: zero violations. Strict mode is on (`.swiftlint.yml`), so warnings fail the lint.

- [ ] **Step 2: Run targeted tests**

Run:
```bash
swift test --filter LineFoldStorage 2>&1 | tail -5
swift test --filter FoldingProviderOutput 2>&1 | tail -5
swift test --filter CodeFoldingEngine 2>&1 | tail -5
swift test --filter FeatureBehavior 2>&1 | tail -5
swift test --filter ComprehensivePerformance 2>&1 | tail -5
```
Expected: pass counts match the baseline captured in Task 1 Step 5. No new failures, no test count regressions.

- [ ] **Step 3: Build the sample app**

Run:
```bash
swift build --target CodeEditorSample 2>&1 | tail -10
```
Expected: `Build complete!`.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorFolding/
ls -1 Sources/CodeEditorPlugin/Core/Folding/
ls -1 Sources/CodeEditorPlugin/Features/ | grep -i fold || echo "(no fold files in Features/ — correct)"
```
Expected:
- `Sources/CodeEditorFolding/` contains exactly 4 files: `FoldRegionAdapter.swift`, `FoldStoreElement.swift`, `FoldingProviderRegistry.swift`, `LineFoldStorage.swift`. No `.gitkeep`.
- `Sources/CodeEditorPlugin/Core/Folding/` contains exactly 4 files: `CodeFoldingConfiguration.swift`, `CodeFoldingEngine.swift`, `FoldPresentationStrategy.swift`, `FoldingOperationsService.swift`.
- `Features/` no longer has any `*Fold*` files.

---

### Task 8: Sample app smoke (manual)

**Files:** none modified. This is the only manual gate in the plan.

- [ ] **Step 1: Launch the sample app**

Run:
```bash
swift run CodeEditorSample
```

- [ ] **Step 2: Open a Swift source file**

In the sample app, open any Swift file (e.g., `Sources/CodeEditorPlugin/Core/Folding/CodeFoldingEngine.swift`). Verify syntax highlighting renders and the gutter shows line numbers.

- [ ] **Step 3: Fold and unfold a region**

Hover over the gutter beside a function declaration. Click the chevron. The function body should collapse to a `⋯` indicator. Click the chevron again. The body should expand.

- [ ] **Step 4: Save and reopen**

Make a small edit, save (Cmd-S), close, reopen. Folding state behavior should match pre-change baseline (per `CodeFoldingConfiguration.saveFoldState`).

- [ ] **Step 5: Quit cleanly**

Cmd-Q to quit. No console errors.

If any step fails, do not proceed — investigate, fix, re-run Task 7, then retry.

---

### Task 9: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

- [ ] **Step 1: Update `CLAUDE.md` — add `CodeEditorFolding` to "Other source roots"**

Open `CLAUDE.md`. Locate the bullet list under `## Source Tree` that begins with "Other source roots (each is its own SPM target — see `Package.swift`):". Insert this bullet alphabetically (between `CodeEditorDiagnostics` and `Sources/CodeEditorPlugin/Languages/`):

```markdown
- `Sources/CodeEditorFolding/` — fold storage primitives (`FoldStoreElement`, `LineFoldStorage`, `FoldInfo`), `FoldRegionAdapter`, and `FoldingProviderRegistry` (phase 4; new in §6.2.8a).
```

- [ ] **Step 2: Update `CLAUDE.md` — note `Core/Folding/` sub-bucket**

Locate the source-tree comment block that lists `Core/` sub-buckets (currently includes "F3 sub-buckets: `Configuration/`, `Documents/`, `Platform/`, `SyntaxHighlighting/`, `Text/`"). Add `Folding/` to that list:

Before:
```markdown
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Platform/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

After:
```markdown
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

- [ ] **Step 3: Update `CLAUDE.md` — refresh umbrella file count**

In `CLAUDE.md`, locate the line that currently reads (approximately):

```
10 top-level directories in the umbrella target, 319 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7), and 591 Swift source files under `Sources/`.
```

Re-count files after the move. Run:
```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
```

Update both numbers in the line. The umbrella file count drops by 4 (the 4 files moved to `CodeEditorFolding`); the total under `Sources/` is unchanged (same files, different target).

- [ ] **Step 4: Update `NEXT.md` §6.0 — add row to status table**

Open `NEXT.md`. Locate the §6.0 status table that currently ends with the `CodeEditorSyntaxHighlighting` row. Append a new row immediately after:

```markdown
| `CodeEditorFolding` | (pending commit SHA) | 4 pure fold-storage / provider-registry files from `Features/` (`FoldStoreElement`, `LineFoldStorage`, `FoldRegionAdapter`, `FoldingProviderRegistry`). 4 `CodeEditorView`-coupled files (`CodeFoldingEngine`, `FoldingOperationsService`, `FoldPresentationStrategy`, `CodeFoldingConfiguration` — renamed from misnamed `FoldableRegion.swift`) relocated to umbrella `Core/Folding/` in pre-commit (see Task 3). | Common, Languages, SyntaxHighlighting, TextModel |
```

The `(pending commit SHA)` placeholder will be filled in Task 10 after the commit lands.

- [ ] **Step 5: Update `NEXT.md` §6.0 — add deviations block**

In `NEXT.md` §6.0, immediately after the §6.2.7 deviations block, insert:

```markdown
**Deviations during §6.2.8a `CodeEditorFolding` (commit `(pending)`):**

- **Half the carry-set turned out to be `CodeEditorView`-coupled.** Brainstorm-time scope was 8 files; reality after import survey was 4 pure + 4 coupled. Carve-out adopted exactly like §6.2.7: 4 pure files moved to `Sources/CodeEditorFolding/`; 4 coupled files (`CodeFoldingEngine`, `FoldingOperationsService`, `FoldPresentationStrategy`, `CodeFoldingConfiguration`) relocated to `Core/Folding/` in pre-commit.
- **`CodeFoldingConfiguration` placement revised.** Brainstorming initially placed it in the new target. With the engine staying in umbrella, all three consumers (`CodeFoldingEngine`, `FoldingOperationsService`, `EditorConfiguration+CodeFolding` bridge) are now umbrella files, so the config stays with them. Avoids forcing an `import CodeEditorFolding` on every consumer for a 19-line struct.
- **`Features/FoldableRegion.swift` renamed to `Core/Folding/CodeFoldingConfiguration.swift`.** The filename was misleading — the file only ever contained `CodeFoldingConfiguration`. The actual `FoldableRegion` struct has lived in `CodeEditorLanguages` since §6.2.6.
- **Direct deps narrower than §6.2.7's pattern.** Folding's target deps are `Common, Languages, SyntaxHighlighting, TextModel` — no `Diagnostics` (only `CodeFoldingEngine` used it; stays in umbrella), no `Platform` (only `CodeFoldingConfiguration` used `PlatformColors`; stays in umbrella).
- **~5 `internal` → `package` promotions** across `FoldStoreElement`, `LineFoldStorage`, `FoldInfo`, `FoldRegionAdapter`, `FoldingProviderRegistry`. Smaller than §6.2.7's ~107 promotions because the moving surface is smaller (4 files vs. 36).
- **No productization.** Matches Languages / SyntaxHighlighting precedent. Folding is core to the editor; no consumer opts out.
- **`CodeEditorPluginTests` target gained `CodeEditorFolding` as a direct dep.** Sample / UI did not require new deps (verified in Step 0 pre-flight).
```

- [ ] **Step 6: Update `NEXT.md` §6.2.8 — mark Folding as done (carve-out)**

In `NEXT.md` step 8 of §6.2 ("Extract feature engines individually"), the bullet currently reads:

```markdown
8. **Extract feature engines individually** — `Completion`, `Folding`, `SmartEditing`, `Search`, `Symbols`, `Annotations`, `Workspace`. ...
```

Below that bullet add:

```markdown
   - **[done — carve-out, see §6.0]** **`CodeEditorFolding`** (§6.2.8a) — 4 pure files moved to `Sources/CodeEditorFolding/`; 4 `CodeEditorView`-coupled files (`CodeFoldingEngine`, `FoldingOperationsService`, `FoldPresentationStrategy`, `CodeFoldingConfiguration`) relocated to `Core/Folding/`. Full extraction completes after §6.2.12 Core split lifts the `CodeEditorView` coupling.
```

- [ ] **Step 7: Update `NEXT.md` §10 — resolve question 2**

In `NEXT.md` §10 ("Suggested next session"), find the numbered point about `CodeFoldingConfiguration`. It currently reads:

```markdown
2. **`Features/` contains `CodeFoldingConfiguration`, which Configuration's `createCodeFoldingConfiguration()` references.** ...
```

Replace with:

```markdown
2. **[resolved §6.2.8a]** **`CodeFoldingConfiguration` stays in umbrella** at `Core/Folding/CodeFoldingConfiguration.swift`. Its three consumers (`CodeFoldingEngine`, `FoldingOperationsService`, `EditorConfiguration+CodeFolding` bridge) are all umbrella files. The bridge file unchanged; gains no new import.
```

- [ ] **Step 8: Verify all four `swift build` / `swift test --filter` / `swiftlint` checks still pass after the doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```
Expected: both clean. (Markdown edits don't affect compilation, but verify anyway.)

---

### Task 10: Main extraction commit

**Files:** none modified in this task; commit + record SHA back into `NEXT.md`.

- [ ] **Step 1: Stage all changes from Tasks 4–9**

Run:
```bash
git add Sources/CodeEditorFolding Sources/CodeEditorPlugin Tests/CodeEditorPluginTests CLAUDE.md NEXT.md
git status --short
```
Expected: shows the 4 file renames (Features → CodeEditorFolding), modifications to ~14 umbrella source files (new imports), modifications to 6 test files (new imports), and modifications to CLAUDE.md + NEXT.md.

- [ ] **Step 2: Create the main extraction commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorFolding target (§6.2.8a)

Move 4 pure fold-storage / provider-registry files from
Sources/CodeEditorPlugin/Features/ to a new
CodeEditorFolding SPM target:
  - FoldStoreElement.swift
  - LineFoldStorage.swift
  - FoldRegionAdapter.swift
  - FoldingProviderRegistry.swift

The 4 CodeEditorView-coupled fold files relocated to
Core/Folding/ in the pre-relocation commit, mirroring
§6.2.7's 818df5f6 → f2798287 sequence.

Target deps: Common, Languages, SyntaxHighlighting,
TextModel. ~5 internal→package promotions across the
moving surface. CodeEditorPluginTests gains the new
target as a direct dep. Sample / UI unchanged.

Spec: docs/superpowers/specs/2026-05-17-codeeditor-folding-extraction-design.md
Plan: docs/superpowers/plans/2026-05-17-codeeditor-folding-extraction.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Capture the commit SHA and back-fill placeholders in `NEXT.md`**

Run:
```bash
git log -1 --format=%h
```
Save the short SHA (e.g., `abc1234`).

Open `NEXT.md` and replace each `(pending commit SHA)` / `(pending)` placeholder added in Task 9 with the actual SHA.

Also fetch the SHA of the relocation commit from Task 3:
```bash
git log -2 --format=%h
```
The second SHA in the output (one commit prior to the just-created extraction commit) is the relocation commit; reference it inside the deviations block if useful.

- [ ] **Step 4: Amend the back-fill into the commit**

Run:
```bash
git add NEXT.md
git commit --amend --no-edit
```

This amends only the SHA back-fill into the most recent (extraction) commit. The relocation commit (one earlier) is not touched.

- [ ] **Step 5: Verify final git state**

Run:
```bash
git log -3 --oneline
git status --short
```
Expected:
- Two new commits on top of the spec-revision commit `4f0f8238`: the relocation commit and the amended extraction commit.
- Working tree clean.

- [ ] **Step 6: Stop. Do not push.**

The user will review the local commits and push when ready.
