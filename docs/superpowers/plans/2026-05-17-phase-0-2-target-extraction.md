# Phase 0–2 Target Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract five new internal-only SPM library targets (`CodeEditorCommon`, `CodeEditorPlatform`, `CodeEditorTextModel`, `CodeEditorConfiguration`, `CodeEditorTheming`) from the monolithic `CodeEditorPlugin` target without changing the umbrella's name or its public consumer-facing API.

**Architecture:** One pre-flight cleanup commit performs all cross-target surgery (relocating shared types, splitting tangled files, extracting cross-boundary extensions into the correct target's source root). The five extraction commits that follow are then pure `git mv` plus `Package.swift` edits. The umbrella stays the sole public SPM product; new targets are internal `.target(...)` entries linked via the umbrella's `dependencies:` list.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftLint (strict mode), XCTest + Swift Testing, snapshot testing via the `ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable` fork.

**Spec:** [`docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md`](../specs/2026-05-17-phase-0-2-target-extraction-design.md)

**Spec-gap notes (discovered during plan writing):**
1. Four cross-target leaks in `Platform/` that the spec did not catch (`PlatformCapabilities.swift`, `PlatformConfigurations.swift`, `TextInputFeatures.swift` each have `extension CodeEditorView` or `extension EditorConfiguration` blocks; `CodeEditorView+EnclosingScrollView.swift` is entirely a view extension). Task 1 absorbs the surgery to relocate these to the correct target's source root before Platform extraction.
2. `CodeEditorDependencies.swift` cannot move to `CodeEditorCommon` as the spec §3a proposed: it's an `internal` DI factory that references types from many future targets (`MemoryMonitor` in `Performance/`, `PlatformCapabilities` in `Platform/`, `LanguageMetadataRegistry` in `Languages/`, etc.). The plan keeps it in `Core/` for now; revisit during the Core/ split (NEXT.md phase 8). `CodeEditorError.swift` still moves to `CodeEditorCommon` as planned — it's a pure enum with only Foundation deps and an in-file `ValidationError`.

---

## File Structure

### Files moved (pre-flight, Task 1)

From `Core/` to a staging dir under the existing target:
- `Sources/CodeEditorPlugin/Core/CodeEditorError.swift` → `Sources/CodeEditorPlugin/Common/Errors/CodeEditorError.swift`

`CodeEditorDependencies.swift` stays in `Core/` — see spec-gap note #2 above.

From `Text/` to `Core/Text/`:
- `Sources/CodeEditorPlugin/Text/TextKitLineNumberHelper.swift` → `Sources/CodeEditorPlugin/Core/Text/TextKitLineNumberHelper.swift`
- `Sources/CodeEditorPlugin/Text/TextKitBridge.swift` → `Sources/CodeEditorPlugin/Core/Text/TextKitBridge.swift`
- `Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift` → `Sources/CodeEditorPlugin/Core/Text/LineGeometryEditHandler.swift`
- `Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift` → `Sources/CodeEditorPlugin/Core/Text/TextKit2RenderingOptimizer.swift`

From `Platform/` to `Core/`:
- `Sources/CodeEditorPlugin/Platform/CodeEditorView+EnclosingScrollView.swift` → `Sources/CodeEditorPlugin/Core/CodeEditorView+EnclosingScrollView.swift`

### Files created (pre-flight, Task 1)

- `Sources/CodeEditorPlugin/Core/CodeEditorView+Configuration.swift` — view-side extension absorbing the `apply(to:)` method (now `view.apply(configuration:)`)
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TextInputFeatureTarget.swift` — two `CodeEditorView: TextInputFeatureTarget` conformance blocks extracted from `Platform/TextInputFeatures.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformCapabilities.swift` — `extension CodeEditorView { ... }` block extracted from `Platform/PlatformCapabilities.swift`
- `Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift` — `extension EditorConfiguration { applyTextInputFeatures(to:) }` extracted from `Platform/TextInputFeatures.swift`
- `Sources/CodeEditorPlugin/Core/EditorConfiguration+PlatformConfigurations.swift` — `extension EditorConfiguration { ... }` block extracted from `Platform/PlatformConfigurations.swift`

### Files modified (pre-flight, Task 1)

- `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift` — remove `apply(to:)` method (lines 288–293)
- `Sources/CodeEditorPlugin/Platform/TextInputFeatures.swift` — remove three extension blocks at the end (CodeEditorView conformances + EditorConfiguration extension)
- `Sources/CodeEditorPlugin/Platform/PlatformCapabilities.swift` — remove `extension CodeEditorView` block at line 207
- `Sources/CodeEditorPlugin/Platform/PlatformConfigurations.swift` — remove `extension EditorConfiguration` block at line 249
- 7 call sites of `configuration.apply(to: view)` in `Sources/` → `view.apply(configuration:)`
- 10 call sites of `configuration.apply(to: view)` in `Tests/` → `view.apply(configuration:)`

### Files moved (extraction commits 2–6)

| Commit | From | To |
|---|---|---|
| 2 | `Sources/CodeEditorPlugin/Common/**` | `Sources/CodeEditorCommon/**` |
| 2 | `Sources/CodeEditorPlugin/Extensions/**` | `Sources/CodeEditorCommon/Extensions/**` |
| 2 | `Sources/CodeEditorPlugin/Utilities/**` | `Sources/CodeEditorCommon/Utilities/**` |
| 2 | `Sources/CodeEditorPlugin/Models/**` | `Sources/CodeEditorCommon/Models/**` |
| 3 | `Sources/CodeEditorPlugin/Platform/**` | `Sources/CodeEditorPlatform/**` |
| 4 | `Sources/CodeEditorPlugin/Text/**` (47 files) | `Sources/CodeEditorTextModel/Text/**` |
| 4 | `Sources/CodeEditorPlugin/Documents/**` | `Sources/CodeEditorTextModel/Documents/**` |
| 5 | `Sources/CodeEditorPlugin/Configuration/**` | `Sources/CodeEditorConfiguration/**` |
| 6 | `Sources/CodeEditorPlugin/Theming/**` | `Sources/CodeEditorTheming/**` |
| 6 | `Sources/CodeEditorPlugin/Resources/Themes/**` | `Sources/CodeEditorTheming/Resources/Themes/**` |

### `Package.swift` edits

- Commits 2, 3, 4, 5, 6 each add a new `.target(...)` entry and add the new target name to `CodeEditorPlugin` target's `dependencies:`.
- Commit 6 additionally removes the `resources: [.process("Resources/Themes")]` entry from `CodeEditorPlugin` and adds it to `CodeEditorTheming`.

---

## Task 1: Pre-flight cleanup (Commit 1)

**Files:**
- Move: 6 existing files (5 listed in "Files moved (pre-flight)", plus `CodeEditorView+EnclosingScrollView.swift`)
- Create: 5 new files (listed in "Files created (pre-flight)")
- Modify: 4 existing files + 17 call sites (listed in "Files modified (pre-flight)")

This task creates a staging directory `Sources/CodeEditorPlugin/Common/` and a new subdir `Sources/CodeEditorPlugin/Core/Text/`, both inside the existing target. No `Package.swift` changes. All work is internal to the umbrella; consumers see only the `apply(to:)` call-shape change.

- [ ] **Step 1.1: Verify clean working tree and main branch**

```bash
git status
git branch --show-current
```

Expected: `nothing to commit, working tree clean` and `main`.

- [ ] **Step 1.2: Relocate `CodeEditorError.swift` to staging**

```bash
mkdir -p Sources/CodeEditorPlugin/Common/Errors
git mv Sources/CodeEditorPlugin/Core/CodeEditorError.swift Sources/CodeEditorPlugin/Common/Errors/CodeEditorError.swift
```

- [ ] **Step 1.3: (Skipped — `CodeEditorDependencies.swift` stays in `Core/`)**

The spec proposed moving this file too, but its internal DI factories reference types from `Performance/`, `Platform/`, and `Languages/`, none of which belong in `CodeEditorCommon`. Leaving it in `Core/` until the phase-8 Core split.

- [ ] **Step 1.4: Move four `Text/` view-helper files into `Core/Text/`**

```bash
mkdir -p Sources/CodeEditorPlugin/Core/Text
git mv Sources/CodeEditorPlugin/Text/TextKitLineNumberHelper.swift Sources/CodeEditorPlugin/Core/Text/TextKitLineNumberHelper.swift
git mv Sources/CodeEditorPlugin/Text/TextKitBridge.swift Sources/CodeEditorPlugin/Core/Text/TextKitBridge.swift
git mv Sources/CodeEditorPlugin/Text/LineGeometryEditHandler.swift Sources/CodeEditorPlugin/Core/Text/LineGeometryEditHandler.swift
git mv Sources/CodeEditorPlugin/Text/TextKit2RenderingOptimizer.swift Sources/CodeEditorPlugin/Core/Text/TextKit2RenderingOptimizer.swift
```

- [ ] **Step 1.5: Move `CodeEditorView+EnclosingScrollView.swift` from `Platform/` to `Core/`**

```bash
git mv Sources/CodeEditorPlugin/Platform/CodeEditorView+EnclosingScrollView.swift Sources/CodeEditorPlugin/Core/CodeEditorView+EnclosingScrollView.swift
```

- [ ] **Step 1.6: Create `Core/CodeEditorView+Configuration.swift` with the absorbed `apply` method**

Write `Sources/CodeEditorPlugin/Core/CodeEditorView+Configuration.swift`:

```swift
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Configuration Application

@MainActor public extension CodeEditorView {
    /// Apply an editor configuration to this view.
    ///
    /// Updates the view with all settings from the configuration, handling
    /// platform-specific differences. Equivalent to assigning the configuration
    /// to the view's `configuration` property and triggering any platform-specific
    /// text-input feature application.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfiguration.minimal
    /// try view.apply(configuration: config)
    /// ```
    ///
    /// - Parameter configuration: The configuration to apply.
    /// - Throws: A `CodeEditorError` if the configuration fails validation.
    func apply(configuration: EditorConfiguration) throws {
        try configuration.validateAndThrow()
        self.configuration = configuration
        configuration.applyTextInputFeatures(to: self)
    }
}
```

- [ ] **Step 1.7: Remove `apply(to:)` from `EditorConfiguration.swift`**

Edit `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift`: delete the documentation block + `@MainActor public func apply(to view: CodeEditorView) throws { ... }` method (currently lines ~256–293). The `validateAndThrow()` method and `createCodeFoldingConfiguration()` method directly below must remain intact.

After edit, confirm `grep -n "func apply(to view: CodeEditorView)" Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift` returns no matches.

- [ ] **Step 1.8: Update 7 source call sites of `configuration.apply(to: view)`**

For each of these files, change the call:

| File:line | Before | After |
|---|---|---|
| `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift:196` | `try configuration.apply(to: textView)` | `try textView.apply(configuration: configuration)` |
| `Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift:71` | `try container.configuration.apply(to: components.textView)` | `try components.textView.apply(configuration: container.configuration)` |
| `Sources/CodeEditorPlugin/Core/EditorRuntime.swift:124` | `try configuration.apply(to: view)` | `try view.apply(configuration: configuration)` |
| `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift:68` | `try configuration.apply(to: textView)` | `try textView.apply(configuration: configuration)` |
| `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift:339` | `try configuration.apply(to: textView)` | `try textView.apply(configuration: configuration)` |
| `Sources/CodeEditorPlugin/Core/CodeEditorView.swift:60` | doc comment `config.apply(to: editor)` | doc comment `try editor.apply(configuration: config)` |
| `Sources/CodeEditorPlugin/Performance/MemoryMonitor.swift:35` | doc comment `config.apply(to: editorView)` | doc comment `try editorView.apply(configuration: config)` |

Use the Edit tool one file at a time. After all edits:

```bash
grep -rn "configuration\.apply(to:" Sources/ 2>/dev/null
```

Expected: no matches in `Sources/`. (Doc-comment matches are fine if they're the new form.)

- [ ] **Step 1.9: Update 10 test call sites of `config.apply(to:)`**

| File:line | Before | After |
|---|---|---|
| `Tests/CodeEditorPluginTests/MinimapIntegrationTests.swift:194` | `try? config.apply(to: textView)` | `try? textView.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/MinimapIntegrationTests.swift:199` | `try? config.apply(to: textView)` | `try? textView.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/ReviewRemediationRegressionTests.swift:120` | `XCTAssertThrowsError(try invalidConfiguration.apply(to: textView))` | `XCTAssertThrowsError(try textView.apply(configuration: invalidConfiguration))` |
| `Tests/CodeEditorPluginTests/LargeFilePerformanceTests.swift:150` | `try? config.apply(to: textView)` | `try? textView.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/LargeFilePerformanceTests.swift:201` | `try? config.apply(to: textView)` | `try? textView.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/LargeFilePerformanceTests.swift:275` | `try? config.apply(to: textView)` | `try? textView.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/LargeFilePerformanceTests.swift:385` | `try? config.apply(to: textView)` | `try? textView.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift:74` | `try setup.apply(to: editor)` | `try editor.apply(configuration: setup)` |
| `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift:85` | `try? config.apply(to: editor)` | `try? editor.apply(configuration: config)` |
| `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift:110` | `try setup.apply(to: editor)` | `try editor.apply(configuration: setup)` |
| `Tests/CodeEditorPluginTests/MemoryMonitorDITests.swift:130` | `try valueOnlyConfiguration.apply(to: editor)` | `try editor.apply(configuration: valueOnlyConfiguration)` |
| `Tests/CodeEditorPluginTests/SimpleMemoryTest.swift:31` | `try? config.apply(to: editor)` | `try? editor.apply(configuration: config)` |

Do **not** edit `Tests/CodeEditorPluginTests/EdgeInsetsTests.swift:99` or `:210` — those are `insets.apply(to: rect)` (a different method on `EdgeInsets`).

After all edits:

```bash
grep -rn "\.apply(to: " Tests/ 2>/dev/null | grep -v "EdgeInsets\|insets\.apply\|features\.apply"
```

Expected: no matches.

- [ ] **Step 1.10: Extract `CodeEditorView: TextInputFeatureTarget` conformances out of `Platform/TextInputFeatures.swift`**

Open `Sources/CodeEditorPlugin/Platform/TextInputFeatures.swift`. The two conformance blocks live near lines 151–168:

```swift
#if canImport(AppKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    public var nsTextView: NSTextView? { self }
    #if canImport(UIKit)
    public var uiTextView: UITextView? { nil }
    #endif
}
#endif

#if canImport(UIKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    #if canImport(AppKit)
    public var nsTextView: NSTextView? { nil }
    #endif
    public var uiTextView: UITextView? { self }
}
#endif
```

(Use `Read` on lines 145–175 to confirm exact form before deleting; preserve any surrounding `#if` markers and license headers.)

Delete both blocks from `TextInputFeatures.swift`. Create `Sources/CodeEditorPlugin/Core/CodeEditorView+TextInputFeatureTarget.swift` with the deleted content plus the necessary imports:

```swift
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - TextInputFeatureTarget Conformance

#if canImport(AppKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    public var nsTextView: NSTextView? { self }
    #if canImport(UIKit)
    public var uiTextView: UITextView? { nil }
    #endif
}
#endif

#if canImport(UIKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    #if canImport(AppKit)
    public var nsTextView: NSTextView? { nil }
    #endif
    public var uiTextView: UITextView? { self }
}
#endif
```

- [ ] **Step 1.11: Extract `extension EditorConfiguration` from `Platform/TextInputFeatures.swift`**

In `Platform/TextInputFeatures.swift`, delete the `extension EditorConfiguration { ... }` block at the bottom (lines ~170–end):

```swift
extension EditorConfiguration {
    /// Apply text input features using the platform abstraction
    @MainActor public func applyTextInputFeatures(to textView: any TextInputFeatureTarget) {
        let features = TextInputFeaturesFactory.create()
        features.apply(to: textView, configuration: behavior)
    }
}
```

Create `Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift`:

```swift
import Foundation

// MARK: - EditorConfiguration Integration

extension EditorConfiguration {
    /// Apply text input features using the platform abstraction.
    @MainActor public func applyTextInputFeatures(to textView: any TextInputFeatureTarget) {
        let features = TextInputFeaturesFactory.create()
        features.apply(to: textView, configuration: behavior)
    }
}
```

- [ ] **Step 1.12: Extract `extension CodeEditorView` from `Platform/PlatformCapabilities.swift`**

Read lines ~200–220 of `Sources/CodeEditorPlugin/Platform/PlatformCapabilities.swift` to capture the `extension CodeEditorView { ... }` block at line 207. Delete that block from the file. Create `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformCapabilities.swift` with the captured content plus appropriate imports (`Foundation`, `#if canImport(AppKit/UIKit)` as the original).

(Specific code is read-and-paste; the block is ≤20 lines.)

- [ ] **Step 1.13: Extract `extension EditorConfiguration` from `Platform/PlatformConfigurations.swift`**

Read lines ~245–end of `Sources/CodeEditorPlugin/Platform/PlatformConfigurations.swift` to capture the `extension EditorConfiguration { ... }` block at line 249. Delete that block. Create `Sources/CodeEditorPlugin/Core/EditorConfiguration+PlatformConfigurations.swift` with the captured content plus imports.

- [ ] **Step 1.14: Build**

```bash
swift build
```

Expected: success with no errors. The `CodeEditorPlugin` target compiles all moved files in their new locations.

If errors surface naming/access issues, the most likely cause is that one of the extracted extensions referenced an internal type now in a different file. Add the appropriate `import` or promote the access modifier — but expect this to be rare since all moves stay within the same target.

- [ ] **Step 1.15: Run SwiftLint**

```bash
swiftlint --fix
swiftlint
```

Expected: clean. If `.swiftlint.yml` rule-specific path filters now fail to match any file (e.g. `Sources/CodeEditorPlugin/Core/TextKitSetupHelper\.swift` on line 283), that's expected — `TextKitSetupHelper.swift` still lives in `Core/`. No `.swiftlint.yml` edits needed in this task.

- [ ] **Step 1.16: Run the full test suite**

```bash
swift test --parallel
```

Expected: all tests pass. The 12 test-side call-site updates should make every previously-passing test still pass.

- [ ] **Step 1.17: Commit**

```bash
git add -A
git status
```

Confirm: ~22 file changes (6 moves, 5 creates, 4 modifies-Platform-files, EditorConfiguration.swift modified, 7 Sources call-site files modified, ~6 Tests files modified).

```bash
git commit -m "$(cat <<'EOF'
Pre-flight cleanup for phase 0-2 target extraction

Relocates `CodeEditorError` and `CodeEditorDependencies` into a
`Common/` staging dir, moves four view-coupled files out of `Text/`
into `Core/Text/`, extracts cross-target extensions out of `Platform/`
into the correct domain's source root, and changes the public
`configuration.apply(to: view)` call shape to `view.apply(configuration:)`.

No Package.swift changes; everything stays in CodeEditorPlugin.
Public API surface changes only at the `apply` call site.

Spec: docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Extract `CodeEditorCommon` (Commit 2)

**Files:**
- Move: `Sources/CodeEditorPlugin/Common/`, `Sources/CodeEditorPlugin/Extensions/`, `Sources/CodeEditorPlugin/Utilities/`, `Sources/CodeEditorPlugin/Models/` → under `Sources/CodeEditorCommon/`
- Modify: `Package.swift` (add target + add dep on umbrella)

- [ ] **Step 2.1: Move staging dir, Extensions, Utilities, Models**

```bash
mkdir -p Sources/CodeEditorCommon
git mv Sources/CodeEditorPlugin/Common/Errors Sources/CodeEditorCommon/Errors
git mv Sources/CodeEditorPlugin/Extensions Sources/CodeEditorCommon/Extensions
git mv Sources/CodeEditorPlugin/Utilities Sources/CodeEditorCommon/Utilities
git mv Sources/CodeEditorPlugin/Models Sources/CodeEditorCommon/Models
rmdir Sources/CodeEditorPlugin/Common 2>/dev/null || true
```

After this, `ls Sources/CodeEditorPlugin/` should no longer include `Common/`, `Extensions/`, `Utilities/`, `Models/`.

- [ ] **Step 2.2: Add `CodeEditorCommon` target to `Package.swift`**

Edit `Package.swift`. After the existing `.target(name: "CodeEditorDesignTokens", ...)` entry, insert:

```swift
        .target(
            name: "CodeEditorCommon",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings
        ),
```

In the existing `.target(name: "CodeEditorPlugin", ...)` block, add `"CodeEditorCommon"` to the `dependencies:` array — at the top of the list, preserving alphabetical/logical order:

```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            ...
        ),
```

(Do not add a new `.library(...)` product entry — `CodeEditorCommon` stays internal.)

- [ ] **Step 2.3: Add `@testable import CodeEditorCommon` if needed**

Run targeted test:

```bash
swift build
```

If the build fails with "cannot find type 'X' in scope" for types like `CodeEditorError`, `CodeEditorDependencies`, or anything from `Extensions/Utilities/Models`, the umbrella's source files probably need `import CodeEditorCommon` added at the top. Add the import to the failing file(s).

Most `internal` usage should still work via the umbrella linking `CodeEditorCommon`, but `internal` types from `CodeEditorCommon` are NOT visible to files in `CodeEditorPlugin`. If `CodeEditorError`'s init was previously `internal`, it needs to be `public` (or `package`) for cross-target access. Apply minimal access-level promotions as needed.

Expected pattern: `CodeEditorError` is already `public` (it's referenced from many places). Same for `CodeEditorDependencies`. If not, promote them.

- [ ] **Step 2.4: Run targeted tests**

```bash
swift test --filter CodeEditorPluginTests
```

Expected: all tests pass. If a test file references internal types from `CodeEditorCommon`, add `@testable import CodeEditorCommon` to that file.

- [ ] **Step 2.5: Run SwiftLint**

```bash
swiftlint --fix
swiftlint
```

Expected: clean. SwiftLint scans `Sources/` (line 9 of `.swiftlint.yml`), so all new `Sources/CodeEditorCommon/` files are covered automatically.

- [ ] **Step 2.6: Commit**

```bash
git add -A
git status
```

Confirm: ~42 file moves + `Package.swift` modified.

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorCommon target (phase 0)

Moves Extensions/, Utilities/, Models/, plus relocated CodeEditorError
and CodeEditorDependencies into a new internal-only SPM target. The
umbrella CodeEditorPlugin target gains a dependency on CodeEditorCommon;
consumers still use a single `import CodeEditorPlugin` statement.

Spec: docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Extract `CodeEditorPlatform` (Commit 3)

**Files:**
- Move: `Sources/CodeEditorPlugin/Platform/` → `Sources/CodeEditorPlatform/`
- Modify: `Package.swift` (add target + add dep on umbrella)

- [ ] **Step 3.1: Move the Platform directory**

```bash
git mv Sources/CodeEditorPlugin/Platform Sources/CodeEditorPlatform
```

After this, `ls Sources/CodeEditorPlugin/` should no longer include `Platform/`. The cross-target extensions removed in Task 1 mean `Sources/CodeEditorPlatform/` is a clean leaf — no `import CodeEditorPlugin` needed.

- [ ] **Step 3.2: Add `CodeEditorPlatform` target to `Package.swift`**

After the `CodeEditorCommon` target entry (added in Task 2), insert:

```swift
        .target(
            name: "CodeEditorPlatform",
            swiftSettings: swiftSettings
        ),
```

In the `CodeEditorPlugin` target's `dependencies:` array, add `"CodeEditorPlatform"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                .product(name: "Dependencies", package: "swift-dependencies"),
                ...
            ],
```

- [ ] **Step 3.3: Build**

```bash
swift build
```

Expected: success. The umbrella's files that previously used `Platform/` types (e.g. `TextInputFeatureTarget`, `PlatformCapabilities`) reach them transitively via the umbrella's link, but Swift requires explicit imports — add `import CodeEditorPlatform` to the umbrella files that reference Platform types if the compiler reports unresolved symbols.

Likely files needing `import CodeEditorPlatform` (verify via build errors, only add if needed):
- `Sources/CodeEditorPlugin/Core/CodeEditorView+TextInputFeatureTarget.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+PlatformCapabilities.swift`
- `Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift`
- `Sources/CodeEditorPlugin/Core/EditorConfiguration+PlatformConfigurations.swift`
- Any other umbrella file that uses `Platform/`-originated public types

For each unresolved-symbol error, add `import CodeEditorPlatform` to the top of the file.

- [ ] **Step 3.4: Run targeted tests**

```bash
swift test --filter CodeEditorPluginTests
```

Expected: all tests pass.

- [ ] **Step 3.5: Run SwiftLint**

```bash
swiftlint --fix
swiftlint
```

Expected: clean.

- [ ] **Step 3.6: Commit**

```bash
git add -A
git status
```

Confirm: 32 file moves + `Package.swift` modified + any umbrella files that gained `import CodeEditorPlatform`.

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorPlatform target (phase 0)

Moves Platform/ to a new internal-only SPM target. The cross-target
extension surgery in commit 1 left Platform/ as a clean leaf with no
internal dependencies. Umbrella files that referenced Platform types
gain explicit `import CodeEditorPlatform` statements.

Spec: docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Extract `CodeEditorTextModel` (Commit 4)

**Files:**
- Move: `Sources/CodeEditorPlugin/Text/` (47 files) and `Sources/CodeEditorPlugin/Documents/` (2 files) → under `Sources/CodeEditorTextModel/`
- Modify: `Package.swift` (add target + add dep on umbrella)

This is the largest extraction. Run a wider grep first to confirm no new cross-target leaks beyond what commit 1 handled.

- [ ] **Step 4.1: Widen-grep verification**

```bash
grep -rh "^import \|: [A-Z][A-Za-z0-9]*\|<[A-Z][A-Za-z0-9]*" Sources/CodeEditorPlugin/Text/ Sources/CodeEditorPlugin/Documents/ \
  | grep -oE "\b[A-Z][A-Za-z0-9]+\b" \
  | sort -u \
  > /tmp/textmodel-symbols.txt
wc -l /tmp/textmodel-symbols.txt
head -50 /tmp/textmodel-symbols.txt
```

Scan the symbol list. Symbols defined in Foundation / AppKit / UIKit / SwiftUI / CodeEditorCommon are fine. Symbols defined in `Sources/CodeEditorPlugin/Core/`, `Layout/`, `Languages/`, `SyntaxHighlighting/`, `Completion/`, `Features/`, `LSP/`, `SwiftUI/`, `Performance/`, `Annotations/`, `Search/`, `Workspace/` are **reverse-dep risks**.

For each suspicious symbol, run:

```bash
grep -rln "^\(public \|internal \)\?\(struct\|class\|enum\|protocol\|actor\|typealias\) <Symbol>" Sources/CodeEditorPlugin/
```

If any symbol is defined in a directory that should be a later phase (e.g. `Languages/`, `SyntaxHighlighting/`), apply one of the **R1 mitigation paths** from the spec:
- (a) move the offending Text/ file into `Core/Text/` via a new fix-up commit between commit 3 and commit 4
- (b) if more than 2–3 surprise files surface, stop and re-brainstorm

Document any surprises found here in the commit message.

- [ ] **Step 4.2: Move `Text/` and `Documents/`**

```bash
mkdir -p Sources/CodeEditorTextModel
git mv Sources/CodeEditorPlugin/Text Sources/CodeEditorTextModel/Text
git mv Sources/CodeEditorPlugin/Documents Sources/CodeEditorTextModel/Documents
```

- [ ] **Step 4.3: Add `CodeEditorTextModel` target to `Package.swift`**

After the `CodeEditorPlatform` entry:

```swift
        .target(
            name: "CodeEditorTextModel",
            dependencies: ["CodeEditorCommon"],
            swiftSettings: swiftSettings
        ),
```

In the `CodeEditorPlugin` target's `dependencies:` array, add `"CodeEditorTextModel"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "Dependencies", package: "swift-dependencies"),
                ...
            ],
```

- [ ] **Step 4.4: Build**

```bash
swift build
```

Expected: success. The four files moved to `Core/Text/` in commit 1 (`TextKitLineNumberHelper.swift`, etc.) now live in the umbrella and reference symbols in `CodeEditorTextModel`. Add `import CodeEditorTextModel` to these files if the compiler reports unresolved symbols.

Other umbrella files that use `Text/` or `Documents/` types may need the same import. Apply minimally.

Watch for **internal-access errors**: if `CodeEditorTextModel` files reference internal types from `CodeEditorCommon` (e.g. internal extensions on `String`), those types must be promoted to `public` or `package`. Apply the minimal promotion.

- [ ] **Step 4.5: Run targeted tests**

```bash
swift test --filter CodeEditorPluginTests
```

Expected: all tests pass. Add `@testable import CodeEditorTextModel` to any failing test file that uses internal TextModel types.

- [ ] **Step 4.6: Run SwiftLint**

```bash
swiftlint --fix
swiftlint
```

Expected: clean.

- [ ] **Step 4.7: Commit**

```bash
git add -A
git status
```

Confirm: 49 file moves + `Package.swift` modified + import updates.

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorTextModel target (phase 1)

Moves Text/ (47 files) and Documents/ (2 files) to a new
internal-only SPM target depending only on CodeEditorCommon.
The four view-coupled files relocated to Core/Text/ in commit 1
remain in the umbrella and reference TextModel via explicit imports.

Spec: docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Extract `CodeEditorConfiguration` (Commit 5)

**Files:**
- Move: `Sources/CodeEditorPlugin/Configuration/` (7 files) → `Sources/CodeEditorConfiguration/`
- Modify: `Package.swift` (add target + add dep on umbrella)

- [ ] **Step 5.1: Widen-grep verification for `Configuration/`**

```bash
grep -rh "^import \|: [A-Z][A-Za-z0-9]*\|<[A-Z][A-Za-z0-9]*" Sources/CodeEditorPlugin/Configuration/ \
  | grep -oE "\b[A-Z][A-Za-z0-9]+\b" \
  | sort -u \
  > /tmp/configuration-symbols.txt
head -50 /tmp/configuration-symbols.txt
```

Symbols defined in CodeEditorCommon, CodeEditorTextModel, Foundation / AppKit / UIKit / SwiftUI are fine. Symbols defined in `Core/`, `Layout/`, `SyntaxHighlighting/`, etc. are **R2 risks**.

The known-good list of cross-target references after commit 1: `CodeEditorView` is no longer referenced in `Configuration/` (the only `apply(to:)` method was moved out). If new `CodeEditorView` references surface, apply the **R2 mitigation**:
- Add a fix-up commit between commit 4 and commit 5 extending `Core/CodeEditorView+Configuration.swift` to absorb the additional method(s).
- Do not amend commit 1.

- [ ] **Step 5.2: Move `Configuration/`**

```bash
git mv Sources/CodeEditorPlugin/Configuration Sources/CodeEditorConfiguration
```

- [ ] **Step 5.3: Add `CodeEditorConfiguration` target to `Package.swift`**

After the `CodeEditorTextModel` entry:

```swift
        .target(
            name: "CodeEditorConfiguration",
            dependencies: ["CodeEditorCommon", "CodeEditorTextModel"],
            swiftSettings: swiftSettings
        ),
```

In the `CodeEditorPlugin` target's `dependencies:` array, add `"CodeEditorConfiguration"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                ...
            ],
```

- [ ] **Step 5.4: Build**

```bash
swift build
```

Expected: success. Files in the umbrella that reference `EditorConfiguration`, `EditorConfiguration.Behavior`, `EditorConfiguration.Display`, etc. need `import CodeEditorConfiguration`. Likely files:
- `Sources/CodeEditorPlugin/Core/CodeEditorView+Configuration.swift`
- `Sources/CodeEditorPlugin/Core/EditorConfiguration+ApplyTextInputFeatures.swift`
- `Sources/CodeEditorPlugin/Core/EditorConfiguration+PlatformConfigurations.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (and its many `+*Extensions.swift` siblings if they use the configuration type)
- `Sources/CodeEditorPlugin/Layout/`, `SwiftUI/`, `Performance/`, etc. files that use `EditorConfiguration`

For each unresolved symbol, add `import CodeEditorConfiguration` to the file's top.

**Note on access-level**: the `apply(configuration:)` method created in commit 1 calls `configuration.validateAndThrow()` and `configuration.applyTextInputFeatures(to:)`. Both are already `public` (verified during plan writing) — no promotion needed.

- [ ] **Step 5.5: Run targeted tests**

```bash
swift test --filter CodeEditorPluginTests
```

Expected: all tests pass. Add `@testable import CodeEditorConfiguration` to failing test files only if they use internal config types.

- [ ] **Step 5.6: Run SwiftLint**

```bash
swiftlint --fix
swiftlint
```

Expected: clean.

- [ ] **Step 5.7: Commit**

```bash
git add -A
git status
```

Confirm: 7 file moves + `Package.swift` modified + import updates.

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorConfiguration target (phase 1)

Moves Configuration/ (7 files) to a new internal-only SPM target
depending on CodeEditorCommon and CodeEditorTextModel. Umbrella
files referencing EditorConfiguration gain explicit imports.

Spec: docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Extract `CodeEditorTheming` (Commit 6)

**Files:**
- Move: `Sources/CodeEditorPlugin/Theming/` and `Sources/CodeEditorPlugin/Resources/Themes/` → under `Sources/CodeEditorTheming/`
- Modify: `Package.swift` (add target, add dep on umbrella, remove `resources:` entry from `CodeEditorPlugin`)

- [ ] **Step 6.1: Move `Theming/` and `Resources/Themes/`**

```bash
mkdir -p Sources/CodeEditorTheming/Resources
git mv Sources/CodeEditorPlugin/Theming/* Sources/CodeEditorTheming/
rmdir Sources/CodeEditorPlugin/Theming
git mv Sources/CodeEditorPlugin/Resources/Themes Sources/CodeEditorTheming/Resources/Themes
rmdir Sources/CodeEditorPlugin/Resources 2>/dev/null || true
```

After this, `ls Sources/CodeEditorPlugin/` should no longer include `Theming/` or `Resources/`. Verify:

```bash
ls Sources/CodeEditorPlugin/
ls Sources/CodeEditorTheming/
ls Sources/CodeEditorTheming/Resources/Themes/
```

- [ ] **Step 6.2: Add `CodeEditorTheming` target and remove the umbrella's `resources:` entry**

In `Package.swift`, after the `CodeEditorConfiguration` entry:

```swift
        .target(
            name: "CodeEditorTheming",
            dependencies: ["CodeEditorDesignTokens", "CodeEditorPlatform"],
            resources: [
                .process("Resources/Themes")
            ],
            swiftSettings: swiftSettings
        ),
```

In the `CodeEditorPlugin` target block, **remove** the `resources: [.process("Resources/Themes")]` entry entirely (it was around lines 100–103 of the original `Package.swift`).

In the same `CodeEditorPlugin` target's `dependencies:` array, add `"CodeEditorTheming"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                ...
            ],
```

- [ ] **Step 6.3: Build**

```bash
swift build
```

Expected: success. Files in the umbrella that reference `Theme`, `ThemeFamily`, `ThemeStyle`, `SyntaxStyle`, color tokens, etc. need `import CodeEditorTheming`. Likely files:
- `Sources/CodeEditorPlugin/SyntaxHighlighting/*` (references `SyntaxStyle`)
- `Sources/CodeEditorPlugin/Layout/*` (gutter, minimap, theme application)
- `Sources/CodeEditorPlugin/Core/CodeEditorView*` (theme application)
- `Sources/CodeEditorPlugin/SwiftUI/*` (theme modifiers)

For each unresolved symbol, add `import CodeEditorTheming` to the file's top.

- [ ] **Step 6.4: Verify theme JSON loads (smoke test)**

```bash
swift run CodeEditorSample
```

Open the sample app and switch through each bundled theme via the theme picker. Verify visible rendering changes — gutter color, line highlight, syntax colors all respond. Quit the app.

If a theme silently fails to load, the issue is likely `Bundle.module` resolving to the wrong target. Find the theme loader (probably in `Sources/CodeEditorTheming/Loader/`) and confirm it uses `Bundle.module` — this resolves to `CodeEditorTheming.bundle` automatically since the loader file lives in that target now. If any other code outside `CodeEditorTheming` loads themes via its own `Bundle.module`, that breaks; fix by routing through a `CodeEditorTheming`-public helper.

- [ ] **Step 6.5: Run targeted tests**

```bash
swift test --filter CodeEditorPluginTests
```

Expected: all tests pass. Pay particular attention to `Tests/CodeEditorPluginTests/Theming/` — these snapshot tests are the strongest signal that theme loading and color computation are intact.

If snapshot tests fail, **do not** re-record. The failure indicates a real regression (likely theme JSON not loading or `Bundle.module` resolving wrong). Diagnose before continuing.

- [ ] **Step 6.6: Run SwiftLint**

```bash
swiftlint --fix
swiftlint
```

Expected: clean.

- [ ] **Step 6.7: Commit**

```bash
git add -A
git status
```

Confirm: 31 file moves + JSON moves + `Package.swift` modified + import updates.

```bash
git commit -m "$(cat <<'EOF'
Extract CodeEditorTheming target (phase 2)

Moves Theming/ (31 files including SyntaxStyle) and Resources/Themes/
JSON bundle to a new internal-only SPM target depending on
CodeEditorDesignTokens and CodeEditorPlatform. The umbrella's
resources: entry is removed; CodeEditorTheming owns the bundle.

Sample app smoke-tested via swift run; each bundled theme loads
and renders correctly.

Spec: docs/superpowers/specs/2026-05-17-phase-0-2-target-extraction-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Final verification

**Files:** none modified — verification only.

- [ ] **Step 7.1: Run the full parallel test suite**

```bash
swift test --parallel
```

Expected: all tests pass across `CodeEditorPluginTests`, `CodeEditorDesignTokensTests`, `CodeEditorUITests`, `CodeEditorSampleTests`.

- [ ] **Step 7.2: Confirm SwiftLint clean**

```bash
swiftlint --fix
swiftlint
```

Expected: no violations. If `--fix` made changes, stage them with `git add -p` and commit as a follow-up "Final SwiftLint polish" commit.

- [ ] **Step 7.3: Smoke-test the sample app**

```bash
swift run CodeEditorSample
```

Open a file, type, switch themes, toggle line numbers, search/replace, fold a region. Each should behave identically to pre-restructure.

- [ ] **Step 7.4: Confirm structure**

```bash
ls Sources/
```

Expected output (alphabetical):
```
CodeEditorCommon
CodeEditorConfiguration
CodeEditorDesignTokens
CodeEditorPlatform
CodeEditorPlugin
CodeEditorSample
CodeEditorTextModel
CodeEditorTheming
CodeEditorTreeSitterLanguages
CodeEditorUI
```

```bash
ls Sources/CodeEditorPlugin/
```

Expected: 14 directories (down from 21). Specifically these are gone — `Common/`, `Documents/`, `Extensions/`, `Models/`, `Platform/`, `Resources/`, `Text/`, `Theming/`, `Utilities/`, and `Configuration/`. (Note: `Common/` was a staging dir from commit 1 and migrated entirely into `CodeEditorCommon` in commit 2.)

```bash
git log --oneline -7
```

Expected: 6 phase 0–2 commits (plus the spec commit) at the top.

- [ ] **Step 7.5: Confirm the `Package.swift` shape**

```bash
swift package describe | grep -E "Module:|Target:" | head -30
```

Expected: 10 modules / targets visible (5 new internal targets + 5 existing).

- [ ] **Step 7.6: Update memory if anything surprising surfaced**

If the implementation revealed something durable for future sessions (e.g. a tangled file pattern that recurs across the codebase), save a memory note via the auto-memory protocol. Otherwise skip — this restructure is the kind of work that lives in code/git, not memory.

---

## Self-review notes

The plan was self-reviewed before saving:

- **Spec coverage:** All seven spec sections have corresponding tasks. §1 (goal) → Task 7.4; §2 (architecture) → Tasks 2–6; §3 (pre-flight) → Task 1; §4 (commit sequence) → Tasks 1–6; §5 (testing) → per-task verification steps; §6 (risks) — R1 mitigation is in Task 4.1, R2 in Task 5.1, R3 in Task 6.4, R4 noted (no edit needed), R5 handled per-task with `@testable import`, R6 in Task 6.2 (explicit removal of umbrella `resources:`), R7 carried forward as a forward-reference. §7 references retained.
- **Placeholder scan:** No TBDs, TODOs, or "implement later" markers.
- **Type consistency:** New extension file names follow the project's domain-scoped `+<Topic>` convention; `apply(configuration:)` method name is consistent across plan, spec, and call-site updates.
- **Spec gap (Platform/ cross-target leaks):** Discovered and absorbed into Task 1 steps 1.5, 1.10, 1.11, 1.12, 1.13. Noted at the top of the plan.
- **Discovered detail:** `EditorConfiguration.validateAndThrow()` is already `public`; `EditorConfiguration.applyTextInputFeatures(to:)` is already `public`. No access-modifier promotions required for the `view.apply(configuration:)` extension to work across the future Configuration boundary.
- **Discovered detail:** `CodeEditorError` is `public` (with in-file `ValidationError`); no promotion needed when it moves to `CodeEditorCommon`. `CodeEditorDependencies` is `internal` and cross-target-coupled — it stays in `Core/` for now (see spec-gap note #2).
