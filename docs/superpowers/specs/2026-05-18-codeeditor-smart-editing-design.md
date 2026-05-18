# §6.2.8c `CodeEditorSmartEditing` extraction — design

**Date:** 2026-05-18
**Section:** NEXT.md §6.2.8c (closes §6.2.8 feature engines)
**Status:** Approved — ready for plan
**Predecessors:** §6.2.8a Folding, §6.2.8b Symbols, §6.2.8d Search, §6.2.8e Annotations, §6.2.8f Workspace, §6.2.8g Completion, §6.2.12 `CodeEditorView`

## 1. Goal

Move the 5 SmartEditing source files out of the umbrella `CodeEditorPlugin` target into a new SPM target `CodeEditorSmartEditing`. Match the §6.2 "one product per concern" pattern. Close the §6.2.8 feature-engine extraction series.

This is import-graph surgery, not feature work. No behavior change.

## 2. Scope

### 2.1 Files moved (5)

| From | To | LOC |
|---|---|---|
| `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift` | `Sources/CodeEditorSmartEditing/SmartEditingEngine.swift` | 310 |
| `Sources/CodeEditorPlugin/Features/SmartEditing/AutoBracketingEngine.swift` | `Sources/CodeEditorSmartEditing/AutoBracketingEngine.swift` | 102 |
| `Sources/CodeEditorPlugin/Features/SmartEditing/MultiCursorEditor.swift` | `Sources/CodeEditorSmartEditing/MultiCursorEditor.swift` | 117 |
| `Sources/CodeEditorPlugin/Features/SmartEditing/SmartIndentationEngine.swift` | `Sources/CodeEditorSmartEditing/SmartIndentationEngine.swift` | 79 |
| `Sources/CodeEditorPlugin/Features/SmartEditing/SmartSelectionExpander.swift` | `Sources/CodeEditorSmartEditing/SmartSelectionExpander.swift` | 137 |

Total: 5 files, ~745 LOC.

The `SmartEditing/` subfolder is flattened — the target name is the namespace, matching every other extracted target (no `Sources/CodeEditorLayout/Layout/`, etc.).

### 2.2 Public surface (unchanged)

After the move, every existing public type continues to exist with the same name and the same access level:

- `SmartEditingEngine` (class, `@MainActor`, `ObservableObject`)
- `MultiCursorEditor` (class, `@MainActor`)
- `AutoBracketingEngine` (enum, `@MainActor`)
- `SmartIndentationEngine` (enum, `@MainActor`)
- `SmartSelectionExpander` (enum, `@MainActor`)
- `SmartEditingConfiguration` (struct)
- `SmartEditingBracketPair` (struct)
- `TextCursor` (struct)
- `AutoIndentRule` (struct, with nested `IndentAction` enum)
- `SmartEditingConfiguration.SelectionStop` (nested enum)

Consumers doing `import CodeEditorPlugin` continue to see all of these through the umbrella's transitive `CodeEditorSmartEditing` dep.

### 2.3 Carve-out: none

Clean full extraction. No `Core/SmartEditing/` residue, no `Sources/CodeEditorPlugin/Features/SmartEditing/` leftovers. After the move, `Sources/CodeEditorPlugin/Features/` is empty and gets deleted.

This is the smallest extraction in the §6.2.8 series (Workspace was 2 files; Search was 1; SmartEditing is 5 but cleanest because all 5 already had the `import CodeEditorView` from §6.2.12 — they were always single-target-consumer code).

## 3. Target definition

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
)
```

### 3.1 Dep rationale

Each dep is justified by an actual import in the moving set:

| Dep | Used by | What for |
|---|---|---|
| `CodeEditorCommon` | `SmartEditingEngine`, `MultiCursorEditor` | `CrossPlatformLogger.logger(...)` |
| `CodeEditorPlatform` | `SmartEditingEngine`, `AutoBracketingEngine`, `MultiCursorEditor`, `SmartSelectionExpander` | `#if canImport(AppKit)/(UIKit)` shims; `PlatformTextViewDelegate` typealias support |
| `CodeEditorTextModel` | `SmartIndentationEngine`, `SmartSelectionExpander` | `TextRangeUtilities.lineRange(...)`, `TextRangeUtilities.wordRange(...)` |
| `CodeEditorView` | All 5 files | `CodeEditorView` class, `textKitBridge`, `addDelegateParticipant`, `removeDelegateParticipant`, `TextViewDelegateParticipant` protocol |

No other deps needed. Specifically:
- **No `CodeEditorConfiguration`.** SmartEditing has its own `SmartEditingConfiguration`; it is not wired into `EditorConfiguration`.
- **No `CodeEditorDiagnostics`.** SmartEditing does not use the umbrella performance pipeline.
- **No `CodeEditorLanguages`.** SmartEditing uses generic bracket pairs / indent rules; no language descriptor consumption.

### 3.2 Productization: no opt-in `.library`

Routes through the umbrella per the §6.2.8g Completion / §6.2.8e Annotations / §6.2.8a Folding / §6.2.8b Symbols precedent: umbrella `CodeEditorPlugin` depends on `CodeEditorSmartEditing`; no `.library(name: "CodeEditorSmartEditing", ...)` entry in `Package.swift` products.

Rationale: SmartEditing is core editor behavior (auto-bracket, auto-indent, multi-cursor selection expansion) that most editor hosts want. Workspace/Search/LSP/Diagnostics were opt-in because they have substantial weight (process management, file watchers) that some hosts genuinely don't want. SmartEditing is ~745 LOC of pure-Swift logic — the cost of bundling is negligible.

After §6.2.14 (umbrella re-export), the umbrella's `CodeEditorPlugin.swift` will gain `@_exported import CodeEditorSmartEditing` so external consumers can mention `SmartEditingEngine` etc. from `import CodeEditorPlugin`. Today that already works through the umbrella because the umbrella target imports the dep transitively.

### 3.3 Phase

Semantic label: **Phase 4 (feature engine)**, matching Completion / Folding / Symbols / Annotations.

Build-graph slot: **Phase 9** (the most downstream feature engine), because `CodeEditorView` is at phase 8. SmartEditing is the only feature engine that hard-depends on `CodeEditorView`; the others were extracted before `CodeEditorView` was carved out and so don't depend on it.

## 4. Consumer ripple

| Consumer | Files affected | Action |
|---|---|---|
| Umbrella `CodeEditorPlugin` target | 0 source files | `Package.swift`: add `"CodeEditorSmartEditing"` to `dependencies:`. No new imports — the only 2 references in `Sources/CodeEditorView/` are `//` doc-comment mentions (`TextKitSetupHelper.swift:77`, `TextViewDelegateParticipant.swift:17`) that compile without an import. |
| Umbrella source tree | `Sources/CodeEditorPlugin/Features/` directory | Deleted (was: 1 root file + `SmartEditing/` subfolder containing 4 files + `.DS_Store`). |
| `CodeEditorUI` | 0 | No change. |
| `CodeEditorSample` | 0 | No change. SmartEditing is not used by the sample app today. |
| `CodeEditorPluginTests` | 2 files + Package.swift | `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift` and `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift` each gain `import CodeEditorSmartEditing`. `Package.swift`: add `"CodeEditorSmartEditing"` to `CodeEditorPluginTests` `dependencies:`. |
| `CodeEditorSampleTests` | 0 | No change. |
| `CodeEditorUITests` | 0 | No change. |
| `CodeEditorDesignTokensTests` | 0 | No change. |

**Total ripple: 5 source-file moves + 2 test-file edits + 1 Package.swift edit (with 2 target dep additions).**

Smallest in the §6.2.8 series.

### 4.1 Test `@testable` handling

Both affected tests already use `@testable import CodeEditorView` (gained during §6.2.12). They keep both `@testable import CodeEditorPlugin` and `@testable import CodeEditorView` defensively per the §6.2.8d "don't blanket-drop @testable" lesson — but neither needs `@testable import CodeEditorSmartEditing` because the test surface is entirely `public` (`SmartEditingEngine()` and its `public` methods).

If pre-flight Step 3 of the plan finds an internal-symbol reach the audit missed, the test gains `@testable import CodeEditorSmartEditing` and a promotion is avoided.

SwiftLint's `sorted_imports` rule will slot `import CodeEditorSmartEditing` alphabetically between `CodeEditorPlugin` and the next module starting with `T` (`CodeEditorTesting` / `CodeEditorView`).

## 5. Access-modifier audit

### 5.1 Already public — no promotion needed

| Symbol | Kind | Today | Source |
|---|---|---|---|
| `SmartEditingEngine` | class | `public final class` + `override public init()` | `SmartEditingEngine.swift:19,50` |
| `SmartEditingEngine.configuration` | property | `@Published public var` | `:30` |
| `SmartEditingEngine.isMultiCursorMode` | property | `@Published public private(set) var` | `:31` |
| `SmartEditingEngine.cursors` | computed property | `public var` | `:34` |
| `SmartEditingEngine.attach(to:)` | method | `public func` | `:64` |
| `SmartEditingEngine.detach()` | method | `public func` | `:72` |
| `SmartEditingEngine.addCursor(at:)` | method | `public func` | `:95` |
| `SmartEditingEngine.addCursorsAtOccurrences()` | method | `public func` | `:102` |
| `SmartEditingEngine.clearMultiCursors()` | method | `public func` | `:109` |
| `SmartEditingEngine.expandSelection()` | method | `public func` | `:118` |
| `MultiCursorEditor` | class | `public final class` + `public init()` | `MultiCursorEditor.swift:10,26` |
| `MultiCursorEditor.cursors` | property | `public private(set) var` | `:14` |
| `MultiCursorEditor.isMultiCursorMode` | computed | `public var` | `:17` |
| `MultiCursorEditor.addCursor(at:)` | method | `public func` | `:32` |
| `MultiCursorEditor.addCursorsAtOccurrences(in:)` | method | `public func` | `:44` |
| `MultiCursorEditor.clearAllCursors()` | method | `public func` | `:75` |
| `MultiCursorEditor.handleInput(_:in:)` | method | `public func` | `:86` |
| `MultiCursorEditor.updateVisuals()` | method | `public func` | `:113` |
| `AutoBracketingEngine` | enum | `public enum` | `AutoBracketingEngine.swift:9` |
| `AutoBracketingEngine.handleCharacterInsertion(_:at:in:bracketPairs:configuration:)` | static func | `public static func` | `:20` |
| `SmartIndentationEngine` | enum | `public enum` | `SmartIndentationEngine.swift:9` |
| `SmartIndentationEngine.calculateIndentation(at:in:rules:configuration:)` | static func | `public static func` | `:19` |
| `SmartIndentationEngine.defaultRules()` | static func | `public static func` | `:70` |
| `SmartSelectionExpander` | enum | `public enum` | `SmartSelectionExpander.swift:10` |
| `SmartSelectionExpander.expandSelection(in:)` | static func | `public static func` | `:15` |
| `SmartSelectionExpander.expandToWord(from:in:)` | static func | `public static func` | `:35` |
| `SmartSelectionExpander.expandToLine(from:in:)` | static func | `public static func` | `:47` |
| `SmartSelectionExpander.expandToBrackets(from:in:)` | static func | `public static func` | `:59` |
| `SmartEditingBracketPair` | struct | `public struct` + `public init(open:close:isQuote:)` | `SmartEditingEngine.swift:221,234` |
| `AutoIndentRule` | struct | `public struct` + synth init (same-target use only) | `SmartEditingEngine.swift:242` |
| `AutoIndentRule.IndentAction` | nested enum | `public enum` | `:249` |
| `TextCursor` | struct | `public struct` + synth init (same-target use only) | `SmartEditingEngine.swift:210` |
| `SmartEditingConfiguration.SelectionStop` | nested enum | `public enum` | `:300` |

### 5.2 Single one-line fix: pre-existing API gap

`SmartEditingConfiguration` is `public` with `public var` fields. Per Swift's synthesized-init rules, the memberwise init for a public struct with default values is `internal`. Today the only constructor path is `engine.configuration` (same-target initializer). External hosts cannot do:

```swift
var config = SmartEditingConfiguration()  // fails: 'init' is internal
config.autoInsertBrackets = false
engine.configuration = config
```

This is a pre-existing API gap (predates this restructure), and it stays a gap after the extraction unless we fix it. Per the project memory **"Fix pre-existing failures, don't document them"**, add a one-line `public init() {}` to `SmartEditingConfiguration` as part of this commit. Same pattern as §6.2.8b Symbols (`SymbolNavigationConfiguration`, `BreadcrumbItem`), §6.2.8g Completion (`CompletionStatistics`), §6.2.12c (`DirtyTracker`, `ErrorRecoveryCoordinator`).

`TextCursor` and `AutoIndentRule` have the same gap but are not externally-constructible by design (constructed inside the engines). Leave alone.

**Total promotion surface: 1 line** (adding `public init()` to `SmartEditingConfiguration`).

Ties §6.2.8d Search, §6.2.8e Annotations, §6.2.8f Workspace, §6.2.12b prep for smallest promotion surface in the §6.2 series — modulo the one-line pre-existing-bug fix.

### 5.3 Cross-target reach into `CodeEditorView` package symbols

The 5 SmartEditing files reach 3 `CodeEditorView` symbols that are not `public`:

| Symbol | Access | Reachable from `CodeEditorSmartEditing`? |
|---|---|---|
| `TextKitBridge` (class) | `package` (`Sources/CodeEditorView/Text/TextKitBridge.swift:20`) | Yes — same Swift package. |
| `CodeEditorView.textKitBridge` (property) | `package` (`Sources/CodeEditorView/CodeEditorView.swift:343`) | Yes — same Swift package. |
| `CodeEditorView.addDelegateParticipant` / `removeDelegateParticipant` | `package` (promoted in §6.2.12) | Yes — same Swift package. |
| `CodeEditorView.text` (property) | `public` (`Sources/CodeEditorView/CodeEditorView.swift:511`) | Yes — public. |
| `CodeEditorView.selectedRange` (property) | `public` (`NSTextView`/`UITextView` override) | Yes — public. |

`package`-visible symbols are cross-target-visible within the same Swift package (SwiftPM emits `-package-name CodeEditorPlugin` for all targets). No promotions required on `CodeEditorView`'s side.

## 6. `Package.swift` changes

1. **Add new target** after the existing `CodeEditorSearch` / `CodeEditorWorkspace` block (alphabetical / by-phase ordering — the file already mixes both conventions, just be consistent with neighbors):

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

2. **Add to umbrella `CodeEditorPlugin` target's `dependencies:`** in alphabetical position (between `"CodeEditorSearch"` and `"CodeEditorSymbols"` would be natural, but the umbrella does not currently include `CodeEditorSearch` or `CodeEditorWorkspace` — those are opt-in. So the slot is between `"CodeEditorPlatform"` and `"CodeEditorSymbols"` alphabetically — but actually `Sm` sorts between `Pl` and `Sy`). Final position: after `"CodeEditorPlatform"`, before `"CodeEditorSymbols"`.

3. **Add to `CodeEditorPluginTests` target's `dependencies:`** in alphabetical position (between `"CodeEditorSearch"` and `"CodeEditorSymbols"`).

4. **No `.library` product entry.** Not productized; routes through umbrella.

5. **Umbrella `exclude:` array.** Current value is `["Info.plist", "Languages", "Layout"]`. `Features` was NOT excluded before (because `Features/SmartEditing*.swift` were compiled into the umbrella). After the move, `Sources/CodeEditorPlugin/Features/` is empty (or contains only `.DS_Store`). Two options:

   - **(a) Delete the directory entirely** (preferred). Cleaner. `.DS_Store` goes with it. No `exclude:` change needed.
   - **(b) Keep an empty `Features/` and add `"Features"` to exclude.** Defensive but unnecessary.

   The plan should use option (a).

6. **No changes to `CodeEditorUI`, `CodeEditorSample`, `CodeEditorSampleTests`, `CodeEditorUITests`, `CodeEditorDesignTokensTests` targets.**

## 7. Commits

**Plan: 1 commit.** No pre-commit relocation (nothing to carve out). No clean-build fix anticipated (dep direction is forward; no circular risk).

Single commit covers:
1. `git mv Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift Sources/CodeEditorSmartEditing/SmartEditingEngine.swift`
2. `git mv Sources/CodeEditorPlugin/Features/SmartEditing/{AutoBracketingEngine,MultiCursorEditor,SmartIndentationEngine,SmartSelectionExpander}.swift Sources/CodeEditorSmartEditing/`
3. Delete `Sources/CodeEditorPlugin/Features/` (including `.DS_Store` and now-empty `SmartEditing/` subfolder)
4. Edit `Package.swift`: new target + 2 dep additions (umbrella + plugin tests)
5. Edit `Tests/CodeEditorPluginTests/ComprehensivePerformanceTests.swift`: add `import CodeEditorSmartEditing`
6. Edit `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift`: add `import CodeEditorSmartEditing`
7. Edit `Sources/CodeEditorSmartEditing/SmartEditingEngine.swift`: add `public init() {}` to `SmartEditingConfiguration`

**Git staging note** (per §6.2.12b TabModel lesson): `git mv` first, *then* stage destination paths in `git add`, so the rename detection doesn't get confused by partial staging.

**End-of-chunk verification:**

```
swift package clean && \
swift build && \
swiftlint --fix && swiftlint && \
swift test --parallel
```

Per the project memory **"don't over-run the test suite mid-plan"**, run targeted tests during plan execution (`swift test --filter SmartEditing`); the full parallel run is the end-of-chunk gate only.

## 8. Risks and known unknowns

1. **`MultiCursorEditor.updateVisuals()` is a no-op stub.** Documented as "Implementation depends on platform-specific drawing." Pre-existing dead-ish surface. Out of scope; leave alone. After the move it remains internally callable from `SmartEditingEngine` (same target).

2. **`@Published` requires Combine.** Combine is implicit when `SwiftUI` is imported. `SwiftUI` is not explicitly imported in `SmartEditingEngine.swift` today — but `@Published` compiles because it's exposed through `ObservableObject` (which requires `import Combine` implicitly). Post-move, the new target needs Combine reachable. Combine is available unconditionally on Apple platforms — no `Package.swift` `dependencies:` addition needed. Risk is low; would surface at compile time as a clear missing-`import Combine` error if it didn't work, and the fix is to add `import Combine` to `SmartEditingEngine.swift`.

3. **Cross-module strict-concurrency re-trigger risk.** §6.2.12 added `@unchecked Sendable` to `CodeEditorView` because cross-module `[weak]` captures of `@MainActor` types tripped the analyzer. SmartEditing uses `private weak var textView: CodeEditorView?` but only reads it synchronously inside `@MainActor` methods — no `Task { [weak textView] ... }` capture. Risk is low; would surface at compile time with a clear error. Mitigation if it fires: scope-extract `textView` into a local at method entry, matching the §6.2.12 pattern.

4. **`isMultiCursorMode` is `@Published public private(set)` set in `addCursor` / `clearMultiCursors` / similar.** Setting it from within the class is same-target — no concern.

5. **Sample app verification.** Per the project memory **NSTextView init invariant**, the spec'd sanity check is to launch the sample app and type a character after a clean build. SmartEditing is not attached in the sample app today (verified: zero references in `Sources/CodeEditorSample/`), so a smoke-test of typing is sufficient — no specific SmartEditing interaction to verify. The full `swift test --parallel` run is the primary correctness gate.

6. **`SmartEditingConfiguration.multiCursorModifierKey` is platform-conditional** (`NSEvent.ModifierFlags` on AppKit, `UIKeyModifierFlags` on UIKit). Post-move, the `#if canImport(AppKit)/(UIKit)` conditional inside `SmartEditingConfiguration` stays — that's expected and matches CLAUDE.md's `canImport` convention.

## 9. Documentation updates

### 9.1 `NEXT.md`

- **§6.0 status sentence:** add "SmartEditing extracted next as §6.2.8c, closing §6.2.8 feature engines."
- **§6.0 status table:** new row:
  ```
  | `CodeEditorSmartEditing` | <commit> | 5 files moved from umbrella `Features/` (`SmartEditingEngine`, `AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). Clean full extraction — no carve-out. Subfolder flattened. 1 pre-existing API-gap fix: `public init()` added to `SmartEditingConfiguration`. Not productized — routes through umbrella per Folding/Symbols/Annotations/Completion precedent. 0 sample / UI ripple; 2 test files + Package.swift only. | Common, Platform, TextModel, View |
  ```
- **§6.0 deviations block:** new "§6.2.8c CodeEditorSmartEditing (commit X)" subsection covering whatever surprises landed.
- **§6.2.8 sub-bullet `[deferred — blocked on §6.2.12]`:** flip to `[done — clean extraction, see §6.0]` with details.
- **§6.3:** unchanged — SmartEditing is not productized as opt-in, matches Completion/Folding/Symbols/Annotations precedent of not being listed.
- **§10:** drop the `6.2.8c CodeEditorSmartEditing` bullet from "Remaining work."

### 9.2 `CLAUDE.md`

- **Source tree section:** add `Sources/CodeEditorSmartEditing/` bullet under "Other source roots". Describe as: "5 files (`SmartEditingEngine` + 4 strategy engines: `AutoBracketingEngine`, `MultiCursorEditor`, `SmartIndentationEngine`, `SmartSelectionExpander`). Not productized — routes through umbrella. Final §6.2.8 feature-engine extraction."
- **Top of file source-tree summary:** drop the `Features/` mention from the `Sources/CodeEditorPlugin/` tree listing. The remaining top-level dirs are `Languages/`, `SwiftUI/`, `Resources/`. Update the file count tally.
- **"What Will Go Wrong" section:** add any new gotchas surfaced during execution (TBD at plan time).

### 9.3 Diagrams

If `docs/Diagrams/` mentions SmartEditing in any non-archived diagram, update to show it as its own target. (Pre-flight Step 1 of the plan: `grep -rn -i 'smart.editing' docs/Diagrams/` to verify.)

## 10. Non-goals (out of scope for this chunk)

- **Wiring SmartEditing into `EditorConfiguration`.** Today hosts construct `SmartEditingEngine()` explicitly and attach. Wiring would be a feature decision, not a restructure decision.
- **Adding sample-app SmartEditing demo.** The sample doesn't use SmartEditing today; adding a demo screen is out of scope.
- **`MultiCursorEditor.updateVisuals()` implementation.** Pre-existing stub; not in scope.
- **`TextCursor` / `AutoIndentRule` public init.** Pre-existing API gaps, but those types are not meant to be externally-constructed (they're built inside the engines). Leave alone.
- **Per-target test split (`CodeEditorSmartEditingTests`).** Deferred to §6.2.15 per established pattern. Tests stay in `CodeEditorPluginTests/`.
- **Productizing SmartEditing as opt-in `.library`.** Considered and rejected during brainstorming: SmartEditing is small (~745 LOC of pure Swift) and core editor behavior; the per-host opt-out value is too small to justify the public-API split. Routes through umbrella per Folding/Symbols/Annotations/Completion precedent.

## 11. Predecessor patterns this design follows

| Pattern | Source | Used here |
|---|---|---|
| Clean full extraction (no carve-out) | §6.2.5 Theming, §6.2.8f Workspace, §6.2.8g Completion, §6.2.12 CodeEditorView | All 5 SmartEditing files move; zero `Core/SmartEditing/` residue |
| Subfolder flattened | §6.2.8a Folding, §6.2.8b Symbols, §6.2.12 CodeEditorView | `SmartEditing/` subfolder dropped at destination |
| Routes through umbrella (not productized) | §6.2.8a Folding, §6.2.8b Symbols, §6.2.8e Annotations, §6.2.8g Completion | Umbrella depends; no opt-in `.library` |
| §4.1 dep claim was wrong | §6.2.5 / §6.2.8b / §6.2.8e / §6.2.8f / §6.2.8g / §6.2.9 / §6.2.10 / §6.2.11 / §6.2.12 | §4.1 listed `TextModel, Configuration` as SmartEditing deps; actual is `Common, Platform, TextModel, View` — same correction pattern |
| Pre-existing API-gap fix during extraction | §6.2.8b Symbols, §6.2.8g Completion, §6.2.12c | `SmartEditingConfiguration.init()` added |
| Don't blanket-drop `@testable` | §6.2.8d Search | Keep `@testable import CodeEditorPlugin` and `@testable import CodeEditorView` defensively on the 2 test files |
| `git mv` then stage destination | §6.2.12b TabModel | Single-commit move for all 5 files |
| `package`-visible cross-target reach within same Swift package | §6.2.12 (`addDelegateParticipant`, `TextViewDelegateParticipant`, etc.) | `TextKitBridge` (`package class`) + `textKitBridge` (`package var`) reachable from new target without further promotion |

## 12. Plan inputs

The implementation plan (`docs/superpowers/plans/2026-05-18-codeeditor-smart-editing-plan.md`) will derive task structure from this spec:

- **Task 1 — Pre-flight:** verify access modifiers (Step 5 above), grep for SmartEditing references project-wide, verify no docs/diagrams need updating, verify `Combine` import situation.
- **Task 2 — Scaffold + move:** create `Sources/CodeEditorSmartEditing/`; `git mv` 5 files; flatten the `SmartEditing/` subfolder.
- **Task 3 — Wire `Package.swift`:** new target + 2 dep additions + delete empty `Features/` directory.
- **Task 4 — Fix consumers:** add 2 imports to test files; add `public init()` to `SmartEditingConfiguration`.
- **Task 5 — Verify:** `swift package clean && swift build && swiftlint --fix && swiftlint && swift test --parallel`; sample-app smoke test; commit.
- **Task 6 — Docs:** update NEXT.md + CLAUDE.md.
