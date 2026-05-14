# SwiftUI Modifier Return Types — Design Spec

**Date:** 2026-05-14
**Status:** Spec
**Closes:** REVIEW.md "Inconsistent SwiftUI modifier return types" (the third of three "needs design" items from "What's left after this round")

## Problem

Public modifiers on `CodeEditor` split across two declaration shapes:

- **`extension View → some View`** — ~25 modifiers writing environment values (`.codeTheme`, `.codeLanguage`, `.lineNumbers`, `.performanceObserver`, `.activeDocument`, `.onTextHover`, etc.).
- **`extension CodeEditor → Self`** (five modifiers) — `onTextChange(perform:)`, `onSelectionChange(perform:)`, `codeCompletion(provider:)`, `editorController(_:)`, `editorInteractionState(_:)`. These mutate stored properties on the `CodeEditor` struct and return a modified copy.
- **`extension CodeEditor → some View`** (13 modifiers) — `.codeFontSize`, `.tabWidth`, `.memoryMonitor`, etc. Behavior identical to the first group (writes env), but declaration site requires `CodeEditor` typing.

Once a chain hits a `some View` modifier, downstream `CodeEditor`-typed modifiers fail to resolve. Example that fails today:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)          // some View
    .onTextChange { _ in }          // error: 'some View' has no member 'onTextChange'
```

The sample sidesteps the trap by always placing struct-mutator modifiers first (`Sources/CodeEditorSample/App/WindowBody.swift:47-63`, `Sources/CodeEditorSample/iOS/IOSRootView.swift:104-112`). This is a latent footgun for external hosts and a bad pedagogical signal.

The compiler error message *"Value of type 'some View' has no member 'onTextChange'"* doesn't point at the cause.

## Goals

1. Every public modifier on `CodeEditor` returns `some View`. No `Self`, no `CodeEditor`.
2. Modifier chains compose in arbitrary order. `.codeLanguage(.swift).onTextChange { … }` and `.onTextChange { … }.codeLanguage(.swift)` both compile.
3. Behavior preserved: text-change callbacks, selection-change callbacks, completion provider, controller attach, interaction-state binding all fire identically to today.
4. Sample call sites stay byte-identical (no rewrites; only inferred return types differ).

## Non-goals

- Adding new public surface for the formerly-stored state. The five formerly-stored-property modifiers keep the same names + parameter labels + parameter types.
- Re-thinking the modifier vocabulary (renames, deprecations, parameter shuffling). Out of scope.
- Touching `CodeEditor.withLanguage(_:language:theme:debounceInterval:)` / `.withConfiguration(_:configuration:language:theme:debounceInterval:)` factories. These already return `some View` from `static` methods; they keep working as-is.
- Addressing `CodeEditorEnvironment.with(...)` nil-clearing (separate REVIEW.md item).
- Touching tree-sitter, LSP, completion ranking, or any non-SwiftUI subsystem.

## Architecture

### `CodeEditorIntent` — one internal env value

New internal type at `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift`:

```swift
struct CodeEditorIntent: Sendable {
    var onTextChange: (@Sendable (String) -> Void)?
    var onSelectionChange: (@Sendable (Range<String.Index>?) -> Void)?
    var completionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    var editorController: EditorController?
    var interactionState: Binding<EditorInteractionState>?
}
```

- All fields optional, default `nil`. Empty intent matches today's "no callbacks set" CodeEditor.
- `Sendable` synthesizes: closures are `@Sendable`; `EditorController` is `@MainActor @Observable` (implicitly `Sendable`); `Binding<EditorInteractionState>` is conditionally `Sendable` because `EditorInteractionState` is `Sendable`.
- Type is internal. Modifiers are public; the env value carrying their state is implementation detail.

### Internal env key

```swift
private struct CodeEditorIntentKey: EnvironmentKey {
    static let defaultValue = CodeEditorIntent()
}

extension EnvironmentValues {
    var codeEditorIntent: CodeEditorIntent {
        get { self[CodeEditorIntentKey.self] }
        set { self[CodeEditorIntentKey.self] = newValue }
    }
}
```

`defaultValue` is a `static let` shared sentinel — same pattern as the `EditorState` env default landed earlier on 2026-05-14. No per-render allocation; readers without an injected intent see the same shared empty value.

### Public modifier bodies

The five modifiers move from `extension CodeEditor` to `extension View` and write via `transformEnvironment`:

```swift
extension View {
    public func onTextChange(
        perform action: @escaping @Sendable (String) -> Void
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.onTextChange = action }
    }

    public func onSelectionChange(
        perform action: @escaping @Sendable (Range<String.Index>?) -> Void
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.onSelectionChange = action }
    }

    public func codeCompletion(
        provider: @escaping @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem]
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.completionProvider = provider }
    }

    public func editorController(_ controller: EditorController) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.editorController = controller }
    }

    public func editorInteractionState(
        _ binding: Binding<EditorInteractionState>
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.interactionState = binding }
    }
}
```

Last-write-wins: two `.onTextChange { … }` modifiers in a chain compose like the current struct-mutator (each call overwrites the field).

### The 13 env-style modifiers move from `extension CodeEditor` → `extension View`

`CodeEditor+ModifiersExtensions.swift:143-551`'s second `extension CodeEditor` block (with its 13 modifiers — `.isSelectedLineHighlighted`, `.editable`, `.codeFontSize`, `.tabWidth`, `.areInvisibleCharactersVisible`, `.isMinimapVisible`, `.autoScrollToCursor`, `.isCodeFoldingEnabled`, `.areFoldingControlsVisible`, `.minimumFoldableLines`, `.animateCodeFolding`, `.memoryMonitor`, `.eventSystem`) — collapses into the first `extension View` block. Bodies don't change; they were already using `transformEnvironment` / `environment` and already returned `some View`. The move is structural: same source lines, different `extension` header.

Exception: `extension CodeEditor` containing `static` factory methods (`.withLanguage`, `.withConfiguration`) stays put. Statics can't move to `extension View`, and they don't participate in chain composition.

### Representable wiring

`CodeEditor.body` reads `@Environment(\.codeEditorIntent)` and threads it into the representable as part of `environment`. The representable's `update(N|UI)View(_:context:)` reads `context.environment.codeEditorIntent` and forwards each field to the coordinator:

```swift
coordinator.onTextChangeCallback = intent.onTextChange
coordinator.onSelectionChange = wrappedSelectionCallback(intent.onSelectionChange, …)
coordinator.editorController = intent.editorController     // weak
coordinator.interactionStateBinding = intent.interactionState
```

Completion provider routes through `EditorController.installSwiftUICompletionProvider(_:)` the same way it does today; the env-driven path is the only thing that changes.

The selection callback's `NSRange` → `Range<String.Index>?` translation already exists in the current `CodeEditor` body somewhere between the modifier setter and the coordinator. The migration preserves the translation site without changing its semantics. The plan will pin the exact line.

### Stored properties drop from `CodeEditor`

The `CodeEditor` struct retains: `text: Binding<String>` and `debounceInterval: Duration` (both init-supplied). The five formerly-stored properties (`onTextChange`, `onSelectionChange`, `completionProvider`, `editorController`, `interactionState`) are removed from the struct. The struct shrinks; `body` becomes a thin "build representable, pass env + intent" wrapper.

## Data flow (after migration)

```
host modifier chain
  ↓ transformEnvironment(\.codeEditorIntent) per modifier
SwiftUI EnvironmentValues
  ↓ @Environment(\.codeEditorIntent) inside CodeEditor.body
CodeEditor.body
  ↓ representable's context.environment.codeEditorIntent
update(N|UI)View(_:context:)
  ↓ assign each intent field to the coordinator
CodeEditorBaseCoordinator
  ↓ text/selection callbacks fire from existing handleTextChange / handleSelectionChange
host's closures execute
```

The intent struct is read-only at the editor — only modifiers (above the editor in the chain) write to it. The representable owns the read-and-forward step.

## Behavior preservation

- **Stale callbacks during teardown.** Coordinator holds callbacks as `var`s assigned on every `update(N|UI)View`. If a modifier is removed between renders, the env reverts to `nil` on that field, and the next update assigns `nil` to the coordinator. Dismantle path nils all callback fields as belt-and-suspenders.
- **Last-write-wins for repeated modifiers.** `transformEnvironment` writes overwrite; same semantics as today's `var copy = self; copy.onTextChange = action; return copy` chain (each call drops the previous value).
- **Controller attach timing.** Today the controller is attached when `makeNSView`/`makeUIView` builds the view, reading `self.editorController`. After migration, `makeNSView`/`makeUIView` reads `context.environment.codeEditorIntent.editorController` and follows the same attach path. The on-attach hook landed in the EditorController.onAttach batch on 2026-05-14 keeps firing identically.

## Public API impact

### Source-breaking

Exactly one pattern breaks: hosts that explicitly variable-typed a `CodeEditor`-returning modifier:

```swift
// Today (works):
let editor: CodeEditor = CodeEditor(text: $code).onTextChange { … }
// After (compile error: cannot convert 'some View' to 'CodeEditor'):
```

Fix is one keyword: `let editor: some View = …`. Sample doesn't do this; external hosts that did pin the type were working against SwiftUI's grain.

### Strictly additive

- New internal `CodeEditorIntent` type. Not public — no API surface added.
- New internal `\.codeEditorIntent` env key. Not public.

### Strictly subtractive (internal)

- `CodeEditor.onTextChange`, `.onSelectionChange`, `.completionProvider`, `.editorController`, `.interactionState` stored properties removed.
- `CodeEditor+ModifiersExtensions.swift`'s second `extension CodeEditor` block removed; its 13 modifiers re-declared under `extension View`.

### Modifier signatures (public)

| Modifier | Today | After |
|---|---|---|
| `.onTextChange(perform:)` | `CodeEditor` | `some View` |
| `.onSelectionChange(perform:)` | `CodeEditor` | `some View` |
| `.codeCompletion(provider:)` | `CodeEditor` | `some View` |
| `.editorController(_:)` | `Self` | `some View` |
| `.editorInteractionState(_:)` | `Self` | `some View` |
| `.isSelectedLineHighlighted`, `.editable`, `.codeFontSize`, `.tabWidth`, `.areInvisibleCharactersVisible`, `.isMinimapVisible`, `.autoScrollToCursor`, `.isCodeFoldingEnabled`, `.areFoldingControlsVisible`, `.minimumFoldableLines`, `.animateCodeFolding`, `.memoryMonitor`, `.eventSystem` | `some View` from `extension CodeEditor` | `some View` from `extension View` (no signature change; declaration site only) |

Parameter labels, parameter types, modifier names: unchanged for all 18 affected modifiers.

## Testing strategy

### New tests

**`Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift`** (Swift Testing `@Suite`):
- Each of the five migrated modifiers writes its field into `EnvironmentValues.codeEditorIntent`; reads back identical.
- Default intent has all five fields nil.
- Two `.onTextChange { … }` modifiers in chain: last-write-wins.
- The 13 moved env-style modifiers keep writing to their existing env keys (regression net).

**`Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift`**:
Each case is a chain that fails to compile today and must compile after:
- `CodeEditor(text: $t).codeLanguage(.swift).onTextChange { _ in }`
- `CodeEditor(text: $t).codeFontSize(14).codeCompletion { _ in [] }`
- `CodeEditor(text: $t).performanceObserver(obs).editorController(controller)`
- `CodeEditor(text: $t).activeDocument(in: docs).onSelectionChange { _ in }`
- Plus inverse orders (which already compile today) — kept as regression coverage.

Tests assert compilation; bodies just need `_ = chain` or a render-able expression.

**`Tests/CodeEditorPluginTests/SwiftUI/IntentCoordinatorWiringTests.swift`**:
- After a chain with `.onTextChange { … }`, simulate `update(N|UI)View` with a populated env; assert `coordinator.onTextChangeCallback != nil` and firing it triggers the bound closure.
- Same shape for `.onSelectionChange`, `.editorController`, `.interactionState`.
- Modifier-removed-between-renders: render with intent set, then render with intent nil; assert coordinator's callbacks are nil and no stale closure fires.

### Existing tests that must still pass

- `Tests/CodeEditorPluginTests/SwiftUICoordinatorTests.swift` (14 tests, including the EditorState mirror coverage from 2026-05-14). These exercise the coordinator's text/selection/controller wiring; they're the cross-check that env-driven delivery matches struct-mutator behavior.
- Sample-side tests (`Tests/CodeEditorSampleTests/`) — compile unchanged.
- Snapshot tests covering the editor pane — render output unchanged.

### Pre-existing failures inherited from earlier batches (not in scope to fix)

`RegexRangeHighlightProviderTests.testParsePerformance100KLines`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`, `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`, `EditorStatusBarSnapshots/*` parallel SIGSEGV.

## SwiftLint guard (optional, light touch)

Add a custom rule `forbidden_swiftui_extension_codeeditor` to `.swiftlint.yml`:

```yaml
forbidden_swiftui_extension_codeeditor:
  name: "Forbidden extension CodeEditor"
  regex: '^extension CodeEditor \{'
  match_kinds:
    - identifier
  message: "Public modifiers on CodeEditor must declare 'extension View' to keep chain composition order-independent. See docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md. Exception: CodeEditor+FactoryExtensions.swift (static factories)."
  severity: error
  included:
    - Sources/CodeEditorPlugin/SwiftUI/.*\.swift
  excluded:
    - Sources/CodeEditorPlugin/SwiftUI/CodeEditor+FactoryExtensions.swift
```

Prevents future regressions of the kind REVIEW.md flagged.

## Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Hosts pinning `let editor: CodeEditor = …` break at compile | Low | One-keyword fix (`let editor: some View = …`). Document in commit message + release notes. |
| Env propagation re-renders cost regression | Very low | Same shape as existing `\.codeEditorConfiguration` chain. Five-field struct copies are negligible. No new benchmark needed. |
| Coordinator picks up stale callback after modifier removal | Low | Coordinator assigns from env on every `update(N|UI)View`; removed modifier reverts env to nil; dismantle path nils as belt-and-suspenders. Covered by `IntentCoordinatorWiringTests`. |
| `Binding<EditorInteractionState>` in env value is not actually `Sendable` under strict-concurrency | Low | `EditorInteractionState` is already declared `Sendable`; `Binding<T>` conforms to `Sendable` when `T` is. Verify during implementation. |
| The closure-typed `completionProvider` env value not Sendable | Low | Closure is already `@Sendable` (existing signature). |
| SwiftUI re-renders editor body when intent env changes downstream | Low | Standard SwiftUI behavior. Same shape as existing env keys; same cost. |

## Migration scope

Single in-tree PR. No phasing.

**Files touched:**
- **Add:** `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift`.
- **Modify:** `CodeEditor.swift` (drop 5 stored properties + their inline modifier definitions; switch `body` to env reads), `CodeEditor+ModifiersExtensions.swift` (move the 13 `extension CodeEditor` decls to `extension View`, plus rewrite the 3 closure-typed modifier bodies), `CodeEditor+CompletionExtensions.swift` (env-driven completion provider read), `CodeEditor+CoordinatorsExtensions.swift` (coordinator picks up callbacks from env on update; no public signature change), `.swiftlint.yml` (add the guard rule).
- **Sample:** no call-site edits required. The 13 sample modifier usages in `WindowBody.swift:47-63` + `IOSRootView.swift:104-112` continue to compile byte-identical.
- **Tests:** three new files (above); existing suites pass unchanged.

## Acceptance criteria

1. Every `extension CodeEditor { public func ... }` modifier under `Sources/CodeEditorPlugin/SwiftUI/` is gone (except statics in `CodeEditor+FactoryExtensions.swift`).
2. The five tests in `ModifierChainCompositionTests` compile (they fail to compile on `main` today; this is the regression net).
3. The sample's editor panes (`WindowBody.editorPane`, `IOSRootView.editor`) compile with zero call-site edits.
4. All existing `SwiftUICoordinatorTests` (14 cases) pass without modification.
5. `swiftlint --strict` passes with zero violations; the new `forbidden_swiftui_extension_codeeditor` rule does not fire on the migrated tree.
6. `swift test --parallel` shows no new failures beyond the documented pre-existing list.
