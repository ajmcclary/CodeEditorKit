# CodeEditorSearch Extraction (§6.2.8d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorSearch` SPM target (productized as a `.library`) containing the single `ProjectSearchProvider.swift` file from `Sources/CodeEditorPlugin/Search/`. Carve-out matching §6.2.8a/§6.2.8b shape: the `CodeEditorView`-coupled `SearchReplaceEngine.swift` stays in the umbrella and relocates to `Core/Search/`; the umbrella's public `EditorController.selectMatch(_:)` extension migrates out to the sample, removing it from the umbrella's public API surface.

**Architecture:** Two code commits + one SHA back-fill commit. Pre-relocation commit (Task 2) shuffles the umbrella's shape (relocates `SearchReplaceEngine.swift` to `Core/Search/` + migrates `EditorController+SelectMatch.swift` to the sample). Main extraction commit (Task 9) creates the new target, moves `ProjectSearchProvider.swift`, adds imports, updates docs. Umbrella does NOT depend on the new target (opt-in semantics per NEXT.md §6.3). Sample + sample-tests + umbrella-tests gain explicit `import CodeEditorSearch`. First cross-restructure removal of a public umbrella API.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target has zero internal `dependencies:` — `ProjectSearchProvider.swift` imports only `Foundation`. No new third-party deps. No `#if canImport` (pure cross-platform; cleaner than §6.2.8f Workspace's AppKit-conditional manager).

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-search-extraction-design.md` (commit `59e6150b`).

**Spec deviation noted up front:** the spec's "~4 sample imports" was conservative — `Sources/CodeEditorSample/App/AppState.swift` only references `PortableProjectSearchAdapter` in a doc comment (no type usage), so it does NOT need a new import. Confirmed count in Task 5: **3 sample-source imports + 4 sample-test imports + 1 umbrella-test import = 8** files.

---

### Task 1: Pre-flight audit

**Files:**
- Read-only: no edits in this task.

- [ ] **Step 1: Confirm carry-set is unchanged since spec**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Search/
ls -1 Sources/CodeEditorPlugin/Features/Search*
ls -1 Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift
```
Expected:
- `Sources/CodeEditorPlugin/Search/` prints exactly one file: `ProjectSearchProvider.swift`.
- `Features/Search*` prints exactly one file: `SearchReplaceEngine.swift`.
- The third command prints the SelectMatch file path (one line).

If any other file appears in `Search/`, stop and consult the user.

- [ ] **Step 2: Exhaustive consumer survey of `ProjectSearch*` types**

Run:
```bash
grep -rln -E "ProjectSearchProvider|PortableProjectSearchAdapter|ProjectSearchResult|ProjectSearchOptions" Sources Tests --include='*.swift' | sort -u
```

Expected exactly these 10 paths:
```
Sources/CodeEditorPlugin/Search/ProjectSearchProvider.swift
Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift
Sources/CodeEditorSample/App/AppState.swift
Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift
Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift
Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift
Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift
Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift
Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift
Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift
```

If any extra path appears (e.g., in `Sources/CodeEditorPlugin/Core/`, `Sources/CodeEditorUI/`, or anywhere else), stop and re-spec — the carve-out shape changes. If a path is missing (e.g., grep returns 9 paths), one of the consumers was removed; verify it isn't load-bearing before proceeding.

- [ ] **Step 3: Verify `AppState.swift` doc-comment-only reference**

Run:
```bash
grep -n "ProjectSearch" Sources/CodeEditorSample/App/AppState.swift
```

Expected exactly:
```
47:    /// Project-wide search state + PortableProjectSearchAdapter for the
49:    let projectSearchModel = ProjectSearchModel()
```

Line 47 is a doc comment (`///` prefix) — the `PortableProjectSearchAdapter` token there is in a comment, not used as a type. Line 49 uses `ProjectSearchModel`, which is a sample type (declared in `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`), not a `CodeEditorSearch` type. **Conclusion:** `AppState.swift` does not need `import CodeEditorSearch`.

If line 47 has been removed or rewritten, or line 49 has been changed to construct `PortableProjectSearchAdapter()` directly, re-evaluate: the import may now be required. Add `import CodeEditorSearch` to `AppState.swift` in Task 5 if so.

- [ ] **Step 4: Confirm `SearchReplaceEngine.swift` is still `CodeEditorView`-coupled**

Run:
```bash
grep -n "CodeEditorView\|textView" Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift | head -20
```

Expected: ~20 hits, including `private weak var textView: CodeEditorView?` (line 27 currently) and `public func attach(to textView: CodeEditorView)` (line 34 currently). If the engine has been refactored to not depend on `CodeEditorView`, stop and re-spec — the whole file may now be a candidate to move into the new target instead of relocating to `Core/Search/`.

- [ ] **Step 5: Confirm `Core/Search/` does not yet exist**

Run:
```bash
ls -la Sources/CodeEditorPlugin/Core/Search 2>&1 | head -3
```

Expected: `No such file or directory`. If the directory exists with files, stop — something has already been staged here in a way the plan doesn't anticipate.

- [ ] **Step 6: Verify `EditorController.nsLocation` and `EditorController.selectRange` are still public**

Run:
```bash
grep -n "public func nsLocation\|public func selectRange" Sources/CodeEditorPlugin/SwiftUI/EditorController.swift
```

Expected: 2 hits — `public func selectRange(_ range: NSRange, scroll: Bool = true)` and `public func nsLocation(forLSPLine line: Int, character: Int) -> Int?`. Both are required by the relocated `EditorController+SelectMatch.swift` after it moves to the sample. If either is no longer public, stop — the migration plan needs to also expose them.

- [ ] **Step 7: Capture baseline test pass count**

Run:
```bash
swift test --filter ProjectSearchProvider 2>&1 | tail -5
swift test --filter EditorControllerSelectMatch 2>&1 | tail -5
swift test --filter SearchReplaceEngine 2>&1 | tail -5
```

Expected: each prints a pass count (`SearchReplaceEngine` may report 0 matches if there's no test class with that exact name — the engine is exercised by `FeatureBehaviorTests`, which has many entries; that's fine). Save the numbers in a scratch buffer. Tasks 6 and 9 verify identical counts.

- [ ] **Step 8: Verify clean working tree**

Run:
```bash
git status --short
```

Expected: no output. If there are uncommitted changes, stop and ask the user.

- [ ] **Step 9: Capture starting SHA for the NEXT.md back-reference**

Run:
```bash
git log -1 --format=%h
```

Expected: `59e6150b` (the spec commit). Save the SHA — Task 8 will need it (the design-spec back-reference) and Task 9 will compute the post-extraction SHA.

---

### Task 2: Pre-relocation commit — reshape the umbrella

This is the §6.2.8a/§6.2.8b pre-commit equivalent. Two moves happen here:

1. **Relocate** `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` → `Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift` (inside the umbrella).
2. **Migrate** `Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift` → `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift` (out of the umbrella, into the sample). Update its imports.

After this task, the umbrella source no longer ships `EditorController.selectMatch(_:)`. The sample now exposes that same `selectMatch(_:)` extension. Build must stay green — no consumer of the umbrella's `selectMatch` exists in-tree outside the sample.

**Files:**
- Move (git mv): `Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift` → `Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift`
- Move (git mv): `Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift` → `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`
- Modify: `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift` (add `import CodeEditorPlugin`)
- Modify: `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift` (drop `@testable import CodeEditorPlugin` qualifier — see Step 5)

- [ ] **Step 1: Create the `Core/Search/` directory**

Run:
```bash
mkdir -p Sources/CodeEditorPlugin/Core/Search
```

- [ ] **Step 2: `git mv` SearchReplaceEngine into `Core/Search/`**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift \
       Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift
```

The file's contents do not change. Its imports (`CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTextModel`, `Foundation`, conditional `AppKit`/`UIKit`) are unaffected by the move because all referenced targets are sibling packages, not umbrella-internal.

- [ ] **Step 3: `git mv` EditorController+SelectMatch into the sample**

Run:
```bash
git mv Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift \
       Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift
```

The file becomes a public `extension EditorController` declared in the sample target. Because `EditorController` is `public` in the umbrella and the extension's methods will remain `public`, anyone who imports both `CodeEditorPlugin` and `CodeEditorSample` will see the extension. The sample currently imports the umbrella, so this works.

- [ ] **Step 4: Add `import CodeEditorPlugin` to the relocated SelectMatch file**

Open `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`. Its current import block reads:

```swift
#if canImport(AppKit)
import Foundation
```

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import Foundation
```

with `new_string`:
```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
```

(Alphabetical order: `CodeEditorPlugin` < `Foundation`. SwiftLint's `sorted_imports` rule will enforce this; pre-sorting is fine.)

Why this import is needed now: previously the file was *inside* `CodeEditorPlugin`, so `EditorController`, `nsLocation(forLSPLine:character:)`, and `selectRange(_:scroll:)` were all visible by name. Now the file is in the sample module, which is downstream of `CodeEditorPlugin`. The import makes those symbols visible.

Note: `ProjectSearchResult` is still in the umbrella at this point (it doesn't move until Task 4). So no `import CodeEditorSearch` is needed yet — that lands in Task 5.

- [ ] **Step 5: Drop unnecessary `@testable` from `EditorControllerSelectMatchTests.swift`**

Open `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`. Current imports:

```swift
#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing
```

The `@testable import CodeEditorPlugin` qualifier was there because the test exercises `selectMatch` (now relocated to the sample) and historically the extension was umbrella-internal. After Step 3, the extension is in the sample (still `public`), so `@testable` for the umbrella is no longer required for the `selectMatch` call site. However, the test also calls `CodeEditorView(frame: .zero)` and `controller.attach(to: view)` — those are `public` in the umbrella, so plain `import` works. Drop the `@testable` qualifier on `CodeEditorPlugin`.

Use `Edit` to replace `old_string`:
```swift
@testable import CodeEditorPlugin
@testable import CodeEditorSample
```

with `new_string`:
```swift
import CodeEditorPlugin
@testable import CodeEditorSample
```

(The `@testable import CodeEditorSample` stays — sample-internal helpers like `makeAttached` are out of scope for changes here, and `@testable` doesn't hurt.)

Note: `ProjectSearchResult` is still in the umbrella, so `import CodeEditorPlugin` covers it. Task 5 Step 6 will add `import CodeEditorSearch` once the type moves.

- [ ] **Step 6: Confirm `Features/` is now empty of Search files but not deleted**

Run:
```bash
ls Sources/CodeEditorPlugin/Features/ | grep -i search
```
Expected: no output. `Features/` still contains other files (`SmartEditingEngine.swift`, `DebuggerIntegration*.swift`, etc.), so the directory itself stays.

Run:
```bash
ls Sources/CodeEditorPlugin/SwiftUI/ | grep -i selectmatch
```
Expected: no output. `EditorController+SelectMatch.swift` is gone from the umbrella.

- [ ] **Step 7: Build green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!`. The umbrella still compiles because `SearchReplaceEngine.swift` is still part of the `CodeEditorPlugin` target (just at a different path under `Core/Search/`). The sample compiles because the relocated SelectMatch file imports `CodeEditorPlugin` and the umbrella still exposes `ProjectSearchResult`.

If the build fails with `cannot find 'EditorController' in scope` in the sample, you missed Step 4 — add `import CodeEditorPlugin`.

If it fails with `cannot find 'ProjectSearchResult' in scope`, the umbrella's `Search/` directory may have been touched accidentally — verify `ls Sources/CodeEditorPlugin/Search/` still prints `ProjectSearchProvider.swift`.

- [ ] **Step 8: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```

Expected: zero violations. If `sorted_imports` adjusts the import order in either edited file, that's expected — accept the autofix.

- [ ] **Step 9: Targeted test pass**

Run:
```bash
swift test --filter EditorControllerSelectMatch 2>&1 | tail -10
swift test --filter SearchReplaceEngine 2>&1 | tail -10
swift test --filter FeatureBehaviorTests 2>&1 | tail -10
```

Expected: counts match the Task 1 Step 7 baseline. Skip the full `swift test --parallel` per `feedback_test_confirmations.md`.

- [ ] **Step 10: Stage and commit the pre-relocation**

Run:
```bash
git add Sources/CodeEditorPlugin Sources/CodeEditorSample Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift
git status --short
```

Expected output (the two renames + one source modification + one test modification):
- `R  Sources/CodeEditorPlugin/Features/SearchReplaceEngine.swift -> Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift`
- `R  Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift -> Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`
- `M  Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`
- `M  Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`

If any other files appear, investigate before committing.

- [ ] **Step 11: Create the pre-relocation commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Relocate umbrella-coupled SearchReplaceEngine + migrate SelectMatch

Pre-commit for the §6.2.8d CodeEditorSearch extraction, mirroring
§6.2.8a's 9704e80b and §6.2.8b's 5d670076.

  1. SearchReplaceEngine.swift moves from Features/ to Core/Search/.
     The in-document find/replace engine stays in the umbrella because
     every public entry point uses CodeEditorView; the relocation just
     marks the F3 bucket explicitly.

  2. EditorController+SelectMatch.swift moves out of the umbrella into
     CodeEditorSample (EditorActions/). The umbrella stops shipping
     `EditorController.selectMatch(_ result: ProjectSearchResult)` as
     public API; the sample owns that integration. External consumers
     can reimplement using the still-public `nsLocation(forLSPLine:character:)`
     and `selectRange(_:scroll:)` primitives.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-search-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Capture the pre-commit SHA**

Run:
```bash
git log -1 --format=%h
```

Save this SHA — Task 8 will record it in NEXT.md's deviations block.

---

### Task 3: Scaffold the `CodeEditorSearch` target + product

**Files:**
- Modify: `Package.swift`

No file is created in this task; the new source directory is created in Task 4 alongside the file move. Because the source move and the `Package.swift` edits all land in the same final commit (Task 9), there's no intermediate broken state.

Important: do **not** commit between Tasks 3 and 9. Build green is the only checkpoint until the main extraction commit. Tasks 3–8 bundle into the Task 9 commit.

- [ ] **Step 1: Add the `.library` product entry to `Package.swift`**

Open `Package.swift`. Locate the `products:` array. The current end of the list is:

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
    ],
```

Alphabetical placement: `CodeEditorSearch` slots between `CodeEditorPlugin` and `CodeEditorUI`. Locate the `CodeEditorPlugin` product entry:

```swift
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
```

Use `Edit` to replace `old_string`:
```swift
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
```

with `new_string`:
```swift
        .library(
            name: "CodeEditorPlugin",
            targets: ["CodeEditorPlugin"]
        ),
        .library(
            name: "CodeEditorSearch",
            targets: ["CodeEditorSearch"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
```

- [ ] **Step 2: Add the target stanza to `Package.swift`**

Locate the `CodeEditorSymbols` target stanza followed by `CodeEditorWorkspace`. Currently the relevant chunk reads:

```swift
        .target(
            name: "CodeEditorSymbols",
            dependencies: [
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorWorkspace",
            swiftSettings: swiftSettings
        ),
```

Alphabetical placement: `CodeEditorSearch` goes between `CodeEditorPlatform` and `CodeEditorSymbols`. Locate the `CodeEditorPlatform` target stanza (lines ~109–112):

```swift
        .target(
            name: "CodeEditorPlatform",
            dependencies: ["CodeEditorCommon"],
            swiftSettings: swiftSettings
        ),
```

Use `Edit` to insert the `CodeEditorSearch` stanza after `CodeEditorPlugin` and before `CodeEditorSymbols`. Look at the actual ordering — `CodeEditorPlugin` is followed by `CodeEditorSyntaxHighlighting` then `CodeEditorSymbols` in the targets array (verify by reading the file). The new stanza inserts before `CodeEditorSyntaxHighlighting` alphabetically.

The exact `Edit` depends on the current adjacent text. Run:
```bash
grep -n "name: \"CodeEditorSymbols\"\|name: \"CodeEditorSyntaxHighlighting\"\|name: \"CodeEditorPlatform\"" Package.swift
```

Use the surrounding lines to construct the `Edit` `old_string`/`new_string`. The result must place:

```swift
        .target(
            name: "CodeEditorSearch",
            swiftSettings: swiftSettings
        ),
```

immediately before `CodeEditorSymbols` (alphabetical order: `Search` < `Symbols` < `SyntaxHighlighting`).

No `dependencies:` array (Foundation-only target). No `path:` override (default `Sources/CodeEditorSearch/` is correct). No `exclude:` or `resources:`. Mirrors `CodeEditorWorkspace`'s minimal stanza.

- [ ] **Step 3: Do NOT add `"CodeEditorSearch"` to the umbrella `CodeEditorPlugin` target's `dependencies:`**

This is the opt-in design decision. Verify the umbrella target's `dependencies:` array still ends with `"CodeEditorTheming"` followed by the two `.product(...)` entries. No `"CodeEditorSearch"` in that list.

- [ ] **Step 4: Add `"CodeEditorSearch"` to `CodeEditorSample` target's `dependencies:`**

Locate the `CodeEditorSample` executable target stanza. Its `dependencies:` currently reads:

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

Use `Edit` to insert `"CodeEditorSearch"` alphabetically (between `"CodeEditorPlugin"` and `"CodeEditorTextModel"`):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                "CodeEditorUI",
                "CodeEditorWorkspace"
            ],
```

- [ ] **Step 5: Add `"CodeEditorSearch"` to `CodeEditorSampleTests` target's `dependencies:`**

Locate the `CodeEditorSampleTests` test target stanza. Its `dependencies:` currently reads:

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

Use `Edit` to insert `"CodeEditorSearch"` alphabetically (between `"CodeEditorSample"` and `"CodeEditorWorkspace"`):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSample",
                "CodeEditorSearch",
                "CodeEditorWorkspace",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

- [ ] **Step 6: Add `"CodeEditorSearch"` to `CodeEditorPluginTests` target's `dependencies:`**

Locate the `CodeEditorPluginTests` test target stanza. Its `dependencies:` currently reads:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

Use `Edit` to insert `"CodeEditorSearch"` alphabetically (between `"CodeEditorPlugin"` and `"CodeEditorSymbols"`):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorPlugin",
                "CodeEditorSearch",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
```

- [ ] **Step 7: Do NOT add `"CodeEditorSearch"` to `CodeEditorUI` / `CodeEditorUITests` / `CodeEditorDesignTokensTests`**

Verify by reading each stanza — none should gain `CodeEditorSearch`. Task 1 Step 2 confirmed none of those targets have ProjectSearch consumers.

- [ ] **Step 8: Build will fail — that's expected**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: build FAILS with one of these errors:
- `error: target 'CodeEditorSearch' referenced in product 'CodeEditorSearch' could not be found`
- `error: the path 'Sources/CodeEditorSearch' does not exist`

That's because the target exists in Package.swift but `Sources/CodeEditorSearch/` doesn't yet. Task 4 fixes that. Do **not** stop here — proceed directly to Task 4.

---

### Task 4: Move `ProjectSearchProvider.swift` into the new target

After this task, `Sources/CodeEditorPlugin/Search/` is empty (and removed); `Sources/CodeEditorSearch/` contains the single file. Build is RED in the consumers because they still resolve `ProjectSearchResult`/`ProjectSearchOptions`/`ProjectSearchProvider`/`PortableProjectSearchAdapter` via the umbrella — Task 5 fixes that.

**Files:**
- Create: `Sources/CodeEditorSearch/` directory
- Move (git mv): 1 file from `Sources/CodeEditorPlugin/Search/` → `Sources/CodeEditorSearch/`
- Delete (after move): `Sources/CodeEditorPlugin/Search/` directory

- [ ] **Step 1: Create the new source root**

Run:
```bash
mkdir -p Sources/CodeEditorSearch
```

No placeholder `.swift` or `.gitkeep` needed — the file move in Step 2 happens in the same logical task, so SwiftPM never sees an empty source directory.

- [ ] **Step 2: `git mv` the single file**

Run:
```bash
git mv Sources/CodeEditorPlugin/Search/ProjectSearchProvider.swift \
       Sources/CodeEditorSearch/ProjectSearchProvider.swift
```

The file's contents do not change. It already imports only `Foundation`, has no `CodeEditorView` reference, and exposes everything `public`.

- [ ] **Step 3: Remove the now-empty umbrella source directory**

Run:
```bash
rmdir Sources/CodeEditorPlugin/Search
```

If `rmdir` fails with "Directory not empty", inspect:
```bash
ls -la Sources/CodeEditorPlugin/Search/
```
The likely culprit is a `.DS_Store`. Remove it (`rm Sources/CodeEditorPlugin/Search/.DS_Store`) and retry `rmdir`. `.DS_Store` files are not tracked by git and don't affect SwiftPM.

- [ ] **Step 4: Verify the new target compiles in isolation**

Run:
```bash
swift build --target CodeEditorSearch 2>&1 | tail -10
```

Expected: `Build complete!`. Foundation-only imports mean no cross-module resolution is needed.

- [ ] **Step 5: Build to confirm the expected red wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```

Expected: build FAILS in sample sources, sample tests, and umbrella tests. Likely errors:

- `cannot find 'PortableProjectSearchAdapter' in scope` in `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`
- `cannot find 'ProjectSearchProvider' in scope` in `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`
- `cannot find 'ProjectSearchResult' in scope` in `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`
- `cannot find 'ProjectSearchResult' in scope` in `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`
- `cannot find 'PortableProjectSearchAdapter' in scope` in `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift`
- `cannot find 'ProjectSearchOptions' in scope` in `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift`
- `cannot find 'ProjectSearchProvider' in scope` in `Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift`
- `cannot find 'ProjectSearchOptions' in scope` in `Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift`
- `cannot find 'ProjectSearchResult' in scope` in `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`
- `cannot find 'ProjectSearchResult' in scope` in `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`

These are expected — Task 5 fixes them. Capture the list and cross-check against the Task 1 Step 2 inventory: the failing files should be exactly those 9 paths (10 minus `Sources/CodeEditorPlugin/SwiftUI/EditorController+SelectMatch.swift`, which moved in Task 2, minus `Sources/CodeEditorPlugin/Search/ProjectSearchProvider.swift`, which is now the new target). If `Sources/CodeEditorSample/App/AppState.swift` shows up, it means the doc-comment-only audit from Task 1 Step 3 was wrong — return to Task 1 to re-check.

---

### Task 5: Add `import CodeEditorSearch` to the consumer files

Each consumer file gains `import CodeEditorSearch` in alphabetical order with its existing imports. SwiftLint's `sorted_imports` will reorder automatically; pre-sorting in this task just avoids a follow-up autofix delta.

**Files:**
- Modify: `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`
- Modify: `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`
- Modify: `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`
- Modify: `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift`
- Modify: `Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift`
- Modify: `Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift`
- Modify: `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`
- Modify: `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`

- [ ] **Step 1: `ProjectSearchModel.swift`**

Open `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`. Read the first 10 lines to confirm the current import block. Expected current imports (alphabetical):

```swift
import CodeEditorPlugin
import Foundation
```

(There may also be a `#if canImport(AppKit)` wrapper — preserve it.)

Use `Edit` to insert `import CodeEditorSearch` alphabetically (between `CodeEditorPlugin` and `Foundation`):

old: `import CodeEditorPlugin\nimport Foundation`
new: `import CodeEditorPlugin\nimport CodeEditorSearch\nimport Foundation`

If the actual import order differs, use the actual lines.

- [ ] **Step 2: `ProjectSearchPanelView.swift`**

Open `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`. Read the first 10 lines. Expected current imports include `CodeEditorPlugin`, `Foundation`, and likely `SwiftUI`. Insert `import CodeEditorSearch` alphabetically after `CodeEditorPlugin`.

If the file currently reads:
```swift
import CodeEditorPlugin
import Foundation
import SwiftUI
```

use `Edit` to replace with:
```swift
import CodeEditorPlugin
import CodeEditorSearch
import Foundation
import SwiftUI
```

- [ ] **Step 3: `EditorController+SelectMatch.swift` (in the sample)**

Open `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`. Current import block (set up in Task 2 Step 4):

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
import CodeEditorSearch
import Foundation
```

- [ ] **Step 4: `ProjectSearchProviderTests.swift`**

Open `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift`. Current imports:

```swift
@testable import CodeEditorPlugin
import Foundation
import Testing
```

The `@testable` qualifier is unnecessary — every symbol the test touches (`PortableProjectSearchAdapter`, `ProjectSearchOptions`) is `public`. Swap to a plain `import` and switch the module:

Use `Edit` to replace `old_string`:
```swift
@testable import CodeEditorPlugin
import Foundation
import Testing
```

with `new_string`:
```swift
import CodeEditorSearch
import Foundation
import Testing
```

(SwiftLint's `sorted_imports` accepts `CodeEditorSearch` before `Foundation`. If the original file used a `# imports` blank-line grouping or doc-comment header, preserve those lines verbatim.)

- [ ] **Step 5: `Support/StubProjectSearchProvider.swift`**

Open `Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift`. Read its current import block. Expected:

```swift
import CodeEditorPlugin
import Foundation
```

Use `Edit` to replace with:
```swift
import CodeEditorPlugin
import CodeEditorSearch
import Foundation
```

If the original has `import Foundation` only (no `CodeEditorPlugin` import — because the stub only conforms to `ProjectSearchProvider`), use:

old: `import Foundation`
new: `import CodeEditorSearch\nimport Foundation`

Read the file first to confirm which case applies.

- [ ] **Step 6: `ProjectSearchModelTests.swift`**

Open `Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift`. Read the first ~10 lines. Likely current:

```swift
@testable import CodeEditorSample
import Foundation
import Testing
```

Insert `import CodeEditorSearch` alphabetically:

```swift
import CodeEditorSearch
@testable import CodeEditorSample
import Foundation
import Testing
```

(SwiftLint sorts by module name, so `CodeEditorSearch` lands before `CodeEditorSample` if you look at letters S-A vs S-E... wait, `CodeEditorS-A-M-P-L-E` < `CodeEditorS-E-A-R-C-H` alphabetically, so `@testable import CodeEditorSample` comes first. Let me reorder.)

Correct alphabetical order:
```swift
@testable import CodeEditorSample
import CodeEditorSearch
import Foundation
import Testing
```

If `ProjectSearchProvider` is referenced (it is — the file uses `StubProjectSearchProvider`), the test target's `import CodeEditorSearch` covers it via the test-target dep added in Task 3 Step 5.

- [ ] **Step 7: `WorkspaceSidebarSnapshotTests.swift`**

Open `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`. Read its first ~12 lines. Likely current:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import CodeEditorWorkspace
@testable import CodeEditorSample
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
```

Insert `import CodeEditorSearch` alphabetically — between `CodeEditorPlugin` and `CodeEditorWorkspace` (S-E-A < S-A-M < W-O-R, so order is `CodeEditorPlugin` < `CodeEditorSearch` < `CodeEditorWorkspace`... wait, `S-A-M-P-L-E` < `S-E-A-R-C-H`, so `@testable import CodeEditorSample` < `import CodeEditorSearch`):

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import CodeEditorSearch
import CodeEditorWorkspace
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
```

- [ ] **Step 8: `EditorControllerSelectMatchTests.swift`**

Open `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`. Current imports (after Task 2 Step 5):

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing
```

Insert `import CodeEditorSearch` between `@testable import CodeEditorSample` and `import Foundation`:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import CodeEditorSearch
import Foundation
import Testing
```

- [ ] **Step 9: Build per-target to localize any miss**

Run:
```bash
swift build --target CodeEditorSearch 2>&1 | tail -5
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: both `Build complete!`. If `CodeEditorSample` fails, the error names the file with the missing reference — return to the relevant Step (1–3) and verify the import was added.

- [ ] **Step 10: Full build green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. No errors anywhere. The targeted-per-test-file build doesn't directly include the test targets above; SwiftPM picks them up in this full pass.

If `Tests/...` files still fail, return to Steps 4–8 and verify their imports.

---

### Task 6: Verification

**Files:** none modified.

- [ ] **Step 1: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```

Expected: zero violations. Strict mode is on, so warnings fail the lint. If `swiftlint --fix` modifies any source file (e.g., import reorder, trailing-whitespace cleanup), the changes are folded into Task 9's main commit. Do not commit separately.

- [ ] **Step 2: Run targeted tests**

Run:
```bash
swift test --filter ProjectSearchProvider 2>&1 | tail -5
swift test --filter EditorControllerSelectMatch 2>&1 | tail -5
swift test --filter ProjectSearchModel 2>&1 | tail -5
swift test --filter WorkspaceSidebarSnapshot 2>&1 | tail -5
swift test --filter FeatureBehaviorTests 2>&1 | tail -5
```

Expected: pass counts match the baselines captured in Task 1 Step 7 (and the in-doc `SearchReplaceEngine` exercise via `FeatureBehaviorTests`). No new failures, no test count regressions.

- [ ] **Step 3: Skip the full test suite per memory `feedback_test_confirmations.md`**

This is an additive-only restructure with the build green and targeted tests passing. Do NOT run `swift test --parallel` — it adds ~minutes without uncovering anything the targeted filter would miss.

If you have specific reason to suspect a regression (e.g., the umbrella build surfaced an unexpected error fixed in Task 5), run the full suite. Otherwise skip.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorSearch/
ls -1 Sources/CodeEditorPlugin/Search 2>&1 | head -3
ls -1 Sources/CodeEditorPlugin/Core/Search/
ls -1 Sources/CodeEditorSample/EditorActions/ | grep -i selectmatch
ls -1 Sources/CodeEditorPlugin/SwiftUI/ | grep -i selectmatch
```

Expected:
- `Sources/CodeEditorSearch/` contains exactly `ProjectSearchProvider.swift`.
- `Sources/CodeEditorPlugin/Search` prints `No such file or directory` (removed in Task 4 Step 3).
- `Sources/CodeEditorPlugin/Core/Search/` contains exactly `SearchReplaceEngine.swift`.
- The sample's `EditorActions/` lists `EditorController+SelectMatch.swift`.
- The umbrella's `SwiftUI/` directory does NOT list `EditorController+SelectMatch.swift` (it migrated to the sample in Task 2).

- [ ] **Step 5: Sanity check `Package.swift` shape**

Run:
```bash
grep -n "CodeEditorSearch" Package.swift
```

Expected: 6 hits:
1. The `.library` product entry (`name: "CodeEditorSearch"`)
2. `targets: ["CodeEditorSearch"]` inside the product entry
3. The `.target` stanza (`name: "CodeEditorSearch"`)
4. `"CodeEditorSearch"` in `CodeEditorSample.dependencies`
5. `"CodeEditorSearch"` in `CodeEditorSampleTests.dependencies`
6. `"CodeEditorSearch"` in `CodeEditorPluginTests.dependencies`

If you see a hit in `CodeEditorPlugin` target (umbrella) `dependencies:`, that's a bug — remove it. Opt-in semantics require the umbrella to NOT depend on the new target.

---

### Task 7: Sample app smoke (manual)

**Files:** none modified. This is the only manual gate in the plan.

- [ ] **Step 1: Launch the sample app**

Run:
```bash
swift run CodeEditorSample
```

If a prior instance is still running, kill it first per `feedback_process_hygiene.md`:
```bash
pkill -f CodeEditorSample 2>/dev/null
pkill -f lldb 2>/dev/null
```

- [ ] **Step 2: Exercise the in-document find/replace surface**

In the sample app, open any sample document. Cmd-F to open Find. Type a token that exists in the text (e.g., `let`). Verify:
- The find bar highlights matches in the document.
- Cmd-G goes to next match; Shift-Cmd-G goes to previous.
- Cmd-Opt-F opens the find-replace flavour; replacing a match works.

This exercises `SearchReplaceEngine` after it relocated to `Core/Search/`. The behavior should be identical to before — relocation does not change semantics.

- [ ] **Step 3: Exercise the project-wide search surface**

Open the workspace sidebar (File → Open Folder…, or the empty-state button). Pick a directory with multiple files (e.g., `Sources/`). Open the project-search panel. Type a token that exists in multiple files (e.g., `swiftSettings`). Verify:
- Results group by file.
- Clicking a result opens that file and selects the matched range — this exercises the **migrated** `EditorController+SelectMatch.swift` via `selectMatch(_:)` in the sample. If the click does nothing (or scrolls but doesn't select), the `selectMatch` extension is not being resolved — check that `EditorController+SelectMatch.swift` is in the sample and that `selectMatch(_:)` is `public`.

- [ ] **Step 4: Quit cleanly**

Cmd-Q to quit. No console errors. Per `feedback_process_hygiene.md`: if the app does not quit cleanly, kill any stale processes (`pkill -f CodeEditorSample`) before retrying.

If any step fails, do not proceed to Task 8 — investigate, fix, re-run Task 6, then retry.

---

### Task 8: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

The `(pending commit SHA)` placeholders added in this task get back-filled in Task 9 Step 3 after the extraction commit lands.

- [ ] **Step 1: Update `CLAUDE.md` — remove `Search/` from the umbrella source tree**

Open `CLAUDE.md`. Locate the `## Source Tree` ASCII tree (currently around lines 45–63 after §6.2.8f's edits — verify by reading the file). Find these three lines:

```
├── LSP/                     # Language Server Protocol support
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Layout/                  # UI components + co-located ViewModels
├── Search/                  # Search result models and shared search support
└── SwiftUI/                 # SwiftUI wrappers and modifiers
```

Use `Edit` to replace `old_string`:
```
├── Layout/                  # UI components + co-located ViewModels
├── Search/                  # Search result models and shared search support
└── SwiftUI/                 # SwiftUI wrappers and modifiers
```

with `new_string`:
```
├── Layout/                  # UI components + co-located ViewModels
└── SwiftUI/                 # SwiftUI wrappers and modifiers
```

`SwiftUI/`'s prefix stays `└──` (already last).

- [ ] **Step 2: Update `CLAUDE.md` — note `Search/` joined the pre-extraction list**

Find the `Pre-extraction directories ...` paragraph (currently includes `Workspace/` per §6.2.8f). Add `Search/` to the list:

old:
```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

new:
```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

- [ ] **Step 3: Update `CLAUDE.md` — add `Core/Search/` to the F3 bucket list**

Find the `Core/` entry in the source-tree description (currently around line 49):

```markdown
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

Use `Edit` to add `Search/` alphabetically:

new:
```markdown
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, Search/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

- [ ] **Step 4: Update `CLAUDE.md` — refresh umbrella file count**

Locate the line that currently reads (per §6.2.8f, around line 70):

```
9 top-level directories in the umbrella target, 311 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8f), and 592 Swift source files under `Sources/`.
```

Re-count files after the moves:
```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
find Sources/CodeEditorPlugin -mindepth 1 -maxdepth 1 -type d | wc -l
```

Expected:
- Umbrella file count drops by **2** (ProjectSearchProvider → CodeEditorSearch; SelectMatch → sample). `SearchReplaceEngine` moves within so doesn't decrement. `311 → 309`.
- Total under `Sources/` stays at `592` (files moved, not added/removed).
- Top-level umbrella directories drop by 1 (`Search/` removed). `9 → 8`.

Use `Edit` to replace with:

```
8 top-level directories in the umbrella target, 309 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8f), and 592 Swift source files under `Sources/`.
```

If the actual `find` counts differ from `309` / `592` / `8`, use the actual numbers. The `480` baseline is historical and does not change. The §-suffix list stays sorted: `§6.2.8b / §6.2.8d / §6.2.8f`.

- [ ] **Step 5: Update `CLAUDE.md` — add `CodeEditorSearch` to "Other source roots"**

Locate the `Sources/CodeEditorWorkspace/` bullet in the "Other source roots" list. Insert `Sources/CodeEditorSearch/` alphabetically — between `Sources/CodeEditorSample/` (which appears below it in line order but after alphabetically? Let me check the actual ordering in the file) and `Sources/CodeEditorSyntaxHighlighting/`. Run:

```bash
grep -n "^- \`Sources/" CLAUDE.md
```

Place the new bullet alphabetically. Expected position: after `Sources/CodeEditorSample/` (which is listed under `CodeEditorUI/` for stylistic reasons in §6.2.8f's edits — verify) or after `Sources/CodeEditorPlatform/`. Actual alphabetical position: `Sources/CodeEditorSample/` < `Sources/CodeEditorSearch/` < `Sources/CodeEditorSymbols/` < `Sources/CodeEditorSyntaxHighlighting/`. The list may not be in strict alphabetical order — match the existing ordering convention (look at how `Symbols`, `Folding`, `Workspace` are placed).

Use `Edit` to add this bullet immediately before the `Sources/CodeEditorSymbols/` bullet (or wherever the existing alphabet-roughly-by-name ordering places it):

```markdown
- `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter (phase 4; new in §6.2.8d). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`).
```

- [ ] **Step 6: Update `NEXT.md` §6.0 status header**

Open `NEXT.md`. Locate the §6.0 prefix paragraph (`Phases 0–4 done; phase 3.5 (SH) carved out.`). Update to reflect the §6.2.8d landing — the exact wording should mention that §6.2.8d Search has been extracted as another carve-out. Read the current text and adapt; expected new text adds a sentence like:

> `CodeEditorSearch` (§6.2.8d) followed as a carve-out — 1 file moved to the new target; `SearchReplaceEngine.swift` stayed in umbrella (relocated to `Core/Search/`) and `EditorController+SelectMatch.swift` migrated to the sample (first cross-restructure public-API removal from the umbrella).

- [ ] **Step 7: Update `NEXT.md` §6.0 status table — append the Search row**

Locate the §6.0 status table. The current closing row is `CodeEditorWorkspace` (`c1739137`). Append immediately after it:

```markdown
| `CodeEditorSearch` | `(pending commit SHA)` | 1 file moved from umbrella `Search/` to new target (`ProjectSearchProvider.swift`). Pre-commit `(pending pre-relocation SHA)` relocated umbrella-coupled `SearchReplaceEngine.swift` to `Core/Search/` and migrated `EditorController+SelectMatch.swift` to `CodeEditorSample/EditorActions/` (removing `EditorController.selectMatch(_ result: ProjectSearchResult)` from the umbrella's public API). Productized as opt-in `.library` per §6.3. Umbrella does NOT depend on it. | (none) |
```

(The `(pending pre-relocation SHA)` placeholder uses the SHA captured in Task 2 Step 12.)

- [ ] **Step 8: Update `NEXT.md` §6.0 — add the §6.2.8d deviations block**

Immediately after the §6.2.8f Workspace deviations block (which closes with "iOS coverage asymmetry preserved"), insert:

```markdown
**Deviations during §6.2.8d `CodeEditorSearch` (commit `(pending)`):**

- **Carve-out shape with three moves.** 1 file into new target (`ProjectSearchProvider.swift` → `Sources/CodeEditorSearch/`); 1 file relocated inside umbrella (`SearchReplaceEngine.swift` → `Core/Search/`); 1 file migrated out of umbrella to sample (`EditorController+SelectMatch.swift` → `Sources/CodeEditorSample/EditorActions/`). Adds a third move type — the umbrella-out migration — to the §6.2.8a/§6.2.8b carve-out vocabulary.
- **NEXT.md §4.1's `Search = Features/SearchReplaceEngine.swift + Search/` claim was wrong.** `SearchReplaceEngine.swift` is heavily `CodeEditorView`-coupled (same blocker as SmartEditing): every public entry takes/uses `CodeEditorView`. It stays in umbrella and travels with §6.2.12. New target ships only the project-wide piece.
- **First cross-restructure public-API removal.** `EditorController.selectMatch(_ result: ProjectSearchResult)` is gone from the umbrella's public API. External consumers reimplement via the still-public `EditorController.nsLocation(forLSPLine:character:)` + `EditorController.selectRange(_:scroll:)` primitives. Sets precedent for §6.2.9 LSP / Debugger extractions where the umbrella's public surface may also thin.
- **Productized opt-in** as `.library(name: "CodeEditorSearch", ...)`. Matches Workspace/Diagnostics precedent. NEXT.md §6.3's "Optional / opt-in" list expands.
- **Umbrella does NOT depend on `CodeEditorSearch`.** Preserved by migrating `EditorController+SelectMatch.swift` to the sample.
- **Zero access-modifier promotions.** Tied with §6.2.8f Workspace as the smallest promotion surface in the restructure series.
- **Pure-Foundation target with no `#if canImport`.** Cleaner than §6.2.8f Workspace (which has `MacOSWorkspaceFileManager` wrapped end-to-end in AppKit-conditional code).
- **Spec over-counted sample imports.** Spec listed ~4 sample-source imports. Reality: 3 — `App/AppState.swift` only references `PortableProjectSearchAdapter` in a doc comment, so the import is unnecessary. Mirrors §6.2.8f Workspace's analogous finding for `AppState.swift`'s `WorkspaceFileWatching` doc-comment reference.
- **Phase 4 semantic label vs build-graph reality.** Spec labels Search as phase 4 (feature engine). With no internal deps, the build graph treats it as parallel to phase 0. Label kept because it's a feature, not foundational infra.
- **Test placement** follows the §6.2.7/§6.2.8a/§6.2.8b/§6.2.8f precedent — no new `CodeEditorSearchTests` target. `ProjectSearchProviderTests.swift` stays in `CodeEditorPluginTests/` with `import CodeEditorSearch` replacing `@testable import CodeEditorPlugin`. Per-target test split deferred to §6.2.15.
- **`@testable` shed on the SelectMatch test.** `EditorControllerSelectMatchTests.swift` dropped `@testable import CodeEditorPlugin` (no longer needed — every symbol it touches is `public`) but kept `@testable import CodeEditorSample` defensively.
```

- [ ] **Step 9: Update `NEXT.md` §6.2.8 — add the Search sub-bullet**

In `NEXT.md` step 8 of §6.2 ("Extract feature engines individually"), the §6.2.8f Workspace sub-bullet currently closes the list (with the `SmartEditing` deferred bullet just below it). Insert the new Search bullet immediately after the Workspace one and before the deferred SmartEditing bullet:

```markdown
   - **[done — carve-out, see §6.0]** **`CodeEditorSearch`** (§6.2.8d) — 1 file moved from `Sources/CodeEditorPlugin/Search/` to `Sources/CodeEditorSearch/`: `ProjectSearchProvider.swift`. `SearchReplaceEngine.swift` relocated to umbrella `Core/Search/`; `EditorController+SelectMatch.swift` migrated out of umbrella to `Sources/CodeEditorSample/EditorActions/` (first cross-restructure public-API removal). Productized as opt-in `.library` per §6.3; umbrella does NOT depend on it. (`(pending)` + pre-relocation `(pending pre-relocation SHA)`)
```

- [ ] **Step 10: Update `NEXT.md` §6.3 — add `CodeEditorSearch` to opt-in list**

Locate §6.3 ("Products to expose"). Update the "Optional / opt-in" line to include `CodeEditorSearch`:

old:
```markdown
- Optional / opt-in: `CodeEditorLSP`, `CodeEditorDebugger`, `CodeEditorDiagnostics`, `CodeEditorWorkspace`
```

new:
```markdown
- Optional / opt-in: `CodeEditorLSP`, `CodeEditorDebugger`, `CodeEditorDiagnostics`, `CodeEditorSearch`, `CodeEditorWorkspace`
```

- [ ] **Step 11: Update `NEXT.md` §10 — strike Search from the remaining list**

In `NEXT.md` §10, locate the "6.2.8 feature engines" bullet. Current text (after §6.2.8f):

```markdown
- **6.2.8 feature engines** — `Search`, `Annotations`, `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0); `Workspace` is done (§6.2.8f, clean extraction — see §6.0); `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

Replace with:

```markdown
- **6.2.8 feature engines** — `Annotations`, `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0); `Search` is done (§6.2.8d, carve-out — see §6.0); `Workspace` is done (§6.2.8f, clean extraction — see §6.0); `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

- [ ] **Step 12: Update `NEXT.md` §10 preamble**

Locate the preamble at the top of §10:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8f, and 6.2.10 are done (see §6.0). Remaining work:
```

Replace with:

```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8f, and 6.2.10 are done (see §6.0). Remaining work:
```

- [ ] **Step 13: Update `NEXT.md` §4.1 phase table**

Locate the `CodeEditorSearch` row in §4.1's phase table. Currently it likely reads:

```markdown
| 4 | `CodeEditorSearch` | `Features/SearchReplaceEngine.swift`, `Search/` | TextModel |
```

Replace with:

```markdown
| 4 | `CodeEditorSearch` | `Search/` (only; `Features/SearchReplaceEngine.swift` stays in umbrella per §6.2.8d — `CodeEditorView`-coupled, awaiting §6.2.12) | (none — Foundation only) |
```

If the row's exact format differs, preserve the table syntax and update just the source-files cell and the dependencies cell.

- [ ] **Step 14: Verify build + lint after doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```

Expected: both clean. (Markdown edits don't affect compilation, but verify in case a `.swift` file was touched accidentally.)

---

### Task 9: Main extraction commit + SHA back-fill

**Files:** none modified in this task; commit + record SHA back into `NEXT.md`.

- [ ] **Step 1: Stage all changes from Tasks 3–8**

Run:
```bash
git add Sources/CodeEditorSearch \
        Sources/CodeEditorPlugin \
        Sources/CodeEditorSample \
        Tests/CodeEditorPluginTests \
        Tests/CodeEditorSampleTests \
        Package.swift \
        CLAUDE.md \
        NEXT.md
git status --short
```

Expected output:
- 1 rename: `Sources/CodeEditorPlugin/Search/ProjectSearchProvider.swift → Sources/CodeEditorSearch/ProjectSearchProvider.swift`
- Modifications to `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`, `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`, `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift`
- Modifications to `Tests/CodeEditorPluginTests/ProjectSearchProviderTests.swift`
- Modifications to `Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift`, `ProjectSearchModelTests.swift`, `WorkspaceSidebarSnapshotTests.swift`, `EditorControllerSelectMatchTests.swift`
- Modifications to `Package.swift`, `CLAUDE.md`, `NEXT.md`

If any unexpected files appear (e.g., `.DS_Store`, snapshot regeneration, untracked source files), investigate before committing.

- [ ] **Step 2: Create the main extraction commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorSearch target (§6.2.8d)

Move ProjectSearchProvider.swift (255 lines, Foundation-only) from
Sources/CodeEditorPlugin/Search/ into a new CodeEditorSearch SPM
target. Carve-out matching §6.2.8a (Folding) and §6.2.8b (Symbols):
SearchReplaceEngine.swift stayed in umbrella because every public
entry uses CodeEditorView (relocated to Core/Search/ in pre-commit).

Adds a third move type to the carve-out vocabulary:
EditorController+SelectMatch.swift migrated out of the umbrella into
Sources/CodeEditorSample/EditorActions/ in the pre-commit. The
umbrella stops shipping
`EditorController.selectMatch(_ result: ProjectSearchResult)` as
public API — first cross-restructure public-API removal. External
consumers reimplement via the still-public
`EditorController.nsLocation(forLSPLine:character:)` and
`selectRange(_:scroll:)` primitives.

Productized as a .library per NEXT.md §6.3's opt-in listing,
matching the Workspace/Diagnostics precedent. The umbrella
CodeEditorPlugin does NOT depend on the new target; consumers
opt in via explicit `import CodeEditorSearch`. In-tree:
CodeEditorSample, CodeEditorSampleTests, and CodeEditorPluginTests
gain the dep; 8 files gain the new import.

Zero access-modifier promotions — every symbol in
ProjectSearchProvider.swift was already public.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-search-extraction-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-search-extraction.md
Pre-relocation: (pending pre-relocation SHA — captured in Task 2 Step 12)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Before running, replace `(pending pre-relocation SHA — captured in Task 2 Step 12)` with the actual SHA from Task 2 Step 12.

- [ ] **Step 3: Capture the extraction commit SHA and back-fill `NEXT.md` placeholders**

Run:
```bash
git log -1 --format=%h
```

Save the short SHA (e.g., `abc1234`).

Open `NEXT.md` and replace each placeholder added in Task 8:
- Task 8 Step 7 (status-table row): `(pending commit SHA)` → `<extraction SHA>`; `(pending pre-relocation SHA)` → `<pre-commit SHA from Task 2 Step 12>`.
- Task 8 Step 8 (deviations block header): `(pending)` → `<extraction SHA>`.
- Task 8 Step 9 (sub-bullet): `(pending)` and `(pending pre-relocation SHA)` → both filled with their respective SHAs.

- [ ] **Step 4: Verify build + lint after the SHA back-fill**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```
Expected: both clean. The SHA back-fill is markdown-only.

- [ ] **Step 5: Commit the SHA back-fill as a separate commit (matches §6.2.8b's `51751af2` precedent)**

Run:
```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Update NEXT.md SHA back-reference for §6.2.8d

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Note: the §6.2.8f Workspace plan offered both `--amend` and a separate-commit option. The separate-commit pattern (used by §6.2.8a `bf6aeb64`, §6.2.8b `51751af2`, §6.2.8f `1b706023`) is the established convention; use it. Do NOT use `git commit --amend`.

- [ ] **Step 6: Verify final git state**

Run:
```bash
git log -5 --oneline
git status --short
```

Expected:
- The SHA back-fill commit on top.
- The main extraction commit below it.
- The pre-relocation commit (from Task 2 Step 11) below that.
- The spec commit (`59e6150b`) at the bottom of this run.
- Working tree clean.

- [ ] **Step 7: Stop. Do not push.**

The user will review the local commits and push when ready.

---

## Plan self-review

**1. Spec coverage:**
- §1 Architecture (new target shape, opt-in product, umbrella relocation, sample migration): Tasks 2 + 3 + 4.
- §2 Files in detail (1 file moves, 1 relocates, 1 migrates out, zero promotions, no scaffold placeholder needed): Tasks 2 + 4. ✓
- §3 Consumer ripple (8 imports across 3 sample sources + 4 sample-tests + 1 umbrella-tests; AppState doc-comment conditional): Tasks 1 (audit) + 5 (imports). ✓
- §4 Tests (no new test target, existing tests get import updates): Tasks 5 + 6. ✓
- §5 NEXT.md / CLAUDE.md updates (status table, deviations block, §6.2.8 bullet, §6.3 opt-in, §10 remaining list, §4.1 phase table, CLAUDE.md tree + counts + Other source roots): Task 8 (13 steps). ✓
- §6 Risks (breaking-API change recipe, AppState conditional import, `@testable` swap, hidden umbrella consumer): Tasks 1 (audit) + 2 (`@testable` swap) + 5 (conditional). ✓
- §5 commit pattern (4 commits — design + plan + extraction + SHA back-fill): committed already (design), this plan-commit comes from writing-plans handoff, Task 2 = pre-relocation commit, Task 9 = extraction commit + Task 9 Step 5 = SHA back-fill commit. ✓ (Note: spec listed 4 commits including design + plan; with the pre-relocation, this plan produces 3 code commits + 1 SHA-update commit = 4 code-side commits total. The spec's count was conservative; the actual count is 4 code-side commits plus the design and plan commits.)

**2. Placeholder scan:**
- `(pending commit SHA)`, `(pending)`, `(pending pre-relocation SHA — captured in Task 2 Step 12)` — these are intentional placeholders the executor back-fills in Task 9 Step 3 / Step 2 commit-msg edit. Not bugs.
- No TBDs, TODOs, "fill in later", or "similar to Task N" references.
- Every step that changes code shows the actual code via `old_string` → `new_string` diffs or full code blocks.

**3. Type consistency:**
- File path `Sources/CodeEditorSearch/ProjectSearchProvider.swift` is consistent across Tasks 4, 6, 9.
- File path `Sources/CodeEditorPlugin/Core/Search/SearchReplaceEngine.swift` is consistent across Tasks 2, 6, 8.
- File path `Sources/CodeEditorSample/EditorActions/EditorController+SelectMatch.swift` is consistent across Tasks 2, 5, 6.
- Import name `import CodeEditorSearch` is used consistently in Tasks 3, 5, 6, 8.
- `ProjectSearchResult`, `ProjectSearchOptions`, `ProjectSearchProvider`, `PortableProjectSearchAdapter` referenced consistently.
- File count delta in CLAUDE.md (Task 8 Step 4): `311 → 309` matches the §3 "net move: 2 files leave umbrella" claim from the spec.

No issues found. Plan ready for execution.
