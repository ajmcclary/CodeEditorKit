# §6.2.8c CodeEditorSmartEditing Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move 5 SmartEditing files from the umbrella `CodeEditorPlugin` target into a new `CodeEditorSmartEditing` SPM target depending on `CodeEditorView`. Closes the §6.2.8 feature-engine extraction series. Zero behavior change.

**Architecture:** Clean full extraction (no carve-out). New target lives at `Sources/CodeEditorSmartEditing/` with deps `CodeEditorCommon, CodeEditorPlatform, CodeEditorTextModel, CodeEditorView`. Umbrella `CodeEditorPlugin` depends on the new target; not productized as an opt-in `.library` (routes through umbrella per Folding/Symbols/Annotations/Completion precedent). One pre-existing API-gap fix: add `public init()` to `SmartEditingConfiguration`.

**Tech Stack:** Swift 6.3 SPM, `swift build` / `swift test --parallel`, SwiftLint (strict), Swift Package Manager `path:`-less target convention.

**Spec:** `docs/superpowers/specs/2026-05-18-codeeditor-smart-editing-design.md` (commit `2e2db39`).

**File map:**

| Action | Path | Responsibility |
|---|---|---|
| Create | `Sources/CodeEditorSmartEditing/SmartEditingEngine.swift` (via `git mv`) | Top-level engine + delegate-participant integration |
| Create | `Sources/CodeEditorSmartEditing/AutoBracketingEngine.swift` (via `git mv`) | Bracket/quote pair insertion strategy |
| Create | `Sources/CodeEditorSmartEditing/MultiCursorEditor.swift` (via `git mv`) | Multi-cursor state + input handling |
| Create | `Sources/CodeEditorSmartEditing/SmartIndentationEngine.swift` (via `git mv`) | Auto-indent calculation |
| Create | `Sources/CodeEditorSmartEditing/SmartSelectionExpander.swift` (via `git mv`) | Selection expansion (word/line/brackets) |
| Delete | `Sources/CodeEditorPlugin/Features/` directory | Empty after move |
| Modify | `Package.swift` | New target + 2 dep additions (umbrella + plugin tests) |
| Modify | `Sources/CodeEditorSmartEditing/SmartEditingEngine.swift` | Add `public init()` to `SmartEditingConfiguration` |
| Modify | `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift` | Add `import CodeEditorSmartEditing` |
| Modify | `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift` | Add `import CodeEditorSmartEditing` |
| Modify | `NEXT.md` | Status table row, §6.2.8 bullet flip, §10 cleanup |
| Modify | `CLAUDE.md` | Source tree section + add `Sources/CodeEditorSmartEditing/` to "Other source roots" |

---

### Task 1: Pre-flight verification

**Files:**
- Read-only: verify access modifiers, consumers, doc references.

This task produces no commits. It exists to catch the kind of late-stage surprise the prior carve-outs (§6.2.7, §6.2.8a, §6.2.8e, §6.2.8g) repeatedly hit. If any step here surfaces a discrepancy from the spec's assumptions, stop and update the spec before continuing.

- [ ] **Step 1: Confirm working tree is clean and on `main`**

Run:
```bash
git status
git log --oneline -1
```
Expected: clean working tree; HEAD is `2e2db39 Spec §6.2.8c CodeEditorSmartEditing extraction` (or a later commit on the same chunk).

- [ ] **Step 2: Verify all 5 source files exist at their expected paths**

Run:
```bash
ls -la Sources/CodeEditorPlugin/Features/ Sources/CodeEditorPlugin/Features/SmartEditing/
```
Expected: `SmartEditingEngine.swift` at `Features/` root; `AutoBracketingEngine.swift`, `MultiCursorEditor.swift`, `SmartIndentationEngine.swift`, `SmartSelectionExpander.swift` at `Features/SmartEditing/`. Plus possibly `.DS_Store`. Nothing else.

- [ ] **Step 3: Verify SmartEditing consumers project-wide (bare-word grep)**

Run:
```bash
grep -rEn '\b(SmartEditingEngine|SmartEditingConfiguration|SmartEditingBracketPair|AutoBracketingEngine|AutoIndentRule|SmartIndentationEngine|SmartSelectionExpander|MultiCursorEditor|TextCursor)\b' --include='*.swift' Sources/ Tests/ | grep -v 'Sources/CodeEditorPlugin/Features/'
```
Expected output (the spec's claim):
- 2 doc-comment references in `Sources/CodeEditorView/` (`TextKitSetupHelper.swift:77`, `TextViewDelegateParticipant.swift:17`) — both inside `//` comments, no import needed
- 1 reference in `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift` (constructs `SmartEditingEngine()`)
- 3 references in `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift` (constructs `SmartEditingEngine()`)
- No matches in `Sources/CodeEditorSample/`, `Sources/CodeEditorUI/`, or any other test target

If any other consumers surface, stop and reconcile with the spec before continuing.

- [ ] **Step 4: Verify `CodeEditorView.text` is `public` and `TextKitBridge`/`textKitBridge` are `package`**

Run:
```bash
grep -nE 'public var text:|package var text:|var text\b' Sources/CodeEditorView/CodeEditorView.swift | head -5
grep -nE 'class TextKitBridge|final class TextKitBridge' Sources/CodeEditorView/Text/TextKitBridge.swift
grep -nE 'textKitBridge =' Sources/CodeEditorView/CodeEditorView.swift
```
Expected:
- `Sources/CodeEditorView/CodeEditorView.swift:511: override public var text: String! {`
- `Sources/CodeEditorView/Text/TextKitBridge.swift:20:package final class TextKitBridge {`
- `Sources/CodeEditorView/CodeEditorView.swift:343:    package lazy var textKitBridge = TextKitBridge(textView: self)`

`package`-visible symbols are reachable cross-target within the same Swift package, so no further promotion is needed in `CodeEditorView`.

- [ ] **Step 5: Verify `SmartEditingConfiguration` lacks an explicit `public init()`**

Run:
```bash
grep -nE 'public init' Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift
```
Expected: 4 matches at lines 50 (`SmartEditingEngine.init()`), 234 (`SmartEditingBracketPair.init(open:close:isQuote:)`), plus 2 inside `IndentAction` / `SelectionStop` if they exist. **No** match at line ~262 inside `SmartEditingConfiguration`. If there is already a `public init()` on `SmartEditingConfiguration`, skip the §5.2 fix step in Task 4.

- [ ] **Step 6: Verify Package.swift target ordering and current contents**

Run:
```bash
grep -nE 'name: "CodeEditor(Workspace|Plugin|UI|SmartEditing|Search)"' Package.swift
```
Expected (key lines):
- `... name: "CodeEditorSearch",` around the leaf-target block
- `... name: "CodeEditorWorkspace",` immediately followed by `swiftSettings: swiftSettings`
- `... name: "CodeEditorPlugin",` (the umbrella target, twice — once in `products`, once in `targets`)
- `... name: "CodeEditorUI",`
- **No existing** `name: "CodeEditorSmartEditing"` line anywhere

- [ ] **Step 7: Verify diagrams have no live SmartEditing references that need updating**

Run:
```bash
grep -rln -i 'smart.editing' docs/Diagrams/
```
Expected: zero or only references inside `docs/archive/`. If a live diagram mentions SmartEditing, note it; the spec's §9.3 said to grep here for that reason.

---

### Task 2: Scaffold and move files

**Files:**
- Create: `Sources/CodeEditorSmartEditing/` (directory + 5 files via `git mv`)
- Delete: `Sources/CodeEditorPlugin/Features/` (after move completes)

- [ ] **Step 1: Create the new target directory**

Run:
```bash
mkdir -p Sources/CodeEditorSmartEditing
```
Expected: no output. Directory exists.

- [ ] **Step 2: Move `SmartEditingEngine.swift` (root file) into the new target**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift Sources/CodeEditorSmartEditing/SmartEditingEngine.swift
```
Expected: no output. `git status` will show the rename.

- [ ] **Step 3: Move the 4 strategy-engine files into the new target (flattens `SmartEditing/` subfolder)**

Run:
```bash
git mv Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift Sources/CodeEditorSmartEditing/AutoBracketingEngine.swift
git mv Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift Sources/CodeEditorSmartEditing/MultiCursorEditor.swift
git mv Sources/CodeEditorPlugin/Features/SmartEditing/SmartIndentationEngine.swift Sources/CodeEditorSmartEditing/SmartIndentationEngine.swift
git mv Sources/CodeEditorPlugin/Features/SmartEditing/SmartSelectionExpander.swift Sources/CodeEditorSmartEditing/SmartSelectionExpander.swift
```
Expected: no output. All 4 moves succeed.

- [ ] **Step 4: Confirm `Features/` is empty (except possibly `.DS_Store` and now-empty `SmartEditing/`)**

Run:
```bash
ls -la Sources/CodeEditorPlugin/Features/ Sources/CodeEditorPlugin/Features/SmartEditing/ 2>/dev/null
find Sources/CodeEditorPlugin/Features -type f
```
Expected: `find` returns only `.DS_Store` (or nothing). Both directories otherwise empty.

- [ ] **Step 5: Delete `Features/` entirely**

Run:
```bash
rm -rf Sources/CodeEditorPlugin/Features
```
Expected: no output. `Features/` no longer exists.

- [ ] **Step 6: Confirm the 5 files now live in the new target directory**

Run:
```bash
ls -la Sources/CodeEditorSmartEditing/
```
Expected: 5 `.swift` files only — `AutoBracketingEngine.swift`, `MultiCursorEditor.swift`, `SmartEditingEngine.swift`, `SmartIndentationEngine.swift`, `SmartSelectionExpander.swift`. No subdirectories, no `.DS_Store`.

- [ ] **Step 7: Verify `git status` reflects the rename + delete cleanly**

Run:
```bash
git status
```
Expected: 5 renames detected, all `R` (or `RM` if any file content changed — it shouldn't here). `Features/` listed as deleted if `.DS_Store` was tracked; otherwise silent.

Do NOT commit yet — Package.swift edits and the test-import additions belong in the same commit.

---

### Task 3: Wire `Package.swift`

**Files:**
- Modify: `Package.swift`

The target ordering in `Package.swift` is loosely leaf-target-first → umbrella → UI → sample → tests. New target slots between `CodeEditorWorkspace` and the umbrella `CodeEditorPlugin`.

- [ ] **Step 1: Add the `CodeEditorSmartEditing` target definition**

Open `Package.swift`. Find the `CodeEditorWorkspace` target (search for `name: "CodeEditorWorkspace",`). It currently looks like:

```swift
.target(
    name: "CodeEditorWorkspace",
    swiftSettings: swiftSettings
),
```

Insert a new `.target(...)` block immediately after the `CodeEditorWorkspace` block's closing `),` and before the next `.target(name: "CodeEditorPlugin",` block:

```swift
.target(
    name: "CodeEditorSmartEditing",
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorPlatform",
        "CodeEditorTextModel",
        "CodeEditorView"
    ],
    swiftSettings: swiftSettings
),
```

- [ ] **Step 2: Add `"CodeEditorSmartEditing"` to the umbrella `CodeEditorPlugin` target's `dependencies:` array**

Find the umbrella's `dependencies:` list (currently between `"CodeEditorAnnotations"` and `"CodeEditorView"`). Insert `"CodeEditorSmartEditing",` after `"CodeEditorPlatform",` and before `"CodeEditorSymbols",`. The result should look like:

```swift
"CodeEditorPlatform",
"CodeEditorSmartEditing",
"CodeEditorSymbols",
```

- [ ] **Step 3: Add `"CodeEditorSmartEditing"` to the `CodeEditorPluginTests` target's `dependencies:` array**

Find the `CodeEditorPluginTests` `.testTarget(...)` block. Insert `"CodeEditorSmartEditing",` after `"CodeEditorSearch",` and before `"CodeEditorSymbols",`. The result should look like:

```swift
"CodeEditorSearch",
"CodeEditorSmartEditing",
"CodeEditorSymbols",
```

- [ ] **Step 4: Do NOT add a `.library(name: "CodeEditorSmartEditing", ...)` product entry**

This target is not productized — it routes through the umbrella per the §6.2.8a/b/e/g precedent. Verify that the `products:` array in `Package.swift` was not modified.

- [ ] **Step 5: Confirm no other targets need the new dep**

The spec verified `CodeEditorUI`, `CodeEditorSample`, `CodeEditorSampleTests`, `CodeEditorUITests`, and `CodeEditorDesignTokensTests` do not reference SmartEditing. Do not edit those target declarations.

- [ ] **Step 6: Sanity-check `Package.swift` parses**

Run:
```bash
swift package describe --type json > /dev/null
```
Expected: exits 0 with no output to stdout. Any parse error indicates a syntactic problem in the edits above.

---

### Task 4: Source-file edits

**Files:**
- Modify: `Sources/CodeEditorSmartEditing/SmartEditingEngine.swift:262`
- Modify: `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift:1-11`
- Modify: `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift:1-4`

- [ ] **Step 1: Add `public init()` to `SmartEditingConfiguration`**

Open `Sources/CodeEditorSmartEditing/SmartEditingEngine.swift` (the moved file). Find the `SmartEditingConfiguration` struct declaration (around line 262):

```swift
/// Smart editing configuration
public struct SmartEditingConfiguration {
    // Auto-bracket insertion
    /// Whether to automatically insert closing brackets
    public var autoInsertBrackets = true
```

Insert a `public init()` after the opening brace and before the first `// MARK:` / property:

```swift
/// Smart editing configuration
public struct SmartEditingConfiguration {
    /// Creates a smart-editing configuration with default values.
    public init() {}

    // Auto-bracket insertion
    /// Whether to automatically insert closing brackets
    public var autoInsertBrackets = true
```

The doc comment is required by SwiftLint's `missing_docs` rule for public symbols.

- [ ] **Step 2: Add `import CodeEditorSmartEditing` to `ComprehensivePerformanceTests.swift`**

Open `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift`. Current imports (lines 1-11):

```swift
import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorLSP
import CodeEditorPlatform
@testable import CodeEditorPlugin
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest
```

Insert `import CodeEditorSmartEditing` in alphabetical position (between `@testable import CodeEditorPlugin` and `import CodeEditorTextModel`):

```swift
import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorLSP
import CodeEditorPlatform
@testable import CodeEditorPlugin
import CodeEditorSmartEditing
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest
```

If SwiftLint's `sorted_imports` autofix prefers a different slot, defer to it in Task 5.

- [ ] **Step 3: Add `import CodeEditorSmartEditing` to `SmartEditingEngineMultiplexerTests.swift`**

Open `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift`. Current imports (lines 1-4):

```swift
@testable import CodeEditorPlugin
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest
```

Insert `import CodeEditorSmartEditing` after `@testable import CodeEditorPlugin`:

```swift
@testable import CodeEditorPlugin
import CodeEditorSmartEditing
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest
```

- [ ] **Step 4: Quick build sanity-check before lint/test**

Run:
```bash
swift build 2>&1 | tail -40
```
Expected: build succeeds. If it fails with "cannot find type X in scope" pointing at a SmartEditing type from one of the test files, double-check the import additions. If it fails inside the new `CodeEditorSmartEditing` target with a missing symbol (e.g. a `TextRangeUtilities` reference), confirm the target's `dependencies:` array in Package.swift matches the spec's §3.1 table.

If build fails with an unrelated pre-existing error, stop and reconcile per the memory "fix pre-existing failures, don't document them."

---

### Task 5: Verify and commit the extraction

**Files:**
- No further file edits in this task.

- [ ] **Step 1: Clean build (catches missing-dep / cached-build masking issues)**

Run:
```bash
swift package clean
swift build 2>&1 | tail -20
```
Expected: build succeeds from scratch. The §6.2.12 commit `d0324a9` exists because incremental builds had masked a missing `CodeEditorPlatform` dep in `CodeEditorTextModel`. Clean-build verification is the gate that catches that class of bug.

- [ ] **Step 2: SwiftLint autofix + strict pass**

Run:
```bash
swiftlint --fix
swiftlint
```
Expected: `swiftlint --fix` may reorder imports in the 2 test files (this is fine — `sorted_imports` is the rule); `swiftlint` exits 0 with zero violations.

If `swiftlint` reports a `missing_docs` violation, it's almost certainly on the new `SmartEditingConfiguration.init()` doc comment — re-check Task 4 Step 1.

- [ ] **Step 3: Targeted test run for SmartEditing**

Run:
```bash
swift test --filter SmartEditing 2>&1 | tail -30
```
Expected: all SmartEditing-related tests pass (the `SmartEditingEngineMultiplexerTests` suite + any SmartEditing assertions in `ComprehensivePerformanceTests`).

- [ ] **Step 4: Full parallel test run (end-of-chunk gate)**

Per the project memory "don't over-run the test suite mid-plan — skip full swift test --parallel after additive-only steps":

Run:
```bash
swift test --parallel 2>&1 | tail -20
```
Expected: green except for the 1 known pre-existing failure noted in recent §6.2.12c verification logs. If new failures appear, investigate before committing.

- [ ] **Step 5: Sample-app smoke test**

Per the project memory **NSTextView init invariant**: after a clean build, launch the sample and type a character to confirm the editor still accepts input.

Run:
```bash
pkill -f CodeEditorSample 2>/dev/null; pkill -f lldb 2>/dev/null; true
swift run CodeEditorSample &
```
Open the sample, click into the editor, type a character. Expect: character appears.

Then kill the app:
```bash
pkill -f CodeEditorSample
```

(SmartEditing is not attached in the sample today, so no auto-bracket behavior to test — just confirm the editor itself still accepts input post-refactor.)

- [ ] **Step 6: Stage and commit the extraction**

Run:
```bash
git status
```
Expected: 5 renames (`Sources/CodeEditorPlugin/Features/... → Sources/CodeEditorSmartEditing/...`), 1 modified `Package.swift`, 2 modified test files, possibly 1 modified `SmartEditingEngine.swift` (the `public init()` add), and 1 deleted `Sources/CodeEditorPlugin/Features/.DS_Store` if it was tracked.

Stage everything:
```bash
git add Package.swift \
    Sources/CodeEditorSmartEditing/ \
    Sources/CodeEditorPlugin/Features \
    Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift \
    Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift
```

Commit:
```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorSmartEditing target (§6.2.8c)

Moves 5 files from umbrella Features/ to a new SPM target depending on
CodeEditorView. Clean full extraction — no carve-out residue. Closes
the §6.2.8 feature-engine extraction series. Subfolder flattened at
destination. Adds public init() on SmartEditingConfiguration to fix a
pre-existing API gap (synth memberwise init is internal on a public
struct with defaulted properties). 0 sample / UI ripple; 2 test files
gain `import CodeEditorSmartEditing`. Umbrella depends on the new
target; not productized as an opt-in .library (matches Folding /
Symbols / Annotations / Completion precedent).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Verify commit success**

Run:
```bash
git log -1 --stat
git status
```
Expected: HEAD is the new commit; working tree clean.

---

### Task 6: Update `NEXT.md` and `CLAUDE.md`

**Files:**
- Modify: `NEXT.md` (status table row in §6.0, §6.2.8 bullet flip, §10 cleanup, new deviations subsection)
- Modify: `CLAUDE.md` (source tree summary, "Other source roots" bullet)

- [ ] **Step 1: Add status-table row to `NEXT.md` §6.0**

Find the existing status table in §6.0 (around line 251 — the rows are `CodeEditorCommon`, `CodeEditorTextModel`, ..., `CodeEditorView`). Append a new row at the bottom of the table (after the `CodeEditorView` row):

Use the actual extraction commit hash from `git log -1 --format=%h` (Task 5 Step 7). Capture surprises encountered during Tasks 2–5 inline.

Template (fill `<commit>` and add any deviations discovered):

```markdown
| `CodeEditorSmartEditing` | `<commit>` | 5 files moved from umbrella `Features/` to new target (`SmartEditingEngine`, `AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). Clean full extraction — no carve-out, subfolder flattened at destination. 1 pre-existing API-gap fix: explicit `public init()` added to `SmartEditingConfiguration` (synth memberwise init was internal-on-public-struct). Not productized — routes through umbrella per Folding/Symbols/Annotations/Completion precedent. 0 sample / UI ripple; 2 plugin-test files gained `import CodeEditorSmartEditing`. `Sources/CodeEditorPlugin/Features/` directory deleted. | Common, Platform, TextModel, View |
```

- [ ] **Step 2: Update the §6.0 status summary sentence**

In §6.0, find the paragraph beginning "Phases 0–5 done; phases 7–8 carved out." (around line 249). At the end of that paragraph, before "Build green on every commit." add a sentence:

```
Then `CodeEditorSmartEditing` (§6.2.8c) closed the §6.2.8 feature-engine series — 5 files moved cleanly from `Features/`, last extraction before the SwiftUI / umbrella-stub / test-support endgame.
```

- [ ] **Step 3: Add the §6.2.8c deviations subsection**

After the existing "Deviations during §6.2.12 `CodeEditorView` (...)" subsection (search for `Deviations during §6.2.12 \`CodeEditorView\``), the next-most-recent block. Append a new subsection at the end of the deviations cluster:

```markdown
**Deviations during §6.2.8c `CodeEditorSmartEditing` (commit `<commit>`):**

- **Clean full extraction — no carve-out.** Third such extraction in §6.2.8 series after Workspace (`c1739137`) and Completion (`28b78b4f`). All 5 files moved; zero `Core/SmartEditing/` residue. The `SmartEditing/` subfolder was flattened at destination per the established target-name-is-the-namespace convention.
- **§4.1 dep claim correction.** NEXT.md §4.1 listed `TextModel, Configuration` as SmartEditing deps. Actual: `Common, Platform, TextModel, View`. Joins the §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12 §4.1-correction pattern.
- **1 pre-existing API-gap fix.** `SmartEditingConfiguration` synth memberwise init was `internal` because all its stored properties had defaults (Swift's synth-init-defaults-to-internal-on-public-struct pattern). Externally `let cfg = SmartEditingConfiguration(); engine.configuration = cfg` would have failed. Explicit `public init()` added inline per memory "Fix pre-existing failures, don't document them." Matches §6.2.8b Symbols / §6.2.8g Completion / §6.2.12c pattern. Smallest possible promotion surface: 1 line of code + 1 doc comment.
- **Not productized.** Umbrella consumes SmartEditing via direct target dep; no `.library` product entry. Matches Folding/Symbols/Annotations/Completion precedent. SmartEditing is ~745 LOC of pure-Swift editor behavior, too small to justify a host-facing opt-out.
- **Consumer ripple: minimal.** 0 source files in umbrella, sample, UI. 2 plugin-test files gained `import CodeEditorSmartEditing`. 1 `Package.swift` edit covering 1 new target + 2 dep additions (umbrella + plugin tests). Smallest §6.2.8 ripple aside from the §6.2.8d Search 3-file edit (which had a public-API removal).
- **Cross-target `package`-visible symbol reach into `CodeEditorView` worked unmodified.** `TextKitBridge` (class) and `CodeEditorView.textKitBridge` (property) are both `package`-visible and reachable from the new target without further promotion — the §6.2.12 `addDelegateParticipant` / `TextViewDelegateParticipant` promotions had already enabled the participant pattern for cross-target consumers.
- **`Sources/CodeEditorPlugin/Features/` directory deleted.** Was empty after the move (modulo `.DS_Store`). Umbrella `exclude:` list unchanged: never contained `"Features"` because Features/ had been source-bearing.
- **Single commit.** No pre-commit relocation needed. No clean-build fix needed.
- **End-of-chunk verification clean.** `swift package clean && swift build && swiftlint --fix && swiftlint && swift test --parallel` all green (modulo the same 1 pre-existing known issue logged in §6.2.12c verification).
- **Closes §6.2.8.** SmartEditing was the final deferred sub-task in the §6.2.8 feature-engine series. Remaining work per §10: §6.2.13 CodeEditorSwiftUI, §6.2.14 umbrella re-export, §6.2.15 CodeEditorTestSupport, then move to `~/Workspace/packages/`.
```

(If Tasks 2–5 surface any extra surprises, append them to this list before committing.)

- [ ] **Step 4: Flip the §6.2.8c bullet in §6.2.8 sub-bullets**

Find the line:
```
- **[deferred — blocked on §6.2.12]** **`CodeEditorSmartEditing`** (§6.2.8c) — audit during §6.2.8f brainstorming found all 5 SmartEditing files ...
```

Replace with:
```
- **[done — clean extraction, see §6.0]** **`CodeEditorSmartEditing`** (§6.2.8c) — 5 files moved cleanly from `Sources/CodeEditorPlugin/Features/` to `Sources/CodeEditorSmartEditing/` (`SmartEditingEngine`, `AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). Subfolder flattened at destination. Not productized — routes through umbrella per Folding/Symbols/Annotations/Completion precedent. 1 pre-existing API-gap fix: explicit `public init()` on `SmartEditingConfiguration`. Final deps: `Common, Platform, TextModel, View`. (`<commit>`)
```

- [ ] **Step 5: Drop the §6.2.8c bullet from §10 "Suggested next session"**

Find the line in §10 that starts:
```
- **6.2.8c `CodeEditorSmartEditing`** — now unblocked by §6.2.12. ...
```

Delete that entire bullet (it spans multiple lines through the next `- **6.2.13`). The remaining §10 bullets (`6.2.13 CodeEditorSwiftUI`, `6.2.14 umbrella re-export`, `6.2.15 CodeEditorTestSupport`, Move to `~/Workspace/packages/`) stay.

Also update the opening sentence of §10. Current:
```
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, 6.2.11, §6.2.12a/b/c (prep), and §6.2.12 (main Core/ split) are done (see §6.0). Remaining work:
```

Change to:
```
Steps 6.2.1 → 6.2.7, 6.2.8a, 6.2.8b, 6.2.8c, 6.2.8d, 6.2.8e, 6.2.8f, 6.2.8g, 6.2.9, 6.2.10, 6.2.11, §6.2.12a/b/c (prep), and §6.2.12 (main Core/ split) are done (see §6.0). Remaining work:
```

- [ ] **Step 6: Update `CLAUDE.md` source tree summary**

Open `CLAUDE.md`. Find the `Sources/CodeEditorPlugin/` tree block (in "Source Tree" section). It currently reads:

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (becomes the @_exported import file in §6.2.14)
├── Features/                # SmartEditing (deferred §6.2.8c — now unblocked by §6.2.12)
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Resources/               # Info.plist
└── SwiftUI/                 # SwiftUI wrappers and modifiers (extracts to CodeEditorSwiftUI in §6.2.13)
```

Delete the `Features/` line. The result:

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift   # Public-facing entry stub (becomes the @_exported import file in §6.2.14)
├── Languages/               # Language descriptors + folding/symbol/completion-model interfaces (compiled as CodeEditorLanguages target via `path:`)
├── Resources/               # Info.plist
└── SwiftUI/                 # SwiftUI wrappers and modifiers (extracts to CodeEditorSwiftUI in §6.2.13)
```

- [ ] **Step 7: Update `CLAUDE.md` umbrella file-count sentence**

Find the paragraph beginning "3 top-level directories in the umbrella target (`Features/`, `Languages/`, `SwiftUI/`...". Replace with:

```
3 top-level directories in the umbrella target (`Languages/`, `SwiftUI/`, plus `Resources/` for `Info.plist`) and 18 Swift source files in the umbrella target (1 root `CodeEditorPlugin.swift` + 17 `SwiftUI/*`; `Languages/` is its own SPM target via `path:`). Down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8c / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a/b/c / §6.2.12. Total Swift source files under `Sources/`: ~585.
```

(Adjust the "~585" if it drifts — verify with `find Sources -name '*.swift' | wc -l`. The §6.2.12c table said 585, and this chunk is net-zero on file count, just relocates 5 files.)

- [ ] **Step 8: Add `Sources/CodeEditorSmartEditing/` to CLAUDE.md "Other source roots"**

In the "Other source roots" list (under "Source Tree"), insert a new bullet in alphabetical position (between `CodeEditorSearch` and `CodeEditorSyntaxHighlighting`):

```
- `Sources/CodeEditorSmartEditing/` — smart-editing engines: `SmartEditingEngine` (top-level coordinator) + 4 strategy engines (`AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). 5 files. Not productized — umbrella `CodeEditorPlugin` depends on it directly (matches Folding/Symbols/Annotations/Completion precedent). Hosts attach via `engine.attach(to: codeEditorView)` — not wired into `EditorConfiguration`. Phase 8 of the §6.2 feature-engine extraction series; closes §6.2.8 (`<commit>`).
```

- [ ] **Step 9: Verify NEXT.md and CLAUDE.md edits are coherent**

Run:
```bash
git diff NEXT.md CLAUDE.md | head -120
```
Inspect: no accidental edits to unrelated sections, the new `<commit>` placeholder is filled with the actual commit hash from Task 5 Step 7, and all internal cross-references (§6.0, §6.2.8, §10) still make sense.

- [ ] **Step 10: Commit the docs**

Run:
```bash
git add NEXT.md CLAUDE.md
git commit -m "$(cat <<'EOF'
Document §6.2.8c CodeEditorSmartEditing extraction in NEXT.md and CLAUDE.md

Adds the §6.0 status-table row, the §6.2.8c deviations subsection,
flips the §6.2.8 sub-bullet to done, removes the §10 remaining-work
bullet. CLAUDE.md gains the `Sources/CodeEditorSmartEditing/` bullet
under "Other source roots" and drops the `Features/` line from the
umbrella source-tree summary. Closes §6.2.8 feature-engine series.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Final sanity check**

Run:
```bash
git log --oneline -3
git status
```
Expected:
- HEAD~0: "Document §6.2.8c CodeEditorSmartEditing extraction in NEXT.md and CLAUDE.md"
- HEAD~1: "Extract CodeEditorSmartEditing target (§6.2.8c)"
- HEAD~2: "Spec §6.2.8c CodeEditorSmartEditing extraction"
- Working tree clean.

Per the project memory **"Default to working on main"**, do NOT push to the remote unless the user explicitly asks.

---

## Done

This plan implements the spec at `docs/superpowers/specs/2026-05-18-codeeditor-smart-editing-design.md` (commit `2e2db39`) end-to-end. Net result: 2 new commits on top of the spec commit; `Sources/CodeEditorSmartEditing/` exists as a new SPM target; umbrella source tree shrinks by 5 files; `Sources/CodeEditorPlugin/Features/` is gone; SmartEditing closes the §6.2.8 feature-engine extraction series.

The next chunk (§6.2.13 `CodeEditorSwiftUI`) is unblocked by this work indirectly — `Sources/CodeEditorPlugin/SwiftUI/` is the only remaining sizable subdirectory in the umbrella, making it the natural next extraction target.
