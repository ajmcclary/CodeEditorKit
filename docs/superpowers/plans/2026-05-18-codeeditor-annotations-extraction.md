# CodeEditorAnnotations Extraction (§6.2.8e) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract 7 of 8 files from `Sources/CodeEditorPlugin/Annotations/` into a new `CodeEditorAnnotations` SPM target. Carve-out matching §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d shape: the `CodeEditorView`-coupled `AnnotationsDataSource.swift` stays in the umbrella and relocates to `Core/Annotations/`. Not productized — the umbrella consumes Annotation types via 3 files (`Core/CodeEditorView+AnnotationsExtensions.swift`, `Core/CodeEditorView+LayoutExtensions.swift`, `Layout/ThemeableUIComponent+Conformances.swift`), so it routes through the umbrella like Folding/Symbols/SH/Languages, not opt-in like Workspace/Search/Diagnostics.

**Architecture:** Two code commits + one SHA back-fill commit. Pre-relocation commit (Task 2) `git mv`s `AnnotationsDataSource.swift` into `Core/Annotations/`; nothing else changes. Main extraction commit (Tasks 3–9) adds the target to `Package.swift`, moves the 7 pure files, adds `import CodeEditorAnnotations` to 14 consumer files (4 umbrella incl. the relocated DataSource, 4 sample, 6 tests), updates CLAUDE.md and NEXT.md. SHA back-fill commit (Task 9 Step 5) fills the `(pending)` placeholders.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target dependencies: `CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTheming` (verified by import grep — no `CodeEditorTextModel` despite NEXT.md §4.1's claim). No new third-party deps. AppKit/UIKit conditional imports preserved in the moving view files.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-annotations-extraction-design.md` (commit `aa847447`).

**Pre-flight verified state (as of `aa847447`):**
- Umbrella file count: **309**; total under `Sources/`: **592**; umbrella top-level directories: **8** (`Annotations/`, `Completion/`, `Core/`, `Features/`, `LSP/`, `Languages/`, `Layout/`, `SwiftUI/`).
- Package.swift umbrella `exclude:` is currently `["Info.plist", "Languages"]` — the §6.2.7 / §6.2.10 / §6.2.8f defensive entries for removed dirs were cleaned up. This plan does NOT add `"Annotations"` to exclude (the spec's "defensive entry" suggestion was based on the older convention; current convention is to `rmdir` instead).
- All 7 moving files have explicit `public init`s — promotion surface is approximately zero.

---

### Task 1: Pre-flight audit

**Files:** read-only. No edits.

- [ ] **Step 1: Confirm carry-set (8 files in `Annotations/`) is unchanged since spec**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Annotations/
```

Expected exactly:
```
Annotation.swift
AnnotationKind.swift
AnnotationView.swift
AnnotationsContentView.swift
AnnotationsDataSource.swift
CodeEditorViewAnnotation.swift
LineAnnotation.swift
MessageLineAnnotation.swift
```

If any extra file appears (e.g., a new `AnnotationProvider.swift`), stop and re-spec — the carve-out shape changes. If a file is missing, verify it wasn't deleted; if it was, decide whether the moving-files list shrinks.

- [ ] **Step 2: Confirm `AnnotationsDataSource.swift` is still the only `CodeEditorView`-coupled file**

Run:
```bash
grep -lnE "CodeEditorView\b" Sources/CodeEditorPlugin/Annotations/*.swift
```

Expected exactly 2 files:
```
Sources/CodeEditorPlugin/Annotations/Annotation.swift
Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift
```

`Annotation.swift`'s reference is in a `@SeeAlso` doc comment only (line 46). Verify:
```bash
grep -nE "CodeEditorView\b" Sources/CodeEditorPlugin/Annotations/Annotation.swift
```
Expected: 1 hit on line 46 starting with `/// - SeeAlso:`. The doc-comment reference does not couple the file; it can move.

`AnnotationsDataSource.swift`'s coupling is in a method signature (line 115: `_ textView: CodeEditorView`). Verify:
```bash
grep -nE "CodeEditorView\b" Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift
```
Expected: 4 hits — 3 doc comments (lines 44, 68, 74) and 1 signature on line 115. If any of the 7 other files now reference `CodeEditorView` outside doc comments, stop and re-spec.

- [ ] **Step 3: Exhaustive consumer survey**

Run:
```bash
grep -rln "MessageLineAnnotation\|LineAnnotation\b\|AnnotationKind\|CodeEditorViewAnnotation\|AnnotationView\|AnnotationsContentView\|AnnotationViewProtocol\|AnnotationsContentViewProtocol" \
    Sources/ Tests/ --include='*.swift' | grep -v "Sources/CodeEditorPlugin/Annotations" | sort -u
```

Expected exactly 13 paths:
```
Sources/CodeEditorPlugin/Core/CodeEditorView+AnnotationsExtensions.swift
Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift
Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift
Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift
Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift
Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift
Sources/CodeEditorSample/KnobPanels/AnnotationsKnobsSection.swift
Tests/CodeEditorPluginTests/AnnotationTests.swift
Tests/CodeEditorPluginTests/Annotations/AnnotationThemeTests.swift
Tests/CodeEditorPluginTests/CodeEditorViewTests.swift
Tests/CodeEditorPluginTests/IOSAnnotationTests.swift
Tests/CodeEditorPluginTests/Layout/ThemeableUIComponentTests.swift
Tests/CodeEditorPluginTests/MemoryLeakTests.swift
```

Plus a 14th file picks up the import after the relocation (Task 2): the relocated `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift` itself, which references `Annotation` and `CodeEditorViewAnnotation` types from the new target. The 13 paths above are the consumers detected by grep against the current pre-move tree; `AnnotationsDataSource.swift` is excluded because it's still in the `Annotations/` source dir at this point.

If extra paths appear (e.g., a new `Sources/CodeEditorPlugin/LSP/...` file references AnnotationKind), stop and re-spec — the consumer-ripple count changes. If fewer paths appear, the spec over-counted; proceed but record the deviation in Task 8 Step 8.

- [ ] **Step 4: Confirm `Core/Annotations/` does not yet exist**

Run:
```bash
ls -la Sources/CodeEditorPlugin/Core/Annotations 2>&1 | head -3
```

Expected: `No such file or directory`. If the directory exists, something has already been staged here that the plan doesn't anticipate.

- [ ] **Step 5: Confirm public-init baseline (zero expected promotions)**

Run:
```bash
grep -nE "(public init|public struct|public class|public protocol|public enum)" \
    Sources/CodeEditorPlugin/Annotations/*.swift
```

Expected: every public top-level type has at least one explicit `public init(...)`:
- `Annotation` (struct) — 2 `public init` overloads.
- `AnnotationKind` (enum) — 1 `public init(from messageKind:)`.
- `AnnotationView` (class) — `public init(annotation:frame:)` + `public required init?(coder:)`.
- `AnnotationsContentView` (class) — `public init(frame frameRect:)` + `public required init?(coder:)`.
- `CodeEditorViewAnnotation` (struct) — 2 `public init` overloads.
- `MessageLineAnnotation` (struct) — `public init(id:message:kind:location:)`.

`LineAnnotation` is a protocol with no init requirement; no init needed.

If any public struct/class is missing an explicit `public init`, the synthesised init may be `internal` even when the struct is `public` — the §6.2.8b Symbols lesson. Add a `public init(...)` task here before Task 5 in that case.

- [ ] **Step 6: Capture baseline test pass count**

Run:
```bash
swift test --filter AnnotationTests 2>&1 | tail -5
swift test --filter AnnotationThemeTests 2>&1 | tail -5
swift test --filter IOSAnnotationTests 2>&1 | tail -5
swift test --filter MemoryLeakTests 2>&1 | tail -5
swift test --filter ThemeableUIComponentTests 2>&1 | tail -5
```

Save the pass counts in a scratch buffer. Tasks 6 and 9 verify identical counts.

Note: `IOSAnnotationTests` only runs in `#if canImport(UIKit)` blocks. On macOS-only CI it reports 0 — that's expected and not a regression.

- [ ] **Step 7: Verify clean working tree**

Run:
```bash
git status --short
```

Expected: no output. If there are uncommitted changes, stop and ask the user.

- [ ] **Step 8: Capture starting SHA for the back-reference**

Run:
```bash
git log -1 --format=%h
```

Expected: `aa847447` (the spec commit). Save it — Task 8 Step 6 references it.

---

### Task 2: Pre-relocation commit — move `AnnotationsDataSource.swift` to `Core/Annotations/`

This is the §6.2.8a / §6.2.8b / §6.2.8d pre-commit equivalent. Only one move happens; the rest of the carry-set stays put.

**Files:**
- Move (`git mv`): `Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift` → `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift`

- [ ] **Step 1: Create the `Core/Annotations/` directory**

Run:
```bash
mkdir -p Sources/CodeEditorPlugin/Core/Annotations
```

- [ ] **Step 2: `git mv` `AnnotationsDataSource.swift` into `Core/Annotations/`**

Run:
```bash
git mv Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift \
       Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift
```

The file's contents do not change. Its imports (`CodeEditorPlatform`, `Foundation`, conditional `AppKit`/`UIKit`) and protocol declaration are unaffected by the path change — `CodeEditorView`, `Annotation`, `CodeEditorViewAnnotation`, and `PlatformView` are all in-target visible from `Core/Annotations/` exactly as they were from `Annotations/`.

- [ ] **Step 3: Verify build is still green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. The file moved within the same target; SwiftPM doesn't care about subdirectory layout. If the build fails with `cannot find 'AnnotationsDataSource' in scope`, something is wrong — investigate before proceeding.

- [ ] **Step 4: Verify targeted tests still pass**

Run:
```bash
swift test --filter AnnotationTests 2>&1 | tail -5
```

Expected: pass count matches the Task 1 Step 6 baseline.

- [ ] **Step 5: Stage and commit the pre-relocation**

Run:
```bash
git add Sources/CodeEditorPlugin
git status --short
```

Expected output (one rename only):
- `R  Sources/CodeEditorPlugin/Annotations/AnnotationsDataSource.swift -> Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift`

If any other files appear, investigate before committing.

- [ ] **Step 6: Create the pre-relocation commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Relocate umbrella-coupled AnnotationsDataSource to Core/Annotations/

Pre-commit for the §6.2.8e CodeEditorAnnotations extraction,
mirroring §6.2.8a's 9704e80b, §6.2.8b's 5d670076, and §6.2.8d's
0cdf53f9.

AnnotationsDataSource.swift declares the @MainActor public protocol
whose required `textView(_ textView: CodeEditorView, viewForLineAnnotation:...)`
method takes CodeEditorView as a parameter. The same umbrella-coupling
shape that kept files in umbrella during SH / Folding / Symbols /
Search extractions. The pure files (Annotation, AnnotationKind,
AnnotationView, AnnotationsContentView, CodeEditorViewAnnotation,
LineAnnotation, MessageLineAnnotation) move to the new
CodeEditorAnnotations target in the follow-up extraction commit.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-annotations-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Capture the pre-commit SHA**

Run:
```bash
git log -1 --format=%h
```

Save this SHA — Task 8 Step 7 will record it in NEXT.md's status table.

---

### Task 3: Scaffold the `CodeEditorAnnotations` target in `Package.swift`

**Files:**
- Modify: `Package.swift`

No source file changes in this task; the source directory is created in Task 4 alongside the file move. Tasks 3–8 bundle into the Task 9 extraction commit — do NOT commit between Tasks 3 and 9.

The new target has **no `.library` product entry** (the umbrella consumes Annotation types, so it routes through the umbrella — matches Folding / Symbols / SH / Languages precedent).

- [ ] **Step 1: Add the `.target` stanza to `Package.swift`**

Locate the existing `.target(name: "CodeEditorSyntaxHighlighting", ...)` and `.target(name: "CodeEditorFolding", ...)` stanzas. The current alphabetical order is `CodeEditorSyntaxHighlighting` → `CodeEditorFolding` → `CodeEditorSearch` → `CodeEditorSymbols` → `CodeEditorWorkspace` → umbrella `CodeEditorPlugin`. The new target sorts as **first** in this group: `CodeEditorAnnotations` < `CodeEditorFolding`.

Currently the relevant chunk reads (around lines 154–183):

```swift
        .target(
            name: "CodeEditorSyntaxHighlighting",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
```

Use `Edit` to replace `old_string`:
```swift
        .target(
            name: "CodeEditorSyntaxHighlighting",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
```

with `new_string`:
```swift
        .target(
            name: "CodeEditorSyntaxHighlighting",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorAnnotations",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTheming"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
```

No `path:` override (default `Sources/CodeEditorAnnotations/` is correct). No `exclude:` or `resources:`. No `.library` product entry (umbrella-consumed).

- [ ] **Step 2: Add `"CodeEditorAnnotations"` to the umbrella `CodeEditorPlugin` target's `dependencies:`**

Locate the umbrella target's `dependencies:` array (around lines 198–212). It currently reads:

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
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            exclude: [
                "Info.plist",
                "Languages"
            ],
            swiftSettings: swiftSettings
        ),
```

Use `Edit` to insert `"CodeEditorAnnotations"` at the top of the list (alphabetically first):

old_string:
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
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
```

new_string:
```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorDiagnostics",
                "CodeEditorFolding",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
```

Important: the umbrella's `exclude:` stays `["Info.plist", "Languages"]`. Do **not** add `"Annotations"` to exclude. The Annotations source directory will be removed (Task 4 Step 3), so SwiftPM never tries to include it. Following the §6.2.8d / §6.2.8f convention of rmdir-after-move rather than the older defensive-exclude convention.

- [ ] **Step 3: Add `"CodeEditorAnnotations"` to `CodeEditorSample` target's `dependencies:`**

Locate the `CodeEditorSample` executable target's `dependencies:` array (around lines 230–244):

```swift
        .executableTarget(
            name: "CodeEditorSample",
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

Use `Edit` to insert `"CodeEditorAnnotations"` at the top alphabetically:

old_string:
```swift
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
```

new_string:
```swift
        .executableTarget(
            name: "CodeEditorSample",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
```

- [ ] **Step 4: Add `"CodeEditorAnnotations"` to `CodeEditorPluginTests` target's `dependencies:`**

Locate the `CodeEditorPluginTests` test target's `dependencies:` array (around lines 254–270):

```swift
        .testTarget(
            name: "CodeEditorPluginTests",
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

Use `Edit` to insert `"CodeEditorAnnotations"` at the top alphabetically:

old_string:
```swift
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
```

new_string:
```swift
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
```

- [ ] **Step 5: Do NOT add `"CodeEditorAnnotations"` to `CodeEditorUI`, `CodeEditorUITests`, `CodeEditorDesignTokensTests`, or `CodeEditorSampleTests`**

Verify by reading each stanza — none should gain `CodeEditorAnnotations`. Task 1 Step 3's consumer survey confirmed none of those targets reference Annotation types directly. If grep at execution time finds even one Annotation reference in those targets, add the dep here and record the deviation in Task 8 Step 8.

- [ ] **Step 6: Do NOT add a `.library` product entry**

This is the design decision: Annotations is umbrella-consumed, so it routes through the umbrella. Verify the `products:` array (lines 56–84) is unchanged — no `CodeEditorAnnotations` library entry should appear.

If the array now lists a `CodeEditorAnnotations` `.library` entry, remove it — the umbrella already exposes Annotation types via re-export through its `dependencies:`.

- [ ] **Step 7: Build will fail — that's expected**

Run:
```bash
swift build 2>&1 | tail -20
```

Expected: build FAILS with one of these errors:
- `error: target 'CodeEditorAnnotations' has no source files`
- `error: the path 'Sources/CodeEditorAnnotations' does not exist`

That's because the target exists in `Package.swift` but `Sources/CodeEditorAnnotations/` doesn't yet. Task 4 fixes that. Do **not** stop here — proceed directly to Task 4.

---

### Task 4: Move the 7 pure files into `Sources/CodeEditorAnnotations/`

After this task, `Sources/CodeEditorPlugin/Annotations/` is empty and removed; `Sources/CodeEditorAnnotations/` contains 7 files. Build is RED in the umbrella consumers because they still resolve `Annotation`/`AnnotationView`/etc. via in-target visibility — Task 5 fixes that.

**Files:**
- Create: `Sources/CodeEditorAnnotations/` directory
- Move (`git mv`): 7 files from `Sources/CodeEditorPlugin/Annotations/` → `Sources/CodeEditorAnnotations/`
- Delete (after move): `Sources/CodeEditorPlugin/Annotations/` directory

- [ ] **Step 1: Create the new source root**

Run:
```bash
mkdir -p Sources/CodeEditorAnnotations
```

No placeholder `.swift` file or `.gitkeep` needed — the file moves in Step 2 happen in the same logical task, so SwiftPM never sees an empty source directory mid-flight (the build was already red after Task 3 Step 7).

- [ ] **Step 2: `git mv` the 7 pure files**

Run each `git mv` in turn (one command per file keeps git's rename detection deterministic):

```bash
git mv Sources/CodeEditorPlugin/Annotations/Annotation.swift \
       Sources/CodeEditorAnnotations/Annotation.swift
git mv Sources/CodeEditorPlugin/Annotations/AnnotationKind.swift \
       Sources/CodeEditorAnnotations/AnnotationKind.swift
git mv Sources/CodeEditorPlugin/Annotations/AnnotationView.swift \
       Sources/CodeEditorAnnotations/AnnotationView.swift
git mv Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift \
       Sources/CodeEditorAnnotations/AnnotationsContentView.swift
git mv Sources/CodeEditorPlugin/Annotations/CodeEditorViewAnnotation.swift \
       Sources/CodeEditorAnnotations/CodeEditorViewAnnotation.swift
git mv Sources/CodeEditorPlugin/Annotations/LineAnnotation.swift \
       Sources/CodeEditorAnnotations/LineAnnotation.swift
git mv Sources/CodeEditorPlugin/Annotations/MessageLineAnnotation.swift \
       Sources/CodeEditorAnnotations/MessageLineAnnotation.swift
```

None of the moved files' contents change. Their existing imports (`CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTheming`, `Foundation`, conditional `AppKit`/`UIKit`) are unaffected by the path change — those targets are sibling SPM modules, not umbrella-internal.

- [ ] **Step 3: Remove the now-empty umbrella source directory**

Run:
```bash
rmdir Sources/CodeEditorPlugin/Annotations
```

If `rmdir` fails with "Directory not empty", inspect:
```bash
ls -la Sources/CodeEditorPlugin/Annotations/
```

The likely culprit is a `.DS_Store`. Remove it (`rm Sources/CodeEditorPlugin/Annotations/.DS_Store`) and retry `rmdir`. `.DS_Store` files are not tracked by git and don't affect SwiftPM.

- [ ] **Step 4: Verify the new target compiles in isolation**

Run:
```bash
swift build --target CodeEditorAnnotations 2>&1 | tail -10
```

Expected: `Build complete!`. The new target's dependencies (`CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTheming`) are all phase 0–2 targets, already green.

If this fails with `cannot find 'PlatformColor' in scope` or similar, the dep set is incomplete — re-check Task 3 Step 1 against the file imports.

- [ ] **Step 5: Build the full package to expose the consumer red wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```

Expected: build FAILS in umbrella, sample, and umbrella-test sources. Likely errors:

- `cannot find 'Annotation' in scope` in `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift`
- `cannot find 'CodeEditorViewAnnotation' in scope` in `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift`
- `cannot find 'AnnotationView' in scope` in `Sources/CodeEditorPlugin/Core/CodeEditorView+AnnotationsExtensions.swift`
- `cannot find 'AnnotationsContentView' in scope` in `Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift`
- `cannot find 'AnnotationsContentView' in scope` in `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift`
- `cannot find 'AnnotationKind' in scope` in sample LSP / sample command-palette / sample knob panel sources
- `cannot find 'AnnotationKind' in scope` / `cannot find 'Annotation' in scope` in test sources

These are expected — Task 5 fixes them. Capture the error file list and cross-check against the Task 1 Step 3 inventory: the failing files should be exactly the 13 consumer paths plus the relocated `AnnotationsDataSource.swift`. If a file fails that's not in the inventory, return to Task 1 Step 3 to re-grep — a hidden consumer existed.

---

### Task 5: Add `import CodeEditorAnnotations` to consumer files

Each consumer file gains `import CodeEditorAnnotations` in alphabetical order with its existing imports. SwiftLint's `sorted_imports` will reorder on autofix; pre-sorting in this task just avoids a follow-up delta. `CodeEditorAnnotations` sorts as the first `CodeEditor*` module alphabetically.

**Files:** 14 modifications (4 umbrella, 4 sample, 6 tests).

- [ ] **Step 1: `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift` (relocated in Task 2)**

Current imports (lines 1–7):

```swift
import CodeEditorPlatform
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorPlatform
import Foundation
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorPlatform
import Foundation
```

(`CodeEditorAnnotations` sorts alphabetically before `CodeEditorPlatform`.)

- [ ] **Step 2: `Sources/CodeEditorPlugin/Core/CodeEditorView+AnnotationsExtensions.swift`**

Current imports (lines 1–4):

```swift
import CodeEditorCommon
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorCommon
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorCommon
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
```

- [ ] **Step 3: `Sources/CodeEditorPlugin/Core/CodeEditorView+LayoutExtensions.swift`**

Current imports (lines 1–2):

```swift
import CodeEditorPlatform
import Foundation
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorPlatform
import Foundation
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorPlatform
import Foundation
```

- [ ] **Step 4: `Sources/CodeEditorPlugin/Layout/ThemeableUIComponent+Conformances.swift`**

Current imports (line 6):

```swift
import Foundation
```

(The file has a multi-line header comment, then the import on line 6.)

Use `Edit` to replace `old_string`:
```swift
import Foundation
```

with `new_string`:
```swift
import CodeEditorAnnotations
import Foundation
```

The file references `AnnotationsContentView` (line 14: `extension AnnotationsContentView: ThemeableUIComponent {}`). The new import resolves it.

- [ ] **Step 5: `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`**

Current imports (top of file):

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Combine
```

(The file uses `#if canImport(AppKit)` to wrap the whole body. Other imports follow further down — for this edit, only the leading block is relevant.)

Use `Edit` to replace `old_string`:
```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Combine
```

with `new_string`:
```swift
#if canImport(AppKit)
import AppKit
import CodeEditorAnnotations
import CodeEditorPlugin
import Combine
```

(`CodeEditorAnnotations` < `CodeEditorPlugin` alphabetically.)

- [ ] **Step 6: `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`**

Current imports (lines 1–5):

```swift
import CodeEditorLanguages
import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorLanguages
import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorLanguages
import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI
```

- [ ] **Step 7: `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift`**

Current imports (lines 1–9):

```swift
import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorTextModel
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorTextModel
import Foundation
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorTextModel
import Foundation
```

- [ ] **Step 8: `Sources/CodeEditorSample/KnobPanels/AnnotationsKnobsSection.swift`**

Current imports (lines 1–2):

```swift
import CodeEditorPlugin
import SwiftUI
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorPlugin
import SwiftUI
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorPlugin
import SwiftUI
```

- [ ] **Step 9: `Tests/CodeEditorPluginTests/AnnotationTests.swift`**

Current imports (lines 1–8):

```swift
import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest
```

The `@testable import CodeEditorPlugin` is load-bearing for this file (the suite reaches into umbrella-internal helpers like `textView.annotationsDataSource` setup via `weak` ivar access patterns and `MockAnnotationDataSource` is `NSObject`-based). Keep `@testable`; just add the new import.

Use `Edit` to replace `old_string`:
```swift
import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest
```

Note on `@testable` audit: even though `Annotation`, `AnnotationView`, `AnnotationKind`, `CodeEditorViewAnnotation` are all `public`, the test sets `textView.annotationsDataSource = dataSource` on a `CodeEditorView` instance — that property setter is `public` (line 466 in `CodeEditorView.swift`), so `@testable` is NOT strictly required for the Annotation surface alone. However, the test may use other umbrella internals; leave `@testable` defensively per §6.2.8d's plan-execution lesson ("do not blanket-drop `@testable` qualifiers without verifying every called symbol's access level").

- [ ] **Step 10: `Tests/CodeEditorPluginTests/Annotations/AnnotationThemeTests.swift`**

Current imports (lines 1–6):

```swift
import CodeEditorDesignTokens
import CodeEditorPlatform
@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorDesignTokens
import CodeEditorPlatform
@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorDesignTokens
import CodeEditorPlatform
@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing
```

Audit: if this file only uses public Annotation surface (`AnnotationKind.color(in: theme)` etc.) and no umbrella internals, `@testable import CodeEditorPlugin` could potentially be dropped. Defer the audit: keep `@testable` defensively for this commit; revisit in §6.2.15 (test-target split).

- [ ] **Step 11: `Tests/CodeEditorPluginTests/CodeEditorViewTests.swift`**

Current imports (lines 1–9):

```swift
import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
import CodeEditorTextModel
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
import CodeEditorTextModel
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
import CodeEditorTextModel
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest
```

Keep `@testable` — this file is broad and almost certainly uses umbrella internals beyond Annotations.

- [ ] **Step 12: `Tests/CodeEditorPluginTests/IOSAnnotationTests.swift`**

Current imports (lines 8–11, after a header comment block):

```swift
@testable import CodeEditorPlugin
import XCTest
#if canImport(UIKit)
import UIKit
```

Use `Edit` to replace `old_string`:
```swift
@testable import CodeEditorPlugin
import XCTest
```

with `new_string`:
```swift
import CodeEditorAnnotations
@testable import CodeEditorPlugin
import XCTest
```

(`CodeEditorAnnotations` sorts before `CodeEditorPlugin` alphabetically.) Keep `@testable` — `MockIOSAnnotationDataSource` extends `NSObject` and the test fixture uses umbrella `CodeEditorView` setup.

- [ ] **Step 13: `Tests/CodeEditorPluginTests/Layout/ThemeableUIComponentTests.swift`**

Current imports (lines 1–4):

```swift
@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing
```

Use `Edit` to replace `old_string`:
```swift
@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing
```

with `new_string`:
```swift
import CodeEditorAnnotations
@testable import CodeEditorPlugin
import CodeEditorTheming
import Foundation
import Testing
```

- [ ] **Step 14: `Tests/CodeEditorPluginTests/MemoryLeakTests.swift`**

Current imports (lines 1–4):

```swift
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSyntaxHighlighting
import XCTest
```

Use `Edit` to replace `old_string`:
```swift
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSyntaxHighlighting
import XCTest
```

with `new_string`:
```swift
import CodeEditorAnnotations
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSyntaxHighlighting
import XCTest
```

- [ ] **Step 15: Per-target build to localize any miss**

Run:
```bash
swift build --target CodeEditorAnnotations 2>&1 | tail -5
swift build --target CodeEditorPlugin 2>&1 | tail -10
swift build --target CodeEditorSample 2>&1 | tail -10
```

Expected: all three `Build complete!`. If `CodeEditorPlugin` fails, the error names the file with the missing reference — return to Steps 1–4 and verify the import was added. If `CodeEditorSample` fails, check Steps 5–8.

- [ ] **Step 16: Full build green**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. The per-target builds in Step 15 don't include the test targets; SwiftPM picks them up in this full pass. If a test file still fails, return to Steps 9–14 and verify their imports.

---

### Task 6: Verification

**Files:** none modified.

- [ ] **Step 1: Run lint with autofix**

Run:
```bash
swiftlint --fix
swiftlint
```

Expected: zero violations. Strict mode is on (warnings fail). If `swiftlint --fix` reorders any import (`sorted_imports`), the change is folded into Task 9's main commit. Do not commit separately.

- [ ] **Step 2: Run targeted tests**

Run:
```bash
swift test --filter AnnotationTests 2>&1 | tail -5
swift test --filter AnnotationThemeTests 2>&1 | tail -5
swift test --filter IOSAnnotationTests 2>&1 | tail -5
swift test --filter MemoryLeakTests 2>&1 | tail -5
swift test --filter ThemeableUIComponentTests 2>&1 | tail -5
```

Expected: pass counts match the Task 1 Step 6 baselines. No new failures, no test count regressions.

- [ ] **Step 3: Skip the full test suite per memory `feedback_test_confirmations.md`**

This is an additive-only restructure with build green and targeted tests passing. Do NOT run `swift test --parallel` — adds minutes without uncovering anything the targeted filter would miss.

If you have specific reason to suspect a regression (e.g., the umbrella build surfaced an unexpected error fixed in Task 5), run the full suite. Otherwise skip.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorAnnotations/
ls -1 Sources/CodeEditorPlugin/Annotations 2>&1 | head -3
ls -1 Sources/CodeEditorPlugin/Core/Annotations/
```

Expected:
- `Sources/CodeEditorAnnotations/` contains exactly 7 files: `Annotation.swift`, `AnnotationKind.swift`, `AnnotationView.swift`, `AnnotationsContentView.swift`, `CodeEditorViewAnnotation.swift`, `LineAnnotation.swift`, `MessageLineAnnotation.swift`.
- `Sources/CodeEditorPlugin/Annotations` prints `No such file or directory` (removed in Task 4 Step 3).
- `Sources/CodeEditorPlugin/Core/Annotations/` contains exactly `AnnotationsDataSource.swift`.

- [ ] **Step 5: Sanity check `Package.swift` shape**

Run:
```bash
grep -n "CodeEditorAnnotations" Package.swift
```

Expected: 4 hits:
1. The `.target` stanza (`name: "CodeEditorAnnotations"`)
2. `"CodeEditorAnnotations"` in the umbrella `CodeEditorPlugin.dependencies`
3. `"CodeEditorAnnotations"` in `CodeEditorSample.dependencies`
4. `"CodeEditorAnnotations"` in `CodeEditorPluginTests.dependencies`

If a `.library(name: "CodeEditorAnnotations", ...)` product entry appears (5+ hits), that's a bug — the spec stipulates no product. Remove it.

If a hit appears in `CodeEditorUI.dependencies`, `CodeEditorUITests.dependencies`, `CodeEditorDesignTokensTests.dependencies`, or `CodeEditorSampleTests.dependencies`, also remove — those targets do not consume Annotation types per Task 1 Step 3.

- [ ] **Step 6: Confirm baseline counts have moved as expected**

Run:
```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
find Sources/CodeEditorPlugin -mindepth 1 -maxdepth 1 -type d | wc -l
```

Expected:
- Umbrella `.swift` count drops by **7** (7 files moved out; `AnnotationsDataSource.swift` relocated within umbrella so no net change): `309 → 302`.
- Total under `Sources/`: unchanged at `592` (files moved, not added/removed).
- Top-level umbrella directories drop by **1** (`Annotations/` removed): `8 → 7`.

If actual numbers differ, use the actual numbers in Task 8 Step 5. The `480` historical baseline does not change.

---

### Task 7: Sample app smoke (manual)

**Files:** none modified. This is the only manual gate in the plan.

- [ ] **Step 1: Launch the sample app**

Run:
```bash
pkill -f CodeEditorSample 2>/dev/null
pkill -f lldb 2>/dev/null
swift run CodeEditorSample
```

The `pkill` lines come from memory `feedback_process_hygiene.md` — kill stale instances before launching.

- [ ] **Step 2: Open the annotations knob panel**

In the sample app, locate the `AnnotationsKnobsSection` panel (typically in the right-side knob inspector). It exposes toggles for annotation kinds.

- [ ] **Step 3: Exercise annotation rendering**

With a sample document open:
- Toggle annotations on. Verify badges render in or near the gutter.
- Change the demo annotation kind (`.error` / `.warning` / `.info`). Verify the badge color changes — this exercises `AnnotationKind.color(in: theme)` in the new target.
- Click a badge. Verify the popover/popup appears — this exercises `AnnotationView.showPopup` (the 601-line `AnnotationView` is the most complex moving file).

If badges do not render or click does not show the popup, the data source wiring is broken — verify `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift` resolved `Annotation` and `CodeEditorViewAnnotation` via the new `import CodeEditorAnnotations` (Task 5 Step 1).

- [ ] **Step 4: Exercise LSP diagnostics annotation surface**

If the sample exposes LSP-driven diagnostics (it does via `DiagnosticsBridge.swift`), trigger one (e.g., open a Swift file with an intentional error). Verify the diagnostic badge renders. This exercises `MessageLineAnnotation` (the LSP-side annotation flavour).

If the sample's LSP server is not configured, skip this step. The unit tests cover the `MessageLineAnnotation` → `Annotation` conversion path.

- [ ] **Step 5: Quit cleanly**

Cmd-Q to quit. No console errors. If the app does not quit cleanly, kill any stale processes (`pkill -f CodeEditorSample`) before retrying.

If any step fails, do not proceed to Task 8 — investigate, fix, re-run Task 6, then retry Task 7.

---

### Task 8: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

The `(pending commit SHA)` placeholders added in this task get back-filled in Task 9 Step 3 after the extraction commit lands.

- [ ] **Step 1: Update `CLAUDE.md` — remove `Annotations/` from the umbrella source tree**

Open `CLAUDE.md`. Locate the `## Source Tree` ASCII tree (lines 52–62). Currently reads:

```
Sources/CodeEditorPlugin/
├── Annotations/             # Data-source driven annotation badges
├── Completion/              # Code completion providers
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, Search/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
├── Features/                # Optional features (folding, smart editing, search/replace, etc.)
├── LSP/                     # Language Server Protocol support
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Layout/                  # UI components + co-located ViewModels
└── SwiftUI/                 # SwiftUI wrappers and modifiers
```

Use `Edit` to replace `old_string`:
```
Sources/CodeEditorPlugin/
├── Annotations/             # Data-source driven annotation badges
├── Completion/              # Code completion providers
```

with `new_string`:
```
Sources/CodeEditorPlugin/
├── Completion/              # Code completion providers
```

The `├──` for `Completion/` stays unchanged (it's no longer last; `SwiftUI/` keeps its `└──`).

- [ ] **Step 2: Update `CLAUDE.md` — note `Annotations/` joined the pre-extraction list**

Find the `Pre-extraction directories ...` paragraph (line 64). Currently reads:

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

Use `Edit` to replace with:

```markdown
Pre-extraction directories (`Text/`, `SyntaxHighlighting/`, `Theming/`, `Configuration/`, `Documents/`, `Platform/`, `Extensions/`, `Models/`, `Utilities/`, `Resources/`, `Workspace/`, `Search/`, `Annotations/`) have been carved out into sibling SPM targets — see "Other source roots" below.
```

- [ ] **Step 3: Update `CLAUDE.md` — add `Annotations/` to the F3 sub-bucket list in `Core/`**

The `Core/` entry currently lists sub-buckets (line 56):

```
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, Search/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

Insert `Annotations/` alphabetically (before `Configuration/`):

```
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Annotations/, Configuration/, Documents/, Folding/, Platform/, Search/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

- [ ] **Step 4: Update `CLAUDE.md` — refresh umbrella file count**

Locate line 68:

```
8 top-level directories in the umbrella target, 309 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8f), and 592 Swift source files under `Sources/`.
```

Use Task 6 Step 6's actual counts. Expected change: `309 → 302`, `8 → 7`, `592` unchanged.

Use `Edit` to replace with:

```
7 top-level directories in the umbrella target, 302 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f), and 592 Swift source files under `Sources/`.
```

The §-suffix list stays sorted: `§6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f`.

If Task 6 Step 6's actual counts differ (e.g., `303` or `301`), use those numbers. The `480` baseline does not change.

- [ ] **Step 5: Update `CLAUDE.md` — add `CodeEditorAnnotations` to "Other source roots"**

Locate the "Other source roots" list (lines 70–86). Insert a new bullet for `CodeEditorAnnotations` alphabetically — between `Sources/CodeEditorCommon/` (which currently appears first in the list) and `Sources/CodeEditorDesignTokens/`. The list isn't in strict alphabetical order (it's grouped by phase), so match the existing convention: `Annotations` is phase 4, so place it after the other phase-0 targets but as the first phase-4 entry.

The closest precedent is the placement of `Sources/CodeEditorSearch/` (phase 4, opt-in) in the existing list. Place `CodeEditorAnnotations` directly before `Sources/CodeEditorSearch/`:

Use `Edit` to insert before the `Sources/CodeEditorSearch/` bullet:

old_string:
```markdown
- `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter (phase 4; new in §6.2.8d). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`). The in-document `SearchReplaceEngine` stays in the umbrella at `Sources/CodeEditorPlugin/Core/Search/` (`CodeEditorView`-coupled, awaiting §6.2.12).
```

new_string:
```markdown
- `Sources/CodeEditorAnnotations/` — annotation data model + view chrome: `Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation` (phase 4; new in §6.2.8e). The umbrella-coupled `AnnotationsDataSource` protocol stays in the umbrella at `Sources/CodeEditorPlugin/Core/Annotations/` (its required method takes `CodeEditorView`, awaiting §6.2.12). Not productized — umbrella consumes Annotation types via 3 files (`Core/CodeEditorView+AnnotationsExtensions.swift`, `Core/CodeEditorView+LayoutExtensions.swift`, `Layout/ThemeableUIComponent+Conformances.swift`), so it routes through the umbrella rather than as an opt-in `.library`.
- `Sources/CodeEditorSearch/` — project-wide file-search protocols + portable adapter (phase 4; new in §6.2.8d). Productized as opt-in `.library` per NEXT.md §6.3; the umbrella `CodeEditorPlugin` does not depend on it. Foundation-only; cross-platform (no `#if canImport`). The in-document `SearchReplaceEngine` stays in the umbrella at `Sources/CodeEditorPlugin/Core/Search/` (`CodeEditorView`-coupled, awaiting §6.2.12).
```

- [ ] **Step 6: Update `NEXT.md` §6.0 status header**

Open `NEXT.md`. Locate the §6.0 prefix paragraph (line 252). Currently includes "`CodeEditorSearch` (§6.2.8d) followed as another carve-out — 1 file moved..." Append a sentence about §6.2.8e immediately before the closing "Nine new SPM targets..." sentence.

old_string:
```markdown
**Phases 0–4 done; phase 3.5 (SH) carved out.** `CodeEditorDiagnostics` (§6.2.10) landed ahead of §6.2.7 in `e60f7857` to unblock SyntaxHighlighting. `CodeEditorSyntaxHighlighting` (§6.2.7) followed as a carve-out — 36 of 45 SH files moved to the new target; 9 `CodeEditorView`-coupled files stayed in umbrella under `Core/SyntaxHighlighting/`. `CodeEditorSearch` (§6.2.8d) followed as another carve-out — 1 file moved to the new target; `SearchReplaceEngine.swift` stayed in umbrella (relocated to `Core/Search/`) and `EditorController+SelectMatch.swift` migrated to the sample (first cross-restructure public-API removal from the umbrella). Nine new SPM targets now exist alongside the existing `CodeEditorDesignTokens` / `CodeEditorPlugin` / `CodeEditorUI` / `CodeEditorSample`. Build green on every commit.
```

new_string:
```markdown
**Phases 0–4 done; phase 3.5 (SH) carved out.** `CodeEditorDiagnostics` (§6.2.10) landed ahead of §6.2.7 in `e60f7857` to unblock SyntaxHighlighting. `CodeEditorSyntaxHighlighting` (§6.2.7) followed as a carve-out — 36 of 45 SH files moved to the new target; 9 `CodeEditorView`-coupled files stayed in umbrella under `Core/SyntaxHighlighting/`. `CodeEditorSearch` (§6.2.8d) followed as another carve-out — 1 file moved to the new target; `SearchReplaceEngine.swift` stayed in umbrella (relocated to `Core/Search/`) and `EditorController+SelectMatch.swift` migrated to the sample (first cross-restructure public-API removal from the umbrella). `CodeEditorAnnotations` (§6.2.8e) followed as another carve-out — 7 of 8 files moved to the new target; the `CodeEditorView`-coupled `AnnotationsDataSource` protocol stayed in umbrella (relocated to `Core/Annotations/`). Ten new SPM targets now exist alongside the existing `CodeEditorDesignTokens` / `CodeEditorPlugin` / `CodeEditorUI` / `CodeEditorSample`. Build green on every commit.
```

(Note the count `Nine new SPM targets` → `Ten new SPM targets`.)

- [ ] **Step 7: Update `NEXT.md` §6.0 status table — append the Annotations row**

Locate the §6.0 status table. The current closing row is `CodeEditorSearch` (`18f9d43a`). Append immediately after it:

```markdown
| `CodeEditorAnnotations` | `(pending commit SHA)` | 7 files moved from umbrella `Annotations/` to new target (`Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation`). Pre-commit `(pending pre-relocation SHA)` relocated umbrella-coupled `AnnotationsDataSource.swift` to `Core/Annotations/`. Not productized — umbrella consumes Annotation types via 3 files (matches Folding/Symbols/SH/Languages precedent). Zero access-modifier promotions. | Common, Platform, Theming |
```

(The `(pending pre-relocation SHA)` placeholder uses the SHA captured in Task 2 Step 7.)

- [ ] **Step 8: Update `NEXT.md` §6.0 — add the §6.2.8e deviations block**

Immediately after the §6.2.8d Search deviations block (which closes with "Test placement follows the §6.2.7/§6.2.8a/§6.2.8b/§6.2.8f precedent..."), insert:

```markdown
**Deviations during §6.2.8e `CodeEditorAnnotations` (commit `(pending)`):**

- **Carve-out shape with 7:1 moved-to-stayed ratio.** Worst in the series so far: SH was 36:9, Folding 4:4, Symbols 2/3:1, Search 1:1, Workspace 2:0 clean. 7 pure files moved (`Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation`); `AnnotationsDataSource` stayed because its required method takes `CodeEditorView` as a parameter (line 115).
- **NEXT.md §4.1's `Annotations → TextModel` dep claim was wrong.** Actual deps: `Common, Platform, Theming`. No `CodeEditorTextModel` reference in the moving set (Foundation `NSRange`/`NSTextLocation` suffice). Joins §6.2.5 Theming's "no Platform dep" correction, §6.2.8b Symbols's "no Common/TextModel/Platform" correction, §6.2.8f Workspace's "Foundation only" correction. Pattern established: §4.1's dep claims are speculative until grep proves them.
- **No productization.** Umbrella consumes Annotation types via 3 umbrella files (`Core/CodeEditorView+AnnotationsExtensions.swift`, `Core/CodeEditorView+LayoutExtensions.swift`, `Layout/ThemeableUIComponent+Conformances.swift`). Matches Folding / Symbols / SH / Languages precedent. Does NOT match Workspace / Search / Diagnostics opt-in pattern.
- **Zero access-modifier promotions.** Every top-level moving type already had explicit `public init`(s). Ties §6.2.8f Workspace and §6.2.8d Search for the smallest promotion surface in the series. Far smaller than §6.2.7 SH (~107) or §6.2.8b Symbols (7).
- **`AnnotationsDataSource` doc-comment `CodeEditorView` references unchanged.** Three doc-comment mentions (lines 44, 68, 74) compile because the file stays in umbrella. `Annotation.swift`'s `@SeeAlso CodeEditorView.addAnnotation(_:)` doc comment (line 46) becomes a cross-module symbol reference after the move; left as-is per CLAUDE.md's no-DocC-catalog stance.
- **Test placement** follows the §6.2.7/§6.2.8a/§6.2.8b/§6.2.8d/§6.2.8f precedent — no new `CodeEditorAnnotationsTests` target. All 6 test files stay in `CodeEditorPluginTests/` with `import CodeEditorAnnotations` added alongside their existing `@testable import CodeEditorPlugin` (kept defensively per §6.2.8d's plan-execution lesson). Per-target test split deferred to §6.2.15.
- **14 files gain `import CodeEditorAnnotations`** — 4 umbrella (including the relocated `AnnotationsDataSource.swift`), 4 sample, 6 tests. No new dep on `CodeEditorUI` / `CodeEditorUITests` / `CodeEditorDesignTokensTests` / `CodeEditorSampleTests`.
- **`Layout/ThemeableUIComponent+Conformances.swift` gains the import now and travels with §6.2.11.** When `CodeEditorLayout` extracts, the new `CodeEditorLayout` target gains `CodeEditorAnnotations` as a direct dep, matching NEXT.md §4.2's `Annotations --> Layout` edge.
- **Phase 4 semantic label vs build-graph reality.** Annotations is labelled phase 4 (feature engine). With deps on `Common, Platform, Theming`, its build-graph slot is between phase 2 (Theming) and phase 4. Label kept because it's a feature, not foundational infra.
```

- [ ] **Step 9: Update `NEXT.md` §6.2.8 — add the Annotations sub-bullet**

Locate the bullet list inside step 8 of §6.2 ("Extract feature engines individually"). The current order is `Folding` → `Symbols` → `Workspace` → `Search` → `SmartEditing` (deferred). Insert the new Annotations sub-bullet immediately before the deferred SmartEditing bullet (after Search):

old_string:
```markdown
   - **[done — carve-out, see §6.0]** **`CodeEditorSearch`** (§6.2.8d) — 1 file moved from `Sources/CodeEditorPlugin/Search/` to `Sources/CodeEditorSearch/`: `ProjectSearchProvider.swift`. `SearchReplaceEngine.swift` relocated to umbrella `Core/Search/`; `EditorController+SelectMatch.swift` migrated out of umbrella to `Sources/CodeEditorSample/EditorActions/` (first cross-restructure public-API removal). Productized as opt-in `.library` per §6.3; umbrella does NOT depend on it. (`18f9d43a` + pre-relocation `0cdf53f9`)
   - **[deferred — blocked on §6.2.12]** **`CodeEditorSmartEditing`** (§6.2.8c)
```

new_string:
```markdown
   - **[done — carve-out, see §6.0]** **`CodeEditorSearch`** (§6.2.8d) — 1 file moved from `Sources/CodeEditorPlugin/Search/` to `Sources/CodeEditorSearch/`: `ProjectSearchProvider.swift`. `SearchReplaceEngine.swift` relocated to umbrella `Core/Search/`; `EditorController+SelectMatch.swift` migrated out of umbrella to `Sources/CodeEditorSample/EditorActions/` (first cross-restructure public-API removal). Productized as opt-in `.library` per §6.3; umbrella does NOT depend on it. (`18f9d43a` + pre-relocation `0cdf53f9`)
   - **[done — carve-out, see §6.0]** **`CodeEditorAnnotations`** (§6.2.8e) — 7 of 8 files moved from `Sources/CodeEditorPlugin/Annotations/` to `Sources/CodeEditorAnnotations/` (`Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation`). 1 `CodeEditorView`-coupled file (`AnnotationsDataSource`) relocated to umbrella `Core/Annotations/`. Not productized — umbrella consumes Annotation types via 3 files; routes through umbrella per Folding/Symbols/SH/Languages precedent. Final deps: `Common`, `Platform`, `Theming`. (`(pending)` + pre-relocation `(pending pre-relocation SHA)`)
   - **[deferred — blocked on §6.2.12]** **`CodeEditorSmartEditing`** (§6.2.8c)
```

(The match string truncates the deferred SmartEditing bullet at its label; preserve the rest of that bullet's text unchanged.)

- [ ] **Step 10: Update `NEXT.md` §10 — strike Annotations from the remaining list**

Locate §10's "6.2.8 feature engines" bullet (line 451):

old_string:
```markdown
- **6.2.8 feature engines** — `Annotations`, `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0); `Search` is done (§6.2.8d, carve-out — see §6.0); `Workspace` is done (§6.2.8f, clean extraction — see §6.0); `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

new_string:
```markdown
- **6.2.8 feature engines** — `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); `Symbols` is done (§6.2.8b, carve-out — see §6.0); `Search` is done (§6.2.8d, carve-out — see §6.0); `Annotations` is done (§6.2.8e, carve-out — see §6.0); `Workspace` is done (§6.2.8f, clean extraction — see §6.0); `SmartEditing` is **deferred** (§6.2.8c — blocked on §6.2.12 Core split because all 5 SmartEditing files take `CodeEditorView` as a parameter on every public entry point). Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

(Note: "One session per remaining engine." removed since only Completion remains.)

- [ ] **Step 11: Update `NEXT.md` §10 preamble**

Locate line 449:

old_string:
```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8f, and 6.2.10 are done (see §6.0). Remaining work:
```

new_string:
```markdown
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, and 6.2.10 are done (see §6.0). Remaining work:
```

- [ ] **Step 12: Update `NEXT.md` §4.1 phase table**

Locate the `CodeEditorAnnotations` row in §4.1's phase table (line 86):

old_string:
```markdown
| 4 | `CodeEditorAnnotations` | `Annotations/` | TextModel |
```

new_string:
```markdown
| 4 | `CodeEditorAnnotations` | `Annotations/` (7 of 8 files; `AnnotationsDataSource.swift` stays in umbrella per §6.2.8e — `CodeEditorView`-coupled, awaiting §6.2.12) | Common, Platform, Theming |
```

(Corrects the `TextModel` dep claim — actual deps are `Common, Platform, Theming`. Matches the §6.2.8d row's revision pattern.)

- [ ] **Step 13: Update `NEXT.md` §3 current state inventory**

Locate the `Annotations/` row in the §3 inventory table (line 53):

```markdown
| Annotations/ | 8 | Annotation data sources / badges |
```

Since `Annotations/` is now empty (extracted), the row should be removed:

old_string:
```markdown
| Configuration/ | 7 | `EditorConfiguration`, presets |
| Models/ | 5 | Shared data models |
| Documents/ | 2 | `EditorDocument` + `EditorDocuments` |
| Workspace/ | 2 | Workspace indexing/search |
| Search/ | 1 | Search result types |
| Resources/ | 0 | Themes JSON only |
```

Wait — verify that table currently. Run:
```bash
grep -n "^| " NEXT.md | head -30
```

If the table still includes pre-extraction rows for already-extracted dirs (`Annotations/`, `Workspace/`, `Search/`, `Configuration/`, `Documents/`, `Models/`, `Resources/`), the inventory is historical and should NOT be edited — it documents the pre-restructure state. Leave the §3 table alone.

If the table has been edited to drop already-extracted rows, drop the `Annotations/` row too:

old_string:
```markdown
| Annotations/ | 8 | Annotation data sources / badges |
```

new_string: (empty — removed)

Read the file to decide which case applies. If unsure, leave the §3 table unchanged — it's the lowest-impact option.

- [ ] **Step 14: Verify build + lint after doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```

Expected: both clean. (Markdown edits don't affect compilation, but verify in case a `.swift` file was touched accidentally.)

---

### Task 9: Main extraction commit + SHA back-fill

**Files:** none modified in this task beyond NEXT.md SHA back-fill.

- [ ] **Step 1: Stage all changes from Tasks 3–8**

Run:
```bash
git add Sources/CodeEditorAnnotations \
        Sources/CodeEditorPlugin \
        Sources/CodeEditorSample \
        Tests/CodeEditorPluginTests \
        Package.swift \
        CLAUDE.md \
        NEXT.md
git status --short
```

Expected output (7 renames + ~11 modifications):
- 7 renames: `Sources/CodeEditorPlugin/Annotations/<File>.swift → Sources/CodeEditorAnnotations/<File>.swift` (one per moved file)
- Modifications to `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift`
- Modifications to `Sources/CodeEditorPlugin/Core/CodeEditorView+AnnotationsExtensions.swift`, `Core/CodeEditorView+LayoutExtensions.swift`, `Layout/ThemeableUIComponent+Conformances.swift`
- Modifications to `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`, `CommandPalette/CommandPaletteCatalog.swift`, `EditorActions/AnnotationsHub.swift`, `KnobPanels/AnnotationsKnobsSection.swift`
- Modifications to 6 test files under `Tests/CodeEditorPluginTests/`
- Modifications to `Package.swift`, `CLAUDE.md`, `NEXT.md`

If any unexpected files appear (e.g., `.DS_Store`, snapshot regeneration, untracked source files), investigate before committing.

- [ ] **Step 2: Create the main extraction commit**

Replace `(pending pre-relocation SHA — captured in Task 2 Step 7)` in the commit message body with the actual SHA from Task 2 Step 7 BEFORE running this command.

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorAnnotations target (§6.2.8e)

Move 7 of 8 files from Sources/CodeEditorPlugin/Annotations/ into a
new CodeEditorAnnotations SPM target: Annotation, AnnotationKind,
AnnotationView, AnnotationsContentView, CodeEditorViewAnnotation,
LineAnnotation, MessageLineAnnotation. Carve-out matching §6.2.7
(SH), §6.2.8a (Folding), §6.2.8b (Symbols), §6.2.8d (Search):
AnnotationsDataSource.swift stayed in umbrella because its required
`textView(_ textView: CodeEditorView, viewForLineAnnotation:...)`
method takes CodeEditorView as a parameter (relocated to
Core/Annotations/ in pre-commit).

NEXT.md §4.1's "Annotations → TextModel" dep claim was wrong; actual
deps are Common + Platform + Theming. No CodeEditorTextModel
reference in the moving set (Foundation NSRange/NSTextLocation
suffice). Joins §6.2.5 Theming and §6.2.8b Symbols in correcting
NEXT.md §4.1's speculative dep claims.

Not productized as a .library. The umbrella CodeEditorPlugin
consumes Annotation types via 3 umbrella files
(Core/CodeEditorView+AnnotationsExtensions.swift,
Core/CodeEditorView+LayoutExtensions.swift,
Layout/ThemeableUIComponent+Conformances.swift), so it routes
through the umbrella like Folding / Symbols / SH / Languages, not
opt-in like Workspace / Search / Diagnostics.

Zero access-modifier promotions — every moving top-level type was
already public with an explicit public init. Ties §6.2.8d Search
and §6.2.8f Workspace for the smallest promotion surface in the
restructure series.

In-tree: 14 files gain `import CodeEditorAnnotations` — 4 umbrella
(including the relocated AnnotationsDataSource), 4 sample, 6 tests.
CodeEditorUI / CodeEditorUITests / CodeEditorDesignTokensTests /
CodeEditorSampleTests unchanged.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-annotations-extraction-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-annotations-extraction.md
Pre-relocation: (pending pre-relocation SHA — captured in Task 2 Step 7)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Capture the extraction commit SHA and back-fill `NEXT.md` placeholders**

Run:
```bash
git log -1 --format=%h
```

Save the short SHA (e.g., `def5678`).

Open `NEXT.md` and replace each placeholder added in Task 8:
- Task 8 Step 7 (status-table row): `(pending commit SHA)` → `<extraction SHA>`; `(pending pre-relocation SHA)` → `<pre-commit SHA from Task 2 Step 7>`.
- Task 8 Step 8 (deviations block header): `(pending)` → `<extraction SHA>`.
- Task 8 Step 9 (sub-bullet): `(pending)` → `<extraction SHA>`; `(pending pre-relocation SHA)` → `<pre-commit SHA>`.

Use `grep -n "(pending" NEXT.md` to verify no placeholders remain after replacement.

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
Update NEXT.md SHA back-reference for §6.2.8e

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Note: the separate-commit pattern (§6.2.8a `bf6aeb64`, §6.2.8b `51751af2`, §6.2.8d `01d20149`, §6.2.8f `1b706023`) is the established convention. Do NOT use `git commit --amend`.

- [ ] **Step 6: Verify final git state**

Run:
```bash
git log -5 --oneline
git status --short
```

Expected:
- The SHA back-fill commit on top.
- The main extraction commit below it.
- The pre-relocation commit (from Task 2 Step 6) below that.
- The spec commit (`aa847447`) at the bottom of this run.
- Working tree clean.

- [ ] **Step 7: Stop. Do not push.**

The user will review the local commits and push when ready.

---

## Plan self-review

**1. Spec coverage:**

| Spec section | Plan coverage |
|---|---|
| §1 Goal (carve-out, AnnotationsDataSource stays, 7 files move, zero promotions, zero breaking changes) | Tasks 2 + 4 + Task 8 Step 8 ✓ |
| §2.1 Files that move (7 listed) | Task 4 Step 2 (all 7 `git mv`s) ✓ |
| §2.2 File that stays (AnnotationsDataSource) | Task 2 (pre-relocation commit) ✓ |
| §2.3 Dependency edges (Common + Platform + Theming, NO TextModel) | Task 3 Step 1 ✓; correction recorded in Task 8 Step 8 ✓ |
| §2.4 No productization | Task 3 Step 6 (explicit no-product check) ✓ |
| §3.1 Pre-commit shape | Task 2 ✓ |
| §3.2 Commit B execution (8 numbered steps) | Tasks 3–9 ✓ |
| §3.3 Zero promotions expected | Task 1 Step 5 (audit), Task 8 Step 8 (deviations note) ✓ |
| §4.1 Umbrella consumers (4 files) | Task 5 Steps 1–4 ✓ |
| §4.2 Sample consumers (4 files) | Task 5 Steps 5–8 ✓ |
| §4.3 Test consumers (6 files) | Task 5 Steps 9–14 ✓ |
| §4.4 Targets unchanged (UI, UITests, DesignTokensTests, SampleTests) | Task 3 Step 5 + Task 6 Step 5 ✓ |
| §4.5 SwiftLint ordering | Task 6 Step 1 + per-step alphabetical inserts ✓ |
| §4.6 `@testable` audit (do not blanket-drop) | Task 5 Steps 9–14 (each step preserves `@testable`) ✓ |
| §5 Risks (dead doc link, doc-comment refs, Layout migration coupling) | Task 8 Step 8 deviations block ✓ |
| §6 Expected deviations | Plan body acknowledges deviations occur (e.g., Task 3 Step 5 "record the deviation"); Task 8 Step 8 deviations block captures them ✓ |
| §7 Test strategy (per-target build order, targeted filters, manual smoke) | Task 5 Step 15, Task 6 Step 2, Task 7 ✓ |
| §8 Non-goals (not reshaping protocol, not productizing, not adding features) | Honored throughout ✓ |

No gaps.

**2. Placeholder scan:**

- `(pending commit SHA)`, `(pending)`, `(pending pre-relocation SHA)`, `(pending pre-relocation SHA — captured in Task 2 Step 7)` — all intentional placeholders the executor back-fills in Task 9 Step 3 / Step 2 commit-msg edit. Not bugs.
- No `TODO`, `TBD`, `FIXME`, `fill in later`, or `similar to Task N` text.
- Every code-editing step shows the actual code via `old_string` → `new_string` diffs or complete code blocks.

**3. Type consistency:**

- File path `Sources/CodeEditorAnnotations/` is consistent across Tasks 3, 4, 6, 8, 9.
- File path `Sources/CodeEditorPlugin/Core/Annotations/AnnotationsDataSource.swift` is consistent across Tasks 2, 5, 6, 8.
- Import name `import CodeEditorAnnotations` is used consistently in Tasks 3, 5, 6, 8.
- Type names `Annotation`, `AnnotationKind`, `AnnotationView`, `AnnotationsContentView`, `CodeEditorViewAnnotation`, `LineAnnotation`, `MessageLineAnnotation`, `AnnotationsDataSource` are spelled identically across the plan.
- File count deltas: Task 6 Step 6 expects `309 → 302` (umbrella), `8 → 7` (umbrella top-level dirs); Task 8 Step 4 records the same numbers.
- Consumer count: Task 1 Step 3 says 13 paths (excluding the relocated AnnotationsDataSource which is in the moved-set's source dir at audit time); Task 5 has 14 steps (Step 1 covers the relocated file; Steps 2–14 cover the 13 grep'd consumers). Internally consistent.
- Pre-relocation SHA reference: captured in Task 2 Step 7, used in Task 8 Step 7 and Task 9 Step 2 and Task 9 Step 3.
- Extraction SHA reference: captured in Task 9 Step 3, back-filled in Task 9 Step 3 and committed in Task 9 Step 5.

No issues found. Plan ready for execution.
