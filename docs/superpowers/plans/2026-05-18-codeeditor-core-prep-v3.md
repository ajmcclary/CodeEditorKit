# §6.2.12c Core/ prep v3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** [`docs/superpowers/specs/2026-05-18-codeeditor-core-prep-v3-design.md`](../specs/2026-05-18-codeeditor-core-prep-v3-design.md)

**Goal:** Move 3 pure-Foundation state types from umbrella `Core/` to `CodeEditorCommon`, delete a 4-file `TextSystem` dead-code cluster, and split `AsyncOperationErrors.swift` (delete dead `CompletionAsyncError`; relocate `ErrorRecoveryCoordinator` to Common). Six commits, each green on `swift build && swiftlint && swift test`. Core/ shrinks 126 → 118.

**Architecture:** Three `git mv` moves + four `git rm` deletes + one rename-and-relocate, in six independently revertible commits. Per the §6.2.12b precedent, smallest moves go first; the AsyncOperationErrors split goes last because it has the most content edits. Zero new SPM targets, zero productization changes, 4 access-modifier promotions (DirtyTracker struct + 3 methods), 1 Package.swift edit (`CodeEditorUITests` gains `CodeEditorCommon` dep). Two public API removals (TextSystem cluster, CompletionAsyncError) — first §6.2.12-prep round with public surface removals.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftLint (strict mode), XCTest + Swift Testing.

---

## File Structure

This plan moves 4 files, deletes 5 files, and edits ~22 consumer files (~21 import additions + 1 Package.swift edit).

**Files relocated (4):**

| From | To | Content edit |
|---|---|---|
| `Sources/CodeEditorPlugin/Core/SelectionState.swift` | `Sources/CodeEditorCommon/SelectionState.swift` | none |
| `Sources/CodeEditorPlugin/Core/EditorInteractionState.swift` | `Sources/CodeEditorCommon/EditorInteractionState.swift` | none |
| `Sources/CodeEditorPlugin/Core/DirtyTracker.swift` | `Sources/CodeEditorCommon/DirtyTracker.swift` | promote `struct` + 3 methods to `public` |
| `Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift` | `Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift` | remove `CompletionAsyncError` block, swap `SyntaxHighlightingError.cancelled` → `CancellationError()`, drop two now-unused imports, strip header comment |

**Files deleted (5):**

- `Sources/CodeEditorPlugin/Core/TextSystem.swift`
- `Sources/CodeEditorPlugin/Core/TextSystemStyler.swift`
- `Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift`
- `Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift`
- The old `AsyncOperationErrors.swift` is moved-and-renamed, not separately deleted — Step covered in Task 6.

**Files modified for new imports (~21):**

- Task 2 (SelectionState): 5 files gain `import CodeEditorCommon`: `Core/EditorStateBridge.swift`, `Core/EditorState.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift`.
- Task 3 (EditorInteractionState): 16 files gain `import CodeEditorCommon` (1 already has it: `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`). Full list in Task 3 Step 4.
- Task 4 (DirtyTracker): 0 new imports (single consumer already imports Common).
- Task 5 (TextSystem deletes): 0 imports.
- Task 6 (AsyncOperationErrors split): 0 new imports (all 3 callers already import Common).

**Package.swift edit (1):**

- Task 2 (or Task 3, whichever first surfaces the need): `CodeEditorUITests` target gains `CodeEditorCommon` dep.

**Docs commit (Task 8):**

- `NEXT.md` — §6.0 header + status table + new deviations block + 3 row flips in audit table + summary-line + §10 first-bullet update + 1 dead-code-cluster note.
- `CLAUDE.md` — source-tree count, `CodeEditorCommon` bullet, "What Will Go Wrong" addition.

---

## Task 1: Pre-flight checks

**Files:** none modified.

- [ ] **Step 1: Confirm clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean` on branch `main`. If anything is uncommitted, stop and surface to the user (per the no-stash rule from memory — reason from the diff, do not shuffle).

- [ ] **Step 2: Confirm starting commit**

```bash
git log -1 --oneline
```

Expected: `04777cb Add §6.2.12c Core/ prep v3 design` (or a descendant of it). If the head is earlier (e.g. on the §6.2.12b doc commit `5d19e595`), stop — the spec must be committed first.

- [ ] **Step 3: Bare-word grep — verify consumer lists match spec**

Run each grep in `Sources/` and `Tests/`:

```bash
echo "=== SelectionState ==="
grep -rln "\bSelectionState\b" Sources/ Tests/ | grep -v Core/SelectionState.swift
echo "=== EditorInteractionState ==="
grep -rln "\bEditorInteractionState\b\|\bEditorCursorPosition\b" Sources/ Tests/ | grep -v Core/EditorInteractionState.swift
echo "=== DirtyTracker ==="
grep -rln "\bDirtyTracker\b" Sources/ Tests/ | grep -v Core/DirtyTracker.swift
echo "=== TextSystem cluster (must be empty outside cluster) ==="
grep -rln "\bTextSystem\b\|\bTextSystemStyler\b\|\bThreePhaseTextSystemStyler\b\|\bTokenSystemValidator\b" Sources/ Tests/ | grep -v 'Core/TextSystem.swift\|Core/TextSystemStyler.swift\|Core/ThreePhaseTextSystemStyler.swift\|Core/TokenSystemValidator.swift'
echo "=== CompletionAsyncError (must be empty outside its file) ==="
grep -rln "\bCompletionAsyncError\b" Sources/ Tests/ | grep -v Core/AsyncOperationErrors.swift
echo "=== ErrorRecoveryCoordinator ==="
grep -rln "\bErrorRecoveryCoordinator\b" Sources/ Tests/ | grep -v Core/AsyncOperationErrors.swift
```

Expected:

- **SelectionState**: exactly 6 files — `Core/EditorStateBridge.swift`, `Core/EditorState.swift`, `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift`.
- **EditorInteractionState** (+ `EditorCursorPosition`): exactly 17 files — `Core/Documents/EditorDocuments.swift`, `Core/Documents/EditorDocument.swift`, `SwiftUI/CodeEditor.swift`, `SwiftUI/CodeEditorIntent.swift`, `SwiftUI/CodeEditor+AppKitExtensions.swift`, `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`, `SwiftUI/CodeEditor+UIKitExtensions.swift`, `SwiftUI/CodeEditor+ModifiersExtensions.swift`, `SwiftUI/CodeEditorRepresentableHelper.swift`, `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift`, plus 7 tests (`EditorInteractionStateTests`, `EditorDocumentsBindingTests`, `ActiveDocumentModifierTests`, `EditorDocumentTests`, `ModifierChainCompositionTests`, `CodeEditorIntentTests`, `EditorInteractionStateBindingTests`).
- **DirtyTracker**: exactly 1 file — `SwiftUI/CodeEditor+CoordinatorsExtensions.swift`.
- **TextSystem cluster**: empty (the four files reference each other only; grep is filtered to exclude them).
- **CompletionAsyncError**: empty (zero in-tree callers).
- **ErrorRecoveryCoordinator**: exactly 3 files — `Core/ActorCoordinator.swift`, `Core/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`, `Core/Actors/TextProcessingActor.swift`.

If the actual greps return a **superset** of these lists, extend the import-add step in the relevant task. If they return a **subset** (i.e. a spec-listed consumer is missing), investigate before proceeding.

- [ ] **Step 4: Scan tests for stale-path assertions** (§6.2.8e / §6.2.12a precedent)

```bash
grep -rn "Sources/CodeEditorPlugin/Core/SelectionState.swift\|Sources/CodeEditorPlugin/Core/EditorInteractionState.swift\|Sources/CodeEditorPlugin/Core/DirtyTracker.swift\|Sources/CodeEditorPlugin/Core/TextSystem.swift\|Sources/CodeEditorPlugin/Core/TextSystemStyler.swift\|Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift\|Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift\|Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift" Tests/
```

Expected: no matches. If a test (e.g. `ReviewRemediationRegressionTests`) asserts on any of these paths, record the file — update the assertion in the same commit as the corresponding move/delete.

- [ ] **Step 5: Baseline build**

```bash
swift build
```

Expected: `Build complete!` (no errors). If a warning is present that isn't blocking, record it; do not let it gate the run.

- [ ] **Step 6: Baseline lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations. If the baseline has lint violations on `main`, stop and surface to the user (do not silently inherit a dirty baseline).

- [ ] **Step 7: Baseline test (targeted)**

```bash
swift test --filter "SelectionState\|EditorInteractionState\|EditorState\|EditorDocument\|EditorStatusBar\|Coordinator\|ActorCoordinator\|ErrorRecovery\|ModifierChainComposition\|CodeEditorIntent"
```

Expected: all tests pass. Record the test count; the same filter rerun at end-of-chunk (Task 7) must show ≥ this count, all passing.

---

## Task 2: Commit 1 — `SelectionState.swift` → `CodeEditorCommon`

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/SelectionState.swift` → `Sources/CodeEditorCommon/SelectionState.swift`
- Modify (5 import adds): `Sources/CodeEditorPlugin/Core/EditorStateBridge.swift`, `Sources/CodeEditorPlugin/Core/EditorState.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`, `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`, `Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift`
- Modify (Package.swift): `CodeEditorUITests` target gains `CodeEditorCommon` dep
- Verify (no edit expected): `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` (already imports Common)

- [ ] **Step 1: Verify destination directory exists**

```bash
ls Sources/CodeEditorCommon/ | head -10
```

Expected: directory listing showing `Errors/`, `Extensions/`, `Models/`, `Utilities/`, plus existing top-level files (`RecoverableAsyncError.swift`, `SendableError.swift`, `SendableTypes.swift`, `SourcePosition.swift`). If the directory does not exist or is missing these markers, stop (the §6.2.12a/b baseline is wrong).

- [ ] **Step 2: Move the file**

```bash
git mv Sources/CodeEditorPlugin/Core/SelectionState.swift Sources/CodeEditorCommon/SelectionState.swift
```

Expected: no output. `git status` shows: `renamed: Sources/CodeEditorPlugin/Core/SelectionState.swift -> Sources/CodeEditorCommon/SelectionState.swift`.

- [ ] **Step 3: Add `import CodeEditorCommon` to 5 consumer files**

For each file, insert `import CodeEditorCommon` alphabetically into the import block. SwiftLint's `sorted_imports` settles ordering; the exact alphabetic slot per file is below.

1. **`Sources/CodeEditorPlugin/Core/EditorStateBridge.swift`** — current imports:

   ```swift
   import CodeEditorTextModel
   import Foundation
   ```

   Edit to:

   ```swift
   import CodeEditorCommon
   import CodeEditorTextModel
   import Foundation
   ```

2. **`Sources/CodeEditorPlugin/Core/EditorState.swift`** — current imports:

   ```swift
   import CodeEditorDiagnostics
   import CodeEditorLanguages
   import CodeEditorSymbols
   import Foundation
   import Observation
   ```

   Edit to:

   ```swift
   import CodeEditorCommon
   import CodeEditorDiagnostics
   import CodeEditorLanguages
   import CodeEditorSymbols
   import Foundation
   import Observation
   ```

3. **`Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`** — current imports include:

   ```swift
   import CodeEditorLanguages
   import CodeEditorSymbols
   import Observation
   import Testing
   ```

   Plus `@testable import CodeEditorPlugin` if present (verify; do **not** drop). Add `import CodeEditorCommon` before `CodeEditorLanguages`.

4. **`Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`** — current imports:

   ```swift
   import CodeEditorLanguages
   import CodeEditorSymbols
   import Testing
   ```

   Plus `@testable import CodeEditorPlugin`. Add `import CodeEditorCommon` before `CodeEditorLanguages`.

5. **`Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift`** — current imports:

   ```swift
   import CodeEditorConfiguration
   @testable import CodeEditorPlugin
   import CodeEditorUI
   import SnapshotTesting
   import SwiftUI
   import XCTest
   ```

   Add `import CodeEditorCommon` before `CodeEditorConfiguration` (alphabetical).

After all 5 edits, run `swiftlint --fix` once to settle any drift.

- [ ] **Step 4: Add `CodeEditorCommon` to `CodeEditorUITests` target in Package.swift**

Open `Package.swift`. Find the `CodeEditorUITests` target. Current dependencies block:

```swift
.testTarget(
    name: "CodeEditorUITests",
    dependencies: [
        "CodeEditorConfiguration",
        "CodeEditorLanguages",
        "CodeEditorSymbols",
        "CodeEditorUI",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ],
    exclude: [
        "Snapshots/__Snapshots__"
    ],
    swiftSettings: swiftSettings
),
```

Edit `dependencies:` array to:

```swift
    dependencies: [
        "CodeEditorCommon",
        "CodeEditorConfiguration",
        "CodeEditorLanguages",
        "CodeEditorSymbols",
        "CodeEditorUI",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ],
```

(Insert `"CodeEditorCommon",` in alphabetical order as the first entry of the list.)

- [ ] **Step 5: Build**

```bash
swift build
```

Expected: `Build complete!`. If the build fails with "cannot find type 'SelectionState'" in a file not in Step 3's list, that's a missed bare-word grep — add `import CodeEditorCommon` to that file before proceeding (likely candidates: a Sample doc-comment reference, or a UI test gained a SelectionState reference recently).

- [ ] **Step 6: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 7: Run targeted tests**

```bash
swift test --filter "SelectionState\|EditorState\|EditorStatusBar"
```

Expected: all tests pass. Record count vs. baseline.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorCommon/SelectionState.swift Sources/CodeEditorPlugin/Core/SelectionState.swift Sources/CodeEditorPlugin/Core/EditorStateBridge.swift Sources/CodeEditorPlugin/Core/EditorState.swift Tests/CodeEditorPluginTests/Core/EditorStateTests.swift Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift Package.swift
git commit -m "$(cat <<'EOF'
Relocate SelectionState to CodeEditorCommon (§6.2.12c prep)

Move Sources/CodeEditorPlugin/Core/SelectionState.swift to
Sources/CodeEditorCommon/SelectionState.swift. Foundation-only public
struct (line/column/selectionLength caret position). Zero
CodeEditorView coupling; zero access-modifier promotions (already
public).

5 consumers gain `import CodeEditorCommon` (EditorStateBridge,
EditorState, EditorStateTests, EditorStateConformanceTests,
EditorStatusBarSnapshots). CodeEditorUITests target gains
CodeEditorCommon dep in Package.swift.

Closes the first of five §6.2.12c moves/deletes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] Relocate SelectionState to CodeEditorCommon (§6.2.12c prep)`. `git status` reports clean.

---

## Task 3: Commit 2 — `EditorInteractionState.swift` → `CodeEditorCommon`

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/EditorInteractionState.swift` → `Sources/CodeEditorCommon/EditorInteractionState.swift`
- Modify (16 import adds): 9 source files + 7 test files (full list in Step 3)
- Verify (no edit expected): `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` (already imports Common)

- [ ] **Step 1: Move the file**

```bash
git mv Sources/CodeEditorPlugin/Core/EditorInteractionState.swift Sources/CodeEditorCommon/EditorInteractionState.swift
```

Expected: no output. The file's `swiftlint:disable discouraged_optional_boolean discouraged_optional_collection` pragma travels with it unchanged (it's a file-level directive).

- [ ] **Step 2: Verify carry-set has no content edits**

```bash
head -15 Sources/CodeEditorCommon/EditorInteractionState.swift
```

Expected: leading import block is `import Foundation` + `import CoreGraphics`, plus the swiftlint pragma. No `import CodeEditorPlugin` reference (would be a structural error). No edits required to the file itself.

- [ ] **Step 3: Add `import CodeEditorCommon` to 16 consumer files**

Each file needs `import CodeEditorCommon` inserted alphabetically. SwiftLint settles ordering; per-file alphabetic slots below.

**Source files (9):**

1. `Sources/CodeEditorPlugin/Core/Documents/EditorDocument.swift` — add `import CodeEditorCommon` (verify current first-line imports; insert alphabetically before any existing `CodeEditor*` import).
2. `Sources/CodeEditorPlugin/Core/Documents/EditorDocuments.swift` — same pattern.
3. `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` — add `import CodeEditorCommon`.
4. `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift` — add `import CodeEditorCommon`.
5. `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift` — add `import CodeEditorCommon`.
6. `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift` — add `import CodeEditorCommon`.
7. `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift` — add `import CodeEditorCommon`.
8. `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` — add `import CodeEditorCommon`.
9. `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` — add `import CodeEditorCommon`. (Verify `CodeEditorSample` target has `CodeEditorCommon` dep in Package.swift; per `grep '"CodeEditorCommon"' Package.swift`, it should already — confirm before edit.)

**Test files (7):**

10. `Tests/CodeEditorPluginTests/Core/EditorInteractionStateTests.swift` — add `import CodeEditorCommon` (keep existing `@testable import CodeEditorPlugin`).
11. `Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift` — add `import CodeEditorCommon`.
12. `Tests/CodeEditorPluginTests/Documents/ActiveDocumentModifierTests.swift` — add `import CodeEditorCommon`.
13. `Tests/CodeEditorPluginTests/Documents/EditorDocumentTests.swift` — add `import CodeEditorCommon`.
14. `Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift` — add `import CodeEditorCommon`.
15. `Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift` — add `import CodeEditorCommon`.
16. `Tests/CodeEditorPluginTests/SwiftUI/EditorInteractionStateBindingTests.swift` — add `import CodeEditorCommon`.

(`SwiftUI/CodeEditor+CoordinatorsExtensions.swift` already imports `CodeEditorCommon` — no edit.)

After all edits, run `swiftlint --fix` once.

- [ ] **Step 4: Verify CodeEditorSample target has CodeEditorCommon dep**

```bash
grep -A 30 'name: "CodeEditorSample"' Package.swift | grep -m 1 'CodeEditorCommon\|dependencies'
```

Expected: `CodeEditorSample` target's `dependencies:` list includes `"CodeEditorCommon"`. If it doesn't, add it (insert alphabetically — list typically begins `"CodeEditorAnnotations", "CodeEditorCommon", ...`). Per §6.2.12a/b state, this dep is almost certainly already there; verify and skip the Package.swift edit if so.

- [ ] **Step 5: Build**

```bash
swift build
```

Expected: `Build complete!`. If the build fails with "cannot find type 'EditorInteractionState'" or "cannot find type 'EditorCursorPosition'" in a file not in Step 3's list, add `import CodeEditorCommon` to that file. (Likely missed candidate: a SwiftUI host-app file that references `EditorCursorPosition` in a property type.)

- [ ] **Step 6: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 7: Run targeted tests**

```bash
swift test --filter "EditorInteractionState\|EditorDocument\|CodeEditorIntent\|ModifierChainComposition\|ActiveDocumentModifier"
```

Expected: all tests pass.

- [ ] **Step 8: Codable sanity check**

`EditorInteractionState` and `EditorCursorPosition` are both `Codable`. Synthesis is per-module — moving across modules shouldn't change conformance behavior, but verify the binding test still passes:

```bash
swift test --filter "EditorInteractionStateBindingTests"
```

Expected: pass. If any decode/encode round-trip fails, inspect for a hard-coded module name in `decoder.userInfo` (rare) — surface to user if found.

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorCommon/EditorInteractionState.swift Sources/CodeEditorPlugin/Core/EditorInteractionState.swift Sources/CodeEditorPlugin/Core/Documents/EditorDocument.swift Sources/CodeEditorPlugin/Core/Documents/EditorDocuments.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKitExtensions.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKitExtensions.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift Tests/CodeEditorPluginTests/Core/EditorInteractionStateTests.swift Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift Tests/CodeEditorPluginTests/Documents/ActiveDocumentModifierTests.swift Tests/CodeEditorPluginTests/Documents/EditorDocumentTests.swift Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift Tests/CodeEditorPluginTests/SwiftUI/EditorInteractionStateBindingTests.swift
git commit -m "$(cat <<'EOF'
Relocate EditorInteractionState to CodeEditorCommon (§6.2.12c prep)

Move Sources/CodeEditorPlugin/Core/EditorInteractionState.swift to
Sources/CodeEditorCommon/. Foundation + CoreGraphics public struct
(serializable cursor/scroll/find-panel/fold state); carries
EditorCursorPosition. Zero CodeEditorView coupling; zero
access-modifier promotions (already public).

16 consumers gain `import CodeEditorCommon` (9 source: 2 Documents,
7 SwiftUI, 1 Sample; 7 plugin tests). CoordinatorsExtensions
already had the import.

Closes the second of five §6.2.12c moves/deletes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit. `git status` reports clean.

---

## Task 4: Commit 3 — `DirtyTracker.swift` → `CodeEditorCommon`

**Files:**
- Move: `Sources/CodeEditorPlugin/Core/DirtyTracker.swift` → `Sources/CodeEditorCommon/DirtyTracker.swift`
- Modify (4 promotions in moved file): `struct DirtyTracker` + `setBaseline(_:)` + `isDirty(currentText:)` + `markClean(currentText:)` (internal → public)
- Verify (no edit expected): `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` (already imports Common; references the struct)

- [ ] **Step 1: Move the file**

```bash
git mv Sources/CodeEditorPlugin/Core/DirtyTracker.swift Sources/CodeEditorCommon/DirtyTracker.swift
```

Expected: no output.

- [ ] **Step 2: Promote `struct DirtyTracker` and 3 methods to `public`**

Open `Sources/CodeEditorCommon/DirtyTracker.swift`. The file currently reads:

```swift
import Foundation

/// View-local dirty tracker. The framework's coordinator owns one instance per
/// editor and asks it after every text-mutation sync whether the current
/// content differs from the baseline.
///
/// Baseline is set on initial text install (`setupContainer`), on host-driven
/// binding swap (`updateContainer` with `text != storage`), and on explicit
/// `markClean(currentText:)`. Returns `false` when no baseline has been set
/// (pre-mount initial state).
struct DirtyTracker: Sendable {
    private var baseline: String?

    mutating func setBaseline(_ text: String) {
        baseline = text
    }

    func isDirty(currentText: String) -> Bool {
        guard let baseline else { return false }
        return baseline != currentText
    }

    mutating func markClean(currentText: String) {
        baseline = currentText
    }
}
```

Edit to:

```swift
import Foundation

/// View-local dirty tracker. The framework's coordinator owns one instance per
/// editor and asks it after every text-mutation sync whether the current
/// content differs from the baseline.
///
/// Baseline is set on initial text install (`setupContainer`), on host-driven
/// binding swap (`updateContainer` with `text != storage`), and on explicit
/// `markClean(currentText:)`. Returns `false` when no baseline has been set
/// (pre-mount initial state).
public struct DirtyTracker: Sendable {
    private var baseline: String?

    public init() {}

    public mutating func setBaseline(_ text: String) {
        baseline = text
    }

    public func isDirty(currentText: String) -> Bool {
        guard let baseline else { return false }
        return baseline != currentText
    }

    public mutating func markClean(currentText: String) {
        baseline = currentText
    }
}
```

(Five edits, not four: the synthesised initializer becomes `internal` once the struct is `public`, so an explicit `public init()` is needed for cross-module construction. This is the same pattern that bit §6.2.8b Symbols and §6.2.8g Completion — a `public` struct's synthesised init defaults to `internal`.)

- [ ] **Step 3: Verify the single consumer**

```bash
grep -n 'DirtyTracker' Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
```

Expected: zero or more references (it's the single in-tree consumer). The file already imports `CodeEditorCommon`, so no import edit is needed. Verify any `DirtyTracker()` construction call site is compatible with the new `public init()`.

- [ ] **Step 4: Build**

```bash
swift build
```

Expected: `Build complete!`. If the build fails with "'init' is inaccessible" or "'setBaseline' is inaccessible", a method or init promotion was missed — verify all 5 edits in Step 2.

- [ ] **Step 5: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 6: Run targeted tests**

```bash
swift test --filter "Coordinator"
```

Expected: all tests pass (DirtyTracker has no direct test, but `CodeEditor+CoordinatorsExtensions` is exercised by coordinator-flow tests).

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorCommon/DirtyTracker.swift Sources/CodeEditorPlugin/Core/DirtyTracker.swift
git commit -m "$(cat <<'EOF'
Relocate DirtyTracker to CodeEditorCommon (§6.2.12c prep)

Move Sources/CodeEditorPlugin/Core/DirtyTracker.swift to
Sources/CodeEditorCommon/. Foundation-only baseline-comparison
dirty tracker (no CodeEditorView coupling).

5 access-modifier promotions: struct DirtyTracker (internal → public),
synthesised init replaced with explicit public init(), 3 methods
(setBaseline, isDirty, markClean) internal → public. Matches the
§6.2.8b Symbols / §6.2.8g Completion pattern where a public struct's
synthesised init defaults to internal.

Sole consumer (SwiftUI/CodeEditor+CoordinatorsExtensions.swift)
already imports CodeEditorCommon — zero new imports.

Closes the third of five §6.2.12c moves/deletes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit.

---

## Task 5: Commit 4 — Delete `TextSystem` dead-code cluster

**Files:**
- Delete: `Sources/CodeEditorPlugin/Core/TextSystem.swift`, `Sources/CodeEditorPlugin/Core/TextSystemStyler.swift`, `Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift`, `Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift`

- [ ] **Step 1: Re-verify dead-code status immediately before deletion**

```bash
echo "=== conformers to TextSystem ==="
grep -rn ': TextSystem\b\|extension.*: TextSystem\b\|class.*: TextSystem\b\|struct.*: TextSystem\b' Sources/ Tests/
echo "=== invocations of the styler / validator classes ==="
grep -rn 'TextSystemStyler(\|ThreePhaseTextSystemStyler(\|TokenSystemValidator(' Sources/ Tests/
echo "=== uses of the Styler typealias ==="
grep -rn '\.Styler\b' Sources/ Tests/
```

Expected:

- First grep: only the 3 generic class declarations *inside the cluster itself* — `Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift:6`, `ThreePhaseTextSystemStyler.swift:8`, `TextSystemStyler.swift:7`.
- Second grep: zero hits.
- Third grep: zero hits.

If any of the three returns a hit *outside the four cluster files*, **stop**. The dead-code claim is wrong; surface to the user and revise the plan (the file is a live consumer; deletion would break the build).

- [ ] **Step 2: Delete the four files**

```bash
git rm Sources/CodeEditorPlugin/Core/TextSystem.swift Sources/CodeEditorPlugin/Core/TextSystemStyler.swift Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift
```

Expected: `rm 'Sources/CodeEditorPlugin/Core/TextSystem.swift'` etc. for all four. `git status` shows: `deleted: Sources/CodeEditorPlugin/Core/TextSystem.swift` (and three siblings).

- [ ] **Step 3: Build**

```bash
swift build
```

Expected: `Build complete!`. If the build fails, the re-verify in Step 1 missed a consumer — restore the relevant file (`git checkout HEAD~0 -- Sources/CodeEditorPlugin/Core/<file>`) and surface to user.

- [ ] **Step 4: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 5: No targeted test** — the cluster has no associated tests (consequence of being dead). Skip to commit.

- [ ] **Step 6: Commit**

```bash
git add -u Sources/CodeEditorPlugin/Core/TextSystem.swift Sources/CodeEditorPlugin/Core/TextSystemStyler.swift Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift
git commit -m "$(cat <<'EOF'
Delete TextSystem dead-code cluster (§6.2.12c prep)

Remove four TextKit2 styling-experiment scaffolding files with zero
in-tree usage:
- Sources/CodeEditorPlugin/Core/TextSystem.swift (public protocol)
- Sources/CodeEditorPlugin/Core/TextSystemStyler.swift (generic class)
- Sources/CodeEditorPlugin/Core/ThreePhaseTextSystemStyler.swift
- Sources/CodeEditorPlugin/Core/TokenSystemValidator.swift

Verified dead:
- protocol TextSystem has zero conformers anywhere in Sources/ or Tests/
- the three generic classes are referenced only by each other and by
  TextSystem's own Styler typealias

First public-API removal in the §6.2.12-prep series. Matches §6.2.9a
Debugger precedent ("if a candidate target's symbols are all
internal-by-use and have zero in-tree consumers, deletion is the
answer, not extraction").

Closes the fourth of five §6.2.12c moves/deletes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit. `git log -1 --stat` shows 4 file deletions, ~410 LOC removed.

---

## Task 6: Commit 5 — Split `AsyncOperationErrors.swift`

**Files:**
- Edit + move: `Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift` → `Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift`
- Verify (no edit expected): `Sources/CodeEditorPlugin/Core/ActorCoordinator.swift`, `Sources/CodeEditorPlugin/Core/SyntaxHighlighting/AsyncSyntaxHighlighter.swift`, `Sources/CodeEditorPlugin/Core/Actors/TextProcessingActor.swift` (all 3 already import Common; reference `ErrorRecoveryCoordinator`)

Per the §6.2.12b lesson "stage destination paths first to avoid broken-rename-commit," this task edits the content **before** running `git mv`, so the relocated file has its final shape before staging.

- [ ] **Step 1: Edit `AsyncOperationErrors.swift` — delete `CompletionAsyncError` block**

Open `Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift`. The current file structure is:

```
1-3:    imports
4-8:    leading comment block about §6.2.7 relocations
10:     // MARK: - Completion Errors
11-151: public enum CompletionAsyncError { ... } (140 lines, 6 cases with recovery-strategy switches)
152-153: blank / mark separator
153:    // MARK: - Error Recovery Coordinator
155-260: public actor ErrorRecoveryCoordinator { ... }
```

Delete lines 10–152 inclusive (the `// MARK: - Completion Errors` comment, the entire `CompletionAsyncError` enum, the blank line, and the `// MARK: - Error Recovery Coordinator` comment that follows — the surviving section needs no `// MARK:` separator since it's the file's only content).

Verify post-edit: the file now starts with the imports + leading comment, then jumps directly to `/// Coordinates error recovery strategies...` doc comment + `public actor ErrorRecoveryCoordinator`. `wc -l` reports ~110 lines (down from 260).

- [ ] **Step 2: Edit `AsyncOperationErrors.swift` — swap `SyntaxHighlightingError.cancelled` for `CancellationError()`**

Find the line that reads:

```swift
        throw lastError ?? SyntaxHighlightingError.cancelled
```

Replace with:

```swift
        throw lastError ?? CancellationError()
```

This is the only `SyntaxHighlightingError` reference in `ErrorRecoveryCoordinator`; after this edit, the file no longer depends on `CodeEditorSyntaxHighlighting`. (`CancellationError` is from the Swift standard library — no import needed.)

- [ ] **Step 3: Edit `AsyncOperationErrors.swift` — strip unused imports**

The file's current import block:

```swift
import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorSyntaxHighlighting
import Foundation
```

`CodeEditorLanguages` was used only by `CompletionAsyncError` (`case providerNotAvailable(Language)`); `CodeEditorSyntaxHighlighting` was used only by the now-swapped `SyntaxHighlightingError.cancelled`. Edit to:

```swift
import CodeEditorCommon
import Foundation
```

- [ ] **Step 4: Edit `AsyncOperationErrors.swift` — strip the §6.2.7-era header comment**

The file currently has, between the imports and the `// MARK:` lines, this comment block:

```swift
// `RecoverableAsyncError`, `RecoveryStrategy`, `BackoffStrategy` live in
// `CodeEditorCommon`; `SyntaxHighlightingError` lives in
// `CodeEditorSyntaxHighlighting` — relocated during the §6.2.7 extraction.
```

Delete these three comment lines. The file's purpose is no longer "errors for async operations" — it's a single recovery-coordinator type, and the header comment was a §6.2.7-era cross-target sign-post that no longer applies (the only remaining type imports `CodeEditorCommon` and lives there post-rename).

Post-edit, the file's first few lines are:

```swift
import CodeEditorCommon
import Foundation

/// Coordinates error recovery strategies across the application
@available(macOS 13.0, iOS 16.0, *)
public actor ErrorRecoveryCoordinator {
    ...
}
```

- [ ] **Step 5: Verify file is self-consistent**

```bash
head -8 Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift
wc -l Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift
```

Expected: header reads exactly the post-edit form from Step 4; `wc -l` reports ~105–110 lines (down from 260). If the head shows residual `CompletionAsyncError` lines or stray `import CodeEditorLanguages`, redo the relevant step.

- [ ] **Step 6: Rename + relocate**

```bash
git mv Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift
```

Expected: no output. `git status` shows: `renamed: Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift -> Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift` plus the modifications staged from Steps 1–4.

- [ ] **Step 7: Verify three consumers still see `ErrorRecoveryCoordinator`**

```bash
grep -n 'ErrorRecoveryCoordinator' Sources/CodeEditorPlugin/Core/ActorCoordinator.swift Sources/CodeEditorPlugin/Core/SyntaxHighlighting/AsyncSyntaxHighlighter.swift Sources/CodeEditorPlugin/Core/Actors/TextProcessingActor.swift
```

Expected: each file references `ErrorRecoveryCoordinator` as a type. Confirm each file already has `import CodeEditorCommon` (per pre-flight Step 3); no import edits needed.

- [ ] **Step 8: Build**

```bash
swift build
```

Expected: `Build complete!`. If the build fails with "cannot find type 'ErrorRecoveryCoordinator'" or "cannot find type 'CompletionAsyncError'" anywhere, two cases:

- If it's `ErrorRecoveryCoordinator` in a file not in Step 7's list: a missed consumer — add `import CodeEditorCommon` to that file.
- If it's `CompletionAsyncError` anywhere: the spec audit was wrong; pre-flight Step 3 should have caught it. Surface to the user.

- [ ] **Step 9: Lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 10: Run targeted tests**

```bash
swift test --filter "ErrorRecovery\|ActorCoordinator\|AsyncSyntaxHighlighter\|TextProcessing"
```

Expected: all tests pass. The `CancellationError()` swap (Step 2) is in a practically-unreachable code path; tests should not exercise it directly, but any test that does (`SyntaxHighlightingError.cancelled` equality assertion) would now fail — investigate and document if it surfaces.

- [ ] **Step 11: Commit**

```bash
git add Sources/CodeEditorCommon/ErrorRecoveryCoordinator.swift Sources/CodeEditorPlugin/Core/AsyncOperationErrors.swift
git commit -m "$(cat <<'EOF'
Split AsyncOperationErrors: delete CompletionAsyncError, relocate ErrorRecoveryCoordinator (§6.2.12c prep)

CompletionAsyncError (public enum, 140 LOC, 6 recovery-strategy cases)
had zero in-tree callers — deleted. CompletionAsyncError was an
early completion-error design that was never wired up.

ErrorRecoveryCoordinator (public actor coordinating retry / fallback /
backoff strategies) relocated from umbrella Core/AsyncOperationErrors.swift
to CodeEditorCommon/ErrorRecoveryCoordinator.swift. Its sole umbrella
dependency was a SyntaxHighlightingError.cancelled fallback in a
practically-unreachable code path; swapped for CancellationError() so
the file is pure-CodeEditorCommon. RecoverableAsyncError + RecoveryStrategy
+ BackoffStrategy already live in CodeEditorCommon (§6.2.7).

Three callers (ActorCoordinator, AsyncSyntaxHighlighter,
TextProcessingActor) already import CodeEditorCommon — zero new
import edits.

AsyncOperationErrors.swift was renamed to ErrorRecoveryCoordinator.swift
during the move (file no longer holds a "bag of async errors"; its
sole remaining type is the recovery coordinator).

Second public-API removal in the §6.2.12-prep series.

Closes the fifth and final §6.2.12c move/delete.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit. `git log -1 --stat` shows a rename + content edit (one file removed from umbrella, one added to Common, ~155 LOC net deletion from `CompletionAsyncError`).

---

## Task 7: End-of-chunk verification

**Files:** none modified.

- [ ] **Step 1: Full build**

```bash
swift build
```

Expected: `Build complete!` with no warnings introduced by this branch.

- [ ] **Step 2: Full lint**

```bash
swiftlint --fix && swiftlint
```

Expected: zero violations. SwiftLint's strict mode is on per CLAUDE.md.

- [ ] **Step 3: Full test suite**

```bash
swift test --parallel
```

Expected: all tests pass. Per the user memory "skip full `swift test --parallel` after additive-only steps; trust the build and run targeted tests instead" — this is the end-of-chunk gate to catch anything the per-task targeted runs missed.

If any unexpected failures surface, do **not** mark Task 7 complete. Diagnose:

- **Stale snapshot in `__Snapshots__/`?** Inspect the diff; if a file move caused a content-only change to a snapshot, that's a real regression — investigate, do not blindly re-record.
- **Stale path string in `ReviewRemediationRegressionTests`?** Same pattern as §6.2.8e / §6.2.12a — update the path string in a new commit (do not amend).
- **A consumer file missed by the bare-word grep?** Add the import in a follow-up commit referencing the missed file.

- [ ] **Step 4: Verify file-count math**

```bash
echo "Core/ root files (expected: 60 - 9 = 51 standalone-service files; total root including Bucket-1 stay-set ≈ 80):"
find Sources/CodeEditorPlugin/Core -maxdepth 1 -name "*.swift" | wc -l
echo "Core/ subtree total (expected: 118):"
find Sources/CodeEditorPlugin/Core -name "*.swift" | wc -l
echo "Umbrella source tree total (expected: 214):"
find Sources/CodeEditorPlugin -name "*.swift" | wc -l
echo "Common total (expected: 8 root + 4 subdirs):"
find Sources/CodeEditorCommon -maxdepth 1 -name "*.swift" | wc -l
```

Expected: Core/ subtree = 118 (was 126 pre-§6.2.12c), umbrella source tree = 214 (was 222), Common root = 8 (was 4 — gains `SelectionState`, `EditorInteractionState`, `DirtyTracker`, `ErrorRecoveryCoordinator`). If the numbers differ from these targets by ±1, the §6.2.12b baseline was slightly off — record the actuals and use them in Task 8's NEXT.md / CLAUDE.md edits.

- [ ] **Step 5: Final commit-history sanity**

```bash
git log --oneline -8
```

Expected output shape (top 7 entries should be):

```
<docs-hash>  Document §6.2.12c Core/ prep v3 in NEXT.md and CLAUDE.md   (after Task 8)
<c5-hash>    Split AsyncOperationErrors: delete CompletionAsyncError, relocate ErrorRecoveryCoordinator (§6.2.12c prep)
<c4-hash>    Delete TextSystem dead-code cluster (§6.2.12c prep)
<c3-hash>    Relocate DirtyTracker to CodeEditorCommon (§6.2.12c prep)
<c2-hash>    Relocate EditorInteractionState to CodeEditorCommon (§6.2.12c prep)
<c1-hash>    Relocate SelectionState to CodeEditorCommon (§6.2.12c prep)
04777cb      Add §6.2.12c Core/ prep v3 design
5d19e595     Document §6.2.12b Core/ prep v2 extraction in NEXT.md and CLAUDE.md
```

(The docs-hash row appears after Task 8 completes.)

---

## Task 8: NEXT.md + CLAUDE.md updates (Commit 6)

**Files:**
- Modify: `NEXT.md` (§6.0 status header, §6.0 status table, new §6.2.12c deviations block, §6.2.12a root-file triage table row flips + dead-code note, summary line, §10 first bullet)
- Modify: `CLAUDE.md` (source-tree line count, `CodeEditorCommon` bullet, new "What Will Go Wrong" entry)

The current state of these documents was set in commit `5d19e595` "Document §6.2.12b Core/ prep v2 extraction in NEXT.md and CLAUDE.md". The §6.2.12c edits parallel that update.

- [ ] **Step 1: Capture the 5 commit hashes**

```bash
git log --oneline -7
```

Record the §6.2.12c commit hashes (excluding the spec commit `04777cb` and the §6.2.12b doc commit `5d19e595`):

- `<c1>` — Task 2 (SelectionState)
- `<c2>` — Task 3 (EditorInteractionState)
- `<c3>` — Task 4 (DirtyTracker)
- `<c4>` — Task 5 (TextSystem cluster delete)
- `<c5>` — Task 6 (AsyncOperationErrors split)

Use the short-hash form (first 7 chars) below.

- [ ] **Step 2: Edit `NEXT.md` §6.0 status header**

Find the existing line near the start of §6.0:

> **Phases 0–5 done; phase 7 carved out.** ... `§6.2.12a` / `§6.2.12b Core/ prep` extractions.

Append `/ §6.2.12c` so the trailing phrase reads: "`§6.2.12a` / `§6.2.12b` / `§6.2.12c Core/ prep` extractions."

- [ ] **Step 3: Add a new row to the §6.0 status table**

Find the table row for §6.2.12b. Add the following row immediately below it:

```markdown
| `§6.2.12c Core/ prep` | `<c1>`, `<c2>`, `<c3>`, `<c4>`, `<c5>` | 3 files relocated from umbrella `Core/` to `CodeEditorCommon/` (`SelectionState`, `EditorInteractionState`, `DirtyTracker`). 1 file split + renamed: `CompletionAsyncError` deleted (dead public enum, 140 LOC, zero in-tree callers); `ErrorRecoveryCoordinator` relocated from umbrella `Core/AsyncOperationErrors.swift` to `CodeEditorCommon/ErrorRecoveryCoordinator.swift` with `SyntaxHighlightingError.cancelled → CancellationError()` swap. 4-file `TextSystem` dead-code cluster deleted (`TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, `TokenSystemValidator`). 4 access-modifier promotions on `DirtyTracker` (struct + 3 methods, plus explicit `public init()`). 1 Package.swift edit (`CodeEditorUITests` gains `CodeEditorCommon` dep). Core/ shrinks 126 → 118 (-8, -6.3%). First §6.2.12-prep round with public-API removals (5 types — TextSystem cluster + CompletionAsyncError). See §6.2.12c deviation block. | (no new target) |
```

Substitute the actual commit hashes from Step 1.

- [ ] **Step 4: Add a new "Deviations during §6.2.12c" block**

Locate the existing `**Deviations during §6.2.12b ` `Core/` ` prep (commits …):**` block. Immediately **after** it ends and **before** the `**§6.2.12a F3 sub-bucket audit table.**` heading, insert a new block:

```markdown
**Deviations during §6.2.12c `Core/` prep (commits `<c1>`, `<c2>`, `<c3>`, `<c4>`, `<c5>`):**

- **Spec / plan / execution count: 9 → 9 → actual.** 4 moves + 5 deletions (4 cluster + 1 split-and-rename). Record any drift.
- **Three Bucket A moves to `CodeEditorCommon`.** `SelectionState` (zero-touch, already public), `EditorInteractionState` + `EditorCursorPosition` (zero-touch, already public), `DirtyTracker` (5 promotions: struct + explicit `public init()` + 3 methods, all internal → public).
- **Four Bucket B deletions confirmed dead in-tree.** `protocol TextSystem` had zero conformers anywhere; the 3 generic classes referenced only each other. First public-API removal in the §6.2.12-prep series (5 types removed counting `CompletionAsyncError`). Matches §6.2.9a Debugger deletion precedent.
- **Bucket C split.** `CompletionAsyncError` (public enum, zero in-tree callers, ~140 LOC) deleted. `ErrorRecoveryCoordinator` relocated to `CodeEditorCommon`. The line-258 `SyntaxHighlightingError.cancelled` fallback (practically-unreachable code path) swapped for `CancellationError()` so the file is pure-`CodeEditorCommon`. `AsyncOperationErrors.swift` renamed to `ErrorRecoveryCoordinator.swift` during the move.
- **Promotion surface: 4** (DirtyTracker struct + 3 methods) or **5** including the explicit `public init()`. Smaller than §6.2.12a TextLayoutFragment (4), ties §6.2.12b Workspace pattern of single-file low-promotion moves.
- **Productization unchanged.** No new `.library` products.
- **Consumer ripple counts** (per commit `git log -1 --stat`):
  - **Commit 1 SelectionState → Common (`<c1>`):** 5 files gain `import CodeEditorCommon` (`Core/EditorStateBridge`, `Core/EditorState`, `EditorStateTests`, `EditorStateConformanceTests`, `EditorStatusBarSnapshots`). 1 Package.swift edit (`CodeEditorUITests` gains `CodeEditorCommon` dep). CoordinatorsExtensions already had the import.
  - **Commit 2 EditorInteractionState → Common (`<c2>`):** 16 files gain `import CodeEditorCommon` (2 Core/Documents + 7 SwiftUI + 1 Sample + 7 plugin tests). CoordinatorsExtensions already had it. Zero Package.swift edits (UITests dep added in Commit 1).
  - **Commit 3 DirtyTracker → Common (`<c3>`):** Zero new imports (single consumer already imports Common). 5 access-modifier promotions on the moved file.
  - **Commit 4 TextSystem cluster delete (`<c4>`):** Zero imports. 4 files removed, ~410 LOC.
  - **Commit 5 AsyncOperationErrors split (`<c5>`):** Zero new imports (all 3 ErrorRecoveryCoordinator callers already imported Common). ~155 LOC removed (CompletionAsyncError).
- **First §6.2.12-prep round with public-API removals.** 5 types removed from the umbrella public surface: `TextSystem`, `TextSystemStyler<Interface>`, `ThreePhaseTextSystemStyler<Interface>`, `TokenSystemValidator<Interface>`, `CompletionAsyncError`. Matches §6.2.9a Debugger / §6.2.8d `selectMatch` precedents.
- **Soft public-API relocation.** `ErrorRecoveryCoordinator` moved from umbrella to `CodeEditorCommon`. External consumers that `import CodeEditorPlugin` continue to see it via the umbrella's transitive `CodeEditorCommon` dep; consumers that need to mention it directly should `import CodeEditorCommon`. Documented in `CLAUDE.md` "What Will Go Wrong."
- **No new test targets.** Per-target test split remains deferred to §6.2.15.
- **Net Core/ file count drop:** 126 → 118 (-8, -6.3%). Umbrella source tree: 222 → 214 (-3.6%).
```

If any of the above bullets is inaccurate vs. what actually landed, edit the bullet to match reality before committing.

- [ ] **Step 5: Flip 3 rows + add a deletions note in the §6.2.12a root-file triage table**

Find the `**§6.2.12a root-file triage table.**` table.

Three rows currently classified as Bucket 3 ("Defer") need to flip:

For `SelectionState.swift`:

```markdown
| `SelectionState.swift` | Bucket 2: Move (zero-touch) | `CodeEditorCommon/` | Moved in `<c1>` (§6.2.12c) |
```

For `EditorInteractionState.swift` (the existing row groups it with `EditorState/EditorStateBridge/SelectionState (state cluster)`; split that row if needed and add):

```markdown
| `EditorInteractionState.swift` | Bucket 2: Move (zero-touch) | `CodeEditorCommon/` | Moved in `<c2>` (§6.2.12c) |
```

For `DirtyTracker.swift`:

```markdown
| `DirtyTracker.swift` | Bucket 2: Move (cheap-break — 4 internal → public promotions + explicit `public init()`) | `CodeEditorCommon/` | Moved in `<c3>` (§6.2.12c) |
```

For `AsyncOperationErrors.swift` (currently Bucket 3 Defer):

```markdown
| `AsyncOperationErrors.swift` | Split + Deleted | Source file replaced by `CodeEditorCommon/ErrorRecoveryCoordinator.swift`; `CompletionAsyncError` deleted as dead code | Renamed-and-relocated in `<c5>` (§6.2.12c) |
```

Add a single new row noting the dead-code-cluster deletion (placed near the bottom of the table or grouped with the TextKit2-orchestration cluster row currently there):

```markdown
| `TextSystem.swift`, `TextSystemStyler.swift`, `ThreePhaseTextSystemStyler.swift`, `TokenSystemValidator.swift` | Bucket 4: Deleted (dead code) | — | Deleted in `<c4>` (§6.2.12c). Verified zero in-tree conformers/consumers. |
```

(If the existing `TextEditingService, TextKitSetupHelper, TextSystem, TextSystemStyler, ThreePhaseTextSystemStyler, TokenSystemValidator (TextKit2 orchestration)` Bucket-3 row exists, edit it to remove the 4 deleted file names and leave `TextEditingService, TextKitSetupHelper (TextKit2 orchestration)` — those two stay deferred to §6.2.12.)

- [ ] **Step 6: Update the §6.2.12a root-file triage table summary line**

Find the existing summary line (currently):

> **Summary:** 65 root files audited at §6.2.12a start (...); 2 moved in §6.2.12a (...); 3 moved in §6.2.12b (...); 60 remain. Of the 60: 29 Bucket 1 Stay; 31 Bucket 3 Defer to §6.2.12.

Replace with:

> **Summary:** 65 root files audited at §6.2.12a start (plan-time inventory under-counted by 1; the actual root count is 65, not the spec's 64); 2 moved in §6.2.12a (`EditorConfiguration+ApplyTextInputFeatures`, `BreadcrumbComponent`); 3 moved in §6.2.12b (`SendableTypes`, `TabModel`, `LanguageDetectionService`); 4 moved + 5 deleted in §6.2.12c (`SelectionState`, `EditorInteractionState`, `DirtyTracker` to Common; `ErrorRecoveryCoordinator` to Common via rename; `TextSystem` cluster of 4 + `CompletionAsyncError` deleted); 51 remain. Of the 51: 29 Bucket 1 Stay; 22 Bucket 3 Defer to §6.2.12.

- [ ] **Step 7: Update §10's first bullet**

Find the `**6.2.12 split `Core/`**` bullet near the bottom of NEXT.md. Two edits:

(a) Update the file count: "The `Core/` dir is 126 files post-§6.2.12b (down from 138; §6.2.12a removed 9; §6.2.12b removed 3 more)" → "The `Core/` dir is 118 files post-§6.2.12c (down from 138; §6.2.12a removed 9; §6.2.12b removed 3; §6.2.12c removed 8 = 3 moves + 4 deletions + 1 split-rename)."

(b) Update the Bucket-3 count: "31 standalone-service files awaiting §6.2.12 disposition" → "22 standalone-service files awaiting §6.2.12 disposition."

(c) Replace the closing sentence "§6.2.12b moved the 3 §6.2.12a-flagged files; the priority worklist for the main split is now the remaining 31 Bucket 3 Defer files." with "§6.2.12b moved the 3 §6.2.12a-flagged files; §6.2.12c moved 4 more state/coordinator files and deleted 5 dead public types; the priority worklist for the main split is now the remaining 22 Bucket 3 Defer files."

- [ ] **Step 8: Edit `CLAUDE.md` — source-tree count**

Find the line: "5 top-level directories in the umbrella target, 222 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a / §6.2.12b), and 589 Swift source files under `Sources/`."

Edit to: "5 top-level directories in the umbrella target, 214 Swift source files in the umbrella target (down from 480 before phase 0–4 extractions and §6.2.7 / §6.2.8a / §6.2.8b / §6.2.8d / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.11 / §6.2.12a / §6.2.12b / §6.2.12c), and 585 Swift source files under `Sources/`."

(Total `Sources/` drops from 589 to 585 — 5 file deletions; the 4 moves stay within `Sources/`. Verify with `find Sources -name '*.swift' | wc -l`; use the actual number from Task 7 Step 4.)

- [ ] **Step 9: Edit `CLAUDE.md` — `CodeEditorCommon` bullet**

Find: "`Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7); `SendablePerformanceMetric` + `FileChangeNotification` (added §6.2.12b)."

Edit to: "`Sources/CodeEditorCommon/` — utilities, models, extensions, errors, `RecoverableAsyncError`+`RecoveryStrategy`+`BackoffStrategy` infra (phase 0; expanded in §6.2.7); `SendablePerformanceMetric` + `FileChangeNotification` (added §6.2.12b); `SelectionState` + `EditorInteractionState` + `EditorCursorPosition` + `DirtyTracker` + `ErrorRecoveryCoordinator` (added §6.2.12c — `ErrorRecoveryCoordinator` relocated from umbrella `Core/AsyncOperationErrors.swift`; that file held a now-dead `CompletionAsyncError` that was deleted)."

- [ ] **Step 10: Edit `CLAUDE.md` — add "What Will Go Wrong" entries**

Find the `## What Will Go Wrong` section. Add the following new bullets at the end of the section (before the next `##` heading):

```markdown
- **`TextSystem` protocol and its styler classes were deleted in §6.2.12c.** `TextSystem`, `TextSystemStyler`, `ThreePhaseTextSystemStyler`, and `TokenSystemValidator` were earlier TextKit2 styling-experiment scaffolding with zero in-tree consumers — deleted, not extracted. External consumers depending on these need to remove the dependency.

- **`CompletionAsyncError` was deleted in §6.2.12c.** Public enum with zero in-tree callers. External consumers pattern-matching on `CompletionAsyncError.providerNotAvailable(_:)` (etc.) need to switch to whatever they ultimately mapped it to.

- **`ErrorRecoveryCoordinator` moved to `CodeEditorCommon` in §6.2.12c.** Previously umbrella-public, now lives in `CodeEditorCommon/ErrorRecoveryCoordinator.swift`. External consumers doing `import CodeEditorPlugin` continue to see it via the umbrella's transitive dep on `CodeEditorCommon`; consumers that need direct access should `import CodeEditorCommon`. The line-258 fallback error type changed from `SyntaxHighlightingError.cancelled` to `CancellationError()` (the path is practically-unreachable; callers should not depend on the specific error type).

- **`SelectionState`, `EditorInteractionState`, `EditorCursorPosition`, `DirtyTracker` moved to `CodeEditorCommon` in §6.2.12c.** Same soft-relocation pattern as `ErrorRecoveryCoordinator`. Test targets that previously reached these via `@testable import CodeEditorPlugin` need to add `import CodeEditorCommon`.
```

- [ ] **Step 11: Build + lint sanity (docs commit only)**

Docs-only changes can't break the build, but run a sanity pass:

```bash
git status
git diff --stat
```

Expected: only `NEXT.md` and `CLAUDE.md` modified.

- [ ] **Step 12: Commit**

```bash
git add NEXT.md CLAUDE.md
git commit -m "$(cat <<'EOF'
Document §6.2.12c Core/ prep v3 in NEXT.md and CLAUDE.md

Record the 3 moves + 1 split-rename + 4 deletions in NEXT.md §6.0
status table and a new §6.2.12c deviations block. Flip 4 rows in the
§6.2.12a root-file triage table from Bucket 3 Defer to Moved /
Split+Deleted. Add a deletions row for the TextSystem cluster. Update
the summary line and §10's first bullet (Core/ now 118 files; 22
Bucket 3 Defer remaining).

Update CLAUDE.md source-tree counts (umbrella 222 → 214) and the
CodeEditorCommon bullet to mention the relocated symbols. Add four
"What Will Go Wrong" entries — three covering the public-API removals
(TextSystem cluster, CompletionAsyncError, ErrorRecoveryCoordinator
soft relocation) and one for the state-type relocations.

First §6.2.12-prep round with public-API removals.

Closes §6.2.12c.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] Document §6.2.12c Core/ prep v3 in NEXT.md and CLAUDE.md`. `git status` reports clean. Six commits total in §6.2.12c (5 moves/deletes + 1 docs).

- [ ] **Step 13: Final sanity log**

```bash
git log --oneline -8
```

Expected output shape (top 7 entries):

```
<docs-hash>  Document §6.2.12c Core/ prep v3 in NEXT.md and CLAUDE.md
<c5-hash>    Split AsyncOperationErrors: delete CompletionAsyncError, relocate ErrorRecoveryCoordinator (§6.2.12c prep)
<c4-hash>    Delete TextSystem dead-code cluster (§6.2.12c prep)
<c3-hash>    Relocate DirtyTracker to CodeEditorCommon (§6.2.12c prep)
<c2-hash>    Relocate EditorInteractionState to CodeEditorCommon (§6.2.12c prep)
<c1-hash>    Relocate SelectionState to CodeEditorCommon (§6.2.12c prep)
04777cb      Add §6.2.12c Core/ prep v3 design
5d19e595     Document §6.2.12b Core/ prep v2 extraction in NEXT.md and CLAUDE.md
```

§6.2.12c is complete. The next chunk is §6.2.12 main (the riskiest single step), per NEXT.md §10.

---

## Self-Review Notes (for plan author)

Coverage check vs. spec:

- **Spec §1 (goal & shape):** Tasks 2–6 implement the 5 source actions; Task 7 verifies; Task 8 records in docs.
- **Spec §2.1 Bucket A:** Tasks 2 / 3 / 4 implement SelectionState / EditorInteractionState / DirtyTracker moves respectively.
- **Spec §2.2 Bucket B:** Task 5 deletes the TextSystem cluster.
- **Spec §2.3 Bucket C:** Task 6 splits AsyncOperationErrors.swift.
- **Spec §3 commit shape:** mapping is 1:1 — Tasks 2 → Commit 1, Task 3 → Commit 2, Task 4 → Commit 3, Task 5 → Commit 4, Task 6 → Commit 5, Task 8 → Commit 6.
- **Spec §4 aggregate surface:** Task 7 Step 4 verifies the file-count math (126 → 118; +4 in Common).
- **Spec §5 NEXT.md / CLAUDE.md edits:** every edit in §5 maps to a concrete step in Task 8.
- **Spec §6 risks 1–8:** addressed inline:
  - Risk 1 (Bucket B public-API removal) — covered by Task 5 Step 1 re-verify + Task 8 Step 10 "What Will Go Wrong" addition.
  - Risk 2 (CompletionAsyncError removal) — Task 6 Step 1 inherently deletes it.
  - Risk 3 (error-semantics tweak) — Task 6 Step 2 makes the swap explicitly, Step 10 reruns targeted tests.
  - Risk 4 (bare-word grep) — Task 1 Step 3 runs all bare-word greps.
  - Risk 5 (stale-path strings) — Task 1 Step 4 scans for them.
  - Risk 6 (cross-module Codable) — Task 3 Step 8 runs the binding test explicitly.
  - Risk 7 (`@testable` defensive retention) — Step 3 of Tasks 2 and 3 both call out not dropping `@testable`.
  - Risk 8 (broken-rename-commit) — Task 6 edits content (Steps 1–4) before running `git mv` (Step 6).
- **Spec §7 open questions:** non-decisions (DirtyTracker placement, file-rename strategy, deletion granularity, per-target tests, version-gate cleanup) settled in spec — no plan steps needed.
- **Spec §8 after this chunk:** plan ends at Task 8 Step 13 with a forward-link to §6.2.12 main.

Placeholder scan: the only `<placeholder>` strings are the 5 commit hashes captured in Task 8 Step 1 — these are runtime values, not unfilled spec items. All test commands, file paths, edit content, and commit messages are filled.

Type consistency: file paths use canonical `Sources/CodeEditorPlugin/Core/...`, `Sources/CodeEditorCommon/...`, `Tests/CodeEditorPluginTests/...`, `Tests/CodeEditorUITests/...` forms throughout. Module names are spelled `CodeEditorCommon`, `CodeEditorLanguages`, `CodeEditorPlugin`, `CodeEditorUI`, `CodeEditorUITests`, `CodeEditorSample`, `CodeEditorPluginTests`, `CodeEditorSampleTests` consistently. Type names match between tasks: `DirtyTracker` (not `DirtyTrackingState`); `ErrorRecoveryCoordinator` (not `RecoveryCoordinator`); `CompletionAsyncError` (not `AsyncCompletionError`); `SelectionState`, `EditorInteractionState`, `EditorCursorPosition` exact.
