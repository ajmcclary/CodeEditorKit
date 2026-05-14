# `CodeEditorEnvironment` nil-clearing — Design Spec

**Date:** 2026-05-14
**Closes:** "What's left after this round" item from [`REVIEW.md`](../../../REVIEW.md) — *"`CodeEditorEnvironment.with(...)` cannot clear optional fields — needs an explicit-nil sentinel or overloaded clearing variants."*
**Status:** Draft for user review.

## Problem

`CodeEditorEnvironment` (`Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift:24-107`) is the consolidated host-facing SwiftUI environment value. Five of its nine fields are optional: `workspaceRoot: URL?`, `memoryMonitor: MemoryMonitor?`, `eventSystem: UnifiedEventSystem?`, `runtimeDependencies: EditorRuntimeDependencies?`, `performanceObservation: PerformanceObservation?`.

The builder method, lines 84-106, takes optional parameters and collapses `nil` to "no change":

```swift
public func with(
    /* … */
    workspaceRoot: URL? = nil,
    memoryMonitor: MemoryMonitor? = nil,
    /* … */
) -> Self {
    Self(
        /* … */
        workspaceRoot: workspaceRoot ?? self.workspaceRoot,
        memoryMonitor: memoryMonitor ?? self.memoryMonitor,
        /* … */
    )
}
```

A host has no way to *clear* an optional through the builder. `env.with(workspaceRoot: nil)` is a no-op.

That alone would be a polish-grade API gap. The load-bearing bug is in the five legacy `EnvironmentValues` setters at lines 154-182, which route writes through `.with(...)`:

```swift
public var codeEditorMemoryMonitor: MemoryMonitor? {
    get { codeEditorEnvironment.memoryMonitor }
    set { codeEditorEnvironment = codeEditorEnvironment.with(memoryMonitor: newValue) }
}
```

Writing `nil` to any of these properties is a silent no-op. SwiftUI hosts will naturally write `env.codeEditorMemoryMonitor = nil` expecting the obvious semantic — clear the field — and instead get nothing. The bug is invisible at the call site, surfaces only when a downstream consumer observes the still-attached value, and matches no documented behavior.

In-tree audit (grep across `Sources/`, `Tests/`): no code currently writes nil to any of the five setters or passes nil to the corresponding `.with(...)` parameters. This is API-completeness work driven by host expectations, not a discovered failure.

## Goals

- Provide an idiomatic, source-compatible way to clear any optional field on `CodeEditorEnvironment` through both the value-builder path (`.with(...)` family) and the SwiftUI modifier path (`View.codeEditorEnvironment(...)` family).
- Fix the silent-no-op on the five legacy `EnvironmentValues` setters so `env.codeEditorMemoryMonitor = nil` actually clears.
- Stay strictly additive on the public API. No existing call site changes shape; no parameter types change.
- Use the keypath-based shape established by the rest of Swift's standard library (`KeyPath`, `WritableKeyPath`) so the new method is discoverable and type-safe at the compile boundary.

## Non-goals

- Redesigning `.with(...)` to support clearing. Keep it as set-only (now documented). The clearing path is separate.
- Adding per-field sentinel enums like `BecomeFirstResponderOption`. That precedent only applies where the field has three distinct host intents (`yes` / `no` / `unchanged`); for the five optional reference types here, `set-to-value` vs `clear` is sufficient.
- Variadic or batched clearing (`clearing(\.a, \.b, \.c)`). Chaining handles it: `env.clearing(\.workspaceRoot).clearing(\.memoryMonitor)`. Two callers in foreseeable use; no reason to grow the surface preemptively.
- Deprecating the legacy `EnvironmentValues` properties (`codeEditorMemoryMonitor`, etc.). They remain for hosts that read individual fields; the setter no-op fix is the entire scope.
- Cross-cutting refactors of `CodeEditorEnvironment` (struct re-layout, splitting into nested types). Out of scope.

## Design

### Public API

A single new method on `CodeEditorEnvironment` and a single new `View` modifier. All additive.

```swift
@available(macOS 12.0, iOS 16.0, *)
extension CodeEditorEnvironment {
    /// Returns a copy with the optional field at `keyPath` set to nil.
    ///
    /// Use this to clear an optional environment field — the `.with(...)`
    /// builder treats `nil` parameters as "no change" and cannot clear.
    /// Compile-time-safe: the `WritableKeyPath<Self, T?>` constraint
    /// rejects non-optional fields.
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
}

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Clears the given optional field on the inherited
    /// `CodeEditorEnvironment`. Call-order semantics match the existing
    /// `.codeEditorEnvironment(...)` modifier family — clearing applies
    /// to whatever value was set up to this point in the modifier chain.
    public func codeEditorEnvironmentClearing<T>(
        _ keyPath: WritableKeyPath<CodeEditorEnvironment, T?>
    ) -> some View {
        transformEnvironment(\.codeEditorEnvironment) { env in
            env = env.clearing(keyPath)
        }
    }
}
```

The `WritableKeyPath<Self, T?>` constraint is load-bearing: only optional fields satisfy it, so `env.clearing(\.theme)` (Theme is non-optional) fails to compile. There is no runtime check; the API is correct-by-construction.

### Legacy setter fix

The five optional `EnvironmentValues` properties are rewritten to assign the field directly on a struct copy, bypassing `.with(...)`:

```swift
// Before (lines 154-158):
public var codeEditorMemoryMonitor: MemoryMonitor? {
    get { codeEditorEnvironment.memoryMonitor }
    set { codeEditorEnvironment = codeEditorEnvironment.with(memoryMonitor: newValue) }
}

// After:
public var codeEditorMemoryMonitor: MemoryMonitor? {
    get { codeEditorEnvironment.memoryMonitor }
    set {
        var env = codeEditorEnvironment
        env.memoryMonitor = newValue
        codeEditorEnvironment = env
    }
}
```

Same shape applied to `codeEditorEventSystem`, `codeEditorPerformanceObservation`, `codeEditorWorkspaceRoot`, `codeEditorRuntimeDependencies`. The four non-optional setters (`codeEditorTheme`, `codeEditorLanguage`, `codeEditorConfiguration`, `codeEditorBecomeFirstResponder`) are unchanged — they were never affected by the nil-collapse bug, and routing through `.with(...)` is harmless there.

This works because `CodeEditorEnvironment`'s stored properties are already `public var` (lines 26-55). The struct is mutable; we just stop interposing the lossy builder.

### Doc-comment updates

- `with(...)` (line 83) gains a one-paragraph note: "This builder is set-only. Passing nil for any optional parameter is treated as 'no change'. To clear an optional field, use `clearing(_:)` or write to it directly on a `var` copy."
- The five optional `EnvironmentValues` properties each get a one-line note: "Writing `nil` clears the underlying field on the `CodeEditorEnvironment`."

### What does NOT change

- The `View.codeEditorEnvironment(language:theme:configuration:becomeFirstResponder:workspaceRoot:memoryMonitor:eventSystem:runtimeDependencies:performanceObservation:)` convenience modifier (lines 202-226). It still routes through `.with(...)` and still cannot clear optionals from a single call. That's fine — hosts wanting to clear chain `.codeEditorEnvironmentClearing(\.field)` after their setter call. Adding nil-clearing to the bulk modifier would require either parameter-type changes (source-breaking) or per-field overloads (surface explosion); the chainable companion modifier is sufficient.
- `.with(...)` signature, parameter types, parameter labels.
- `EnvironmentValues` getter behavior on any property.
- The `CodeEditorEnvironmentBuilder` result builder.
- All existing call sites in `Sources/`, `Tests/`, sample.

## Testing

All tests added to existing test files. No new test targets.

**Setter no-op regression coverage** — `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift`, 5 new XCTest cases:

- `testCodeEditorMemoryMonitorSetterClearsOnNil`
- `testCodeEditorEventSystemSetterClearsOnNil`
- `testCodeEditorPerformanceObservationSetterClearsOnNil`
- `testCodeEditorWorkspaceRootSetterClearsOnNil`
- `testCodeEditorRuntimeDependenciesSetterClearsOnNil`

Each test seeds the underlying `CodeEditorEnvironment` with a non-nil value via direct construction, writes `nil` through the legacy property setter on a captured `EnvironmentValues`, and asserts the getter returns `nil`. Without the fix, all five fail; with the fix, all five pass.

**`clearing(_:)` semantic coverage** — same file, 5 new cases:

- `testClearingWorkspaceRootReturnsNilField`
- `testClearingMemoryMonitorReturnsNilField`
- `testClearingEventSystemReturnsNilField`
- `testClearingPerformanceObservationReturnsNilField`
- `testClearingRuntimeDependenciesReturnsNilField`

Each seeds a populated `CodeEditorEnvironment`, calls `.clearing(\.<field>)`, asserts only that field is nil on the result and all other fields are byte-identical to the seed.

**Chained-clear test** — 1 case:

- `testClearingChainedClearsBothFields` — `env.clearing(\.workspaceRoot).clearing(\.memoryMonitor)` returns an env with both fields nil and all others preserved.

**Modifier integration test** — 1 case using SwiftUI's environment-read pattern already used elsewhere in the file:

- `testCodeEditorEnvironmentClearingModifierWritesNil` — apply `.codeEditorEnvironment(workspaceRoot: url)` then `.codeEditorEnvironmentClearing(\.workspaceRoot)` to a probe view; read `\.codeEditorEnvironment.workspaceRoot`; assert nil.

Total: 12 new tests.

**Compile-fail evidence** is documented in the spec only — there is no idiomatic way to assert "this code would not compile" inside a Swift test target without a separate macro-testing harness. The constraint `WritableKeyPath<Self, T?>` is verified by inspection.

## Public API impact

**Strictly additive on the framework:**
- `CodeEditorEnvironment.clearing<T>(_:WritableKeyPath<Self, T?>) -> Self` — new instance method.
- `View.codeEditorEnvironmentClearing<T>(_:WritableKeyPath<CodeEditorEnvironment, T?>) -> some View` — new modifier.

**Behavior change visible to hosts:**
- Writing `nil` to any of `codeEditorMemoryMonitor`, `codeEditorEventSystem`, `codeEditorPerformanceObservation`, `codeEditorWorkspaceRoot`, `codeEditorRuntimeDependencies` now actually clears the underlying field. Previous behavior was a silent no-op. Hosts depending on the no-op — vanishingly unlikely; the behavior is undocumented and contrary to intuition — would see clearing where they previously saw retention. We accept this as a correctness fix, not a compatibility break.

**No source-breaking changes.** `.with(...)` keeps its parameters, types, and "nil means unchanged" semantic. Existing test fixtures and the sample compile without modification.

## Risks and follow-ups

- **Risk: discoverability.** The clearing API lives next to `.with(...)` but the two paths are spelled differently. A host reading the doc comment on `.with(...)` should find `clearing(_:)` quickly; we lean on the cross-reference.
- **Risk: chained-clear allocations.** `env.clearing(\.workspaceRoot).clearing(\.memoryMonitor)` makes two struct copies. The struct is small and copies are not on a hot path (env-rebuilds happen at most a handful of times per SwiftUI body). Not optimizing.
- **Follow-up not in this PR:** The bulk `View.codeEditorEnvironment(language:…)` convenience modifier still can't clear in a single call. If a host pattern emerges where multi-field clears via the modifier become idiomatic, the natural next step is `View.codeEditorEnvironmentClearing(_ keyPaths: PartialKeyPath<CodeEditorEnvironment>...)` accepting variadic keypaths. Deferred; chainable single-keypath modifier solves every known use case.
- **Follow-up not in this PR:** The four non-optional setter properties (`codeEditorTheme`, `codeEditorLanguage`, `codeEditorConfiguration`, `codeEditorBecomeFirstResponder`) could also be migrated to direct field-write for consistency, but they have no bug and the change would be churn-only. Leave them.

## Files touched

- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorEnvironment+Extensions.swift` — add `clearing(_:)` method, add `codeEditorEnvironmentClearing(_:)` modifier, rewrite 5 legacy setters, update 6 doc comments.
- `Tests/CodeEditorPluginTests/SwiftUIEnvironmentConfigurationTests.swift` — add 12 new tests.

Two files modified, zero added, zero deleted.

## Verification

- `swift build`
- `swiftlint --strict`
- Targeted `swift test --filter "SwiftUIEnvironment|Environment"` — the touched suite plus adjacent env coverage.
- `swift test --parallel` — full-suite regression net, expected to reproduce only the pre-existing failures documented in `REVIEW.md` (no new failures introduced).
