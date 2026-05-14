# SwiftUI Modifier Return Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the five struct-mutator modifiers on `CodeEditor` (`.onTextChange`, `.onSelectionChange`, `.codeCompletion`, `.editorController`, `.editorInteractionState`) to an internal `CodeEditorIntent` environment value so every public modifier returns `some View`. Move the 13 env-style modifiers still declared on `extension CodeEditor` to `extension View` for full symmetry. After this PR every public modifier composes in arbitrary order; sample call sites stay byte-identical.

**Architecture:** Introduce one internal env-keyed struct (`CodeEditorIntent`) carrying optional fields for each formerly-stored callback/reference. Public modifiers write to that struct via `transformEnvironment(\.codeEditorIntent)`. `CodeEditor.body` reads the intent through `@Environment(\.codeEditorIntent)`, builds wrapper closures via a new testable static helper (`makeRepresentableCallbacks`), and threads the values into the existing representable + coordinator pipeline. No public type or signature changes other than the return-type widening from `CodeEditor`/`Self` to `some View`.

**Tech Stack:** Swift 6.3 strict concurrency, SwiftUI (macOS 13+ / iOS 16+), XCTest + Swift Testing for tests, SwiftLint for the regression-prevention rule.

**Spec:** [`docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md`](../specs/2026-05-14-swiftui-modifier-return-types-design.md) (commit `42160cd`).

---

## File map

**Add:**
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift` — the internal `CodeEditorIntent` struct + `EnvironmentValues.codeEditorIntent` env key.
- `Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift` — env-propagation unit tests.
- `Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift` — compile-time regression net for the chain composition (chains that fail to compile on `main` today).
- `Tests/CodeEditorPluginTests/SwiftUI/IntentCoordinatorWiringTests.swift` — functional tests for the static helper that wraps intent callbacks for the representable.

**Modify:**
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` — drop five stored properties (`onTextChange`, `onSelectionChange`, `completionProvider`, `interactionState`, `editorController`) + two inline modifier definitions (`.editorController(_:)`, `.editorInteractionState(_:)`) + two private callback wrappers (`handleTextChange`, `handleSelectionChange`). Add `@Environment(\.codeEditorIntent)` and a new static helper `makeRepresentableCallbacks(from:textBinding:)`. Update `body` to consume intent from env.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift` — relocate the three closure-typed modifiers (`.onTextChange`, `.onSelectionChange`, `.codeCompletion`) to `extension View`; absorb the two modifiers moved out of `CodeEditor.swift` (`.editorController`, `.editorInteractionState`); flip the second `extension CodeEditor { … }` header to `extension View { … }` (13 modifier bodies unchanged).
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift` — update the stale chain-ordering warning in `.activeDocument(in:)`'s docstring (lines 26-31).
- `.swiftlint.yml` — add the `forbidden_swiftui_extension_codeeditor` custom rule under `custom_rules:`.
- `REVIEW.md` — mark the "Inconsistent SwiftUI modifier return types" item as landed in the "What's left after this round" section, with a new dated batch section at the appropriate spot.

**Untouched on purpose (DO NOT modify):**
- `CodeEditor+FactoryExtensions.swift` — `static` factories on `extension CodeEditor`; the rule explicitly excludes this file because statics can't move to `extension View` and don't participate in chain composition.
- `CodeEditorRepresentableHelper.swift`, `CodeEditor+AppKitExtensions.swift`, `CodeEditor+UIKitExtensions.swift` — the representable structs and helper continue to receive callbacks as `let` fields from `body`; only the *source* of those values changes (env intent instead of `self.…`).
- All sample call sites — `Sources/CodeEditorSample/App/WindowBody.swift:47-63`, `Sources/CodeEditorSample/iOS/IOSRootView.swift:104-112` etc. Their inferred return types change but the source code does not.

**Known-broken behavior preserved (NOT in scope to fix):**
- `.codeCompletion(provider:)` is a no-op today: `CodeEditor.completionProvider` (assigned at `CodeEditor+ModifiersExtensions.swift:276`) has no reader anywhere in `Sources/CodeEditorPlugin/`. The migration preserves this — the new `CodeEditorIntent.completionProvider` field is also unread. Flag for a separate follow-up.

---

## Verification commands

These run during each task; the plan calls them out explicitly per step.

```bash
# Lint (must pass strict; warnings are errors)
swiftlint --fix && swiftlint

# Targeted test runs
swift test --filter CodeEditorIntentTests
swift test --filter ModifierChainCompositionTests
swift test --filter IntentCoordinatorWiringTests
swift test --filter SwiftUICoordinatorTests
swift test --filter PerformanceObserverModifierTests
swift test --filter ActiveDocumentModifierTests

# Full build
swift build

# Sample-app build (target, not directory — per CLAUDE.md)
swift build --target CodeEditorSample
```

**Pre-existing failures (DOCUMENTED in REVIEW.md; not in scope to fix in this PR):** `RegexRangeHighlightProviderTests.testParsePerformance100KLines`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`, `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`, `EditorStatusBarSnapshots/*` parallel SIGSEGV.

---

## Task 1: Add `CodeEditorIntent` type + env key

**Files:**
- Create: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift`
- Create: `Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift`:

```swift
//
//  CodeEditorIntentTests.swift
//  CodeEditorPluginTests
//
//  Env-propagation unit tests for CodeEditorIntent. See
//  docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md.
//

@testable import CodeEditorPlugin
import SwiftUI
import XCTest

@available(macOS 13.0, iOS 16.0, *)
final class CodeEditorIntentTests: XCTestCase {
    @MainActor
    func testDefaultIntentHasAllFieldsNil() {
        let intent = CodeEditorIntent()
        XCTAssertNil(intent.onTextChange)
        XCTAssertNil(intent.onSelectionChange)
        XCTAssertNil(intent.completionProvider)
        XCTAssertNil(intent.editorController)
        XCTAssertNil(intent.interactionState)
    }

    @MainActor
    func testIntentFieldsRoundtrip() {
        var intent = CodeEditorIntent()
        intent.onTextChange = { _ in }
        intent.onSelectionChange = { _ in }
        intent.completionProvider = { _ in [] }
        intent.interactionState = .constant(EditorInteractionState())
        XCTAssertNotNil(intent.onTextChange)
        XCTAssertNotNil(intent.onSelectionChange)
        XCTAssertNotNil(intent.completionProvider)
        XCTAssertNotNil(intent.interactionState)
    }

    @MainActor
    func testDefaultEnvironmentValueIsEmptyIntent() {
        let env = EnvironmentValues()
        XCTAssertNil(env.codeEditorIntent.onTextChange)
        XCTAssertNil(env.codeEditorIntent.onSelectionChange)
        XCTAssertNil(env.codeEditorIntent.completionProvider)
        XCTAssertNil(env.codeEditorIntent.editorController)
        XCTAssertNil(env.codeEditorIntent.interactionState)
    }
}
```

- [ ] **Step 2: Run test to verify it fails to compile**

```bash
swift test --filter CodeEditorIntentTests
```

Expected: build failure — `CodeEditorIntent` and `codeEditorIntent` are undefined.

- [ ] **Step 3: Add the type and env key**

Create `Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift`:

```swift
//
//  CodeEditorIntent.swift
//  CodeEditorPlugin
//
//  Carries the closures and reference bindings supplied by the
//  `CodeEditor` modifier chain that previously lived as stored
//  properties on the `CodeEditor` struct. Internal: modifiers are
//  public; the env value carrying their state is implementation
//  detail.
//
//  Spec: docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md
//

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
struct CodeEditorIntent: Sendable {
    var onTextChange: (@Sendable (String) -> Void)?
    var onSelectionChange: (@Sendable (Range<String.Index>?) -> Void)?
    var completionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    var editorController: EditorController?
    var interactionState: Binding<EditorInteractionState>?
}

@available(macOS 13.0, iOS 16.0, *)
private struct CodeEditorIntentKey: EnvironmentKey {
    static let defaultValue = CodeEditorIntent()
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    /// Editor intent populated by `CodeEditor` modifier chain. Read by
    /// `CodeEditor.body` and forwarded into the representable/coordinator.
    var codeEditorIntent: CodeEditorIntent {
        get { self[CodeEditorIntentKey.self] }
        set { self[CodeEditorIntentKey.self] = newValue }
    }
}

#endif
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter CodeEditorIntentTests
```

Expected: all 3 tests PASS.

- [ ] **Step 5: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorIntent.swift Tests/CodeEditorPluginTests/SwiftUI/CodeEditorIntentTests.swift
git commit -m "$(cat <<'EOF'
Add CodeEditorIntent env value for modifier-chain state

Internal env key + Sendable struct holding the five formerly-stored
properties (onTextChange, onSelectionChange, completionProvider,
editorController, interactionState). Followups migrate the modifiers
to write into this struct via transformEnvironment.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `makeRepresentableCallbacks` static helper + its tests

This helper extracts the wrapper-closure construction that today lives inside `CodeEditor.body` (the `handleTextChange` / `handleSelectionChange` private methods). Extracting it makes Task 3's body changes mechanical and unit-tests the closure-wrapping logic directly.

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` (add static helper near line 354, after `resolveInteractionBinding`)
- Create: `Tests/CodeEditorPluginTests/SwiftUI/IntentCoordinatorWiringTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/CodeEditorPluginTests/SwiftUI/IntentCoordinatorWiringTests.swift`:

```swift
//
//  IntentCoordinatorWiringTests.swift
//  CodeEditorPluginTests
//
//  Functional tests for CodeEditor.makeRepresentableCallbacks(from:textBinding:).
//  Spec: docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md.
//

@testable import CodeEditorPlugin
import SwiftUI
import XCTest

@available(macOS 13.0, iOS 16.0, *)
final class IntentCoordinatorWiringTests: XCTestCase {
    @MainActor
    func testNilIntentProducesNilCallbacks() {
        let binding = Binding<String>.constant("abc")
        let (textCallback, selectionCallback) = CodeEditor.makeRepresentableCallbacks(
            from: CodeEditorIntent(),
            textBinding: binding
        )
        XCTAssertNil(textCallback)
        XCTAssertNil(selectionCallback)
    }

    @MainActor
    func testOnTextChangeForwardsThroughWrapper() {
        var captured: String?
        var intent = CodeEditorIntent()
        intent.onTextChange = { captured = $0 }

        let binding = Binding<String>.constant("abc")
        let (textCallback, _) = CodeEditor.makeRepresentableCallbacks(
            from: intent,
            textBinding: binding
        )

        XCTAssertNotNil(textCallback)
        textCallback?("hello")
        XCTAssertEqual(captured, "hello")
    }

    @MainActor
    func testOnSelectionChangeConvertsNSRangeToStringIndexRange() {
        var captured: Range<String.Index>?
        var intent = CodeEditorIntent()
        intent.onSelectionChange = { captured = $0 }

        let binding = Binding<String>.constant("hello world")
        let (_, selectionCallback) = CodeEditor.makeRepresentableCallbacks(
            from: intent,
            textBinding: binding
        )

        XCTAssertNotNil(selectionCallback)
        // "hello" — UTF-16 location 0, length 5
        selectionCallback?(NSRange(location: 0, length: 5))

        let expectedStart = binding.wrappedValue.startIndex
        let expectedEnd = binding.wrappedValue.index(expectedStart, offsetBy: 5)
        XCTAssertEqual(captured, expectedStart..<expectedEnd)
    }

    @MainActor
    func testOnSelectionChangeSilentlyDropsInvalidRanges() {
        var fired = false
        var intent = CodeEditorIntent()
        intent.onSelectionChange = { _ in fired = true }

        let binding = Binding<String>.constant("abc")
        let (_, selectionCallback) = CodeEditor.makeRepresentableCallbacks(
            from: intent,
            textBinding: binding
        )

        // Past-end range — Range(_:in:) returns nil; today's
        // handleSelectionChange returns silently; preserve that.
        selectionCallback?(NSRange(location: 100, length: 5))
        XCTAssertFalse(fired)
    }
}
```

- [ ] **Step 2: Run test to verify it fails to compile**

```bash
swift test --filter IntentCoordinatorWiringTests
```

Expected: build failure — `CodeEditor.makeRepresentableCallbacks` undefined.

- [ ] **Step 3: Add the static helper to `CodeEditor.swift`**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, after the `resolveInteractionBinding` static (currently ends at line 354), add a new `// MARK:` section:

```swift
    // MARK: - Intent-driven callback wrapping

    /// Builds the `onTextChange` / `onSelectionChange` closures that
    /// `body` passes to the representable, given the env-supplied
    /// intent and the effective text binding.
    ///
    /// `selectionCallback` converts `NSRange` → `Range<String.Index>?`
    /// against the binding's current value; ranges that fail to map
    /// (e.g., past-end selections) silently drop. This matches the
    /// pre-migration behavior of `handleSelectionChange`.
    ///
    /// Extracted as a `static` helper so it's unit-testable without
    /// rendering the view.
    static func makeRepresentableCallbacks(
        from intent: CodeEditorIntent,
        textBinding: Binding<String>
    ) -> (
        textCallback: ((String) -> Void)?,
        selectionCallback: ((NSRange) -> Void)?
    ) {
        let textCallback: ((String) -> Void)? = intent.onTextChange.map { handler in
            { newText in handler(newText) }
        }
        let selectionCallback: ((NSRange) -> Void)? = intent.onSelectionChange.map { handler in
            { nsRange in
                guard let range = Range(nsRange, in: textBinding.wrappedValue) else { return }
                handler(range)
            }
        }
        return (textCallback, selectionCallback)
    }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter IntentCoordinatorWiringTests
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift Tests/CodeEditorPluginTests/SwiftUI/IntentCoordinatorWiringTests.swift
git commit -m "$(cat <<'EOF'
Add CodeEditor.makeRepresentableCallbacks static helper

Extracts the NSRange → Range<String.Index>? wrapping that today lives
inside body's private handleSelectionChange method. Pure refactor:
helper is not yet called from body. The next task wires body to
consume CodeEditorIntent via this helper.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Migrate the five struct-mutator modifiers to `extension View` + rewire `CodeEditor.body`

This is the load-bearing task. Five modifier definitions move; `CodeEditor.body` switches from stored properties to env reads; the five stored properties + two private wrappers drop. Sample call sites stay byte-identical.

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`

- [ ] **Step 1: Verify pre-state — chain composition fails today**

Write a scratch file at `/tmp/chain_check.swift` and ensure it does NOT compile against the current package:

```swift
import SwiftUI
import CodeEditorPlugin

@available(macOS 13.0, iOS 16.0, *)
struct Probe: View {
    @State var text = ""
    var body: some View {
        CodeEditor(text: $text)
            .codeLanguage(.swift)
            .onTextChange { _ in }   // expected error: 'some View' has no member 'onTextChange'
    }
}
```

```bash
swift -F .build/debug -I .build/debug -L .build/debug -lCodeEditorPlugin /tmp/chain_check.swift 2>&1 | head -20
```

Expected: compile error mentioning "no member 'onTextChange'" or similar. This pins the red state we are flipping.

(Skip this step if scratch builds are awkward; the same pre-state is implicit and Task 5's ModifierChainCompositionTests will fail to compile against the pre-state if checked out.)

- [ ] **Step 2: Move three closure-typed modifiers in `CodeEditor+ModifiersExtensions.swift`**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`, edit the second `extension CodeEditor` block (starts at line 143). Three modifiers move out — `.onTextChange` (currently lines 206-214), `.onSelectionChange` (currently lines 237-243), `.codeCompletion` (currently lines 272-278).

Delete those three function definitions from the `extension CodeEditor` block (keep their preceding doc comments together with the function bodies as you move them — don't orphan comments).

Add them to the `extension View` block at the top of the file (the one starting at line 7), as new functions with `some View` return type. The new bodies use `transformEnvironment(\.codeEditorIntent)`:

```swift
    /// Adds a text change handler with optional debouncing.
    ///
    /// - Parameters:
    ///   - action: Closure called when text changes
    /// - Returns: A view with the text change handler attached
    ///
    /// The handler is called whenever the text content changes. Use debouncing
    /// to reduce the frequency of calls for performance-sensitive operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use default debouncing (100ms)
    /// CodeEditor(text: $code)
    ///     .onTextChange { newText in
    ///         print("Text changed: \(newText.count) characters")
    ///     }
    ///
    /// // Or specify custom debouncing in initializer
    /// CodeEditor(text: $code, debounceInterval: .milliseconds(500))
    ///     .onTextChange { newText in
    ///         saveToDatabase(newText)
    ///     }
    /// ```
    public func onTextChange(
        perform action: @escaping @Sendable (String) -> Void
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.onTextChange = action }
    }

    /// Adds a selection change handler.
    ///
    /// - Parameter action: Closure called when the text selection changes
    /// - Returns: A view with the selection change handler attached
    ///
    /// The handler provides the selected range as `Range<String.Index>` or `nil`
    /// if no text is selected. Selection changes are not debounced.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .onSelectionChange { range in
    ///         if let range = range {
    ///             let selectedText = String(code[range])
    ///             print("Selected: \(selectedText)")
    ///         } else {
    ///             print("No selection")
    ///         }
    ///     }
    /// ```
    public func onSelectionChange(
        perform action: @escaping @Sendable (Range<String.Index>?) -> Void
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.onSelectionChange = action }
    }

    /// Configures a custom code completion provider.
    ///
    /// - Parameter provider: Async closure that returns completion items
    /// - Returns: A view with the completion provider attached
    ///
    /// The provider is called when the user triggers code completion and receives
    /// a `SwiftUICompletionContext` with the current text, cursor position, and language.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .codeCompletion { context in
    ///         let items = await fetchCompletions(
    ///             for: context.language,
    ///             at: context.cursorPosition,
    ///             in: context.text
    ///         )
    ///         return items.map { item in
    ///             SwiftUICompletionItem(
    ///                 label: item.label,
    ///                 kind: item.kind,
    ///                 insertText: item.insertText
    ///             )
    ///         }
    ///     }
    /// ```
    ///
    /// - Note: As of 2026-05-14 the SwiftUI provider closure is stored
    ///   on `CodeEditorIntent` but not yet consumed by the editor. A
    ///   separate follow-up wires it through the completion pipeline.
    public func codeCompletion(
        provider: @escaping @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem]
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.completionProvider = provider }
    }
```

Place these three new functions inside the first `extension View` block (after `.becomeFirstResponder(_:)` at line 139). Preserve alphabetical/logical ordering of the function group — group all closure-typed modifiers together.

- [ ] **Step 3: Move two `Self`-returning modifiers from `CodeEditor.swift` to `CodeEditor+ModifiersExtensions.swift`**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, **delete** these two function definitions:
- `editorInteractionState(_:)` at lines 274-278
- `editorController(_:)` at lines 296-300 (including the preceding doc comment block at lines 280-295)

Also delete the section comment at line 266 (`// MARK: - Modifiers`) since the only two modifiers in that section are leaving.

In `CodeEditor+ModifiersExtensions.swift`, add to the first `extension View` block (right after `.codeCompletion(provider:)` from Step 2):

```swift
    /// Binds editor interaction state for persistence and restoration.
    ///
    /// The current implementation provides two-way cursor-position sync:
    /// selection changes update `cursorPositions`, and external writes to
    /// `cursorPositions` move the editor caret. Other fields are retained
    /// for host persistence and future editor integrations.
    public func editorInteractionState(
        _ binding: Binding<EditorInteractionState>
    ) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.interactionState = binding }
    }

    /// Attaches a host-owned `EditorController` so the host can drive
    /// find/replace, folding, line/symbol navigation, and the annotations
    /// data source through a single façade. The controller weakly
    /// references the underlying `CodeEditorView` for its lifetime.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @State private var controller = EditorController()
    ///
    /// var body: some View {
    ///     CodeEditor(text: $code)
    ///         .editorController(controller)
    ///     Button("Fold All") { controller.foldAll() }
    /// }
    /// ```
    public func editorController(_ controller: EditorController) -> some View {
        transformEnvironment(\.codeEditorIntent) { $0.editorController = controller }
    }
```

- [ ] **Step 4: Drop stored properties from `CodeEditor.swift`**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, **delete** the entire callback/state property group (currently lines 166-177):

```swift
    // Callbacks
    internal var onTextChange: (@Sendable (String) -> Void)?
    internal var onSelectionChange: (@Sendable (Range<String.Index>?) -> Void)?
    internal var completionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?

    // Interaction state (opt-in, two-way binding)
    internal var interactionState: Binding<EditorInteractionState> = .constant(EditorInteractionState())

    // Imperative command façade (opt-in). When set, the SwiftUI representable
    // weakly assigns the underlying CodeEditorView into the controller so
    // host code can call find/fold/goto/etc. through the controller's API.
    internal var editorController: EditorController?
```

Also delete the two private methods (currently lines 434-446):

```swift
    // MARK: - Private Methods

    private func handleTextChange(_ newText: String) {
        // The coordinator will handle this, so this can be simplified
        // The text binding is updated directly by the coordinator
        onTextChange?(newText)
    }

    private func handleSelectionChange(_ selection: NSRange) {
        // Convert NSRange to Range<String.Index>
        guard let range = Range(selection, in: text) else { return }
        onSelectionChange?(range)
    }
```

Add a new `@Environment` declaration right after the existing `@Environment(\.activeDocumentManager)` line (currently line 147):

```swift
    // Intent populated by the modifier chain (.onTextChange, .editorController, …).
    // Read by body to wire callbacks and references into the representable.
    @Environment(\.codeEditorIntent) private var codeEditorIntent
```

- [ ] **Step 5: Update `CodeEditor.body` to consume the intent**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`, replace the existing body (currently lines 358-432) with the env-driven version. The body's final shape:

```swift
    public var body: some View {
        let effectiveLanguage = initialLanguage ?? environment.language
        let effectiveTheme = initialTheme ?? environment.theme

        var effectiveRuntimeDependencies: EditorRuntimeDependencies
        if let provided = environment.runtimeDependencies {
            effectiveRuntimeDependencies = provided
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            }
        } else {
            effectiveRuntimeDependencies = fallbackRuntimeDependencies
            effectiveRuntimeDependencies.workspaceRoot = environment.workspaceRoot
            effectiveRuntimeDependencies.eventSystem = environment.eventSystem
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            } else {
                effectiveRuntimeDependencies.memoryMonitor = defaultMemoryMonitor
            }
        }

        let effectiveConfiguration = Self.makeEffectiveConfiguration(from: environment)
        let effectiveDebounceInterval = textDebounceInterval
            ?? effectiveConfiguration.performance.textChangeDebounceInterval

        let effectiveTextBinding = Self.resolveTextBinding(
            stored: $text,
            manager: activeDocumentManager
        )
        let storedInteraction = codeEditorIntent.interactionState
            ?? .constant(EditorInteractionState())
        let effectiveInteractionBinding = Self.resolveInteractionBinding(
            stored: storedInteraction,
            manager: activeDocumentManager
        )

        let (textCallback, selectionCallback) = Self.makeRepresentableCallbacks(
            from: codeEditorIntent,
            textBinding: effectiveTextBinding
        )

        return CodeEditorRepresentable(
            text: effectiveTextBinding,
            language: effectiveLanguage,
            theme: effectiveTheme,
            configuration: effectiveConfiguration,
            runtimeDependencies: effectiveRuntimeDependencies,
            textDebounceInterval: effectiveDebounceInterval,
            interactionState: effectiveInteractionBinding,
            editorController: codeEditorIntent.editorController,
            hostEditorState: hostEditorState,
            onTextChange: textCallback,
            onSelectionChange: selectionCallback
        )
        .environment(\.codeEditorLanguage, effectiveLanguage)
        .environment(\.codeEditorTheme, effectiveTheme)
        .environment(\.codeEditorConfiguration, effectiveConfiguration)
        .environment(\.editorEventBus, codeEditorIntent.editorController?.editorEventBus)
        .onAppear {
            if environment.memoryMonitor == nil && environment.runtimeDependencies == nil {
                defaultMemoryMonitor.startMonitoring()
            }
        }
        .onDisappear {
            if environment.memoryMonitor == nil && environment.runtimeDependencies == nil {
                defaultMemoryMonitor.stopMonitoring()
            }
        }
    }
```

Key changes from the original body:
- `interactionState` (stored property) → `codeEditorIntent.interactionState ?? .constant(...)`
- `editorController` (stored property) → `codeEditorIntent.editorController` (passed to the representable AND used for `editorEventBus`)
- `handleTextChange`/`handleSelectionChange` calls → `Self.makeRepresentableCallbacks(...)` output

The kept-as-is "no `.searchable`" comment from the original body — its content was historical context for an old TextKit1-era bug. Keep it as a brief multi-line `//` comment block above the `.environment(\.codeEditorLanguage, ...)` line:

```swift
        // No `.searchable(...)` here on purpose. The old wrapper added a
        // toolbar search field that competes for first responder on macOS,
        // which made the editor appear read-only at launch even with a
        // valid `becomeFirstResponder: .yes` request. Hosts that want
        // searchable chrome can layer it outside the editor.
```

- [ ] **Step 6: Verify build is green**

```bash
swift build
```

Expected: PASS, no warnings.

- [ ] **Step 7: Run unaffected and affected tests**

```bash
swift test --filter CodeEditorIntentTests
swift test --filter IntentCoordinatorWiringTests
swift test --filter SwiftUICoordinatorTests
swift test --filter PerformanceObserverModifierTests
swift test --filter ActiveDocumentModifierTests
swift test --filter EditorControllerOnAttachTests
swift test --filter EditorInteractionStateBindingTests
```

Expected: all PASS. Coordinator tests are the regression net for the behavioral preservation.

- [ ] **Step 8: Sample app builds unchanged**

```bash
swift build --target CodeEditorSample
```

Expected: PASS, no warnings, no edits to sample sources required.

- [ ] **Step 9: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 10: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift
git commit -m "$(cat <<'EOF'
Migrate five struct-mutator modifiers to extension View → some View

.onTextChange, .onSelectionChange, .codeCompletion, .editorController,
and .editorInteractionState now write to a CodeEditorIntent env value
and return some View. CodeEditor.body reads the intent through
@Environment and threads it into the existing representable pipeline.
Five stored properties + two private callback wrappers drop from the
CodeEditor struct.

Sample call sites stay byte-identical. .codeCompletion(provider:) was
and remains a no-op (provider is stored but never consumed); separate
follow-up will wire it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Move the 13 env-style modifiers from `extension CodeEditor` → `extension View`

Pure structural refactor — change the second extension header in `CodeEditor+ModifiersExtensions.swift` from `extension CodeEditor` to `extension View`. The 13 modifier bodies are unchanged. After Task 3, this block contains only env-style writes (`transformEnvironment` / `environment`); all already return `some View`.

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift`

- [ ] **Step 1: Identify the block**

After Task 3, the second `extension CodeEditor` block contains 13 modifier definitions:
- `.isSelectedLineHighlighted`, `.editable`
- `.codeFontSize`, `.tabWidth`, `.areInvisibleCharactersVisible`, `.isMinimapVisible`
- `.autoScrollToCursor`, `.isCodeFoldingEnabled`, `.areFoldingControlsVisible`, `.minimumFoldableLines`, `.animateCodeFolding`
- `.memoryMonitor`, `.eventSystem`

These all use `transformEnvironment(\.codeEditorConfiguration) { … }` or `environment(\.somekey, value)` — pure env writes.

- [ ] **Step 2: Flip the extension header**

Change:

```swift
@available(macOS 13.0, iOS 16.0, *)
extension CodeEditor {
    /// Configures highlighting of the currently selected line.
    ...
```

to:

```swift
@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Configures highlighting of the currently selected line.
    ...
```

Leave every function body unchanged. The third `extension View` block at the bottom (around line 553-590 containing `.performanceObserver`) can be merged into the second one to keep the file tidy, but is not required.

- [ ] **Step 3: Build and run tests**

```bash
swift build
swift test --filter SwiftUICoordinatorTests
swift test --filter PerformanceObserverModifierTests
```

Expected: PASS. The behavioral change is zero (env reads at the editor read the same keys that env writes at the modifier site wrote to).

- [ ] **Step 4: Sample app builds unchanged**

```bash
swift build --target CodeEditorSample
```

Expected: PASS.

- [ ] **Step 5: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift
git commit -m "$(cat <<'EOF'
Move 13 env-style modifiers from extension CodeEditor → extension View

Pure structural refactor. Modifier bodies unchanged; all already used
transformEnvironment / environment under the hood. Removing the
CodeEditor-typed declaration removes the chain-break footgun:
.codeFontSize(...) and the like compose with .onTextHover, .frame, and
arbitrary SwiftUI modifiers without ordering constraints.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add the chain-composition regression net

These tests fail to compile against `main` — they're the regression net for the migration.

**Files:**
- Create: `Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift`

- [ ] **Step 1: Write the test file**

Create `Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift`:

```swift
//
//  ModifierChainCompositionTests.swift
//  CodeEditorPluginTests
//
//  Regression net for the SwiftUI modifier return-type migration.
//  Each test below is a modifier chain that failed to compile before
//  the 2026-05-14 migration because a `some View`-typed modifier
//  appeared upstream of a `CodeEditor`-typed one. If any case here
//  fails to compile, the migration has regressed.
//
//  Spec: docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md
//

@testable import CodeEditorPlugin
import SwiftUI
import XCTest

@available(macOS 13.0, iOS 16.0, *)
final class ModifierChainCompositionTests: XCTestCase {
    // MARK: - Chains that previously failed to compile

    @MainActor
    func testLanguageBeforeOnTextChange() {
        let text = Binding<String>.constant("")
        _ = CodeEditor(text: text)
            .codeLanguage(.swift)
            .onTextChange { _ in }
    }

    @MainActor
    func testFontSizeBeforeCodeCompletion() {
        let text = Binding<String>.constant("")
        _ = CodeEditor(text: text)
            .codeFontSize(14)
            .codeCompletion { _ in [] }
    }

    @MainActor
    func testPerformanceObserverBeforeEditorController() {
        let text = Binding<String>.constant("")
        let observation = PerformanceObservation()
        let controller = EditorController()
        _ = CodeEditor(text: text)
            .performanceObserver(observation)
            .editorController(controller)
    }

    @MainActor
    func testActiveDocumentBeforeOnSelectionChange() {
        let text = Binding<String>.constant("")
        let documents = EditorDocuments()
        _ = CodeEditor(text: text)
            .activeDocument(in: documents)
            .onSelectionChange { _ in }
    }

    @MainActor
    func testLineNumbersBeforeEditorInteractionState() {
        let text = Binding<String>.constant("")
        let interaction = Binding<EditorInteractionState>.constant(
            EditorInteractionState()
        )
        _ = CodeEditor(text: text)
            .lineNumbers(true)
            .editorInteractionState(interaction)
    }

    @MainActor
    func testMemoryMonitorBeforeOnTextChange() {
        let text = Binding<String>.constant("")
        let monitor = MemoryMonitor()
        _ = CodeEditor(text: text)
            .memoryMonitor(monitor)
            .onTextChange { _ in }
    }

    // MARK: - Inverse orders — regression coverage (compiled before too)

    @MainActor
    func testOnTextChangeBeforeLanguage() {
        let text = Binding<String>.constant("")
        _ = CodeEditor(text: text)
            .onTextChange { _ in }
            .codeLanguage(.swift)
    }

    @MainActor
    func testEditorControllerBeforeFontSize() {
        let text = Binding<String>.constant("")
        let controller = EditorController()
        _ = CodeEditor(text: text)
            .editorController(controller)
            .codeFontSize(14)
    }
}
```

- [ ] **Step 2: Verify all tests compile and pass**

```bash
swift test --filter ModifierChainCompositionTests
```

Expected: 8 tests PASS (compilation gates; bodies don't assert anything beyond "expression typechecks").

- [ ] **Step 3: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 4: Commit**

```bash
git add Tests/CodeEditorPluginTests/SwiftUI/ModifierChainCompositionTests.swift
git commit -m "$(cat <<'EOF'
Add regression net for SwiftUI modifier chain composition

Eight chains that failed to compile before the 2026-05-14 migration
(any some View-typed modifier upstream of a CodeEditor-typed one) are
now compile-time gates. If a future change re-introduces an
extension CodeEditor public modifier, these tests fail to build.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Update the stale chain-ordering warning in `.activeDocument(in:)` docstring

The docstring at `CodeEditor+DocumentsExtensions.swift:26-31` explicitly warns hosts that `.editorController`, `.editorInteractionState`, `.onTextChange`, and `.codeCompletion` must precede `.activeDocument(in:)`. After Tasks 3-4 that warning is wrong — the chain composes in any order.

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift` (lines 26-31)

- [ ] **Step 1: Edit the docstring**

In `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift`, replace the paragraph starting at line 26:

```swift
    /// Defined on `View` (rather than `CodeEditor`) so it composes with
    /// view-typed modifiers higher in the chain. Note that
    /// `CodeEditor`-typed methods such as `.editorController(_:)`,
    /// `.editorInteractionState(_:)`, `.onTextChange(_:)`, and
    /// `.codeCompletion(_:)` must be applied to `CodeEditor` *before*
    /// `.activeDocument(in:)` (they return `Self`, not `some View`).
```

with:

```swift
    /// Defined on `View` (rather than `CodeEditor`) so it composes with
    /// view-typed modifiers higher in the chain. As of 2026-05-14 every
    /// public CodeEditor modifier returns `some View`, so call order is
    /// no longer constrained.
```

- [ ] **Step 2: Build**

```bash
swift build
```

Expected: PASS.

- [ ] **Step 3: Run SwiftLint**

```bash
swiftlint --fix && swiftlint
```

Expected: 0 violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift
git commit -m "$(cat <<'EOF'
Drop stale chain-ordering warning in .activeDocument(in:) docstring

After the modifier return-type migration every public CodeEditor
modifier returns some View; the "must come before" warning the
docstring carried is obsolete.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add SwiftLint guard against re-introducing `extension CodeEditor` modifiers

Prevents future regressions of the kind REVIEW.md flagged. The rule fires only inside `Sources/CodeEditorPlugin/SwiftUI/` and excludes `CodeEditor+FactoryExtensions.swift` (the only legitimate site for `extension CodeEditor`, used for `static` factories).

**Files:**
- Modify: `.swiftlint.yml`

- [ ] **Step 1: Add the custom rule**

In `.swiftlint.yml`, find the `custom_rules:` section (currently around line 252). After the `forbidden_text_view_delegate_assignment` block (ends around line 288), add:

```yaml
  forbidden_swiftui_extension_codeeditor:
    included: 'Sources/CodeEditorPlugin/SwiftUI/.*\.swift'
    excluded: 'Sources/CodeEditorPlugin/SwiftUI/CodeEditor\+FactoryExtensions\.swift'
    name: "Forbidden extension CodeEditor"
    # Public modifiers on CodeEditor must declare 'extension View' to keep
    # chain composition order-independent. See
    # docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md.
    # Exception: CodeEditor+FactoryExtensions.swift (static factories).
    regex: '^extension CodeEditor \{'
    message: "Public modifiers on CodeEditor must declare 'extension View' to keep chain composition order-independent. Move new modifiers to an existing 'extension View' block in CodeEditor+ModifiersExtensions.swift. See docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md."
    severity: error
```

- [ ] **Step 2: Run SwiftLint and verify the rule does not fire on the migrated tree**

```bash
swiftlint --strict
```

Expected: 0 violations. (The two remaining `extension CodeEditor` blocks in the tree are in `CodeEditor+FactoryExtensions.swift`, which is excluded.)

- [ ] **Step 3: Verify the rule catches a regression (sanity check)**

Temporarily add an `extension CodeEditor { }` block to `CodeEditor+ModifiersExtensions.swift`, run `swiftlint`, and confirm the rule fires with the expected message. **Then revert that change.**

```bash
# 1. Add a probe extension block to CodeEditor+ModifiersExtensions.swift:
#    extension CodeEditor { }
# 2. Run swiftlint:
swiftlint
# Expected: error matching forbidden_swiftui_extension_codeeditor.
# 3. Remove the probe and confirm clean:
swiftlint --strict
# Expected: 0 violations.
```

(Skip Step 3 if you trust the regex — but it's cheap insurance for the rule's existence claim.)

- [ ] **Step 4: Commit**

```bash
git add .swiftlint.yml
git commit -m "$(cat <<'EOF'
SwiftLint: forbid extension CodeEditor outside factory file

Custom rule errors on any 'extension CodeEditor { }' inside
Sources/CodeEditorPlugin/SwiftUI/ except for the factory file (which
hosts static factories that don't participate in chain composition).
Prevents reintroducing the chain-break footgun REVIEW.md flagged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update REVIEW.md and run full-suite verification

**Files:**
- Modify: `REVIEW.md`

- [ ] **Step 1: Final full-build + lint pass**

```bash
swift build && swiftlint --fix && swiftlint
swift build --target CodeEditorSample
```

Expected: both green; 0 violations.

- [ ] **Step 2: Targeted test run for all new + affected suites**

```bash
swift test --filter CodeEditorIntentTests
swift test --filter IntentCoordinatorWiringTests
swift test --filter ModifierChainCompositionTests
swift test --filter SwiftUICoordinatorTests
swift test --filter PerformanceObserverModifierTests
swift test --filter ActiveDocumentModifierTests
swift test --filter EditorControllerOnAttachTests
swift test --filter EditorInteractionStateBindingTests
```

Expected: all PASS.

- [ ] **Step 3: Full-suite parallel test run**

```bash
swift test --parallel
```

Expected: no NEW failures. Pre-existing failures (`RegexRangeHighlightProviderTests.testParsePerformance100KLines`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`, `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`, `EditorStatusBarSnapshots/*` parallel SIGSEGV) reproduce; nothing else fails.

- [ ] **Step 4: Update REVIEW.md**

Append a new dated batch section to `REVIEW.md` documenting the landed work. Position it after the most-recent existing batch section (the Completion ranking unification batch from 2026-05-14, around the top of the file).

The section should follow the format of prior batches — a table mapping spec items to their landed state, files-touched list, public-API-impact paragraph, test summary, and pre-existing-failure note. Use the spec at `docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md` and this plan as the source of truth.

Additionally, in the "What's left after this round" section near the bottom of `REVIEW.md`, mark the third item:

```
- **Inconsistent SwiftUI modifier return types** — `some View` vs `CodeEditor`. Pick one shape and migrate.
```

as landed:

```
- ~~**Inconsistent SwiftUI modifier return types** — `some View` vs `CodeEditor`. Pick one shape and migrate.~~ ✅ Landed in the SwiftUI modifier return-types batch on 2026-05-14. Every public modifier returns `some View`; the five formerly struct-mutator modifiers (.onTextChange, .onSelectionChange, .codeCompletion, .editorController, .editorInteractionState) now write to an internal CodeEditorIntent env value. SwiftLint rule `forbidden_swiftui_extension_codeeditor` prevents the regression class. Spec at `docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md`; plan at `docs/superpowers/plans/2026-05-14-swiftui-modifier-return-types.md`.
```

The status header at the top of REVIEW.md (currently dated "2026-05-14") should append a brief note: `… plus the SwiftUI modifier return-types batch (every public modifier returns `some View`; closes the last "What's left after this round" design item beyond LSP iOS and CodeEditorEnvironment.with nil-clearing)`.

- [ ] **Step 5: Commit**

```bash
git add REVIEW.md
git commit -m "$(cat <<'EOF'
REVIEW.md: SwiftUI modifier return-types batch landed

Every public CodeEditor modifier now returns some View; five
struct-mutators migrated to a CodeEditorIntent env value. SwiftLint
rule forbidden_swiftui_extension_codeeditor prevents the regression
class. Closes the third of three "needs design" items from "What's
left after this round" (only LSP iOS coverage and
CodeEditorEnvironment.with nil-clearing remain).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review checklist (run after Task 8)

Look at the plan against the spec with fresh eyes — this is a self-check, not a subagent dispatch:

- [ ] Spec section "Architecture > CodeEditorIntent" → Task 1.
- [ ] Spec section "Architecture > Internal env key" → Task 1.
- [ ] Spec section "Architecture > Public modifier bodies" (5 modifiers) → Task 3.
- [ ] Spec section "Architecture > 13 env-style modifiers" → Task 4.
- [ ] Spec section "Architecture > Representable wiring" → Tasks 2 (helper) + 3 (body uses helper).
- [ ] Spec section "Architecture > Stored properties drop" → Task 3 Step 4.
- [ ] Spec section "Behavior preservation > Stale callbacks during teardown" → Covered by existing `CodeEditorRepresentableHelper.dismantle`; not re-tested in this PR (existing coordinator dismantle tests stay green).
- [ ] Spec section "Behavior preservation > Last-write-wins" → Implicit in `transformEnvironment` semantics; spot-checked by `CodeEditorIntentTests.testIntentFieldsRoundtrip` and the chain composition tests.
- [ ] Spec section "Behavior preservation > Controller attach timing" → Covered by existing `EditorControllerOnAttachTests`; verified in Task 3 Step 7.
- [ ] Spec section "Testing strategy > CodeEditorIntentTests" → Task 1.
- [ ] Spec section "Testing strategy > ModifierChainCompositionTests" → Task 5.
- [ ] Spec section "Testing strategy > IntentCoordinatorWiringTests" → Task 2.
- [ ] Spec section "SwiftLint guard" → Task 7.
- [ ] Spec section "Public API impact > Source-breaking" → No code change required; the migration achieves it via Tasks 3-4. Plan flags in commit messages.
- [ ] Spec section "Migration scope > Files touched" — Task plan's file map matches.
- [ ] Spec section "Acceptance criteria" — all six covered by Tasks 1-8.

**Placeholder scan:** No "TBD", "TODO", "fill in details", or "similar to Task N" entries. Every step has either complete code or an exact command + expected output.

**Type consistency:** `CodeEditorIntent`, `codeEditorIntent`, `makeRepresentableCallbacks(from:textBinding:)` — names match across Tasks 1-3. `forbidden_swiftui_extension_codeeditor` rule name matches between Task 7 step and REVIEW.md text.

**Scope:** Eight tasks; each is one atomic unit with its own commit. Single PR.
