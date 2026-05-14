# `CodeEditorEnvironment` nil-clearing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `CodeEditorEnvironment.clearing(\.field)` keypath method and matching `View.codeEditorEnvironmentClearing(\.field)` modifier so hosts can clear optional env fields; fix the five legacy `EnvironmentValues` setter properties (`codeEditorMemoryMonitor`, `codeEditorEventSystem`, `codeEditorPerformanceObservation`, `codeEditorWorkspaceRoot`, `codeEditorRuntimeDependencies`) so writing `nil` actually clears (currently a silent no-op).

**Architecture:** Strictly additive on the framework. One new instance method on `CodeEditorEnvironment` constrained to `WritableKeyPath<Self, T?>` (compile-time-safe; non-optional fields rejected). One new `View` modifier delegating through `transformEnvironment`. Five legacy setter properties rewritten to write the struct field directly on a `var` copy instead of routing through the lossy `.with(...)` builder. Zero source-breaking changes; `.with(...)` keeps its parameters, types, and "nil means unchanged" semantic.

**Tech Stack:** Swift 6.3 (StrictConcurrency), SwiftUI (`EnvironmentValues`, `View.transformEnvironment`), XCTest. Spec at `docs/superpowers/specs/2026-05-14-codeeditor-environment-clearing-design.md` (commit `5d9fcce`).

---

## File Structure

**Framework — 1 modified:**
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` — add `clearing(_:)` method inside the existing `struct CodeEditorEnvironment` body, rewrite five legacy setter properties in `extension EnvironmentValues`, add `codeEditorEnvironmentClearing(_:)` inside the existing `extension View` block, update six doc comments.

**Tests — 1 modified:**
- `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift` — add twelve `@MainActor` XCTest cases at the bottom of the existing class.

No new files; no deletions.

---

## Task 1: Add five failing setter no-op tests (red)

**Files:**
- Modify: `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift` (append to the bottom of the existing class, before the closing `}`)

These tests verify that writing `nil` to each of the five legacy optional setter properties on `EnvironmentValues` actually clears the underlying field on `CodeEditorEnvironment`. They will fail today because all five setters route through `.with(...)`, which collapses `nil` to "no change". Adding the tests first lets us verify the bug exists before fixing it.

- [ ] **Step 1: Add the five setter-clears-on-nil tests**

Open `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift`. Locate the final closing `}` of the `SwiftUIEnvironmentConfigurationTests` class (around the file's end). Insert the following section immediately before it:

```swift
    // MARK: - Legacy setter clears-on-nil regression tests
    // Spec: docs/superpowers/specs/2026-05-14-codeeditor-environment-clearing-design.md

    @MainActor
    func testCodeEditorMemoryMonitorSetterClearsOnNil() {
        var values = EnvironmentValues()
        let monitor = MemoryMonitor()

        values.codeEditorMemoryMonitor = monitor
        XCTAssertNotNil(values.codeEditorMemoryMonitor, "Sanity: setter installs value.")

        values.codeEditorMemoryMonitor = nil
        XCTAssertNil(
            values.codeEditorMemoryMonitor,
            "Writing nil through the legacy setter must clear the underlying field."
        )
    }

    @MainActor
    func testCodeEditorEventSystemSetterClearsOnNil() {
        var values = EnvironmentValues()
        let system = UnifiedEventSystem()

        values.codeEditorEventSystem = system
        XCTAssertNotNil(values.codeEditorEventSystem, "Sanity: setter installs value.")

        values.codeEditorEventSystem = nil
        XCTAssertNil(
            values.codeEditorEventSystem,
            "Writing nil through the legacy setter must clear the underlying field."
        )
    }

    @MainActor
    func testCodeEditorPerformanceObservationSetterClearsOnNil() {
        var values = EnvironmentValues()
        let observation = PerformanceObservation()

        values.codeEditorPerformanceObservation = observation
        XCTAssertNotNil(values.codeEditorPerformanceObservation, "Sanity: setter installs value.")

        values.codeEditorPerformanceObservation = nil
        XCTAssertNil(
            values.codeEditorPerformanceObservation,
            "Writing nil through the legacy setter must clear the underlying field."
        )
    }

    @MainActor
    func testCodeEditorWorkspaceRootSetterClearsOnNil() {
        var values = EnvironmentValues()
        let url = URL(fileURLWithPath: "/tmp/codeeditor-test-workspace")

        values.codeEditorWorkspaceRoot = url
        XCTAssertEqual(values.codeEditorWorkspaceRoot, url, "Sanity: setter installs value.")

        values.codeEditorWorkspaceRoot = nil
        XCTAssertNil(
            values.codeEditorWorkspaceRoot,
            "Writing nil through the legacy setter must clear the underlying field."
        )
    }

    @MainActor
    func testCodeEditorRuntimeDependenciesSetterClearsOnNil() {
        var values = EnvironmentValues()
        let deps = EditorRuntimeDependencies.live()

        values.codeEditorRuntimeDependencies = deps
        XCTAssertNotNil(values.codeEditorRuntimeDependencies, "Sanity: setter installs value.")

        values.codeEditorRuntimeDependencies = nil
        XCTAssertNil(
            values.codeEditorRuntimeDependencies,
            "Writing nil through the legacy setter must clear the underlying field."
        )
    }
```

If the file uses 4-space indentation (it does — verify with the surrounding methods), match it.

- [ ] **Step 2: Run the five tests, expect five failures**

Run:
```bash
swift test --filter 'SwiftUIEnvironmentConfigurationTests/testCodeEditor(MemoryMonitor|EventSystem|PerformanceObservation|WorkspaceRoot|RuntimeDependencies)SetterClearsOnNil'
```

Expected: 5 failures at the second `XCTAssertNil` of each test, each saying "Writing nil through the legacy setter must clear the underlying field" failed because the value was still installed.

If any test fails to compile, the issue is one of:
- A typo in the property name (compare to lines 154-182 of `CodeEditorEnvironment+Extensions.swift`).
- `EditorRuntimeDependencies.live()` returning a `@MainActor`-isolated type that needs `@MainActor` propagation (the surrounding test method is already `@MainActor`, so this should be fine).

Do not commit yet — failing tests don't land in `main`. Proceed to Task 2.

---

## Task 2: Fix the five legacy setters (green) and commit

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` (lines 154-182 — five property blocks)

Rewrite each of the five optional setter properties to write the struct field directly on a `var` copy, bypassing the lossy `.with(...)` builder. The four non-optional setter properties (`codeEditorTheme`, `codeEditorLanguage`, `codeEditorConfiguration`, `codeEditorBecomeFirstResponder`) are not modified — they have no nil-collapse bug.

- [ ] **Step 1: Rewrite `codeEditorMemoryMonitor` (lines 154-158)**

Replace the current property block:

```swift
    /// Legacy: Access the memory monitor directly
    public var codeEditorMemoryMonitor: MemoryMonitor? {
        get { codeEditorEnvironment.memoryMonitor }
        set { codeEditorEnvironment = codeEditorEnvironment.with(memoryMonitor: newValue) }
    }
```

with:

```swift
    /// Legacy: Access the memory monitor directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`. (The setter writes the field directly
    /// instead of routing through `with(_:)`, which treats `nil` as
    /// "no change".)
    public var codeEditorMemoryMonitor: MemoryMonitor? {
        get { codeEditorEnvironment.memoryMonitor }
        set {
            var env = codeEditorEnvironment
            env.memoryMonitor = newValue
            codeEditorEnvironment = env
        }
    }
```

- [ ] **Step 2: Rewrite `codeEditorEventSystem` (lines 160-164)**

Replace:

```swift
    /// Legacy: Access the event system directly
    public var codeEditorEventSystem: UnifiedEventSystem? {
        get { codeEditorEnvironment.eventSystem }
        set { codeEditorEnvironment = codeEditorEnvironment.with(eventSystem: newValue) }
    }
```

with:

```swift
    /// Legacy: Access the event system directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorEventSystem: UnifiedEventSystem? {
        get { codeEditorEnvironment.eventSystem }
        set {
            var env = codeEditorEnvironment
            env.eventSystem = newValue
            codeEditorEnvironment = env
        }
    }
```

- [ ] **Step 3: Rewrite `codeEditorPerformanceObservation` (lines 166-170)**

Replace:

```swift
    /// Legacy: Access the performance observation directly
    public var codeEditorPerformanceObservation: PerformanceObservation? {
        get { codeEditorEnvironment.performanceObservation }
        set { codeEditorEnvironment = codeEditorEnvironment.with(performanceObservation: newValue) }
    }
```

with:

```swift
    /// Legacy: Access the performance observation directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorPerformanceObservation: PerformanceObservation? {
        get { codeEditorEnvironment.performanceObservation }
        set {
            var env = codeEditorEnvironment
            env.performanceObservation = newValue
            codeEditorEnvironment = env
        }
    }
```

- [ ] **Step 4: Rewrite `codeEditorWorkspaceRoot` (lines 172-176)**

Replace:

```swift
    /// Legacy: Access the workspace root directly
    public var codeEditorWorkspaceRoot: URL? {
        get { codeEditorEnvironment.workspaceRoot }
        set { codeEditorEnvironment = codeEditorEnvironment.with(workspaceRoot: newValue) }
    }
```

with:

```swift
    /// Legacy: Access the workspace root directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorWorkspaceRoot: URL? {
        get { codeEditorEnvironment.workspaceRoot }
        set {
            var env = codeEditorEnvironment
            env.workspaceRoot = newValue
            codeEditorEnvironment = env
        }
    }
```

- [ ] **Step 5: Rewrite `codeEditorRuntimeDependencies` (lines 178-182)**

Replace:

```swift
    /// Access complete runtime dependencies directly.
    public var codeEditorRuntimeDependencies: EditorRuntimeDependencies? {
        get { codeEditorEnvironment.runtimeDependencies }
        set { codeEditorEnvironment = codeEditorEnvironment.with(runtimeDependencies: newValue) }
    }
```

with:

```swift
    /// Access complete runtime dependencies directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorRuntimeDependencies: EditorRuntimeDependencies? {
        get { codeEditorEnvironment.runtimeDependencies }
        set {
            var env = codeEditorEnvironment
            env.runtimeDependencies = newValue
            codeEditorEnvironment = env
        }
    }
```

- [ ] **Step 6: Run the five setter tests, expect five passes**

Run:
```bash
swift test --filter 'SwiftUIEnvironmentConfigurationTests/testCodeEditor(MemoryMonitor|EventSystem|PerformanceObservation|WorkspaceRoot|RuntimeDependencies)SetterClearsOnNil'
```

Expected: 5 tests pass.

- [ ] **Step 7: Run the full `SwiftUIEnvironmentConfigurationTests` suite to verify no regression**

Run:
```bash
swift test --filter SwiftUIEnvironmentConfigurationTests
```

Expected: All existing tests pass alongside the 5 new ones.

- [ ] **Step 8: SwiftLint clean check**

Run:
```bash
swiftlint --strict --quiet
```

Expected: 0 violations.

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift \
        Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift

git commit -m "$(cat <<'EOF'
Fix silent no-op when clearing CodeEditorEnvironment legacy setters

The five optional EnvironmentValues setters (codeEditorMemoryMonitor,
codeEditorEventSystem, codeEditorPerformanceObservation,
codeEditorWorkspaceRoot, codeEditorRuntimeDependencies) routed nil
writes through CodeEditorEnvironment.with(...), which collapses nil
to "no change". Hosts writing `env.codeEditorMemoryMonitor = nil`
silently retained the prior value. Rewrite each setter to write the
field directly on a var copy. Adds five regression tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add five `clearing(_:)` tests + chained-clear test (red, compile-fail)

**Files:**
- Modify: `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift` (append below the setter regression block from Task 1)

These tests exercise the new `clearing<T>(_:WritableKeyPath<Self, T?>) -> Self` method directly. They will fail to compile because the method doesn't exist yet — confirming the test symbol matches the production symbol we add in Task 4.

- [ ] **Step 1: Add the six tests**

Insert immediately below the `// MARK: - Legacy setter clears-on-nil regression tests` block:

```swift
    // MARK: - clearing(_:) keypath method tests
    // Spec: docs/superpowers/specs/2026-05-14-codeeditor-environment-clearing-design.md

    @MainActor
    func testClearingWorkspaceRootReturnsNilField() {
        let url = URL(fileURLWithPath: "/tmp/codeeditor-test")
        let env = CodeEditorEnvironment(workspaceRoot: url)
        XCTAssertEqual(env.workspaceRoot, url, "Sanity: seeded.")

        let cleared = env.clearing(\.workspaceRoot)

        XCTAssertNil(cleared.workspaceRoot, "Field must be nil after clearing.")
        XCTAssertEqual(env.workspaceRoot, url, "Source env must be unchanged.")
    }

    @MainActor
    func testClearingMemoryMonitorReturnsNilField() {
        let monitor = MemoryMonitor()
        let env = CodeEditorEnvironment(memoryMonitor: monitor)
        XCTAssertNotNil(env.memoryMonitor, "Sanity: seeded.")

        let cleared = env.clearing(\.memoryMonitor)

        XCTAssertNil(cleared.memoryMonitor, "Field must be nil after clearing.")
        XCTAssertNotNil(env.memoryMonitor, "Source env must be unchanged.")
    }

    @MainActor
    func testClearingEventSystemReturnsNilField() {
        let system = UnifiedEventSystem()
        let env = CodeEditorEnvironment(eventSystem: system)
        XCTAssertNotNil(env.eventSystem, "Sanity: seeded.")

        let cleared = env.clearing(\.eventSystem)

        XCTAssertNil(cleared.eventSystem, "Field must be nil after clearing.")
        XCTAssertNotNil(env.eventSystem, "Source env must be unchanged.")
    }

    @MainActor
    func testClearingPerformanceObservationReturnsNilField() {
        let observation = PerformanceObservation()
        let env = CodeEditorEnvironment(performanceObservation: observation)
        XCTAssertNotNil(env.performanceObservation, "Sanity: seeded.")

        let cleared = env.clearing(\.performanceObservation)

        XCTAssertNil(cleared.performanceObservation, "Field must be nil after clearing.")
        XCTAssertNotNil(env.performanceObservation, "Source env must be unchanged.")
    }

    @MainActor
    func testClearingRuntimeDependenciesReturnsNilField() {
        let deps = EditorRuntimeDependencies.live()
        let env = CodeEditorEnvironment(runtimeDependencies: deps)
        XCTAssertNotNil(env.runtimeDependencies, "Sanity: seeded.")

        let cleared = env.clearing(\.runtimeDependencies)

        XCTAssertNil(cleared.runtimeDependencies, "Field must be nil after clearing.")
        XCTAssertNotNil(env.runtimeDependencies, "Source env must be unchanged.")
    }

    @MainActor
    func testClearingChainedClearsBothFields() {
        let url = URL(fileURLWithPath: "/tmp/codeeditor-test")
        let monitor = MemoryMonitor()
        let env = CodeEditorEnvironment(
            workspaceRoot: url,
            memoryMonitor: monitor
        )

        let cleared = env
            .clearing(\.workspaceRoot)
            .clearing(\.memoryMonitor)

        XCTAssertNil(cleared.workspaceRoot, "First chained clear must take effect.")
        XCTAssertNil(cleared.memoryMonitor, "Second chained clear must take effect.")
        XCTAssertEqual(cleared.language, env.language, "Untouched fields must be preserved.")
        XCTAssertEqual(cleared.theme, env.theme, "Untouched fields must be preserved.")
    }
```

- [ ] **Step 2: Run the six tests, expect compile failure**

Run:
```bash
swift test --filter 'SwiftUIEnvironmentConfigurationTests/testClearing'
```

Expected: compile failure with errors pointing at `.clearing(\.…)` — "no member 'clearing' in CodeEditorEnvironment" or similar.

This is the desired state. Do not commit. Proceed to Task 4.

---

## Task 4: Add `clearing(_:)` method (green) and commit

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` (insert inside the existing `struct CodeEditorEnvironment` body, after the `with(...)` method at line 106, before the closing `}` of the struct at line 107)

- [ ] **Step 1: Insert the `clearing(_:)` method**

Locate the closing `}` of `with(...)` (currently line 106) inside `public struct CodeEditorEnvironment`. The struct's own closing `}` is on line 107. Insert this method between them — immediately after line 106 and before line 107:

```swift

    /// Returns a copy with the optional field at `keyPath` set to `nil`.
    ///
    /// Use this to clear an optional environment field — the `with(_:)`
    /// builder treats `nil` parameters as "no change" and cannot clear.
    /// The `WritableKeyPath<Self, T?>` constraint makes the API
    /// correct-by-construction: non-optional fields like `theme`,
    /// `language`, `configuration`, and `becomeFirstResponder` are
    /// rejected at compile time.
    ///
    /// Chainable for multi-field clears:
    ///
    /// ```swift
    /// let cleared = env
    ///     .clearing(\.workspaceRoot)
    ///     .clearing(\.memoryMonitor)
    /// ```
    public func clearing<T>(_ keyPath: WritableKeyPath<Self, T?>) -> Self {
        var copy = self
        copy[keyPath: keyPath] = nil
        return copy
    }
```

The leading blank line separates the method visually from `with(...)`.

- [ ] **Step 2: Run the six `clearing` tests, expect all pass**

Run:
```bash
swift test --filter 'SwiftUIEnvironmentConfigurationTests/testClearing'
```

Expected: 6 tests pass (the five field-clear tests + the chained-clear test).

- [ ] **Step 3: Run the full `SwiftUIEnvironmentConfigurationTests` suite to verify no regression**

Run:
```bash
swift test --filter SwiftUIEnvironmentConfigurationTests
```

Expected: All existing tests pass, plus the 5 Task-1 setter tests, plus the 6 new `clearing` tests.

- [ ] **Step 4: SwiftLint clean check**

Run:
```bash
swiftlint --strict --quiet
```

Expected: 0 violations.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift \
        Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift

git commit -m "$(cat <<'EOF'
Add CodeEditorEnvironment.clearing(\.field) keypath method

Closes the load-bearing half of the "CodeEditorEnvironment.with(...)
cannot clear optional fields" item from REVIEW.md. New method is
constrained to WritableKeyPath<Self, T?> so non-optional fields are
rejected at compile time. Chainable. Six new tests cover each
optional field plus a chained-clear.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add failing modifier smoke test (red, compile-fail)

**Files:**
- Modify: `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift` (append below the `clearing(_:)` block)

The modifier is a 3-line `transformEnvironment` delegation to `clearing(_:)`. Behavioral correctness is already covered by the `clearing(_:)` unit tests. The modifier test is therefore a compile-and-shape smoke check matching the pattern in `Tests/CodeEditorPluginTests/Documents/ActiveDocumentModifierTests.swift` (`activeDocumentModifierChainCompiles` case).

- [ ] **Step 1: Add the modifier smoke test**

Insert immediately below the `clearing(_:)` test block:

```swift
    // MARK: - codeEditorEnvironmentClearing(_:) modifier tests
    // Spec: docs/superpowers/specs/2026-05-14-codeeditor-environment-clearing-design.md

    @MainActor
    func testCodeEditorEnvironmentClearingModifierChainCompiles() {
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let url = URL(fileURLWithPath: "/tmp/codeeditor-test")

        // Verify the modifier chain shape advertised in the spec.
        // If anything refuses to type-check, this expression won't compile.
        let view = CodeEditor(text: binding)
            .codeEditorEnvironment(workspaceRoot: url)
            .codeEditorEnvironmentClearing(\.workspaceRoot)

        XCTAssertNotNil(view, "Modifier chain must produce a non-nil view.")
    }
```

- [ ] **Step 2: Run the modifier test, expect compile failure**

Run:
```bash
swift test --filter 'SwiftUIEnvironmentConfigurationTests/testCodeEditorEnvironmentClearingModifierChainCompiles'
```

Expected: compile failure with an error pointing at `.codeEditorEnvironmentClearing(\.workspaceRoot)` — "no member 'codeEditorEnvironmentClearing' on View" or similar.

Do not commit. Proceed to Task 6.

---

## Task 6: Add `codeEditorEnvironmentClearing(_:)` modifier (green) and commit

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` (insert inside the existing `extension View` block, after the `codeEditorEnvironment(language:…)` convenience modifier at line 226, before the block's closing `}` at line 227)

- [ ] **Step 1: Insert the modifier**

Locate the closing `}` of the `codeEditorEnvironment(language: Language? = nil, …)` modifier (currently line 226) inside `extension View`. The extension's own closing `}` is on line 227. Insert this modifier between them — immediately after line 226 and before line 227:

```swift

    /// Clears the given optional field on the inherited
    /// `CodeEditorEnvironment`.
    ///
    /// Call-order semantics match the existing
    /// `.codeEditorEnvironment(...)` modifier family — clearing applies
    /// to whatever value was set up to this point in the modifier chain.
    /// Use this when the bulk `.codeEditorEnvironment(workspaceRoot:…)`
    /// modifier cannot express "clear this field" because passing `nil`
    /// is treated as "no change".
    ///
    /// ```swift
    /// CodeEditor(text: $text)
    ///     .codeEditorEnvironment(workspaceRoot: url)
    ///     // …conditional logic that no longer wants a workspace root…
    ///     .codeEditorEnvironmentClearing(\.workspaceRoot)
    /// ```
    public func codeEditorEnvironmentClearing<T>(
        _ keyPath: WritableKeyPath<CodeEditorEnvironment, T?>
    ) -> some View {
        transformEnvironment(\.codeEditorEnvironment) { env in
            env = env.clearing(keyPath)
        }
    }
```

The leading blank line separates the modifier visually from the preceding `codeEditorEnvironment(language:…)` overload.

- [ ] **Step 2: Run the modifier test, expect pass**

Run:
```bash
swift test --filter 'SwiftUIEnvironmentConfigurationTests/testCodeEditorEnvironmentClearingModifierChainCompiles'
```

Expected: 1 test passes.

- [ ] **Step 3: Run the full `SwiftUIEnvironmentConfigurationTests` suite to verify no regression**

Run:
```bash
swift test --filter SwiftUIEnvironmentConfigurationTests
```

Expected: All existing tests pass, plus the 5 setter tests from Task 1, plus the 6 clearing tests from Task 3, plus the 1 modifier test.

- [ ] **Step 4: SwiftLint clean check**

Run:
```bash
swiftlint --strict --quiet
```

Expected: 0 violations.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift \
        Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift

git commit -m "$(cat <<'EOF'
Add View.codeEditorEnvironmentClearing(\.field) modifier

Symmetric SwiftUI surface for CodeEditorEnvironment.clearing(\.field).
Three-line transformEnvironment delegation. Same call-order semantics
as the existing .codeEditorEnvironment(...) modifier family. Adds one
shape/compile smoke test.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Update `with(...)` doc comment and commit

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` (the doc comment for `with(...)` at line 83)

The five legacy-setter doc comments already gained a "writing nil clears" note in Task 2. The `with(...)` doc comment still says only "Creates a copy with updated values" and needs the cross-reference to `clearing(_:)`.

- [ ] **Step 1: Replace the `with(...)` doc comment**

Locate the line currently reading `/// Creates a copy with updated values` (line 83 in the original file; line numbers will have shifted after Tasks 2, 4, 6 — search for the exact string instead). Replace that single line with:

```swift
    /// Creates a copy with updated values.
    ///
    /// This builder is set-only. Passing `nil` for any optional
    /// parameter is treated as "no change" — the existing value is
    /// preserved. To clear an optional field, use ``clearing(_:)``
    /// or write the field directly on a `var` copy of the
    /// environment.
```

The four-space indentation matches the surrounding struct body.

- [ ] **Step 2: Build clean**

Run:
```bash
swift build
```

Expected: build succeeds with no warnings or errors.

- [ ] **Step 3: SwiftLint clean check**

Run:
```bash
swiftlint --strict --quiet
```

Expected: 0 violations.

- [ ] **Step 4: Run the full `SwiftUIEnvironmentConfigurationTests` suite once more**

Run:
```bash
swift test --filter SwiftUIEnvironmentConfigurationTests
```

Expected: All tests pass — the 12 new ones plus everything previously in the suite. No regressions.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift

git commit -m "$(cat <<'EOF'
Doc: with(_:) is set-only; cross-reference clearing(_:)

Spell out the nil-collapse contract on CodeEditorEnvironment.with(...)
and point at the new clearing(_:) keypath method for the clearing
path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Final verification

This task is a verification net, not a code change. Run each command, report each result. If any command fails, stop and investigate before declaring the work done.

- [ ] **Step 1: Full build**

Run:
```bash
swift build
```

Expected: clean build, no warnings.

- [ ] **Step 2: SwiftLint strict**

Run:
```bash
swiftlint --strict --quiet
```

Expected: exit 0, no output.

- [ ] **Step 3: Targeted test run for the touched surface**

Run:
```bash
swift test --filter 'SwiftUIEnvironment|EnvironmentConfiguration'
```

Expected: all tests pass. Confirm that the 12 new tests are visible in the output (5 setter clears + 5 clearing field tests + 1 chained-clear + 1 modifier smoke).

- [ ] **Step 4: Full parallel suite regression net**

Run:
```bash
swift test --parallel
```

Expected: the suite reports the same failures documented in `REVIEW.md`'s Status section, and nothing else. Known pre-existing failures (do not investigate as part of this work — they reproduce on bare `main`):
- `RegexRangeHighlightProviderTests.testParsePerformance100KLines` (flake on slower machines).
- `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap` (pre-existing).
- `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage` (sample test rot from a prior batch).
- `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed` (sample test rot from a prior batch).
- `EditorStatusBarSnapshots/*` SIGSEGV under `--parallel` (Swift-Testing/XCTest snapshot bridge).
- `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness` (flake under parallel load).
- `PerformanceObservationTests.restartAfterStopResumesRefreshTicks` (flake under parallel load).
- `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor` (FPS counter not running headless).

If any *new* failure appears, isolate it with `swift test --filter <name>` and investigate before declaring the work done.

- [ ] **Step 5: Confirm commit graph**

Run:
```bash
git log --oneline main..HEAD
```

Expected: four commits, most-recent first:

```
<sha>  Doc: with(_:) is set-only; cross-reference clearing(_:)
<sha>  Add View.codeEditorEnvironmentClearing(\.field) modifier
<sha>  Add CodeEditorEnvironment.clearing(\.field) keypath method
<sha>  Fix silent no-op when clearing CodeEditorEnvironment legacy setters
```

If the count or ordering differs, audit the prior tasks — a step was skipped.

- [ ] **Step 6: REVIEW.md update (separate commit)**

This step is the work's pedagogical close-out. Append a new section to `REVIEW.md`'s landed-batches list following the style of the existing batches (e.g., "SwiftUI modifier return-types batch (landed 2026-05-14)"). The section should:

- Name the batch (e.g., "`CodeEditorEnvironment` nil-clearing batch (landed 2026-05-14)").
- Cite the spec and plan paths.
- Tabulate the four items: setter fix, `clearing(_:)` method, modifier, doc comments.
- List files touched, tests added (12), public API impact.
- Update the "What's left after this round" section to mark the `CodeEditorEnvironment.with(...)` item as ✅ Landed, leaving only the LSP iOS coverage item as truly open.

Commit:

```bash
git add REVIEW.md

git commit -m "$(cat <<'EOF'
REVIEW.md: CodeEditorEnvironment nil-clearing batch landed

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review notes

This section is a checklist run by the plan author, captured here for traceability.

**Spec coverage:**
- "Provide an idiomatic, source-compatible way to clear any optional field" — Tasks 4 (method) + 6 (modifier).
- "Fix the silent-no-op on the five legacy `EnvironmentValues` setters" — Task 2.
- "Stay strictly additive on the public API" — verified by the diff shape (no parameter-type or signature changes to existing surface).
- "Use the keypath-based shape" — Task 4 method body and Task 6 modifier body both use `WritableKeyPath<…, T?>`.
- Doc-comment updates (1 on `.with(...)` + 5 setters = 6 total) — five land in Task 2, one lands in Task 7.
- Testing: 5 setter no-op tests (Task 1), 5 `clearing(_:)` field tests (Task 3), 1 chained-clear test (Task 3), 1 modifier smoke test (Task 5) = 12 tests total. Matches the spec's "Total: 12 new tests."
- Files touched: `CodeEditorEnvironment+Extensions.swift` (Tasks 2, 4, 6, 7) + `SwiftUIEnvironmentConfigurationTests.swift` (Tasks 1, 3, 5) = 2 files modified. Matches the spec's "Two files modified, zero added, zero deleted."
- Verification: `swift build`, `swiftlint --strict`, targeted test, parallel test — Task 8 steps 1-4. Matches the spec's verification list.

**Placeholder scan:** No "TBD", "TODO", "implement later". All test bodies and implementation code shown in full.

**Type consistency:** `clearing` is named identically in both the method (Task 4) and the modifier body (Task 6: `env.clearing(keyPath)`). Method signature `clearing<T>(_ keyPath: WritableKeyPath<Self, T?>) -> Self` is identical between Task 4 implementation and the call site in Task 6. Modifier signature `codeEditorEnvironmentClearing<T>(_ keyPath: WritableKeyPath<CodeEditorEnvironment, T?>) -> some View` is identical between Task 5 (test usage) and Task 6 (implementation). Field accessor names in setter rewrites match the property names on `CodeEditorEnvironment` (Task 2 lines vs the existing struct fields at the spec's lines 26-55).
