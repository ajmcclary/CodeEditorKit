# CodeEditorWorkspace Extraction (§6.2.8f) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorWorkspace` SPM target (productized as a `.library`) containing the 2 workspace file-tree files from `Sources/CodeEditorPlugin/Workspace/`. Clean full extraction — no carve-out, no umbrella relocation, no access-modifier promotions, no file splits.

**Architecture:** Single-commit extraction. The umbrella `CodeEditorPlugin` does NOT depend on the new target (opt-in semantics per NEXT.md §6.3). Sample app + Sample tests gain explicit `import CodeEditorWorkspace` in 5 files. First clean full extraction since §6.2.5 `CodeEditorTheming`.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target has zero internal `dependencies:` — both moving files import only `Foundation` (and conditional `AppKit` inside `MacOSWorkspaceFileManager`). No new third-party deps.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-workspace-extraction-design.md` (commit `f57664e2`).

**Spec deviation noted up front:** the spec's "6 files gain a new import" count was wrong. `Sources/CodeEditorSample/App/AppState.swift` only references `WorkspaceFileWatching` in a doc comment (no type usage), so it does NOT need an import. Actual count is **5 files** — listed in Task 4.

---

### Task 1: Pre-flight audit

**Files:**
- Read-only: no edits in this task.

- [ ] **Step 1: Confirm carry-set (2 files in `Workspace/`) is unchanged since spec**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Workspace/
```
Expected: exactly two files print — `WorkspaceFileProtocols.swift` and `MacOSWorkspaceFileManager.swift`. Nothing else.

- [ ] **Step 2: Confirm no umbrella source consumer of Workspace types**

Run:
```bash
grep -rln -E "WorkspaceFileNode|WorkspaceFileEvent|WorkspaceFileTree|WorkspaceFileWatching|MacOSWorkspaceFileManager" Sources/CodeEditorPlugin --include='*.swift' | grep -v "Sources/CodeEditorPlugin/Workspace/"
```
Expected: **no output**. If any umbrella source file prints, capture the path — the plan needs to add `CodeEditorWorkspace` as an umbrella dep (currently treated as opt-in / no umbrella dep). Stop and consult the user if this happens.

- [ ] **Step 3: Confirm consumer-ripple inventory matches the plan**

Run:
```bash
grep -rln -E "WorkspaceFileNode|WorkspaceFileEvent|WorkspaceFileTree|WorkspaceFileWatching|MacOSWorkspaceFileManager" Sources/CodeEditorSample Sources/CodeEditorUI Tests/CodeEditorSampleTests Tests/CodeEditorUITests Tests/CodeEditorPluginTests Tests/CodeEditorDesignTokensTests --include='*.swift' 2>/dev/null | sort -u
```
Expected exactly these 5 paths (sorted):
```
Sources/CodeEditorSample/Workspace/FilePanelView.swift
Sources/CodeEditorSample/Workspace/WorkspaceModel.swift
Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift
Tests/CodeEditorSampleTests/WorkspaceModelTests.swift
Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift
```

Note: `Sources/CodeEditorSample/App/AppState.swift` only references `WorkspaceFileWatching` in a doc comment, so it should NOT appear in this grep. If it does, re-read the file — there is a new code-level reference and Task 4 needs to add it.

- [ ] **Step 4: Capture baseline test pass count**

Run:
```bash
swift test --filter WorkspaceModelTests 2>&1 | tail -5
swift test --filter WorkspaceSidebarSnapshot 2>&1 | tail -5
```
Expected: each prints pass count. Note them in a scratch buffer; Task 5 will verify identical counts.

- [ ] **Step 5: Verify clean working tree**

Run:
```bash
git status --short
```
Expected: no output (clean tree). If there are uncommitted changes, stop and ask the user.

- [ ] **Step 6: Capture starting SHA for the NEXT.md back-reference (used in Task 7 + Task 8)**

Run:
```bash
git log -1 --format=%h
```
Expected: a 7+ char short SHA (currently `f57664e2`, the spec commit). Save it.

---

### Task 2: Scaffold the `CodeEditorWorkspace` target + product

**Files:**
- Create: `Sources/CodeEditorWorkspace/.gitkeep`
- Modify: `Package.swift`

- [ ] **Step 1: Create the new source root with a placeholder**

Run:
```bash
mkdir -p Sources/CodeEditorWorkspace
touch Sources/CodeEditorWorkspace/.gitkeep
```

The `.gitkeep` exists so Step 5 build can succeed against an "empty" target. It's deleted in Task 3.

- [ ] **Step 2: Add the `.library` product entry to `Package.swift`**

Open `Package.swift`. Locate the `products:` array (currently at lines 55–76). Find the `CodeEditorPlugin` product entry:

```swift
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
```

Immediately above it (so alphabetical ordering is preserved between `CodeEditorDiagnostics` and `CodeEditorUI`... wait, `Workspace` is after `UI` alphabetically), insert the new product entry at the right alphabetical position. The final ordering of the `products:` array should be:

```swift
    products: [
        .library(
            name: "CodeEditorDesignTokens",
            targets: ["CodeEditorDesignTokens"]
        ),
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .library(
            name: "CodeEditorWorkspace",
            targets: ["CodeEditorWorkspace"]
        ),
        .executable(
            name: "CodeEditorSample",
            targets: ["CodeEditorSample"]
        )
    ],
```

Use the `Edit` tool with `old_string`:
```swift
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .executable(
            name: "CodeEditorSample",
            targets: ["CodeEditorSample"]
        )
```

and `new_string`:
```swift
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .library(
            name: "CodeEditorWorkspace",
            targets: ["CodeEditorWorkspace"]
        ),
        .executable(
            name: "CodeEditorSample",
            targets: ["CodeEditorSample"]
        )
```

- [ ] **Step 3: Add the target stanza to `Package.swift`**

In `Package.swift`, locate the `CodeEditorSymbols` target stanza (currently around lines 172–179):

```swift
        .target(
            name: "CodeEditorSymbols",
            dependencies: [
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting"
            ],
            swiftSettings: swiftSettings
        ),
```

Immediately after it (and before the `CodeEditorPlugin` umbrella target stanza), insert:

```swift
        .target(
            name: "CodeEditorWorkspace",
            swiftSettings: swiftSettings
        ),
```

Note: no `dependencies:` array (the target has zero internal deps). No `path:` override (the default `Sources/CodeEditorWorkspace/` is correct). No `exclude:` or `resources:`.

- [ ] **Step 4: Add `"Workspace"` to the umbrella `CodeEditorPlugin` target's `exclude:`**

In `Package.swift`, locate the `CodeEditorPlugin` target stanza (currently around lines 180–204). Find its `exclude:` array (currently at lines 197–202):

```swift
            exclude: [
                "Info.plist",
                "Languages",
                "Performance",
                "SyntaxHighlighting"
            ],
```

Use `Edit` to replace with the alphabetically extended list:

```swift
            exclude: [
                "Info.plist",
                "Languages",
                "Performance",
                "SyntaxHighlighting",
                "Workspace"
            ],
```

This is defensive — `Sources/CodeEditorPlugin/Workspace/` becomes empty after Task 3's `git mv` and the directory itself gets removed, so SwiftPM wouldn't double-count anyway. But the explicit `exclude:` entry matches the §6.2.6 / §6.2.7 / §6.2.10 precedent (`Languages`, `SyntaxHighlighting`, `Performance` all stayed in `exclude:` after their source dirs were emptied).

- [ ] **Step 5: Do NOT add `"CodeEditorWorkspace"` to the umbrella's `dependencies:`**

This is the key opt-in design decision from the spec. Verify by reading the umbrella target stanza's `dependencies:` array — it should still end with `"CodeEditorTheming"` followed by the two `.product(...)` entries. No `"CodeEditorWorkspace"` in that list.

- [ ] **Step 6: Add `"CodeEditorWorkspace"` to `CodeEditorSample` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorSample` executable target stanza (currently around lines 215–236). Find its `dependencies:` array (lines 217–228):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                "CodeEditorUI"
            ],
```

Use `Edit` to insert `"CodeEditorWorkspace"` alphabetically (after `"CodeEditorUI"`):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                "CodeEditorUI",
                "CodeEditorWorkspace"
            ],
```

- [ ] **Step 7: Add `"CodeEditorWorkspace"` to `CodeEditorSampleTests` target's `dependencies:`**

In `Package.swift`, locate the `CodeEditorSampleTests` test target stanza (currently around lines 287–302). Find its `dependencies:` array:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

Use `Edit` to insert `"CodeEditorWorkspace"` alphabetically (after `"CodeEditorSample"` and before the `.product(...)` entry):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
                "CodeEditorWorkspace",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

- [ ] **Step 8: Do NOT add `"CodeEditorWorkspace"` to `CodeEditorPluginTests` / `CodeEditorUI` / `CodeEditorUITests` / `CodeEditorDesignTokensTests`**

Verify by reading each of those four target stanzas — none should gain `CodeEditorWorkspace`. Task 1 Step 3 confirmed none of those targets have Workspace consumers.

- [ ] **Step 9: Verify build is green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!` with no errors. The new target has only `.gitkeep` so SPM compiles it as an empty module. The product entry resolves the empty target. The `exclude: ["Workspace"]` on the umbrella does not cause an error because the directory still has 2 files (they move in Task 3).

If the build fails with `the path 'Workspace' is not under Sources/CodeEditorPlugin/`, the umbrella `exclude:` entry is being checked too aggressively — verify the directory still exists with files.

- [ ] **Step 10: No commit yet**

This task bundles with Tasks 3–7 into the single extraction commit (Task 8). Do not commit here.

---

### Task 3: Move the 2 files into `Sources/CodeEditorWorkspace/`

After this task, the umbrella source `Workspace/` directory is empty (and will be removed). The 2 files compile in their new home as an isolated module. The build is RED because the sample app and sample tests still reach Workspace types via their existing `import CodeEditorPlugin` — Task 4 fixes that.

**Files:**
- Delete: `Sources/CodeEditorWorkspace/.gitkeep`
- Move (git mv): 2 files from `Sources/CodeEditorPlugin/Workspace/` → `Sources/CodeEditorWorkspace/`
- Delete (after move): `Sources/CodeEditorPlugin/Workspace/` directory

- [ ] **Step 1: Delete the scaffold placeholder**

Run:
```bash
rm Sources/CodeEditorWorkspace/.gitkeep
```

- [ ] **Step 2: `git mv` the 2 files**

Run:
```bash
git mv Sources/CodeEditorPlugin/Workspace/WorkspaceFileProtocols.swift \
       Sources/CodeEditorWorkspace/WorkspaceFileProtocols.swift
git mv Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift \
       Sources/CodeEditorWorkspace/MacOSWorkspaceFileManager.swift
```

- [ ] **Step 3: Remove the now-empty source directory**

Run:
```bash
rmdir Sources/CodeEditorPlugin/Workspace
```

If `rmdir` fails with "Directory not empty", inspect:
```bash
ls -la Sources/CodeEditorPlugin/Workspace/
```
The likely culprit is a `.DS_Store`. Remove it (`rm Sources/CodeEditorPlugin/Workspace/.DS_Store`) and retry `rmdir`. `.DS_Store` files are not tracked by git and don't affect SwiftPM.

- [ ] **Step 4: Verify the new target compiles in isolation**

Run:
```bash
swift build --target CodeEditorWorkspace 2>&1 | tail -10
```
Expected: `Build complete!` with the new target's 2 files compiled. Foundation-only imports mean no cross-module dependency resolution is needed.

- [ ] **Step 5: Build to confirm the expected red wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```
Expected: build FAILS in the sample app and sample tests. Likely errors:
- `cannot find 'MacOSWorkspaceFileManager' in scope` in `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`
- `cannot find 'WorkspaceFileNode' in scope` in `Sources/CodeEditorSample/Workspace/FilePanelView.swift`
- `cannot find 'WorkspaceFileNode' in scope` in `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`
- `cannot find 'WorkspaceFileNode' in scope` in `Tests/CodeEditorSampleTests/WorkspaceModelTests.swift`
- `cannot find 'WorkspaceFileTree' in scope` in `Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift`

These are expected — Task 4 fixes them.

Capture the exact file paths flagged in the errors. They should match the 5-file list from Task 1 Step 3.

---

### Task 4: Add `import CodeEditorWorkspace` to the 5 consumer files

All 5 files are macOS-only (wrapped in `#if canImport(AppKit)`) and currently reach Workspace types via the umbrella's transitive surface. Each file keeps `import CodeEditorPlugin` (still needed for unrelated umbrella types) and gains `import CodeEditorWorkspace` alphabetically.

**Files:**
- Modify: `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`
- Modify: `Sources/CodeEditorSample/Workspace/FilePanelView.swift`
- Modify: `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`
- Modify: `Tests/CodeEditorSampleTests/WorkspaceModelTests.swift`
- Modify: `Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift`

- [ ] **Step 1: `WorkspaceModel.swift`**

Open `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`. Its current import block reads:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
```

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
```

with `new_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorWorkspace
import Foundation
```

- [ ] **Step 2: `FilePanelView.swift`**

Open `Sources/CodeEditorSample/Workspace/FilePanelView.swift`. Its current import block reads:

```swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI
```

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI
```

with `new_string`:
```swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorWorkspace
import SwiftUI
```

- [ ] **Step 3: `WorkspaceSidebarSnapshotTests.swift`**

Open `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`. Its current import block reads:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
```

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
```

with `new_string`:
```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import CodeEditorWorkspace
@testable import CodeEditorSample
```

Note the alphabetical ordering: `CodeEditorPlugin` < `CodeEditorSample` < `CodeEditorWorkspace` is sorted, but `@testable import CodeEditorSample` is keyed by `CodeEditorSample` for ordering. The result lands `CodeEditorWorkspace` between `CodeEditorPlugin` and the `@testable import CodeEditorSample`.

- [ ] **Step 4: `WorkspaceModelTests.swift`**

Open `Tests/CodeEditorSampleTests/WorkspaceModelTests.swift`. Its current import block reads:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing
```

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
```

with `new_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorWorkspace
@testable import CodeEditorSample
```

- [ ] **Step 5: `StubWorkspaceFileTree.swift`**

Open `Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift`. Its current import block reads:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
```

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
```

with `new_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorWorkspace
import Foundation
```

- [ ] **Step 6: Build per-target to localize any miss**

Run:
```bash
swift build --target CodeEditorSample 2>&1 | tail -20
swift build --target CodeEditorSampleTests 2>&1 | tail -20
```
Expected: both `Build complete!`. If either fails, the error message names the file with the missing reference — go back to the relevant Step (1–5) and verify the import was added.

- [ ] **Step 7: Full build green**

Run:
```bash
swift build 2>&1 | tail -10
```
Expected: `Build complete!`. No errors anywhere.

---

### Task 5: Verification

**Files:** none modified.

- [ ] **Step 1: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```
Expected: zero violations. Strict mode is on (`.swiftlint.yml`), so warnings fail the lint.

If `swiftlint --fix` modifies any source file (e.g., trailing whitespace cleanup), the changes are folded into Task 8's main commit. Do not commit separately.

- [ ] **Step 2: Run targeted tests**

Run:
```bash
swift test --filter WorkspaceModelTests 2>&1 | tail -5
swift test --filter WorkspaceSidebarSnapshot 2>&1 | tail -5
```
Expected: pass counts match the baseline captured in Task 1 Step 4. No new failures, no test count regressions.

- [ ] **Step 3: Skip the full test suite per memory `feedback_test_confirmations.md`**

This is an additive-only restructure with the build green and targeted tests passing. Do NOT run `swift test --parallel` — it adds ~minutes without uncovering anything the targeted filter would miss.

If you have specific reason to suspect a regression (e.g., the umbrella build surfaced an unexpected error fixed in Task 4), run the full suite. Otherwise skip.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorWorkspace/
ls -1 Sources/CodeEditorPlugin/Workspace 2>&1 | head -3
```
Expected:
- `Sources/CodeEditorWorkspace/` contains exactly 2 files: `MacOSWorkspaceFileManager.swift`, `WorkspaceFileProtocols.swift`. No `.gitkeep`.
- `Sources/CodeEditorPlugin/Workspace` prints `No such file or directory` (directory removed in Task 3 Step 3).

- [ ] **Step 5: Sanity check `Package.swift` shape**

Run:
```bash
grep -n "CodeEditorWorkspace" Package.swift
```
Expected: 5 hits:
1. The `.library` product entry (`name: "CodeEditorWorkspace"`)
2. The `.target` stanza (`name: "CodeEditorWorkspace"`)
3. The `targets: ["CodeEditorWorkspace"]` line inside the product entry
4. `"CodeEditorWorkspace"` in `CodeEditorSample.dependencies`
5. `"CodeEditorWorkspace"` in `CodeEditorSampleTests.dependencies`

If you see 0 hits in `CodeEditorPlugin` target (umbrella) `dependencies:`, that's correct (opt-in semantics).

---

### Task 6: Sample app smoke (manual)

**Files:** none modified. This is the only manual gate in the plan.

- [ ] **Step 1: Launch the sample app**

Run:
```bash
swift run CodeEditorSample
```

- [ ] **Step 2: Exercise the workspace surface**

In the sample app, use the File menu (or the "Open Folder…" button if the workspace sidebar shows the empty state) to open a directory — `Sources/` is a reasonable choice since it has nested folders.

Verify:
- The workspace sidebar lists top-level entries
- Expanding a directory shows children
- Clicking a `.swift` file opens it in the editor

- [ ] **Step 3: Edit a file and verify the watcher**

Open a Swift file via the sidebar. In a separate terminal, `touch` an unrelated file inside the open workspace root (e.g., `touch Sources/CodeEditorWorkspace/scratch.tmp`). Within ~2 seconds (the polling interval — see `MacOSWorkspaceFileManager.swift:96`), the sidebar should refresh and show the new entry.

Clean up: `rm Sources/CodeEditorWorkspace/scratch.tmp`. The sidebar should remove it on the next poll.

- [ ] **Step 4: Quit cleanly**

Cmd-Q to quit. No console errors. Per memory `feedback_process_hygiene.md`: if the app does not quit cleanly, kill any stale `CodeEditorSample` / `lldb` processes (`pkill -f CodeEditorSample`) before retrying.

If any step fails, do not proceed to Task 7 — investigate, fix, re-run Task 5, then retry.

---

### Task 7: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

The `(pending commit SHA)` placeholders added in this task get back-filled in Task 8 Step 3 after the extraction commit lands.

- [ ] **Step 1: Update `CLAUDE.md` — remove `Workspace/` from the umbrella source tree**

Open `CLAUDE.md`. Locate the `## Source Tree` code block (currently around lines 45–64). Its last lines read:

```
├── Search/                  # Search result models and shared search support
├── SwiftUI/                 # SwiftUI wrappers and modifiers
└── Workspace/               # Workspace indexing/search types
```

Use `Edit` to replace `old_string`:
```
├── Search/                  # Search result models and shared search support
├── SwiftUI/                 # SwiftUI wrappers and modifiers
└── Workspace/               # Workspace indexing/search types
```

with `new_string`:
```
├── Search/                  # Search result models and shared search support
└── SwiftUI/                 # SwiftUI wrappers and modifiers
```

Note the tree-glyph change: `SwiftUI/` becomes the last entry, so its prefix changes from `├──` to `└──`.

- [ ] **Step 2: Update `CLAUDE.md` — note `Workspace/` joined the pre-extraction list**

In `CLAUDE.md`, locate the line that currently reads (around line 66):

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

Use `Edit` to add `Workspace/` to the list:

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

- [ ] **Step 3: Update `CLAUDE.md` — refresh umbrella file count**

In `CLAUDE.md`, locate the line that currently reads (around line 70):

```
10 top-level directories in the umbrella target, 313 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b), and 592 Swift source files under `Sources/`.
```

Re-count files after the move:
```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
```

Expected: umbrella drops by **2** (`313 → 311`); total stays at `592` (the files moved, not added). Also the directory count drops from 10 → 9 (Workspace/ removed).

Use `Edit` to replace the line with:

```
9 top-level directories in the umbrella target, 311 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8f), and 592 Swift source files under `Sources/`.
```

If the actual `find` counts differ from `311` / `592`, use the actual numbers. The `480` baseline is historical and does not change.

- [ ] **Step 4: Update `CLAUDE.md` — add `CodeEditorWorkspace` to "Other source roots"**

In `CLAUDE.md`, locate the bullet list under "Other source roots (each is its own SPM target — see `Package.swift`):" (starts around line 72). Insert this bullet alphabetically — after `Sources/CodeEditorUI/` and before `Sources/CodeEditorSample/`:

```markdown
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter (phase 4; new in §6.2.8f). Productized as an opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager. iOS adapter is a future session.
```

Use `Edit` to replace `old_string`:
```markdown
- `Sources/CodeEditorUI/` — optional SwiftUI chrome/components.
- `Sources/CodeEditorSample/` — executable demo app target.
```

with `new_string`:
```markdown
- `Sources/CodeEditorUI/` — optional SwiftUI chrome/components.
- `Sources/CodeEditorWorkspace/` — workspace file-tree protocols + macOS `MacOSWorkspaceFileManager` adapter (phase 4; new in §6.2.8f). Productized as an opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; AppKit-conditional manager. iOS adapter is a future session.
- `Sources/CodeEditorSample/` — executable demo app target.
```

- [ ] **Step 5: Update `NEXT.md` §6.0 — append the Workspace row to the status table**

Open `NEXT.md`. Locate the §6.0 status table. The current closing row is the `CodeEditorSymbols` entry (commit `fefe8f93`). Append a new row immediately after:

```markdown
| `CodeEditorWorkspace` | `(pending commit SHA)` | 2 files moved from umbrella `Workspace/` to new target (`WorkspaceFileProtocols.swift`, `MacOSWorkspaceFileManager.swift`). Zero `CodeEditorView` coupling, zero internal SPM deps. Productized as opt-in `.library` per §6.3. Umbrella does NOT depend on it. | (none) |
```

- [ ] **Step 6: Update `NEXT.md` §6.0 — add deviations block**

In `NEXT.md` §6.0, immediately after the §6.2.8b deviations block ("Deviations during §6.2.8b `CodeEditorSymbols` (commit `fefe8f93`):"), insert:

```markdown
**Deviations during §6.2.8f `CodeEditorWorkspace` (commit `(pending)`):**

- **Clean full extraction — no carve-out.** First since §6.2.5 `CodeEditorTheming`. Both moving files are zero-`CodeEditorView`-reference. No `Core/Workspace/` relocation bucket created. NEXT.md §4.1's "Depends on: TextModel" claim was wrong; actual deps are **none** (Foundation only).
- **§6.2.8 ordering reshuffled.** NEXT.md §6.2.8 listed the order as `Folding → Symbols → SmartEditing → Search → Annotations → Workspace → Completion`. SmartEditing is blocked by `CodeEditorView` coupling (all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point — carve-out yields an empty target). Workspace ran first instead because it was the cleanest of the remaining candidates. SmartEditing waits for §6.2.12 Core split.
- **Productized.** Per NEXT.md §6.3's "Optional / opt-in" listing. New `.library(name: "CodeEditorWorkspace", targets: ["CodeEditorWorkspace"])` product entry. Matches the §6.2.10 Diagnostics precedent.
- **Umbrella does NOT depend on the new target.** Opt-in semantics. Public-API surface tightening: consumers doing `import CodeEditorPlugin` no longer get transitive access to Workspace types. The only confirmed in-tree consumer is `CodeEditorSample`; 5 sample / sample-test files gain explicit `import CodeEditorWorkspace`. External consumers should be re-verified at §6.2.16 (move to `~/Workspace/packages/`).
- **Zero access-modifier promotions.** All 5 top-level types (`WorkspaceFileNode`, `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching`, `MacOSWorkspaceFileManager`) were already `public` with explicit `public init`s and `public` members. Smallest promotion surface in the entire restructure series (§6.2.7 had ~107; §6.2.8b had 7).
- **`CodeEditorSample` + `CodeEditorSampleTests` targets gained `CodeEditorWorkspace` as a direct dep.** No other targets changed. `CodeEditorPluginTests`, `CodeEditorUI`, `CodeEditorUITests`, `CodeEditorDesignTokensTests` all unchanged.
- **Spec over-counted import additions.** Spec listed 6 files needing `import CodeEditorWorkspace`. Reality: 5. `Sources/CodeEditorSample/App/AppState.swift` only references `WorkspaceFileWatching` in a doc comment (no type usage); the doc comment compiles without the import.
- **Phase 4 semantic label vs build-graph reality.** Spec labels Workspace as phase 4 (feature engine). With no internal deps, the build graph treats it as parallel to phase 0. Label kept because it's a feature, not foundational infra.
- **iOS coverage asymmetry preserved.** `MacOSWorkspaceFileManager` is AppKit-only (`#if canImport(AppKit)` end-to-end). On iOS, `CodeEditorWorkspace` exposes only the protocols. A future `UIWorkspaceFileManager.swift` adapter is a separate session.
```

- [ ] **Step 7: Update `NEXT.md` §6.2.8 — add Workspace sub-bullet + record SmartEditing deferral**

In `NEXT.md` step 8 of §6.2 ("Extract feature engines individually"), the §6.2.8b Symbols sub-bullet currently closes the list. Immediately below it add:

```markdown
   - **[done — clean extraction, see §6.0]** **`CodeEditorWorkspace`** (§6.2.8f) — 2 files moved cleanly from `Sources/CodeEditorPlugin/Workspace/` to `Sources/CodeEditorWorkspace/`: `WorkspaceFileProtocols.swift`, `MacOSWorkspaceFileManager.swift`. Zero `CodeEditorView` coupling, zero internal SPM deps. Productized as opt-in `.library` per §6.3; umbrella does NOT depend on it. (`(pending)`)
   - **[deferred — blocked on §6.2.12]** **`CodeEditorSmartEditing`** (§6.2.8c) — audit during §6.2.8f brainstorming found all 5 SmartEditing files (`SmartEditingEngine.swift`, `SmartEditing/AutoBracketingEngine.swift`, `SmartEditing/MultiCursorEditor.swift`, `SmartEditing/SmartIndentationEngine.swift`, `SmartEditing/SmartSelectionExpander.swift`) take `CodeEditorView` as a parameter on every public entry point. A carve-out yields an empty target. Re-spec after §6.2.12 Core split removes the coupling.
```

- [ ] **Step 8: Update `NEXT.md` §10 — strike Workspace from "Suggested next session" and record SmartEditing deferral**

In `NEXT.md` §10, the first bullet currently reads (after §6.2.8b):

```markdown
- **6.2.8 feature engines** — `SmartEditing`, `Search`, `Annotations`, `Workspace`, `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0). Full extraction of the engines themselves blocked on §6.2.12 Core split removing `CodeEditorView` coupling. One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

Replace with:

```markdown
- **6.2.8 feature engines** — `Search`, `Annotations`, `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0); `Workspace` is done (§6.2.8f, clean extraction — see §6.0); `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

- [ ] **Step 9: Update `NEXT.md` §10 "Suggested next session" preamble**

Locate the preamble line at the top of §10:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, and 6.2.10 are done (see §6.0). Remaining work:
```

Replace with:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8f, and 6.2.10 are done (see §6.0). Remaining work:
```

- [ ] **Step 10: Verify build + lint after doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```
Expected: both clean. (Markdown edits don't affect compilation, but verify anyway in case the doc-update steps accidentally touched a `.swift` file.)

---

### Task 8: Main extraction commit + SHA back-fill

**Files:** none modified in this task; commit + record SHA back into `NEXT.md`.

- [ ] **Step 1: Stage all changes from Tasks 2–7**

Run:
```bash
git add Sources/CodeEditorWorkspace \
        Sources/CodeEditorPlugin \
        Sources/CodeEditorSample \
        Tests/CodeEditorSampleTests \
        Package.swift \
        CLAUDE.md \
        NEXT.md
git status --short
```

Expected output:
- 2 renames: `Sources/CodeEditorPlugin/Workspace/{WorkspaceFileProtocols,MacOSWorkspaceFileManager}.swift` → `Sources/CodeEditorWorkspace/...`
- Modifications to `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`, `Sources/CodeEditorSample/Workspace/FilePanelView.swift`
- Modifications to `Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift`, `Tests/CodeEditorSampleTests/WorkspaceModelTests.swift`, `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`
- Modifications to `Package.swift`, `CLAUDE.md`, `NEXT.md`

If any unexpected files appear (e.g., `.DS_Store`, snapshot regeneration), investigate before committing.

- [ ] **Step 2: Create the main extraction commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorWorkspace target (§6.2.8f)

Move 2 files from Sources/CodeEditorPlugin/Workspace/ into a
new CodeEditorWorkspace SPM target:
  - WorkspaceFileProtocols.swift
  - MacOSWorkspaceFileManager.swift

Clean full extraction — no carve-out, no umbrella relocation,
no access-modifier promotions. First since §6.2.5 Theming.
Both moving files have zero CodeEditorView coupling and import
only Foundation (the manager wraps everything in
#if canImport(AppKit)).

Productized as a .library per NEXT.md §6.3's opt-in listing,
matching the §6.2.10 Diagnostics precedent. The umbrella
CodeEditorPlugin target does NOT depend on the new target;
consumers opt in via explicit `import CodeEditorWorkspace`.
In-tree, CodeEditorSample + CodeEditorSampleTests gain the
new dep and 5 sample / sample-test files gain the new import.

Also records the deferral of §6.2.8c CodeEditorSmartEditing
in NEXT.md §6.0 / §10: brainstorming-time audit found that
all 5 SmartEditing files take CodeEditorView as a parameter
on every public entry point, so a carve-out yields an empty
target. Re-spec after §6.2.12 Core split removes the coupling.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-workspace-extraction-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-workspace-extraction.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Capture the commit SHA and back-fill `NEXT.md` placeholders**

Run:
```bash
git log -1 --format=%h
```
Save the short SHA (e.g., `abc1234`).

Open `NEXT.md` and replace each `(pending commit SHA)` / `(pending)` placeholder added in Task 7 with the actual SHA. Specifically:
- Task 7 Step 5: the status-table cell `| \`(pending commit SHA)\` |` becomes `| \`<SHA>\` |`.
- Task 7 Step 6: the deviations-block header `Deviations during §6.2.8f \`CodeEditorWorkspace\` (commit \`(pending)\`):` becomes `... (commit \`<SHA>\`):`.
- Task 7 Step 7: the §6.2.8 sub-bullet trailing `(\`(pending)\`)` becomes `(\`<SHA>\`)`.

- [ ] **Step 4: Amend the SHA back-fill into the commit**

Run:
```bash
git add NEXT.md
git commit --amend --no-edit
```

This amends only the SHA back-fill into the most recent (extraction) commit. The amended commit replaces the original within the same SHA-prefix horizon — verify by inspecting Step 5.

Note: `git log -1 --format=%h` after the amend will show a different SHA (amending rewrites the commit). The new SHA is what's now in `NEXT.md`. Double-check by running:
```bash
git log -1 --format=%h
git show --stat HEAD | head -3
```

If the SHA shown in NEXT.md differs from the post-amend SHA, re-do Step 3 with the post-amend SHA and `git commit --amend --no-edit` again.

Some prior extraction commits (§6.2.8a, §6.2.8b) used a separate follow-up commit instead of `--amend` for the SHA back-fill. Either approach is fine; the `--amend` form here keeps the history tighter for a small additive change. If you prefer the follow-up-commit pattern, skip Step 4 entirely and let Task 8 end at Step 3 — the SHA-update commit becomes a separate atomic change matching `51751af2` / `bf6aeb64`.

- [ ] **Step 5: Verify final git state**

Run:
```bash
git log -3 --oneline
git status --short
```
Expected:
- The new extraction commit on top of the spec commit `f57664e2`.
- Working tree clean.

- [ ] **Step 6: Stop. Do not push.**

The user will review the local commit and push when ready.
