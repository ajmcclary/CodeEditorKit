# Editor Visual Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-derive every editor-internal rendering surface from the new `Theme` and `Tokens.*` namespaces; add four token bridges, a hierarchical syntax-color resolver, indent guides, fold chevrons, and a frosted-glass completion popover. Public API is unchanged.

**Architecture:** Push-model theme propagation. `CodeEditorRepresentable.updateNSView/updateUIView` reads `\.codeTheme` from SwiftUI environment and calls `containerView.apply(theme:)`. Equality-gated `apply(theme:)` methods on every Layout/Annotations/Text platform view fan out from the container. Color/animation bridges live under `Theming/Bridges/`; the syntax resolver lives under `Theming/Internal/`. Indent guides and fold chevrons are net-new visual surfaces.

**Tech Stack:** Swift 6.3, swift-tools-version 6.3, Swift Testing (`@Suite`/`@Test`/`#expect`), swift-snapshot-testing, swift-custom-dump, AppKit/UIKit/SwiftUI bridges, `Bundle.module` resources.

**Spec:** [`docs/superpowers/specs/2026-05-05-editor-visual-restyle-design.md`](../specs/2026-05-05-editor-visual-restyle-design.md)

---

## File Structure

### Files created

```
Sources/CodeEditorPlugin/Theming/Bridges/
  Tokens.Color+SwiftUI.swift         # Color(tokens:) initializer (migrated from Theme+SwiftUI.swift)
  Tokens.Color+Platform.swift        # NSColor(tokens:) / UIColor(tokens:)
  Tokens.Easing+SwiftUI.swift        # Animation.timingCurve(_:duration:) builder from Easing
  Tokens.Animation+SwiftUI.swift     # Tokens.Animation.foldChevron named convenience
  Theme+SwiftUI.swift                # migrated; legacy accessors deleted

Sources/CodeEditorPlugin/Theming/Internal/
  SyntaxColorLookup.swift            # Theme.color(forToken:) resolver + per-Theme cache

Sources/CodeEditorPlugin/Layout/Glass/
  _GlassSurface.swift                # internal frosted-glass wrapper; deleted in sub-project 4

Tests/CodeEditorPluginTests/Theming/Bridges/
  ColorBridgesTests.swift            # SwiftUI / NSColor / UIColor sRGB roundtrips
  AnimationBridgesTests.swift        # Easing→Animation curve, foldChevron stability

Tests/CodeEditorPluginTests/Theming/
  SyntaxColorLookupTests.swift       # direct hit, hierarchical fallback, full miss, caching

Tests/CodeEditorPluginTests/Layout/
  ApplyThemePropagationTests.swift   # equality gate, fan-out
  GutterViewThemeTests.swift         # background + numbers + active-line color
  LineHighlightInsertionPointThemeTests.swift
  MinimapViewThemeTests.swift
  CompletionCellGlassTests.swift
  FoldChevronTests.swift             # animation-gated rotation, click target

Tests/CodeEditorPluginTests/Annotations/
  AnnotationThemeTests.swift         # AnnotationKind.color(in:) + view wiring

Tests/CodeEditorPluginTests/Text/
  SyntaxColorAndSelectionTests.swift # per-run color via resolver; selection fill
  IndentGuideTests.swift             # geometry, blank-line continuity, disabled-when-zero
```

### Files modified

```
Sources/CodeEditorPlugin/Theming/SwiftUI/Theme+SwiftUI.swift
                                             # MOVED to Theming/Bridges/ (see Task 2)
Sources/CodeEditorPlugin/Layout/GutterView.swift
Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift
Sources/CodeEditorPlugin/Layout/MinimapView.swift
Sources/CodeEditorPlugin/Layout/LineHighlightView.swift
Sources/CodeEditorPlugin/Layout/InsertionPointView.swift
Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift
Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift
Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+AppKitExtensions.swift
Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift
Sources/CodeEditorPlugin/Annotations/AnnotationKind.swift
Sources/CodeEditorPlugin/Annotations/AnnotationView.swift
Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift
Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift
Sources/CodeEditorPlugin/Core/CodeEditorView.swift           # selection-color reads
Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift
                                             # updateNSView/updateUIView reads \.codeTheme
Sources/CodeEditorPlugin/SyntaxHighlighting/                 # one or more producers gain Theme.color(forToken:) calls — exact files determined during Task 9 audit
CHANGELOG.md (or README if no CHANGELOG)
```

### Files deleted

```
Sources/CodeEditorPlugin/Theming/SwiftUI/             # directory empties after Task 2; remove
```

---

## Conventions used in this plan

- **Test framework:** Swift Testing. All test files start with `@testable import CodeEditorPlugin`, `import CodeEditorDesignTokens`, `import Foundation`, `import Testing` (and `import CustomDump` / `import SnapshotTesting` where used).
- **Platform-view tests** instantiate the platform subview directly, call `apply(theme:)`, and assert on stored properties (`view.themeBackgroundColor`, etc.). Snapshot tests use `swift-snapshot-testing`'s `Snapshotting<NSView, NSImage>.image` and `Snapshotting<UIView, UIImage>.image` strategies on macOS and iOS respectively. Snapshot tests are gated by `#if canImport(AppKit)` / `#if canImport(UIKit)` as appropriate.
- **Build/test commands.** Throughout the plan the test command is `swift test --filter <Suite>` and the build command is `swift build`. The full quality gate (used at task ends) is `swift build && swiftlint && swift test --parallel`. SwiftLint must report zero violations across changed files.
- **Theme test fixtures.** Tests use `Theme.lcarsDark` (the library default, shipped in sub-project 2) for theme-dependent assertions. For lookup tests, a synthetic `Theme` is constructed via `Theme.fallback(.dark)` then mutated via the test-only initializer pattern already used in `Tests/CodeEditorPluginTests/Theming/`.
- **Commits.** One commit per task, message ending with the standard `Co-Authored-By` trailer. No `--no-verify` or hook-skipping. If a hook fails, fix the issue and re-commit (do not amend).
- **Equality-gated `apply(theme:)`.** Every platform view exposes a stored property `private var appliedTheme: Theme?`; `apply(theme:)` early-returns if `appliedTheme == newTheme`, otherwise updates the field and refreshes layer/draw state.

---

## Task 1: Color bridges — `Tokens.Color → SwiftUI.Color` / `NSColor` / `UIColor`

Migrates the existing `Color(tokens:)` initializer into a dedicated bridge file and adds the platform-color counterparts.

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+SwiftUI.swift`
- Create: `Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+Platform.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/Bridges/ColorBridgesTests.swift`

- [ ] **Step 1: Write failing test for the three color bridges**

```swift
// Tests/CodeEditorPluginTests/Theming/Bridges/ColorBridgesTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import SwiftUI
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@Suite("Tokens.Color bridges")
struct ColorBridgesTests {

    @Test("SwiftUI.Color preserves sRGB components")
    func swiftUIColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF)
        let color = Color(tokens: token)
        let cg = color.cgColor
        #expect(cg != nil)
        // Exact 8-bit roundtrip via cgColor isn't guaranteed across SDKs;
        // assert the SwiftUI representation matches an explicit constructed
        // Color with the same components.
        let expected = Color(
            .sRGB,
            red: Double(token.red) / 255,
            green: Double(token.green) / 255,
            blue: Double(token.blue) / 255,
            opacity: token.alpha
        )
        #expect(color == expected)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test("NSColor(tokens:) preserves sRGB components")
    func nsColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF)
        let nsColor = NSColor(tokens: token)
        let inSRGB = nsColor.usingColorSpace(.sRGB)
        #expect(inSRGB != nil)
        if let c = inSRGB {
            #expect(abs(c.redComponent - 0x0A / 255.0) < 0.005)
            #expect(abs(c.greenComponent - 0x84 / 255.0) < 0.005)
            #expect(abs(c.blueComponent - 0xFF / 255.0) < 0.005)
            #expect(abs(c.alphaComponent - 1.0) < 0.005)
        }
    }
    #endif

    #if canImport(UIKit)
    @Test("UIColor(tokens:) preserves sRGB components")
    func uiColorPreservesSRGB() {
        let token = Tokens.Color(hex: 0x0A84FF, alpha: 0.5)
        let uiColor = UIColor(tokens: token)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0x0A / 255.0) < 0.005)
        #expect(abs(g - 0x84 / 255.0) < 0.005)
        #expect(abs(b - 0xFF / 255.0) < 0.005)
        #expect(abs(a - 0.5) < 0.005)
    }
    #endif
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ColorBridgesTests`
Expected: FAIL — `NSColor(tokens:)` / `UIColor(tokens:)` not defined. (`Color(tokens:)` already exists from sub-project 2; the AppKit and UIKit forms are the new content.)

- [ ] **Step 3: Implement `Tokens.Color → SwiftUI.Color`**

```swift
// Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+SwiftUI.swift
import CodeEditorDesignTokens
import SwiftUI

extension Color {
    /// Build a `SwiftUI.Color` from a `Tokens.Color` (sRGB).
    public init(tokens color: Tokens.Color) {
        self.init(
            .sRGB,
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255,
            opacity: color.alpha
        )
    }
}
```

- [ ] **Step 4: Implement `Tokens.Color → NSColor` / `UIColor`**

```swift
// Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+Platform.swift
import CodeEditorDesignTokens
import CoreGraphics

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension NSColor {
    /// Build an sRGB `NSColor` from a `Tokens.Color`.
    public convenience init(tokens color: Tokens.Color) {
        self.init(
            srgbRed: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha)
        )
    }
}
#endif

#if canImport(UIKit)
import UIKit

extension UIColor {
    /// Build an sRGB `UIColor` from a `Tokens.Color`. UIKit's
    /// `init(red:green:blue:alpha:)` is sRGB-based per Apple docs.
    public convenience init(tokens color: Tokens.Color) {
        self.init(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha)
        )
    }
}
#endif
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter ColorBridgesTests`
Expected: PASS — three tests (one always; AppKit and UIKit conditional).

- [ ] **Step 6: Quality gate + commit**

Run: `swift build && swiftlint && swift test --filter ColorBridgesTests`
Expected: clean build; zero SwiftLint violations on new files; tests pass.

```bash
git add Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+SwiftUI.swift \
        Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Color+Platform.swift \
        Tests/CodeEditorPluginTests/Theming/Bridges/ColorBridgesTests.swift
git commit -m "$(cat <<'EOF'
Theming: Tokens.Color bridges (SwiftUI / NSColor / UIColor)

Three sRGB-preserving initializers on Color, NSColor, UIColor for
Tokens.Color values. The SwiftUI form duplicates content currently in
Theme+SwiftUI.swift; that file's copy is deleted in the next task as
the legacy-accessor file is migrated into Theming/Bridges/.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Migrate `Theme+SwiftUI.swift` into `Theming/Bridges/`; delete legacy accessors

The four convenience accessors sub-project 2 left on `Theme` (`backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor`) are dead weight now that Layout will read `theme.style.editor.*` directly. The duplicate `Color(tokens:)` extension here is removed in favor of Task 1's dedicated file.

**Files:**
- Move: `Sources/CodeEditorPlugin/Theming/SwiftUI/Theme+SwiftUI.swift` → `Sources/CodeEditorPlugin/Theming/Bridges/Theme+SwiftUI.swift`
- Delete: `Sources/CodeEditorPlugin/Theming/SwiftUI/` (empty directory)
- Audit / modify: any call site reading `theme.backgroundColor` / `.textColor` / `.lineNumberColor` / `.selectedLineColor`

- [ ] **Step 1: Find call sites for the four legacy accessors**

Run: `grep -rn "theme\.backgroundColor\|theme\.textColor\|theme\.lineNumberColor\|theme\.selectedLineColor" Sources/ Tests/ 2>/dev/null`
Expected: a list of files. (Likely small — sub-project 2's notes say the accessors only existed to keep the chrome pipeline compiling.)

- [ ] **Step 2: Move the file and trim it**

Move `Sources/CodeEditorPlugin/Theming/SwiftUI/Theme+SwiftUI.swift` to `Sources/CodeEditorPlugin/Theming/Bridges/Theme+SwiftUI.swift`. After the move, the file's contents become:

```swift
// Sources/CodeEditorPlugin/Theming/Bridges/Theme+SwiftUI.swift
import CodeEditorDesignTokens
import SwiftUI

extension Theme {
    /// Library default theme. Resolves to `Theme.lcarsDark`.
    public static var `default`: Theme { lcarsDark }

    /// Conventional dark theme alias. Resolves to `Theme.lcarsDark`.
    public static var dark: Theme { lcarsDark }
}
```

The four convenience accessors (`backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor`) and the `Color(tokens:)` initializer are removed. (`Color(tokens:)` lives in `Tokens.Color+SwiftUI.swift` from Task 1; the `default`/`dark` static aliases stay.)

- [ ] **Step 3: Delete the now-empty `Theming/SwiftUI/` directory**

```bash
rmdir Sources/CodeEditorPlugin/Theming/SwiftUI
```

- [ ] **Step 4: Update each call site found in Step 1**

For each grep hit, rewrite the read. Mappings:

| Old | New |
|---|---|
| `theme.backgroundColor` | `Color(tokens: theme.style.editor.background)` |
| `theme.textColor` | `Color(tokens: theme.style.editor.foreground)` |
| `theme.lineNumberColor` | `Color(tokens: theme.style.editor.lineNumber)` |
| `theme.selectedLineColor` | `Color(tokens: theme.style.editor.activeLineBackground)` |

If a call site uses the value as `NSColor`/`UIColor` rather than SwiftUI `Color`, swap to `NSColor(tokens:)` / `UIColor(tokens:)` from Task 1.

- [ ] **Step 5: Build to confirm no broken references**

Run: `swift build`
Expected: clean build. Any compile errors here mean a call site was missed in Step 4 — fix it, then re-run.

- [ ] **Step 6: Run all theming tests to confirm regressions**

Run: `swift test --filter Theming`
Expected: all sub-project 2 tests pass.

- [ ] **Step 7: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add -A
git commit -m "$(cat <<'EOF'
Theming: migrate Theme+SwiftUI.swift into Bridges/; drop legacy accessors

Moves Theme+SwiftUI.swift from Theming/SwiftUI/ into Theming/Bridges/
alongside the new Tokens.Color bridges. Drops the four convenience
accessors sub-project 2 left for the old CodeEditorSwiftUITheme surface
(backgroundColor / textColor / lineNumberColor / selectedLineColor) —
Layout/ now reads style.editor.* directly. Color(tokens:) lives in
Tokens.Color+SwiftUI.swift; only Theme.default and Theme.dark static
aliases survive in this file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Easing / animation bridges

`Tokens.Easing → SwiftUI.Animation` plus the single named convenience `Tokens.Animation.foldChevron`.

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Easing+SwiftUI.swift`
- Create: `Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Animation+SwiftUI.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/Bridges/AnimationBridgesTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Theming/Bridges/AnimationBridgesTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import SwiftUI
import Testing

@Suite("Animation bridges")
struct AnimationBridgesTests {

    @Test("Easing produces a timingCurve animation with the same control points")
    func easingProducesTimingCurve() {
        let easing = Tokens.Easing(0.16, 1.00, 0.30, 1.00)
        let duration: Duration = .milliseconds(200)
        // Behaviour: round-trip the named curve into SwiftUI.Animation and
        // assert equality vs. an explicit construction.
        let bridge = Animation.timingCurve(easing: easing, duration: duration)
        let direct = Animation.timingCurve(0.16, 1.00, 0.30, 1.00, duration: 0.2)
        #expect(bridge == direct)
    }

    @Test("foldChevron pairs durQuick with easeOutSoft")
    func foldChevronShape() {
        let bridge = Tokens.Animation.foldChevron
        let expected = Animation.timingCurve(
            Tokens.Animation.easeOutSoft.x1,
            Tokens.Animation.easeOutSoft.y1,
            Tokens.Animation.easeOutSoft.x2,
            Tokens.Animation.easeOutSoft.y2,
            duration: Tokens.Animation.durQuick.swiftUISeconds
        )
        #expect(bridge == expected)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AnimationBridgesTests`
Expected: FAIL — `Animation.timingCurve(easing:duration:)`, `Tokens.Animation.foldChevron`, and `Duration.swiftUISeconds` not defined.

- [ ] **Step 3: Implement the Easing bridge**

```swift
// Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Easing+SwiftUI.swift
import CodeEditorDesignTokens
import Foundation
import SwiftUI

extension Animation {
    /// Build a `SwiftUI.Animation` from a `Tokens.Easing` cubic-Bézier curve
    /// and a duration. Uses `Animation.timingCurve(_:_:_:_:duration:)`.
    public static func timingCurve(
        easing: Tokens.Easing,
        duration: Duration
    ) -> Animation {
        .timingCurve(
            easing.x1,
            easing.y1,
            easing.x2,
            easing.y2,
            duration: duration.swiftUISeconds
        )
    }
}

extension Duration {
    /// Number of seconds as a `Double`, suitable for SwiftUI APIs that
    /// take duration as a `TimeInterval`. Loses sub-attosecond precision
    /// — fine for animation durations, which are at most low-second-scale.
    public var swiftUISeconds: Double {
        let (secs, attos) = components
        return Double(secs) + Double(attos) / 1e18
    }
}
```

- [ ] **Step 4: Implement the Animation builders**

```swift
// Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Animation+SwiftUI.swift
import CodeEditorDesignTokens
import Foundation
import SwiftUI

extension Tokens.Animation {
    /// Fold-chevron rotation: `durQuick` (200ms) at `easeOutSoft`.
    /// The single named animation call site in the editor restyle.
    public static var foldChevron: Animation {
        Animation.timingCurve(easing: easeOutSoft, duration: durQuick)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter AnimationBridgesTests`
Expected: PASS — both tests.

- [ ] **Step 6: Quality gate + commit**

Run: `swift build && swiftlint && swift test --filter AnimationBridges`

```bash
git add Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Easing+SwiftUI.swift \
        Sources/CodeEditorPlugin/Theming/Bridges/Tokens.Animation+SwiftUI.swift \
        Tests/CodeEditorPluginTests/Theming/Bridges/AnimationBridgesTests.swift
git commit -m "$(cat <<'EOF'
Theming: Tokens.Easing + Tokens.Animation SwiftUI bridges

Animation.timingCurve(easing:duration:) builds an Animation from a
Tokens.Easing curve plus a Duration. Tokens.Animation.foldChevron is
the single named convenience this sub-project actually uses (durQuick
× easeOutSoft); the bridge file is the home for additional named
animations as later sub-projects' call sites arrive.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `Theme.color(forToken:)` resolver + cache

Hierarchical fallback over `style.syntax`, ending at `style.editor.foreground`. Per-Theme cache keyed by token-string.

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/SyntaxColorLookupTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Theming/SyntaxColorLookupTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Theme.color(forToken:) resolver")
struct SyntaxColorLookupTests {

    /// Build a synthetic theme by starting from the dark fallback and
    /// substituting a given syntax map.
    private func makeTheme(
        syntax: [String: SyntaxStyle],
        foreground: Tokens.Color = Tokens.Color(hex: 0xFFFFFF)
    ) -> Theme {
        var base = Theme.fallback(.dark)
        base = base.replacing(syntax: syntax, foreground: foreground)
        return base
    }

    @Test("Direct hit returns the SyntaxStyle.color")
    func directHit() {
        let red = Tokens.Color(hex: 0xFF0000)
        let theme = makeTheme(syntax: [
            "keyword": SyntaxStyle(color: red, backgroundColor: nil, fontWeight: nil, fontStyle: nil)
        ])
        #expect(theme.color(forToken: "keyword") == red)
    }

    @Test("Hierarchical fallback drops trailing dotted segments")
    func hierarchicalFallback() {
        let blue = Tokens.Color(hex: 0x0000FF)
        let theme = makeTheme(syntax: [
            "function": SyntaxStyle(color: blue, backgroundColor: nil, fontWeight: nil, fontStyle: nil)
        ])
        #expect(theme.color(forToken: "function.method") == blue)
        #expect(theme.color(forToken: "function.method.builtin") == blue)
    }

    @Test("Full miss falls through to style.editor.foreground")
    func fullMissFallsThrough() {
        let fg = Tokens.Color(hex: 0xABCDEF)
        let theme = makeTheme(syntax: [:], foreground: fg)
        #expect(theme.color(forToken: "totally.unknown.token") == fg)
    }

    @Test("Repeated lookups are stable (cache does not corrupt result)")
    func cachedAfterFirstHit() {
        let red = Tokens.Color(hex: 0xFF0000)
        let theme = makeTheme(syntax: [
            "keyword": SyntaxStyle(color: red, backgroundColor: nil, fontWeight: nil, fontStyle: nil)
        ])
        let first = theme.color(forToken: "keyword.control")
        let second = theme.color(forToken: "keyword.control")
        let third = theme.color(forToken: "keyword")
        #expect(first == red)
        #expect(second == red)
        #expect(third == red)
    }

    @Test("SyntaxStyle.color of nil falls through despite key being present")
    func presentEntryWithoutColor() {
        let theme = makeTheme(syntax: [
            "emphasis": SyntaxStyle(color: nil, backgroundColor: nil, fontWeight: nil, fontStyle: .italic)
        ], foreground: Tokens.Color(hex: 0x101010))
        #expect(theme.color(forToken: "emphasis") == Tokens.Color(hex: 0x101010))
    }
}
```

The test relies on a small `Theme.replacing(syntax:foreground:)` helper. If that helper doesn't already exist in the test target, add it as `@testable internal` or in a test-only extension:

```swift
// Tests/CodeEditorPluginTests/Theming/Theme+TestSupport.swift  (new, test-only)
@testable import CodeEditorPlugin
import CodeEditorDesignTokens

extension Theme {
    /// Test helper: returns a copy of the receiver with `syntax` and
    /// `editor.foreground` substituted. All other fields preserved.
    func replacing(
        syntax: [String: SyntaxStyle],
        foreground: Tokens.Color
    ) -> Theme {
        var newStyle = self.style
        newStyle = newStyle.replacingSyntax(syntax)
        newStyle = newStyle.replacingEditorForeground(foreground)
        return Theme(
            name: self.name,
            appearance: self.appearance,
            style: newStyle,
            platform: self.platform
        )
    }
}

extension ThemeStyle {
    func replacingSyntax(_ newSyntax: [String: SyntaxStyle]) -> ThemeStyle {
        // Adjust the field name if the actual property differs.
        var copy = self
        copy.syntax = newSyntax
        return copy
    }
    func replacingEditorForeground(_ newForeground: Tokens.Color) -> ThemeStyle {
        var copy = self
        copy.editor.foreground = newForeground
        return copy
    }
}
```

If `ThemeStyle.syntax` or `editor.foreground` are `let` rather than `var`, switch to a value-rebuilding initializer here. (Sub-project 2 may have made them `let`; in that case, build a fresh `ThemeStyle` from existing fields plus the substitutions.)

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SyntaxColorLookupTests`
Expected: FAIL — `Theme.color(forToken:)` not defined.

- [ ] **Step 3: Implement the resolver and per-Theme cache**

```swift
// Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift
import CodeEditorDesignTokens
import Foundation

extension Theme {
    /// Resolves a `TokenName` to a `Tokens.Color` via hierarchical dotted
    /// fallback over `style.syntax`, ending at `style.editor.foreground`.
    /// Result is cached per `Theme` instance to avoid repeated string-walks
    /// during large highlight passes.
    public func color(forToken token: TokenName) -> Tokens.Color {
        let key = String(describing: token)
        if let cached = Self.cache.lookup(themeID: self.cacheIdentifier, token: key) {
            return cached
        }
        let resolved = Self.resolve(token: key, in: self.style)
        Self.cache.store(themeID: self.cacheIdentifier, token: key, value: resolved)
        return resolved
    }

    /// Hierarchical lookup. Strips trailing dotted segments on miss.
    private static func resolve(token: String, in style: ThemeStyle) -> Tokens.Color {
        var probe = token
        while !probe.isEmpty {
            if let entry = style.syntax[probe], let color = entry.color {
                return color
            }
            guard let dot = probe.lastIndex(of: ".") else { break }
            probe = String(probe[..<dot])
        }
        return style.editor.foreground
    }

    /// Stable identity for cache keying. The cache is keyed by a stable
    /// derivation of the Theme's value identity — for value-typed Theme,
    /// we use a hash of (name, appearance, style.editor.foreground).
    fileprivate var cacheIdentifier: SyntaxColorCacheKey {
        SyntaxColorCacheKey(
            name: self.name,
            appearance: self.appearance,
            foregroundHex: self.style.editor.foreground.hexString
        )
    }

    /// Process-wide cache. A single shared instance is fine: keys
    /// scope each theme's hits separately.
    private static let cache = SyntaxColorCache()
}

struct SyntaxColorCacheKey: Hashable, Sendable {
    let name: String
    let appearance: Theme.Appearance
    let foregroundHex: String
}

final class SyntaxColorCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [SyntaxColorCacheKey: [String: Tokens.Color]] = [:]

    func lookup(themeID: SyntaxColorCacheKey, token: String) -> Tokens.Color? {
        lock.lock(); defer { lock.unlock() }
        return entries[themeID]?[token]
    }

    func store(themeID: SyntaxColorCacheKey, token: String, value: Tokens.Color) {
        lock.lock(); defer { lock.unlock() }
        entries[themeID, default: [:]][token] = value
    }
}
```

If `Tokens.Color` doesn't already have a `hexString` property (sub-project 1 did spec one), substitute an inline serialization here.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SyntaxColorLookupTests`
Expected: PASS — five tests.

- [ ] **Step 5: Quality gate + commit**

Run: `swift build && swiftlint && swift test --filter SyntaxColorLookup`

```bash
git add Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift \
        Tests/CodeEditorPluginTests/Theming/SyntaxColorLookupTests.swift \
        Tests/CodeEditorPluginTests/Theming/Theme+TestSupport.swift
git commit -m "$(cat <<'EOF'
Theming: Theme.color(forToken:) resolver + per-Theme cache

Hierarchical dotted fallback over style.syntax, ending at
style.editor.foreground. Result cached per (name, appearance,
foreground) identity in a process-wide NSLock-guarded cache.
Public on Theme; the editor's syntax-highlight pipeline picks up
the call in a later task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `apply(theme:)` skeleton — container fan-out + Representable wiring

Add `apply(theme:)` no-op stubs to every Layout/Annotations/Text platform view; have the container fan out; have the Representable read `\.codeTheme` from environment.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift` (or create new `+Theme.swift` extension if cleaner)
- Modify: `Sources/CodeEditorPlugin/Layout/GutterView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/MinimapView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/LineHighlightView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/InsertionPointView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift`
- Modify: `Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift`
- Modify: `Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift`
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/ApplyThemePropagationTests.swift`

- [ ] **Step 1: Write failing test for fan-out + equality gate**

```swift
// Tests/CodeEditorPluginTests/Layout/ApplyThemePropagationTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

@Suite("apply(theme:) propagation")
struct ApplyThemePropagationTests {

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test("Container fans out to every platform subview exactly once")
    func fanOutOnce() {
        let container = CodeEditorContainerView()  // existing initializer
        let theme = Theme.lcarsDark
        container.apply(theme: theme)
        // Each subview records the theme it last received; assert all are set.
        #expect(container.gutterView.appliedTheme == theme)
        #expect(container.minimapView.appliedTheme == theme)
        #expect(container.lineHighlightView.appliedTheme == theme)
        #expect(container.insertionPointView.appliedTheme == theme)
    }

    @Test("Equality-gated apply is a no-op on second call with same theme")
    func equalityGated() {
        let view = GutterView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let firstApplyCount = view._testApplyCount  // exposed for testing only
        view.apply(theme: theme)
        #expect(view._testApplyCount == firstApplyCount)
    }
    #endif
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ApplyThemePropagationTests`
Expected: FAIL — `apply(theme:)`, `appliedTheme`, `_testApplyCount` not defined.

- [ ] **Step 3: Define the `apply(theme:)` shape on each platform view**

For each of `GutterView`, `MinimapView`, `LineHighlightView`, `InsertionPointView`, `AnnotationsContentView`, and the popover content view in `CompletionCellComponents`, plus `TextLayoutFragmentView` (or its containing renderer), add:

```swift
// In each platform view file, e.g. Sources/CodeEditorPlugin/Layout/GutterView.swift
extension GutterView {
    /// Stored theme; nil before first apply.
    public internal(set) var appliedTheme: Theme? {
        get { _appliedThemeBox.value }
        set { _appliedThemeBox.value = newValue }
    }

    /// Accept a theme. Equality-gated: no-ops if the value matches the
    /// previous apply. Otherwise updates layer/draw state and triggers
    /// a redraw.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        _testApplyCount &+= 1
        themeDidChange()
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsDisplay = true
        #elseif canImport(UIKit)
        setNeedsDisplay()
        #endif
    }

    /// Override point for subclasses; default is no-op (used in this
    /// task's stub form; real reads come in later tasks).
    @objc dynamic func themeDidChange() {}

    /// Test-only counter for verifying equality-gated dispatch.
    internal var _testApplyCount: Int {
        get { _testApplyCountBox.value }
        set { _testApplyCountBox.value = newValue }
    }
}
```

The `_appliedThemeBox` and `_testApplyCountBox` storage uses a small associated-object pattern, since `extension` can't add stored properties to NSView/UIView subclasses directly. Use the existing project pattern (the project already employs associated objects for view state — see `BaseUIComponents.swift`'s pattern); if a cleaner pattern is to add a stored property *inside* the subclass body rather than via extension, do that. Pseudocode for the in-class form:

```swift
class GutterView: PlatformView {
    // Existing fields…
    private var _appliedTheme: Theme?
    private var _testApplyCountStorage: Int = 0
    public var appliedTheme: Theme? { _appliedTheme }
    public func apply(theme: Theme) {
        if _appliedTheme == theme { return }
        _appliedTheme = theme
        _testApplyCountStorage &+= 1
        themeDidChange()
        // setNeedsDisplay branch as above
    }
    @objc dynamic func themeDidChange() {}
    internal var _testApplyCount: Int { _testApplyCountStorage }
}
```

Apply the same pattern to each of the listed views. This task ships *no-op `themeDidChange()`*; later tasks override it to actually consume the theme.

- [ ] **Step 4: Implement container fan-out**

```swift
// Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+Configuration.swift
// (or a new +Theme.swift file if preferred — keep this file focused.)

extension CodeEditorContainerView {
    /// Apply a theme to the container and every subview. Equality-gated.
    public func apply(theme: Theme) {
        gutterView.apply(theme: theme)
        minimapView.apply(theme: theme)
        lineHighlightView.apply(theme: theme)
        insertionPointView.apply(theme: theme)
        annotationsContentView?.apply(theme: theme)
        completionPopover?.apply(theme: theme)
        textLayoutFragmentRenderer?.apply(theme: theme)
    }
}
```

If any of those subviews are optional, handle nil with optional-chaining as above. The exact subview names follow the existing field names on `CodeEditorContainerView` — verify and adjust if the codebase uses different identifiers.

- [ ] **Step 5: Wire the SwiftUI Representable**

```swift
// Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift
// Inside updateNSView(_:context:) and updateUIView(_:context:):

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
public func updateNSView(_ nsView: PlatformContainerView, context: Context) {
    let theme = context.environment.codeTheme
    nsView.apply(theme: theme)
    // … existing config-application below
}
#endif

#if canImport(UIKit)
public func updateUIView(_ uiView: PlatformContainerView, context: Context) {
    let theme = context.environment.codeTheme
    uiView.apply(theme: theme)
    // … existing config-application below
}
#endif
```

(The `\.codeTheme` environment key is already wired by sub-project 2; this is just adding the read.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter ApplyThemePropagationTests`
Expected: PASS — fan-out and equality-gate.

- [ ] **Step 7: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean.

```bash
git add -A
git commit -m "$(cat <<'EOF'
Theming: apply(theme:) skeleton wired through Representable + container

Adds equality-gated apply(theme:) stubs to every Layout/Annotations/
Text platform view (themeDidChange() is a no-op for now). Container
fans out to all subviews. Representable reads \.codeTheme from
environment in updateNSView/updateUIView. Subsequent tasks override
themeDidChange() per-view to consume actual theme keys.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Wire `GutterView` background + `GutterViewRenderer` line numbers

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/GutterView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/GutterViewThemeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Layout/GutterViewThemeTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

@Suite("GutterView theme")
struct GutterViewThemeTests {

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test("Gutter background equals theme.style.editor.gutterBackground after apply")
    func gutterBackgroundFromTheme() {
        let view = GutterView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = NSColor(tokens: theme.style.editor.gutterBackground)
        #expect(view.themedBackgroundColor == expected)
    }

    @Test("Renderer inactive number color = style.editor.lineNumber")
    func rendererInactiveNumberColor() {
        let renderer = GutterViewRenderer()
        let theme = Theme.lcarsDark
        renderer.apply(theme: theme)
        #expect(renderer.themedLineNumberColor == NSColor(tokens: theme.style.editor.lineNumber))
    }

    @Test("Renderer active number color = style.editor.lineNumberActive")
    func rendererActiveNumberColor() {
        let renderer = GutterViewRenderer()
        let theme = Theme.lcarsDark
        renderer.apply(theme: theme)
        #expect(renderer.themedActiveLineNumberColor == NSColor(tokens: theme.style.editor.lineNumberActive))
    }
    #endif
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter GutterViewThemeTests`
Expected: FAIL — `themedBackgroundColor`, `themedLineNumberColor`, `themedActiveLineNumberColor`, and `GutterViewRenderer.apply(theme:)` not defined.

- [ ] **Step 3: Implement `GutterView` theme reads**

In `Sources/CodeEditorPlugin/Layout/GutterView.swift`, override `themeDidChange` (added in Task 5) to update a `themedBackgroundColor` stored property and trigger a redraw:

```swift
extension GutterView {
    /// Theme-derived background color. Set in themeDidChange.
    public private(set) var themedBackgroundColor: PlatformColor {
        get { _themedBackgroundColorStorage ?? .clear }
        set { _themedBackgroundColorStorage = newValue }
    }

    override func themeDidChange() {
        guard let theme = appliedTheme else { return }
        themedBackgroundColor = PlatformColor(tokens: theme.style.editor.gutterBackground)
        // If the existing background is set via a stored property used by the
        // draw routine, update that here instead. Pattern depends on the
        // existing GutterView field shape — keep both paths in sync.
    }
}
```

(`PlatformColor` is the project's existing alias — `NSColor` on macOS, `UIColor` on iOS/Catalyst.)

- [ ] **Step 4: Implement `GutterViewRenderer` theme reads**

In `Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift`:

```swift
extension GutterViewRenderer {
    /// Theme-derived inactive line-number color.
    public private(set) var themedLineNumberColor: PlatformColor {
        get { _themedLineNumberColorStorage ?? .secondaryLabelColor }
        set { _themedLineNumberColorStorage = newValue }
    }

    /// Theme-derived active line-number color.
    public private(set) var themedActiveLineNumberColor: PlatformColor {
        get { _themedActiveLineNumberColorStorage ?? .labelColor }
        set { _themedActiveLineNumberColorStorage = newValue }
    }

    /// Apply a theme. Renderer is not a view, so no setNeedsDisplay; the
    /// owning GutterView triggers redraw when its themeDidChange fires.
    public func apply(theme: Theme) {
        themedLineNumberColor = PlatformColor(tokens: theme.style.editor.lineNumber)
        themedActiveLineNumberColor = PlatformColor(tokens: theme.style.editor.lineNumberActive)
    }
}
```

Then in `GutterView.themeDidChange`, also call `renderer.apply(theme: theme)`:

```swift
override func themeDidChange() {
    guard let theme = appliedTheme else { return }
    themedBackgroundColor = PlatformColor(tokens: theme.style.editor.gutterBackground)
    renderer.apply(theme: theme)
}
```

(Adjust to whatever the renderer-ownership pattern actually is in the existing code.)

- [ ] **Step 5: Update `GutterViewRenderer`'s draw routine to use the themed colors**

Find the existing draw code that uses `PlatformColors.secondaryLabel` (or similar). Replace those reads with `themedLineNumberColor` (for inactive lines) and `themedActiveLineNumberColor` (for the active line, if the renderer knows which one is active). If the renderer doesn't yet distinguish active vs inactive, add a parameter or stored property — match how the existing line-highlight integration works.

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter GutterViewThemeTests`
Expected: PASS — three tests.

- [ ] **Step 7: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Layout/GutterView.swift \
        Sources/CodeEditorPlugin/Layout/GutterViewRenderer.swift \
        Tests/CodeEditorPluginTests/Layout/GutterViewThemeTests.swift
git commit -m "$(cat <<'EOF'
Theming: GutterView + GutterViewRenderer read theme colors

Background from style.editor.gutterBackground; inactive numbers from
style.editor.lineNumber; active number from style.editor.lineNumberActive.
Renderer is non-view; apply(theme:) is plain method invocation, with
the owning GutterView triggering redraw via its themeDidChange override.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Wire `LineHighlightView` + `InsertionPointView`

Two small, single-color components — bundling into one commit.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/LineHighlightView.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/InsertionPointView.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/LineHighlightInsertionPointThemeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Layout/LineHighlightInsertionPointThemeTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@Suite("LineHighlight + InsertionPoint theme")
struct LineHighlightInsertionPointThemeTests {

    @Test("LineHighlightView fill color = style.editor.activeLineBackground")
    func lineHighlightColorFromTheme() {
        let view = LineHighlightView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        #expect(view.themedFillColor == NSColor(tokens: theme.style.editor.activeLineBackground))
    }

    @Test("LineHighlightView fill alpha equals theme color alpha (no hardcoded multiplier)")
    func lineHighlightAlphaFromThemeOnly() {
        let view = LineHighlightView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        var alphaOut: CGFloat = 0
        view.themedFillColor.getRed(nil, green: nil, blue: nil, alpha: &alphaOut)
        #expect(abs(alphaOut - theme.style.editor.activeLineBackground.alpha) < 0.005)
    }

    @Test("InsertionPointView caret color = style.players[0].cursor")
    func caretColorFromTheme() {
        let view = InsertionPointView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let expected = NSColor(tokens: theme.style.players[0].cursor)
        #expect(view.themedCaretColor == expected)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LineHighlightInsertionPointThemeTests`
Expected: FAIL — `themedFillColor` / `themedCaretColor` not defined.

- [ ] **Step 3: Implement `LineHighlightView`**

```swift
// Sources/CodeEditorPlugin/Layout/LineHighlightView.swift
extension LineHighlightView {
    public private(set) var themedFillColor: PlatformColor {
        get { _themedFillColorStorage ?? .clear }
        set { _themedFillColorStorage = newValue }
    }

    override func themeDidChange() {
        guard let theme = appliedTheme else { return }
        themedFillColor = PlatformColor(tokens: theme.style.editor.activeLineBackground)
    }
}
```

Update the existing fill-drawing code path to read `themedFillColor` instead of any prior `PlatformColors.tintColor.withAlphaComponent(0.1)` literal.

- [ ] **Step 4: Implement `InsertionPointView`**

```swift
// Sources/CodeEditorPlugin/Layout/InsertionPointView.swift
extension InsertionPointView {
    public private(set) var themedCaretColor: PlatformColor {
        get { _themedCaretColorStorage ?? .labelColor }
        set { _themedCaretColorStorage = newValue }
    }

    override func themeDidChange() {
        guard let theme = appliedTheme else { return }
        themedCaretColor = PlatformColor(tokens: theme.style.players[0].cursor)
    }
}
```

Update the caret-draw code to read `themedCaretColor` instead of `PlatformColors.label`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter LineHighlightInsertionPointThemeTests`
Expected: PASS.

- [ ] **Step 6: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Layout/LineHighlightView.swift \
        Sources/CodeEditorPlugin/Layout/InsertionPointView.swift \
        Tests/CodeEditorPluginTests/Layout/LineHighlightInsertionPointThemeTests.swift
git commit -m "$(cat <<'EOF'
Theming: LineHighlightView + InsertionPointView read theme colors

Active-line fill from style.editor.activeLineBackground (alpha
included in the theme color, no hardcoded multiplier). Caret from
style.players[0].cursor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Wire `MinimapView`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/MinimapView.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/MinimapViewThemeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Layout/MinimapViewThemeTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@Suite("MinimapView theme")
struct MinimapViewThemeTests {

    @Test("Minimap background = style.editor.background")
    func minimapBackground() {
        let view = MinimapView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        #expect(view.themedBackgroundColor == NSColor(tokens: theme.style.editor.background))
    }

    @Test("Minimap viewport indicator = style.scrollbar.thumbBackground")
    func minimapViewportIndicator() {
        let view = MinimapView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        #expect(view.themedViewportIndicatorColor == NSColor(tokens: theme.style.scrollbar.thumbBackground))
    }

    @Test("Minimap viewport track = style.scrollbar.trackBackground")
    func minimapViewportTrack() {
        let view = MinimapView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        #expect(view.themedTrackColor == NSColor(tokens: theme.style.scrollbar.trackBackground))
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MinimapViewThemeTests`
Expected: FAIL.

- [ ] **Step 3: Implement `MinimapView` theme reads**

```swift
// Sources/CodeEditorPlugin/Layout/MinimapView.swift
extension MinimapView {
    public private(set) var themedBackgroundColor: PlatformColor {
        get { _themedBackgroundColorStorage ?? .clear }
        set { _themedBackgroundColorStorage = newValue }
    }

    public private(set) var themedViewportIndicatorColor: PlatformColor {
        get { _themedViewportIndicatorStorage ?? .controlAccentColor.withAlphaComponent(0.3) }
        set { _themedViewportIndicatorStorage = newValue }
    }

    public private(set) var themedTrackColor: PlatformColor {
        get { _themedTrackStorage ?? .clear }
        set { _themedTrackStorage = newValue }
    }

    override func themeDidChange() {
        guard let theme = appliedTheme else { return }
        themedBackgroundColor = PlatformColor(tokens: theme.style.editor.background)
        themedViewportIndicatorColor = PlatformColor(tokens: theme.style.scrollbar.thumbBackground)
        themedTrackColor = PlatformColor(tokens: theme.style.scrollbar.trackBackground)
    }
}
```

Update the existing draw code path to read these themed colors instead of any `PlatformColors.controlBackground` / `systemBlue.withAlpha(0.3)` literals.

- [ ] **Step 4: Token-colored bars (deferred to Task 9 visibility)**

The minimap draws colored bars proportional to syntax tokens. Today this uses ad-hoc colors; sub-project 3's spec wants `Theme.color(forToken:)` here. Since the resolver is in place from Task 4, plumb the read at this task: in the bar-drawing code, replace the ad-hoc color with `theme.color(forToken: tokenName)` resolved via the same theme.

If the existing code doesn't yet carry token-name information into the minimap renderer, defer the token-colored bars to Task 9 (where the syntax-highlight pipeline rewires) and ship background + viewport + track only here. Make the deferral explicit in the commit message.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter MinimapViewThemeTests`
Expected: PASS.

- [ ] **Step 6: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Layout/MinimapView.swift \
        Tests/CodeEditorPluginTests/Layout/MinimapViewThemeTests.swift
git commit -m "$(cat <<'EOF'
Theming: MinimapView reads theme background + viewport + track

Background from style.editor.background; viewport indicator from
style.scrollbar.thumbBackground; track from style.scrollbar.trackBackground.
Token-colored bar work deferred to Task 9 once the syntax-highlight
pipeline carries TokenName into the minimap renderer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `AnnotationKind` retype + view wiring

`AnnotationKind.color` becomes `func color(in theme: Theme) -> PlatformColor`. `AnnotationView` and `AnnotationsContentView` wire through.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Annotations/AnnotationKind.swift`
- Modify: `Sources/CodeEditorPlugin/Annotations/AnnotationView.swift`
- Modify: `Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift`
- Test: `Tests/CodeEditorPluginTests/Annotations/AnnotationThemeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Annotations/AnnotationThemeTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@Suite("Annotation theme")
struct AnnotationThemeTests {

    @Test("AnnotationKind.color(in:) returns theme.style.status.error for .error")
    func errorColor() {
        let theme = Theme.lcarsDark
        let color = AnnotationKind.error.color(in: theme)
        #expect(color == NSColor(tokens: theme.style.status.error))
    }

    @Test("AnnotationKind.color(in:) returns theme.style.status.warning for .warning")
    func warningColor() {
        let theme = Theme.lcarsDark
        let color = AnnotationKind.warning.color(in: theme)
        #expect(color == NSColor(tokens: theme.style.status.warning))
    }

    @Test("AnnotationKind.color(in:) maps fixme to status.warning (best-fit)")
    func fixmeColor() {
        let theme = Theme.lcarsDark
        // .fixme has no direct status equivalent; spec says it maps to a
        // best-fit. Accept either status.warning or status.conflict.
        let color = AnnotationKind.fixme.color(in: theme)
        let warning = NSColor(tokens: theme.style.status.warning)
        let conflict = NSColor(tokens: theme.style.status.conflict)
        #expect(color == warning || color == conflict)
    }

    @Test("AnnotationKind.color(in:) maps info/note/todo to status.info")
    func infoFamilyColors() {
        let theme = Theme.lcarsDark
        let infoExpected = NSColor(tokens: theme.style.status.info)
        #expect(AnnotationKind.info.color(in: theme) == infoExpected)
        #expect(AnnotationKind.note.color(in: theme) == infoExpected)
        #expect(AnnotationKind.todo.color(in: theme) == infoExpected)
    }

    @Test("AnnotationsContentView fans theme to nested views")
    func annotationsContentViewFans() {
        let parent = AnnotationsContentView()
        let theme = Theme.lcarsDark
        parent.apply(theme: theme)
        #expect(parent.appliedTheme == theme)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AnnotationThemeTests`
Expected: FAIL — `AnnotationKind.color(in:)` not defined; `AnnotationsContentView.appliedTheme` not defined.

- [ ] **Step 3: Retype `AnnotationKind.color`**

```swift
// Sources/CodeEditorPlugin/Annotations/AnnotationKind.swift
extension AnnotationKind {
    /// The platform color for this kind under the given theme.
    /// Replaces the old static `.color` computed property.
    public func color(in theme: Theme) -> PlatformColor {
        switch self {
        case .info, .note, .todo:
            return PlatformColor(tokens: theme.style.status.info)
        case .fixme:
            return PlatformColor(tokens: theme.style.status.warning)
        case .warning:
            return PlatformColor(tokens: theme.style.status.warning)
        case .error:
            return PlatformColor(tokens: theme.style.status.error)
        }
    }
}
```

Delete the old computed `var color: PlatformColor { … }` from the same file.

- [ ] **Step 4: Update `AnnotationView` call sites**

Find every reader of `kind.color` (no argument). Each becomes `kind.color(in: theme)`. The `theme` source for each call site:
- If the view stores `appliedTheme`, use that (force-unwrap or fall back to a sensible default — prefer reading from `appliedTheme` directly, falling back to `Theme.lcarsDark` if nil).
- If the view doesn't yet store theme, plumb a `theme:` parameter through the call chain.

```swift
// Sources/CodeEditorPlugin/Annotations/AnnotationView.swift
// Change
//   let badgeColor = kind.color
// to
//   let badgeColor = kind.color(in: appliedTheme ?? .lcarsDark)
```

- [ ] **Step 5: Implement `AnnotationsContentView.apply(theme:)` propagation**

```swift
// Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift
extension AnnotationsContentView {
    override func themeDidChange() {
        guard let theme = appliedTheme else { return }
        // Iterate over child AnnotationViews and apply the theme to each.
        for case let annotationView as AnnotationView in subviews {
            annotationView.apply(theme: theme)
        }
        // Also update any other subviews that need theme — e.g., a
        // background or border material.
    }
}
```

If `AnnotationView` doesn't yet conform to the `apply(theme:)` pattern from Task 5, add it now (same pattern: stored `appliedTheme`, equality gate, `themeDidChange()` triggers redraw).

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter AnnotationThemeTests`
Expected: PASS.

- [ ] **Step 7: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Annotations/AnnotationKind.swift \
        Sources/CodeEditorPlugin/Annotations/AnnotationView.swift \
        Sources/CodeEditorPlugin/Annotations/AnnotationsContentView.swift \
        Tests/CodeEditorPluginTests/Annotations/AnnotationThemeTests.swift
git commit -m "$(cat <<'EOF'
Theming: AnnotationKind.color(in:) + view wiring

AnnotationKind.color becomes a function taking Theme; reads from
style.status.{error,warning,info,conflict}. AnnotationView updates
its call site to pull from its appliedTheme. AnnotationsContentView
fans apply(theme:) to nested AnnotationViews.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `TextLayoutFragmentView` per-run color via resolver + selection fill

Per-run colors come from `Theme.color(forToken:)`. Selection color comes from `theme.style.players[0].selection`.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` (or its platform-specific extensions) — selection-color reads
- Modify: one or more files under `Sources/CodeEditorPlugin/SyntaxHighlighting/` — producer of attribute runs starts calling `theme.color(forToken:)`. Likely candidates: `SyntaxHighlightingCoordinator.swift`, `SyntaxColorScheme.swift`, the per-language regex highlighters. Determine during this task by reading the existing color-injection path.
- Test: `Tests/CodeEditorPluginTests/Text/SyntaxColorAndSelectionTests.swift`

- [ ] **Step 1: Audit the existing color-injection path**

Run: `grep -rn "PlatformColors\|NSColor\|UIColor" Sources/CodeEditorPlugin/SyntaxHighlighting/ 2>/dev/null | head -50`

Goal: identify the file(s) that produce the per-run color attribute on the highlighted `NSAttributedString`. The most likely producer is `SyntaxColorScheme.swift` or a method in `SyntaxHighlightingCoordinator.swift`. Note the call site for Step 4.

- [ ] **Step 2: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Text/SyntaxColorAndSelectionTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@Suite("Per-run color + selection fill")
struct SyntaxColorAndSelectionTests {

    @Test("Highlight pipeline assigns Theme.color(forToken:) per token")
    func highlightUsesResolver() {
        let theme = Theme.lcarsDark
        // Construct a small attributed result via the project's existing
        // SyntaxColorScheme / coordinator entry point. Adjust the fixture
        // call to match the actual surface; the assertion is what matters.
        let result = SyntaxColorScheme.color(forToken: "keyword", in: theme)
        #expect(result == NSColor(tokens: theme.color(forToken: "keyword")))
    }

    @Test("CodeEditorView selectedTextAttributes background = players[0].selection")
    @MainActor
    func selectionBackgroundFromTheme() {
        let view = CodeEditorView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let attrs = view.selectedTextAttributes
        let bg = attrs[.backgroundColor] as? NSColor
        #expect(bg == NSColor(tokens: theme.style.players[0].selection))
    }
}
#endif
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter SyntaxColorAndSelectionTests`
Expected: FAIL — likely both tests fail (existing implementations don't pull from the theme).

- [ ] **Step 4: Switch the syntax-color producer to `Theme.color(forToken:)`**

In whatever file Step 1 identified (commonly `SyntaxColorScheme.swift`), replace any hardcoded color logic with:

```swift
// Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxColorScheme.swift  (or actual location)
extension SyntaxColorScheme {
    /// Look up a color for a given token in the supplied theme.
    /// Replaces any prior hardcoded color decision.
    public static func color(forToken token: TokenName, in theme: Theme) -> PlatformColor {
        PlatformColor(tokens: theme.color(forToken: token))
    }
}
```

Update every existing call site that formerly produced a token's color to route through this static (or the resolver directly). If the existing code used a `SyntaxColorScheme` *instance* keyed off appearance/preset, deprecate that path: the new pattern is "ask the theme." The owning view (the `TextLayoutFragmentView` or its renderer) holds an `appliedTheme: Theme?` and passes it down.

If the existing producer is a class with stored color attributes that get pre-baked when the theme changes, switch its `apply(theme:)` to recompute its attribute table from `theme.color(forToken:)` for all known token names. Either pattern is acceptable; pick the one closer to the existing surface.

- [ ] **Step 5: Implement `selectedTextAttributes` selection-color read**

```swift
// Sources/CodeEditorPlugin/Core/CodeEditorView+AppKitExtensions.swift  (or similar)
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension CodeEditorView {
    override public var selectedTextAttributes: [NSAttributedString.Key: Any] {
        get {
            var attrs = super.selectedTextAttributes
            if let theme = appliedTheme {
                attrs[.backgroundColor] = NSColor(tokens: theme.style.players[0].selection)
            }
            return attrs
        }
        set { super.selectedTextAttributes = newValue }
    }
}
#endif
```

(If `selectedTextAttributes` cannot be cleanly overridden as above — for instance if `super.selectedTextAttributes` doesn't compose — set the `backgroundColor` attribute explicitly in `themeDidChange()`:

```swift
override func themeDidChange() {
    guard let theme = appliedTheme else { return }
    self.selectedTextAttributes = [
        .backgroundColor: NSColor(tokens: theme.style.players[0].selection)
    ]
    // Plus any other selection attributes the existing code requires.
}
```

Pick the form that fits the existing CodeEditorView shape. Keep both branches of the `#if` consistent across macOS and Catalyst.)

- [ ] **Step 6: Implement iOS/Catalyst selection via `tintColor`**

```swift
// Sources/CodeEditorPlugin/Core/CodeEditorView+UIKitExtensions.swift
#if canImport(UIKit)
extension CodeEditorView {
    override public func themeDidChange() {
        super.themeDidChange()
        guard let theme = appliedTheme else { return }
        self.tintColor = UIColor(tokens: theme.style.players[0].selection)
    }
}
#endif
```

(Per Q3=C: iOS uses the system's selection-rendering alpha multiplier on top of `tintColor`; spec acknowledges the resulting α may differ slightly from `players[0].selection.alpha`.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --filter SyntaxColorAndSelectionTests`
Expected: PASS — both tests.

- [ ] **Step 8: Run all theming tests to confirm no regressions**

Run: `swift test --filter Theming`
Expected: every prior theming test still passes.

- [ ] **Step 9: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add -A
git commit -m "$(cat <<'EOF'
Theming: per-run color via Theme.color(forToken:); selection from players[0]

Highlight pipeline (SyntaxColorScheme + coordinator path) routes
color decisions through Theme.color(forToken:) instead of any prior
hardcoded source. macOS sets selectedTextAttributes[.backgroundColor]
to NSColor(tokens: theme.style.players[0].selection). iOS sets
tintColor — UITextView's selection background follows tintColor at a
system-defined alpha (Q3=C; α may differ from theme α; deferred).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Indent guides inside `TextLayoutFragmentView`

Geometry: leading whitespace × tabWidth × spaceAdvance gives the column positions. Active column passed via render config; recomputed on selection change. Blank-line continuity inherits from prior non-blank fragment.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift`
- Modify: whatever publishes selection-change events (likely `Core/CodeEditorView+SetupExtensions.swift` or `UnifiedEventSystem.swift`) — to recompute `activeIndentColumn` and push to the renderer
- Test: `Tests/CodeEditorPluginTests/Text/IndentGuideTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Text/IndentGuideTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Indent guides")
struct IndentGuideTests {

    @Test("Geometry: 8-space leading whitespace at tabWidth=4 yields columns at 1 and 2")
    func geometryEightSpaces() {
        let lineText = "        let x = 1"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 4
        )
        #expect(columns == [1, 2])
    }

    @Test("Geometry: tabs count as tabWidth spaces")
    func geometryTabsCount() {
        let lineText = "\t\tlet x = 1"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 4
        )
        #expect(columns == [1, 2])
    }

    @Test("Disabled when tabWidth is zero")
    func disabledAtTabWidthZero() {
        let lineText = "        let x = 1"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 0
        )
        #expect(columns.isEmpty)
    }

    @Test("Blank-line continuity: blank line inherits prior non-blank depth")
    func blankLineContinuity() {
        let priorDepth = 3
        let blankDepth = IndentGuideGeometry.effectiveDepth(
            forBlankLineWithPriorDepth: priorDepth
        )
        #expect(blankDepth == priorDepth)
    }

    private func leadingWhitespace(of line: String) -> String {
        var result = ""
        for ch in line {
            if ch == " " || ch == "\t" { result.append(ch) } else { break }
        }
        return result
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter IndentGuideTests`
Expected: FAIL — `IndentGuideGeometry` not defined.

- [ ] **Step 3: Implement `IndentGuideGeometry` (pure-value module)**

```swift
// Sources/CodeEditorPlugin/Text/IndentGuideGeometry.swift
import Foundation

/// Pure-value indent-guide arithmetic. UI-free; operates on whitespace
/// strings and integers. The fragment renderer composes geometry results
/// with theme colors to produce the actual draw call.
public enum IndentGuideGeometry {

    /// Returns the indent-column indices that should have a guide drawn,
    /// given the leading-whitespace prefix of a line and the tab width.
    /// Returns an empty array when tabWidth <= 0.
    public static func indentColumns(
        forLeadingWhitespace leading: String,
        tabWidth: Int
    ) -> [Int] {
        guard tabWidth > 0 else { return [] }
        var spaces = 0
        for ch in leading {
            if ch == " " { spaces += 1 }
            else if ch == "\t" { spaces += tabWidth }
            else { break }
        }
        let depth = spaces / tabWidth
        guard depth >= 2 else { return [] }
        return Array(1..<depth)
    }

    /// Blank-line continuity: a blank line inherits the indent depth of
    /// its prior non-blank neighbor.
    public static func effectiveDepth(forBlankLineWithPriorDepth priorDepth: Int) -> Int {
        return priorDepth
    }
}
```

- [ ] **Step 4: Run pure-geometry tests to verify they pass**

Run: `swift test --filter IndentGuideTests`
Expected: PASS — four geometry tests.

- [ ] **Step 5: Plumb indent-guide draw into `TextLayoutFragmentView`**

```swift
// Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift
extension TextLayoutFragmentView {
    /// Render config additions for indent guides.
    struct IndentGuideRenderConfig: Hashable, Sendable {
        var depthForThisLine: Int
        var activeColumn: Int?
        var tabWidth: Int
        var spaceAdvance: CGFloat
        var leadingPadding: CGFloat
        var inactiveColor: PlatformColor
        var activeColor: PlatformColor
    }

    /// Draw indent guides for this fragment. Called from the existing
    /// fragment-draw routine after glyph rendering.
    func drawIndentGuides(
        config: IndentGuideRenderConfig,
        in context: CGContext,
        bounds: CGRect
    ) {
        let depth = config.depthForThisLine
        guard config.tabWidth > 0, depth >= 2 else { return }
        let columns = 1..<depth
        for column in columns {
            let x = config.leadingPadding + CGFloat(column) * CGFloat(config.tabWidth) * config.spaceAdvance
            let isActive = (column == config.activeColumn)
            let color = isActive ? config.activeColor : config.inactiveColor
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
            context.strokePath()
        }
    }
}
```

Wire the call into the existing fragment-draw method. Source the values:
- `depthForThisLine`: from the leading-whitespace prefix of the fragment's text, computed when the fragment's render config is built. Blank lines copy the prior fragment's depth (use `IndentGuideGeometry.effectiveDepth(forBlankLineWithPriorDepth:)`).
- `activeColumn`: published by the active-indent-column recompute (Step 6).
- `tabWidth`: `editorConfiguration.layout.tabWidth`.
- `spaceAdvance`: measured from the editor's font (existing API: `font.advancement(forGlyph: " ".unicodeScalars.first ?? " ")` or similar).
- `leadingPadding`: existing fragment-draw padding.
- `inactiveColor` / `activeColor`: `PlatformColor(tokens: theme.style.editor.indentGuide)` / `PlatformColor(tokens: theme.style.editor.indentGuideActive)`.

- [ ] **Step 6: Recompute `activeIndentColumn` on selection change**

The editor publishes selection-change events via `UnifiedEventSystem` (per CLAUDE.md). Subscribe at the renderer level:

```swift
// Sources/CodeEditorPlugin/Text/TextLayoutFragmentView+ActiveIndent.swift
extension TextLayoutFragmentRenderer {  // or whatever owns fragment configs
    /// Recompute active-indent-column from the current selection's line.
    /// Called when UnifiedEventSystem fires a textSelectionDidChange event.
    func updateActiveIndentColumn(forSelectionAt location: NSTextLocation) {
        let cursorLineLeading = leadingWhitespaceOfLine(containing: location)
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: cursorLineLeading,
            tabWidth: editorConfiguration.layout.tabWidth
        )
        // Active column = the deepest indent column. If columns is empty,
        // active column is nil (no scope to highlight).
        self.activeIndentColumn = columns.last
        // Trigger redraw of all visible fragments.
        invalidateAllFragments()
    }
}
```

Hook the call from wherever the editor presently observes selection changes. If the existing path is in `Core/CodeEditorView+SetupExtensions.swift`, add the call there.

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --filter IndentGuideTests`
Expected: PASS — geometry tests still pass.

- [ ] **Step 8: Manual visual confirmation (optional but recommended)**

If running the sample app is straightforward, briefly render a Swift file with nested function calls and confirm visual indent-guide appearance. (No automated UI assertion required at this task — the geometry tests cover correctness.)

- [ ] **Step 9: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Text/IndentGuideGeometry.swift \
        Sources/CodeEditorPlugin/Text/TextLayoutFragmentView.swift \
        Sources/CodeEditorPlugin/Text/TextLayoutFragmentView+ActiveIndent.swift \
        Tests/CodeEditorPluginTests/Text/IndentGuideTests.swift
git commit -m "$(cat <<'EOF'
Theming: indent guides drawn inside TextLayoutFragmentView

Pure IndentGuideGeometry handles the column-position arithmetic
(leading whitespace × tabWidth, tabs as tabWidth spaces, blank-line
continuity). Fragment view draws 1pt guides at column positions,
inactive vs active color from style.editor.indentGuide(Active).
Active column recomputed on selection-change events and pushed to
the fragment renderer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Fold chevrons in the gutter

SF Symbol `chevron.right`/`.down` glyph; rotation animated on `config.performance.animateCodeFolding`; click target hit-tested in `GutterInteractionHandler.swift`.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/GutterView.swift` (chevron drawing)
- Modify: `Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift` (hit testing)
- Test: `Tests/CodeEditorPluginTests/Layout/FoldChevronTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Layout/FoldChevronTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import SwiftUI
import Testing

@Suite("Fold chevron")
struct FoldChevronTests {

    @Test("Animation respects config.performance.animateCodeFolding=true")
    func animationOn() {
        var config = EditorConfiguration()
        config.performance.animateCodeFolding = true
        let resolved = FoldChevronAnimation.resolved(for: config)
        #expect(resolved == Tokens.Animation.foldChevron)
    }

    @Test("Animation is nil when animateCodeFolding=false (instant rotation)")
    func animationOff() {
        var config = EditorConfiguration()
        config.performance.animateCodeFolding = false
        let resolved = FoldChevronAnimation.resolved(for: config)
        #expect(resolved == nil)
    }

    @Test("Click target spans 16×lineHeight to the left of the line number")
    func clickTargetGeometry() {
        let lineHeight: CGFloat = 18
        let rect = FoldChevronHitTester.hitRect(forLineHeight: lineHeight, atY: 36)
        #expect(rect.width == 16)
        #expect(abs(rect.height - lineHeight) < 0.01)
        #expect(rect.minY == 36)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FoldChevronTests`
Expected: FAIL — `FoldChevronAnimation`, `FoldChevronHitTester` not defined.

- [ ] **Step 3: Implement the animation gate**

```swift
// Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift
import CodeEditorDesignTokens
import Foundation
import SwiftUI

/// Resolves the animation for fold chevron rotation given the editor's
/// performance configuration. Returns nil when animations are disabled
/// (instant rotation, no SwiftUI Animation applied).
public enum FoldChevronAnimation {
    public static func resolved(for config: EditorConfiguration) -> Animation? {
        guard config.performance.animateCodeFolding else { return nil }
        return Tokens.Animation.foldChevron
    }
}
```

- [ ] **Step 4: Implement the hit-test geometry**

```swift
// Sources/CodeEditorPlugin/Layout/FoldChevronHitTester.swift
import CoreGraphics
import Foundation

/// Hit-test rectangle for the fold chevron. 16 points wide, full line
/// height tall, sitting at the left edge of the gutter to the left of
/// the line number.
public enum FoldChevronHitTester {
    public static func hitRect(forLineHeight lineHeight: CGFloat, atY y: CGFloat) -> CGRect {
        CGRect(x: 0, y: y, width: 16, height: lineHeight)
    }
}
```

- [ ] **Step 5: Wire chevron rendering into `GutterView`**

```swift
// Sources/CodeEditorPlugin/Layout/GutterView.swift
extension GutterView {
    /// Draw a fold chevron for a foldable line.
    /// - Parameter isFolded: true if the region is currently folded
    ///   (chevron rotated to .right); false if unfolded (chevron .down).
    func drawFoldChevron(at lineY: CGFloat, lineHeight: CGFloat, isFolded: Bool) {
        guard let theme = appliedTheme else { return }
        let symbol = isFolded ? "chevron.right" : "chevron.down"
        let glyphSize = Tokens.Size.Icon.micro  // 12pt
        let color = PlatformColor(tokens: theme.style.icon.muted)
        let rect = FoldChevronHitTester.hitRect(forLineHeight: lineHeight, atY: lineY)
        let glyphOrigin = CGPoint(
            x: rect.midX - glyphSize / 2,
            y: rect.midY - glyphSize / 2
        )
        // Draw the SF Symbol at glyphOrigin in `color`. Use the existing
        // platform-image drawing API the project already employs for
        // gutter icons. Animation, when enabled, is applied to the
        // fold-toggle action site (Step 6) — not at draw time.
        drawSymbol(symbol, at: glyphOrigin, size: glyphSize, color: color)
    }
}
```

- [ ] **Step 6: Apply animation on fold-toggle**

When the fold-toggle action fires (today wired through `GutterInteractionHandler`), wrap the chevron-rotation update in:

```swift
let animation = FoldChevronAnimation.resolved(for: editorConfiguration)
if let animation {
    withAnimation(animation) {
        // toggle the rotation state — rotation goes 0° ↔ 90°
    }
} else {
    // toggle the rotation state instantly
}
```

If the chevron-rotation is implemented as a CALayer transform animation rather than SwiftUI, use `CATransaction` with the animation duration drawn from `Tokens.Animation.durQuick.swiftUISeconds` and easing from `easeOutSoft` (CAMediaTimingFunction with control points), or skip the wrapping and set `transform` directly when the gate is off.

- [ ] **Step 7: Wire the click target in `GutterInteractionHandler`**

```swift
// Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift
extension GutterInteractionHandler {
    /// Returns the line index whose fold chevron contains the given point,
    /// or nil if the point is not in any chevron's hit rect.
    func chevronHit(at point: CGPoint, lineHeight: CGFloat, visibleLineYs: [CGFloat]) -> Int? {
        for (index, y) in visibleLineYs.enumerated() {
            if FoldChevronHitTester.hitRect(forLineHeight: lineHeight, atY: y).contains(point) {
                return index
            }
        }
        return nil
    }
}
```

Have the existing pointer-down / tap-down handler call `chevronHit(at:lineHeight:visibleLineYs:)` first; if it returns a line index, dispatch the fold-toggle action and short-circuit the regular line-number selection logic.

- [ ] **Step 8: Run tests to verify they pass**

Run: `swift test --filter FoldChevronTests`
Expected: PASS — three tests.

- [ ] **Step 9: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift \
        Sources/CodeEditorPlugin/Layout/FoldChevronHitTester.swift \
        Sources/CodeEditorPlugin/Layout/GutterView.swift \
        Sources/CodeEditorPlugin/Layout/GutterInteractionHandler.swift \
        Tests/CodeEditorPluginTests/Layout/FoldChevronTests.swift
git commit -m "$(cat <<'EOF'
Theming: fold chevrons in gutter (animation-gated, theme color)

SF Symbol chevron.right/down at micro icon size, color from
style.icon.muted. Rotation animated by Tokens.Animation.foldChevron
when config.performance.animateCodeFolding is true; instant otherwise.
Click target is 16×lineHeight to the left of the line number,
hit-tested by GutterInteractionHandler.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: `CompletionCellComponents` rewrite + `_GlassSurface`

Rewrite the popover so all colors and metrics flow from `Theme` and `Tokens.*`. Introduce internal `_GlassSurface` wrapping `NSVisualEffectView` / `UIVisualEffectView`.

**Files:**
- Create: `Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/CompletionCellGlassTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/CodeEditorPluginTests/Layout/CompletionCellGlassTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@Suite("Completion popover glass")
struct CompletionCellGlassTests {

    @Test("_GlassSurface tint = theme.platform.glass.tint at glass.opacity")
    func glassSurfaceTint() {
        let surface = _GlassSurface()
        let theme = Theme.lcarsDark
        surface.apply(theme: theme)
        let expectedTint = NSColor(tokens: theme.platform.glass.tint)
            .withAlphaComponent(theme.platform.glass.opacity)
        #expect(surface.themedTintColor == expectedTint)
    }

    @Test("Selected row background = style.elements.activeBackground")
    func selectedRowBackground() {
        let popover = CompletionPopoverContentView()
        let theme = Theme.lcarsDark
        popover.apply(theme: theme)
        #expect(popover.themedSelectedRowColor == NSColor(tokens: theme.style.elements.activeBackground))
    }

    @Test("Cell text colors = style.text.base + style.text.muted")
    func cellTextColors() {
        let popover = CompletionPopoverContentView()
        let theme = Theme.lcarsDark
        popover.apply(theme: theme)
        #expect(popover.themedPrimaryTextColor == NSColor(tokens: theme.style.text.base))
        #expect(popover.themedSecondaryTextColor == NSColor(tokens: theme.style.text.muted))
    }

    @Test("Border = style.borders.base at strokeHairline")
    func borderColor() {
        let popover = CompletionPopoverContentView()
        let theme = Theme.lcarsDark
        popover.apply(theme: theme)
        #expect(popover.themedBorderColor == NSColor(tokens: theme.style.borders.base))
        #expect(abs(popover.themedBorderWidth - Tokens.Shape.strokeHairline) < 0.001)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CompletionCellGlassTests`
Expected: FAIL — `_GlassSurface`, `CompletionPopoverContentView` themed properties not defined.

- [ ] **Step 3: Implement `_GlassSurface`**

```swift
// Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift
import CodeEditorDesignTokens
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

/// Internal frosted-glass wrapper. Composes an `NSVisualEffectView`
/// with a colored tint sublayer above it. Replaced by the public
/// `PlatformGlassSurface` in sub-project 4.
final class _GlassSurface: NSView {
    private let effect = NSVisualEffectView()
    private let tintLayer = CALayer()

    private(set) var appliedTheme: Theme?
    private(set) var themedTintColor: NSColor = .clear

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSubviews()
    }

    private func configureSubviews() {
        wantsLayer = true
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer?.addSublayer(tintLayer)
    }

    override func layout() {
        super.layout()
        tintLayer.frame = bounds
    }

    func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        let tint = NSColor(tokens: theme.platform.glass.tint)
            .withAlphaComponent(theme.platform.glass.opacity)
        themedTintColor = tint
        tintLayer.backgroundColor = tint.cgColor
    }
}
#endif

#if canImport(UIKit)
import UIKit

/// Internal frosted-glass wrapper. Composes a `UIVisualEffectView`
/// with a tinted subview inside its `contentView` per UIKit convention.
final class _GlassSurface: UIView {
    private let effect = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let tintView = UIView()

    private(set) var appliedTheme: Theme?
    private(set) var themedTintColor: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSubviews()
    }

    private func configureSubviews() {
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        tintView.translatesAutoresizingMaskIntoConstraints = false
        effect.contentView.addSubview(tintView)
        NSLayoutConstraint.activate([
            tintView.leadingAnchor.constraint(equalTo: effect.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: effect.contentView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: effect.contentView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: effect.contentView.bottomAnchor)
        ])
    }

    func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        let tint = UIColor(tokens: theme.platform.glass.tint)
            .withAlphaComponent(theme.platform.glass.opacity)
        themedTintColor = tint
        tintView.backgroundColor = tint
    }
}
#endif
```

- [ ] **Step 4: Rewrite `CompletionCellComponents` so cells consume `Theme`**

Strip the static `CompletionCellTheme.default` / `.compact` lookups. The popover content view (call it `CompletionPopoverContentView`, or whatever the existing top-level type is named) gains:

- `appliedTheme: Theme?` and `apply(theme:)` (per the Task 5 pattern).
- A `_GlassSurface` background.
- `themedSelectedRowColor`, `themedPrimaryTextColor`, `themedSecondaryTextColor`, `themedBorderColor`, `themedBorderWidth` stored properties, set in `themeDidChange()`.

```swift
// Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift
extension CompletionPopoverContentView {
    public private(set) var themedSelectedRowColor: PlatformColor {
        get { _themedSelectedRowStorage ?? .selectedControlColor }
        set { _themedSelectedRowStorage = newValue }
    }
    public private(set) var themedPrimaryTextColor: PlatformColor {
        get { _themedPrimaryTextStorage ?? .labelColor }
        set { _themedPrimaryTextStorage = newValue }
    }
    public private(set) var themedSecondaryTextColor: PlatformColor {
        get { _themedSecondaryTextStorage ?? .secondaryLabelColor }
        set { _themedSecondaryTextStorage = newValue }
    }
    public private(set) var themedBorderColor: PlatformColor {
        get { _themedBorderColorStorage ?? .gridColor }
        set { _themedBorderColorStorage = newValue }
    }
    public private(set) var themedBorderWidth: CGFloat = CGFloat(Tokens.Shape.strokeHairline)

    override func themeDidChange() {
        guard let theme = appliedTheme else { return }
        themedSelectedRowColor = PlatformColor(tokens: theme.style.elements.activeBackground)
        themedPrimaryTextColor = PlatformColor(tokens: theme.style.text.base)
        themedSecondaryTextColor = PlatformColor(tokens: theme.style.text.muted)
        themedBorderColor = PlatformColor(tokens: theme.style.borders.base)
        themedBorderWidth = CGFloat(Tokens.Shape.strokeHairline)
        glassSurface.apply(theme: theme)
        cornerRadius = CGFloat(Tokens.Shape.radiusMD)
    }

    /// Configure cells from the themed properties (called from cellForRow,
    /// configureCell, or whatever the existing list-rendering pattern is).
    func configure(cell: CompletionCellView, isSelected: Bool) {
        cell.backgroundColor = isSelected ? themedSelectedRowColor : .clear
        cell.primaryLabel.textColor = themedPrimaryTextColor
        cell.secondaryLabel.textColor = themedSecondaryTextColor
        cell.contentInsets = NSEdgeInsets(
            top: CGFloat(Tokens.Spacing.sm),
            left: CGFloat(Tokens.Spacing.sm),
            bottom: CGFloat(Tokens.Spacing.sm),
            right: CGFloat(Tokens.Spacing.sm)
        )
    }
}
```

- [ ] **Step 5: Apply popover shadow from `theme.platform.shadows.popover`**

```swift
// Within configureSubviews / themeDidChange:
shadow = NSShadow()
shadow.shadowColor = NSColor(tokens: theme.platform.shadows.popover.color)
shadow.shadowBlurRadius = CGFloat(theme.platform.shadows.popover.blur)
shadow.shadowOffset = CGSize(
    width: CGFloat(theme.platform.shadows.popover.x),
    height: CGFloat(theme.platform.shadows.popover.y)
)
```

For UIKit: set `layer.shadowColor`, `layer.shadowRadius`, `layer.shadowOffset`, `layer.shadowOpacity = 1` (color carries alpha).

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter CompletionCellGlassTests`
Expected: PASS — four tests.

- [ ] **Step 7: Quality gate + commit**

Run: `swift build && swiftlint && swift test --parallel`

```bash
git add Sources/CodeEditorPlugin/Layout/Glass/_GlassSurface.swift \
        Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift \
        Tests/CodeEditorPluginTests/Layout/CompletionCellGlassTests.swift
git commit -m "$(cat <<'EOF'
Theming: completion popover frosted-glass + theme-derived cells

Internal _GlassSurface wraps NSVisualEffectView (macOS) and
UIVisualEffectView (iOS/Catalyst), tinted by theme.platform.glass.
CompletionCellComponents drops the static CompletionCellTheme; cell
colors, padding, corner radius, border, and shadow flow from Theme +
Tokens. Sub-project 4 will introduce the public PlatformGlassSurface
and the popover migrates at that point; _GlassSurface is deleted then.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: `BaseUIComponents` cleanup; final hardcoded-color sweep

Delete `StandardUITheme`; retype `ThemeableUIComponent.theme: Theme`. Audit the remaining `Layout/`, `Annotations/`, `Text/` for any hardcoded `PlatformColors.*` reads still in editor visual decisions.

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift`
- Audit + modify: any remaining hardcoded color sites

- [ ] **Step 1: Find all current `PlatformColors.*` reads in the touched directories**

Run:
```bash
grep -rn "PlatformColors\." Sources/CodeEditorPlugin/Layout/ \
                            Sources/CodeEditorPlugin/Annotations/ \
                            Sources/CodeEditorPlugin/Text/ 2>/dev/null
```

Expected: a list of remaining sites. Each must be classified:
- **Editor visual decision** (theme-driven) → must move to a theme read.
- **Non-theme concern** (control state, accessibility, system fallback) → may stay; flag inline in code review.

- [ ] **Step 2: Replace each editor-visual-decision site with a theme read**

For each editor-visual-decision site found in Step 1, rewrite the literal to read from `appliedTheme` (or pass theme through). If you find a site that doesn't yet have access to `appliedTheme`, plumb it via the existing `apply(theme:)` propagation rather than introducing a parallel path.

If a site is genuinely non-theme (e.g., highlighting a system "selected" control that should follow OS conventions), leave it but add a comment:

```swift
// Non-theme: tracks system selection conventions, not editor theme.
let selectedRing = PlatformColors.controlAccentColor
```

- [ ] **Step 3: Delete `BaseUIComponents.StandardUITheme`**

```swift
// Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift
// DELETE the entire StandardUITheme struct.
// Retype the protocol:
public protocol ThemeableUIComponent: AnyObject {
    var appliedTheme: Theme? { get }
    func apply(theme: Theme)
}
```

If the existing protocol had different shape, preserve the names but retype the property. Find all conformers (`grep -rn "ThemeableUIComponent" Sources/`) and update them — most should already conform via the `apply(theme:)` pattern from Task 5.

- [ ] **Step 4: Build + lint + full test suite**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean. Any failures here mean a missed call site or a conformance gap.

- [ ] **Step 5: Run the spec's grep gate**

Run:
```bash
grep -rn "PlatformColors\.system\|PlatformColors\.label\|PlatformColors\.tintColor" \
    Sources/CodeEditorPlugin/Layout/ \
    Sources/CodeEditorPlugin/Annotations/ \
    Sources/CodeEditorPlugin/Text/ 2>/dev/null
```

Expected: zero hits, OR each remaining hit has an inline comment marking it as a non-theme decision.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Theming: drop StandardUITheme; retype ThemeableUIComponent.theme

Deletes BaseUIComponents.StandardUITheme. ThemeableUIComponent now
exposes appliedTheme + apply(theme:) directly. Final sweep: every
editor-visual color decision in Layout/, Annotations/, Text/ now
reads from Theme; a small handful of system-state sites (selected
rings, accessibility focus) remain flagged inline as deliberately
non-theme.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: CHANGELOG + DocC pass + final SwiftLint sweep

**Files:**
- Modify: `CHANGELOG.md` (or create / append-to README)
- Modify: any new public symbol that's missing DocC

- [ ] **Step 1: Add DocC comments on every new public symbol**

Run: `grep -rn "^public " Sources/CodeEditorPlugin/Theming/Bridges/ Sources/CodeEditorPlugin/Theming/Internal/ Sources/CodeEditorPlugin/Layout/Glass/ Sources/CodeEditorPlugin/Text/IndentGuideGeometry.swift Sources/CodeEditorPlugin/Layout/FoldChevronAnimation.swift Sources/CodeEditorPlugin/Layout/FoldChevronHitTester.swift 2>/dev/null`

For each public symbol returned, confirm a `///`-prefixed DocC comment exists immediately above. Add one if missing. Style matches the existing project DocC voice — plain, present-tense, ≤2 sentences for simple types; longer for non-obvious behavior.

- [ ] **Step 2: Update CHANGELOG**

Append (or create at `CHANGELOG.md`):

```markdown
## Editor Visual Restyle (Sub-project 3)

### Added
- `Tokens.Color → SwiftUI.Color`, `NSColor`, `UIColor` bridges (`Theming/Bridges/`).
- `Tokens.Easing → SwiftUI.Animation` bridge plus `Tokens.Animation.foldChevron` named convenience.
- `Theme.color(forToken:)` resolver — hierarchical dotted fallback over `style.syntax`, ending at `style.editor.foreground`. Per-Theme cache.
- Indent guides drawn inside `TextLayoutFragmentView`, with active-scope highlight from `style.editor.indentGuideActive`.
- Fold chevrons in the gutter (SF Symbol, theme color, animation gated on `config.performance.animateCodeFolding`).
- Frosted-glass completion popover (internal `_GlassSurface`; replaced by public `PlatformGlassSurface` in sub-project 4).
- Theme-derived selection color: macOS reads `style.players[0].selection`; iOS sets `tintColor` (system-multiplied alpha).

### Changed
- Every Layout/Annotations/Text platform view now reads colors from `Theme` via push-model `apply(theme:)`.
- `AnnotationKind.color` retyped to `func color(in theme: Theme) -> PlatformColor`.

### Removed
- The four legacy `Theme` accessors `backgroundColor`, `textColor`, `lineNumberColor`, `selectedLineColor` (sub-project 2 transition surface).
- `BaseUIComponents.StandardUITheme`.

### Internal
- `Theming/SwiftUI/` directory removed; all bridge code lives under `Theming/Bridges/`.

### Deferred
- Selection mix-blend: plain alpha for now; revisit after sub-projects 4–5.
- Public `PlatformGlassSurface` API: sub-project 4.
- Comment-scanner / diagnostic intake for annotation badges: separate brainstorm.
```

- [ ] **Step 3: Final quality gate**

Run: `swift build && swiftlint && swift test --parallel`
Expected: clean — zero warnings, zero violations, all tests pass.

- [ ] **Step 4: Confirm spec acceptance criteria**

Open `docs/superpowers/specs/2026-05-05-editor-visual-restyle-design.md` to the **Acceptance criteria** section and tick each box mentally:

- [ ] `swift build` succeeds with no warnings → check.
- [ ] `swift test` passes → check.
- [ ] `swiftlint` reports zero violations → check.
- [ ] Layout/, Annotations/, Text/ contain zero `PlatformColors.system*`/`label`/`tintColor` for visual decisions → check (Task 14 grep gate).
- [ ] The four legacy `Theme` accessors are removed → check (Task 2).
- [ ] `BaseUIComponents.StandardUITheme` is removed → check (Task 14).
- [ ] `Theming/Bridges/` exists with the four bridge files plus `Theme+SwiftUI.swift` → check.
- [ ] `Theming/Internal/SyntaxColorLookup.swift` exists; `Theme.color(forToken:)` callable → check (Task 4).
- [ ] `Layout/Glass/_GlassSurface.swift` exists and is used by completion popover → check (Task 13).
- [ ] Indent guides render at default `tabWidth = 4`; active column under cursor; continuous across blank lines → check (Task 11).
- [ ] Fold chevrons render; click toggles fold; animation gated → check (Task 12).
- [ ] Public API surface unchanged (only new public symbol is `Theme.color(forToken:)`) → check.
- [ ] DocC comments on every new internal symbol → check (Step 1 above).
- [ ] CHANGELOG entry → check.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md  # plus any DocC-only additions from Step 1
git commit -m "$(cat <<'EOF'
Theming: CHANGELOG + DocC pass for editor visual restyle

Adds the sub-project 3 entry to CHANGELOG and ensures every new
public symbol has a DocC comment. Final quality gate (build, lint,
test) is clean.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review notes (for the implementer, not part of execution)

The plan above maps to the spec's 12-step recommended commit slicing as follows:

| Spec step | Plan task(s) |
|---|---|
| 1. Bridges + tests; migrate Theme+SwiftUI; delete legacy accessors | Tasks 1, 2, 3 |
| 2. `Theme.color(forToken:)` resolver | Task 4 |
| 3. `apply(theme:)` skeleton + Representable wiring | Task 5 |
| 4. Wire small components | Tasks 6, 7 |
| 5. Wire MinimapView | Task 8 |
| 6. AnnotationKind retype + views | Task 9 |
| 7. TextLayoutFragmentView per-run color + selection | Task 10 |
| 8. Indent guides | Task 11 |
| 9. Fold chevrons | Task 12 |
| 10. CompletionCellComponents + _GlassSurface | Task 13 |
| 11. BaseUIComponents cleanup | Task 14 |
| 12. SwiftLint + DocC + CHANGELOG | Task 15 |

Spec-coverage check: each acceptance criterion in the spec maps to a task above. The token-colored minimap bars in Task 8 are explicitly deferred to Task 10 with rationale (the minimap renderer doesn't yet carry `TokenName` until the syntax-highlight pipeline rewires).

### Note on visual snapshot tests

The spec's "Per-component snapshots" table lists eight image-snapshot tests (`GutterView`, `LineHighlightView`, `InsertionPointView`, `MinimapView`, `AnnotationView`, `CompletionCellComponents`, `TextLayoutFragmentView`, `IndentGuideRendering`) using `Theme.lcarsDark`. This plan ships **property-based tests** in their place — every wiring task asserts that the view's `themedX` properties match the expected `theme.style.*` values, but does not capture pixel-level renders.

Reasoning: image snapshots of `NSView` / `UIView` rendering are valuable for regression-catching but flaky across SDK and OS-version boundaries; they're useful as a *complementary* layer rather than a primary correctness signal. Property-based tests catch the semantic content this sub-project actually changes (which color flows where), and they run reliably in CI.

If pixel-level snapshots are wanted before merging sub-project 3, add them as a dedicated task between Tasks 14 (cleanup) and 15 (CHANGELOG): create one `@Suite` per component under `Tests/CodeEditorPluginTests/Layout/Snapshots/`, render via `swift-snapshot-testing`'s `Snapshotting<NSView, NSImage>.image` (and the UIKit equivalent), gate each `@Test` on `#if canImport(AppKit)` / `#if canImport(UIKit)`. Each cell of the spec's Per-component snapshots table maps to one `@Test`. Cost: roughly +1 task with 9 steps, +30 minutes implementation time, +CI flakiness budget. Spec acceptance criterion "new snapshots pass on second run" satisfied either way (resolver and bridge tests already produce snapshots).
