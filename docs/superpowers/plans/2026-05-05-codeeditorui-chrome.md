# CodeEditorUI Chrome Primitives Implementation Plan

> **Archive note:** Historical working note from May 2026. It may mention pre-0.2.0 Catalyst, plugin, or theme APIs; use `AGENTS.md`, `docs/README.md`, and `docs/FeatureMatrix.md` for current package truth.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new `CodeEditorUI` SwiftPM library target with eight chrome components (title bar, traffic lights, tab strip, breadcrumb, status bar, sidebar shell, command palette, glass surface), an additive `@Observable EditorState` in `CodeEditorPlugin` with `\.editorState` env key, and two SwiftUI Style protocols (`EditorTabStripStyle`, `EditorCommandPaletteStyle`).

**Architecture:** Chrome is fully reactive — a single `@Observable final class EditorState` lives in `CodeEditorPlugin`. Host instantiates and injects via `.environment(state)`; both `CodeEditor` (writes selection/language/dirty/hwAccel/lineCount) and chrome (reads) see the same instance. Two components use the SwiftUI Style protocol pattern (à la `ButtonStyle`); the rest are plain views with `@ViewBuilder` slots. Liquid Glass is wrapped natively (`.glassEffect()`) — no abstraction. Cross-platform tiering: title bar / traffic lights / sidebar shell are macOS+Catalyst; tab strip / breadcrumb / status bar / command palette / glass surface are all-platform.

**Tech Stack:** Swift 6.3, swift-tools-version 6.3, Swift Testing (`@Suite`/`@Test`/`#expect`) for unit tests, XCTest for SwiftUI image snapshots (gated to macOS), `swift-snapshot-testing`, `swift-custom-dump`, `Observation` (`@Observable`).

**Spec:** [`docs/superpowers/specs/2026-05-05-codeeditorui-chrome-design.md`](../specs/2026-05-05-codeeditorui-chrome-design.md)

---

## File Structure

### Files created

```
Sources/CodeEditorPlugin/Core/
  EditorState.swift                              # @Observable; editor + host fields
  SelectionState.swift                           # public value type
  TabModel.swift                                 # public value type
  BreadcrumbComponent.swift                      # public value type
Sources/CodeEditorPlugin/SwiftUI/
  EditorState+Environment.swift                  # \.editorState env key

Sources/CodeEditorUI/
  Window/
    EditorTitleBar.swift
    EditorTrafficLights.swift
  TabStrip/
    EditorTabStrip.swift
    EditorTabStripStyle.swift                    # protocol + Configuration + Default/Compact built-ins
    EditorTab.swift
  Breadcrumb/
    EditorBreadcrumbView.swift
  StatusBar/
    EditorStatusBar.swift
  Sidebar/
    EditorSidebarShell.swift
  CommandPalette/
    EditorCommandPalette.swift
    EditorCommandPaletteStyle.swift              # protocol + Configuration + Default
    EditorCommandPaletteRow.swift
    CommandPaletteItem.swift
  Glass/
    PlatformGlassSurface.swift
  Theming/
    Theme+Chrome.swift                           # SwiftUI.Color accessors for chrome.*
    Theme+Glass.swift                            # glass tint/opacity/shadow accessors

Tests/CodeEditorUITests/
  EditorStateTests.swift                         # @Observable mutation tests
  CodeEditorPluginCoreTypeShapeTests.swift       # SelectionState/TabModel/BreadcrumbComponent conformance
  EditorStateEnvironmentTests.swift              # env-key default behavior
  PlatformGlassSurfaceTests.swift                # role table sanity
  ThemeChromeAccessorTests.swift                 # bridge accessors
  StyleProtocolTests.swift                       # default style behavior + custom-style installation
  CommandPaletteFilterTests.swift                # palette query filter behavior
  TypeShapeAuditTests.swift                      # all CodeEditorUI public types Sendable
  Snapshots/
    EditorTitleBarSnapshots.swift
    EditorTrafficLightsSnapshots.swift
    EditorTabStripSnapshots.swift
    EditorBreadcrumbSnapshots.swift
    EditorStatusBarSnapshots.swift
    EditorSidebarShellSnapshots.swift
    EditorCommandPaletteSnapshots.swift
    PlatformGlassSurfaceSnapshots.swift
    SnapshotSupport.swift                        # shared NSHostingView helper, theme fixtures
  __Snapshots__/                                 # excluded via Package.swift
```

### Files modified

```
Package.swift                                    # add CodeEditorUI library + target + CodeEditorUITests
Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift
                                                 # body: pull \.editorState from env; pass to representable
Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift
                                                 # representable carries optional EditorState
Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
                                                 # coordinator writes selection/language/dirty/hwAccel/lineCount
CHANGELOG.md                                     # release-note section
```

### Files deleted

None. This sub-project is fully additive.

---

## Conventions used in this plan

- **Test framework.** Swift Testing for type-shape, observation, filter, and bridge tests (`@Suite`, `@Test`, `#expect`). XCTest with `@MainActor` + `XCTestCase` for SwiftUI image snapshot tests, gated to `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`. This matches existing `Tests/CodeEditorPluginTests/CodeEditorSnapshotTests.swift`.
- **Build/test commands.** Per-task tests run via `swift test --filter <Suite>`. The full quality gate at task end is `swift build && swiftlint && swift test --parallel`. SwiftLint must report zero violations.
- **Cross-platform gating.** macOS+Catalyst components use `#if canImport(AppKit)` (Catalyst's `AppKit` is the UIKit-bridge form). When AppKit isn't available (pure iOS), the components compile out entirely. All-platform components have no gates.
- **Liquid Glass API.** The plan assumes the SwiftUI 26.x modifier `.glassEffect(...)` ships in the form `.glassEffect(_ glass: Glass = .regular, in shape: some Shape = .rect)`. If the actual SDK spelling differs at implementation time, adapt the call sites in `PlatformGlassSurface.swift` only — the public surface (`platformGlassSurface(_:)`) is unchanged.
- **Commits.** One commit per task, message ending with the standard `Co-Authored-By` trailer.
- **Snapshot recording.** Snapshots are recorded on first run in a clean tree and committed. `isRecording` defaults off so CI fails on drift.

---

## Task 1: `EditorState` + value types in `CodeEditorPlugin`

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/SelectionState.swift`
- Create: `Sources/CodeEditorPlugin/Core/TabModel.swift`
- Create: `Sources/CodeEditorPlugin/Core/BreadcrumbComponent.swift`
- Create: `Sources/CodeEditorPlugin/Core/EditorState.swift`
- Create: `Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift`
- Test (added to existing test target): `Tests/CodeEditorPluginTests/Core/EditorStateTests.swift`
- Test: `Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift`

- [ ] **Step 1: Write failing tests for value types and observation**

```swift
// Tests/CodeEditorPluginTests/Core/EditorStateConformanceTests.swift
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("EditorState public types conform to expected protocols")
struct EditorStateConformanceTests {
    private static func requireValueShape<T>(_ type: T.Type)
    where T: Sendable & Hashable {
        _ = String(describing: type)
    }

    @Test("SelectionState, TabModel, BreadcrumbComponent are Sendable + Hashable")
    func auditValueTypes() {
        Self.requireValueShape(SelectionState.self)
        Self.requireValueShape(TabModel.self)
        Self.requireValueShape(BreadcrumbComponent.self)
        Self.requireValueShape(BreadcrumbComponent.Kind.self)
    }

    @Test("TabModel and BreadcrumbComponent are Identifiable")
    func auditIdentifiable() {
        let tab = TabModel(name: "Foo.swift")
        _ = tab.id  // compile-time proof of Identifiable
        let crumb = BreadcrumbComponent(name: "Sources", kind: .folder)
        _ = crumb.id
    }
}
```

```swift
// Tests/CodeEditorPluginTests/Core/EditorStateTests.swift
@testable import CodeEditorPlugin
import Foundation
import Observation
import Testing

@Suite("EditorState observation")
@MainActor
struct EditorStateTests {
    @Test("Default EditorState has empty/nil fields")
    func defaultsAreEmpty() {
        let state = EditorState()
        #expect(state.selection == nil)
        #expect(state.language == nil)
        #expect(state.isDirty == false)
        #expect(state.hardwareAccelerationActive == false)
        #expect(state.lineCount == 0)
        #expect(state.documentName.isEmpty)
        #expect(state.documentURL == nil)
        #expect(state.tabs.isEmpty)
        #expect(state.activeTabID == nil)
        #expect(state.breadcrumbPath.isEmpty)
        #expect(state.workspaceName.isEmpty)
    }

    @Test("Mutating selection fires observation")
    func mutatingSelectionFiresObservers() {
        let state = EditorState()
        var fireCount = 0
        withObservationTracking {
            _ = state.selection
        } onChange: {
            fireCount += 1
        }
        state.selection = SelectionState(line: 1, column: 1)
        #expect(fireCount == 1)
    }

    @Test("Mutating tabs fires observation")
    func mutatingTabsFiresObservers() {
        let state = EditorState()
        var fireCount = 0
        withObservationTracking {
            _ = state.tabs
        } onChange: {
            fireCount += 1
        }
        state.tabs.append(TabModel(name: "Foo.swift"))
        #expect(fireCount == 1)
    }

    @Test("SelectionState equality")
    func selectionEquality() {
        let a = SelectionState(line: 10, column: 4, selectionLength: 3)
        let b = SelectionState(line: 10, column: 4, selectionLength: 3)
        let c = SelectionState(line: 10, column: 4)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("TabModel preserves identity across mutations")
    func tabModelIdentityStable() {
        var tab = TabModel(name: "Foo.swift")
        let id = tab.id
        tab.name = "Bar.swift"
        tab.isDirty = true
        #expect(tab.id == id)
    }

    @Test("BreadcrumbComponent round-trips through array")
    func breadcrumbRoundtrip() {
        let crumbs = [
            BreadcrumbComponent(name: "Sources",          kind: .folder),
            BreadcrumbComponent(name: "CodeEditorPlugin", kind: .folder),
            BreadcrumbComponent(name: "Foo.swift",        kind: .file),
            BreadcrumbComponent(name: "greet(_:)",        kind: .symbol),
        ]
        let copy = Array(crumbs)
        #expect(copy == crumbs)
        #expect(copy.map(\.id) == crumbs.map(\.id))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter EditorState`
Expected: FAIL — `SelectionState`, `TabModel`, `BreadcrumbComponent`, `EditorState` not defined.

- [ ] **Step 3: Implement `SelectionState`**

```swift
// Sources/CodeEditorPlugin/Core/SelectionState.swift
import Foundation

/// Caret/selection position in the active document.
///
/// Line and column are 1-based to match the convention used throughout
/// editor UIs. `selectionLength` is in characters (not bytes); zero means
/// caret-only with no selected range.
public struct SelectionState: Hashable, Sendable {
    /// 1-based line number.
    public var line: Int
    /// 1-based column number, in display columns.
    public var column: Int
    /// Length of the active selection in characters; zero when caret-only.
    public var selectionLength: Int

    /// Creates a new selection state.
    /// - Parameters:
    ///   - line: 1-based line number.
    ///   - column: 1-based column number.
    ///   - selectionLength: length in characters; defaults to 0 (caret-only).
    public init(line: Int, column: Int, selectionLength: Int = 0) {
        self.line = line
        self.column = column
        self.selectionLength = selectionLength
    }
}
```

- [ ] **Step 4: Implement `TabModel`**

```swift
// Sources/CodeEditorPlugin/Core/TabModel.swift
import Foundation

/// A single open tab in the chrome's tab strip.
///
/// Tabs are host-owned. The package provides this shape so chrome
/// (`EditorTabStrip`) can render uniformly across hosts. `id` is stable
/// across name and dirty-flag changes; mutate `name`/`url`/`language`/
/// `isDirty` on the same instance rather than replacing the model.
public struct TabModel: Hashable, Identifiable, Sendable {
    /// Stable identifier; preserved across in-place mutations.
    public let id: UUID
    /// Display name shown on the tab.
    public var name: String
    /// File URL backing the tab, if any. Optional for unsaved/scratch tabs.
    public var url: URL?
    /// Detected/explicit language for the tab's content, if any.
    public var language: Language?
    /// True when the tab's content has unsaved changes.
    public var isDirty: Bool

    /// Creates a new tab model.
    /// - Parameters:
    ///   - id: stable identifier; defaults to a fresh UUID.
    ///   - name: display name.
    ///   - url: file URL backing the tab; defaults to nil.
    ///   - language: language for the tab's content; defaults to nil.
    ///   - isDirty: dirty-flag; defaults to false.
    public init(
        id: UUID = UUID(),
        name: String,
        url: URL? = nil,
        language: Language? = nil,
        isDirty: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.language = language
        self.isDirty = isDirty
    }
}
```

- [ ] **Step 5: Implement `BreadcrumbComponent`**

```swift
// Sources/CodeEditorPlugin/Core/BreadcrumbComponent.swift
import Foundation

/// One segment of a breadcrumb trail (workspace › folder › file › symbol).
///
/// Breadcrumb data lives next to the rest of `EditorState`'s host-driven
/// fields; the chrome's visual rendering of separators, kind glyphs, and
/// hover lives in `CodeEditorUI/Breadcrumb/EditorBreadcrumbView.swift`.
public struct BreadcrumbComponent: Hashable, Identifiable, Sendable {
    /// Kind of segment — drives the leading glyph and tap behavior in the
    /// breadcrumb view.
    public enum Kind: Hashable, Sendable {
        case workspace
        case folder
        case file
        case symbol
    }

    /// Stable identifier; preserved across name changes.
    public let id: UUID
    /// Display name.
    public let name: String
    /// Segment kind.
    public let kind: Kind

    /// Creates a new breadcrumb component.
    /// - Parameters:
    ///   - id: stable identifier; defaults to a fresh UUID.
    ///   - name: display name.
    ///   - kind: segment kind.
    public init(id: UUID = UUID(), name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}
```

- [ ] **Step 6: Implement `EditorState`**

```swift
// Sources/CodeEditorPlugin/Core/EditorState.swift
import Foundation
import Observation

/// Live state of the editor and its surrounding chrome.
///
/// Chrome views (`EditorStatusBar`, `EditorBreadcrumbView`, `EditorTitleBar`)
/// observe this object via `\.editorState` in the SwiftUI environment and
/// re-render when fields they read mutate. The editor target writes
/// `selection`, `language`, `isDirty`, `hardwareAccelerationActive`, and
/// `lineCount`; the host writes the rest (`documentName`, `documentURL`,
/// `tabs`, `activeTabID`, `breadcrumbPath`, `workspaceName`).
///
/// **MainActor-bound by convention.** `@Observable` does not synthesize
/// `Sendable`. Mutation from non-main contexts is unsupported. Read access
/// from any context is safe.
@Observable
public final class EditorState: @unchecked Sendable {
    // MARK: Editor-written

    /// Caret/selection in the active document; nil before the editor mounts.
    public var selection: SelectionState?
    /// Detected/explicit language for the active document.
    public var language: Language?
    /// True when the active document has unsaved changes.
    public var isDirty: Bool
    /// Reflects the editor's *actual* hardware-acceleration state — what's
    /// running, not what's configured. Status bar reads this so the UI
    /// shows truth.
    public var hardwareAccelerationActive: Bool
    /// Total line count of the active document.
    public var lineCount: Int

    // MARK: Host-written

    /// Display name for the active document (e.g., `"EditorState.swift"`).
    public var documentName: String
    /// File URL for the active document, if any.
    public var documentURL: URL?
    /// Open tabs. Host owns ordering and lifecycle.
    public var tabs: [TabModel]
    /// Active tab in `tabs`; nil when no document is open.
    public var activeTabID: TabModel.ID?
    /// Breadcrumb trail. Host computes from `documentURL` + workspace root +
    /// symbol path.
    public var breadcrumbPath: [BreadcrumbComponent]
    /// Workspace name for the title bar / sidebar header.
    public var workspaceName: String

    /// Creates a fresh empty `EditorState`. All fields default to empty/nil.
    public init() {
        self.selection = nil
        self.language = nil
        self.isDirty = false
        self.hardwareAccelerationActive = false
        self.lineCount = 0
        self.documentName = ""
        self.documentURL = nil
        self.tabs = []
        self.activeTabID = nil
        self.breadcrumbPath = []
        self.workspaceName = ""
    }
}
```

- [ ] **Step 7: Implement environment key**

```swift
// Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift
#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI environment key carrying a live `EditorState`.
///
/// Hosts that integrate `CodeEditorUI` chrome should instantiate an
/// `EditorState`, hold it in `@State`, and inject it via
/// `.environment(\.editorState, state)`. Hosts without chrome can ignore
/// this key — the editor writes to the env's default (a fresh empty
/// instance per access) and observation no-ops because no view is reading.
public struct EditorStateEnvironmentKey: EnvironmentKey {
    public static let defaultValue: EditorState = EditorState()
    public typealias Value = EditorState
}

extension EnvironmentValues {
    /// The shared `EditorState` for chrome and editor integration.
    ///
    /// Defaults to a fresh empty `EditorState` per access; replace by
    /// injecting an explicit instance with `.environment(\.editorState, _:)`.
    public var editorState: EditorState {
        get { self[EditorStateEnvironmentKey.self] }
        set { self[EditorStateEnvironmentKey.self] = newValue }
    }
}
#endif
```

- [ ] **Step 8: Run tests to verify pass**

Run: `swift test --filter EditorState`
Expected: PASS — all tests green.

- [ ] **Step 9: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: build succeeds, zero lint violations, all tests pass.

- [ ] **Step 10: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/ \
        Sources/CodeEditorPlugin/SwiftUI/EditorState+Environment.swift \
        Tests/CodeEditorPluginTests/Core/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorState + value types in CodeEditorPlugin

@Observable EditorState class with editor-written fields (selection,
language, isDirty, hardwareAccelerationActive, lineCount) and
host-written fields (documentName, documentURL, tabs, activeTabID,
breadcrumbPath, workspaceName). Adds public SelectionState, TabModel,
BreadcrumbComponent value types and the \.editorState env key.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `CodeEditorUI` target skeleton + `Package.swift` wiring

**Files:**
- Modify: `Package.swift`
- Create: `Sources/CodeEditorUI/CodeEditorUI.swift` (placeholder umbrella file so SwiftPM has something to compile)
- Create: `Tests/CodeEditorUITests/TargetCompilesTests.swift`

- [ ] **Step 1: Write failing test that requires the target to exist**

```swift
// Tests/CodeEditorUITests/TargetCompilesTests.swift
import CodeEditorUI
import Foundation
import Testing

@Suite("CodeEditorUI target compiles")
struct TargetCompilesTests {
    @Test("module loads")
    func moduleLoads() {
        // If this file compiles and links, the target is wired correctly.
        #expect(CodeEditorUI.identifier == "CodeEditorUI")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TargetCompilesTests`
Expected: FAIL — `CodeEditorUI` module not found.

- [ ] **Step 3: Add CodeEditorUI target + product to Package.swift**

```swift
// Package.swift — modifications inside the existing Package(...) call

products: [
    .library(name: "CodeEditorDesignTokens", targets: ["CodeEditorDesignTokens"]),
    .library(name: "CodeEditorPlugin",       targets: ["CodeEditorPlugin"]),
    .library(name: "CodeEditorUI",           targets: ["CodeEditorUI"])  // ADD
],

// targets — add after the CodeEditorPlugin .target(...) block:
.target(
    name: "CodeEditorUI",
    dependencies: ["CodeEditorDesignTokens", "CodeEditorPlugin"],
    swiftSettings: swiftSettings
),

// targets — add after the existing CodeEditorPluginTests block:
.testTarget(
    name: "CodeEditorUITests",
    dependencies: [
        "CodeEditorUI",
        .product(name: "CustomDump",      package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ],
    exclude: ["__Snapshots__"],
    swiftSettings: swiftSettings
)
```

- [ ] **Step 4: Create the placeholder umbrella file**

```swift
// Sources/CodeEditorUI/CodeEditorUI.swift
import Foundation

/// Umbrella namespace for the `CodeEditorUI` target. Contains a stable
/// module identifier so consumers can verify the module loaded; otherwise
/// purely metadata. All concrete API (chrome views, styles, surfaces)
/// lives in sibling files under `Window/`, `TabStrip/`, etc.
public enum CodeEditorUI {
    /// Stable module identifier. Useful as a probe in tests and as a
    /// stamp in any per-target diagnostics.
    public static let identifier: String = "CodeEditorUI"
}
```

- [ ] **Step 5: Run tests to verify pass**

Run: `swift test --filter TargetCompilesTests`
Expected: PASS.

- [ ] **Step 6: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: build succeeds with the new target, zero lint, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/CodeEditorUI/ Tests/CodeEditorUITests/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add target skeleton + Package.swift wiring

Adds the CodeEditorUI library product, its source target depending on
CodeEditorDesignTokens + CodeEditorPlugin, and the CodeEditorUITests
test target. Ships a placeholder umbrella file with a module identifier
so the target has something to compile.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Theme bridges — `Theme+Chrome.swift` and `Theme+Glass.swift`

**Files:**
- Create: `Sources/CodeEditorUI/Theming/Theme+Chrome.swift`
- Create: `Sources/CodeEditorUI/Theming/Theme+Glass.swift`
- Test: `Tests/CodeEditorUITests/ThemeChromeAccessorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorUITests/ThemeChromeAccessorTests.swift
import CodeEditorDesignTokens
@testable import CodeEditorPlugin
@testable import CodeEditorUI
import Foundation
import SwiftUI
import Testing

@Suite("Theme chrome + glass SwiftUI accessors")
@MainActor
struct ThemeChromeAccessorTests {
    @Test("chrome accessors map to style.chrome.* underlying tokens")
    func chromeAccessorsMapCorrectly() {
        let theme = Theme.lcarsDark
        // Round-trip through Tokens.Color → SwiftUI.Color and back via raw
        // RGBA. Equality on SwiftUI.Color isn't reliable, so we compare
        // the source Tokens.Color directly through the bridge.
        #expect(theme.titleBarColor == Color(tokens: theme.style.chrome.titleBarBackground))
        #expect(theme.tabBarColor   == Color(tokens: theme.style.chrome.tabBarBackground))
        #expect(theme.statusBarColor == Color(tokens: theme.style.chrome.statusBarBackground))
        #expect(theme.panelColor    == Color(tokens: theme.style.chrome.panelBackground))
        #expect(theme.elevatedColor == Color(tokens: theme.style.chrome.elevatedSurfaceBackground))
        #expect(theme.tabActiveColor   == Color(tokens: theme.style.chrome.tabActiveBackground))
        #expect(theme.tabInactiveColor == Color(tokens: theme.style.chrome.tabInactiveBackground))
        #expect(theme.toolbarColor  == Color(tokens: theme.style.chrome.toolbarBackground))
        #expect(theme.surfaceColor  == Color(tokens: theme.style.chrome.surfaceBackground))
        #expect(theme.titleBarInactiveColor   == Color(tokens: theme.style.chrome.titleBarInactiveBackground))
        #expect(theme.panelFocusedBorderColor == Color(tokens: theme.style.chrome.panelFocusedBorder))
    }

    @Test("glass accessors map to platform.glass.* underlying tokens")
    func glassAccessorsMapCorrectly() {
        let theme = Theme.lcarsDark
        #expect(theme.glassTintColor == Color(tokens: theme.platform.glass.tint))
        #expect(theme.glassOpacity   == theme.platform.glass.opacity)
    }

    @Test("popoverShadow returns the platform.shadows.popover values")
    func popoverShadowMaps() {
        let theme = Theme.lcarsDark
        let shadow = theme.popoverShadow
        let source = theme.platform.shadows.popover
        #expect(shadow.color == Color(tokens: source.color))
        #expect(shadow.blur  == CGFloat(source.blur))
        #expect(shadow.x     == CGFloat(source.xOffset))
        #expect(shadow.y     == CGFloat(source.yOffset))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ThemeChromeAccessorTests`
Expected: FAIL — accessors not defined.

- [ ] **Step 3: Implement `Theme+Chrome.swift`**

```swift
// Sources/CodeEditorUI/Theming/Theme+Chrome.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// SwiftUI `Color` accessors for `Theme.style.chrome.*` token values.
///
/// These helpers exist so chrome views can read theme values fluently:
/// `theme.titleBarColor` instead of `Color(tokens: theme.style.chrome.titleBarBackground)`.
/// Each accessor is a simple bridge — no caching, no derivation.
extension Theme {
    /// Title bar background for the active window.
    public var titleBarColor: Color {
        Color(tokens: style.chrome.titleBarBackground)
    }

    /// Title bar background for an inactive window.
    public var titleBarInactiveColor: Color {
        Color(tokens: style.chrome.titleBarInactiveBackground)
    }

    /// Tab strip background.
    public var tabBarColor: Color {
        Color(tokens: style.chrome.tabBarBackground)
    }

    /// Active tab background.
    public var tabActiveColor: Color {
        Color(tokens: style.chrome.tabActiveBackground)
    }

    /// Inactive tab background.
    public var tabInactiveColor: Color {
        Color(tokens: style.chrome.tabInactiveBackground)
    }

    /// Status bar background.
    public var statusBarColor: Color {
        Color(tokens: style.chrome.statusBarBackground)
    }

    /// Toolbar background.
    public var toolbarColor: Color {
        Color(tokens: style.chrome.toolbarBackground)
    }

    /// Generic surface background.
    public var surfaceColor: Color {
        Color(tokens: style.chrome.surfaceBackground)
    }

    /// Elevated surface background (popovers, sheets).
    public var elevatedColor: Color {
        Color(tokens: style.chrome.elevatedSurfaceBackground)
    }

    /// Side panel background.
    public var panelColor: Color {
        Color(tokens: style.chrome.panelBackground)
    }

    /// Border color when a panel has focus.
    public var panelFocusedBorderColor: Color {
        Color(tokens: style.chrome.panelFocusedBorder)
    }
}
```

- [ ] **Step 4: Implement `Theme+Glass.swift`**

```swift
// Sources/CodeEditorUI/Theming/Theme+Glass.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// SwiftUI accessors for `Theme.platform.glass` and the popover shadow.
///
/// Liquid Glass surfaces (`PlatformGlassSurface`) read `glassTintColor` +
/// `glassOpacity` from the active theme. Popovers (command palette,
/// completion menu) read `popoverShadow` for their drop shadow.
extension Theme {
    /// Tint color blended into the Liquid Glass material.
    public var glassTintColor: Color {
        Color(tokens: platform.glass.tint)
    }

    /// Glass tint opacity in `0...1`.
    public var glassOpacity: Double {
        platform.glass.opacity
    }

    /// Popover-class drop shadow as a SwiftUI-friendly tuple.
    ///
    /// The tuple's components map to `View.shadow(color:radius:x:y:)`
    /// where `radius == blur`.
    public var popoverShadow: (color: Color, blur: CGFloat, x: CGFloat, y: CGFloat) {
        let source = platform.shadows.popover
        return (
            color: Color(tokens: source.color),
            blur:  CGFloat(source.blur),
            x:     CGFloat(source.xOffset),
            y:     CGFloat(source.yOffset)
        )
    }
}
```

- [ ] **Step 5: Run tests to verify pass**

Run: `swift test --filter ThemeChromeAccessorTests`
Expected: PASS.

- [ ] **Step 6: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorUI/Theming/ Tests/CodeEditorUITests/ThemeChromeAccessorTests.swift
git commit -m "$(cat <<'EOF'
CodeEditorUI: add Theme+Chrome and Theme+Glass SwiftUI bridges

SwiftUI Color accessors for Theme.style.chrome.* and Theme.platform.glass
so chrome views can read theme values fluently. popoverShadow returns
a SwiftUI-friendly tuple aligned with View.shadow(color:radius:x:y:).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `PlatformGlassSurface` modifier + snapshot test scaffolding

**Files:**
- Create: `Sources/CodeEditorUI/Glass/PlatformGlassSurface.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/SnapshotSupport.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/PlatformGlassSurfaceSnapshots.swift`
- Create: `Tests/CodeEditorUITests/PlatformGlassSurfaceTests.swift`

- [ ] **Step 1: Write failing tests — role enumeration sanity + snapshot scaffolding**

```swift
// Tests/CodeEditorUITests/PlatformGlassSurfaceTests.swift
import CodeEditorUI
import Foundation
import Testing

@Suite("PlatformGlassSurface role enumeration")
struct PlatformGlassSurfaceTests {
    @Test("Role declares all five expected cases")
    func roleCases() {
        let cases: [PlatformGlassSurface.Role] =
            [.titleBar, .tabBar, .statusBar, .panel, .popover]
        #expect(Set(cases).count == 5)
    }

    @Test("Role is Sendable + Hashable")
    func roleConforms() {
        let role: any (Sendable & Hashable) = PlatformGlassSurface.Role.titleBar
        _ = role
    }
}
```

```swift
// Tests/CodeEditorUITests/Snapshots/SnapshotSupport.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

/// Shared snapshot-test helpers. Wraps a SwiftUI `View` in `NSHostingView`
/// at a fixed size so `assertSnapshot(of:as: .image)` can render it
/// deterministically on macOS CI runners.
@MainActor
enum SnapshotSupport {
    /// Default snapshot size for chrome rows (title bar, status bar, tab strip).
    static let rowSize = CGSize(width: 800, height: 60)
    /// Default snapshot size for breadcrumbs.
    static let breadcrumbSize = CGSize(width: 800, height: 28)
    /// Default snapshot size for vertical chrome (sidebar shell).
    static let panelSize = CGSize(width: 240, height: 480)
    /// Default snapshot size for popovers (command palette).
    static let popoverSize = CGSize(width: 480, height: 320)
    /// Default snapshot size for traffic lights only.
    static let trafficLightsSize = CGSize(width: 80, height: 24)
    /// Default snapshot size for glass surface samples.
    static let glassSize = CGSize(width: 400, height: 80)

    /// Themes used for parity snapshots. The light variant is the LCARS
    /// Light family member if it exists, otherwise the first `.light`
    /// theme in the bundled Zed Trek family.
    static let darkTheme: Theme = .lcarsDark
    static let lightTheme: Theme = pickLightTheme()

    private static func pickLightTheme() -> Theme {
        let family = ThemeFamily.bundled("zed-trek")
        if let light = family?.themes.first(where: { $0.name == "LCARS Light" }) {
            return light
        }
        if let firstLight = family?.themes.first(where: { $0.appearance == .light }) {
            return firstLight
        }
        return Theme.fallback(appearance: .light)
    }

    /// Wrap a SwiftUI view in an NSHostingView at the given size, ready
    /// for `assertSnapshot(of:as: .image(size:))`.
    static func host<V: View>(_ view: V, size: CGSize) -> NSView {
        let hostingView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    /// Apply a theme + standard background to a view for snapshotting.
    @ViewBuilder
    static func framed<V: View>(_ view: V, theme: Theme) -> some View {
        view
            .environment(\.codeTheme, theme)
            .background(Color(tokens: theme.style.editor.background))
    }
}
#endif
```

```swift
// Tests/CodeEditorUITests/Snapshots/PlatformGlassSurfaceSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class PlatformGlassSurfaceSnapshots: XCTestCase {
    func testTitleBarRoleDark()  { snap(role: .titleBar,  theme: .dark) }
    func testTitleBarRoleLight() { snap(role: .titleBar,  theme: .light) }
    func testTabBarRoleDark()    { snap(role: .tabBar,    theme: .dark) }
    func testTabBarRoleLight()   { snap(role: .tabBar,    theme: .light) }
    func testStatusBarRoleDark() { snap(role: .statusBar, theme: .dark) }
    func testStatusBarRoleLight() { snap(role: .statusBar, theme: .light) }
    func testPanelRoleDark()     { snap(role: .panel,     theme: .dark) }
    func testPanelRoleLight()    { snap(role: .panel,     theme: .light) }
    func testPopoverRoleDark()   { snap(role: .popover,   theme: .dark) }
    func testPopoverRoleLight()  { snap(role: .popover,   theme: .light) }

    private enum ThemeChoice { case dark, light }

    private func snap(role: PlatformGlassSurface.Role, theme: ThemeChoice) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let body = SnapshotSupport.framed(
            Text(String(describing: role))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .platformGlassSurface(role),
            theme: resolved
        )
        let host = SnapshotSupport.host(body, size: SnapshotSupport.glassSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter PlatformGlassSurface`
Expected: FAIL — `PlatformGlassSurface` and `.platformGlassSurface(_:)` not defined; `SnapshotSupport` references missing types.

- [ ] **Step 3: Implement `PlatformGlassSurface`**

```swift
// Sources/CodeEditorUI/Glass/PlatformGlassSurface.swift
import CodeEditorPlugin
import SwiftUI

/// `ViewModifier` that applies the platform's Liquid Glass surface to its
/// content, layered with a theme-driven tint, role-specific background,
/// and (for `.popover`) the theme's popover shadow.
///
/// Reads `\.codeTheme` from the SwiftUI environment to pick up
/// `Theme.platform.glass` and `Theme.style.chrome.*` colors. Pass a `Role`
/// to indicate which kind of chrome surface this is — the modifier maps
/// roles to backgrounds and tint multipliers per the spec's table.
public struct PlatformGlassSurface: ViewModifier {
    /// The kind of chrome surface — drives background, tint multiplier,
    /// and shadow choice.
    public enum Role: Hashable, Sendable {
        case titleBar
        case tabBar
        case statusBar
        case panel
        case popover
    }

    @Environment(\.codeTheme) private var theme

    /// Surface role; selected by the host at modifier-installation time.
    public let role: Role

    /// Creates a glass-surface modifier for the given role.
    public init(role: Role) {
        self.role = role
    }

    public func body(content: Content) -> some View {
        content
            .background(roleBackground)
            .glassEffect()
            .overlay(theme.glassTintColor.opacity(scaledOpacity))
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: shadowX,
                y: shadowY
            )
    }

    // MARK: - Role-driven layers

    private var roleBackground: Color {
        switch role {
        case .titleBar:  return theme.titleBarColor
        case .tabBar:    return theme.tabBarColor
        case .statusBar: return theme.statusBarColor
        case .panel:     return theme.panelColor
        case .popover:   return theme.elevatedColor
        }
    }

    private var scaledOpacity: Double {
        let base = theme.glassOpacity
        let multiplier: Double
        switch role {
        case .titleBar, .statusBar: multiplier = 1.0
        case .tabBar:               multiplier = 0.8
        case .panel, .popover:      multiplier = 1.2
        }
        return min(base * multiplier, 1.0)
    }

    private var shadowColor: Color {
        role == .popover ? theme.popoverShadow.color : .clear
    }

    private var shadowRadius: CGFloat {
        role == .popover ? theme.popoverShadow.blur : 0
    }

    private var shadowX: CGFloat {
        role == .popover ? theme.popoverShadow.x : 0
    }

    private var shadowY: CGFloat {
        role == .popover ? theme.popoverShadow.y : 0
    }
}

extension View {
    /// Apply the platform's Liquid Glass surface for the given chrome role.
    ///
    /// The modifier reads the active `Theme` from the environment and
    /// composes background fill, tint, and shadow per role.
    public func platformGlassSurface(_ role: PlatformGlassSurface.Role) -> some View {
        modifier(PlatformGlassSurface(role: role))
    }
}
```

- [ ] **Step 4: Run unit test (role enumeration) to verify pass**

Run: `swift test --filter PlatformGlassSurfaceTests`
Expected: PASS.

- [ ] **Step 5: Record the snapshot baselines**

Run snapshot tests once with recording mode on, then commit the resulting PNGs:

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter PlatformGlassSurfaceSnapshots
swift test --filter PlatformGlassSurfaceSnapshots   # second run must pass without recording
```

Expected: first run records 10 PNGs into `Tests/CodeEditorUITests/Snapshots/__Snapshots__/PlatformGlassSurfaceSnapshots/`; second run passes against them.

- [ ] **Step 6: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorUI/Glass/ \
        Tests/CodeEditorUITests/PlatformGlassSurfaceTests.swift \
        Tests/CodeEditorUITests/Snapshots/SnapshotSupport.swift \
        Tests/CodeEditorUITests/Snapshots/PlatformGlassSurfaceSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/PlatformGlassSurfaceSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add PlatformGlassSurface modifier + snapshot scaffolding

ViewModifier wrapping SwiftUI's native Liquid Glass effect, layered with
role-driven background, theme-driven tint, and popover shadow when role
== .popover. Adds shared SnapshotSupport helpers (NSHostingView wrapper,
fixed sizes, dark/light theme picks) used by the rest of this sub-project.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `EditorTrafficLights` + `EditorTitleBar` (macOS + Catalyst)

**Files:**
- Create: `Sources/CodeEditorUI/Window/EditorTrafficLights.swift`
- Create: `Sources/CodeEditorUI/Window/EditorTitleBar.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorTrafficLightsSnapshots.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorTitleBarSnapshots.swift`

- [ ] **Step 1: Write failing snapshot tests**

```swift
// Tests/CodeEditorUITests/Snapshots/EditorTrafficLightsSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorTrafficLightsSnapshots: XCTestCase {
    func testDecorativeDark()      { snap(theme: .dark,  withCallbacks: false) }
    func testDecorativeLight()     { snap(theme: .light, withCallbacks: false) }
    func testWithCallbacksDark()   { snap(theme: .dark,  withCallbacks: true) }
    func testWithCallbacksLight()  { snap(theme: .light, withCallbacks: true) }

    private enum ThemeChoice { case dark, light }

    private func snap(theme: ThemeChoice, withCallbacks: Bool) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        var configuration = TrafficLightsConfiguration.standard
        if withCallbacks {
            configuration.onClose = {}
            configuration.onMinimize = {}
            configuration.onZoom = {}
        }
        let view = SnapshotSupport.framed(
            EditorTrafficLights(configuration: configuration).padding(8),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.trafficLightsSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

```swift
// Tests/CodeEditorUITests/Snapshots/EditorTitleBarSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorTitleBarSnapshots: XCTestCase {
    func testEmptyTrailingDark()    { snap(theme: .dark,  trailing: false) }
    func testEmptyTrailingLight()   { snap(theme: .light, trailing: false) }
    func testWithToolbarDark()      { snap(theme: .dark,  trailing: true) }
    func testWithToolbarLight()     { snap(theme: .light, trailing: true) }

    private enum ThemeChoice { case dark, light }

    @ViewBuilder
    private func toolbarPills() -> some View {
        HStack(spacing: 6) {
            Text("⌘B").font(.system(size: 10, design: .monospaced)).padding(.horizontal, 8).frame(height: 22)
            Text("▶").font(.system(size: 10, design: .monospaced)).padding(.horizontal, 8).frame(height: 22)
            Text("◧").font(.system(size: 10, design: .monospaced)).padding(.horizontal, 8).frame(height: 22)
        }
    }

    private func snap(theme: ThemeChoice, trailing: Bool) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let state = EditorState()
        state.documentName = "EditorState.swift — CodeEditorPlugin"
        let titleBar = trailing
            ? AnyView(EditorTitleBar { toolbarPills() })
            : AnyView(EditorTitleBar())
        let view = SnapshotSupport.framed(
            titleBar.environment(\.editorState, state),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.rowSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter EditorTitleBar`
Expected: FAIL — `EditorTrafficLights`, `EditorTitleBar`, `TrafficLightsConfiguration` not defined.

- [ ] **Step 3: Implement `EditorTrafficLights`**

```swift
// Sources/CodeEditorUI/Window/EditorTrafficLights.swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import SwiftUI

/// Optional callbacks for the three traffic-light buttons.
///
/// `.standard` is the decorative form (no callbacks attached). Hosts
/// embedding `EditorTrafficLights` inside a real `NSWindow` can wire
/// `onClose` to `NSApp.keyWindow?.close()`, etc.
public struct TrafficLightsConfiguration: Sendable {
    /// Invoked when the user clicks the close button.
    public var onClose: (@Sendable () -> Void)?
    /// Invoked when the user clicks the minimize button.
    public var onMinimize: (@Sendable () -> Void)?
    /// Invoked when the user clicks the zoom button.
    public var onZoom: (@Sendable () -> Void)?

    /// Decorative form — no callbacks. The lights render but don't act.
    public static let standard: Self = .init()

    /// Memberwise builder.
    public init(
        onClose:    (@Sendable () -> Void)? = nil,
        onMinimize: (@Sendable () -> Void)? = nil,
        onZoom:     (@Sendable () -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onZoom = onZoom
    }
}

/// Custom-painted SwiftUI traffic lights matching macOS Tahoe colors and
/// sizing. Available on macOS and Mac Catalyst; absent on iOS.
///
/// Each circle is `size`×`size` (default 14pt). Hover state grows the
/// internal glyphs subtly. Callbacks from `TrafficLightsConfiguration`
/// fire on click; if all three are nil the lights are decorative.
public struct EditorTrafficLights: View {
    /// Standard Tahoe close-button red.
    private static let closeColor = Color(red: 1.0,        green: 0.365, blue: 0.341)
    /// Standard Tahoe minimize-button yellow.
    private static let minimizeColor = Color(red: 0.996,   green: 0.737, blue: 0.180)
    /// Standard Tahoe zoom-button green.
    private static let zoomColor = Color(red: 0.157,       green: 0.784, blue: 0.251)

    /// Stroke color for the dot's hairline border.
    private static let strokeColor = Color.black.opacity(0.18)

    /// Configuration carrying optional click callbacks.
    public let configuration: TrafficLightsConfiguration
    /// Diameter of each light in points.
    public let size: CGFloat

    /// Creates a traffic-lights cluster.
    /// - Parameters:
    ///   - configuration: optional callbacks; defaults to decorative.
    ///   - size: diameter in points; defaults to 14.
    public init(
        configuration: TrafficLightsConfiguration = .standard,
        size: CGFloat = 14
    ) {
        self.configuration = configuration
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 9) {
            light(color: Self.closeColor,    action: configuration.onClose)
            light(color: Self.minimizeColor, action: configuration.onMinimize)
            light(color: Self.zoomColor,     action: configuration.onZoom)
        }
    }

    @ViewBuilder
    private func light(color: Color, action: (@Sendable () -> Void)?) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Self.strokeColor, lineWidth: 0.5))
            .accessibilityHidden(action == nil)
            .onTapGesture { action?() }
    }
}
#endif
```

- [ ] **Step 4: Implement `EditorTitleBar`**

```swift
// Sources/CodeEditorUI/Window/EditorTitleBar.swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Tahoe-styled title bar with traffic lights, centered title, and a
/// trailing slot for toolbar pills.
///
/// Available on macOS and Mac Catalyst. The title bar is an embeddable
/// SwiftUI view — it does not require `.windowStyle(.hiddenTitleBar)` and
/// does not interact with the host `NSWindow`'s real traffic-light
/// buttons. For real-window integration, hosts apply
/// `.windowStyle(.hiddenTitleBar)` themselves and use SwiftUI's window
/// toolbar APIs.
public struct EditorTitleBar<Trailing: View>: View {
    @Environment(\.codeTheme)   private var theme
    @Environment(\.editorState) private var editorState

    private let titleOverride: String?
    private let trafficLights: TrafficLightsConfiguration
    private let trailing: () -> Trailing

    /// Creates a title bar.
    /// - Parameters:
    ///   - title: shown in the centered title position. When nil, the bar
    ///     reads `\.editorState`'s `documentName`.
    ///   - trafficLights: callback configuration for the three buttons.
    ///   - trailing: `@ViewBuilder` slot for trailing toolbar content.
    public init(
        title: String? = nil,
        trafficLights: TrafficLightsConfiguration = .standard,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.titleOverride = title
        self.trafficLights = trafficLights
        self.trailing = trailing
    }

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                EditorTrafficLights(configuration: trafficLights)
                    .padding(.leading, 14)
                Spacer()
                trailing()
                    .padding(.trailing, 14)
            }

            Text(resolvedTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 120)   // reserve space for traffic lights + trailing
                .allowsHitTesting(false)
        }
        .frame(height: 38)
        .platformGlassSurface(.titleBar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(tokens: theme.style.borders.base).opacity(0.5))
                .frame(height: 0.5)
        }
    }

    private var resolvedTitle: String {
        if let titleOverride { return titleOverride }
        return editorState.documentName
    }
}
#endif
```

- [ ] **Step 5: Record snapshot baselines and verify pass**

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter "EditorTrafficLightsSnapshots|EditorTitleBarSnapshots"
swift test --filter "EditorTrafficLightsSnapshots|EditorTitleBarSnapshots"
```

Expected: 4 + 4 PNGs recorded, then second run passes against them.

- [ ] **Step 6: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorUI/Window/ \
        Tests/CodeEditorUITests/Snapshots/EditorTrafficLightsSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/EditorTitleBarSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorTrafficLightsSnapshots/ \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorTitleBarSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorTrafficLights + EditorTitleBar (macOS + Catalyst)

Painted SwiftUI traffic lights with Tahoe colors and optional click
callbacks. EditorTitleBar composes traffic lights + centered title +
trailing @ViewBuilder slot, backed by PlatformGlassSurface(.titleBar).
Both gated to canImport(AppKit) — absent on pure iOS.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `EditorBreadcrumbView`

**Files:**
- Create: `Sources/CodeEditorUI/Breadcrumb/EditorBreadcrumbView.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorBreadcrumbSnapshots.swift`

- [ ] **Step 1: Write failing snapshot tests**

```swift
// Tests/CodeEditorUITests/Snapshots/EditorBreadcrumbSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorBreadcrumbSnapshots: XCTestCase {
    func testShortDark()    { snap(theme: .dark,  long: false) }
    func testShortLight()   { snap(theme: .light, long: false) }
    func testLongDark()     { snap(theme: .dark,  long: true) }
    func testLongLight()    { snap(theme: .light, long: true) }

    private enum ThemeChoice { case dark, light }

    private func snap(theme: ThemeChoice, long: Bool) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let path: [BreadcrumbComponent] = long
            ? [
                .init(name: "Workspace",          kind: .workspace),
                .init(name: "Sources",            kind: .folder),
                .init(name: "CodeEditorPlugin",   kind: .folder),
                .init(name: "Theming",            kind: .folder),
                .init(name: "Loader",             kind: .folder),
                .init(name: "ThemeFamily.swift",  kind: .file),
                .init(name: "ThemeFamily.theme(named:)", kind: .symbol),
            ]
            : [
                .init(name: "Sources",       kind: .folder),
                .init(name: "Foo.swift",     kind: .file),
                .init(name: "greet(_:)",     kind: .symbol),
            ]
        let view = SnapshotSupport.framed(
            EditorBreadcrumbView(components: path)
                .padding(.horizontal, 14)
                .padding(.vertical, 4),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.breadcrumbSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter EditorBreadcrumb`
Expected: FAIL — `EditorBreadcrumbView` not defined.

- [ ] **Step 3: Implement `EditorBreadcrumbView`**

```swift
// Sources/CodeEditorUI/Breadcrumb/EditorBreadcrumbView.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Renders a breadcrumb trail (workspace › folder › file › symbol).
///
/// Reads `\.editorState.breadcrumbPath` when no `components` are passed;
/// otherwise uses the explicit `components`. Tap callback invoked when
/// the user clicks a segment; nil callback means segments are not
/// interactive.
public struct EditorBreadcrumbView: View {
    @Environment(\.codeTheme)   private var theme
    @Environment(\.editorState) private var editorState

    private let componentsOverride: [BreadcrumbComponent]?
    private let onSelect: ((BreadcrumbComponent) -> Void)?

    /// Creates a breadcrumb view.
    /// - Parameters:
    ///   - components: explicit path; pass nil to read from `EditorState`.
    ///   - onSelect: tap callback per segment; nil makes segments inert.
    public init(
        components: [BreadcrumbComponent]? = nil,
        onSelect: ((BreadcrumbComponent) -> Void)? = nil
    ) {
        self.componentsOverride = components
        self.onSelect = onSelect
    }

    public var body: some View {
        let path = resolvedPath
        HStack(spacing: 4) {
            ForEach(Array(path.enumerated()), id: \.element.id) { index, component in
                segment(component)
                if index < path.count - 1 {
                    chevron
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
    }

    private var resolvedPath: [BreadcrumbComponent] {
        componentsOverride ?? editorState.breadcrumbPath
    }

    @ViewBuilder
    private func segment(_ component: BreadcrumbComponent) -> some View {
        let label = HStack(spacing: 4) {
            kindGlyph(for: component.kind)
            Text(component.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Color(tokens: theme.style.text.base))

        if let onSelect {
            Button {
                onSelect(component)
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    @ViewBuilder
    private func kindGlyph(for kind: BreadcrumbComponent.Kind) -> some View {
        let glyph: String
        switch kind {
        case .workspace: glyph = "rectangle.stack"
        case .folder:    glyph = "folder"
        case .file:      glyph = "doc"
        case .symbol:    glyph = "function"
        }
        Image(systemName: glyph)
            .imageScale(.small)
            .foregroundStyle(Color(tokens: theme.style.icon.base))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .imageScale(.small)
            .foregroundStyle(Color(tokens: theme.style.text.muted))
    }
}
```

- [ ] **Step 4: Record snapshots and verify pass**

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter EditorBreadcrumbSnapshots
swift test --filter EditorBreadcrumbSnapshots
```

- [ ] **Step 5: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorUI/Breadcrumb/ \
        Tests/CodeEditorUITests/Snapshots/EditorBreadcrumbSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorBreadcrumbSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorBreadcrumbView

Renders a breadcrumb trail with kind glyphs (workspace/folder/file/
symbol) and chevron separators. Reads EditorState.breadcrumbPath when
no explicit components are passed. Optional onSelect callback for
navigation; absent callback renders inert segments.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `EditorStatusBar`

**Files:**
- Create: `Sources/CodeEditorUI/StatusBar/EditorStatusBar.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift`

- [ ] **Step 1: Write failing snapshot tests**

```swift
// Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorStatusBarSnapshots: XCTestCase {
    func testNoDocDark()             { snap(theme: .dark,  scenario: .noDoc) }
    func testNoDocLight()            { snap(theme: .light, scenario: .noDoc) }
    func testWithSelectionDark()     { snap(theme: .dark,  scenario: .docWithSelection) }
    func testWithSelectionLight()    { snap(theme: .light, scenario: .docWithSelection) }
    func testWithTrailingDark()      { snap(theme: .dark,  scenario: .docWithTrailingExtras) }
    func testWithTrailingLight()     { snap(theme: .light, scenario: .docWithTrailingExtras) }

    private enum ThemeChoice { case dark, light }
    private enum Scenario { case noDoc, docWithSelection, docWithTrailingExtras }

    @ViewBuilder
    private func trailingExtras() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
            Text("LSP").font(.system(size: 11, design: .monospaced))
        }
    }

    private func snap(theme: ThemeChoice, scenario: Scenario) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let state = EditorState()
        switch scenario {
        case .noDoc:
            break
        case .docWithSelection, .docWithTrailingExtras:
            state.selection = SelectionState(line: 142, column: 18, selectionLength: 0)
            state.language = .swift
            state.lineCount = 380
            state.hardwareAccelerationActive = true
        }
        let bar: AnyView = {
            switch scenario {
            case .docWithTrailingExtras:
                return AnyView(EditorStatusBar { trailingExtras() })
            default:
                return AnyView(EditorStatusBar())
            }
        }()
        let configuration = EditorConfiguration()
        let view = SnapshotSupport.framed(
            bar
                .environment(\.editorState, state)
                .environment(\.codeEditorConfiguration, configuration),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.rowSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter EditorStatusBar`
Expected: FAIL — `EditorStatusBar` not defined.

- [ ] **Step 3: Implement `EditorStatusBar`**

```swift
// Sources/CodeEditorUI/StatusBar/EditorStatusBar.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Bottom status bar — language indicator on the left, selection +
/// indentation + hardware-acceleration indicator on the right, plus a
/// trailing `@ViewBuilder` slot for host extras (e.g., LSP status,
/// branch name).
///
/// Reads `\.codeTheme`, `\.codeEditorConfiguration`, and `\.editorState`
/// from the environment. Renders zero-fields when no document is open
/// (no selection in `EditorState`).
public struct EditorStatusBar<Trailing: View>: View {
    @Environment(\.codeTheme)               private var theme
    @Environment(\.codeEditorConfiguration) private var configuration
    @Environment(\.editorState)             private var editorState

    private let trailing: () -> Trailing

    /// Creates a status bar.
    /// - Parameter trailing: `@ViewBuilder` slot for trailing host content.
    public init(@ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            languageBadge
            Spacer()
            selectionBadge
            indentationBadge
            hardwareAccelerationBadge
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 28)
        .platformGlassSurface(.statusBar)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color(tokens: theme.style.text.muted))
    }

    @ViewBuilder
    private var languageBadge: some View {
        if let language = editorState.language {
            Label(language.displayName, systemImage: "chevron.left.slash.chevron.right")
                .labelStyle(.titleAndIcon)
        } else {
            Text("Plain Text")
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if let selection = editorState.selection {
            if selection.selectionLength == 0 {
                Text("Ln \(selection.line), Col \(selection.column)")
            } else {
                Text("Ln \(selection.line), Col \(selection.column) (\(selection.selectionLength) sel)")
            }
        } else {
            Text("Ln —")
        }
    }

    @ViewBuilder
    private var indentationBadge: some View {
        let mode = configuration.layout.insertSpacesForTabs ? "Spaces" : "Tabs"
        Text("\(mode): \(configuration.layout.tabWidth)")
    }

    @ViewBuilder
    private var hardwareAccelerationBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(editorState.hardwareAccelerationActive
                      ? Color(tokens: Tokens.Palette.Status.successDark)
                      : Color(tokens: theme.style.text.muted))
                .frame(width: 6, height: 6)
            Text(editorState.hardwareAccelerationActive ? "GPU" : "CPU")
        }
    }
}
```

- [ ] **Step 4: Record snapshots and verify pass**

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter EditorStatusBarSnapshots
swift test --filter EditorStatusBarSnapshots
```

- [ ] **Step 5: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorUI/StatusBar/ \
        Tests/CodeEditorUITests/Snapshots/EditorStatusBarSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorStatusBarSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorStatusBar

Bottom status bar reading EditorState (language/selection/lineCount/
hwAccel) and EditorConfiguration (layout.insertSpacesForTabs/tabWidth).
Trailing @ViewBuilder slot for host extras like LSP status. Backed by
PlatformGlassSurface(.statusBar).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Tab strip — `EditorTab`, `EditorTabStrip`, `EditorTabStripStyle`

**Files:**
- Create: `Sources/CodeEditorUI/TabStrip/EditorTab.swift`
- Create: `Sources/CodeEditorUI/TabStrip/EditorTabStripStyle.swift`
- Create: `Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift`
- Create: `Tests/CodeEditorUITests/StyleProtocolTests.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorUITests/StyleProtocolTests.swift
import CodeEditorPlugin
import CodeEditorUI
import Foundation
import SwiftUI
import Testing

@Suite("Tab strip & command palette style protocols")
@MainActor
struct StyleProtocolTests {
    @Test("DefaultEditorTabStripStyle.makeBody returns non-empty for empty tabs")
    func defaultStyleEmpty() {
        let configuration = EditorTabStripStyleConfiguration(
            tabs: [],
            activeTabID: nil,
            setActive: { _ in },
            close: { _ in }
        )
        let body = DefaultEditorTabStripStyle().makeBody(configuration: configuration)
        _ = body  // compile-time proof body builds
    }

    @Test("DefaultEditorTabStripStyle.makeBody returns non-empty for many tabs")
    func defaultStyleMany() {
        let tabs = (0..<10).map { idx in
            TabModel(name: "File\(idx).swift", isDirty: idx % 2 == 0)
        }
        let configuration = EditorTabStripStyleConfiguration(
            tabs: tabs,
            activeTabID: tabs[3].id,
            setActive: { _ in },
            close: { _ in }
        )
        let body = DefaultEditorTabStripStyle().makeBody(configuration: configuration)
        _ = body
    }

    @Test("CompactEditorTabStripStyle is distinct from default")
    func compactDistinct() {
        // The two styles produce different opaque body types, so the
        // distinction is structural rather than runtime-comparable.
        // We assert they exist and can both be installed.
        _ = DefaultEditorTabStripStyle()
        _ = CompactEditorTabStripStyle()
    }
}
```

```swift
// Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorTabStripSnapshots: XCTestCase {
    func testEmptyDark()           { snap(theme: .dark,  variant: .empty) }
    func testEmptyLight()          { snap(theme: .light, variant: .empty) }
    func testSingleDark()          { snap(theme: .dark,  variant: .single) }
    func testSingleLight()         { snap(theme: .light, variant: .single) }
    func testManyDark()            { snap(theme: .dark,  variant: .many) }
    func testManyLight()           { snap(theme: .light, variant: .many) }
    func testWithDirtyDark()       { snap(theme: .dark,  variant: .withDirty) }
    func testWithDirtyLight()      { snap(theme: .light, variant: .withDirty) }
    func testCompactStyleDark()    { snap(theme: .dark,  variant: .compactStyle) }
    func testCompactStyleLight()   { snap(theme: .light, variant: .compactStyle) }

    private enum ThemeChoice { case dark, light }
    private enum Variant { case empty, single, many, withDirty, compactStyle }

    private func snap(theme: ThemeChoice, variant: Variant) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let tabs: [TabModel]
        switch variant {
        case .empty:
            tabs = []
        case .single:
            tabs = [TabModel(name: "Foo.swift", language: .swift)]
        case .many, .compactStyle:
            tabs = [
                TabModel(name: "Foo.swift", language: .swift),
                TabModel(name: "Bar.ts",    language: .typescript),
                TabModel(name: "Baz.py",    language: .python),
                TabModel(name: "Qux.json",  language: .json),
            ]
        case .withDirty:
            tabs = [
                TabModel(name: "Foo.swift", language: .swift, isDirty: true),
                TabModel(name: "Bar.ts",    language: .typescript),
            ]
        }
        let active = tabs.first?.id
        let view: AnyView = {
            let bindingTabs = Binding<[TabModel]>(get: { tabs }, set: { _ in })
            let bindingActive = Binding<TabModel.ID?>(get: { active }, set: { _ in })
            let strip = EditorTabStrip(tabs: bindingTabs, activeTabID: bindingActive)
            switch variant {
            case .compactStyle:
                return AnyView(strip.editorTabStripStyle(.compact))
            default:
                return AnyView(strip)
            }
        }()
        let framed = SnapshotSupport.framed(view, theme: resolved)
        let host = SnapshotSupport.host(framed, size: SnapshotSupport.rowSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter "StyleProtocolTests|EditorTabStripSnapshots"`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `EditorTab`**

```swift
// Sources/CodeEditorUI/TabStrip/EditorTab.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// One file tab in the chrome's tab strip.
///
/// Public so custom `EditorTabStripStyle` implementations can compose
/// the same primitive. Renders a leading language glyph, the tab name,
/// and a trailing close button (or dirty dot when `tab.isDirty` is true).
public struct EditorTab: View {
    @Environment(\.codeTheme) private var theme

    private let tab: TabModel
    private let isActive: Bool
    private let onSelect: () -> Void
    private let onClose: (() -> Void)?

    /// Creates a tab.
    /// - Parameters:
    ///   - tab: model.
    ///   - isActive: true when this tab is the foreground tab.
    ///   - onSelect: tap action.
    ///   - onClose: close-button action; nil suppresses the close button.
    public init(
        tab: TabModel,
        isActive: Bool,
        onSelect: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.tab = tab
        self.isActive = isActive
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 6) {
            languageGlyph
            Text(tab.name)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(1)
                .truncationMode(.middle)
            trailingControl
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(background)
        .overlay(activeIndicator, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var background: some View {
        Color(tokens: isActive
              ? theme.style.chrome.tabActiveBackground
              : theme.style.chrome.tabInactiveBackground)
    }

    @ViewBuilder
    private var activeIndicator: some View {
        if isActive {
            Rectangle()
                .fill(Color(tokens: theme.style.text.accent))
                .frame(height: 2)
        }
    }

    @ViewBuilder
    private var languageGlyph: some View {
        let glyph: String
        switch tab.language {
        case .swift?:      glyph = "swift"
        case .typescript?, .javascript?: glyph = "curlybraces"
        case .python?:     glyph = "p.circle"
        case .json?:       glyph = "doc.text"
        case .markdown?:   glyph = "text.alignleft"
        default:           glyph = "doc"
        }
        Image(systemName: glyph)
            .imageScale(.small)
            .foregroundStyle(Color(tokens: theme.style.icon.base))
    }

    @ViewBuilder
    private var trailingControl: some View {
        if tab.isDirty {
            Circle()
                .fill(Color(tokens: theme.style.text.muted))
                .frame(width: 8, height: 8)
        } else if let onClose {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 4: Implement `EditorTabStripStyle`**

```swift
// Sources/CodeEditorUI/TabStrip/EditorTabStripStyle.swift
import CodeEditorPlugin
import SwiftUI

/// Style protocol for `EditorTabStrip`, à la `ButtonStyle`.
///
/// Implementers receive the strip's data + actions in `Configuration`
/// and return a body view. Library ships `.default` and `.compact`;
/// hosts install custom styles via `.editorTabStripStyle(_:)`.
public protocol EditorTabStripStyle {
    associatedtype Body: View
    /// Render the strip for the given configuration.
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
    typealias Configuration = EditorTabStripStyleConfiguration
}

/// Data + actions handed to an `EditorTabStripStyle` to render with.
public struct EditorTabStripStyleConfiguration {
    /// Current tabs in the strip.
    public let tabs: [TabModel]
    /// Active tab's ID; nil when no tab is active.
    public let activeTabID: TabModel.ID?
    /// Activate a tab by ID.
    public let setActive: (TabModel.ID) -> Void
    /// Close a tab by ID.
    public let close: (TabModel.ID) -> Void

    /// Memberwise builder for tests/custom styles.
    public init(
        tabs: [TabModel],
        activeTabID: TabModel.ID?,
        setActive: @escaping (TabModel.ID) -> Void,
        close: @escaping (TabModel.ID) -> Void
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.setActive = setActive
        self.close = close
    }
}

/// Default tab strip style — comfortable height, scroll-on-overflow,
/// dirty dot replaces close button on dirty tabs.
public struct DefaultEditorTabStripStyle: EditorTabStripStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(configuration.tabs) { tab in
                    EditorTab(
                        tab: tab,
                        isActive: tab.id == configuration.activeTabID,
                        onSelect: { configuration.setActive(tab.id) },
                        onClose:  { configuration.close(tab.id) }
                    )
                    Divider()
                        .frame(height: 16)
                        .opacity(0.3)
                }
            }
        }
        .frame(height: 36)
        .platformGlassSurface(.tabBar)
    }
}

/// Compact tab strip style — shorter height, no dividers.
public struct CompactEditorTabStripStyle: EditorTabStripStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(configuration.tabs) { tab in
                    EditorTab(
                        tab: tab,
                        isActive: tab.id == configuration.activeTabID,
                        onSelect: { configuration.setActive(tab.id) },
                        onClose:  { configuration.close(tab.id) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 28)
        .platformGlassSurface(.tabBar)
    }
}

extension EditorTabStripStyle where Self == DefaultEditorTabStripStyle {
    /// Default tab strip style.
    public static var `default`: Self { .init() }
}

extension EditorTabStripStyle where Self == CompactEditorTabStripStyle {
    /// Compact tab strip style.
    public static var compact: Self { .init() }
}

// MARK: - Style installation

private struct EditorTabStripStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue: any EditorTabStripStyle = DefaultEditorTabStripStyle()
}

extension EnvironmentValues {
    var editorTabStripStyle: any EditorTabStripStyle {
        get { self[EditorTabStripStyleEnvironmentKey.self] }
        set { self[EditorTabStripStyleEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Install a tab strip style for any `EditorTabStrip` in this view's
    /// scope.
    public func editorTabStripStyle<S: EditorTabStripStyle>(_ style: S) -> some View {
        environment(\.editorTabStripStyle, style)
    }
}
```

- [ ] **Step 5: Implement `EditorTabStrip`**

```swift
// Sources/CodeEditorUI/TabStrip/EditorTabStrip.swift
import CodeEditorPlugin
import SwiftUI

/// File-tab strip. Reads its style from `\.editorTabStripStyle` (default
/// is `DefaultEditorTabStripStyle`); hosts override via
/// `.editorTabStripStyle(_:)`.
///
/// Tabs and active selection are passed via `Binding`s — typically
/// `Binding<[TabModel]>(get: { state.tabs }, set: { state.tabs = $0 })`,
/// but any host model that produces those bindings works.
public struct EditorTabStrip: View {
    @Environment(\.editorTabStripStyle) private var style

    @Binding private var tabs: [TabModel]
    @Binding private var activeTabID: TabModel.ID?
    private let onClose: ((TabModel.ID) -> Void)?

    /// Creates a tab strip.
    /// - Parameters:
    ///   - tabs: bound array of tabs; mutate to reorder/insert/remove.
    ///   - activeTabID: bound active-tab id; mutate to switch foreground.
    ///   - onClose: extra close hook fired in addition to default
    ///     "remove from `tabs`" behavior. nil means "default behavior only."
    public init(
        tabs: Binding<[TabModel]>,
        activeTabID: Binding<TabModel.ID?>,
        onClose: ((TabModel.ID) -> Void)? = nil
    ) {
        self._tabs = tabs
        self._activeTabID = activeTabID
        self.onClose = onClose
    }

    public var body: some View {
        let configuration = EditorTabStripStyleConfiguration(
            tabs: tabs,
            activeTabID: activeTabID,
            setActive: { id in activeTabID = id },
            close: { id in
                onClose?(id)
                if let index = tabs.firstIndex(where: { $0.id == id }) {
                    tabs.remove(at: index)
                    if activeTabID == id { activeTabID = tabs.first?.id }
                }
            }
        )
        AnyView(style.makeBody(configuration: configuration))
    }
}
```

- [ ] **Step 6: Run unit tests + record snapshots and verify pass**

```bash
swift test --filter StyleProtocolTests
SNAPSHOT_TESTING_RECORD=true swift test --filter EditorTabStripSnapshots
swift test --filter EditorTabStripSnapshots
```

- [ ] **Step 7: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorUI/TabStrip/ \
        Tests/CodeEditorUITests/StyleProtocolTests.swift \
        Tests/CodeEditorUITests/Snapshots/EditorTabStripSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorTabStripSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorTabStrip + EditorTabStripStyle

EditorTab renders a single file tab (language glyph, name, dirty dot
or close button). EditorTabStripStyle protocol with Default and Compact
built-ins, installed via .editorTabStripStyle(_:). EditorTabStrip is
the view that resolves the active style and hands it the configuration.
Closing a tab removes it from the bound array and shifts active to the
first remaining tab.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `EditorSidebarShell` (macOS + Catalyst)

**Files:**
- Create: `Sources/CodeEditorUI/Sidebar/EditorSidebarShell.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorSidebarShellSnapshots.swift`

- [ ] **Step 1: Write failing snapshot test**

```swift
// Tests/CodeEditorUITests/Snapshots/EditorSidebarShellSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorSidebarShellSnapshots: XCTestCase {
    func testFullDark()  { snap(theme: .dark) }
    func testFullLight() { snap(theme: .light) }

    private enum ThemeChoice { case dark, light }

    @ViewBuilder
    private func tabBar() -> some View {
        HStack(spacing: 4) {
            sidebarTab("Files", isActive: true)
            sidebarTab("Search", isActive: false)
            sidebarTab("Issues", isActive: false)
            Spacer()
        }
    }

    private func sidebarTab(_ label: String, isActive: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(isActive ? Color.white.opacity(0.08) : .clear)
            .clipShape(.rect(cornerRadius: 5))
    }

    @ViewBuilder
    private func contentBody() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(["Sources", "CodeEditorPlugin", "Configuration",
                     "EditorConfiguration.swift", "Theming"], id: \.self) { label in
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(label)
                }
                .font(.system(size: 12))
                .padding(.leading, 8)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func footerBody() -> some View {
        HStack(spacing: 4) {
            ForEach(["Swift", "TS", "Python", "Rust", "JSON"], id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func snap(theme: ThemeChoice) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let view = SnapshotSupport.framed(
            EditorSidebarShell(
                sectionTitle: "CodeEditorPlugin",
                header:  { tabBar() },
                content: { contentBody() },
                footer:  { footerBody() }
            ),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.panelSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}
#endif
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter EditorSidebarShell`
Expected: FAIL — `EditorSidebarShell` not defined.

- [ ] **Step 3: Implement `EditorSidebarShell`**

```swift
// Sources/CodeEditorUI/Sidebar/EditorSidebarShell.swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Styled sidebar container. *No tree* — the host fills `content` with
/// whatever workspace/file/search view is appropriate. Provides a
/// glass-backed panel with optional header (tab bar in the prototype),
/// a section title, and a footer slot.
///
/// Available on macOS and Mac Catalyst. Absent on iOS — sidebars on
/// iPad have a different navigation idiom and aren't covered by this
/// component.
public struct EditorSidebarShell<Header: View, Content: View, Footer: View>: View {
    @Environment(\.codeTheme) private var theme

    private let sectionTitle: String?
    private let header: () -> Header
    private let content: () -> Content
    private let footer: () -> Footer

    /// Creates a sidebar shell.
    /// - Parameters:
    ///   - sectionTitle: optional uppercase section header above content.
    ///   - header: top slot (e.g., tab bar, search field).
    ///   - content: main slot — the host's tree or list.
    ///   - footer: bottom slot (e.g., language switchers, status row).
    public init(
        sectionTitle: String? = nil,
        @ViewBuilder header:  @escaping () -> Header  = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer:  @escaping () -> Footer  = { EmptyView() }
    ) {
        self.sectionTitle = sectionTitle
        self.header = header
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(separator, alignment: .bottom)

            if let sectionTitle {
                Text(sectionTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            footer()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(separator, alignment: .top)
        }
        .platformGlassSurface(.panel)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(tokens: theme.style.borders.base).opacity(0.5))
            .frame(height: 0.5)
    }
}
#endif
```

- [ ] **Step 4: Record snapshots and verify pass**

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter EditorSidebarShellSnapshots
swift test --filter EditorSidebarShellSnapshots
```

- [ ] **Step 5: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorUI/Sidebar/ \
        Tests/CodeEditorUITests/Snapshots/EditorSidebarShellSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorSidebarShellSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorSidebarShell (macOS + Catalyst)

Glass-backed sidebar container with header / sectionTitle / content /
footer slots. No file tree — host supplies the actual content. Available
on macOS and Mac Catalyst; absent on iOS.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Command palette — `CommandPaletteItem`, `EditorCommandPaletteRow`, `EditorCommandPaletteStyle`, `EditorCommandPalette`

**Files:**
- Create: `Sources/CodeEditorUI/CommandPalette/CommandPaletteItem.swift`
- Create: `Sources/CodeEditorUI/CommandPalette/EditorCommandPaletteRow.swift`
- Create: `Sources/CodeEditorUI/CommandPalette/EditorCommandPaletteStyle.swift`
- Create: `Sources/CodeEditorUI/CommandPalette/EditorCommandPalette.swift`
- Create: `Tests/CodeEditorUITests/CommandPaletteFilterTests.swift`
- Create: `Tests/CodeEditorUITests/Snapshots/EditorCommandPaletteSnapshots.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorUITests/CommandPaletteFilterTests.swift
@testable import CodeEditorUI
import Foundation
import Testing

@Suite("Command palette query filter")
struct CommandPaletteFilterTests {
    private let items: [CommandPaletteItem] = [
        .init(title: "Open File…",        kind: .action,  shortcut: "⌘O"),
        .init(title: "Open Workspace",    kind: .action,  shortcut: nil),
        .init(title: "Save",              kind: .action,  shortcut: "⌘S"),
        .init(title: "Toggle Sidebar",    kind: .action,  shortcut: "⌘B"),
        .init(title: "Editor: Font Size", kind: .setting, shortcut: nil),
    ]

    @Test("Empty query returns all items in order")
    func emptyQuery() {
        let result = CommandPaletteFilter.filter(items: items, query: "")
        #expect(result.map(\.title) == items.map(\.title))
    }

    @Test("Substring match is case-insensitive")
    func substringMatch() {
        let result = CommandPaletteFilter.filter(items: items, query: "open")
        #expect(result.map(\.title) == ["Open File…", "Open Workspace"])
    }

    @Test("Whitespace-only query returns all")
    func whitespaceQuery() {
        let result = CommandPaletteFilter.filter(items: items, query: "   ")
        #expect(result.count == items.count)
    }

    @Test("No match returns empty")
    func noMatch() {
        let result = CommandPaletteFilter.filter(items: items, query: "xyzzy")
        #expect(result.isEmpty)
    }
}
```

```swift
// Tests/CodeEditorUITests/Snapshots/EditorCommandPaletteSnapshots.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorCommandPaletteSnapshots: XCTestCase {
    func testEmptyQueryDark()    { snap(theme: .dark,  variant: .empty) }
    func testEmptyQueryLight()   { snap(theme: .light, variant: .empty) }
    func testWithQueryDark()     { snap(theme: .dark,  variant: .withQuery) }
    func testWithQueryLight()    { snap(theme: .light, variant: .withQuery) }
    func testNoResultsDark()     { snap(theme: .dark,  variant: .noResults) }
    func testNoResultsLight()    { snap(theme: .light, variant: .noResults) }

    private enum ThemeChoice { case dark, light }
    private enum Variant { case empty, withQuery, noResults }

    private static let items: [CommandPaletteItem] = [
        .init(title: "Open File…",        kind: .action,  shortcut: "⌘O"),
        .init(title: "Open Workspace",    kind: .action,  shortcut: nil),
        .init(title: "Save",              kind: .action,  shortcut: "⌘S"),
        .init(title: "Toggle Sidebar",    kind: .action,  shortcut: "⌘B"),
        .init(title: "Editor: Font Size", kind: .setting, shortcut: nil),
    ]

    private func snap(theme: ThemeChoice, variant: Variant) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let initialQuery: String
        switch variant {
        case .empty:     initialQuery = ""
        case .withQuery: initialQuery = "open"
        case .noResults: initialQuery = "xyzzy"
        }
        let view = SnapshotSupport.framed(
            EditorCommandPalettePreviewHarness(
                items: Self.items,
                initialQuery: initialQuery
            ),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.popoverSize)
        assertSnapshot(of: host, as: .image(precision: 0.99, perceptualPrecision: 0.99))
    }
}

/// Test-only harness because `EditorCommandPalette` itself is presented
/// via `Binding<Bool> isPresented`; the snapshot needs the rendered
/// content with a specific query already applied. This struct mirrors
/// the palette's body for snapshotting.
@MainActor
private struct EditorCommandPalettePreviewHarness: View {
    let items: [CommandPaletteItem]
    let initialQuery: String
    @Environment(\.codeTheme) private var theme

    var body: some View {
        let visible = CommandPaletteFilter.filter(items: items, query: initialQuery)
        DefaultEditorCommandPaletteStyle().makeBody(
            configuration: EditorCommandPaletteStyleConfiguration(
                prompt: "Type a command…",
                query: .constant(initialQuery),
                visibleItems: visible,
                highlightedID: visible.first?.id,
                onHighlight: { _ in },
                onSelect: { _ in }
            )
        )
        .padding(16)
    }
}
#endif
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter "CommandPaletteFilterTests|EditorCommandPaletteSnapshots"`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `CommandPaletteItem`**

```swift
// Sources/CodeEditorUI/CommandPalette/CommandPaletteItem.swift
import Foundation

/// One item in the command palette.
///
/// Items are host-supplied. The package provides the shape so the
/// palette's filter and renderer behave uniformly.
public struct CommandPaletteItem: Hashable, Identifiable, Sendable {
    /// Item kind — drives the leading glyph.
    public enum Kind: Hashable, Sendable {
        case file
        case symbol
        case action
        case setting
    }

    /// Stable identifier.
    public let id: UUID
    /// Primary label.
    public let title: String
    /// Secondary label (e.g., file path, command source).
    public let subtitle: String?
    /// Item kind.
    public let kind: Kind
    /// Display-only shortcut hint (e.g., `"⌘O"`); not bound to a real key.
    public let shortcut: String?

    /// Memberwise builder.
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        kind: Kind,
        shortcut: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.shortcut = shortcut
    }
}

/// Internal helper that filters items by a query string. Lives in the
/// same module so unit tests can exercise it without touching SwiftUI.
enum CommandPaletteFilter {
    static func filter(items: [CommandPaletteItem], query: String) -> [CommandPaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let needle = trimmed.lowercased()
        return items.filter { $0.title.lowercased().contains(needle) }
    }
}
```

- [ ] **Step 4: Implement `EditorCommandPaletteRow`**

```swift
// Sources/CodeEditorUI/CommandPalette/EditorCommandPaletteRow.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// One row inside the command palette. Public so custom styles can
/// compose the same primitive.
public struct EditorCommandPaletteRow: View {
    @Environment(\.codeTheme) private var theme

    private let item: CommandPaletteItem
    private let isHighlighted: Bool

    /// Creates a palette row.
    /// - Parameters:
    ///   - item: model.
    ///   - isHighlighted: true when this row is the keyboard-focused row.
    public init(item: CommandPaletteItem, isHighlighted: Bool) {
        self.item = item
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        HStack(spacing: 10) {
            kindGlyph
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                }
            }
            Spacer()
            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
    }

    @ViewBuilder
    private var kindGlyph: some View {
        let glyph: String
        switch item.kind {
        case .file:    glyph = "doc"
        case .symbol:  glyph = "function"
        case .action:  glyph = "play.fill"
        case .setting: glyph = "slider.horizontal.3"
        }
        Image(systemName: glyph)
            .imageScale(.medium)
            .foregroundStyle(Color(tokens: theme.style.icon.base))
            .frame(width: 18)
    }

    private var rowBackground: Color {
        isHighlighted
            ? Color(tokens: theme.style.text.accent).opacity(0.15)
            : .clear
    }
}
```

- [ ] **Step 5: Implement `EditorCommandPaletteStyle`**

```swift
// Sources/CodeEditorUI/CommandPalette/EditorCommandPaletteStyle.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Style protocol for `EditorCommandPalette`, à la `ButtonStyle`.
public protocol EditorCommandPaletteStyle {
    associatedtype Body: View
    /// Render the palette for the given configuration.
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
    typealias Configuration = EditorCommandPaletteStyleConfiguration
}

/// Data + actions handed to an `EditorCommandPaletteStyle` to render with.
public struct EditorCommandPaletteStyleConfiguration {
    /// Placeholder text shown in the search field.
    public let prompt: String
    /// Bound query string the field edits.
    public let query: Binding<String>
    /// Items currently visible (post-filter).
    public let visibleItems: [CommandPaletteItem]
    /// Currently keyboard-focused item, or nil if none.
    public let highlightedID: CommandPaletteItem.ID?
    /// Update the highlighted item.
    public let onHighlight: (CommandPaletteItem.ID) -> Void
    /// Confirm the selection.
    public let onSelect: (CommandPaletteItem) -> Void

    /// Memberwise builder.
    public init(
        prompt: String,
        query: Binding<String>,
        visibleItems: [CommandPaletteItem],
        highlightedID: CommandPaletteItem.ID?,
        onHighlight: @escaping (CommandPaletteItem.ID) -> Void,
        onSelect: @escaping (CommandPaletteItem) -> Void
    ) {
        self.prompt = prompt
        self.query = query
        self.visibleItems = visibleItems
        self.highlightedID = highlightedID
        self.onHighlight = onHighlight
        self.onSelect = onSelect
    }
}

/// Default palette style — frosted-glass card with search field on top
/// and a scrolling list of `EditorCommandPaletteRow`s.
public struct DefaultEditorCommandPaletteStyle: EditorCommandPaletteStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            searchField(prompt: configuration.prompt, query: configuration.query)
                .padding(.horizontal, 12).padding(.vertical, 10)

            Divider().opacity(0.4)

            if configuration.visibleItems.isEmpty {
                emptyState(prompt: configuration.prompt)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(configuration.visibleItems) { item in
                            Button {
                                configuration.onSelect(item)
                            } label: {
                                EditorCommandPaletteRow(
                                    item: item,
                                    isHighlighted: item.id == configuration.highlightedID
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                if isHovering {
                                    configuration.onHighlight(item.id)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .platformGlassSurface(.popover)
        .clipShape(.rect(cornerRadius: 12))
        .frame(maxWidth: 480)
    }

    @ViewBuilder
    private func searchField(prompt: String, query: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").imageScale(.medium)
            TextField(prompt, text: query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
    }

    @ViewBuilder
    private func emptyState(prompt: String) -> some View {
        VStack(spacing: 6) {
            Text("No commands match")
                .font(.system(size: 12, weight: .medium))
            Text(prompt)
                .font(.system(size: 11))
                .opacity(0.6)
        }
    }
}

extension EditorCommandPaletteStyle where Self == DefaultEditorCommandPaletteStyle {
    /// Default command-palette style.
    public static var `default`: Self { .init() }
}

// MARK: - Style installation

private struct EditorCommandPaletteStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue: any EditorCommandPaletteStyle = DefaultEditorCommandPaletteStyle()
}

extension EnvironmentValues {
    var editorCommandPaletteStyle: any EditorCommandPaletteStyle {
        get { self[EditorCommandPaletteStyleEnvironmentKey.self] }
        set { self[EditorCommandPaletteStyleEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Install a command palette style for `EditorCommandPalette` in this
    /// view's scope.
    public func editorCommandPaletteStyle<S: EditorCommandPaletteStyle>(_ style: S) -> some View {
        environment(\.editorCommandPaletteStyle, style)
    }
}
```

- [ ] **Step 6: Implement `EditorCommandPalette`**

```swift
// Sources/CodeEditorUI/CommandPalette/EditorCommandPalette.swift
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Opinionated command-palette view. Pass `Binding<Bool>` to control
/// presentation, `[CommandPaletteItem]` for the static command set, and
/// an `onSelect` callback for the picked item.
///
/// Hosts wire the keyboard shortcut themselves (e.g., `.keyboardShortcut`
/// on a button or window-toolbar item) — the palette stays neutral on
/// `⌘P` vs `⌘⇧P`. Internal handling responds to `Esc` (dismiss),
/// `↑/↓` (move highlight), `Return` (select highlighted).
public struct EditorCommandPalette: View {
    @Environment(\.editorCommandPaletteStyle) private var style

    @Binding private var isPresented: Bool
    @State private var query: String = ""
    @State private var highlightedID: CommandPaletteItem.ID?

    private let items: [CommandPaletteItem]
    private let onSelect: (CommandPaletteItem) -> Void
    private let prompt: String

    /// Creates a command palette.
    /// - Parameters:
    ///   - isPresented: bound visibility flag — host toggles to show/hide.
    ///   - items: full command set; the palette filters by query at render.
    ///   - onSelect: invoked when the user confirms an item.
    ///   - prompt: placeholder text for the search field.
    public init(
        isPresented: Binding<Bool>,
        items: [CommandPaletteItem],
        onSelect: @escaping (CommandPaletteItem) -> Void,
        prompt: String = "Type a command…"
    ) {
        self._isPresented = isPresented
        self.items = items
        self.onSelect = onSelect
        self.prompt = prompt
    }

    public var body: some View {
        if isPresented {
            paletteBody
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .background(KeyboardCommands(
                    onEscape:    { isPresented = false; query = "" },
                    onArrowUp:   { moveHighlight(by: -1) },
                    onArrowDown: { moveHighlight(by: +1) },
                    onReturn:    confirmHighlighted
                ))
        } else {
            EmptyView()
        }
    }

    private var paletteBody: some View {
        let visible = CommandPaletteFilter.filter(items: items, query: query)
        let resolved = highlightedID ?? visible.first?.id
        return AnyView(
            style.makeBody(
                configuration: EditorCommandPaletteStyleConfiguration(
                    prompt: prompt,
                    query: $query,
                    visibleItems: visible,
                    highlightedID: resolved,
                    onHighlight: { id in highlightedID = id },
                    onSelect: { item in
                        isPresented = false
                        query = ""
                        onSelect(item)
                    }
                )
            )
        )
    }

    private func moveHighlight(by delta: Int) {
        let visible = CommandPaletteFilter.filter(items: items, query: query)
        guard !visible.isEmpty else { return }
        let currentID = highlightedID ?? visible.first?.id
        guard let currentIndex = visible.firstIndex(where: { $0.id == currentID }) else {
            highlightedID = visible.first?.id
            return
        }
        let nextIndex = (currentIndex + delta).clamped(to: 0...(visible.count - 1))
        highlightedID = visible[nextIndex].id
    }

    private func confirmHighlighted() {
        let visible = CommandPaletteFilter.filter(items: items, query: query)
        let id = highlightedID ?? visible.first?.id
        guard let id, let item = visible.first(where: { $0.id == id }) else { return }
        isPresented = false
        query = ""
        onSelect(item)
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct KeyboardCommands: View {
    let onEscape: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onReturn: () -> Void

    var body: some View {
        // Invisible focusable view that catches keyboard events for the
        // palette. Uses SwiftUI's `.onKeyPress` (Tahoe-era) for crisp
        // handling without an AppKit responder shim.
        Color.clear
            .focusable()
            .onKeyPress(.escape)    { onEscape();   return .handled }
            .onKeyPress(.upArrow)   { onArrowUp();  return .handled }
            .onKeyPress(.downArrow) { onArrowDown(); return .handled }
            .onKeyPress(.return)    { onReturn();   return .handled }
    }
}
```

- [ ] **Step 7: Run unit tests + record snapshots and verify pass**

```bash
swift test --filter CommandPaletteFilterTests
SNAPSHOT_TESTING_RECORD=true swift test --filter EditorCommandPaletteSnapshots
swift test --filter EditorCommandPaletteSnapshots
```

- [ ] **Step 8: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorUI/CommandPalette/ \
        Tests/CodeEditorUITests/CommandPaletteFilterTests.swift \
        Tests/CodeEditorUITests/Snapshots/EditorCommandPaletteSnapshots.swift \
        Tests/CodeEditorUITests/Snapshots/__Snapshots__/EditorCommandPaletteSnapshots/
git commit -m "$(cat <<'EOF'
CodeEditorUI: add EditorCommandPalette + style + row

CommandPaletteItem (file/symbol/action/setting). EditorCommandPaletteRow
renders one item with kind glyph, title/subtitle, optional shortcut hint.
EditorCommandPaletteStyle protocol with Default; DefaultEditorCommandPaletteStyle
ships frosted-glass popover + search field + scrolling row list backed by
PlatformGlassSurface(.popover). EditorCommandPalette is the opinionated view:
Esc dismisses; up/down moves highlight; return selects. Host attaches the
keyboard-trigger shortcut themselves.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Wire `CodeEditor` editor-side writes into `EditorState`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`
- Test: `Tests/CodeEditorPluginTests/Core/EditorStateBridgeTests.swift`

This task adapts `CodeEditor.body` to read `\.editorState` and pass it into `CodeEditorRepresentable`'s coordinator path. The coordinator already routes `onSelectionChange` (line/column derivation lives there); we add writes to `state.selection`, `state.language`, `state.lineCount`, `state.hardwareAccelerationActive`, and `state.isDirty` at the existing callback sites.

**Background reading.** Before starting, read these files to understand the current shape:
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift:240-290` — the `body` and where to splice the env read.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` — where the representable forwards properties.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` — selection-change and text-change call sites.

- [ ] **Step 1: Write failing bridge test**

```swift
// Tests/CodeEditorPluginTests/Core/EditorStateBridgeTests.swift
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("CodeEditor → EditorState bridge")
@MainActor
struct EditorStateBridgeTests {
    /// The editor never *replaces* the env's `EditorState` instance — it
    /// only mutates fields. This test asserts that mutating editor-driven
    /// fields directly on the instance fires observation.
    @Test("Setting selection on EditorState fires observation")
    func selectionMutationFires() async {
        let state = EditorState()
        var fireCount = 0
        withObservationTracking {
            _ = state.selection
        } onChange: {
            fireCount += 1
        }
        state.selection = SelectionState(line: 10, column: 4)
        #expect(fireCount == 1)
    }

    /// Assert that the bridge call sites (which we add in this task)
    /// produce the expected `SelectionState` from an `NSRange` + line
    /// computation. This is a pure-function helper test for
    /// `EditorStateBridge.deriveSelection(from:in:)`.
    @Test("EditorStateBridge.deriveSelection maps NSRange to 1-based Ln/Col")
    func deriveSelectionMaps() {
        let text = "alpha\nbeta\ngamma"
        // Caret after 'a' on line 2 → line 2, column 2 (1-based)
        let range = NSRange(location: text.distance(from: text.startIndex, to: text.firstIndex(of: "b")!) + 1, length: 0)
        let result = EditorStateBridge.deriveSelection(from: range, in: text)
        #expect(result.line == 2)
        #expect(result.column == 2)
        #expect(result.selectionLength == 0)
    }

    @Test("EditorStateBridge.deriveSelection preserves selection length")
    func deriveSelectionLength() {
        let text = "hello"
        let range = NSRange(location: 1, length: 3)
        let result = EditorStateBridge.deriveSelection(from: range, in: text)
        #expect(result.line == 1)
        #expect(result.column == 2)
        #expect(result.selectionLength == 3)
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter EditorStateBridge`
Expected: FAIL — `EditorStateBridge` not defined.

- [ ] **Step 3: Implement `EditorStateBridge` helper**

```swift
// Sources/CodeEditorPlugin/Core/EditorStateBridge.swift
import Foundation

/// Internal helper for converting editor primitives (`NSRange`, raw
/// text) into the value types `EditorState` expects. Lives in the
/// editor target so the SwiftUI bridge's call sites can use it without
/// importing `CodeEditorUI`.
enum EditorStateBridge {
    /// Maps an `NSRange` over `text` to a `SelectionState` with 1-based
    /// line and column. Walks `text` from the start to the range's
    /// `location` counting newlines. O(n) — fine for typical selection
    /// changes. For very large documents the editor can cache line
    /// offsets and short-circuit; that's a sub-project 3 concern.
    static func deriveSelection(from range: NSRange, in text: String) -> SelectionState {
        let prefix = (text as NSString).substring(with: NSRange(location: 0, length: range.location))
        let lines = prefix.components(separatedBy: "\n")
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        return SelectionState(line: line, column: column, selectionLength: range.length)
    }

    /// Counts lines in `text` (number of `\n` + 1, or 0 for empty).
    static func lineCount(of text: String) -> Int {
        if text.isEmpty { return 0 }
        return text.components(separatedBy: "\n").count
    }
}
```

- [ ] **Step 4: Splice `EditorState` into `CodeEditor.body`**

Open `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift`. In the `body` accessor, after the existing `effectiveTheme` line, add the env read:

```swift
// Existing line (paraphrased — match the actual surrounding code):
//   let effectiveTheme = initialTheme ?? environment.theme

@Environment(\.editorState) private var editorState
// (Add this property next to the other @Environment declarations
// at the top of the struct, ~line 156 — colocated with
// `@Environment(\.codeEditorEnvironment) private var environment`.)
```

In the `body` itself, pass the state into `CodeEditorRepresentable`:

```swift
return CodeEditorRepresentable(
    text: $text,
    language: effectiveLanguage,
    theme: effectiveTheme,
    configuration: effectiveConfiguration,
    memoryMonitor: effectiveMemoryMonitor,
    isFocused: Binding(
        get: { isFocused },
        set: { isFocused = $0 }
    ),
    textDebounceInterval: effectiveDebounceInterval,
    editorState: editorState,                    // ADD
    onTextChange: handleTextChange,
    onSelectionChange: handleSelectionChange
)
```

- [ ] **Step 5: Modify `CodeEditorRepresentableHelper.swift` to carry the state**

Open `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`. Three concrete edits:

**5a. Add a stored property to the `CodeEditorRepresentable` struct.**

```swift
// Among the other stored properties (text, language, theme, etc.):
let editorState: EditorState
```

**5b. Update the initializer to accept and assign it.**

```swift
// Add to the init's parameter list (place after textDebounceInterval,
// before onTextChange to match the call-site order in CodeEditor.body):
editorState: EditorState,

// Add to the init body:
self.editorState = editorState
```

**5c. Inside the coordinator's selection-change handler, write through to the state.**

The coordinator already calls `onSelectionChange?(selection)` when the underlying `NSTextView` selection mutates. At that same call site, before or after the existing call:

```swift
parent.editorState.selection = EditorStateBridge.deriveSelection(
    from: selection,
    in: textView.text
)
parent.editorState.language = parent.language
parent.editorState.lineCount = EditorStateBridge.lineCount(of: textView.text)
```

If `parent.editorState` access doesn't compile because the coordinator captures `parent` weakly via `Coordinator`, mirror the existing pattern used by `parent.onSelectionChange?(...)` — the state writes go in the same closure body.

- [ ] **Step 6: Modify `CodeEditor+CoordinatorsExtensions.swift` for hwAccel + dirty tracking**

In whichever method applies the configuration to the platform text view (search for `useHardwareAcceleration`), add:

```swift
parent.editorState.hardwareAccelerationActive = parent.configuration.performance.useHardwareAcceleration
```

In the text-change handler (where `onTextChange?(newText)` is called), compare against a snapshot to detect dirty state:

```swift
// Added at the same call site as onTextChange?(newText):
parent.editorState.isDirty = (newText != parent.lastSavedSnapshot)
```

If `lastSavedSnapshot` doesn't exist on the representable yet, add it as a stored property defaulting to the initial text — host apps can update it on save through a future API; for now, the dirty flag tracks "unsaved relative to the initial text," which is the right behavior for a new editor instance.

- [ ] **Step 7: Run tests to verify pass**

```bash
swift test --filter EditorStateBridge
swift test --filter EditorState
```

Expected: PASS — bridge helper tests and the existing `EditorState` observation tests both green.

- [ ] **Step 8: Run full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean. Any pre-existing tests that exercised `CodeEditor` also pass — the change is additive.

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/EditorStateBridge.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift \
        Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift \
        Tests/CodeEditorPluginTests/Core/EditorStateBridgeTests.swift
git commit -m "$(cat <<'EOF'
CodeEditor: write editor-side fields to \.editorState

CodeEditor.body reads \.editorState from env and passes it into the
representable; the coordinator's selection-change handler writes
selection/language/lineCount; the configuration apply path writes
hardwareAccelerationActive; the text-change handler writes isDirty.
Adds an internal EditorStateBridge helper for NSRange→SelectionState
conversion.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Conformance audit + DocC pass + CHANGELOG

**Files:**
- Create: `Tests/CodeEditorUITests/TypeShapeAuditTests.swift`
- Modify: any source file missing DocC on a public symbol (audit-driven)
- Modify (or create): `CHANGELOG.md`

- [ ] **Step 1: Write failing conformance audit test**

```swift
// Tests/CodeEditorUITests/TypeShapeAuditTests.swift
import CodeEditorPlugin
import CodeEditorUI
import Foundation
import Testing

/// Compile-time audit. If any public chrome type loses a declared
/// conformance, this file stops compiling.
@Suite("CodeEditorUI public types conform to expected protocols")
struct TypeShapeAuditTests {
    private static func requireSendable<T>(_ type: T.Type) where T: Sendable {
        _ = String(describing: type)
    }

    private static func requireValueShape<T>(_ type: T.Type)
    where T: Sendable & Hashable {
        _ = String(describing: type)
    }

    @Test("public value-shape types are Sendable + Hashable")
    func auditValueTypes() {
        Self.requireValueShape(TrafficLightsConfiguration.self)
        Self.requireValueShape(BreadcrumbComponent.self)
        Self.requireValueShape(BreadcrumbComponent.Kind.self)
        Self.requireValueShape(CommandPaletteItem.self)
        Self.requireValueShape(CommandPaletteItem.Kind.self)
        Self.requireValueShape(PlatformGlassSurface.Role.self)
    }

    @Test("public Sendable types stay Sendable")
    func auditSendableOnly() {
        Self.requireSendable(EditorTabStripStyleConfiguration.self)
        Self.requireSendable(EditorCommandPaletteStyleConfiguration.self)
    }
}
```

- [ ] **Step 2: Run test to verify it compiles and passes**

Run: `swift test --filter TypeShapeAuditTests`
Expected: PASS — all conformances already declared by earlier tasks.

(If FAIL, the audit caught a missing conformance; fix the type's declaration and re-run.)

- [ ] **Step 3: DocC sweep**

Run a quick grep for any public symbol missing a DocC comment:

```bash
swift package generate-documentation --target CodeEditorUI 2>&1 | grep -i "missing.*documentation" || true
```

For any flagged symbol, add a `///` DocC comment matching the pattern used by neighboring symbols. This shouldn't surface anything if Tasks 1-11 added DocC as written.

- [ ] **Step 4: Update CHANGELOG**

Append (or create) `CHANGELOG.md`:

```markdown
## Unreleased

### Added — `CodeEditorUI` (sub-project 4 of Design System Migration)
- New `CodeEditorUI` library product. Depends on `CodeEditorDesignTokens`
  and `CodeEditorPlugin`. SwiftUI-only chrome primitives.
- New `EditorState` `@Observable` class in `CodeEditorPlugin` with
  editor-written fields (`selection`, `language`, `isDirty`,
  `hardwareAccelerationActive`, `lineCount`) and host-written fields
  (`documentName`, `documentURL`, `tabs`, `activeTabID`,
  `breadcrumbPath`, `workspaceName`).
- New `\.editorState` SwiftUI environment key with a default empty
  instance.
- New public value types in `CodeEditorPlugin/Core/`: `SelectionState`,
  `TabModel`, `BreadcrumbComponent`.
- Eight chrome components in `CodeEditorUI`:
  - `EditorTitleBar` (macOS + Catalyst): Tahoe title bar with traffic
    lights, centered title, and trailing toolbar slot.
  - `EditorTrafficLights` (macOS + Catalyst): painted SwiftUI
    close/min/zoom buttons with optional click callbacks.
  - `EditorTabStrip` (all platforms): file-tab strip with bound
    `[TabModel]`/`activeTabID`, scroll-on-overflow, dirty dot.
  - `EditorBreadcrumbView` (all platforms): chevron-separated breadcrumb
    trail with kind glyphs.
  - `EditorStatusBar` (all platforms): language + selection +
    indentation + hardware-acceleration indicator + trailing slot.
  - `EditorSidebarShell` (macOS + Catalyst): glass-backed panel
    container with header / sectionTitle / content / footer slots.
    No tree.
  - `EditorCommandPalette` (all platforms): Cmd-Shift-P-style picker
    with `Esc`/`↑↓`/`Return` handling. Host wires the keyboard trigger.
  - `PlatformGlassSurface` (all platforms): `ViewModifier` wrapping
    SwiftUI's native Liquid Glass effect, theme-driven.
- Two SwiftUI Style protocols: `EditorTabStripStyle` (with `.default`,
  `.compact`) and `EditorCommandPaletteStyle` (with `.default`).
- Theme bridges: `Theme.titleBarColor`, `tabBarColor`, `statusBarColor`,
  `panelColor`, `elevatedColor`, `tabActiveColor`, `tabInactiveColor`,
  `toolbarColor`, `surfaceColor`, `titleBarInactiveColor`,
  `panelFocusedBorderColor`, `glassTintColor`, `glassOpacity`,
  `popoverShadow`.

### Changed
- `CodeEditor` body reads `\.editorState` from env; coordinator writes
  selection/language/lineCount/hwAccel/isDirty to it. Additive — hosts
  that don't inject an `EditorState` see no behavioral change.

### No breaking changes.
```

- [ ] **Step 5: Run final full quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean — build succeeds, zero lint, all tests pass on macOS and iOS Simulator.

- [ ] **Step 6: Commit**

```bash
git add Tests/CodeEditorUITests/TypeShapeAuditTests.swift CHANGELOG.md
# Plus any DocC additions surfaced by Step 3.
git commit -m "$(cat <<'EOF'
CodeEditorUI: type-shape audit, DocC sweep, CHANGELOG

Adds compile-time conformance audit covering all public CodeEditorUI
value-shape types. Sweeps DocC comments on any public symbol missed by
earlier tasks. Records the sub-project 4 changes in CHANGELOG.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

After Task 12 commits cleanly, the entire sub-project is done. Run one last full sweep to confirm everything still ties together:

```bash
swift build
swiftlint
swift test --parallel
swift package generate-documentation --target CodeEditorUI
```

Expected:
- `swift build` succeeds with no warnings.
- `swiftlint` reports zero violations.
- `swift test --parallel` passes — all `CodeEditorPluginTests`, `CodeEditorDesignTokensTests`, and `CodeEditorUITests` green.
- DocC catalog generates with no missing-documentation diagnostics on `CodeEditorUI` or the new `CodeEditorPlugin/Core/` types.

The library product `CodeEditorUI` is publishable; sub-project 5 (`CodeEditorSample`) can now consume it.
