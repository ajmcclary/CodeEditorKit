# CodeEditorSymbols Extraction (§6.2.8b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a new `CodeEditorSymbols` SPM target containing 2 pure files from `Features/` (`SymbolNavigationTypes`, `SymbolProviderCatalog`) plus a split-out `SymbolRangeIndex` file; relocate the 1 `CodeEditorView`-coupled file (`SymbolNavigator`) inside the umbrella to `Core/Symbols/`.

**Architecture:** Carve-out extraction matching §6.2.8a (Folding) exactly. Pure leaf files move to a new sibling target; umbrella-coupled glue is relocated under `Core/Symbols/` to mark the F3 bucket explicitly. `SymbolRangeIndex<Value>` — a generic interval-tree storage type currently bundled with `SymbolProviderCatalog.swift` — splits into its own file mid-extraction, mirroring §6.2.7's `RangeQueryParser` extraction. Two commits — pre-relocation (Task 3) and main extraction (Task 11) — mirroring §6.2.8a's `9704e80b` → `76abf928` sequence.

**Tech Stack:** Swift 6.3 SPM package, `StrictConcurrency` enabled. New target depends on `CodeEditorLanguages`, `CodeEditorSyntaxHighlighting`. No new third-party deps.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-symbols-extraction-design.md` (commit `e6047280`).

---

### Task 1: Pre-flight audit

**Files:**
- Read-only: no edits in this task.

- [ ] **Step 1: Confirm carry-set (3 files in `Features/`) is unchanged since spec**

Run:
```bash
ls -1 Sources/CodeEditorPlugin/Features/{SymbolNavigationTypes,SymbolProviderCatalog,SymbolNavigator}.swift
```
Expected: all 3 paths print with no error.

- [ ] **Step 2: Confirm no Sample/UI/SampleTests direct dependency on the moving types**

Run:
```bash
grep -rln -E "SymbolNavigationConfiguration|BreadcrumbItem\b|SymbolProviderCatalog|SymbolRangeIndex" Sources/CodeEditorSample Sources/CodeEditorUI Tests/CodeEditorSampleTests Tests/CodeEditorUITests Tests/CodeEditorDesignTokensTests 2>/dev/null
```
Expected: no output. If output appears, capture the file list — those targets will need `CodeEditorSymbols` added as a dependency in Task 2.

- [ ] **Step 3: Enumerate exact umbrella + test consumer files (used in Task 6)**

Run:
```bash
grep -rln -E "SymbolNavigationConfiguration|BreadcrumbItem\b|SymbolProviderCatalog|SymbolRangeIndex" Sources/CodeEditorPlugin Tests/CodeEditorPluginTests | sort -u
```
Expected: a small list. The 3 source files in `Sources/CodeEditorPlugin/Features/` that are about to move (or split) appear in this list — ignore them. The remaining entries are the import targets for Task 6. Pre-survey expectation: `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift` (which will relocate in Task 3) and `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift` — that's it. Save this list verbatim.

- [ ] **Step 4: Capture baseline test pass count**

Run:
```bash
swift test --filter FeatureBehavior 2>&1 | tail -5
swift test --filter SymbolNavigator 2>&1 | tail -5
swift test --filter ComprehensivePerformance 2>&1 | tail -5
swift test --filter PerformanceRegression 2>&1 | tail -5
swift test --filter ReviewRemediationRegression 2>&1 | tail -5
```
Expected: each prints pass count. Note them in a scratch buffer; Task 8 will verify identical counts.

- [ ] **Step 5: Verify clean working tree**

Run:
```bash
git status --short
```
Expected: no output (clean tree). If there are uncommitted changes, stop and ask the user.

---

### Task 2: Scaffold the `CodeEditorSymbols` target

**Files:**
- Create: `Sources/CodeEditorSymbols/.gitkeep`
- Modify: `Package.swift`

- [ ] **Step 1: Create the new source root with a placeholder**

Run:
```bash
mkdir -p Sources/CodeEditorSymbols
touch Sources/CodeEditorSymbols/.gitkeep
```

- [ ] **Step 2: Add the target stanza to `Package.swift`**

Open `Package.swift`. Locate the `CodeEditorFolding` target stanza. Immediately after it (and before the `CodeEditorPlugin` umbrella target stanza), insert:

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

- [ ] **Step 3: Add the dependency to `CodeEditorPlugin` umbrella target**

In `Package.swift`, locate the `CodeEditorPlugin` target stanza. In its `dependencies:` array, insert `"CodeEditorSymbols"` alphabetically — between `"CodeEditorPlatform"` and `"CodeEditorSyntaxHighlighting"`. The order after insertion should read:

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
            ...
```

- [ ] **Step 4: Add the dependency to `CodeEditorPluginTests` target**

In `Package.swift`, locate the `CodeEditorPluginTests` test target stanza. Add `"CodeEditorSymbols"` alphabetically to its `dependencies:` array (between `"CodeEditorPlatform"` and `"CodeEditorSyntaxHighlighting"` if those are present, or otherwise between `"CodeEditorFolding"` and `"CodeEditorSyntaxHighlighting"`).

- [ ] **Step 5: If Step 2 of Task 1 found Sample/UI/SampleTests references, add the dep there too**

If `CodeEditorSample` was in the output from Task 1 Step 2, add `"CodeEditorSymbols"` to its `dependencies:` array alphabetically.

If `CodeEditorUI` was in the output, do the same for the `CodeEditorUI` target.

If any test target (`CodeEditorSampleTests`, `CodeEditorUITests`, `CodeEditorDesignTokensTests`) was in the output, do the same for that target.

Otherwise (the expected case), skip this step.

- [ ] **Step 6: Verify build is green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!` and no errors. The new target has only the `.gitkeep` so SPM compiles it as an empty module.

- [ ] **Step 7: No commit yet**

This task's edits bundle with Task 3 into a single pre-relocation commit. Do not commit here.

---

### Task 3: Pre-relocation commit — move `SymbolNavigator` to `Core/Symbols/`

Mirrors §6.2.8a's `9704e80b`. After this task, `SymbolNavigator.swift` still lives in the umbrella target; only its path changes. The 2 pure files and the not-yet-split `SymbolRangeIndex` stay in `Features/` until Tasks 4–5.

**Files:**
- Create directory: `Sources/CodeEditorPlugin/Core/Symbols/`
- Move (git mv): 1 file from `Sources/CodeEditorPlugin/Features/` → `Sources/CodeEditorPlugin/Core/Symbols/`

- [ ] **Step 1: Create the `Core/Symbols/` directory**

Run:
```bash
mkdir -p Sources/CodeEditorPlugin/Core/Symbols
```

- [ ] **Step 2: `git mv` the 1 coupled file**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/SymbolNavigator.swift \
       Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift
```

- [ ] **Step 3: Verify build is still green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!`. The file is still in the umbrella target; only its path changed.

- [ ] **Step 4: Verify targeted tests still pass**

Run:
```bash
swift test --filter FeatureBehavior 2>&1 | tail -3
swift test --filter SymbolNavigator 2>&1 | tail -3
```
Expected: same pass counts as Task 1 Step 4.

- [ ] **Step 5: Commit the relocation (bundles Task 2 scaffold + this relocation)**

Run:
```bash
git add Sources/CodeEditorPlugin/Core/Symbols \
        Sources/CodeEditorPlugin/Features \
        Sources/CodeEditorSymbols \
        Package.swift
git commit -m "$(cat <<'EOF'
Relocate umbrella-coupled SymbolNavigator to Core/Symbols/

SymbolNavigator moves from Features/ to Core/Symbols/ as
the explicit "umbrella-coupled symbol glue" sub-bucket.
Mirrors §6.2.8a's Core/Folding/ relocation in 9704e80b
and §6.2.7's Core/SyntaxHighlighting/ in 818df5f6.

Also scaffolds the CodeEditorSymbols target stanza in
Package.swift with an empty source root (placeholder
.gitkeep). Subsequent commit splits SymbolRangeIndex out
of SymbolProviderCatalog and moves the 3 pure files into
the new target.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Verify commit landed cleanly**

Run:
```bash
git log -1 --stat | head -15
```
Expected: 3 file changes (1 rename + Package.swift + `.gitkeep`), no other files touched.

---

### Task 4: Split `SymbolRangeIndex` into its own file

Carve `SymbolRangeIndex<Value>` (currently at lines 66–127 of `SymbolProviderCatalog.swift`) into a new file in the umbrella `Features/` directory. Both files stay in the umbrella for the duration of this task, so the build remains green. Task 5 moves both into the new target.

**Files:**
- Create: `Sources/CodeEditorPlugin/Features/SymbolRangeIndex.swift`
- Modify: `Sources/CodeEditorPlugin/Features/SymbolProviderCatalog.swift`

- [ ] **Step 1: Read the current `SymbolProviderCatalog.swift` to capture the section to split**

Run:
```bash
sed -n '63,127p' Sources/CodeEditorPlugin/Features/SymbolProviderCatalog.swift
```
Expected output: the trailing `final class SymbolRangeIndex<Value>` declaration with its private `Node` class and helper methods. (Use the lower bound `63` to grab the blank line before the class so the cut is clean.)

- [ ] **Step 2: Create `Features/SymbolRangeIndex.swift` with the carved-out type**

Create `Sources/CodeEditorPlugin/Features/SymbolRangeIndex.swift` with this exact content (verbatim copy from `SymbolProviderCatalog.swift` plus the `Foundation` import):

```swift
import Foundation

final class SymbolRangeIndex<Value> {
    private final class Node {
        let range: NSRange
        let value: Value
        var maxUpperBound: Int
        var left: Node?
        var right: Node?

        init(range: NSRange, value: Value) {
            self.range = range
            self.value = value
            self.maxUpperBound = NSMaxRange(range)
        }
    }

    private var root: Node?

    func insert(range: NSRange, value: Value) {
        root = insert(range: range, value: value, into: root)
    }

    func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    func removeAll() {
        root = nil
    }

    private func insert(range: NSRange, value: Value, into node: Node?) -> Node {
        guard let node else {
            return Node(range: range, value: value)
        }

        if range.location < node.range.location {
            node.left = insert(range: range, value: value, into: node.left)
        } else {
            node.right = insert(range: range, value: value, into: node.right)
        }

        node.maxUpperBound = max(node.maxUpperBound, NSMaxRange(range))
        return node
    }

    private func findContaining(location: Int, in node: Node?, results: inout [Value]) {
        guard let node else { return }

        if let left = node.left, left.maxUpperBound >= location {
            findContaining(location: location, in: left, results: &results)
        }

        if node.range.location <= location, location <= NSMaxRange(node.range) {
            results.append(node.value)
        }

        if location >= node.range.location {
            findContaining(location: location, in: node.right, results: &results)
        }
    }
}
```

Modifiers remain `internal` (no modifier = `internal`) at this point — promotions to `package` happen in Task 7, after the file has moved into the new target.

- [ ] **Step 3: Trim `SymbolRangeIndex` out of `SymbolProviderCatalog.swift`**

Use `Edit` to remove the trailing section of `Sources/CodeEditorPlugin/Features/SymbolProviderCatalog.swift`. The exact `old_string` to remove:

```swift
private struct EmptySymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in _: String) async -> [DocumentSymbol] {
        []
    }
}

final class SymbolRangeIndex<Value> {
    private final class Node {
        let range: NSRange
        let value: Value
        var maxUpperBound: Int
        var left: Node?
        var right: Node?

        init(range: NSRange, value: Value) {
            self.range = range
            self.value = value
            self.maxUpperBound = NSMaxRange(range)
        }
    }

    private var root: Node?

    func insert(range: NSRange, value: Value) {
        root = insert(range: range, value: value, into: root)
    }

    func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    func removeAll() {
        root = nil
    }

    private func insert(range: NSRange, value: Value, into node: Node?) -> Node {
        guard let node else {
            return Node(range: range, value: value)
        }

        if range.location < node.range.location {
            node.left = insert(range: range, value: value, into: node.left)
        } else {
            node.right = insert(range: range, value: value, into: node.right)
        }

        node.maxUpperBound = max(node.maxUpperBound, NSMaxRange(range))
        return node
    }

    private func findContaining(location: Int, in node: Node?, results: inout [Value]) {
        guard let node else { return }

        if let left = node.left, left.maxUpperBound >= location {
            findContaining(location: location, in: left, results: &results)
        }

        if node.range.location <= location, location <= NSMaxRange(node.range) {
            results.append(node.value)
        }

        if location >= node.range.location {
            findContaining(location: location, in: node.right, results: &results)
        }
    }
}
```

Replace with this `new_string` (the `EmptySymbolProvider` block preserved, the `SymbolRangeIndex` block removed):

```swift
private struct EmptySymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in _: String) async -> [DocumentSymbol] {
        []
    }
}
```

After the edit, the file's last lines should be the closing `}` of `EmptySymbolProvider` followed by a final newline. No trailing `SymbolRangeIndex`.

- [ ] **Step 4: Verify build is still green**

Run:
```bash
swift build 2>&1 | tail -20
```
Expected: `Build complete!`. Both files are in the umbrella; `SymbolNavigator` (also in umbrella, now at `Core/Symbols/`) still resolves `SymbolRangeIndex<DocumentSymbol>` because both files compile into the same module.

- [ ] **Step 5: No commit yet**

The split bundles into the main extraction commit (Task 11). Do not commit here.

---

### Task 5: Move the 3 pure files into `Sources/CodeEditorSymbols/`

After this task, the build is RED — the relocated `SymbolNavigator.swift` in `Core/Symbols/` references types that are now in a separate module. Tasks 6–7 restore green.

**Files:**
- Delete: `Sources/CodeEditorSymbols/.gitkeep`
- Move (git mv): 3 files from `Sources/CodeEditorPlugin/Features/` → `Sources/CodeEditorSymbols/`

- [ ] **Step 1: Delete the scaffold placeholder**

Run:
```bash
rm Sources/CodeEditorSymbols/.gitkeep
```

- [ ] **Step 2: `git mv` the 3 pure files**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift  Sources/CodeEditorSymbols/
git mv Sources/CodeEditorPlugin/Features/SymbolProviderCatalog.swift  Sources/CodeEditorSymbols/
git mv Sources/CodeEditorPlugin/Features/SymbolRangeIndex.swift       Sources/CodeEditorSymbols/
```

- [ ] **Step 3: Build to capture the error wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```
Expected: build FAILS. Likely errors:
- `cannot find 'SymbolRangeIndex' in scope` in `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`
- `cannot find 'SymbolProviderCatalog' in scope` in `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`
- `cannot find 'SymbolProviderCatalog' in scope` in `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

These are expected — Task 6 fixes them.

Capture the exact file paths flagged in the errors. They should match the list captured in Task 1 Step 3.

---

### Task 6: Add `import CodeEditorSymbols` to umbrella + test callers

**Files:** based on Task 1 Step 3 + Task 5 Step 3 outputs. Expected list (verified during Task 1):

- `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`
- `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`

If Task 1 Step 3 surfaced any other files, include them.

- [ ] **Step 1: Add `import CodeEditorSymbols` to `SymbolNavigator.swift`**

Open `Sources/CodeEditorPlugin/Core/Symbols/SymbolNavigator.swift`. Its current import block reads:

```swift
import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
```

Use `Edit` to replace that block with:

```swift
import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorSymbols
import CodeEditorTextModel
import Foundation
```

- [ ] **Step 2: Add `import CodeEditorSymbols` to `FeatureBehaviorTests.swift`**

Open `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift`. Its current import block (verified during brainstorming) reads:

```swift
import CodeEditorConfiguration
import CodeEditorFolding
import CodeEditorLanguages
import CodeEditorPlatform
...
import CodeEditorTextModel
import XCTest
```

(The middle `...` rows include `@testable import CodeEditorPlugin` and possibly other modules — re-read the file to confirm the exact block.)

Use `Edit` to insert `import CodeEditorSymbols` alphabetically. After `import CodeEditorPlatform` and before the next module (e.g., `import CodeEditorTextModel` or `@testable import CodeEditorPlugin`, whichever is alphabetically next).

If the file uses a single import block with mixed alphabetization, preserve the existing pattern and insert in the correct alphabetical slot.

- [ ] **Step 3: Build to capture the next error wavefront**

Run:
```bash
swift build 2>&1 | tail -60
```
Expected: build still FAILS, but errors now shift to access-level errors of the form `'SymbolRangeIndex' is inaccessible due to 'internal' protection level`. Task 7 promotes the relevant members.

If you see lingering `cannot find` errors, return to Step 1 or Step 2 for the file that flagged them — likely a missed import.

---

### Task 7: Promote access modifiers (`internal` → `package`)

All 5 promotions live in `Sources/CodeEditorSymbols/SymbolRangeIndex.swift`. None of the other 2 files in the new target need promotions — they are already `public` where they cross the boundary.

**Files:**
- Modify: `Sources/CodeEditorSymbols/SymbolRangeIndex.swift`

- [ ] **Step 1: Promote `SymbolRangeIndex` class declaration**

Open `Sources/CodeEditorSymbols/SymbolRangeIndex.swift`. Use `Edit` to change:

```swift
final class SymbolRangeIndex<Value> {
```

to:

```swift
package final class SymbolRangeIndex<Value> {
```

- [ ] **Step 2: Promote `SymbolRangeIndex`'s synthesised init**

`SymbolRangeIndex` has no explicit `init()` — Swift synthesises one. Add an explicit `package init()` immediately after the `private var root: Node?` line. Use `Edit` to change:

```swift
    private var root: Node?

    func insert(range: NSRange, value: Value) {
```

to:

```swift
    private var root: Node?

    package init() {}

    package func insert(range: NSRange, value: Value) {
```

(This both adds the init and promotes the first public method — see Step 3 for the remaining methods.)

- [ ] **Step 3: Promote `findContaining(location:)` and `removeAll()`**

Use `Edit` to change:

```swift
    func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    func removeAll() {
        root = nil
    }
```

to:

```swift
    package func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    package func removeAll() {
        root = nil
    }
```

- [ ] **Step 4: Leave private helpers UNCHANGED**

Verify by reading the file: the nested `private final class Node` and the two `private func` overloads (`insert(range:value:into:)`, `findContaining(location:in:results:)`) keep their `private` modifier. They are leaf helpers used only by `SymbolRangeIndex` itself.

After all promotions, the file's class declaration block should read:

```swift
package final class SymbolRangeIndex<Value> {
    private final class Node {
        // ...unchanged...
    }

    private var root: Node?

    package init() {}

    package func insert(range: NSRange, value: Value) {
        root = insert(range: range, value: value, into: root)
    }

    package func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    package func removeAll() {
        root = nil
    }

    private func insert(range: NSRange, value: Value, into node: Node?) -> Node {
        // ...unchanged...
    }

    private func findContaining(location: Int, in node: Node?, results: inout [Value]) {
        // ...unchanged...
    }
}
```

- [ ] **Step 5: Build until green**

Run:
```bash
swift build 2>&1 | tail -60
```

If the build still FAILS with access-level errors, the failing line shows the exact symbol. Promote it in its file and re-run. Expect at most 1 iteration — the promotion surface is tiny.

When it returns `Build complete!`, proceed.

---

### Task 8: Verification

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
swift test --filter FeatureBehavior 2>&1 | tail -5
swift test --filter SymbolNavigator 2>&1 | tail -5
swift test --filter ComprehensivePerformance 2>&1 | tail -5
swift test --filter PerformanceRegression 2>&1 | tail -5
swift test --filter ReviewRemediationRegression 2>&1 | tail -5
```
Expected: pass counts match the baseline captured in Task 1 Step 4. No new failures, no test count regressions.

- [ ] **Step 3: Build the sample app**

Run:
```bash
swift build --target CodeEditorSample 2>&1 | tail -10
```
Expected: `Build complete!`.

- [ ] **Step 4: Verify file layout**

Run:
```bash
ls -1 Sources/CodeEditorSymbols/
ls -1 Sources/CodeEditorPlugin/Core/Symbols/
ls -1 Sources/CodeEditorPlugin/Features/ | grep -i "Symbol" || echo "(no Symbol files in Features/ — correct)"
```
Expected:
- `Sources/CodeEditorSymbols/` contains exactly 3 files: `SymbolNavigationTypes.swift`, `SymbolProviderCatalog.swift`, `SymbolRangeIndex.swift`. No `.gitkeep`.
- `Sources/CodeEditorPlugin/Core/Symbols/` contains exactly 1 file: `SymbolNavigator.swift`.
- `Features/` no longer has any `Symbol*` files.

---

### Task 9: Sample app smoke (manual)

**Files:** none modified. This is the only manual gate in the plan.

- [ ] **Step 1: Launch the sample app**

Run:
```bash
swift run CodeEditorSample
```

- [ ] **Step 2: Open a Swift source file**

In the sample app, open any Swift file with multiple symbols (e.g., `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`). Verify syntax highlighting renders and the gutter shows line numbers.

- [ ] **Step 3: Exercise the symbol navigator surface (if exposed)**

If the sample app exposes a symbol outline or breadcrumb UI (check `Sources/CodeEditorSample/` for views that consume `SymbolNavigator`'s `@Published` outputs), open it and confirm:
- Top-level symbols populate (functions, types, properties)
- Cursor movement updates the breadcrumb path
- "Navigate to next/previous symbol" (if bound to a keyboard shortcut) jumps correctly

If the sample app does NOT expose this UI, skip this step and rely on the test coverage from Task 8.

- [ ] **Step 4: Edit and re-detect**

Type a few characters at the top of the file. Wait ~500ms (debounce). Verify symbols update without errors in the log.

- [ ] **Step 5: Quit cleanly**

Cmd-Q to quit. No console errors.

If any step fails, do not proceed — investigate, fix, re-run Task 8, then retry.

---

### Task 10: Update CLAUDE.md and NEXT.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `NEXT.md`

- [ ] **Step 1: Update `CLAUDE.md` — add `CodeEditorSymbols` to "Other source roots"**

Open `CLAUDE.md`. Locate the bullet list under `## Source Tree` that begins with "Other source roots (each is its own SPM target — see `Package.swift`):". Insert this bullet alphabetically (after `Sources/CodeEditorSyntaxHighlighting/` if present, or in the correct alphabetical slot — likely between `Sources/CodeEditorSample/` and `Sources/CodeEditorSyntaxHighlighting/`):

```markdown
- `Sources/CodeEditorSymbols/` — symbol-navigation surface: `BreadcrumbItem`, `SymbolNavigationConfiguration`, `SymbolProviderCatalog`, and generic `SymbolRangeIndex` storage (phase 4; new in §6.2.8b). The umbrella-coupled `SymbolNavigator` lives in `Sources/CodeEditorPlugin/Core/Symbols/`.
```

- [ ] **Step 2: Update `CLAUDE.md` — note `Core/Symbols/` sub-bucket**

Locate the source-tree comment block that lists `Core/` sub-buckets. After the §6.2.8a Folding extraction it currently reads (approximately):

```markdown
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

Add `Symbols/` to that list alphabetically:

```markdown
├── Core/                    # Main APIs, services, event system (includes F3 sub-buckets: Configuration/, Documents/, Folding/, Platform/, Symbols/, SyntaxHighlighting/, Text/ — umbrella-coupled glue staged here pending §6.2.12 Core split)
```

- [ ] **Step 3: Update `CLAUDE.md` — refresh umbrella file count**

In `CLAUDE.md`, locate the line that currently reads (approximately, after §6.2.8a):

```
10 top-level directories in the umbrella target, 315 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a), and 591 Swift source files under `Sources/`.
```

Re-count files after the move. Run:
```bash
find Sources/CodeEditorPlugin -name '*.swift' | wc -l
find Sources -name '*.swift' | wc -l
```

Update both numbers in the line. The umbrella file count drops by **2** (`SymbolNavigationTypes.swift` and `SymbolProviderCatalog.swift` leave the umbrella; `SymbolNavigator.swift` stays in the umbrella under `Core/Symbols/`; `SymbolRangeIndex.swift` is newly created and lives in the new target). The total under `Sources/` increases by **1** (the new split-out file).

Adjust the trailing parenthetical to read `(down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b)`.

- [ ] **Step 4: Update `NEXT.md` §6.0 — back-reference the spec from §6.0**

Open `NEXT.md`. Locate the §6.0 status table. The current closing row is the `CodeEditorFolding` entry. Append a new row immediately after:

```markdown
| `CodeEditorSymbols` | (pending commit SHA) | 3 files in new target (2 from `Features/` — `SymbolNavigationTypes`, `SymbolProviderCatalog` — + 1 split-out `SymbolRangeIndex.swift` extracted from `SymbolProviderCatalog`). 1 `CodeEditorView`-coupled file (`SymbolNavigator`) relocated to umbrella `Core/Symbols/` in pre-commit (see Task 3). | Languages, SyntaxHighlighting |
```

The `(pending commit SHA)` placeholder will be filled in Task 11.

- [ ] **Step 5: Update `NEXT.md` §6.0 — add deviations block**

In `NEXT.md` §6.0, immediately after the §6.2.8a deviations block ("Deviations during §6.2.8a `CodeEditorFolding`..."), insert:

```markdown
**Deviations during §6.2.8b `CodeEditorSymbols` (commit `(pending)`):**

- **Carve-out adopted, matching §6.2.8a precedent.** 1 of 3 `Features/` Symbol* files (`SymbolNavigator`) references `CodeEditorView` directly (5 distinct member accesses). Carve-out: 2 pure files moved to `Sources/CodeEditorSymbols/`; `SymbolNavigator` relocated to `Core/Symbols/` in pre-commit (see Task 3).
- **`SymbolRangeIndex<Value>` split into its own file mid-extraction.** Previously bundled at the bottom of `SymbolProviderCatalog.swift` by historical accident — a generic interval-tree storage type unrelated to the provider catalog. Split mirrors §6.2.7's `RangeQueryParser` extraction from `RegexRangeHighlightProvider`. New target ends up with 3 files (2 moved + 1 split).
- **Target deps narrower than the plan implied.** Final deps are `Languages, SyntaxHighlighting` — no `Common` (no moving file imports it), no `TextModel`, no `Platform`. Tighter than §6.2.8a Folding's `Common, Languages, SyntaxHighlighting, TextModel`.
- **~5 `internal` → `package` promotions** across `SymbolRangeIndex` (class declaration + synthesised init + 3 public methods). No promotions in the other 2 moving files — `SymbolProviderCatalog`, `BreadcrumbItem`, `SymbolNavigationConfiguration`, and `EmptySymbolProvider` are already correctly scoped. Smallest promotion surface in any §6.2 extraction so far.
- **No productization.** Matches Languages / SyntaxHighlighting / Folding precedent. Symbols routes through the umbrella.
- **Net consumer ripple: 1 umbrella import + 1 test import.** `Core/Symbols/SymbolNavigator.swift` gains `import CodeEditorSymbols` (for `SymbolRangeIndex` and `SymbolProviderCatalog`). `Tests/CodeEditorPluginTests/FeatureBehaviorTests.swift` gains the same (for `SymbolProviderCatalog`). `SwiftUI/EditorController.swift`, the 3 perf tests, and `ReviewRemediationRegressionTests` need no new imports.
```

- [ ] **Step 6: Update `NEXT.md` §6.2.8 — add Symbols sub-bullet**

In `NEXT.md` step 8 of §6.2 ("Extract feature engines individually"), the §6.2.8a Folding sub-bullet currently reads:

```markdown
   - **[done — carve-out, see §6.0]** **`CodeEditorFolding`** (§6.2.8a) — ...
```

Immediately below it add:

```markdown
   - **[done — carve-out, see §6.0]** **`CodeEditorSymbols`** (§6.2.8b) — 3 files in `Sources/CodeEditorSymbols/` (2 from `Features/`: `SymbolNavigationTypes`, `SymbolProviderCatalog`; plus split-out `SymbolRangeIndex.swift`). 1 `CodeEditorView`-coupled file (`SymbolNavigator`) relocated to `Core/Symbols/`. Final deps: `Languages`, `SyntaxHighlighting`. (`(pending)` + pre-relocation `(pending)`)
```

- [ ] **Step 7: Update `NEXT.md` §10 — strike Symbols from "Suggested next session"**

In `NEXT.md` §10, the first bullet currently reads (after §6.2.8a):

```markdown
- **6.2.8 feature engines** — `Symbols`, `SmartEditing`, `Search`, `Annotations`, `Workspace`, `Completion`. `Folding` is done (§6.2.8a, carve-out — see §6.0); full extraction of the engine itself blocked on §6.2.12 Core split removing `CodeEditorView` coupling. One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

Replace the leading list with the remaining engines (Symbols removed) and append a note:

```markdown
- **6.2.8 feature engines** — `SmartEditing`, `Search`, `Annotations`, `Workspace`, `Completion`. `Folding` is done (§6.2.8a, carve-out); `Symbols` is done (§6.2.8b, carve-out). Full extraction of the engines themselves blocked on §6.2.12 Core split removing `CodeEditorView` coupling. One session per remaining engine. Completion last (most call sites). `Features/Debugger*` may be design-only — confirm-or-delete before promoting.
```

- [ ] **Step 8: Verify build + lint after doc edits**

Run:
```bash
swift build 2>&1 | tail -5
swiftlint 2>&1 | tail -5
```
Expected: both clean. (Markdown edits don't affect compilation, but verify anyway.)

---

### Task 11: Main extraction commit

**Files:** none modified in this task; commit + record SHA back into `NEXT.md`.

- [ ] **Step 1: Stage all changes from Tasks 4–10**

Run:
```bash
git add Sources/CodeEditorSymbols \
        Sources/CodeEditorPlugin \
        Tests/CodeEditorPluginTests \
        CLAUDE.md \
        NEXT.md
git status --short
```
Expected: shows the 3 file renames (`Features` → `CodeEditorSymbols`), 1 new file (`SymbolRangeIndex.swift` in the new target — may show as part of the rename of `SymbolProviderCatalog.swift` depending on git rename detection), modifications to `Core/Symbols/SymbolNavigator.swift` (new import), modifications to `FeatureBehaviorTests.swift` (new import), and modifications to `CLAUDE.md` + `NEXT.md`.

- [ ] **Step 2: Create the main extraction commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorSymbols target (§6.2.8b)

Move 2 pure symbol-side files from
Sources/CodeEditorPlugin/Features/ to a new
CodeEditorSymbols SPM target:
  - SymbolNavigationTypes.swift
  - SymbolProviderCatalog.swift

Split SymbolRangeIndex<Value> out of
SymbolProviderCatalog.swift into its own file
(Sources/CodeEditorSymbols/SymbolRangeIndex.swift) —
a generic interval-tree storage type unrelated to the
provider catalog. Mirrors §6.2.7's RangeQueryParser
extraction.

The CodeEditorView-coupled SymbolNavigator relocated
to Core/Symbols/ in the pre-relocation commit,
mirroring §6.2.8a's 9704e80b → 76abf928 sequence.

Target deps: Languages, SyntaxHighlighting. ~5
internal→package promotions on SymbolRangeIndex.
CodeEditorPluginTests gains the new target as a
direct dep. Sample / UI unchanged.

Spec: docs/superpowers/specs/2026-05-18-codeeditor-symbols-extraction-design.md
Plan: docs/superpowers/plans/2026-05-18-codeeditor-symbols-extraction.md

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

Also capture the SHA of the relocation commit from Task 3:
```bash
git log -2 --format=%h
```
The second SHA in the output (one commit prior) is the relocation commit.

Open `NEXT.md` and replace each `(pending commit SHA)` / `(pending)` placeholder added in Task 10 with the actual SHA. Where the placeholder reads `(pending) + pre-relocation (pending)` (Task 10 Step 6), fill both — the main extraction SHA and the pre-relocation SHA.

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
- Two new commits on top of the spec commit `e6047280`: the relocation commit (from Task 3) and the amended extraction commit (from this task).
- Working tree clean.

- [ ] **Step 6: Stop. Do not push.**

The user will review the local commits and push when ready.
