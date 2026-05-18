# CodeEditorSwiftUI Extraction (§6.2.13) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all 17 files from `Sources/CodeEditorPlugin/SwiftUI/` into a new SPM target `CodeEditorSwiftUI` at `Sources/CodeEditorSwiftUI/`. Productized as `.library(name: "CodeEditorSwiftUI", targets: ["CodeEditorSwiftUI"])` per NEXT.md §6.3 "Probably" tier. Umbrella `CodeEditorPlugin` adds the new target as a direct dependency (productized + umbrella-coupled, matching §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12). Public API surface of `import CodeEditorPlugin` is unchanged.

**Architecture:** Two or three commits. (1) Scaffold the new target with a placeholder `.swift` file + `Package.swift` edits (new product entry, new target declaration, umbrella dep). (2) Bulk `git mv` the 17 files, delete the placeholder, bulk-add `import CodeEditorSwiftUI` / `@testable import CodeEditorSwiftUI` to 255 consumer files via awk script, add `CodeEditorSwiftUI` to 5 consumer target deps in `Package.swift`, `swiftlint --fix`, iterate on any compile errors, build + test green. (3) **Conditional** clean-build fix only if `swift package clean && swift build` surfaces a transitive-dep masking bug (per §6.2.12 precedent — that round needed it for a missing `CodeEditorPlatform` dep in `CodeEditorTextModel`). End-of-chunk: `NEXT.md` §6.0 / §6.2 / §10 docs update + `CLAUDE.md` source-tree update in their own commit.

**Tech Stack:** Swift 6.3 SPM, `StrictConcurrency` enabled. New target's 12 internal deps (audit-confirmed): `CodeEditorAnnotations`, `CodeEditorCommon`, `CodeEditorCompletion`, `CodeEditorConfiguration`, `CodeEditorDiagnostics`, `CodeEditorLanguages`, `CodeEditorLayout`, `CodeEditorLSP`, `CodeEditorPlatform`, `CodeEditorTextModel`, `CodeEditorTheming`, `CodeEditorView`. No external products (no `Dependencies`, no `IssueReporting`, no `SwiftSyntax`).

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-swiftui-extraction-design.md` (commit `25ced6e`).

**Lessons baked in:**

- §6.2.7 SH: compile-driven access-modifier promotions. Spec baseline is 0 promotions; budget 0–5 surprises.
- §6.2.8b Symbols / §6.2.8c SmartEditing / §6.2.8g Completion / §6.2.12c: synth-init asymmetry — `public` structs / actors / classes with implicit inits that get constructed across target boundaries need explicit `public init(...)`.
- §6.2.8d Search: do NOT blanket-drop `@testable import CodeEditorPlugin` from tests; internal umbrella symbols may still be required.
- §6.2.8e Annotations: bare-word grep (`\b<TypeName>\b`) catches consumers that compound-name grep misses; budget compile-error iteration to catch the 5–15 under-counted files.
- §6.2.8f Workspace: SwiftPM requires at least one `.swift` file for a target with a `.library` product — scaffold with a placeholder file in Task 2, delete in Task 3.
- §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout / §6.2.12 View: productized + umbrella-coupled pattern. `.library` product + umbrella keeps direct dep.
- §6.2.11 Layout / §6.2.12 View: SwiftLint's `sorted_imports` rule decides alphabetical order; don't hand-write import order — let `swiftlint --fix` apply it.
- §6.2.12b: `git mv` followed by `git add` must stage both sides of the rename in the same commit. If a single `git add` errors on a removed source path, abandon and re-stage with both destination + deletion explicitly.
- §6.2.12: `[weak]` captures of `@MainActor` types across module boundaries trip cross-module strict-concurrency checks where same-module analysis tolerated them. If the build flags `CodeEditorBaseCoordinator`, add `@MainActor` to `markClean(view:)` or `@unchecked Sendable` to the class.
- §6.2.12 / §6.2.8c: `package extension Foo { ... }` is rejected by SwiftLint's `no_extension_access_modifier`. If a promotion lands, apply `package` per-method, not per-extension.
- `feedback_test_confirmations.md`: skip full `swift test --parallel` after additive-only steps; trust the build and run targeted tests instead.
- `project_nstextview_init_invariant.md`: sample-app smoke test is the canary — typing-still-works confirms the SwiftUI Representable wrapper still owns the TextKit2 network end-to-end.
- `feedback_fix_pre_existing_failures.md`: if a one-line stale-reference fix appears during execution, fix it inline rather than documenting it as a known issue.

**Estimated effort:** half-day. Most time is the 255-file consumer-import sweep + compile-error iteration.

---

### Task 1: Pre-flight audit

**Files:** read-only.

This task gathers facts that drive Tasks 2–4. Record the output of each step in the conversation so subsequent tasks can reference exact counts and file paths. Do not edit any file.

- [ ] **Step 1: Confirm working tree clean and on main**

Run:
```bash
git status
git log --oneline -3
```

Expected: clean working tree; HEAD includes the §6.2.13 spec commit (`25ced6e Spec §6.2.13 CodeEditorSwiftUI extraction`) or a later commit on the same chunk.

- [ ] **Step 2: Confirm carry-set inventory matches spec (17 files)**

Run:
```bash
find Sources/CodeEditorPlugin/SwiftUI -name '*.swift' | sort
```

Expected output (17 files):
```
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+FactoryExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+RepresentableParameters.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditorPlatformAdapter.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift
Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift
Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift
Sources/CodeEditorPlugin/SwiftUI/EditorController+TemporaryAttributesExtensions.swift
Sources/CodeEditorPlugin/SwiftUI/EditorController.swift
Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift
```

If count differs from 17, stop and reconcile with the spec before continuing.

- [ ] **Step 3: Audit the slice's union of imports**

Run:
```bash
grep -h '^import\|^@testable import' Sources/CodeEditorPlugin/SwiftUI/*.swift | sort -u
```

Expected: `Foundation`, `SwiftUI`, `AppKit`, `UIKit`, `@preconcurrency Combine`, plus the 12 internal `CodeEditor*` targets from the spec §3.1. No third-party imports (no `Dependencies`, no `IssueReporting`, no `SwiftSyntax`/`SwiftParser`).

If extra imports appear, reconcile with the spec's §3.1 list — the new target's `dependencies:` may need adjustment.

- [ ] **Step 4: Confirm `CodeEditorBaseCoordinator` location and protocol conformance**

Run:
```bash
grep -nE 'class CodeEditorBaseCoordinator|protocol CodeEditorCoordinating' \
    Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift \
    Sources/CodeEditorView/CodeEditorCoordinating.swift
```

Expected:
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift:22:open class CodeEditorBaseCoordinator: NSObject, ObservableObject, CodeEditorCoordinating`
- `Sources/CodeEditorView/CodeEditorCoordinating.swift:N:package protocol CodeEditorCoordinating: AnyObject`

Confirms: the open class moves with the slice; the package protocol stays in `CodeEditorView`. No promotion needed for either.

- [ ] **Step 5: Confirm `markClean(view:)` access modifier**

Run:
```bash
grep -nE 'markClean|func markClean' Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
```

Expected: at least one match with `package func markClean(view: CodeEditorView)` (the protocol conformance impl).

If the modifier is `internal` instead of `package`, the build will fail post-move because `package` is required for the protocol requirement in `CodeEditorView` target. Note for Task 3.

- [ ] **Step 6: Audit `EditorController.attach(to:)` access modifier**

Run:
```bash
grep -nE 'func attach\(to ' Sources/CodeEditorPlugin/SwiftUI/EditorController.swift
```

Expected: `func attach(to view: CodeEditorView?)` — implicit `internal`. Stays `internal`; tests will need `@testable import CodeEditorSwiftUI`.

- [ ] **Step 7: Survey consumer ripple by target**

Run (umbrella SwiftUI/ types referenced by `CodeEditorUI` sources):
```bash
grep -rln -E '\b(CodeEditor|EditorController|EditorControllerHandle|EditorState|CodeEditorBaseCoordinator|CodeEditorIntent|CodeEditorEnvironment|CodeEditorPlatformAdapter|CodeEditorRepresentableHelper|CodeEditorTheme)\b' \
    Sources/CodeEditorUI/ | sort
```

Expected: ~15 files. Record exact count.

Run (`CodeEditorSample`):
```bash
grep -rln -E '\b(CodeEditor|EditorController|EditorControllerHandle|EditorState|CodeEditorBaseCoordinator|CodeEditorIntent|CodeEditorEnvironment|CodeEditorPlatformAdapter|CodeEditorRepresentableHelper|CodeEditorTheme)\b' \
    Sources/CodeEditorSample/ | wc -l
```

Expected: ~58. Record exact count.

Run (`CodeEditorPluginTests`):
```bash
grep -rln -E '\b(CodeEditor|EditorController|EditorControllerHandle|EditorState|CodeEditorBaseCoordinator|CodeEditorIntent|CodeEditorEnvironment|CodeEditorPlatformAdapter|CodeEditorRepresentableHelper|CodeEditorTheme)\b' \
    Tests/CodeEditorPluginTests/ | wc -l
```

Expected: ~130. Record exact count.

Run (`CodeEditorSampleTests`):
```bash
grep -rln -E '\b(CodeEditor|EditorController|EditorControllerHandle|EditorState|CodeEditorBaseCoordinator|CodeEditorIntent|CodeEditorEnvironment|CodeEditorPlatformAdapter|CodeEditorRepresentableHelper|CodeEditorTheme)\b' \
    Tests/CodeEditorSampleTests/ | wc -l
```

Expected: ~37. Record exact count.

Run (`CodeEditorUITests`):
```bash
grep -rln -E '\b(CodeEditor|EditorController|EditorControllerHandle|EditorState|CodeEditorBaseCoordinator|CodeEditorIntent|CodeEditorEnvironment|CodeEditorPlatformAdapter|CodeEditorRepresentableHelper|CodeEditorTheme)\b' \
    Tests/CodeEditorUITests/ | wc -l
```

Expected: ~15. Record exact count.

**Note:** the regex above is intentionally broad. It will over-match files that mention `CodeEditor*` types unrelated to the SwiftUI slice. Task 3's blanket-add approach handles this — over-adding `import CodeEditorSwiftUI` is harmless (SwiftLint won't flag it; build doesn't care). Under-adding is the only error mode, and the compile-error loop in Task 3 catches that.

Total expected: ~255 files across 5 targets. Record total.

- [ ] **Step 8: Confirm Package.swift target ordering**

Run:
```bash
grep -nE 'name: "CodeEditor(View|SmartEditing|Plugin|UI|Workspace)"' Package.swift
```

Expected key locations:
- `products:` — `CodeEditorView` at line ~85, between `UI` (~81) and `Workspace` (~89).
- `targets:` — `CodeEditorView` target def at line ~250; `CodeEditorWorkspace` at ~273; `CodeEditorSmartEditing` at ~277; umbrella `CodeEditorPlugin` at ~287.

The new `.library` product slots alphabetically between `CodeEditorUI` and `CodeEditorView` in the products array; the new target declaration slots between `CodeEditorSmartEditing` and umbrella `CodeEditorPlugin` (or anywhere after its deps are defined — `CodeEditorView` is the latest dep).

- [ ] **Step 9: Baseline build + lint + test green**

Run:
```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`.

Run:
```bash
swiftlint 2>&1 | tail -3
```

Expected: `0 violations`.

Run:
```bash
swift test --parallel 2>&1 | tail -10
```

Expected: all suites pass with at most the 1 pre-existing known issue noted in §6.2.12c verification. DO NOT proceed to Task 2 if the baseline is broken.

- [ ] **Step 10: Record audit summary**

Write a short summary in the conversation:
- Carry-set: 17 files (confirmed/discrepancy)
- Slice imports: 12 internal + Foundation/SwiftUI/AppKit/UIKit/Combine (confirmed/discrepancy)
- `CodeEditorBaseCoordinator`: open class, line 22 of CodeEditor+CoordinatorsExtensions.swift
- `markClean(view:)`: package (yes/no)
- `EditorController.attach(to:)`: internal (yes/no)
- Consumer ripple totals: CodeEditorUI=____, CodeEditorSample=____, CodeEditorPluginTests=____, CodeEditorSampleTests=____, CodeEditorUITests=____, total=____
- Baseline green: yes/no.

This summary informs whether Tasks 3–4 need to handle any surprises beyond the spec's baseline.

---

### Task 2: Scaffold `CodeEditorSwiftUI` target (Commit 1)

**Files:**
- Create: `Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift`
- Modify: `Package.swift` (add product entry + target definition + umbrella dep)

- [ ] **Step 1: Create the new target directory and placeholder source file**

Run:
```bash
mkdir -p Sources/CodeEditorSwiftUI
```

Create `Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift`:

```swift
// Scaffold placeholder — deleted in Task 3 once real sources move in.
// SwiftPM requires at least one `.swift` file for a target with a
// `.library` product (§6.2.8f Workspace lesson).

internal enum _CodeEditorSwiftUIScaffoldPlaceholder {
    case placeholder
}
```

- [ ] **Step 2: Add new `.library` product entry to Package.swift**

Open `Package.swift`. Find the `products:` array (around line 55). The existing `.library` entries are alphabetically ordered: ...DesignTokens, Diagnostics, LSP, Layout, Plugin, Search, UI, **View**, Workspace, then `.executable(... CodeEditorSample)`.

`CodeEditorSwiftUI` slots alphabetically between `CodeEditorSearch` (line ~76) and `CodeEditorUI` (line ~80). Insert immediately before the `CodeEditorUI` entry:

```swift
        .library(
            name: "CodeEditorSwiftUI",
            targets: ["CodeEditorSwiftUI"]
        ),
```

Verify the alphabetical run is unbroken: ...`CodeEditorSearch`, `CodeEditorSwiftUI`, `CodeEditorUI`, `CodeEditorView`...

- [ ] **Step 3: Add new target declaration to Package.swift**

In `Package.swift`, the existing `targets:` array is phase-ordered, not alphabetical. The new target's deps include `CodeEditorView` (the latest non-aggregate dep), so it must be declared AFTER `CodeEditorView` (line ~250). Insert immediately after `CodeEditorSmartEditing` (line ~285) and before the umbrella `CodeEditorPlugin` (line ~287):

```swift
        .target(
            name: "CodeEditorSwiftUI",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
```

Note the alphabetical convention used in sibling target declarations: `CodeEditorLSP` slots before `CodeEditorLanguages` (matches the §6.2.9 import-ordering lesson — uppercase `L` < lowercase `a` per `sorted_imports`).

- [ ] **Step 4: Add `CodeEditorSwiftUI` to umbrella's `dependencies:` array**

Find the umbrella `.target(name: "CodeEditorPlugin", ...)` block (line ~287). Its `dependencies:` array is alphabetical. Insert `"CodeEditorSwiftUI",` between `"CodeEditorSymbols",` and `"CodeEditorSyntaxHighlighting",`. Result:

```swift
                "CodeEditorSmartEditing",
                "CodeEditorSwiftUI",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
```

- [ ] **Step 5: Verify Package.swift parses**

Run:
```bash
swift package describe --type json > /dev/null
```

Expected: exits 0 with no output. Any parse error indicates a syntactic problem.

- [ ] **Step 6: Build new target standalone**

Run:
```bash
swift build --target CodeEditorSwiftUI 2>&1 | tail -10
```

Expected: `Build complete!`. The placeholder file compiles; the 12 deps resolve.

- [ ] **Step 7: Build the umbrella with the new dep**

Run:
```bash
swift build --target CodeEditorPlugin 2>&1 | tail -10
```

Expected: `Build complete!`.

- [ ] **Step 8: Full build green**

Run:
```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`.

- [ ] **Step 9: Lint clean**

Run:
```bash
swiftlint --fix && swiftlint 2>&1 | tail -3
```

Expected: `0 violations`. The placeholder's `_` prefix is permitted; `internal enum` doesn't require `missing_docs`.

- [ ] **Step 10: Commit scaffold (Commit 1)**

Run:
```bash
git status
```

Expected: 1 new file (`Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift`) + 1 modified (`Package.swift`).

Stage and commit:
```bash
git add Package.swift Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift
git commit -m "$(cat <<'EOF'
Scaffold §6.2.13 CodeEditorSwiftUI target

Adds .library product, target declaration, and umbrella dep for the
new CodeEditorSwiftUI target. Includes _ScaffoldPlaceholder.swift to
satisfy SwiftPM's "non-empty target" requirement (§6.2.8f Workspace
lesson); the placeholder is deleted in Task 3 (bulk move).

No SwiftUI/ files moved yet. Build green.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Verify commit success**

Run:
```bash
git log -1 --format='%h %s'
git status
```

Expected: HEAD is the new commit; working tree clean.

---

### Task 3: Bulk move + ripple (Commit 2)

**Files:**
- Move: 17 files from `Sources/CodeEditorPlugin/SwiftUI/` to `Sources/CodeEditorSwiftUI/`
- Delete: `Sources/CodeEditorPlugin/SwiftUI/` directory, `Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift`
- Modify: `Package.swift` (add `CodeEditorSwiftUI` to 5 consumer target deps)
- Modify: ~255 consumer files across `Sources/CodeEditorUI/`, `Sources/CodeEditorSample/`, `Tests/CodeEditorPluginTests/`, `Tests/CodeEditorSampleTests/`, `Tests/CodeEditorUITests/` (add `import CodeEditorSwiftUI` line)

All work in this task lands in ONE commit. The bulk-add must be atomic with the file move because tests/source files reference the moved types — a half-applied state leaves the build red.

- [ ] **Step 1: Move all 17 files via `git mv`**

Run:
```bash
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift Sources/CodeEditorSwiftUI/CodeEditor+AppKitExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift Sources/CodeEditorSwiftUI/CodeEditor+DocumentsExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+FactoryExtensions.swift Sources/CodeEditorSwiftUI/CodeEditor+FactoryExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift Sources/CodeEditorSwiftUI/CodeEditor+ModifiersExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+RepresentableParameters.swift Sources/CodeEditorSwiftUI/CodeEditor+RepresentableParameters.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift Sources/CodeEditorSwiftUI/CodeEditor+UIKitExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift Sources/CodeEditorSwiftUI/CodeEditor.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift Sources/CodeEditorSwiftUI/CodeEditorEnvironment+Extensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift Sources/CodeEditorSwiftUI/CodeEditorIntent.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditorPlatformAdapter.swift Sources/CodeEditorSwiftUI/CodeEditorPlatformAdapter.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift Sources/CodeEditorSwiftUI/CodeEditorRepresentableHelper.swift
git mv Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift Sources/CodeEditorSwiftUI/CodeEditorTheme+Extensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/EditorController+Completion.swift Sources/CodeEditorSwiftUI/EditorController+Completion.swift
git mv Sources/CodeEditorPlugin/SwiftUI/EditorController+TemporaryAttributesExtensions.swift Sources/CodeEditorSwiftUI/EditorController+TemporaryAttributesExtensions.swift
git mv Sources/CodeEditorPlugin/SwiftUI/EditorController.swift Sources/CodeEditorSwiftUI/EditorController.swift
git mv Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift Sources/CodeEditorSwiftUI/EditorState+Environment.swift
```

Expected: no output. `git status` will show 17 renames.

- [ ] **Step 2: Delete the scaffold placeholder and the now-empty SwiftUI/ directory**

Run:
```bash
rm Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift
rmdir Sources/CodeEditorPlugin/SwiftUI
```

If `rmdir` fails because of `.DS_Store`, remove it first:
```bash
rm -f Sources/CodeEditorPlugin/SwiftUI/.DS_Store
rmdir Sources/CodeEditorPlugin/SwiftUI
```

If anything else remains in the directory, stop and reconcile — the spec assumes 17 files only.

- [ ] **Step 3: Verify the new target directory has exactly 17 files**

Run:
```bash
ls -la Sources/CodeEditorSwiftUI/
find Sources/CodeEditorSwiftUI -name '*.swift' | wc -l
```

Expected: 17 `.swift` files, no `.gitkeep`, no `_ScaffoldPlaceholder.swift`, no subdirectories, no `.DS_Store`.

- [ ] **Step 4: Add `CodeEditorSwiftUI` to 5 consumer target deps in Package.swift**

Open `Package.swift`. Apply each edit. The `dependencies:` array within each consumer target is alphabetical; insert `"CodeEditorSwiftUI",` in alphabetical position (between `"CodeEditorSmartEditing"` if present, or `"CodeEditorSearch"`, and `"CodeEditorSymbols"`).

**Edit 1:** `.target(name: "CodeEditorUI", ...)` (line ~316). Current deps array:
```swift
dependencies: [
    "CodeEditorDesignTokens",
    "CodeEditorLanguages",
    "CodeEditorPlugin",
    "CodeEditorSymbols",
    "CodeEditorTheming",
    "CodeEditorView"
],
```
Insert `"CodeEditorSwiftUI",` between `"CodeEditorPlugin",` and `"CodeEditorSymbols",`:
```swift
dependencies: [
    "CodeEditorDesignTokens",
    "CodeEditorLanguages",
    "CodeEditorPlugin",
    "CodeEditorSwiftUI",
    "CodeEditorSymbols",
    "CodeEditorTheming",
    "CodeEditorView"
],
```

**Edit 2:** `.executableTarget(name: "CodeEditorSample", ...)` (line ~328). Insert `"CodeEditorSwiftUI",` between `"CodeEditorSearch",` and `"CodeEditorTextModel",`:
```swift
"CodeEditorSearch",
"CodeEditorSwiftUI",
"CodeEditorTextModel",
```

**Edit 3:** `.testTarget(name: "CodeEditorPluginTests", ...)` (line ~356). Insert `"CodeEditorSwiftUI",` between `"CodeEditorSmartEditing",` and `"CodeEditorSymbols",`:
```swift
"CodeEditorSmartEditing",
"CodeEditorSwiftUI",
"CodeEditorSymbols",
```

**Edit 4:** `.testTarget(name: "CodeEditorUITests", ...)` (line ~399). Alphabetical order: `Sw` < `Sy` because `w` (0x77) < `y` (0x79), so `CodeEditorSwiftUI` slots before `CodeEditorSymbols`. Insert `"CodeEditorSwiftUI",` between `"CodeEditorLanguages",` and `"CodeEditorSymbols",`:
```swift
"CodeEditorLanguages",
"CodeEditorSwiftUI",
"CodeEditorSymbols",
```

**Edit 5:** `.testTarget(name: "CodeEditorSampleTests", ...)` (line ~416). Insert `"CodeEditorSwiftUI",` between `"CodeEditorSearch",` and `"CodeEditorView",`:
```swift
"CodeEditorSearch",
"CodeEditorSwiftUI",
"CodeEditorView",
```

(Note: `CodeEditorSampleTests` deps array does not currently contain `CodeEditorTextModel` between Sample and Search, so the alphabetical slot is what's stated above. Verify the surrounding entries before editing.)

- [ ] **Step 5: Verify Package.swift still parses**

Run:
```bash
swift package describe --type json > /dev/null
```

Expected: exits 0.

- [ ] **Step 6: Bulk-add `import CodeEditorSwiftUI` to umbrella `CodeEditorUI` source files**

Use this awk script to add `import CodeEditorSwiftUI` immediately after the existing `import` block of every `.swift` file in `Sources/CodeEditorUI/`. SwiftLint's `sorted_imports` will reorder during Step 11.

Run:
```bash
for f in $(grep -rl '^import ' Sources/CodeEditorUI/ --include='*.swift'); do
    if ! grep -q '^import CodeEditorSwiftUI' "$f"; then
        awk '
            /^import / && !done { print; lastImport=NR; next }
            !lastImport { print; next }
            NR == lastImport+1 && !done { print "import CodeEditorSwiftUI"; done=1 }
            { print }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
done
```

This is harmless if a file doesn't actually need the import — SwiftLint won't flag an unused import in this codebase (no `unused_import` rule). The compile loop in Step 12 reveals missed files; over-adding is the safe direction.

- [ ] **Step 7: Bulk-add `import CodeEditorSwiftUI` to `CodeEditorSample` source files**

Run the same script against `Sources/CodeEditorSample/`:
```bash
for f in $(grep -rl '^import ' Sources/CodeEditorSample/ --include='*.swift'); do
    if ! grep -q '^import CodeEditorSwiftUI' "$f"; then
        awk '
            /^import / && !done { print; lastImport=NR; next }
            !lastImport { print; next }
            NR == lastImport+1 && !done { print "import CodeEditorSwiftUI"; done=1 }
            { print }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
done
```

- [ ] **Step 8: Bulk-add `@testable import CodeEditorSwiftUI` to `CodeEditorPluginTests`**

Tests reach `EditorController.attach(to:)` (internal) — `@testable` is required. The script differs slightly: insert `@testable import` after the existing `@testable import CodeEditorPlugin` line (per §6.2.8d "don't blanket-drop @testable" lesson — leave the existing umbrella import in place, add the new one alongside).

Run:
```bash
for f in $(grep -rl '^import \|^@testable import ' Tests/CodeEditorPluginTests/ --include='*.swift'); do
    if ! grep -q '^@testable import CodeEditorSwiftUI' "$f"; then
        awk '
            /^import / && !done { print; lastImport=NR; next }
            /^@testable import / && !done { print; lastImport=NR; next }
            !lastImport { print; next }
            NR == lastImport+1 && !done { print "@testable import CodeEditorSwiftUI"; done=1 }
            { print }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
done
```

- [ ] **Step 9: Bulk-add `@testable import CodeEditorSwiftUI` to `CodeEditorSampleTests`**

Run:
```bash
for f in $(grep -rl '^import \|^@testable import ' Tests/CodeEditorSampleTests/ --include='*.swift'); do
    if ! grep -q '^@testable import CodeEditorSwiftUI' "$f"; then
        awk '
            /^import / && !done { print; lastImport=NR; next }
            /^@testable import / && !done { print; lastImport=NR; next }
            !lastImport { print; next }
            NR == lastImport+1 && !done { print "@testable import CodeEditorSwiftUI"; done=1 }
            { print }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
done
```

- [ ] **Step 10: Bulk-add `@testable import CodeEditorSwiftUI` to `CodeEditorUITests`**

Run:
```bash
for f in $(grep -rl '^import \|^@testable import ' Tests/CodeEditorUITests/ --include='*.swift'); do
    if ! grep -q '^@testable import CodeEditorSwiftUI' "$f"; then
        awk '
            /^import / && !done { print; lastImport=NR; next }
            /^@testable import / && !done { print; lastImport=NR; next }
            !lastImport { print; next }
            NR == lastImport+1 && !done { print "@testable import CodeEditorSwiftUI"; done=1 }
            { print }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
done
```

- [ ] **Step 11: Run `swiftlint --fix` to normalize import ordering**

Run:
```bash
swiftlint --fix 2>&1 | tail -10
```

Expected: `sorted_imports` reorders the inserted lines alphabetically across the 255 affected files. Output reports the number of corrections; should be a large count.

- [ ] **Step 12: Build and iterate on compile errors**

Run:
```bash
swift build 2>&1 | tail -40
```

Three possible outcomes:

**Outcome A — build succeeds.** Proceed to Step 13.

**Outcome B — "cannot find type X in scope" errors.** A file consumes a SwiftUI/-slice type but didn't get the import line. Most likely cause: bare-word grep over-narrow at audit time (per §6.2.8e lesson). Fix iteratively:
1. From the compile error, identify the file path.
2. Add `import CodeEditorSwiftUI` (or `@testable import CodeEditorSwiftUI` if it's a test file consuming internal symbols).
3. Re-run `swiftlint --fix` to normalize.
4. Re-run `swift build`. Repeat until clean.

Budget: 5–15 additional imports per §5.6 of the spec.

**Outcome C — `MainActor`-isolation / Sendable strict-concurrency errors on `CodeEditorBaseCoordinator`.** Per §4.3 of the spec and §6.2.12 precedent. Fix:
1. Open `Sources/CodeEditorSwiftUI/CodeEditor+CoordinatorsExtensions.swift`.
2. Try adding `@MainActor` to the `markClean(view:)` declaration (preferred). If that's already there or doesn't help, fall back to `@unchecked Sendable` on the `CodeEditorBaseCoordinator` class declaration.
3. Re-run `swift build`. Record which fix was needed for the deviations block in Task 7.

**Outcome D — synth-init / cross-target accessibility error on a public struct/actor.** Per §6.2.8c / §6.2.12c precedent. Fix:
1. Open the offending file (per the error location).
2. Add an explicit `public init()` (or `public init(...)` with the parameters matching the synthesized memberwise init).
3. Add a `///` doc comment if SwiftLint's `missing_docs` flags it (more likely on actor inits than struct inits per §6.2.12c).
4. Re-run `swift build`. Record in deviations.

**Outcome E — Package.swift target-dep error.** A consumer target references the new module but doesn't list it as a dep. Fix:
1. Add `"CodeEditorSwiftUI",` to that target's `dependencies:` array in `Package.swift`.
2. Re-run `swift build`.

Stay in this loop until `swift build` is clean. Do NOT commit yet.

- [ ] **Step 13: Lint clean**

Run:
```bash
swiftlint --fix && swiftlint 2>&1 | tail -3
```

Expected: `0 violations`.

If `missing_docs` violations appear, they're likely on any new `public init()` added in Step 12 (Outcome D). Add `///` doc comments per §6.2.12c lesson.

- [ ] **Step 14: Test green**

Run:
```bash
swift test --parallel 2>&1 | tail -20
```

Expected: all suites pass with at most the 1 pre-existing known issue noted at baseline (Task 1 Step 9). If new failures surface, investigate before committing.

- [ ] **Step 15: Stage and review the commit**

Run:
```bash
git status
```

Expected (high level):
- 17 renames `Sources/CodeEditorPlugin/SwiftUI/* → Sources/CodeEditorSwiftUI/*`
- 1 deleted `Sources/CodeEditorSwiftUI/_ScaffoldPlaceholder.swift`
- 1 modified `Package.swift`
- ~255 modified consumer files across `Sources/CodeEditorUI/`, `Sources/CodeEditorSample/`, `Tests/...`
- Possibly 1 modified file in `Sources/CodeEditorSwiftUI/` if Step 12 surfaced a `@unchecked Sendable` / promotion fix

Run a sanity check on the move:
```bash
git diff --stat HEAD | tail -5
```

Expected: the line count delta should be small (renames + import-line additions only; no large body changes).

Stage all the changes:
```bash
git add Package.swift \
        Sources/CodeEditorSwiftUI/ \
        Sources/CodeEditorPlugin/SwiftUI \
        Sources/CodeEditorUI/ \
        Sources/CodeEditorSample/ \
        Tests/CodeEditorPluginTests/ \
        Tests/CodeEditorSampleTests/ \
        Tests/CodeEditorUITests/
```

- [ ] **Step 16: Commit (Commit 2)**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract §6.2.13 CodeEditorSwiftUI target

Moves 17 files from umbrella SwiftUI/ to a new SPM target depending on
CodeEditorView (+ 11 other internal targets). Clean full extraction —
no carve-out residue. CodeEditorBaseCoordinator moves with the slice;
the §6.2.12 CodeEditorCoordinating package protocol handles the
cross-target conformance. Productized as .library + umbrella-coupled
(matches §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12 pattern).

Consumer ripple: ~15 source files in CodeEditorUI, ~58 in
CodeEditorSample, ~130 plugin tests, ~37 sample tests, ~15 UI tests
gained `import CodeEditorSwiftUI` (5 of those targets also gained the
new target as a direct Package.swift dep). Existing
`@testable import CodeEditorPlugin` / `CodeEditorView` kept defensively
per §6.2.8d lesson.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 17: Verify commit success**

Run:
```bash
git log -1 --format='%h %s'
git status
```

Expected: HEAD is the new commit; working tree clean.

---

### Task 4 (CONDITIONAL): Clean-build fix (Commit 3)

**Run this task only if `swift package clean && swift build` surfaces a transitive-dep masking bug.** Otherwise skip directly to Task 5.

The §6.2.12 commit `d0324a9` exists because incremental builds had masked a missing `CodeEditorPlatform` dep in `CodeEditorTextModel`. The clean-build slot is reserved for that class of bug.

- [ ] **Step 1: Clean rebuild**

Run:
```bash
swift package clean
swift build 2>&1 | tail -30
```

If output is `Build complete!`, **skip the rest of this task** — proceed to Task 5.

If errors appear (typically "cannot find module X" or "no such module Y"), continue.

- [ ] **Step 2: Identify the missing dep**

Read the error output. Most likely cause: a `.target(name: "X", dependencies: [...])` array in `Package.swift` is missing a `"CodeEditor<Other>"` entry that incremental builds had been picking up transitively from another consumer.

Common pattern (per §6.2.12 d0324a9 precedent):
- A file in target X has `import CodeEditorY`
- Target X's `dependencies:` doesn't list `CodeEditorY`
- Target X transitively reached Y through another dep that includes Y
- Clean build forces direct deps, exposing the gap

- [ ] **Step 3: Add the missing dep to Package.swift**

Add `"CodeEditor<Other>"` to the offending target's `dependencies:` array, maintaining alphabetical order.

- [ ] **Step 4: Verify clean build passes**

Run:
```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`.

- [ ] **Step 5: Run full tests to confirm no regression**

Run:
```bash
swift test --parallel 2>&1 | tail -10
```

Expected: green except the pre-existing known issue.

- [ ] **Step 6: Commit the fix**

Run:
```bash
git add Package.swift
git commit -m "$(cat <<'EOF'
Fix §6.2.13 clean-build transitive dep

Adds <missing dep description> to <target name>'s dependencies array.
Incremental builds had masked the gap because <Other> was reachable
through another transitive dep; clean rebuild surfaces it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Customize the commit-message body to match the actual missing dep.

---

### Task 5: End-of-chunk verification

**Files:** no edits.

- [ ] **Step 1: Final clean build**

Run:
```bash
swift package clean
swift build 2>&1 | tail -5
```

Expected: `Build complete!`.

- [ ] **Step 2: SwiftLint clean**

Run:
```bash
swiftlint --fix && swiftlint 2>&1 | tail -3
```

Expected: `0 violations`. Note: `swiftlint --fix` should report 0 corrections if nothing changed since Task 3 Step 13.

- [ ] **Step 3: Full parallel test run**

Run:
```bash
swift test --parallel 2>&1 | tail -20
```

Expected: 0 lint violations across ~826 files; all test suites pass with at most the 1 pre-existing known issue noted in the §6.2.12c / §6.2.8c verification logs.

Record the test count and known-issue name in the conversation. They'll go in the §6.2.13 deviations block in Task 7.

- [ ] **Step 4: Sample-app manual smoke test (per `project_nstextview_init_invariant.md`)**

Kill any stale sample / lldb processes first (per `feedback_process_hygiene.md`):

```bash
pkill -f CodeEditorSample 2>/dev/null
pkill -f lldb 2>/dev/null
true
```

Launch the sample (prefer release build for cleaner startup):

```bash
swift run --configuration release CodeEditorSample &
```

Manual checks:
1. The window appears with the native NSWindow chrome (no embedded `EditorTitleBar` per `feedback_sample_window_chrome.md`).
2. Open a file from the sample's workspace.
3. Click into the editor.
4. Type a character — it appears immediately. (This is the canary for the NSTextView init invariant.)
5. Press Return / arrow keys / Cmd+Z — text editing still works.
6. Open a different language file (e.g. `.json`, `.md`) — syntax highlighting still applies.

If typing silently fails, the §6.2.13 move has regressed the SwiftUI Representable wrapper. Stop, investigate via `lldb` attach, and revert/fix before continuing.

Kill the sample when done:
```bash
pkill -f CodeEditorSample
```

- [ ] **Step 5: Record verification summary**

Write in the conversation:
- Clean build: green/red
- SwiftLint: 0 violations / count
- Test run: X tests in Y suites passed; Z known issues
- Sample-app smoke test: typing works / regressed
- Number of commits in this chunk: 2 or 3

---

### Task 6: Update `NEXT.md`

**Files:**
- Modify: `NEXT.md` (status table row in §6.0, §6.2.13 deviations subsection, §6.2.13 bullet flip in §6.2, §10 cleanup)

- [ ] **Step 1: Add status-table row to §6.0**

Open `NEXT.md`. Find the status table in §6.0 (begins around line 251, last row is `CodeEditorSmartEditing` at line ~273). Append a new row at the bottom of the table:

```markdown
| `CodeEditorSwiftUI` | `<commit-2>` (scaffold `<commit-1>`; clean-build fix `<commit-3>` if any) | 17 files moved cleanly from umbrella `SwiftUI/` to new target. Clean full extraction — no carve-out. CodeEditorBaseCoordinator (open class) moves with the slice; §6.2.12 CodeEditorCoordinating package protocol handles cross-target conformance unchanged. Productized as `.library`; umbrella DOES depend on it (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout / §6.2.12 View precedent). Consumer ripple: ~15 CodeEditorUI + ~58 CodeEditorSample + ~130 plugin-test + ~37 sample-test + ~15 UI-test files gained imports. 5 Package.swift target-dep additions (CodeEditorUI, CodeEditorSample, CodeEditorPluginTests, CodeEditorSampleTests, CodeEditorUITests). `Sources/CodeEditorPlugin/SwiftUI/` directory deleted. | Annotations, Common, Completion, Configuration, Diagnostics, Languages, Layout, LSP, Platform, TextModel, Theming, View |
```

Replace `<commit-2>` with the actual hash from `git log` of the bulk-move commit (Task 3 Step 17). Include `<commit-1>` (scaffold) and `<commit-3>` (clean-build fix) parenthetically.

Update the actual consumer ripple counts from Task 5 Step 5.

- [ ] **Step 2: Update §6.0 status summary sentence**

Find the paragraph beginning "Phases 0–5 done; phases 7–8 carved out; §6.2.8 feature engines closed." (around line 249). Two edits:

1. Append a new sentence after the §6.2.8c sentence (before "Thirteen new SPM targets now exist..."):

```
Then `CodeEditorSwiftUI` (§6.2.13) extracted the SwiftUI slice — 17 files moved cleanly, leaving only `CodeEditorPlugin.swift` + `Languages/` (own target via `path:`) + `Resources/` in the umbrella.
```

2. Replace the existing count phrase "Thirteen new SPM targets now exist alongside the existing `CodeEditorDesignTokens` / `CodeEditorPlugin` / `CodeEditorUI` / `CodeEditorSample`" with:

```
Fourteen new SPM targets now exist alongside the existing `CodeEditorDesignTokens` / `CodeEditorPlugin` / `CodeEditorUI` / `CodeEditorSample`
```

(Adjust the count phrasing if the §6.2.8c documentation commit already used a different number — verify via `grep -nE 'new SPM target' NEXT.md` before editing.)

- [ ] **Step 3: Add the §6.2.13 deviations subsection**

After the existing "Deviations during §6.2.8c `CodeEditorSmartEditing` (...)" subsection (it's the most recent), append:

```markdown
**Deviations during §6.2.13 `CodeEditorSwiftUI` (commit `<commit-2>`, scaffold `<commit-1>`, clean-build fix `<commit-3>` if any):**

- **Clean full extraction — no carve-out.** Fourth such extraction after §6.2.8f Workspace, §6.2.8g Completion, §6.2.8c SmartEditing, and §6.2.12 CodeEditorView. All 17 files moved; zero `Core/SwiftUI/` residue. `SwiftUI/` subfolder flattened at destination per the target-name-is-the-namespace convention.
- **CodeEditorBaseCoordinator cross-target conformance worked unmodified.** The §6.2.12 `CodeEditorCoordinating` package protocol was specifically introduced to enable this hand-off. `markClean(view:)` stayed `package`-visible on the conformer; protocol stayed `package` in CodeEditorView. No promotion or annotation needed. (If `@MainActor` / `@unchecked Sendable` was required during execution per §4.3 of the spec, record specifics here.)
- **§4.1 dep claim correction.** NEXT.md §4.1 listed `CodeEditorSwiftUI → the Editor target`. Actual: 12 internal deps spanning phase 0 (Common, Platform) through phase 8 (View). Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12 §4.1-correction pattern.
- **Productized + umbrella-coupled.** New `.library(name: "CodeEditorSwiftUI", targets: ["CodeEditorSwiftUI"])` product. Umbrella `CodeEditorPlugin` gains `CodeEditorSwiftUI` as direct dep. Matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout / §6.2.12 View precedent. Public API surface of `import CodeEditorPlugin` is unchanged.
- **Access-modifier promotion count: 0 (baseline) + X (execution-surprise).** Spec baseline was 0; record actual count from Task 3 Step 12 here, including any `public init()` additions or `@unchecked Sendable` annotations.
- **Consumer ripple count: ~255 total** (largest in the restructure series). Per-target: <CodeEditorUI count> CodeEditorUI + <Sample count> CodeEditorSample + <PluginTests count> plugin tests + <SampleTests count> sample tests + <UITests count> UI tests. 5 Package.swift target-dep additions.
- **Bare-word grep under-count caveat held.** Spec budgeted 5–15 additional consumer files surfacing during compile-error iteration; actual count: <fill in from Task 3 Step 12>.
- **`Sources/CodeEditorPlugin/SwiftUI/` directory deleted.** Umbrella source tree now retains only `CodeEditorPlugin.swift` (91 LOC root), `Languages/` (own SPM target via `path:`), and `Resources/Info.plist`. The single sizable carve-out remaining is the §6.2.14 umbrella re-export and the §6.2.15 test-support split.
- **Commit count: 2 (or 3 if clean-build fix landed).** Matches the spec's per-commit gating.
- **End-of-chunk verification clean.** `swift package clean && swift build && swiftlint --fix && swiftlint && swift test --parallel` all green: 0 lint violations across ~<file count> files, <test count> tests in <suite count> suites passed with <known-issue count> pre-existing known issue(s).
- **Sample-app manual verification: <pass/fail>.** Typing works, syntax highlighting applies, native NSWindow chrome intact (no embedded `EditorTitleBar` regression).
- **Closes §6.2.13.** Remaining restructure work per §10: §6.2.14 umbrella re-export, §6.2.15 CodeEditorTestSupport, move to `~/Workspace/packages/`.
```

Fill in every `<placeholder>` with the actual value captured during Tasks 3–5.

- [ ] **Step 4: Flip the §6.2.13 bullet in §6.2 (or §6.2 sub-bullets)**

Find the §6.2 step 13 entry in NEXT.md (line ~669):
```
13. **Extract `CodeEditorSwiftUI`** — move `SwiftUI/`. Depends on the editor-surface target.
```

Replace with:
```
13. **[done — clean extraction, see §6.0]** **Extract `CodeEditorSwiftUI`** (§6.2.13) — 17 files moved cleanly from `Sources/CodeEditorPlugin/SwiftUI/` to `Sources/CodeEditorSwiftUI/`. CodeEditorBaseCoordinator (open class) moves with the slice; §6.2.12 CodeEditorCoordinating package protocol handles cross-target conformance unchanged. Productized as `.library`; umbrella DOES depend on it. Final deps: `Annotations, Common, Completion, Configuration, Diagnostics, Languages, Layout, LSP, Platform, TextModel, Theming, View`. (`<commit-2>` + scaffold `<commit-1>`)
```

- [ ] **Step 5: Drop the §6.2.13 bullet from §10 "Suggested next session"**

In §10 (around line 719), the current first remaining-work bullet is:
```
- **6.2.13 `CodeEditorSwiftUI`** — extract `Sources/CodeEditorPlugin/SwiftUI/` (17 files) to a new SPM target depending on `CodeEditorView`. Straightforward — the slice's existing imports are mostly correct post-§6.2.12. Will need careful handling of `CodeEditorBaseCoordinator` (currently umbrella-resident; conforms to `CodeEditorCoordinating` in CodeEditorView).
```

Delete that entire bullet. The remaining §10 bullets (§6.2.14, §6.2.15, move to `~/Workspace/packages/`) stay.

Also update the opening sentence of §10. Current:
```
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8c, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, 6.2.11, §6.2.12a/b/c (prep), and §6.2.12 (main Core/ split) are done (see §6.0). Remaining work:
```

Change to:
```
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8c, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, 6.2.11, §6.2.12a/b/c (prep), §6.2.12 (main Core/ split), and §6.2.13 are done (see §6.0). Remaining work:
```

- [ ] **Step 6: Verify NEXT.md edits coherent**

Run:
```bash
git diff NEXT.md | head -150
```

Inspect:
- No accidental edits to unrelated sections.
- Every `<commit>` / `<count>` placeholder is filled with actual values.
- Internal cross-references (§6.0, §6.2, §10) still resolve.
- Markdown table syntax for the new §6.0 row is valid (pipe count matches header).

---

### Task 7: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` (source tree summary, "Other source roots" list, "What Will Go Wrong" with any new caveats)

- [ ] **Step 1: Update source-tree summary**

Open `CLAUDE.md`. Find the `Sources/CodeEditorPlugin/` tree block:

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (becomes the @_exported import file in §6.2.14)
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Resources/               # Info.plist
└── SwiftUI/                 # SwiftUI wrappers and modifiers (extracts to CodeEditorSwiftUI in §6.2.13)
```

Delete the `SwiftUI/` line. Result:

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (becomes the @_exported import file in §6.2.14)
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
└── Resources/               # Info.plist
```

- [ ] **Step 2: Update umbrella file-count sentence**

Find the paragraph beginning "2 top-level directories in the umbrella target..." (post-§6.2.8c phrasing) or "3 top-level directories..." (older phrasing). Update to:

```
1 top-level directory in the umbrella target (`Languages/` — own SPM target via `path:` — plus `Resources/` for `Info.plist`) and 1 Swift source file in the umbrella target (`CodeEditorPlugin.swift`; `Languages/` is its own SPM target via `path:`). Down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8c / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a/b/c / §6.2.12 / §6.2.13. Total Swift source files under `Sources/`: ~<count>.
```

Verify the file count:
```bash
find Sources -name '*.swift' | wc -l
```

Use that number in place of `<count>`. Expected delta from §6.2.8c's "~586" is net-zero on `Sources/` totals (the 17 files relocate but don't disappear) — so ~586.

- [ ] **Step 3: Add `Sources/CodeEditorSwiftUI/` to "Other source roots"**

In the "Other source roots" list, insert a new bullet in alphabetical position (between `Sources/CodeEditorSmartEditing/` and `Sources/CodeEditorSymbols/` — verify alphabetical: `Smart` < `SwiftUI` < `Symbols`):

```
- `Sources/CodeEditorSwiftUI/` — SwiftUI host wrapper + Representable bridge: `CodeEditor` (struct), `EditorController` (class), `CodeEditorBaseCoordinator` (open class, conforms to `CodeEditorCoordinating` package protocol in `CodeEditorView`), `CodeEditorIntent`, `CodeEditorEnvironment`, `CodeEditorPlatformAdapter`, `CodeEditorRepresentableHelper`, `EditorState+Environment` reader, plus `CodeEditor+*` / `EditorController+*` slice extensions. 17 files (phase 9; new in §6.2.13). Productized as `.library`; umbrella `CodeEditorPlugin` depends on it (matches §6.2.9 LSP / §6.2.10 Diagnostics / §6.2.11 Layout / §6.2.12 View precedent — productized + umbrella-coupled).
```

- [ ] **Step 4: Update "What Will Go Wrong" section if execution surfaced any new caveats**

If Task 3 Step 12 surfaced any `@MainActor` / `@unchecked Sendable` / synth-init / promotion issues that future contributors should know about, add a one-line note to `CLAUDE.md`'s "What Will Go Wrong" section. Examples (only add if encountered):

- "`CodeEditorBaseCoordinator` requires `@MainActor` on `markClean(view:)` for cross-module strict-concurrency. Same pattern as `CodeEditorView`'s `@unchecked Sendable` from §6.2.12."
- "`CodeEditor` (the SwiftUI struct) now lives in `CodeEditorSwiftUI` target, not the umbrella's SwiftUI/ slice. External consumers doing `import CodeEditorPlugin` continue to see it via the umbrella's transitive dep on `CodeEditorSwiftUI`."

If nothing surfaced, skip this step.

- [ ] **Step 5: Verify CLAUDE.md edits coherent**

Run:
```bash
git diff CLAUDE.md | head -80
```

Inspect: no accidental edits, source-tree section + "Other source roots" both updated, file count matches `find` output.

- [ ] **Step 6: Commit the docs (Commit 3 or 4)**

Run:
```bash
git add NEXT.md CLAUDE.md
git commit -m "$(cat <<'EOF'
Document §6.2.13 CodeEditorSwiftUI extraction in NEXT.md and CLAUDE.md

Adds §6.0 status-table row + §6.2.13 deviations subsection, flips §6.2
step 13 to done, removes §10 remaining-work bullet. CLAUDE.md gains
the Sources/CodeEditorSwiftUI/ bullet under "Other source roots" and
drops the SwiftUI/ line from the umbrella source-tree summary. The
umbrella now retains only CodeEditorPlugin.swift, Languages/ (own SPM
target via path:), and Resources/Info.plist.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Final sanity check**

Run:
```bash
git log --oneline -5
git status
```

Expected (assuming Task 4 did NOT run):
- HEAD~0: "Document §6.2.13 CodeEditorSwiftUI extraction in NEXT.md and CLAUDE.md"
- HEAD~1: "Extract §6.2.13 CodeEditorSwiftUI target"
- HEAD~2: "Scaffold §6.2.13 CodeEditorSwiftUI target"
- HEAD~3: "Spec §6.2.13 CodeEditorSwiftUI extraction"
- Working tree clean.

If Task 4 ran:
- HEAD~0: "Document §6.2.13 CodeEditorSwiftUI extraction in NEXT.md and CLAUDE.md"
- HEAD~1: "Fix §6.2.13 clean-build transitive dep"
- HEAD~2: "Extract §6.2.13 CodeEditorSwiftUI target"
- HEAD~3: "Scaffold §6.2.13 CodeEditorSwiftUI target"
- HEAD~4: "Spec §6.2.13 CodeEditorSwiftUI extraction"

Per the project memory **"Default to working on main"**, do NOT push to the remote unless the user explicitly asks.

---

## Done

This plan implements the spec at `docs/superpowers/specs/2026-05-18-codeeditor-swiftui-extraction-design.md` (commit `25ced6e`) end-to-end. Net result:

- 3 or 4 new commits on top of the spec commit.
- `Sources/CodeEditorSwiftUI/` exists as a new SPM target with 17 files + a new `.library` product.
- Umbrella source tree shrinks from `CodeEditorPlugin.swift` + `Languages/` + `Resources/` + `SwiftUI/` to just the first three. The umbrella retains its 17 dep edges into the layered targets, now with `CodeEditorSwiftUI` added.
- 255 consumer files across 5 targets gain `import CodeEditorSwiftUI` (or `@testable import CodeEditorSwiftUI` for tests).
- Public API surface of `import CodeEditorPlugin` is unchanged.

The next chunks (§6.2.14 umbrella re-export, §6.2.15 CodeEditorTestSupport) are now unblocked. §6.2.14 will hard-wire `@_exported import CodeEditorSwiftUI` (and the rest of the layered targets) into `CodeEditorPlugin.swift`, reducing the umbrella body to a single file of re-export declarations.
