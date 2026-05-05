# Design System Migration

**Date:** 2026-05-05
**Status:** brainstorm complete — pending user review of written spec
**Type:** umbrella spec covering five sub-projects; sub-project 1 is fully specified, sub-projects 2–5 are sketched and will each get their own spec.

## Goal

Adopt the visual design under `Design/` (a React/CSS prototype) as the canonical look-and-feel for the CodeEditorPlugin Swift package, **and** ship a public chrome layer (window/tabs/breadcrumb/status bar/sidebar) so consumers get an Apple-native, Liquid-Glass IDE experience out of the box without owning the look themselves.

## Context

### What exists today
- `CodeEditorPlugin` is a single SwiftPM target — a focused, mature TextKit2-based editor *component*. Layout pieces (`GutterView`, `MinimapView`, `LineHighlightView`, `InsertionPointView`, completion cells, `CodeEditorContainerView`) are all internal-rendering details with ad-hoc styling.
- `EditorConfiguration` exposes `display/layout/behavior/performance` knobs that map 1:1 to the design's tweaks panel.
- A `Theme` struct exists (`Theme.Colors` + `Theme.Fonts`) but does not ship named themes and does not express the broader color surface the new design needs (gutter active fg, selection blend, status semantics, VCS semantics, etc.).
- Platform floor: `macOS 26.3+`, `iOS 26.3+`, `Mac Catalyst 26.3+` (Liquid Glass / Tahoe APIs available unconditionally).
- No app shell — no chrome, no sidebar/file tree, no tab strip, no breadcrumb, no status bar.

### What `Design/` provides
A web prototype demonstrating:
- `tokens.css` — Apple-native typography/spacing/shape/opacity/animation/size token system.
- `macos-window.jsx` — Tahoe-styled window chrome with traffic lights, toolbar pills, Liquid Glass.
- `ios-frame.jsx` — iOS 26 device frame with status bar, nav pills, keyboard.
- `app.jsx` — full IDE shell: sidebar with file tree + tabs, breadcrumb, theme/language/preset switchers, "live config" code summary.
- `editor.jsx` — visual prototype of the editor with gutter annotation badges (TODO/FIXME/NOTE/WARNING/ERROR), fold chevrons, indent guides, active-line highlight, selection with `mixBlendMode`, frosted-glass completion popover, minimap, status bar.
- `themes.jsx` — five named themes (xcodeDark, xcodeLight, vsDark, github, solarized).

The `EditorConfiguration` knobs in `app.jsx` already mirror the Swift package's `display/layout/behavior/performance` shape, so configuration semantics carry over cleanly.

## Strategy

### Sub-project decomposition

| # | Sub-project | Depends on | Why this order |
|---|---|---|---|
| 1 | `CodeEditorDesignTokens` target — codify `tokens.css` as Swift token namespaces (typography, spacing, shape, opacity, animation, size, fallback palette) | nothing | Pure values, zero UI. Unblocks 2/3/4 and is testable in isolation. |
| 2 | `Theme` rewrite + bundled themes (in `CodeEditorPlugin`) | tokens | Replaces today's `Theme` with a Zed-v0.2.0-compatible JSON-loadable schema plus a small `platform` extension. Ships bundled themes as JSON resources. **The only breaking change in this rollout.** |
| 3 | Editor visual restyle (in `CodeEditorPlugin`) | tokens, new Theme | Re-derives `GutterView`, `MinimapView`, `LineHighlightView`, completion popover, fold chevrons, indent guides, annotation badges from tokens + new theme. Maps existing `TokenName` system to Zed syntax vocabulary. Internal-only — public API unchanged. |
| 4 | `CodeEditorUI` target — chrome primitives | tokens, new Theme | `EditorTitleBar`, `EditorTabStripStyle`, `EditorTab`, `EditorBreadcrumbView`, `EditorStatusBar`, `EditorSidebarShell` (styled container, *no* tree), `EditorCommandPaletteStyle`, Liquid Glass surface helpers. SwiftUI-only, composable, host-driven state. |
| 5 | `CodeEditorSample` executable target | tokens, plugin, UI | File-tree implementation, multi-document state, theme/language/preset switchers, "live config" summary. Demonstrates the full design end-to-end. Run with `swift run CodeEditorSample` on macOS. |

**Sequencing.** 1 must land before 2/3/4. 2 must land before 3. After 2 lands, 3 and 4 can run in parallel. 5 is the integration capstone.

Each sub-project gets its own spec → plan → implementation cycle. This document fully specs sub-project 1 and sketches 2–5.

### Cross-cutting decisions

- **Module structure:** three library targets in one SwiftPM package — `CodeEditorDesignTokens`, `CodeEditorPlugin`, `CodeEditorUI` — plus an `executableTarget` for the sample. Tokens have no UI deps; chrome lives in its own product so embedded uses of the editor don't pay the chrome compile cost.
- **Build system:** SwiftPM only. No Xcode project. The sample runs on macOS via `swift run`. iOS demo is out of scope for this rollout (would need an Xcode host project).
- **API stability:** selective break. `CodeEditor` (SwiftUI entry point) and the `display/layout/behavior/performance` knobs in `EditorConfiguration` stay source-compatible. `Theme` is rewritten — pre-1.0, no deprecation runway.
- **Chrome philosophy:** toolkit primitives only. No opinionated `Workspace`/`Document` model. The file-tree implementation is owned by the sample app, not the package.
- **Theme schema:** Zed v0.2.0 (`https://zed.dev/schema/themes/v0.2.0.json`) plus a `platform` extension key for Liquid Glass / shadows / fields that vanilla Zed doesn't model. Vanilla Zed JSONs load cleanly with derived defaults for the missing `platform` section.
- **Bundled themes:** five "neutral" defaults (Xcode Dark/Light, VS Code Dark, GitHub, Solarized) **plus** the user's `Zed Trek` family (20 variants). Both ship as JSON resources in `CodeEditorPlugin/Resources/Themes/`.

### Package layout

The `Package.swift` below is the **end-state** after all five sub-projects land. Each sub-project extends it incrementally:

- After sub-project 1: `CodeEditorDesignTokens` target and product added; `CodeEditorPlugin` gains the dep. `CodeEditorUI`, `CodeEditorSample`, `CodeEditorUITests`, `CodeEditorDesignTokensTests`, and the `resources:` clause on `CodeEditorPlugin` are not yet added.
- After sub-project 2: `resources: [.process("Resources/Themes")]` added to `CodeEditorPlugin`.
- After sub-project 4: `CodeEditorUI` target/product and `CodeEditorUITests` added.
- After sub-project 5: `CodeEditorSample` executable target added.

```swift
let package = Package(
    name: "CodeEditorPlugin",
    platforms: [.macOS("26.3"), .iOS("26.3"), .macCatalyst("26.3")],
    products: [
        .library(name: "CodeEditorDesignTokens", targets: ["CodeEditorDesignTokens"]),
        .library(name: "CodeEditorPlugin",      targets: ["CodeEditorPlugin"]),
        .library(name: "CodeEditorUI",          targets: ["CodeEditorUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump",      from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies",     from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git",         from: "602.0.0"),
    ],
    targets: [
        .target(name: "CodeEditorDesignTokens", swiftSettings: swiftSettings),

        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorDesignTokens",
                .product(name: "Dependencies",  package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax",   package: "swift-syntax"),
                .product(name: "SwiftParser",   package: "swift-syntax"),
            ],
            exclude: ["Info.plist"],
            resources: [.process("Resources/Themes")],
            swiftSettings: swiftSettings
        ),

        .target(
            name: "CodeEditorUI",
            dependencies: ["CodeEditorDesignTokens", "CodeEditorPlugin"],
            swiftSettings: swiftSettings
        ),

        .executableTarget(
            name: "CodeEditorSample",
            dependencies: ["CodeEditorDesignTokens", "CodeEditorPlugin", "CodeEditorUI"],
            swiftSettings: swiftSettings
        ),

        .testTarget(name: "CodeEditorDesignTokensTests",
                    dependencies: ["CodeEditorDesignTokens",
                                   .product(name: "CustomDump", package: "swift-custom-dump"),
                                   .product(name: "SnapshotTesting", package: "swift-snapshot-testing")],
                    exclude: ["__Snapshots__"],
                    swiftSettings: swiftSettings),

        .testTarget(name: "CodeEditorPluginTests",
                    dependencies: ["CodeEditorPlugin",
                                   .product(name: "CustomDump", package: "swift-custom-dump"),
                                   .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
                                   .product(name: "SnapshotTesting", package: "swift-snapshot-testing")],
                    exclude: ["__Snapshots__"],
                    swiftSettings: swiftSettings),

        .testTarget(name: "CodeEditorUITests",
                    dependencies: ["CodeEditorUI",
                                   .product(name: "SnapshotTesting", package: "swift-snapshot-testing")],
                    exclude: ["__Snapshots__"],
                    swiftSettings: swiftSettings),
    ]
)
```

### Source tree

```
Sources/
  CodeEditorDesignTokens/
    Tokens.swift              # umbrella enum
    Color.swift               # Tokens.Color value type
    Easing.swift              # Tokens.Easing value type
    Typography.swift
    Spacing.swift
    Shape.swift
    Opacity.swift
    Animation.swift
    Size.swift
    Palette.swift             # fallback Apple system colors

  CodeEditorPlugin/           # existing 18 directories preserved
    …
    Resources/
      Themes/
        xcode-dark.json
        xcode-light.json
        vs-dark.json
        github.json
        solarized.json
        zed-trek.json         # 20-variant family

  CodeEditorUI/
    Window/
      EditorTitleBar.swift
      EditorTrafficLights.swift
    TabStrip/
    Breadcrumb/
    StatusBar/
    Sidebar/
    CommandPalette/
    Glass/                    # Liquid Glass surface helpers shared across chrome

  CodeEditorSample/
    App.swift
    FileTree/                 # workspace model + FSEvents/DispatchSource watching
    Switchers/
    ConfigurationSummary/
    Samples/                  # sample source files for demo

Tests/
  CodeEditorDesignTokensTests/
  CodeEditorPluginTests/      # existing
  CodeEditorUITests/
```

## Sub-project 1 — `CodeEditorDesignTokens` (full spec)

### Purpose

Codify `Design/tokens.css` as a UI-agnostic Swift module. **Foundation only** — no `SwiftUI`, no `AppKit`, no `UIKit`, no `CoreGraphics`. UI bridging (`Tokens.Color → SwiftUI.Color`, `Tokens.Easing → SwiftUI.Animation`) lives in `CodeEditorPlugin` and `CodeEditorUI`.

This keeps the module reusable for non-UI consumers (other Swift work, snapshot diffing tooling, server-side rendering, headless tests) and makes its tests trivial — pure value comparisons.

### Color representation

```swift
public extension Tokens {
    struct Color: Hashable, Sendable, Codable {
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8
        public let alpha: Double

        public init(r: UInt8, g: UInt8, b: UInt8, alpha: Double = 1)
        public init(hex: UInt32, alpha: Double = 1)               // 0x0A84FF
        public init?(hexString: String)                           // "#0A84FF" or "#0A84FF80"

        public var hexString: String                              // "#0A84FF" or "#0A84FF80" if alpha < 1
    }
}
```

The CSS uses `color-mix(in oklch, accent 90%, black)` for hover/pressed/tint variants. Rather than carry an oklch math library, we **pre-compute** those derived colors once during token authoring and bake the resulting sRGB values as static `let`s. The perceptual difference vs. live oklch math is acceptable for a code editor.

`Double` for alpha; `UInt8` for components — exact representation, no float fuzz, `Hashable` works as intended.

### Animation representation

```swift
public extension Tokens {
    struct Easing: Hashable, Sendable, Codable {
        public let x1: Double
        public let y1: Double
        public let x2: Double
        public let y2: Double
        public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double)
    }
}
```

Durations as `Duration` (Swift std lib, `Sendable`).

### Numeric type for sizes

`Double` throughout — not `CGFloat`. `CoreGraphics` is technically a UI-adjacent import; even though the type would resolve, importing it conflicts with the "Foundation only" rule. Consumers in `CodeEditorPlugin`/`CodeEditorUI` cast `Double → CGFloat` at the bridge. Cost: ~one `CGFloat()` initializer per token site. Benefit: hard module boundary.

### Namespace shape

```swift
public enum Tokens {

    public enum Typography {
        public static let fontSansStack:    [String]
        public static let fontDisplayStack: [String]
        public static let fontRoundedStack: [String]
        public static let fontMonoStack:    [String]

        public enum Size {
            public static let displayXL: Double = 80
            public static let displayLG: Double = 60
            public static let displayMD: Double = 48
            public static let displaySM: Double = 44
            public static let titleXL:   Double = 34
            public static let titleLG:   Double = 28
            public static let titleMD:   Double = 22
            public static let titleSM:   Double = 20
            public static let headingLG: Double = 17
            public static let headingMD: Double = 15
            public static let bodyLG:    Double = 17
            public static let bodyMD:    Double = 16
            public static let bodySM:    Double = 13
            public static let captionLG: Double = 12
            public static let captionMD: Double = 11
            public static let overline:  Double = 11
        }

        public enum Weight {
            public static let regular  = 400
            public static let medium   = 500
            public static let semibold = 600
            public static let bold     = 700
        }

        public enum LineHeight {
            public static let tight:   Double = 1.0
            public static let normal:  Double = 1.2
            public static let relaxed: Double = 1.5
        }

        public enum Tracking {
            public static let caps: Double = 0.5
        }
    }

    public enum Spacing {
        public static let xxxs: Double = 2
        public static let xxs:  Double = 4
        public static let xs:   Double = 6
        public static let sm:   Double = 8
        public static let smMd: Double = 10
        public static let md:   Double = 12
        public static let lg:   Double = 16
        public static let xl:   Double = 20
        public static let xxl:  Double = 24
        public static let xxxl: Double = 32
        public static let cardPadding: Double = lg
        public static let section:     Double = xl
        public static let content:     Double = xxl
    }

    public enum Shape {
        public static let radiusXS:     Double = 4
        public static let radiusSM:     Double = 6
        public static let radiusMD:     Double = 10
        public static let radiusLG:     Double = 12
        public static let radiusXL:     Double = 16
        public static let radiusXXL:    Double = 20
        public static let radiusChip:   Double = 8
        public static let radiusWindow: Double = 40
        public static let radiusFull:   Double = 9999

        public static let strokeHairline: Double = 0.5
        public static let strokeThin:     Double = 1
        public static let strokeMedLight: Double = 1.5
        public static let strokeMedium:   Double = 2
        public static let strokeThick:    Double = 3
        public static let strokeRing:     Double = 8
    }

    public enum Opacity {
        public static let faint:         Double = 0.03
        public static let dim:           Double = 0.04
        public static let subtle:        Double = 0.05
        public static let mist:          Double = 0.06
        public static let soft:          Double = 0.08
        public static let tint:          Double = 0.10
        public static let glassFill:     Double = 0.12
        public static let glassBorder:   Double = 0.14
        public static let glassHighlight: Double = 0.15
        public static let light:         Double = 0.20
        public static let disabled:      Double = 0.30
        public static let medium:        Double = 0.50
        public static let strong:        Double = 0.70
        public static let heavy:         Double = 0.80
        public static let near:          Double = 0.85
    }

    public enum Animation {
        public static let durInstant:  Duration = .milliseconds(100)
        public static let durFast:     Duration = .milliseconds(150)
        public static let durQuick:    Duration = .milliseconds(200)
        public static let durDrawer:   Duration = .milliseconds(250)
        public static let durControl:  Duration = .milliseconds(300)
        public static let durPage:     Duration = .milliseconds(350)
        public static let durSection:  Duration = .milliseconds(400)
        public static let durScreen:   Duration = .milliseconds(500)
        public static let durVerySlow: Duration = .milliseconds(600)

        public static let easeOutSoft      = Easing(0.16, 1.00, 0.30, 1.00)
        public static let easeInOutSoft    = Easing(0.25, 0.80, 0.25, 1.00)
        public static let easeSpringSnappy = Easing(0.22, 1.00, 0.36, 1.00)
    }

    public enum Size {
        public enum Icon {
            public static let indicator: Double = 10
            public static let micro:     Double = 12
            public static let xs:        Double = 16
            public static let sm:        Double = 18
            public static let md:        Double = 24
            public static let lg:        Double = 32
            public static let xl:        Double = 44
            public static let xxl:       Double = 48
        }

        public enum Touch {
            public static let min:         Double = 44
            public static let comfortable: Double = 48
            public static let row:         Double = 52
            public static let large:       Double = 56
        }

        public enum Avatar {
            public static let xs: Double = 24
            public static let sm: Double = 32
            public static let md: Double = 40
            public static let lg: Double = 48
            public static let xl: Double = 64
        }
    }

    public enum Palette {
        public enum Accent {
            public static let dark    = Color(hex: 0x0A84FF)
            public static let light   = Color(hex: 0x007AFF)
            public static let contrast = Color(hex: 0xFFFFFF)
            // Pre-baked oklch-mix derivatives:
            public static let hoverDark, pressedDark: Color
            public static let tint10Dark, tint15Dark, tint20Dark, tint25Dark: Color
            public static let hoverLight, pressedLight: Color
            public static let tint10Light, tint15Light, tint20Light, tint25Light: Color
        }

        public enum Status {
            public static let successDark = Color(hex: 0x30D158)
            public static let warningDark = Color(hex: 0xFF9F0A)
            public static let errorDark   = Color(hex: 0xFF453A)
            public static let infoDark    = Color(hex: 0x0A84FF)
            public static let cautionDark = Color(hex: 0xFFD60A)

            public static let successLight = Color(hex: 0x34C759)
            public static let warningLight = Color(hex: 0xFF9500)
            public static let errorLight   = Color(hex: 0xFF3B30)
            public static let infoLight    = Color(hex: 0x007AFF)
        }

        public enum ANSI {
            public static let black   = Color(hex: 0x1E1E1E)
            public static let red     = Color(hex: 0xF44747)
            public static let green   = Color(hex: 0x6A9955)
            public static let yellow  = Color(hex: 0xD7BA7D)
            public static let blue    = Color(hex: 0x569CD6)
            public static let magenta = Color(hex: 0xC39BD3)
            public static let cyan    = Color(hex: 0x4DD0E1)
            public static let white   = Color(hex: 0xD4D4D4)
        }
    }
}
```

### Out of scope for sub-project 1
- No `SwiftUI.Color` / `PlatformColor` bridging.
- No `EnvironmentValues` keys.
- No `SemanticTokens` struct (semantic colors live in `Theme` — sub-project 2).
- No usage in the editor or chrome (sub-projects 3 and 4).
- No theme JSON loading (sub-project 2).

### Tests (`CodeEditorDesignTokensTests`)
- **Roundtrip Codable.** Encode every static `Tokens.Color` and `Tokens.Easing`, decode, assert equality (CustomDump-friendly diffs on failure).
- **Snapshot drift guard.** Serialize a struct that aggregates every static value to JSON; commit the snapshot. CI fails on unintended changes with a readable diff. (Uses existing `swift-snapshot-testing` dependency.)
- **Sanity asserts.** `Tokens.Spacing.lg == 16`, `Tokens.Shape.radiusFull > Tokens.Shape.radiusWindow`, derived accent variants are darker than base (HSL lightness check), opacity values monotonically increase faint < dim < … < near.
- **Hex roundtrip.** `Tokens.Color(hex: 0x0A84FF).hexString == "#0A84FF"`. `Tokens.Color(hexString: "#0A84FF80")?.alpha ≈ 0.5`.
- **Document-style coverage.** Reflect on every public type and assert it conforms to `Sendable`, `Hashable`, `Codable`. Catches accidental concurrency-unsafe additions.

### Acceptance criteria
- [ ] `swift build` succeeds with `CodeEditorDesignTokens` as a library product.
- [ ] Module imports nothing beyond `Foundation`.
- [ ] `swift test --filter CodeEditorDesignTokensTests` passes; new snapshots pass on second run.
- [ ] Zero SwiftLint violations in the new directory.
- [ ] `CodeEditorPlugin` adds `CodeEditorDesignTokens` as a dep but otherwise unchanged.
- [ ] Documentation comments on every public symbol (DocC-friendly).

## Sub-project 2 — `Theme` rewrite + bundled themes (sketch)

### High-level shape

Zed v0.2.0 schema as the canonical theme format, plus a `platform` extension key for Liquid Glass / shadows / fields. Themes are JSON resources loaded at runtime; the existing programmatic `Theme` struct is replaced.

```swift
public struct ThemeFamily: Hashable, Sendable, Codable {
    public let schema: String
    public let name: String
    public let author: String?
    public let themes: [Theme]
}

public struct Theme: Hashable, Sendable, Codable, Identifiable {
    public enum Appearance: String, Sendable, Codable { case dark, light }
    public var id: String { name }
    public let name: String
    public let appearance: Appearance
    public let style: ThemeStyle
    public let platform: PlatformExtension?
}

public struct ThemeStyle: Hashable, Sendable, Codable {
    public let editor:     EditorColors          // 16 keys
    public let chrome:     ChromeColors          // title_bar, tab_bar, tab, status_bar, toolbar, panel
    public let elements:   ElementStates         // element.* + ghost_element.*
    public let borders:    BorderColors
    public let text:       TextLevels
    public let icon:       IconLevels
    public let status:     StatusPalette         // info/success/warning/error/conflict
    public let vcs:        VCSPalette            // created/modified/deleted/renamed/ignored/hidden/unreachable
    public let scrollbar:  ScrollbarColors
    public let search:     SearchColors
    public let predictive: PredictiveColors      // → drives inline completion suggestions UI
    public let hint:       HintColors
    public let dropTarget: Tokens.Color
    public let players:    [Player]              // [0] used; rest preserved on roundtrip
    public let accents:    [Tokens.Color]
    public let syntax:     [String: SyntaxStyle] // 28+ Zed token names
    public let terminal:   TerminalColors?       // future-compat
}

public struct PlatformExtension: Hashable, Sendable, Codable {
    public let shadows: PlatformShadows
    public let glass:   PlatformGlass
    public let field:   PlatformField
}

public struct SyntaxStyle: Hashable, Sendable, Codable {
    public let color:           Tokens.Color
    public let backgroundColor: Tokens.Color?
    public let fontWeight:      Int?
    public let fontStyle:       FontStyle?       // .normal, .italic
}
```

### Custom Codable
Zed's dotted snake_case keys (`text.muted`, `editor.gutter.background`, `function.method`) decode into nested camelCase fields. Unknown keys are preserved in a `[String: Tokens.Color]` overflow bag so encoding any third-party Zed JSON roundtrips losslessly.

### `ThemeLoader`
- `Theme.bundled(named:)` — loads a named theme by file basename from `Bundle.module/Resources/Themes`.
- `ThemeFamily(jsonData:)` — decodes any Zed JSON.
- `ThemeFamily(contentsOf:)` — loads from a URL (user-provided themes).
- `Theme.fallback(appearance:)` — returns a hardcoded minimum theme assembled from `Tokens.Palette` if all loading fails.

### Bundled themes (in `CodeEditorPlugin/Resources/Themes/`)
- `xcode-dark.json`
- `xcode-light.json`
- `vs-dark.json`
- `github.json`
- `solarized.json`
- `zed-trek.json` (the user's existing 20-variant family — vendored from `~/Downloads/zed-trek/themes/zed-trek.json`)

### Breaking changes
- The existing `Theme` struct (`Theme.Colors`, `Theme.Fonts`) is removed.
- Any environment key or modifier accepting old-`Theme` becomes the new `Theme`.
- `CodeEditorTheme+Extensions.swift` and adjacent files get rewritten.
- `CodeEditor` SwiftUI entry point keeps the same modifier shape (`.codeTheme(_:)`) but the parameter type changes.

### Out of scope
Editor restyle to consume the new theme is sub-project 3.

### Open questions for sub-project 2's spec
- Vendoring `zed-trek.json` into the package — copy with attribution comment, or git-submodule the source repo?
- Which theme is the default if none is set — `xcode-dark`?
- Where does the Zed-token-name → existing `TokenName` mapping live, here or in sub-project 3? (Likely 3, since it's editor-internal.)

## Sub-project 3 — Editor visual restyle (sketch)

Pure internals. No public API changes.

### Components touched
- `Layout/GutterView.swift` and renderer — annotation badges (TODO/FIXME/NOTE/WARNING/ERROR with colored glyphs), fold chevrons with rotation animation gated on `config.performance.animateCodeFolding`.
- `Layout/MinimapView.swift` — token-colored bars derived from theme syntax colors, viewport indicator.
- `Layout/LineHighlightView.swift` — active-line treatment with alpha from theme.
- `Layout/InsertionPointView.swift` — caret color from `players[0].cursor`.
- `Layout/CompletionCellComponents.swift` — frosted-glass popover backed by Liquid Glass material.
- `Text/` — selection rendering with `mixBlendMode` equivalent on AppKit/UIKit.
- `SyntaxHighlighting/TokenName.swift` and friends — mapping layer to Zed syntax vocabulary (`attribute`, `boolean`, `comment`, `constructor`, `function.method`, `punctuation.bracket`, `string.special`, `variable.special`, `variant`, etc.).

### Bridges introduced
- `CodeEditorPlugin/Extensions/Tokens.Color+SwiftUI.swift` — `Tokens.Color → Color`.
- `CodeEditorPlugin/Extensions/Tokens.Color+Platform.swift` — `Tokens.Color → NSColor / UIColor`.
- `CodeEditorPlugin/Extensions/Tokens.Easing+SwiftUI.swift` — `Tokens.Easing → Animation.timingCurve(...)`.
- `CodeEditorPlugin/Extensions/Tokens.Animation+SwiftUI.swift` — convenience `Animation` builders.

### Indent guides
The current container does not render indent guides. This sub-project adds them as a layer driven by `config.layout.tabWidth` and `config.display.showInvisibleCharacters`.

## Sub-project 4 — `CodeEditorUI` chrome primitives (sketch)

SwiftUI-only target. Toolkit primitives, not opinionated screens.

### Components
- `Window/EditorTitleBar.swift` — Tahoe title bar with traffic lights, centered title, trailing toolbar pills.
- `Window/EditorTrafficLights.swift` — system traffic lights wrapper.
- `TabStrip/EditorTabStripStyle.swift` and `EditorTab.swift` — file tabs with language glyph, dirty indicator, close button. Host-owned state via binding.
- `Breadcrumb/EditorBreadcrumbView.swift` — `Sources › CodeEditorPlugin › Foo.swift` style trail.
- `StatusBar/EditorStatusBar.swift` — Ln/Col, total lines, tab/space indicator, hardware-acceleration indicator, debounce.
- `Sidebar/EditorSidebarShell.swift` — styled container with section headers and tab bar (Files/Search/Issues). *No tree.*
- `CommandPalette/EditorCommandPaletteStyle.swift` — frosted-glass list with kind glyphs.
- `Glass/PlatformGlassSurface.swift` — Liquid Glass material wrapper used by all chrome.

### Public API style
SwiftUI `ViewModifier`-style configuration plus environment values for theme. Each component takes a binding for its model where appropriate, keeping the chrome host-state-driven.

## Sub-project 5 — `CodeEditorSample` (sketch)

`executableTarget`. Runs on macOS via `swift run CodeEditorSample`.

### What it owns
- File-tree implementation: `WorkspaceModel`, FSEvents/DispatchSource watching, virtualized rows, expand/collapse state, search.
- Multi-document state: open tabs, dirty tracking, active document selection.
- Switchers: theme/language/preset pickers wired to chrome.
- Configuration-summary sidebar showing live `EditorConfiguration` Swift code.
- Sample source files for the demo (Swift, TypeScript, Python, Rust, JSON).

### What it depends on
All three library products. Demonstrates each of them in isolation and together.

## Open questions for future sub-project specs

- (#2) Default theme name — `xcode-dark` or `zed-trek::Federation Dark`?
- (#2) Theme hot-reload from a watched directory — useful in dev, complexity in prod?
- (#3) `mixBlendMode` for selection — AppKit and UIKit both lack a one-liner equivalent. Likely a `CALayer.compositingFilter` on macOS and a custom blend on iOS. May fall back to plain alpha if too costly.
- (#3) Zed-vocabulary mapping completeness — some Zed token names (e.g., `embedded`) don't have a current `TokenName` analog. Decide per-token: extend `TokenName` or accept a fallback color.
- (#4) Whether `EditorStatusBar` should observe `EditorConfiguration` directly or just take a value snapshot — observation couples chrome to configuration internals; snapshots require the host to push updates.
- (#5) iOS host story — separate Xcode project later if iOS demo becomes a real requirement.

## Implementation sequencing

1. **Sub-project 1 spec → plan → implementation.** Land tokens + tests + Package.swift split. Existing `CodeEditorPlugin` adds tokens dep.
2. **Sub-project 2 spec → plan → implementation.** Theme rewrite, JSON resources, breaking change to `Theme`. Existing tests adapted; some compile errors in restyle work expected and addressed in 3.
3. **Sub-projects 3 and 4 in parallel.** 3 lands editor restyle on the new theme. 4 lands chrome primitives. They share the new theme but don't otherwise depend on each other.
4. **Sub-project 5 spec → plan → implementation.** Sample app integrates everything.

Each sub-project gets its own `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and implementation plan when its turn comes.

## References

- `Design/tokens.css` — design token CSS source.
- `Design/app.jsx`, `editor.jsx`, `themes.jsx`, `macos-window.jsx`, `ios-frame.jsx`, `tweaks-panel.jsx` — visual prototype.
- `~/Downloads/zed-trek/themes/zed-trek.json` — Zed Trek theme family (20 variants) authored by the user.
- Zed theme schema v0.2.0: `https://zed.dev/schema/themes/v0.2.0.json`.
- Existing `CodeEditorPlugin/Configuration/EditorConfiguration.swift` — knob shape preserved by this rollout.
- Existing `CodeEditorPlugin/SyntaxHighlighting/Theme.swift` — replaced by sub-project 2.
