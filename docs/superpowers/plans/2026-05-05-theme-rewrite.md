# Theme Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the package's three theme-shaped types with a single Zed v0.2.0-compatible JSON-loadable `Theme`, ship the user's Zed Trek family (20 variants) as the only bundled JSON, and make `LCARS Dark` the library default.

**Architecture:** Two-level decoder — top-level `ThemeStyle.init(from:)` reads a flat `[String: Tokens.Color]` plus structured maps; per-prefix sub-structs build themselves from the flat dictionary via plain `init(flat:warnings:path:)` constructors. Lenient with diagnostics: missing/malformed values fall back to package-internal defaults and accumulate in a `WarningCollector` sitting on `decoder.userInfo`. Public API is a single `.codeTheme(Theme)` SwiftUI modifier; internal call sites use a temporary `Theme.color(forLegacyToken:)` adapter that sub-project 3 will replace.

**Tech Stack:** Swift 6.3, swift-tools-version 6.3, Swift Testing (`@Suite`/`@Test`/`#expect`), swift-snapshot-testing, swift-custom-dump, `Foundation.JSONDecoder`, `Bundle.module` resources.

**Spec:** [`docs/superpowers/specs/2026-05-05-theme-rewrite-design.md`](../specs/2026-05-05-theme-rewrite-design.md)

---

## File Structure

### Files created

```
Sources/CodeEditorPlugin/Theming/
  Theme.swift                                  # Theme + Theme.Appearance enum
  ThemeFamily.swift                            # ThemeFamily + theme(named:)
  ThemeStyle.swift                             # ThemeStyle (top-level Codable)
  EditorColors.swift                           # editor.* sub-struct
  ChromeColors.swift                           # title_bar/tab_bar/tab/status_bar/toolbar/panel
  ElementStates.swift                          # element.* + ghost_element.*
  BorderColors.swift                           # border.*
  TextLevels.swift                             # text.*
  IconLevels.swift                             # icon.*
  StatusPalette.swift                          # info/success/warning/error/conflict
  VCSPalette.swift                             # created/modified/deleted/renamed/ignored/hidden/unreachable
  ScrollbarColors.swift                        # scrollbar.*
  SearchColors.swift                           # search.*
  PredictiveColors.swift                       # predictive.*
  HintColors.swift                             # hint.*
  PlayerColors.swift                           # players[]
  SyntaxStyle.swift                            # syntax map entry
  TerminalColors.swift                         # terminal.* (reserved, all-optional)
  PlatformExtension.swift                      # platform.* (our extension key)
  Loader/
    ThemeFamily+Loader.swift                   # init(jsonData:), init(contentsOf:), bundled(_:), loaded(...)
    ThemeWarning.swift                         # ThemeWarning value type
    WarningCollector.swift                     # final class on decoder.userInfo
    DynamicCodingKey.swift                     # single-stringValue CodingKey
    ZedColorBridge.swift                       # String <-> Tokens.Color helpers + Tokens.Palette-based fallbacks
  Internal/
    SyntaxColorLookup.swift                    # Theme.color(forLegacyToken:) adapter — deleted in sub-project 3

Sources/CodeEditorPlugin/Resources/Themes/
  zed-trek.json                                # vendored from ~/Downloads/zed-trek/themes/

Tests/CodeEditorPluginTests/Theming/
  ThemeFamilyLoaderTests.swift                 # bundled lookup, parse-error throws, file-missing throws
  ZedTrekDecodeTests.swift                     # all 20 variants decode cleanly, LCARS Dark sanity
  ThemeStyleSnapshotTests.swift                # CustomDump snapshot of LCARS Dark style
  LenientDecodeTests.swift                     # missing key, malformed color, unknown platform key, absent platform
  SyntaxStyleTests.swift                       # color optional, weight 100-900, font_style values, emphasis-only entry
  PlatformExtensionDerivedTests.swift          # derived(from:appearance:) sanity
  FallbackThemeTests.swift                     # Theme.fallback(.dark) and (.light) sanity
  ThemingConformanceTests.swift                # all public Theming/ types conform to Sendable+Hashable+Codable
  ThemeRoundtripTests.swift                    # decode → encode → decode equivalence on bundled variants
  CodeThemeModifierTests.swift                 # .codeTheme(_:) modifier + environment default
  PluginThemeAPITests.swift                    # register/setTheme/currentTheme via plugin API
```

### Files modified

```
Package.swift                                                   # add resources:[.process("Resources/Themes")]
Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift  # full rewrite — new modifier + env value
Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder+ConvenienceExtensions.swift
                                                                # theme(_:) builder retyped to new Theme
Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift  # setupDefaultTheme() reads Theme.lcarsDark
Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift          # theme: Theme protocol property retyped; call sites use color(forLegacyToken:)
Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift  # any direct old-Theme construction call sites (audit during Task 10)
Sources/CodeEditorPlugin/PluginSystem/PluginAPI.swift           # delete EditorTheme + ThemeColors; ThemeAPI methods retyped
Sources/CodeEditorPlugin/PluginSystem/PluginAPIBridge.swift     # ThemeAPIImpl rewired
Sources/CodeEditorPlugin/SyntaxHighlighting/TokenName.swift     # docstring updates only — remove Theme.Colors example
CHANGELOG.md (or README if no CHANGELOG yet)                    # release-note section
```

### Files deleted

```
Sources/CodeEditorPlugin/SyntaxHighlighting/Theme.swift         # replaced by Theming/Theme.swift
```

---

## Conventions used in this plan

- **Test framework:** Swift Testing. All test files start with `@testable import CodeEditorPlugin`, `import Foundation`, `import Testing` (and `import CustomDump` / `import SnapshotTesting` where used).
- **Tokens.Color decode source.** `Tokens.Color`'s synthesized `Codable` reads `{red,green,blue,alpha}` JSON objects, **not hex strings.** The Zed JSON path always reads strings and converts via `Tokens.Color(hexString:)`. Encoding follows the inverse — `flatten(into:prefix:)` emits `Tokens.Color` values via `hexString` into a `[String: String]` flat object. The `ZedColorBridge.swift` helper file owns this translation.
- **Build/test commands.** Throughout the plan, the test command is `swift test --filter <Suite>` and the build command is `swift build`. The full quality gate (used at task ends) is `swift build && swiftlint && swift test --parallel`. SwiftLint must report zero violations.
- **Commits.** One commit per task, message ending with the standard `Co-Authored-By` trailer.

---

## Task 1: Foundation primitives — `ThemeWarning`, `WarningCollector`, `DynamicCodingKey`, `ZedColorBridge`

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Loader/ThemeWarning.swift`
- Create: `Sources/CodeEditorPlugin/Theming/Loader/WarningCollector.swift`
- Create: `Sources/CodeEditorPlugin/Theming/Loader/DynamicCodingKey.swift`
- Create: `Sources/CodeEditorPlugin/Theming/Loader/ZedColorBridge.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/FoundationPrimitivesTests.swift`

- [ ] **Step 1: Write failing tests for the four primitives**

```swift
// Tests/CodeEditorPluginTests/Theming/FoundationPrimitivesTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Foundation primitives")
struct FoundationPrimitivesTests {
    @Test("DynamicCodingKey roundtrips its stringValue")
    func dynamicCodingKey() {
        let key = DynamicCodingKey(stringValue: "editor.gutter.background")
        #expect(key.stringValue == "editor.gutter.background")
        #expect(key.intValue == nil)
        #expect(DynamicCodingKey(intValue: 5) == nil)
    }

    @Test("WarningCollector accumulates warnings in order")
    func warningCollectorAccumulates() {
        let collector = WarningCollector()
        collector.record(.init(kind: .missingKey, keyPath: "a", detail: nil))
        collector.record(.init(kind: .malformedColor, keyPath: "b", detail: "not-a-color"))
        #expect(collector.warnings.count == 2)
        #expect(collector.warnings[0].kind == .missingKey)
        #expect(collector.warnings[1].detail == "not-a-color")
    }

    @Test("WarningCollector.missing returns fallback and records warning")
    func warningCollectorMissingFallsBack() {
        let collector = WarningCollector()
        let fallback = Tokens.Color(hex: 0xABCDEF)
        let value = collector.missing(path: "text", key: "text.muted", fallback: fallback)
        #expect(value == fallback)
        #expect(collector.warnings.count == 1)
        #expect(collector.warnings[0].kind == .missingKey)
        #expect(collector.warnings[0].keyPath == "text.muted")
    }

    @Test("ZedColorBridge.parse accepts 6- and 8-digit hex")
    func zedColorBridgeParseAccepts() {
        let collector = WarningCollector()
        let opaque = ZedColorBridge.parse("#0A84FF", path: "x", warnings: collector)
        #expect(opaque == Tokens.Color(hex: 0x0A84FF))
        let translucent = ZedColorBridge.parse("#0A84FF80", path: "x", warnings: collector)
        #expect(translucent?.alpha != nil && abs((translucent?.alpha ?? 0) - 0.5) < 0.01)
        #expect(collector.warnings.isEmpty)
    }

    @Test("ZedColorBridge.parse warns on malformed and returns nil")
    func zedColorBridgeParseRejects() {
        let collector = WarningCollector()
        let result = ZedColorBridge.parse("not-a-color", path: "x", warnings: collector)
        #expect(result == nil)
        #expect(collector.warnings.count == 1)
        #expect(collector.warnings[0].kind == .malformedColor)
        #expect(collector.warnings[0].detail == "not-a-color")
    }

    @Test("ZedColorBridge.encode formats 6-digit when opaque, 8-digit when translucent")
    func zedColorBridgeEncode() {
        #expect(ZedColorBridge.encode(Tokens.Color(hex: 0x0A84FF)) == "#0A84FF")
        let translucent = Tokens.Color(hex: 0x0A84FF, alpha: 0.5)
        let encoded = ZedColorBridge.encode(translucent)
        #expect(encoded.hasPrefix("#0A84FF"))
        #expect(encoded.count == 9)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FoundationPrimitivesTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `ThemeWarning`**

```swift
// Sources/CodeEditorPlugin/Theming/Loader/ThemeWarning.swift
import Foundation

/// A non-fatal issue encountered while decoding a theme. Accumulates in a
/// `WarningCollector` rather than throwing, so a single typo or missing key
/// doesn't block an otherwise-loadable theme.
public struct ThemeWarning: Hashable, Sendable, CustomStringConvertible {
    public enum Kind: String, Sendable, Hashable, Codable {
        /// A required key was absent; a default was substituted.
        case missingKey
        /// A hex string couldn't parse as `#rrggbb` or `#rrggbbaa`.
        case malformedColor
        /// A key under `platform.*` wasn't recognized; preserved in `extras`.
        case unknownPlatformKey
        /// Defensive — the same key appeared more than once in source JSON.
        case duplicateKey
    }

    public let kind: Kind
    public let keyPath: String
    public let detail: String?

    public init(kind: Kind, keyPath: String, detail: String? = nil) {
        self.kind = kind
        self.keyPath = keyPath
        self.detail = detail
    }

    public var description: String {
        if let detail {
            return "[\(kind.rawValue)] \(keyPath): \(detail)"
        }
        return "[\(kind.rawValue)] \(keyPath)"
    }
}
```

- [ ] **Step 4: Implement `WarningCollector`**

```swift
// Sources/CodeEditorPlugin/Theming/Loader/WarningCollector.swift
import CodeEditorDesignTokens
import Foundation

/// Accumulates ThemeWarnings during a decode pass. Lives on
/// `JSONDecoder.userInfo` under `.themeWarnings`, mutated by the various
/// sub-struct flat-init constructors as they encounter missing/malformed
/// keys. Single-threaded by the decoder contract — `JSONDecoder.decode`
/// runs synchronously on the calling thread.
final class WarningCollector: @unchecked Sendable {
    private(set) var warnings: [ThemeWarning] = []

    func record(_ warning: ThemeWarning) {
        warnings.append(warning)
    }

    /// Convenience: record a `.missingKey` warning and return the supplied
    /// fallback so call sites can read as
    /// `self.muted = flat["text.muted"] ?? warnings.missing(path: ..., key: ..., fallback: ...)`.
    func missing<T>(path _: String, key: String, fallback: T) -> T {
        warnings.append(.init(kind: .missingKey, keyPath: key, detail: nil))
        return fallback
    }
}

extension CodingUserInfoKey {
    /// Slot for a `WarningCollector` on a configured `JSONDecoder.userInfo`.
    static let themeWarnings = CodingUserInfoKey(rawValue: "themeWarnings")!
}
```

- [ ] **Step 5: Implement `DynamicCodingKey`**

```swift
// Sources/CodeEditorPlugin/Theming/Loader/DynamicCodingKey.swift
import Foundation

/// A `CodingKey` that round-trips any string. Used by `ThemeStyle.init(from:)`
/// to read Zed JSON's flat dotted keys (e.g., `editor.gutter.background`,
/// `text.muted`).
struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue _: Int) { nil }
}
```

- [ ] **Step 6: Implement `ZedColorBridge`**

```swift
// Sources/CodeEditorPlugin/Theming/Loader/ZedColorBridge.swift
import CodeEditorDesignTokens
import Foundation

/// Bridges between Zed's `"#rrggbb[aa]"` hex-string color format and
/// `Tokens.Color`. `Tokens.Color`'s synthesized `Codable` reads
/// `{red,green,blue,alpha}` objects — that's the right shape for our token
/// snapshots but the wrong shape for Zed JSON. This file is the single point
/// of translation.
enum ZedColorBridge {
    /// Parse a Zed-format hex string. Records a `.malformedColor` warning and
    /// returns nil on failure; the caller decides whether to substitute a
    /// fallback (and emit a corresponding `.missingKey`).
    static func parse(_ hex: String, path _: String, warnings: WarningCollector) -> Tokens.Color? {
        if let color = Tokens.Color(hexString: hex) { return color }
        warnings.record(.init(kind: .malformedColor, keyPath: path, detail: hex))
        return nil
    }

    /// Encode a Tokens.Color as Zed-format hex. `#RRGGBB` when alpha == 1,
    /// `#RRGGBBAA` otherwise.
    static func encode(_ color: Tokens.Color) -> String {
        color.hexString
    }
}
```

- [ ] **Step 7: Run tests**

Run: `swift test --filter FoundationPrimitivesTests`
Expected: PASS — six tests green.

- [ ] **Step 8: SwiftLint**

Run: `swiftlint lint Sources/CodeEditorPlugin/Theming Tests/CodeEditorPluginTests/Theming`
Expected: zero violations.

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/Loader \
         Tests/CodeEditorPluginTests/Theming/FoundationPrimitivesTests.swift
git commit -m "$(cat <<'EOF'
Theming: foundation primitives

Adds ThemeWarning, WarningCollector, DynamicCodingKey, and ZedColorBridge
in Sources/CodeEditorPlugin/Theming/Loader. These are the building blocks
the rest of the theme rewrite (sub-project 2) depends on.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Leaf value types — `SyntaxStyle`, `Player`, `TerminalColors`

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/SyntaxStyle.swift`
- Create: `Sources/CodeEditorPlugin/Theming/PlayerColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/TerminalColors.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/SyntaxStyleTests.swift`

The first two are simple structured types decoded directly from their Zed shape (object-shaped, no flat-key routing needed). `TerminalColors` is reserved future-compat — every field optional, decoded straight via synthesized Codable from a Zed-shaped object that uses `terminal.foreground`, `terminal.ansi.red`, etc.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/CodeEditorPluginTests/Theming/SyntaxStyleTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("SyntaxStyle")
struct SyntaxStyleTests {
    @Test("decodes color + font_weight + font_style")
    func decodesAllFields() throws {
        let json = #"{"color":"#7ec8de","font_weight":700,"font_style":"italic"}"#
        let style = try JSONDecoder().decode(SyntaxStyle.self, from: Data(json.utf8))
        #expect(style.color == Tokens.Color(hex: 0x7EC8DE))
        #expect(style.fontWeight == 700)
        #expect(style.fontStyle == .italic)
        #expect(style.backgroundColor == nil)
    }

    @Test("decodes emphasis-style entry with no color")
    func decodesEmphasisStyleOnly() throws {
        let json = #"{"font_style":"italic"}"#
        let style = try JSONDecoder().decode(SyntaxStyle.self, from: Data(json.utf8))
        #expect(style.color == nil)
        #expect(style.fontStyle == .italic)
        #expect(style.fontWeight == nil)
    }

    @Test("decodes weight 100 through 900")
    func acceptsAnyValidWeight() throws {
        for weight in stride(from: 100, through: 900, by: 100) {
            let json = #"{"color":"#000000","font_weight":\#(weight)}"#
            let style = try JSONDecoder().decode(SyntaxStyle.self, from: Data(json.utf8))
            #expect(style.fontWeight == weight)
        }
    }

    @Test("Player decodes cursor + selection + optional background")
    func playerDecodes() throws {
        let json = #"{"cursor":"#7ec8de","selection":"#7ec8de26","background":"#7ec8de33"}"#
        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))
        #expect(player.cursor == Tokens.Color(hex: 0x7EC8DE))
        #expect(player.background?.alpha != nil)
    }

    @Test("Player decodes without background")
    func playerDecodesWithoutBackground() throws {
        let json = #"{"cursor":"#7ec8de","selection":"#7ec8de26"}"#
        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))
        #expect(player.background == nil)
    }

    @Test("TerminalColors decodes selectively")
    func terminalDecodes() throws {
        let json = #"{"foreground":"#dfe7f1","ansi":{"red":"#ff7373"}}"#
        let term = try JSONDecoder().decode(TerminalColors.self, from: Data(json.utf8))
        #expect(term.foreground == Tokens.Color(hex: 0xDFE7F1))
        #expect(term.ansi?.red == Tokens.Color(hex: 0xFF7373))
        #expect(term.background == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter SyntaxStyleTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `SyntaxStyle`**

```swift
// Sources/CodeEditorPlugin/Theming/SyntaxStyle.swift
import CodeEditorDesignTokens
import Foundation

/// Per-token syntax styling, keyed under `style.syntax` in Zed JSON.
///
/// Zed allows entries that have only `font_style` or only `font_weight`
/// (e.g., `emphasis: { font_style: italic }`), so `color` is optional.
/// Weights follow the CSS scale (100–900).
public struct SyntaxStyle: Hashable, Sendable, Codable {
    public enum FontStyle: String, Sendable, Hashable, Codable {
        case normal
        case italic
    }

    public let color: Tokens.Color?
    public let backgroundColor: Tokens.Color?
    public let fontWeight: Int?
    public let fontStyle: FontStyle?

    public init(
        color: Tokens.Color? = nil,
        backgroundColor: Tokens.Color? = nil,
        fontWeight: Int? = nil,
        fontStyle: FontStyle? = nil
    ) {
        self.color = color
        self.backgroundColor = backgroundColor
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
    }

    private enum CodingKeys: String, CodingKey {
        case color
        case backgroundColor = "background_color"
        case fontWeight = "font_weight"
        case fontStyle = "font_style"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Zed encodes colors as hex strings; bridge through ZedColorBridge.
        if let hex = try container.decodeIfPresent(String.self, forKey: .color) {
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
                ?? WarningCollector()
            self.color = ZedColorBridge.parse(hex, path: "syntax.color", warnings: warnings)
        } else {
            self.color = nil
        }
        if let hex = try container.decodeIfPresent(String.self, forKey: .backgroundColor) {
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
                ?? WarningCollector()
            self.backgroundColor = ZedColorBridge.parse(hex, path: "syntax.background_color", warnings: warnings)
        } else {
            self.backgroundColor = nil
        }
        self.fontWeight = try container.decodeIfPresent(Int.self, forKey: .fontWeight)
        self.fontStyle = try container.decodeIfPresent(FontStyle.self, forKey: .fontStyle)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(color.map(ZedColorBridge.encode), forKey: .color)
        try container.encodeIfPresent(backgroundColor.map(ZedColorBridge.encode), forKey: .backgroundColor)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(fontStyle, forKey: .fontStyle)
    }
}
```

- [ ] **Step 4: Implement `Player`**

```swift
// Sources/CodeEditorPlugin/Theming/PlayerColors.swift
import CodeEditorDesignTokens
import Foundation

/// One entry from the `players` array. `players[0]` is the user's local
/// caret/selection; subsequent entries are reserved for collaborative
/// editing and preserved on roundtrip even though the editor draws only [0].
public struct Player: Hashable, Sendable, Codable {
    public let cursor: Tokens.Color
    public let selection: Tokens.Color
    public let background: Tokens.Color?

    public init(cursor: Tokens.Color, selection: Tokens.Color, background: Tokens.Color? = nil) {
        self.cursor = cursor
        self.selection = selection
        self.background = background
    }

    private enum CodingKeys: String, CodingKey {
        case cursor, selection, background
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        let cursorHex = try container.decode(String.self, forKey: .cursor)
        let selectionHex = try container.decode(String.self, forKey: .selection)
        guard let cursor = ZedColorBridge.parse(cursorHex, path: "players.cursor", warnings: warnings),
              let selection = ZedColorBridge.parse(selectionHex, path: "players.selection", warnings: warnings)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .cursor, in: container,
                debugDescription: "Player.cursor/selection malformed hex"
            )
        }
        self.cursor = cursor
        self.selection = selection
        if let bgHex = try container.decodeIfPresent(String.self, forKey: .background) {
            self.background = ZedColorBridge.parse(bgHex, path: "players.background", warnings: warnings)
        } else {
            self.background = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ZedColorBridge.encode(cursor), forKey: .cursor)
        try container.encode(ZedColorBridge.encode(selection), forKey: .selection)
        try container.encodeIfPresent(background.map(ZedColorBridge.encode), forKey: .background)
    }
}
```

- [ ] **Step 5: Implement `TerminalColors`**

```swift
// Sources/CodeEditorPlugin/Theming/TerminalColors.swift
import CodeEditorDesignTokens
import Foundation

/// Reserved for future terminal pane support. Every field optional; absent
/// from most Zed JSONs in the wild. Sub-project 2 only models the shape so
/// roundtrip preserves any values that are present.
public struct TerminalColors: Hashable, Sendable, Codable {
    public struct ANSI: Hashable, Sendable, Codable {
        public let black: Tokens.Color?
        public let red: Tokens.Color?
        public let green: Tokens.Color?
        public let yellow: Tokens.Color?
        public let blue: Tokens.Color?
        public let magenta: Tokens.Color?
        public let cyan: Tokens.Color?
        public let white: Tokens.Color?
        public let brightBlack: Tokens.Color?
        public let brightRed: Tokens.Color?
        public let brightGreen: Tokens.Color?
        public let brightYellow: Tokens.Color?
        public let brightBlue: Tokens.Color?
        public let brightMagenta: Tokens.Color?
        public let brightCyan: Tokens.Color?
        public let brightWhite: Tokens.Color?

        public init(black: Tokens.Color? = nil, red: Tokens.Color? = nil, green: Tokens.Color? = nil,
                    yellow: Tokens.Color? = nil, blue: Tokens.Color? = nil, magenta: Tokens.Color? = nil,
                    cyan: Tokens.Color? = nil, white: Tokens.Color? = nil,
                    brightBlack: Tokens.Color? = nil, brightRed: Tokens.Color? = nil,
                    brightGreen: Tokens.Color? = nil, brightYellow: Tokens.Color? = nil,
                    brightBlue: Tokens.Color? = nil, brightMagenta: Tokens.Color? = nil,
                    brightCyan: Tokens.Color? = nil, brightWhite: Tokens.Color? = nil) {
            self.black = black; self.red = red; self.green = green; self.yellow = yellow
            self.blue = blue; self.magenta = magenta; self.cyan = cyan; self.white = white
            self.brightBlack = brightBlack; self.brightRed = brightRed
            self.brightGreen = brightGreen; self.brightYellow = brightYellow
            self.brightBlue = brightBlue; self.brightMagenta = brightMagenta
            self.brightCyan = brightCyan; self.brightWhite = brightWhite
        }

        private enum CodingKeys: String, CodingKey {
            case black, red, green, yellow, blue, magenta, cyan, white
            case brightBlack = "bright_black", brightRed = "bright_red"
            case brightGreen = "bright_green", brightYellow = "bright_yellow"
            case brightBlue = "bright_blue", brightMagenta = "bright_magenta"
            case brightCyan = "bright_cyan", brightWhite = "bright_white"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
                ?? WarningCollector()
            func parseIfPresent(_ key: CodingKeys) throws -> Tokens.Color? {
                guard let hex = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
                return ZedColorBridge.parse(hex, path: "terminal.ansi.\(key.rawValue)", warnings: warnings)
            }
            self.black = try parseIfPresent(.black); self.red = try parseIfPresent(.red)
            self.green = try parseIfPresent(.green); self.yellow = try parseIfPresent(.yellow)
            self.blue = try parseIfPresent(.blue); self.magenta = try parseIfPresent(.magenta)
            self.cyan = try parseIfPresent(.cyan); self.white = try parseIfPresent(.white)
            self.brightBlack = try parseIfPresent(.brightBlack); self.brightRed = try parseIfPresent(.brightRed)
            self.brightGreen = try parseIfPresent(.brightGreen); self.brightYellow = try parseIfPresent(.brightYellow)
            self.brightBlue = try parseIfPresent(.brightBlue); self.brightMagenta = try parseIfPresent(.brightMagenta)
            self.brightCyan = try parseIfPresent(.brightCyan); self.brightWhite = try parseIfPresent(.brightWhite)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(black.map(ZedColorBridge.encode), forKey: .black)
            try container.encodeIfPresent(red.map(ZedColorBridge.encode), forKey: .red)
            try container.encodeIfPresent(green.map(ZedColorBridge.encode), forKey: .green)
            try container.encodeIfPresent(yellow.map(ZedColorBridge.encode), forKey: .yellow)
            try container.encodeIfPresent(blue.map(ZedColorBridge.encode), forKey: .blue)
            try container.encodeIfPresent(magenta.map(ZedColorBridge.encode), forKey: .magenta)
            try container.encodeIfPresent(cyan.map(ZedColorBridge.encode), forKey: .cyan)
            try container.encodeIfPresent(white.map(ZedColorBridge.encode), forKey: .white)
            try container.encodeIfPresent(brightBlack.map(ZedColorBridge.encode), forKey: .brightBlack)
            try container.encodeIfPresent(brightRed.map(ZedColorBridge.encode), forKey: .brightRed)
            try container.encodeIfPresent(brightGreen.map(ZedColorBridge.encode), forKey: .brightGreen)
            try container.encodeIfPresent(brightYellow.map(ZedColorBridge.encode), forKey: .brightYellow)
            try container.encodeIfPresent(brightBlue.map(ZedColorBridge.encode), forKey: .brightBlue)
            try container.encodeIfPresent(brightMagenta.map(ZedColorBridge.encode), forKey: .brightMagenta)
            try container.encodeIfPresent(brightCyan.map(ZedColorBridge.encode), forKey: .brightCyan)
            try container.encodeIfPresent(brightWhite.map(ZedColorBridge.encode), forKey: .brightWhite)
        }
    }

    public let foreground: Tokens.Color?
    public let background: Tokens.Color?
    public let ansi: ANSI?

    public init(foreground: Tokens.Color? = nil, background: Tokens.Color? = nil, ansi: ANSI? = nil) {
        self.foreground = foreground
        self.background = background
        self.ansi = ansi
    }

    private enum CodingKeys: String, CodingKey {
        case foreground, background, ansi
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector
            ?? WarningCollector()
        if let hex = try container.decodeIfPresent(String.self, forKey: .foreground) {
            self.foreground = ZedColorBridge.parse(hex, path: "terminal.foreground", warnings: warnings)
        } else { self.foreground = nil }
        if let hex = try container.decodeIfPresent(String.self, forKey: .background) {
            self.background = ZedColorBridge.parse(hex, path: "terminal.background", warnings: warnings)
        } else { self.background = nil }
        self.ansi = try container.decodeIfPresent(ANSI.self, forKey: .ansi)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(foreground.map(ZedColorBridge.encode), forKey: .foreground)
        try container.encodeIfPresent(background.map(ZedColorBridge.encode), forKey: .background)
        try container.encodeIfPresent(ansi, forKey: .ansi)
    }
}
```

- [ ] **Step 6: Run tests**

Run: `swift test --filter SyntaxStyleTests`
Expected: PASS — six tests green.

- [ ] **Step 7: Build + lint**

Run: `swift build && swiftlint lint Sources/CodeEditorPlugin/Theming`
Expected: builds; zero lint violations.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/SyntaxStyle.swift \
         Sources/CodeEditorPlugin/Theming/PlayerColors.swift \
         Sources/CodeEditorPlugin/Theming/TerminalColors.swift \
         Tests/CodeEditorPluginTests/Theming/SyntaxStyleTests.swift
git commit -m "$(cat <<'EOF'
Theming: SyntaxStyle, Player, TerminalColors

Three Codable leaf types for the new theme schema. SyntaxStyle.color is
optional (Zed's emphasis entry has only font_style). Player models
players[i] verbatim. TerminalColors is reserved future-compat with every
field optional.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Sub-struct fallback palette + `TextLevels` (representative leaf)

Most sub-structs follow the same pattern: an `init(flat:warnings:path:)` constructor that reads a small set of known keys from a `[String: Tokens.Color]` dictionary, defaults missing entries via `WarningCollector.missing(...)`, and routes remaining `<prefix>.*` keys into a per-struct `extras` overflow bag. This task establishes the pattern with `TextLevels` (the simplest non-trivial one) and a small `ThemeFallbackPalette` of internal fallback colors used as substitutes when keys are missing.

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Loader/ThemeFallbackPalette.swift` (internal)
- Create: `Sources/CodeEditorPlugin/Theming/TextLevels.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/TextLevelsTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// Tests/CodeEditorPluginTests/Theming/TextLevelsTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("TextLevels")
struct TextLevelsTests {
    @Test("populates known suffixes from flat dictionary")
    func populatesFromFlat() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "text":             Tokens.Color(hex: 0x111111),
            "text.muted":       Tokens.Color(hex: 0x222222),
            "text.placeholder": Tokens.Color(hex: 0x333333),
            "text.disabled":    Tokens.Color(hex: 0x444444),
            "text.accent":      Tokens.Color(hex: 0x555555)
        ]
        let levels = TextLevels(flat: flat, warnings: collector, path: "style")
        #expect(levels.base == Tokens.Color(hex: 0x111111))
        #expect(levels.muted == Tokens.Color(hex: 0x222222))
        #expect(levels.placeholder == Tokens.Color(hex: 0x333333))
        #expect(levels.disabled == Tokens.Color(hex: 0x444444))
        #expect(levels.accent == Tokens.Color(hex: 0x555555))
        #expect(levels.extras.isEmpty)
        #expect(collector.warnings.isEmpty)
    }

    @Test("missing keys fall back to ThemeFallbackPalette and warn")
    func missingKeysFallBackAndWarn() {
        let collector = WarningCollector()
        let levels = TextLevels(flat: ["text": Tokens.Color(hex: 0x111111)],
                                warnings: collector, path: "style")
        #expect(levels.base == Tokens.Color(hex: 0x111111))
        #expect(levels.muted == ThemeFallbackPalette.textMuted(.dark))
        #expect(collector.warnings.count == 4)
        #expect(Set(collector.warnings.map(\.keyPath)) == [
            "text.muted", "text.placeholder", "text.disabled", "text.accent"
        ])
    }

    @Test("unknown text.* keys land in extras")
    func unknownKeysBecomeExtras() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "text":              Tokens.Color(hex: 0x111111),
            "text.muted":        Tokens.Color(hex: 0x222222),
            "text.placeholder":  Tokens.Color(hex: 0x333333),
            "text.disabled":     Tokens.Color(hex: 0x444444),
            "text.accent":       Tokens.Color(hex: 0x555555),
            "text.brand":        Tokens.Color(hex: 0xAAAAAA)
        ]
        let levels = TextLevels(flat: flat, warnings: collector, path: "style")
        #expect(levels.extras == ["text.brand": Tokens.Color(hex: 0xAAAAAA)])
    }

    @Test("flatten round-trips a populated TextLevels")
    func flattenEmitsAllKeys() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "text":              Tokens.Color(hex: 0x111111),
            "text.muted":        Tokens.Color(hex: 0x222222),
            "text.placeholder":  Tokens.Color(hex: 0x333333),
            "text.disabled":     Tokens.Color(hex: 0x444444),
            "text.accent":       Tokens.Color(hex: 0x555555),
            "text.brand":        Tokens.Color(hex: 0xAAAAAA)
        ]
        let levels = TextLevels(flat: flat, warnings: collector, path: "style")
        var out: [String: Tokens.Color] = [:]
        levels.flatten(into: &out)
        #expect(out["text"] == flat["text"])
        #expect(out["text.muted"] == flat["text.muted"])
        #expect(out["text.brand"] == flat["text.brand"])
    }
}
```

- [ ] **Step 2: Run tests, expect failure**

Run: `swift test --filter TextLevelsTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `ThemeFallbackPalette`**

```swift
// Sources/CodeEditorPlugin/Theming/Loader/ThemeFallbackPalette.swift
import CodeEditorDesignTokens
import Foundation

/// Internal substitution table used when a Zed JSON omits a known color key.
/// Values are tuned for visual sanity rather than exact match to any
/// particular external theme — when a real theme value is missing, we want
/// the editor to render *something readable*, not crash. Split by appearance
/// because dark/light themes need different substitutes.
///
/// Functions take a Theme.Appearance to keep call sites short. When the
/// caller doesn't have an appearance handy yet (e.g., during the first pass
/// of a leaf sub-struct decode, before the Theme wrapper is built), passing
/// `.dark` is fine — Zed Trek's variants are predominantly dark and the
/// substitute will be replaced by a real value in well-formed JSON.
enum ThemeFallbackPalette {
    static func textBase(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0xDFE7F1) : Tokens.Color(hex: 0x1C1C1E)
    }
    static func textMuted(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x8B99AB) : Tokens.Color(hex: 0x6E6E73)
    }
    static func textPlaceholder(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x68778C) : Tokens.Color(hex: 0x9E9EA3)
    }
    static func textDisabled(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x4F5D70) : Tokens.Color(hex: 0xC7C7CC)
    }
    static func textAccent(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Palette.Accent.dark : Tokens.Palette.Accent.light
    }

    static func iconBase(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0xC5D1DF) : Tokens.Color(hex: 0x3A3A3C)
    }
    static func iconMuted(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x768699) : Tokens.Color(hex: 0x8E8E93)
    }
    static func iconAccent(_ appearance: Theme.Appearance) -> Tokens.Color {
        textAccent(appearance)
    }
    static func iconDisabled(_ appearance: Theme.Appearance) -> Tokens.Color {
        textDisabled(appearance)
    }
    static func iconPlaceholder(_ appearance: Theme.Appearance) -> Tokens.Color {
        textPlaceholder(appearance)
    }

    static func background(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x020204) : Tokens.Color(hex: 0xFFFFFF)
    }
    static func surface(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x07090F) : Tokens.Color(hex: 0xF2F2F7)
    }
    static func border(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x1A2232) : Tokens.Color(hex: 0xD1D1D6)
    }
    static func dropTarget(_ appearance: Theme.Appearance) -> Tokens.Color {
        appearance == .dark ? Tokens.Color(hex: 0x7EC8DE26) : Tokens.Color(hex: 0x007AFF26)
    }
    static func clear() -> Tokens.Color { Tokens.Color(hex: 0x000000, alpha: 0) }

    static func status(_ kind: StatusKind, appearance: Theme.Appearance) -> Tokens.Color {
        switch (kind, appearance) {
        case (.info, .dark):     return Tokens.Palette.Status.infoDark
        case (.info, .light):    return Tokens.Palette.Status.infoLight
        case (.success, .dark):  return Tokens.Palette.Status.successDark
        case (.success, .light): return Tokens.Palette.Status.successLight
        case (.warning, .dark):  return Tokens.Palette.Status.warningDark
        case (.warning, .light): return Tokens.Palette.Status.warningLight
        case (.error, .dark):    return Tokens.Palette.Status.errorDark
        case (.error, .light):   return Tokens.Palette.Status.errorLight
        case (.conflict, .dark): return Tokens.Palette.Status.warningDark
        case (.conflict, .light): return Tokens.Palette.Status.warningLight
        }
    }

    enum StatusKind { case info, success, warning, error, conflict }
}
```

- [ ] **Step 4: Implement `TextLevels`**

```swift
// Sources/CodeEditorPlugin/Theming/TextLevels.swift
import CodeEditorDesignTokens
import Foundation

/// Text colors at five emphasis levels, mapped to Zed's `text` / `text.*`
/// keys. `extras` preserves any unknown `text.*` keys so a roundtrip never
/// loses data.
public struct TextLevels: Hashable, Sendable, Codable {
    public let base: Tokens.Color
    public let muted: Tokens.Color
    public let placeholder: Tokens.Color
    public let disabled: Tokens.Color
    public let accent: Tokens.Color
    public let extras: [String: Tokens.Color]

    public init(
        base: Tokens.Color, muted: Tokens.Color, placeholder: Tokens.Color,
        disabled: Tokens.Color, accent: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.base = base; self.muted = muted; self.placeholder = placeholder
        self.disabled = disabled; self.accent = accent; self.extras = extras
    }

    /// Build from a flat dictionary keyed by Zed dotted names, recording
    /// `.missingKey` warnings as we go. Substitutes from
    /// `ThemeFallbackPalette.text*(.dark)` — Zed Trek's variants are
    /// predominantly dark; sub-project 3 will revisit the appearance plumbing
    /// if needed.
    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        let appearance: Theme.Appearance = .dark
        self.base = flat["text"]
            ?? warnings.missing(path: path, key: "text", fallback: ThemeFallbackPalette.textBase(appearance))
        self.muted = flat["text.muted"]
            ?? warnings.missing(path: path, key: "text.muted", fallback: ThemeFallbackPalette.textMuted(appearance))
        self.placeholder = flat["text.placeholder"]
            ?? warnings.missing(path: path, key: "text.placeholder", fallback: ThemeFallbackPalette.textPlaceholder(appearance))
        self.disabled = flat["text.disabled"]
            ?? warnings.missing(path: path, key: "text.disabled", fallback: ThemeFallbackPalette.textDisabled(appearance))
        self.accent = flat["text.accent"]
            ?? warnings.missing(path: path, key: "text.accent", fallback: ThemeFallbackPalette.textAccent(appearance))
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("text.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["text"] = base
        dict["text.muted"] = muted
        dict["text.placeholder"] = placeholder
        dict["text.disabled"] = disabled
        dict["text.accent"] = accent
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = ["text", "text.muted", "text.placeholder", "text.disabled", "text.accent"]
}
```

Note: this file references `Theme.Appearance` which is added in Task 9. To compile in isolation now, add a local `enum _Appearance { case dark, light }` and use it; Task 9 will replace with the public type. **Or**, simpler: also create a stub `Theme.swift` alongside this task that contains only the `Appearance` enum (the rest fills in at Task 9). The plan takes the stub-Theme approach below.

- [ ] **Step 5: Add a minimal `Theme.swift` stub for the Appearance enum**

```swift
// Sources/CodeEditorPlugin/Theming/Theme.swift
import CodeEditorDesignTokens
import Foundation

/// Stub. Full type lands in Task 9.
public struct Theme {
    public enum Appearance: String, Sendable, Hashable, Codable {
        case dark, light
    }
}
```

- [ ] **Step 6: Run tests**

Run: `swift test --filter TextLevelsTests`
Expected: PASS — four tests green.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/Loader/ThemeFallbackPalette.swift \
         Sources/CodeEditorPlugin/Theming/TextLevels.swift \
         Sources/CodeEditorPlugin/Theming/Theme.swift \
         Tests/CodeEditorPluginTests/Theming/TextLevelsTests.swift
git commit -m "$(cat <<'EOF'
Theming: TextLevels + fallback palette pattern

Establishes the per-prefix sub-struct pattern used by the rest of the
theme rewrite: init(flat:warnings:path:) reads known suffixes,
WarningCollector.missing supplies fallbacks for absent keys, and unknown
text.* keys land in self.extras so roundtrips don't lose data.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Remaining flat-prefix sub-structs

Apply the **same pattern** as `TextLevels` to each sub-struct below. For each, the table lists: known suffixes (the keys it owns), the matching `ThemeFallbackPalette` accessor (or a literal Tokens.Color hex if no fallback exists), and any field-name notes.

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/IconLevels.swift`
- Create: `Sources/CodeEditorPlugin/Theming/BorderColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/ScrollbarColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/SearchColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/PredictiveColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/HintColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/StatusPalette.swift`
- Create: `Sources/CodeEditorPlugin/Theming/VCSPalette.swift`
- Create: `Sources/CodeEditorPlugin/Theming/EditorColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/ChromeColors.swift`
- Create: `Sources/CodeEditorPlugin/Theming/ElementStates.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/SubStructFlatInitTests.swift`

### Routing tables

`IconLevels` — same shape as `TextLevels`:
- Known suffixes: `icon`, `icon.muted`, `icon.placeholder`, `icon.disabled`, `icon.accent`
- Fields: `base`, `muted`, `placeholder`, `disabled`, `accent`
- Fallbacks: `ThemeFallbackPalette.icon*`

`BorderColors` — Zed has six border keys:
- Known suffixes: `border`, `border.disabled`, `border.focused`, `border.selected`, `border.transparent`, `border.variant`
- Fields: `base`, `disabled`, `focused`, `selected`, `transparent`, `variant`
- Fallbacks: `ThemeFallbackPalette.border` for `base`, the same with low alpha for variants. Use literal Tokens.Color values where no semantic mapping exists.

`ScrollbarColors`:
- Known suffixes: `scrollbar.track.background`, `scrollbar.track.border`, `scrollbar.thumb.background`, `scrollbar.thumb.border`, `scrollbar.thumb.hover_background`
- Fields: `trackBackground`, `trackBorder`, `thumbBackground`, `thumbBorder`, `thumbHoverBackground`
- Fallbacks: derive from `ThemeFallbackPalette.background` and `border`.

`SearchColors`:
- Known suffixes: `search.match_background`
- Fields: `matchBackground`
- Fallback: `Tokens.Palette.Accent.tint20Dark`

`PredictiveColors`:
- Known suffixes: `predictive`, `predictive.background`, `predictive.border`
- Fields: `base`, `background`, `border`
- Fallback: `ThemeFallbackPalette.textMuted`, low-alpha variants for bg/border.

`HintColors`:
- Known suffixes: `hint`, `hint.background`, `hint.border`
- Fields: `base`, `background`, `border`
- Fallback: same as `PredictiveColors` shape.

`StatusPalette` — five status kinds × three keys each:
- Known suffixes: for each kind in `info, success, warning, error, conflict`: bare, `.background`, `.border`. So 15 keys total: `info`, `info.background`, `info.border`, `success`, `success.background`, `success.border`, …
- Fields: nested `Status` value with `base/background/border`; one Status per kind.
- Fallback: `ThemeFallbackPalette.status(kind, appearance:)` for `base`; low-alpha variants for bg/border.

`VCSPalette` — seven VCS kinds × three keys each:
- Known suffixes: for each kind in `created, modified, deleted, renamed, ignored, hidden, unreachable`: bare, `.background`, `.border`. 21 keys total.
- Fields: nested `VCS` value with `base/background/border`; one VCS per kind.
- Fallback: map to `ThemeFallbackPalette.status` semantics (created→success, modified→info, deleted→error, renamed→info, ignored→textDisabled, hidden→textDisabled, unreachable→textMuted).

`EditorColors` — Zed's `editor.*` keys:
- Known suffixes: `editor.background`, `editor.foreground`, `editor.gutter.background`, `editor.active_line.background`, `editor.highlighted_line.background`, `editor.active_line_number`, `editor.line_number`, `editor.invisible`, `editor.indent_guide`, `editor.indent_guide_active`, `editor.wrap_guide`, `editor.active_wrap_guide`, `editor.subheader.background`, `editor.document_highlight.read_background`, `editor.document_highlight.write_background`, `editor.document_highlight.bracket_background`
- Fields: `background`, `foreground`, `gutterBackground`, `activeLineBackground`, `highlightedLineBackground`, `activeLineNumber`, `lineNumber`, `invisible`, `indentGuide`, `indentGuideActive`, `wrapGuide`, `activeWrapGuide`, `subheaderBackground`, `documentHighlightRead`, `documentHighlightWrite`, `documentHighlightBracket`
- Fallback: `background` → `ThemeFallbackPalette.background(.dark)`, `foreground` → `textBase(.dark)`, etc.

`ChromeColors` — title bar / tab bar / tab / status bar / toolbar / panel:
- Known suffixes: `title_bar.background`, `title_bar.inactive_background`, `tab_bar.background`, `tab.active_background`, `tab.inactive_background`, `status_bar.background`, `toolbar.background`, `surface.background`, `elevated_surface.background`, `panel.background`, `panel.focused_border`, `panel.indent_guide`, `panel.indent_guide_active`, `panel.indent_guide_hover`, `pane.focused_border`, `pane_group.border`
- Fields: `titleBarBackground`, `titleBarInactiveBackground`, `tabBarBackground`, `tabActiveBackground`, `tabInactiveBackground`, `statusBarBackground`, `toolbarBackground`, `surfaceBackground`, `elevatedSurfaceBackground`, `panelBackground`, `panelFocusedBorder`, `panelIndentGuide`, `panelIndentGuideActive`, `panelIndentGuideHover`, `paneFocusedBorder`, `paneGroupBorder`
- Fallback: `ThemeFallbackPalette.surface/.background/.border` variants.

`ElementStates` — `element.*` and `ghost_element.*`:
- Known suffixes for element: `element.background`, `element.hover`, `element.active`, `element.selected`, `element.disabled`
- Known suffixes for ghost_element: `ghost_element.background`, `ghost_element.hover`, `ghost_element.active`, `ghost_element.selected`, `ghost_element.disabled`
- Fields: nested `States { background, hover, active, selected, disabled }`; one for `element`, one for `ghostElement`.
- Fallback: `ThemeFallbackPalette.surface(.dark)` and accent-tint variants.

- [ ] **Step 1: Write the consolidated test file**

```swift
// Tests/CodeEditorPluginTests/Theming/SubStructFlatInitTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Sub-struct flat-init constructors")
struct SubStructFlatInitTests {
    @Test("IconLevels populates from flat")
    func iconLevels() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "icon": Tokens.Color(hex: 0xAAAAAA),
            "icon.muted": Tokens.Color(hex: 0xBBBBBB),
            "icon.placeholder": Tokens.Color(hex: 0xCCCCCC),
            "icon.disabled": Tokens.Color(hex: 0xDDDDDD),
            "icon.accent": Tokens.Color(hex: 0xEEEEEE)
        ]
        let icons = IconLevels(flat: flat, warnings: collector, path: "style")
        #expect(icons.base == Tokens.Color(hex: 0xAAAAAA))
        #expect(icons.accent == Tokens.Color(hex: 0xEEEEEE))
        #expect(collector.warnings.isEmpty)
    }

    @Test("BorderColors populates 6 keys")
    func borderColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "border": Tokens.Color(hex: 0x111111),
            "border.disabled": Tokens.Color(hex: 0x222222),
            "border.focused": Tokens.Color(hex: 0x333333),
            "border.selected": Tokens.Color(hex: 0x444444),
            "border.transparent": Tokens.Color(hex: 0x555555),
            "border.variant": Tokens.Color(hex: 0x666666)
        ]
        let borders = BorderColors(flat: flat, warnings: collector, path: "style")
        #expect(borders.base == Tokens.Color(hex: 0x111111))
        #expect(borders.variant == Tokens.Color(hex: 0x666666))
    }

    @Test("ScrollbarColors populates 5 dotted keys")
    func scrollbarColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "scrollbar.track.background": Tokens.Color(hex: 0x111111),
            "scrollbar.track.border": Tokens.Color(hex: 0x222222),
            "scrollbar.thumb.background": Tokens.Color(hex: 0x333333),
            "scrollbar.thumb.border": Tokens.Color(hex: 0x444444),
            "scrollbar.thumb.hover_background": Tokens.Color(hex: 0x555555)
        ]
        let scrollbar = ScrollbarColors(flat: flat, warnings: collector, path: "style")
        #expect(scrollbar.trackBackground == Tokens.Color(hex: 0x111111))
        #expect(scrollbar.thumbHoverBackground == Tokens.Color(hex: 0x555555))
    }

    @Test("StatusPalette populates 5 kinds × 3 keys")
    func statusPalette() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "info": Tokens.Color(hex: 0x111111), "info.background": Tokens.Color(hex: 0x121212), "info.border": Tokens.Color(hex: 0x131313),
            "success": Tokens.Color(hex: 0x211111), "success.background": Tokens.Color(hex: 0x221212), "success.border": Tokens.Color(hex: 0x231313),
            "warning": Tokens.Color(hex: 0x311111), "warning.background": Tokens.Color(hex: 0x321212), "warning.border": Tokens.Color(hex: 0x331313),
            "error": Tokens.Color(hex: 0x411111), "error.background": Tokens.Color(hex: 0x421212), "error.border": Tokens.Color(hex: 0x431313),
            "conflict": Tokens.Color(hex: 0x511111), "conflict.background": Tokens.Color(hex: 0x521212), "conflict.border": Tokens.Color(hex: 0x531313)
        ]
        let status = StatusPalette(flat: flat, warnings: collector, path: "style")
        #expect(status.info.base == Tokens.Color(hex: 0x111111))
        #expect(status.error.background == Tokens.Color(hex: 0x421212))
        #expect(status.conflict.border == Tokens.Color(hex: 0x531313))
    }

    @Test("VCSPalette populates 7 kinds × 3 keys")
    func vcsPalette() {
        let collector = WarningCollector()
        var flat: [String: Tokens.Color] = [:]
        for (idx, kind) in ["created", "modified", "deleted", "renamed", "ignored", "hidden", "unreachable"].enumerated() {
            flat[kind] = Tokens.Color(hex: UInt32(idx + 1) * 0x010101)
            flat["\(kind).background"] = Tokens.Color(hex: UInt32(idx + 1) * 0x020202)
            flat["\(kind).border"] = Tokens.Color(hex: UInt32(idx + 1) * 0x030303)
        }
        let vcs = VCSPalette(flat: flat, warnings: collector, path: "style")
        #expect(vcs.created.base == Tokens.Color(hex: 0x010101))
        #expect(vcs.deleted.border == Tokens.Color(hex: 0x090909))
    }

    @Test("EditorColors populates 16 keys")
    func editorColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "editor.background": Tokens.Color(hex: 0x010204),
            "editor.foreground": Tokens.Color(hex: 0xDFE7F1),
            "editor.gutter.background": Tokens.Color(hex: 0x05070D),
            "editor.active_line.background": Tokens.Color(hex: 0x7EC8DE12),
            "editor.highlighted_line.background": Tokens.Color(hex: 0xB5A7FF1F),
            "editor.active_line_number": Tokens.Color(hex: 0x7EC8DE),
            "editor.line_number": Tokens.Color(hex: 0x5D6B7F),
            "editor.invisible": Tokens.Color(hex: 0x1B2433),
            "editor.indent_guide": Tokens.Color(hex: 0x121826),
            "editor.indent_guide_active": Tokens.Color(hex: 0x7EC8DE),
            "editor.wrap_guide": Tokens.Color(hex: 0x121826),
            "editor.active_wrap_guide": Tokens.Color(hex: 0xB5A7FF),
            "editor.subheader.background": Tokens.Color(hex: 0x05070D),
            "editor.document_highlight.read_background": Tokens.Color(hex: 0x7EC8DE24),
            "editor.document_highlight.write_background": Tokens.Color(hex: 0xB5A7FF26),
            "editor.document_highlight.bracket_background": Tokens.Color(hex: 0x7EC8DE33)
        ]
        let editor = EditorColors(flat: flat, warnings: collector, path: "style")
        #expect(editor.background == Tokens.Color(hex: 0x010204))
        #expect(editor.foreground == Tokens.Color(hex: 0xDFE7F1))
        #expect(editor.documentHighlightBracket == Tokens.Color(hex: 0x7EC8DE33))
    }

    @Test("ChromeColors populates")
    func chromeColors() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "title_bar.background": Tokens.Color(hex: 0x111111),
            "title_bar.inactive_background": Tokens.Color(hex: 0x121212),
            "tab_bar.background": Tokens.Color(hex: 0x131313),
            "tab.active_background": Tokens.Color(hex: 0x141414),
            "tab.inactive_background": Tokens.Color(hex: 0x151515),
            "status_bar.background": Tokens.Color(hex: 0x161616),
            "toolbar.background": Tokens.Color(hex: 0x171717),
            "surface.background": Tokens.Color(hex: 0x181818),
            "elevated_surface.background": Tokens.Color(hex: 0x191919),
            "panel.background": Tokens.Color(hex: 0x1A1A1A),
            "panel.focused_border": Tokens.Color(hex: 0x1B1B1B),
            "panel.indent_guide": Tokens.Color(hex: 0x1C1C1C),
            "panel.indent_guide_active": Tokens.Color(hex: 0x1D1D1D),
            "panel.indent_guide_hover": Tokens.Color(hex: 0x1E1E1E),
            "pane.focused_border": Tokens.Color(hex: 0x1F1F1F),
            "pane_group.border": Tokens.Color(hex: 0x202020)
        ]
        let chrome = ChromeColors(flat: flat, warnings: collector, path: "style")
        #expect(chrome.titleBarBackground == Tokens.Color(hex: 0x111111))
        #expect(chrome.paneGroupBorder == Tokens.Color(hex: 0x202020))
    }

    @Test("ElementStates populates element.* and ghost_element.*")
    func elementStates() {
        let collector = WarningCollector()
        let flat: [String: Tokens.Color] = [
            "element.background": Tokens.Color(hex: 0x111111),
            "element.hover": Tokens.Color(hex: 0x222222),
            "element.active": Tokens.Color(hex: 0x333333),
            "element.selected": Tokens.Color(hex: 0x444444),
            "element.disabled": Tokens.Color(hex: 0x555555),
            "ghost_element.background": Tokens.Color(hex: 0x661111),
            "ghost_element.hover": Tokens.Color(hex: 0x662222),
            "ghost_element.active": Tokens.Color(hex: 0x663333),
            "ghost_element.selected": Tokens.Color(hex: 0x664444),
            "ghost_element.disabled": Tokens.Color(hex: 0x665555)
        ]
        let elements = ElementStates(flat: flat, warnings: collector, path: "style")
        #expect(elements.element.background == Tokens.Color(hex: 0x111111))
        #expect(elements.ghostElement.disabled == Tokens.Color(hex: 0x665555))
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `swift test --filter SubStructFlatInitTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement each sub-struct following the `TextLevels` pattern**

Each file follows the same shape. For brevity, the plan shows `IconLevels.swift` in full and lists per-struct field/key tables for the others. The `flatten(into:)` method, `extras` filter, and `knownKeys` set follow `TextLevels` mechanically.

```swift
// Sources/CodeEditorPlugin/Theming/IconLevels.swift
import CodeEditorDesignTokens
import Foundation

public struct IconLevels: Hashable, Sendable, Codable {
    public let base: Tokens.Color
    public let muted: Tokens.Color
    public let placeholder: Tokens.Color
    public let disabled: Tokens.Color
    public let accent: Tokens.Color
    public let extras: [String: Tokens.Color]

    public init(base: Tokens.Color, muted: Tokens.Color, placeholder: Tokens.Color,
                disabled: Tokens.Color, accent: Tokens.Color, extras: [String: Tokens.Color] = [:]) {
        self.base = base; self.muted = muted; self.placeholder = placeholder
        self.disabled = disabled; self.accent = accent; self.extras = extras
    }

    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        let appearance: Theme.Appearance = .dark
        self.base = flat["icon"]
            ?? warnings.missing(path: path, key: "icon", fallback: ThemeFallbackPalette.iconBase(appearance))
        self.muted = flat["icon.muted"]
            ?? warnings.missing(path: path, key: "icon.muted", fallback: ThemeFallbackPalette.iconMuted(appearance))
        self.placeholder = flat["icon.placeholder"]
            ?? warnings.missing(path: path, key: "icon.placeholder", fallback: ThemeFallbackPalette.iconPlaceholder(appearance))
        self.disabled = flat["icon.disabled"]
            ?? warnings.missing(path: path, key: "icon.disabled", fallback: ThemeFallbackPalette.iconDisabled(appearance))
        self.accent = flat["icon.accent"]
            ?? warnings.missing(path: path, key: "icon.accent", fallback: ThemeFallbackPalette.iconAccent(appearance))
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("icon.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    func flatten(into dict: inout [String: Tokens.Color]) {
        dict["icon"] = base
        dict["icon.muted"] = muted
        dict["icon.placeholder"] = placeholder
        dict["icon.disabled"] = disabled
        dict["icon.accent"] = accent
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = ["icon", "icon.muted", "icon.placeholder", "icon.disabled", "icon.accent"]
}
```

For `BorderColors`, `ScrollbarColors`, `SearchColors`, `PredictiveColors`, `HintColors`, `EditorColors`, `ChromeColors`: write the analogous file. Use the routing tables above. For each:
- `public let` fields one per known suffix.
- `init(base:..., extras:)` memberwise.
- `init(flat:warnings:path:)` reading each suffix with `?? warnings.missing(...)` fallback.
- `flatten(into:)` writing each.
- `static let knownKeys: Set<String>` for the extras filter.

For `StatusPalette` and `VCSPalette` use a nested `Status` (or `VCS`) sub-struct:

```swift
// Sources/CodeEditorPlugin/Theming/StatusPalette.swift
import CodeEditorDesignTokens
import Foundation

public struct StatusPalette: Hashable, Sendable, Codable {
    public struct Status: Hashable, Sendable, Codable {
        public let base: Tokens.Color
        public let background: Tokens.Color
        public let border: Tokens.Color
    }

    public let info: Status
    public let success: Status
    public let warning: Status
    public let error: Status
    public let conflict: Status

    public init(info: Status, success: Status, warning: Status, error: Status, conflict: Status) {
        self.info = info; self.success = success; self.warning = warning
        self.error = error; self.conflict = conflict
    }

    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        let appearance: Theme.Appearance = .dark
        func make(_ kind: String, fallbackKind: ThemeFallbackPalette.StatusKind) -> Status {
            let base = flat[kind] ?? warnings.missing(path: path, key: kind,
                fallback: ThemeFallbackPalette.status(fallbackKind, appearance: appearance))
            let bg = flat["\(kind).background"] ?? warnings.missing(path: path, key: "\(kind).background",
                fallback: Tokens.Color(red: base.red, green: base.green, blue: base.blue, alpha: 0.15))
            let border = flat["\(kind).border"] ?? warnings.missing(path: path, key: "\(kind).border", fallback: base)
            return Status(base: base, background: bg, border: border)
        }
        self.info = make("info", fallbackKind: .info)
        self.success = make("success", fallbackKind: .success)
        self.warning = make("warning", fallbackKind: .warning)
        self.error = make("error", fallbackKind: .error)
        self.conflict = make("conflict", fallbackKind: .conflict)
    }

    func flatten(into dict: inout [String: Tokens.Color]) {
        for (kind, status) in [("info", info), ("success", success), ("warning", warning), ("error", error), ("conflict", conflict)] {
            dict[kind] = status.base
            dict["\(kind).background"] = status.background
            dict["\(kind).border"] = status.border
        }
    }
}
```

`VCSPalette` follows the identical pattern with seven kinds (`created`, `modified`, `deleted`, `renamed`, `ignored`, `hidden`, `unreachable`) and the per-kind fallback mapping listed in the routing table above.

For `ElementStates`, use a nested `States { background, hover, active, selected, disabled }` sub-struct decoded twice — once for `element.*` keys, once for `ghost_element.*` — exposed as `element` and `ghostElement`.

- [ ] **Step 4: Run tests**

Run: `swift test --filter SubStructFlatInitTests`
Expected: PASS — eight tests green.

- [ ] **Step 5: Build + lint**

Run: `swift build && swiftlint lint Sources/CodeEditorPlugin/Theming`
Expected: builds; zero violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/IconLevels.swift \
         Sources/CodeEditorPlugin/Theming/BorderColors.swift \
         Sources/CodeEditorPlugin/Theming/ScrollbarColors.swift \
         Sources/CodeEditorPlugin/Theming/SearchColors.swift \
         Sources/CodeEditorPlugin/Theming/PredictiveColors.swift \
         Sources/CodeEditorPlugin/Theming/HintColors.swift \
         Sources/CodeEditorPlugin/Theming/StatusPalette.swift \
         Sources/CodeEditorPlugin/Theming/VCSPalette.swift \
         Sources/CodeEditorPlugin/Theming/EditorColors.swift \
         Sources/CodeEditorPlugin/Theming/ChromeColors.swift \
         Sources/CodeEditorPlugin/Theming/ElementStates.swift \
         Tests/CodeEditorPluginTests/Theming/SubStructFlatInitTests.swift
git commit -m "$(cat <<'EOF'
Theming: remaining flat-prefix sub-structs

Eleven sub-struct types (Icon/Border/Scrollbar/Search/Predictive/Hint/
Status/VCS/Editor/Chrome/ElementStates) following the TextLevels pattern.
Each owns a per-prefix overflow bag for unknown keys.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `PlatformExtension` with `derived(from:appearance:)` factory

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/PlatformExtension.swift`
- Test: `Tests/CodeEditorPluginTests/Theming/PlatformExtensionDerivedTests.swift`

`PlatformExtension` is decoded directly from the `platform` JSON object (when present) or **synthesized** from a `ThemeStyle` (when absent). It always lands as a non-optional field on `Theme`.

- [ ] **Step 1: Failing test**

```swift
// Tests/CodeEditorPluginTests/Theming/PlatformExtensionDerivedTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("PlatformExtension")
struct PlatformExtensionDerivedTests {
    @Test("derived from a populated ThemeStyle has non-clear glass tint")
    func derivedHasGlassTint() {
        let style = ThemeStyleFixtures.minimalDark()
        let platform = PlatformExtension.derived(from: style, appearance: .dark)
        #expect(platform.glass.tint != Tokens.Color(hex: 0x000000, alpha: 0))
        #expect(platform.glass.opacity > 0)
    }

    @Test("derived has popover shadow with non-zero blur")
    func derivedHasPopoverShadow() {
        let style = ThemeStyleFixtures.minimalDark()
        let platform = PlatformExtension.derived(from: style, appearance: .dark)
        #expect(platform.shadows.popover.blur > 0)
    }

    @Test("decodes from explicit platform object")
    func decodesExplicitPlatformObject() throws {
        let json = #"""
        {
          "glass": { "tint": "#7EC8DE", "opacity": 0.12 },
          "shadows": { "popover": { "color": "#000000", "blur": 24, "x": 0, "y": 12 } },
          "field": { "fill": "#101010", "border": "#202020", "focused_border": "#0A84FF" }
        }
        """#
        let decoder = JSONDecoder()
        decoder.userInfo[.themeWarnings] = WarningCollector()
        let platform = try decoder.decode(PlatformExtension.self, from: Data(json.utf8))
        #expect(platform.glass.tint == Tokens.Color(hex: 0x7EC8DE))
        #expect(abs(platform.glass.opacity - 0.12) < 1e-9)
        #expect(platform.shadows.popover.blur == 24)
        #expect(platform.field.focusedBorder == Tokens.Color(hex: 0x0A84FF))
    }

    @Test("unknown platform key lands in extras and warns")
    func unknownKeyInExtras() throws {
        let json = #"""
        {
          "glass": { "tint": "#7EC8DE", "opacity": 0.12 },
          "shadows": { "popover": { "color": "#000000", "blur": 1, "x": 0, "y": 1 } },
          "field": { "fill": "#101010", "border": "#202020", "focused_border": "#0A84FF" },
          "weird_key": "#FF0000"
        }
        """#
        let decoder = JSONDecoder()
        let collector = WarningCollector()
        decoder.userInfo[.themeWarnings] = collector
        let platform = try decoder.decode(PlatformExtension.self, from: Data(json.utf8))
        #expect(platform.extras["weird_key"] == Tokens.Color(hex: 0xFF0000))
        #expect(collector.warnings.contains { $0.kind == .unknownPlatformKey })
    }
}

/// Test helpers for a minimal but populated ThemeStyle.
enum ThemeStyleFixtures {
    static func minimalDark() -> ThemeStyle {
        // Implementation comes in Task 6 — at the time this test is *written*
        // there's no ThemeStyle yet. To avoid a forward dependency, the test
        // passes constructor values directly.
        // Replace with: ThemeStyle(...) once Task 6 lands.
        // For now, inline a stub.
        return ThemeStyle.makeStubForTesting(
            background: Tokens.Color(hex: 0x020204),
            editorForeground: Tokens.Color(hex: 0xDFE7F1)
        )
    }
}
```

The `ThemeStyle.makeStubForTesting` helper isn't defined yet — Task 6 introduces it as an internal test-support extension. The plan adds the test now and intentionally lets the Task 5 test build ungreen-but-compiles-with-stub once Task 6 lands. **Important sequencing:** if the stub is needed earlier, add a placeholder fixture in the test file with `Tokens.Color`-only fields. Keep the test green for the explicit-decode and unknown-key cases first.

- [ ] **Step 2: Implement `PlatformExtension`**

```swift
// Sources/CodeEditorPlugin/Theming/PlatformExtension.swift
import CodeEditorDesignTokens
import Foundation

/// Platform-specific extension key on Zed JSON. Vanilla Zed doesn't model
/// Liquid Glass / shadows / fields, so this lives under `platform.*` in our
/// JSONs and is synthesized from the rest of the style when absent.
public struct PlatformExtension: Hashable, Sendable, Codable {
    public struct Glass: Hashable, Sendable, Codable {
        public let tint: Tokens.Color
        public let opacity: Double

        public init(tint: Tokens.Color, opacity: Double) {
            self.tint = tint
            self.opacity = opacity
        }
    }

    public struct Shadow: Hashable, Sendable, Codable {
        public let color: Tokens.Color
        public let blur: Double
        public let x: Double
        public let y: Double

        public init(color: Tokens.Color, blur: Double, x: Double, y: Double) {
            self.color = color; self.blur = blur; self.x = x; self.y = y
        }

        private enum CodingKeys: String, CodingKey {
            case color, blur, x, y
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector ?? WarningCollector()
            let colorHex = try container.decode(String.self, forKey: .color)
            self.color = ZedColorBridge.parse(colorHex, path: "platform.shadows.popover.color", warnings: warnings)
                ?? Tokens.Color(hex: 0x000000, alpha: 0.5)
            self.blur = try container.decode(Double.self, forKey: .blur)
            self.x = try container.decode(Double.self, forKey: .x)
            self.y = try container.decode(Double.self, forKey: .y)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ZedColorBridge.encode(color), forKey: .color)
            try container.encode(blur, forKey: .blur)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
        }
    }

    public struct Shadows: Hashable, Sendable, Codable {
        public let popover: Shadow

        public init(popover: Shadow) { self.popover = popover }
    }

    public struct Field: Hashable, Sendable, Codable {
        public let fill: Tokens.Color
        public let border: Tokens.Color
        public let focusedBorder: Tokens.Color

        public init(fill: Tokens.Color, border: Tokens.Color, focusedBorder: Tokens.Color) {
            self.fill = fill; self.border = border; self.focusedBorder = focusedBorder
        }

        private enum CodingKeys: String, CodingKey {
            case fill, border
            case focusedBorder = "focused_border"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector ?? WarningCollector()
            let fillHex = try container.decode(String.self, forKey: .fill)
            let borderHex = try container.decode(String.self, forKey: .border)
            let focusedHex = try container.decode(String.self, forKey: .focusedBorder)
            self.fill = ZedColorBridge.parse(fillHex, path: "platform.field.fill", warnings: warnings)
                ?? Tokens.Color(hex: 0x101010)
            self.border = ZedColorBridge.parse(borderHex, path: "platform.field.border", warnings: warnings)
                ?? Tokens.Color(hex: 0x202020)
            self.focusedBorder = ZedColorBridge.parse(focusedHex, path: "platform.field.focused_border", warnings: warnings)
                ?? Tokens.Palette.Accent.dark
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ZedColorBridge.encode(fill), forKey: .fill)
            try container.encode(ZedColorBridge.encode(border), forKey: .border)
            try container.encode(ZedColorBridge.encode(focusedBorder), forKey: .focusedBorder)
        }
    }

    public let glass: Glass
    public let shadows: Shadows
    public let field: Field
    public let extras: [String: Tokens.Color]

    public init(glass: Glass, shadows: Shadows, field: Field, extras: [String: Tokens.Color] = [:]) {
        self.glass = glass; self.shadows = shadows; self.field = field; self.extras = extras
    }

    private enum CodingKeys: String, CodingKey {
        case glass, shadows, field
    }

    public init(from decoder: Decoder) throws {
        // Decode known keys via the keyed container, then re-decode the same
        // payload via DynamicCodingKey to discover unknown keys for `extras`.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let glassContainer = try container.nestedContainer(keyedBy: GlassCodingKeys.self, forKey: .glass)
        let shadowsContainer = try container.nestedContainer(keyedBy: ShadowsCodingKeys.self, forKey: .shadows)
        _ = shadowsContainer  // silence unused — we decode below

        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector ?? WarningCollector()

        let tintHex = try glassContainer.decode(String.self, forKey: .tint)
        let opacity = try glassContainer.decode(Double.self, forKey: .opacity)
        let tint = ZedColorBridge.parse(tintHex, path: "platform.glass.tint", warnings: warnings)
            ?? Tokens.Color(hex: 0x7EC8DE)
        self.glass = Glass(tint: tint, opacity: opacity)
        self.shadows = try container.decode(Shadows.self, forKey: .shadows)
        self.field = try container.decode(Field.self, forKey: .field)

        // Pass 2: unknown keys → extras
        let dynContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var extras: [String: Tokens.Color] = [:]
        let known: Set<String> = ["glass", "shadows", "field"]
        for key in dynContainer.allKeys where !known.contains(key.stringValue) {
            if let hex = try? dynContainer.decode(String.self, forKey: key),
               let color = ZedColorBridge.parse(hex, path: "platform.\(key.stringValue)", warnings: warnings) {
                warnings.record(.init(kind: .unknownPlatformKey, keyPath: "platform.\(key.stringValue)", detail: nil))
                extras[key.stringValue] = color
            }
        }
        self.extras = extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(glass, forKey: .glass)
        try container.encode(shadows, forKey: .shadows)
        try container.encode(field, forKey: .field)
        if !extras.isEmpty {
            var dyn = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in extras {
                try dyn.encode(ZedColorBridge.encode(value), forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }

    private enum GlassCodingKeys: String, CodingKey { case tint, opacity }
    private enum ShadowsCodingKeys: String, CodingKey { case popover }

    /// Synthesize a PlatformExtension from a ThemeStyle when the JSON omits
    /// the `platform` key. Glass tint = editor.background at 12% alpha;
    /// popover shadow = soft drop tuned to appearance; field colors derived
    /// from element states.
    public static func derived(from style: ThemeStyle, appearance: Theme.Appearance) -> PlatformExtension {
        let bg = style.editor.background
        let glassTint = Tokens.Color(red: bg.red, green: bg.green, blue: bg.blue, alpha: 0.12)
        let shadowColor = appearance == .dark
            ? Tokens.Color(hex: 0x000000, alpha: 0.55)
            : Tokens.Color(hex: 0x000000, alpha: 0.18)
        let popover = Shadow(color: shadowColor, blur: 24, x: 0, y: 12)
        let field = Field(
            fill: style.elements.element.background,
            border: style.borders.base,
            focusedBorder: style.borders.focused
        )
        return PlatformExtension(
            glass: Glass(tint: glassTint, opacity: 0.12),
            shadows: Shadows(popover: popover),
            field: field
        )
    }
}
```

- [ ] **Step 3: Add a test-only stub helper for `ThemeStyle`**

Add this method to `ThemeStyleFixtures` once Task 6 lands. For Task 5 in isolation, the explicit-decode and unknown-key tests pass; the `derived(...)` tests stay marked `@Test(.disabled())` until Task 6 wires up `ThemeStyleFixtures.minimalDark()`.

- [ ] **Step 4: Run tests**

Run: `swift test --filter PlatformExtensionDerivedTests`
Expected: explicit-decode and unknown-key tests PASS; derived-from tests SKIPPED (or remove until Task 6).

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/PlatformExtension.swift \
         Tests/CodeEditorPluginTests/Theming/PlatformExtensionDerivedTests.swift
git commit -m "$(cat <<'EOF'
Theming: PlatformExtension with derived defaults

Models Liquid Glass / popover shadow / field — the things vanilla Zed
doesn't. Decodes from an explicit `platform` object when present; can be
synthesized from a ThemeStyle via derived(from:appearance:) when absent.
Unknown platform.* keys land in self.extras and emit
.unknownPlatformKey warnings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `ThemeStyle` top-level decoder + encoder

This is the central routing logic. `ThemeStyle.init(from:)` walks the flat Zed `style` object once, partitioning keys by prefix and routing to the right sub-struct constructors.

**Files:**
- Modify: nothing, but create `Sources/CodeEditorPlugin/Theming/ThemeStyle.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/ThemeStyleDecoderTests.swift`

- [ ] **Step 1: Failing test**

```swift
// Tests/CodeEditorPluginTests/Theming/ThemeStyleDecoderTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("ThemeStyle top-level decoder")
struct ThemeStyleDecoderTests {
    @Test("routes flat dotted keys into the right sub-structs")
    func routesFlatKeys() throws {
        let json = #"""
        {
          "background": "#020204",
          "background.appearance": "opaque",
          "surface.background": "#07090F",
          "elevated_surface.background": "#10121C",
          "editor.background": "#010204",
          "editor.foreground": "#DFE7F1",
          "editor.gutter.background": "#05070D",
          "editor.active_line.background": "#7EC8DE12",
          "editor.highlighted_line.background": "#B5A7FF1F",
          "editor.active_line_number": "#7EC8DE",
          "editor.line_number": "#5D6B7F",
          "editor.invisible": "#1B2433",
          "editor.indent_guide": "#121826",
          "editor.indent_guide_active": "#7EC8DE",
          "editor.wrap_guide": "#121826",
          "editor.active_wrap_guide": "#B5A7FF",
          "editor.subheader.background": "#05070D",
          "editor.document_highlight.read_background": "#7EC8DE24",
          "editor.document_highlight.write_background": "#B5A7FF26",
          "editor.document_highlight.bracket_background": "#7EC8DE33",
          "title_bar.background": "#080B12",
          "title_bar.inactive_background": "#05070D",
          "tab_bar.background": "#020204",
          "tab.active_background": "#10121C",
          "tab.inactive_background": "#05070D",
          "status_bar.background": "#080B12",
          "toolbar.background": "#080B12",
          "panel.background": "#080B12",
          "panel.focused_border": "#C7E9F1",
          "panel.indent_guide": "#121826",
          "panel.indent_guide_active": "#7EC8DE",
          "panel.indent_guide_hover": "#B5A7FF",
          "pane.focused_border": "#7EC8DE",
          "pane_group.border": "#121826",
          "border": "#1A2232",
          "border.disabled": "#10121C",
          "border.focused": "#7EC8DE",
          "border.selected": "#B5A7FF",
          "border.transparent": "#7EC8DE00",
          "border.variant": "#121826",
          "text": "#DFE7F1",
          "text.muted": "#8B99AB",
          "text.placeholder": "#68778C",
          "text.disabled": "#4F5D70",
          "text.accent": "#C7E9F1",
          "icon": "#C5D1DF",
          "icon.muted": "#768699",
          "icon.placeholder": "#5D6B7F",
          "icon.disabled": "#364253",
          "icon.accent": "#7EC8DE",
          "element.background": "#10121C",
          "element.hover": "#151C2B",
          "element.active": "#1B273A",
          "element.selected": "#252041",
          "element.disabled": "#080B12",
          "ghost_element.background": "#00000000",
          "ghost_element.hover": "#7EC8DE18",
          "ghost_element.active": "#7EC8DE2B",
          "ghost_element.selected": "#B5A7FF33",
          "ghost_element.disabled": "#10121C88",
          "drop_target.background": "#B5A7FF2E",
          "scrollbar.track.background": "#020204",
          "scrollbar.track.border": "#121826",
          "scrollbar.thumb.background": "#7EC8DE99",
          "scrollbar.thumb.border": "#B5A7FF",
          "scrollbar.thumb.hover_background": "#C7E9F1AA",
          "search.match_background": "#B5A7FF66",
          "predictive": "#8B99AB",
          "predictive.background": "#7EC8DE1D",
          "predictive.border": "#257EA7",
          "hint": "#7EC8DE",
          "hint.background": "#102838",
          "hint.border": "#257EA7",
          "info": "#7EC8DE", "info.background": "#102838", "info.border": "#257EA7",
          "success": "#4EE6A6", "success.background": "#0F2A21", "success.border": "#2F9F68",
          "warning": "#FF9933", "warning.background": "#33210D", "warning.border": "#FF9933",
          "error": "#FF7373", "error.background": "#341519", "error.border": "#EF5A5A",
          "conflict": "#FF9933", "conflict.background": "#33210D", "conflict.border": "#FF9933",
          "created": "#4EE6A6", "created.background": "#0F2A21", "created.border": "#2F9F68",
          "modified": "#7EC8DE", "modified.background": "#102838", "modified.border": "#257EA7",
          "deleted": "#FF7373", "deleted.background": "#341519", "deleted.border": "#EF5A5A",
          "renamed": "#B5A7FF", "renamed.background": "#211D36", "renamed.border": "#7566D8",
          "ignored": "#4F5D70", "ignored.background": "#05070D", "ignored.border": "#121826",
          "hidden": "#364253", "hidden.background": "#05070D", "hidden.border": "#10121C",
          "unreachable": "#68727C", "unreachable.background": "#10121C", "unreachable.border": "#1A2232",
          "link_text.hover": "#C7E9F1",
          "players": [
            { "background": "#7EC8DE33", "cursor": "#7EC8DE", "selection": "#7EC8DE26" }
          ],
          "accents": [ "#7EC8DE", "#C7E9F1", "#B5A7FF" ],
          "syntax": {
            "keyword": { "color": "#C7E9F1", "font_weight": 800 },
            "string":  { "color": "#7EC8DE" }
          }
        }
        """#
        let decoder = JSONDecoder()
        let collector = WarningCollector()
        decoder.userInfo[.themeWarnings] = collector
        let style = try decoder.decode(ThemeStyle.self, from: Data(json.utf8))

        #expect(style.background == Tokens.Color(hex: 0x020204))
        #expect(style.backgroundAppearance == "opaque")
        #expect(style.editor.background == Tokens.Color(hex: 0x010204))
        #expect(style.text.muted == Tokens.Color(hex: 0x8B99AB))
        #expect(style.elements.element.background == Tokens.Color(hex: 0x10121C))
        #expect(style.scrollbar.thumbHoverBackground == Tokens.Color(hex: 0xC7E9F1, alpha: 170.0/255.0))
        #expect(style.status.warning.base == Tokens.Color(hex: 0xFF9933))
        #expect(style.vcs.deleted.background == Tokens.Color(hex: 0x341519))
        #expect(style.dropTarget.alpha < 0.5)
        #expect(style.players.count == 1)
        #expect(style.accents.count == 3)
        #expect(style.syntax["keyword"]?.fontWeight == 800)
        #expect(collector.warnings.isEmpty)
    }

    @Test("encoder produces a flat-keyed object that decodes back equally")
    func encoderRoundtrips() throws {
        let json = #"""
        {
          "background": "#020204",
          "editor.background": "#010204",
          "editor.foreground": "#DFE7F1",
          "text": "#DFE7F1",
          "text.muted": "#8B99AB",
          "text.placeholder": "#68778C",
          "text.disabled": "#4F5D70",
          "text.accent": "#C7E9F1",
          "players": [{ "cursor": "#7EC8DE", "selection": "#7EC8DE26" }],
          "accents": [],
          "syntax": {}
        }
        """#
        let decoder1 = JSONDecoder()
        decoder1.userInfo[.themeWarnings] = WarningCollector()
        let style1 = try decoder1.decode(ThemeStyle.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(style1)
        let decoder2 = JSONDecoder()
        decoder2.userInfo[.themeWarnings] = WarningCollector()
        let style2 = try decoder2.decode(ThemeStyle.self, from: encoded)
        #expect(style1.editor.background == style2.editor.background)
        #expect(style1.text.muted == style2.text.muted)
    }
}
```

- [ ] **Step 2: Implement `ThemeStyle`**

```swift
// Sources/CodeEditorPlugin/Theming/ThemeStyle.swift
import CodeEditorDesignTokens
import Foundation

/// The full visual surface of a theme. Decoded from Zed's flat dotted
/// `style` object via custom Codable; each sub-struct receives a slice of
/// the flat dictionary scoped to its prefix.
public struct ThemeStyle: Hashable, Sendable, Codable {
    public let background: Tokens.Color
    public let backgroundAppearance: String?
    public let editor: EditorColors
    public let chrome: ChromeColors
    public let elements: ElementStates
    public let borders: BorderColors
    public let text: TextLevels
    public let icon: IconLevels
    public let status: StatusPalette
    public let vcs: VCSPalette
    public let scrollbar: ScrollbarColors
    public let search: SearchColors
    public let predictive: PredictiveColors
    public let hint: HintColors
    public let dropTarget: Tokens.Color
    public let linkTextHover: Tokens.Color
    public let players: [Player]
    public let accents: [Tokens.Color]
    public let syntax: [String: SyntaxStyle]
    public let terminal: TerminalColors?
    public let extras: [String: Tokens.Color]

    public init(
        background: Tokens.Color, backgroundAppearance: String?,
        editor: EditorColors, chrome: ChromeColors, elements: ElementStates,
        borders: BorderColors, text: TextLevels, icon: IconLevels,
        status: StatusPalette, vcs: VCSPalette, scrollbar: ScrollbarColors,
        search: SearchColors, predictive: PredictiveColors, hint: HintColors,
        dropTarget: Tokens.Color, linkTextHover: Tokens.Color,
        players: [Player], accents: [Tokens.Color],
        syntax: [String: SyntaxStyle], terminal: TerminalColors?,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.background = background; self.backgroundAppearance = backgroundAppearance
        self.editor = editor; self.chrome = chrome; self.elements = elements
        self.borders = borders; self.text = text; self.icon = icon
        self.status = status; self.vcs = vcs; self.scrollbar = scrollbar
        self.search = search; self.predictive = predictive; self.hint = hint
        self.dropTarget = dropTarget; self.linkTextHover = linkTextHover
        self.players = players; self.accents = accents
        self.syntax = syntax; self.terminal = terminal; self.extras = extras
    }

    public init(from decoder: Decoder) throws {
        let warnings = decoder.userInfo[.themeWarnings] as? WarningCollector ?? WarningCollector()
        let dyn = try decoder.container(keyedBy: DynamicCodingKey.self)

        // Pass 1: separate structured keys from flat color keys.
        let structuredKeys: Set<String> = [
            "syntax", "players", "accents", "platform", "terminal"
        ]
        let stringKeys: Set<String> = ["background.appearance"]

        var flat: [String: Tokens.Color] = [:]
        var bgAppearance: String? = nil
        for key in dyn.allKeys {
            if structuredKeys.contains(key.stringValue) { continue }
            if stringKeys.contains(key.stringValue) {
                bgAppearance = try? dyn.decode(String.self, forKey: key)
                continue
            }
            // Color-valued key; bridge through ZedColorBridge.
            if let hex = try? dyn.decode(String.self, forKey: key),
               let color = ZedColorBridge.parse(hex, path: key.stringValue, warnings: warnings) {
                flat[key.stringValue] = color
            }
        }

        self.background = flat["background"]
            ?? warnings.missing(path: "style", key: "background", fallback: ThemeFallbackPalette.background(.dark))
        self.backgroundAppearance = bgAppearance
        self.dropTarget = flat["drop_target.background"]
            ?? warnings.missing(path: "style", key: "drop_target.background", fallback: ThemeFallbackPalette.dropTarget(.dark))
        self.linkTextHover = flat["link_text.hover"]
            ?? warnings.missing(path: "style", key: "link_text.hover", fallback: ThemeFallbackPalette.textAccent(.dark))

        self.editor = EditorColors(flat: flat, warnings: warnings, path: "style")
        self.chrome = ChromeColors(flat: flat, warnings: warnings, path: "style")
        self.elements = ElementStates(flat: flat, warnings: warnings, path: "style")
        self.borders = BorderColors(flat: flat, warnings: warnings, path: "style")
        self.text = TextLevels(flat: flat, warnings: warnings, path: "style")
        self.icon = IconLevels(flat: flat, warnings: warnings, path: "style")
        self.status = StatusPalette(flat: flat, warnings: warnings, path: "style")
        self.vcs = VCSPalette(flat: flat, warnings: warnings, path: "style")
        self.scrollbar = ScrollbarColors(flat: flat, warnings: warnings, path: "style")
        self.search = SearchColors(flat: flat, warnings: warnings, path: "style")
        self.predictive = PredictiveColors(flat: flat, warnings: warnings, path: "style")
        self.hint = HintColors(flat: flat, warnings: warnings, path: "style")

        // Pass 2: structured maps and arrays.
        self.syntax = (try? dyn.decode([String: SyntaxStyle].self, forKey: DynamicCodingKey(stringValue: "syntax"))) ?? [:]
        self.players = (try? dyn.decode([Player].self, forKey: DynamicCodingKey(stringValue: "players"))) ?? []
        let accentsHex = (try? dyn.decode([String].self, forKey: DynamicCodingKey(stringValue: "accents"))) ?? []
        self.accents = accentsHex.compactMap {
            ZedColorBridge.parse($0, path: "style.accents", warnings: warnings)
        }
        self.terminal = try? dyn.decode(TerminalColors.self, forKey: DynamicCodingKey(stringValue: "terminal"))

        // Pass 3: collect any flat keys that didn't land in a known sub-struct.
        let consumedKeys = Self.consumedFlatKeys(from: flat,
            editor: editor, chrome: chrome, elements: elements,
            borders: borders, text: text, icon: icon,
            status: status, vcs: vcs, scrollbar: scrollbar,
            search: search, predictive: predictive, hint: hint
        )
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { !consumedKeys.contains($0.key) }.map { ($0.key, $0.value) })
    }

    public func encode(to encoder: Encoder) throws {
        var dyn = encoder.container(keyedBy: DynamicCodingKey.self)
        var flat: [String: Tokens.Color] = [:]
        flat["background"] = background
        flat["drop_target.background"] = dropTarget
        flat["link_text.hover"] = linkTextHover
        editor.flatten(into: &flat)
        chrome.flatten(into: &flat)
        elements.flatten(into: &flat)
        borders.flatten(into: &flat)
        text.flatten(into: &flat)
        icon.flatten(into: &flat)
        status.flatten(into: &flat)
        vcs.flatten(into: &flat)
        scrollbar.flatten(into: &flat)
        search.flatten(into: &flat)
        predictive.flatten(into: &flat)
        hint.flatten(into: &flat)
        for (key, value) in extras { flat[key] = value }

        for (key, value) in flat {
            try dyn.encode(ZedColorBridge.encode(value), forKey: DynamicCodingKey(stringValue: key))
        }
        if let bgAppearance = backgroundAppearance {
            try dyn.encode(bgAppearance, forKey: DynamicCodingKey(stringValue: "background.appearance"))
        }
        try dyn.encode(syntax, forKey: DynamicCodingKey(stringValue: "syntax"))
        try dyn.encode(players, forKey: DynamicCodingKey(stringValue: "players"))
        try dyn.encode(accents.map(ZedColorBridge.encode), forKey: DynamicCodingKey(stringValue: "accents"))
        if let terminal { try dyn.encode(terminal, forKey: DynamicCodingKey(stringValue: "terminal")) }
    }

    private static func consumedFlatKeys(
        from flat: [String: Tokens.Color],
        editor: EditorColors, chrome: ChromeColors, elements: ElementStates,
        borders: BorderColors, text: TextLevels, icon: IconLevels,
        status: StatusPalette, vcs: VCSPalette, scrollbar: ScrollbarColors,
        search: SearchColors, predictive: PredictiveColors, hint: HintColors
    ) -> Set<String> {
        var consumed: Set<String> = ["background", "drop_target.background", "link_text.hover"]
        var probe: [String: Tokens.Color] = [:]
        editor.flatten(into: &probe);   chrome.flatten(into: &probe)
        elements.flatten(into: &probe); borders.flatten(into: &probe)
        text.flatten(into: &probe);     icon.flatten(into: &probe)
        status.flatten(into: &probe);   vcs.flatten(into: &probe)
        scrollbar.flatten(into: &probe); search.flatten(into: &probe)
        predictive.flatten(into: &probe); hint.flatten(into: &probe)
        consumed.formUnion(probe.keys)
        return consumed
    }
}

#if DEBUG
extension ThemeStyle {
    /// Test-only convenience used by ThemeStyleFixtures.
    static func makeStubForTesting(
        background: Tokens.Color = Tokens.Color(hex: 0x020204),
        editorForeground: Tokens.Color = Tokens.Color(hex: 0xDFE7F1)
    ) -> ThemeStyle {
        // Minimal: every required field gets a usable but cheap value.
        let collector = WarningCollector()
        let editor = EditorColors(flat: ["editor.background": background, "editor.foreground": editorForeground],
                                  warnings: collector, path: "test")
        let chrome = ChromeColors(flat: [:], warnings: collector, path: "test")
        let elements = ElementStates(flat: [:], warnings: collector, path: "test")
        let borders = BorderColors(flat: [:], warnings: collector, path: "test")
        let text = TextLevels(flat: [:], warnings: collector, path: "test")
        let icon = IconLevels(flat: [:], warnings: collector, path: "test")
        let status = StatusPalette(flat: [:], warnings: collector, path: "test")
        let vcs = VCSPalette(flat: [:], warnings: collector, path: "test")
        let scrollbar = ScrollbarColors(flat: [:], warnings: collector, path: "test")
        let search = SearchColors(flat: [:], warnings: collector, path: "test")
        let predictive = PredictiveColors(flat: [:], warnings: collector, path: "test")
        let hint = HintColors(flat: [:], warnings: collector, path: "test")
        return ThemeStyle(
            background: background, backgroundAppearance: nil,
            editor: editor, chrome: chrome, elements: elements,
            borders: borders, text: text, icon: icon,
            status: status, vcs: vcs, scrollbar: scrollbar,
            search: search, predictive: predictive, hint: hint,
            dropTarget: ThemeFallbackPalette.dropTarget(.dark),
            linkTextHover: ThemeFallbackPalette.textAccent(.dark),
            players: [], accents: [], syntax: [:], terminal: nil
        )
    }
}
#endif
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter ThemeStyleDecoderTests`
Expected: PASS — both tests green.

- [ ] **Step 4: Re-run the platform-extension test that depended on the stub**

Run: `swift test --filter PlatformExtensionDerivedTests`
Expected: previously-disabled `derived from a populated ThemeStyle` and `derived has popover shadow` tests now PASS. Re-enable them by removing `@Test(.disabled())` if present.

- [ ] **Step 5: Build + lint**

Run: `swift build && swiftlint lint Sources/CodeEditorPlugin/Theming`
Expected: builds; zero violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/ThemeStyle.swift \
         Tests/CodeEditorPluginTests/Theming/ThemeStyleDecoderTests.swift \
         Tests/CodeEditorPluginTests/Theming/PlatformExtensionDerivedTests.swift
git commit -m "$(cat <<'EOF'
Theming: ThemeStyle top-level decoder + encoder

Three-pass init(from:) — flat color keys to a [String: Tokens.Color]
dictionary, structured keys (syntax/players/accents/terminal) decoded
directly, and unknown flat keys collected into self.extras after every
sub-struct has consumed its own. Encoder mirrors the decode path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `Theme`, `ThemeFamily`, `Theme.fallback(appearance:)`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Theming/Theme.swift` (replace stub from Task 3)
- Create: `Sources/CodeEditorPlugin/Theming/ThemeFamily.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/FallbackThemeTests.swift`

- [ ] **Step 1: Failing test**

```swift
// Tests/CodeEditorPluginTests/Theming/FallbackThemeTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Theme.fallback")
struct FallbackThemeTests {
    @Test("dark fallback has usable values")
    func darkFallbackUsable() {
        let theme = Theme.fallback(appearance: .dark)
        #expect(theme.appearance == .dark)
        #expect(theme.style.editor.background.alpha == 1)
        #expect(theme.style.editor.background != Tokens.Color(hex: 0x000000, alpha: 0))
        #expect(theme.style.editor.foreground != theme.style.editor.background)
    }

    @Test("light fallback has usable values")
    func lightFallbackUsable() {
        let theme = Theme.fallback(appearance: .light)
        #expect(theme.appearance == .light)
        #expect(theme.style.editor.background != theme.style.editor.foreground)
    }

    @Test("ThemeFamily decodes from a minimal JSON")
    func familyDecodesMinimal() throws {
        let json = #"""
        {
          "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
          "name": "Test Family",
          "themes": [
            {
              "appearance": "dark",
              "name": "Test Dark",
              "style": {
                "background": "#020204",
                "editor.background": "#010204",
                "editor.foreground": "#DFE7F1",
                "players": [{ "cursor": "#7EC8DE", "selection": "#7EC8DE26" }],
                "accents": [],
                "syntax": {}
              }
            }
          ]
        }
        """#
        let family = try ThemeFamily(jsonData: Data(json.utf8))
        #expect(family.name == "Test Family")
        #expect(family.themes.count == 1)
        #expect(family.themes[0].name == "Test Dark")
        #expect(family.theme(named: "Test Dark") != nil)
        #expect(family.theme(named: "Bogus") == nil)
    }
}
```

- [ ] **Step 2: Replace the stub `Theme.swift` with the full type**

```swift
// Sources/CodeEditorPlugin/Theming/Theme.swift
import CodeEditorDesignTokens
import Foundation

/// A complete theme — the unit applied to the editor via `.codeTheme(_:)`.
/// Decoded from Zed v0.2.0 JSON. Always has a non-optional `platform`
/// extension; if the source JSON omits the `platform` key, defaults are
/// synthesized via `PlatformExtension.derived(from:appearance:)`.
public struct Theme: Hashable, Sendable, Codable, Identifiable {
    public enum Appearance: String, Sendable, Hashable, Codable {
        case dark, light
    }

    public var id: String { name }
    public let name: String
    public let appearance: Appearance
    public let style: ThemeStyle
    public let platform: PlatformExtension

    public init(name: String, appearance: Appearance, style: ThemeStyle, platform: PlatformExtension) {
        self.name = name
        self.appearance = appearance
        self.style = style
        self.platform = platform
    }

    private enum CodingKeys: String, CodingKey {
        case name, appearance, style, platform
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.appearance = try container.decode(Appearance.self, forKey: .appearance)
        self.style = try container.decode(ThemeStyle.self, forKey: .style)
        if let explicit = try? container.decode(PlatformExtension.self, forKey: .platform) {
            self.platform = explicit
        } else {
            self.platform = PlatformExtension.derived(from: style, appearance: appearance)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(style, forKey: .style)
        try container.encode(platform, forKey: .platform)
    }

    /// Hard-coded minimum theme assembled from internal fallback colors.
    /// Used when both the bundled themes and user-supplied JSON are
    /// unavailable. Never fails; always returns a usable theme.
    public static func fallback(appearance: Appearance) -> Theme {
        let collector = WarningCollector()
        let style = ThemeStyle(
            background: ThemeFallbackPalette.background(appearance),
            backgroundAppearance: "opaque",
            editor: EditorColors(flat: [:], warnings: collector, path: "fallback"),
            chrome: ChromeColors(flat: [:], warnings: collector, path: "fallback"),
            elements: ElementStates(flat: [:], warnings: collector, path: "fallback"),
            borders: BorderColors(flat: [:], warnings: collector, path: "fallback"),
            text: TextLevels(flat: [:], warnings: collector, path: "fallback"),
            icon: IconLevels(flat: [:], warnings: collector, path: "fallback"),
            status: StatusPalette(flat: [:], warnings: collector, path: "fallback"),
            vcs: VCSPalette(flat: [:], warnings: collector, path: "fallback"),
            scrollbar: ScrollbarColors(flat: [:], warnings: collector, path: "fallback"),
            search: SearchColors(flat: [:], warnings: collector, path: "fallback"),
            predictive: PredictiveColors(flat: [:], warnings: collector, path: "fallback"),
            hint: HintColors(flat: [:], warnings: collector, path: "fallback"),
            dropTarget: ThemeFallbackPalette.dropTarget(appearance),
            linkTextHover: ThemeFallbackPalette.textAccent(appearance),
            players: [Player(cursor: ThemeFallbackPalette.textAccent(appearance),
                             selection: Tokens.Color(red: 0x7E, green: 0xC8, blue: 0xDE, alpha: 0.15),
                             background: nil)],
            accents: [], syntax: [:], terminal: nil
        )
        return Theme(
            name: "Fallback \(appearance.rawValue.capitalized)",
            appearance: appearance,
            style: style,
            platform: PlatformExtension.derived(from: style, appearance: appearance)
        )
    }
}
```

- [ ] **Step 3: Implement `ThemeFamily`**

```swift
// Sources/CodeEditorPlugin/Theming/ThemeFamily.swift
import CodeEditorDesignTokens
import Foundation

/// A named collection of themes. Zed JSONs are family files — even
/// "single-theme" files have a one-element `themes` array.
public struct ThemeFamily: Hashable, Sendable, Codable {
    public let schema: String?
    public let name: String
    public let author: String?
    public let themes: [Theme]

    public init(schema: String? = nil, name: String, author: String? = nil, themes: [Theme]) {
        self.schema = schema
        self.name = name
        self.author = author
        self.themes = themes
    }

    private enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case name, author, themes
    }

    public func theme(named: String) -> Theme? {
        themes.first { $0.name == named }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter FallbackThemeTests`
Expected: PASS — three tests green.

- [ ] **Step 5: Build + lint**

Run: `swift build && swiftlint lint Sources/CodeEditorPlugin/Theming`
Expected: builds; zero violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/Theme.swift \
         Sources/CodeEditorPlugin/Theming/ThemeFamily.swift \
         Tests/CodeEditorPluginTests/Theming/FallbackThemeTests.swift
git commit -m "$(cat <<'EOF'
Theming: Theme + ThemeFamily + Theme.fallback

Replaces the Theme stub with the full type. ThemeFamily wraps the
themes[] array. Theme.fallback(appearance:) hand-builds a minimum
viable theme from the internal fallback palette so the editor always
has something to render.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Loader API surface — `init(jsonData:)`, `init(contentsOf:)`, `loaded(...)`

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/ThemeFamilyLoaderTests.swift`

- [ ] **Step 1: Failing test**

```swift
// Tests/CodeEditorPluginTests/Theming/ThemeFamilyLoaderTests.swift
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("ThemeFamily loader")
struct ThemeFamilyLoaderTests {
    @Test("init(jsonData:) throws on parse error")
    func initJsonDataThrowsOnParseError() {
        #expect(throws: DecodingError.self) {
            _ = try ThemeFamily(jsonData: Data("not json".utf8))
        }
    }

    @Test("loaded(jsonData:) returns warnings for malformed colors")
    func loadedReturnsWarnings() throws {
        let json = #"""
        {
          "name": "Test", "themes": [
            {
              "appearance": "dark", "name": "Test Dark",
              "style": {
                "background": "not-a-color",
                "editor.background": "#010204",
                "editor.foreground": "#DFE7F1",
                "players": [{ "cursor": "#7EC8DE", "selection": "#7EC8DE26" }],
                "accents": [], "syntax": {}
              }
            }
          ]
        }
        """#
        let (family, warnings) = try ThemeFamily.loaded(jsonData: Data(json.utf8))
        #expect(family.themes.count == 1)
        #expect(warnings.contains { $0.kind == .malformedColor })
    }

    @Test("init(contentsOf:) reads from a file URL")
    func initContentsOfReadsFromFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("theme-test-\(UUID().uuidString).json")
        let json = #"""
        {
          "name": "FromFile", "themes": [{
            "appearance": "dark", "name": "FromFile Dark",
            "style": {
              "background": "#020204",
              "editor.background": "#010204",
              "editor.foreground": "#DFE7F1",
              "players": [{ "cursor": "#7EC8DE", "selection": "#7EC8DE26" }],
              "accents": [], "syntax": {}
            }
          }]
        }
        """#
        try Data(json.utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }
        let family = try ThemeFamily(contentsOf: temp)
        #expect(family.name == "FromFile")
    }

    @Test("init(contentsOf:) on missing file throws")
    func initContentsOfMissingFileThrows() {
        let missing = URL(fileURLWithPath: "/tmp/definitely-not-here-\(UUID().uuidString).json")
        #expect(throws: (any Error).self) {
            _ = try ThemeFamily(contentsOf: missing)
        }
    }
}
```

- [ ] **Step 2: Implement the loader**

```swift
// Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift
import Foundation

extension ThemeFamily {
    /// Decode from raw JSON bytes. Throws on parse failure or missing
    /// required top-level fields. Lenient on individual color keys.
    public init(jsonData data: Data) throws {
        let (family, _) = try Self.decode(data: data)
        self = family
    }

    /// Decode from a file URL. Throws on I/O or parse failure.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(jsonData: data)
    }

    /// Decode + collect warnings.
    public static func loaded(jsonData data: Data) throws -> (ThemeFamily, [ThemeWarning]) {
        try decode(data: data)
    }

    /// Decode + collect warnings from a file URL.
    public static func loaded(contentsOf url: URL) throws -> (ThemeFamily, [ThemeWarning]) {
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    private static func decode(data: Data) throws -> (ThemeFamily, [ThemeWarning]) {
        let collector = WarningCollector()
        let decoder = JSONDecoder()
        decoder.userInfo[.themeWarnings] = collector
        let family = try decoder.decode(ThemeFamily.self, from: data)
        return (family, collector.warnings)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter ThemeFamilyLoaderTests`
Expected: PASS — four tests green.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift \
         Tests/CodeEditorPluginTests/Theming/ThemeFamilyLoaderTests.swift
git commit -m "$(cat <<'EOF'
Theming: ThemeFamily loader API

init(jsonData:) and init(contentsOf:) for the throwing path; loaded(...)
variants returning (ThemeFamily, [ThemeWarning]) for callers that want
to surface lenient-decode diagnostics.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Vendor `zed-trek.json`, update `Package.swift`, bundled accessors, `Theme.lcarsDark`

**Files:**
- Create: `Sources/CodeEditorPlugin/Resources/Themes/zed-trek.json` (copied from `~/Downloads/zed-trek/themes/zed-trek.json`)
- Modify: `Package.swift` — add `resources: [.process("Resources/Themes")]` clause
- Modify: `Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift` — add `bundled(_:)`
- Modify: `Sources/CodeEditorPlugin/Theming/Theme.swift` — add `bundled(family:variant:)` and `lcarsDark`
- Create: `Tests/CodeEditorPluginTests/Theming/ZedTrekDecodeTests.swift`

- [ ] **Step 1: Copy the JSON**

```bash
mkdir -p Sources/CodeEditorPlugin/Resources/Themes
cp ~/Downloads/zed-trek/themes/zed-trek.json Sources/CodeEditorPlugin/Resources/Themes/zed-trek.json
```

- [ ] **Step 2: Modify `Package.swift`**

Find the `CodeEditorPlugin` target and add the `resources:` parameter. Replace this section:

```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorDesignTokens",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            exclude: [
                "Info.plist"
            ],
            swiftSettings: swiftSettings
        ),
```

with:

```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorDesignTokens",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Resources/Themes")
            ],
            swiftSettings: swiftSettings
        ),
```

- [ ] **Step 3: Add `ThemeFamily.bundled(_:)`**

Append to `Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift`:

```swift
extension ThemeFamily {
    /// Load a bundled theme family by file basename (without extension).
    /// In sub-project 2 only `"zed-trek"` resolves. Returns nil if the
    /// resource is missing or fails to parse.
    public static func bundled(_ name: String) -> ThemeFamily? {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Themes"
        ) else { return nil }
        return try? ThemeFamily(contentsOf: url)
    }
}
```

- [ ] **Step 4: Add `Theme.bundled(family:variant:)` and `lcarsDark`**

Append to `Sources/CodeEditorPlugin/Theming/Theme.swift`:

```swift
extension Theme {
    /// Load a specific variant from a bundled family. Returns nil if the
    /// family or the named variant is missing.
    public static func bundled(family: String, variant: String) -> Theme? {
        ThemeFamily.bundled(family)?.theme(named: variant)
    }

    /// Library default. Resolves to "LCARS Dark" from the "zed-trek" bundle;
    /// falls back to `Theme.fallback(appearance: .dark)` if the bundle is
    /// somehow absent (build error in normal use).
    public static var lcarsDark: Theme {
        bundled(family: "zed-trek", variant: "LCARS Dark")
            ?? Theme.fallback(appearance: .dark)
    }
}
```

- [ ] **Step 5: Failing test for bundled lookup**

```swift
// Tests/CodeEditorPluginTests/Theming/ZedTrekDecodeTests.swift
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("Zed Trek bundled decode")
struct ZedTrekDecodeTests {
    @Test("ThemeFamily.bundled(\"zed-trek\") loads 20 themes")
    func bundledFamilyLoads() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        #expect(family.themes.count == 20)
    }

    @Test("ThemeFamily.bundled returns nil for unknown name")
    func bundledFamilyMiss() {
        #expect(ThemeFamily.bundled("nonexistent") == nil)
    }

    @Test("Theme.bundled(family:variant:) hits and misses correctly")
    func bundledThemeVariantHitMiss() {
        #expect(Theme.bundled(family: "zed-trek", variant: "LCARS Dark") != nil)
        #expect(Theme.bundled(family: "zed-trek", variant: "Bogus") == nil)
        #expect(Theme.bundled(family: "x", variant: "y") == nil)
    }

    @Test("Theme.lcarsDark resolves from the bundle")
    func lcarsDarkResolves() {
        let theme = Theme.lcarsDark
        #expect(theme.name == "LCARS Dark")
        #expect(theme.appearance == .dark)
    }

    @Test("All 20 Zed Trek variants decode without warnings")
    func allVariantsDecodeCleanly() throws {
        guard let url = Bundle.module.url(
            forResource: "zed-trek", withExtension: "json", subdirectory: "Themes"
        ) else {
            Issue.record("zed-trek.json not bundled")
            return
        }
        let data = try Data(contentsOf: url)
        let (family, warnings) = try ThemeFamily.loaded(jsonData: data)
        #expect(family.themes.count == 20)
        #expect(warnings.isEmpty,
                "Bundled themes should decode cleanly; got \(warnings.count) warnings: \(warnings.prefix(5))")
    }

    @Test("All 20 expected variant names are present")
    func variantNamesMatch() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        let expected: Set<String> = [
            "Black Alert Dark", "Black Alert Light", "Borg Cube Dark", "Borg Cube Light",
            "Command Dark", "Command Light", "Federation Dark", "Federation Light",
            "LCARS Dark", "LCARS Light", "Mission Control Dark", "Mission Control Light",
            "Ready Room Dark", "Ready Room Light", "Red Alert Dark", "Red Alert Light",
            "Sick Bay Dark", "Sick Bay Light", "Yellow Alert Dark", "Yellow Alert Light"
        ]
        #expect(Set(family.themes.map(\.name)) == expected)
    }
}
```

- [ ] **Step 6: Run tests**

Run: `swift test --filter ZedTrekDecodeTests`
Expected: PASS — six tests green. **If `allVariantsDecodeCleanly` reports warnings**, this points at a routing or fallback gap in the sub-struct decoders — investigate the warning paths and extend the decoder rather than relaxing the test.

- [ ] **Step 7: Build, lint, full test sweep**

Run: `swift build && swiftlint && swift test --parallel`
Expected: builds; zero violations; all green.

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorPlugin/Resources/Themes/zed-trek.json \
         Package.swift \
         Sources/CodeEditorPlugin/Theming/Loader/ThemeFamily+Loader.swift \
         Sources/CodeEditorPlugin/Theming/Theme.swift \
         Tests/CodeEditorPluginTests/Theming/ZedTrekDecodeTests.swift
git commit -m "$(cat <<'EOF'
Theming: bundle Zed Trek + bundled accessors + LCARS Dark default

Vendors zed-trek.json (20 variants, authored by ajmcclary) into
Resources/Themes. Adds ThemeFamily.bundled(_:) and
Theme.bundled(family:variant:) for resource lookup. Theme.lcarsDark is
the library default. All 20 variants decode cleanly with zero warnings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Snapshot, lenient-decode, and conformance tests

**Files:**
- Create: `Tests/CodeEditorPluginTests/Theming/ThemeStyleSnapshotTests.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/LenientDecodeTests.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/ThemingConformanceTests.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/ThemeRoundtripTests.swift`

- [ ] **Step 1: Snapshot test for `LCARS Dark`**

```swift
// Tests/CodeEditorPluginTests/Theming/ThemeStyleSnapshotTests.swift
@testable import CodeEditorPlugin
import CustomDump
import Foundation
import SnapshotTesting
import Testing

@Suite("Theme structure snapshots")
struct ThemeStyleSnapshotTests {
    @Test("LCARS Dark style structure (CustomDump)")
    func lcarsDarkStyleSnapshot() {
        let theme = Theme.lcarsDark
        assertSnapshot(of: theme.style, as: .dump)
    }
}
```

- [ ] **Step 2: Lenient-decode tests**

```swift
// Tests/CodeEditorPluginTests/Theming/LenientDecodeTests.swift
@testable import CodeEditorPlugin
import CodeEditorDesignTokens
import Foundation
import Testing

@Suite("Lenient decode")
struct LenientDecodeTests {
    private func minimalThemeJson(extraStyleKeys: [String: String] = [:],
                                  removed: Set<String> = []) -> Data {
        var styleKeys: [String: String] = [
            "background": "#020204",
            "editor.background": "#010204",
            "editor.foreground": "#DFE7F1",
            "editor.gutter.background": "#05070D",
            "text": "#DFE7F1",
            "text.muted": "#8B99AB",
            "text.placeholder": "#68778C",
            "text.disabled": "#4F5D70",
            "text.accent": "#C7E9F1"
        ]
        for (key, value) in extraStyleKeys { styleKeys[key] = value }
        for key in removed { styleKeys.removeValue(forKey: key) }
        let pairs = styleKeys.map { "\"\($0.key)\":\"\($0.value)\"" }.joined(separator: ",")
        let json = """
        {"name":"T","themes":[{"appearance":"dark","name":"T Dark","style":{
        \(pairs),"players":[{"cursor":"#7EC8DE","selection":"#7EC8DE26"}],"accents":[],"syntax":{}
        }}]}
        """
        return Data(json.utf8)
    }

    @Test("missing editor.gutter.background falls back and warns")
    func missingGutterFallsBack() throws {
        let data = minimalThemeJson(removed: ["editor.gutter.background"])
        let (family, warnings) = try ThemeFamily.loaded(jsonData: data)
        let theme = try #require(family.themes.first)
        #expect(theme.style.editor.gutterBackground == ThemeFallbackPalette.background(.dark) ||
                theme.style.editor.gutterBackground != Tokens.Color(hex: 0x000000, alpha: 0))
        #expect(warnings.contains { $0.keyPath == "editor.gutter.background" && $0.kind == .missingKey })
    }

    @Test("malformed hex falls back and warns")
    func malformedHexWarns() throws {
        let data = minimalThemeJson(extraStyleKeys: ["text.muted": "not-a-color"])
        let (_, warnings) = try ThemeFamily.loaded(jsonData: data)
        #expect(warnings.contains { $0.kind == .malformedColor && $0.detail == "not-a-color" })
    }

    @Test("absent platform key derives defaults")
    func absentPlatformDerives() throws {
        let data = minimalThemeJson()
        let (family, _) = try ThemeFamily.loaded(jsonData: data)
        let theme = try #require(family.themes.first)
        #expect(theme.platform.glass.opacity > 0)
        #expect(theme.platform.shadows.popover.blur > 0)
    }

    @Test("emphasis-only syntax entry decodes with no color")
    func emphasisOnlySyntaxEntry() throws {
        // Inline a JSON variant — `minimalThemeJson` doesn't expose syntax customization.
        let json = #"""
        {"name":"T","themes":[{"appearance":"dark","name":"T Dark","style":{
        "background":"#020204","editor.background":"#010204","editor.foreground":"#DFE7F1",
        "players":[{"cursor":"#7EC8DE","selection":"#7EC8DE26"}],"accents":[],
        "syntax":{"emphasis":{"font_style":"italic"}}}}]}
        """#
        let (family, _) = try ThemeFamily.loaded(jsonData: Data(json.utf8))
        let theme = try #require(family.themes.first)
        #expect(theme.style.syntax["emphasis"]?.color == nil)
        #expect(theme.style.syntax["emphasis"]?.fontStyle == .italic)
    }
}
```

- [ ] **Step 3: Conformance audit**

```swift
// Tests/CodeEditorPluginTests/Theming/ThemingConformanceTests.swift
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("Theming conformance audit")
struct ThemingConformanceTests {
    private static func requireConformance<T>(_ type: T.Type)
    where T: Sendable & Hashable & Codable { _ = String(describing: type) }

    @Test("public Theming types conform to Sendable, Hashable, Codable") func auditAll() {
        Self.requireConformance(Theme.self)
        Self.requireConformance(Theme.Appearance.self)
        Self.requireConformance(ThemeFamily.self)
        Self.requireConformance(ThemeStyle.self)
        Self.requireConformance(EditorColors.self)
        Self.requireConformance(ChromeColors.self)
        Self.requireConformance(ElementStates.self)
        Self.requireConformance(BorderColors.self)
        Self.requireConformance(TextLevels.self)
        Self.requireConformance(IconLevels.self)
        Self.requireConformance(StatusPalette.self)
        Self.requireConformance(StatusPalette.Status.self)
        Self.requireConformance(VCSPalette.self)
        Self.requireConformance(ScrollbarColors.self)
        Self.requireConformance(SearchColors.self)
        Self.requireConformance(PredictiveColors.self)
        Self.requireConformance(HintColors.self)
        Self.requireConformance(Player.self)
        Self.requireConformance(SyntaxStyle.self)
        Self.requireConformance(SyntaxStyle.FontStyle.self)
        Self.requireConformance(TerminalColors.self)
        Self.requireConformance(TerminalColors.ANSI.self)
        Self.requireConformance(PlatformExtension.self)
        Self.requireConformance(PlatformExtension.Glass.self)
        Self.requireConformance(PlatformExtension.Shadow.self)
        Self.requireConformance(PlatformExtension.Shadows.self)
        Self.requireConformance(PlatformExtension.Field.self)
        Self.requireConformance(ThemeWarning.self)
        Self.requireConformance(ThemeWarning.Kind.self)
    }
}
```

- [ ] **Step 4: Roundtrip smoke test**

```swift
// Tests/CodeEditorPluginTests/Theming/ThemeRoundtripTests.swift
@testable import CodeEditorPlugin
import CustomDump
import Foundation
import Testing

@Suite("Theme encode/decode roundtrip")
struct ThemeRoundtripTests {
    @Test("encode + decode of every bundled variant returns an equal Theme")
    func bundledRoundtripEqual() throws {
        let family = try #require(ThemeFamily.bundled("zed-trek"))
        for theme in family.themes {
            let encoded = try JSONEncoder().encode(theme)
            let decoder = JSONDecoder()
            decoder.userInfo[.themeWarnings] = WarningCollector()
            let decoded = try decoder.decode(Theme.self, from: encoded)
            expectNoDifference(decoded, theme)
        }
    }
}
```

- [ ] **Step 5: Run all four test files**

Run: `swift test --filter "ThemeStyleSnapshotTests|LenientDecodeTests|ThemingConformanceTests|ThemeRoundtripTests"`
Expected: snapshot test runs first time and writes a new snapshot file (records as failure on first run by snapshot-testing convention — re-run and it passes); other three pass first time.

Re-run: `swift test --filter ThemeStyleSnapshotTests`
Expected: PASS on second run.

- [ ] **Step 6: Commit**

```bash
git add Tests/CodeEditorPluginTests/Theming/ThemeStyleSnapshotTests.swift \
         Tests/CodeEditorPluginTests/Theming/LenientDecodeTests.swift \
         Tests/CodeEditorPluginTests/Theming/ThemingConformanceTests.swift \
         Tests/CodeEditorPluginTests/Theming/ThemeRoundtripTests.swift \
         Tests/CodeEditorPluginTests/__Snapshots__
git commit -m "$(cat <<'EOF'
Theming: snapshot, lenient-decode, conformance, roundtrip tests

LCARS Dark style snapshot (CustomDump). Lenient-decode fixtures for
missing keys, malformed hex, absent platform, emphasis-only syntax
entries. Reflection-based audit that every public type conforms to
Sendable/Hashable/Codable. Encode-decode roundtrip equality across all
20 bundled variants.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: SwiftUI `.codeTheme(_:)` modifier + environment value

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift` — full rewrite
- Create: `Tests/CodeEditorPluginTests/Theming/CodeThemeModifierTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// Tests/CodeEditorPluginTests/Theming/CodeThemeModifierTests.swift
@testable import CodeEditorPlugin
import Foundation
import SwiftUI
import Testing

@Suite("codeTheme modifier")
struct CodeThemeModifierTests {
    @Test("default environment value is Theme.lcarsDark")
    @MainActor
    func defaultEnvironmentValue() {
        let env = EnvironmentValues()
        #expect(env.codeTheme.name == Theme.lcarsDark.name)
    }

    @Test("setting environment value via key path round-trips")
    @MainActor
    func environmentRoundtrips() {
        var env = EnvironmentValues()
        let theme = Theme.fallback(appearance: .light)
        env.codeTheme = theme
        #expect(env.codeTheme.name == theme.name)
        #expect(env.codeTheme.appearance == .light)
    }
}
```

- [ ] **Step 2: Replace `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift`**

```swift
// Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift
import SwiftUI

private struct CodeThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .lcarsDark
}

extension EnvironmentValues {
    /// The theme applied to the code editor in this view hierarchy.
    /// Default: `Theme.lcarsDark`.
    public var codeTheme: Theme {
        get { self[CodeThemeKey.self] }
        set { self[CodeThemeKey.self] = newValue }
    }
}

extension View {
    /// Apply a `Theme` to the code editor in this view hierarchy.
    public func codeTheme(_ theme: Theme) -> some View {
        environment(\.codeTheme, theme)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter CodeThemeModifierTests`
Expected: PASS — two tests green.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift \
         Tests/CodeEditorPluginTests/Theming/CodeThemeModifierTests.swift
git commit -m "$(cat <<'EOF'
Theming: SwiftUI .codeTheme(_:) modifier + environment value

Replaces the old CodeEditorSwiftUITheme + .codeEditorTheme(_:) modifier
with a single .codeTheme(Theme) modifier and an EnvironmentValues.codeTheme
key that defaults to Theme.lcarsDark.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Internal adapter, migrate call sites, delete old types

This is the riskiest task — touches many files outside `Theming/`. Tests should already pass when starting; goal is to keep them passing while removing the old types.

**Files:**
- Create: `Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/CompletionCellComponents.swift` (audit each `Theme` reference)
- Modify: `Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder+ConvenienceExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/TokenName.swift` (docstring updates only)
- Delete: `Sources/CodeEditorPlugin/SyntaxHighlighting/Theme.swift`

- [ ] **Step 1: Write the adapter**

```swift
// Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift
import CodeEditorDesignTokens
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension Theme {
    /// Internal compatibility adapter — gives the existing syntax-highlighting
    /// pipeline a way to ask the new Theme for a color by `TokenName`. Sub-
    /// project 3 will replace the editor-internal mapping with a complete
    /// Zed→TokenName bridge and delete this file.
    func color(forLegacyToken token: TokenName) -> PlatformColor? {
        // Direct match — TokenName("keyword") → style.syntax["keyword"]?.color.
        if let syntax = style.syntax[token.rawValue], let color = syntax.color {
            return PlatformColor(tokens: color)
        }
        // Some legacy TokenName strings carry dotted variants; fall through
        // to the editor's foreground if the syntax map has no entry.
        return PlatformColor(tokens: style.editor.foreground)
    }
}

// MARK: - Tokens.Color → PlatformColor

extension PlatformColor {
    convenience init(tokens color: Tokens.Color) {
        self.init(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha)
        )
    }
}
```

- [ ] **Step 2: Audit and update `BaseUIComponents.swift`**

Open `Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift`. Find the protocol property `var theme: Theme { get set }`. Confirm it now refers to the new `Theme` (it will after the old `Theme.swift` is deleted). Update any `theme.color(forToken:)` call to `theme.color(forLegacyToken:)`. If a call site was reading `theme.colors.colors` (the old `[TokenName: PlatformColor]` dictionary) directly, it needs to be reworked to call `theme.color(forLegacyToken:)` per token.

Run `swift build` after each edit; expect a focused set of compile errors that flag every old call site. Fix them mechanically.

- [ ] **Step 3: Audit `CompletionCellComponents.swift`**

This file uses a separate `CompletionCellTheme` type — that's a distinct cell-level styling type, not the `Theme` we're replacing. **Leave it alone unless it constructs a `Theme(colors:fonts:)`.** If it does (audit by searching `Theme(`), retype to read from the new theme via the environment.

- [ ] **Step 4: Update `EditorConfigurationBuilder+ConvenienceExtensions.swift`**

Find:

```swift
func theme(_ theme: CodeEditorSwiftUITheme) -> Self {
```

Change to:

```swift
func theme(_ theme: Theme) -> Self {
```

Adjust the body to store/forward the new `Theme` value. If the builder previously stored a `CodeEditorSwiftUITheme`, store a `Theme` instead.

- [ ] **Step 5: Update `setupDefaultTheme()` in `CodeEditorView+SetupExtensions.swift`**

Replace whatever the existing implementation does with:

```swift
internal func setupDefaultTheme() {
    self.theme = .lcarsDark
}
```

If there's surrounding logic that constructs a default theme via `Theme(colors:fonts:)`, delete that path — `Theme.lcarsDark` is the canonical default now.

- [ ] **Step 6: Update docstrings in `TokenName.swift`**

Find the docstring example referencing the old API:

```swift
/// let theme = Theme(name: "MyTheme")
```

Replace it with the new shape:

```swift
/// let theme = Theme.lcarsDark
/// let color = theme.color(forLegacyToken: TokenName("keyword"))
```

(Keep the example minimal — `forLegacyToken` is internal so this docstring may need to point at the public path through `theme.style.syntax["keyword"]?.color` instead.)

- [ ] **Step 7: Delete the old `Theme.swift`**

```bash
git rm Sources/CodeEditorPlugin/SyntaxHighlighting/Theme.swift
```

- [ ] **Step 8: Build, run tests**

Run: `swift build`
Expected: builds cleanly. If there are remaining compile errors, they'll point at call sites that still expect old `Theme.Colors`/`Theme.Fonts` types — fix each by switching to `theme.color(forLegacyToken:)` or by reading directly from `theme.style.*` for chrome-style queries.

Run: `swift test --parallel`
Expected: all tests pass — the editor's existing visual output is sourced from the new theme via the legacy adapter; sub-project 3 will replace the adapter.

- [ ] **Step 9: SwiftLint**

Run: `swiftlint`
Expected: zero violations. Fix any new issues introduced by the migration.

- [ ] **Step 10: Commit**

```bash
git add Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift \
         Sources/CodeEditorPlugin/Layout/BaseUIComponents.swift \
         Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder+ConvenienceExtensions.swift \
         Sources/CodeEditorPlugin/Core/CodeEditorView+SetupExtensions.swift \
         Sources/CodeEditorPlugin/SyntaxHighlighting/TokenName.swift
git rm -f Sources/CodeEditorPlugin/SyntaxHighlighting/Theme.swift  # if not already staged
git commit -m "$(cat <<'EOF'
Theming: migrate internal call sites to new Theme; delete old type

Adds Theme.color(forLegacyToken:) as a temporary adapter so existing
syntax-highlighting and Layout call sites keep rendering unchanged
against the new Theme. Sub-project 3 will replace the adapter with a
real Zed-vocabulary bridge and delete this file. Removes the old
Theme.Colors/Theme.Fonts type and its file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Plugin-API consolidation

**Files:**
- Modify: `Sources/CodeEditorPlugin/PluginSystem/PluginAPI.swift`
- Modify: `Sources/CodeEditorPlugin/PluginSystem/PluginAPIBridge.swift`
- Create: `Tests/CodeEditorPluginTests/Theming/PluginThemeAPITests.swift`

- [ ] **Step 1: Failing tests**

```swift
// Tests/CodeEditorPluginTests/Theming/PluginThemeAPITests.swift
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("Plugin ThemeAPI")
struct PluginThemeAPITests {
    @Test("register then setTheme updates currentTheme")
    func registerThenSet() async throws {
        let api = makeThemeAPI()
        let theme = Theme.fallback(appearance: .light)
        try await api.register(theme)
        try await api.setTheme(theme.id)
        let current = await api.currentTheme()
        #expect(current.id == theme.id)
    }

    @Test("setTheme on unknown id throws")
    func setUnknownThrows() async {
        let api = makeThemeAPI()
        await #expect(throws: (any Error).self) {
            try await api.setTheme("definitely-not-registered")
        }
    }

    /// Construct a fresh ThemeAPI for testing. The exact factory depends
    /// on how the plugin system is wired — replace with the project's own
    /// test harness factory if one exists.
    private func makeThemeAPI() -> any ThemeAPI {
        // PluginAPIImpl or its test analog; point at whatever the existing
        // PluginAPIBridge tests use to instantiate.
        ThemeAPIImpl.makeForTesting()
    }
}
```

The `ThemeAPIImpl.makeForTesting()` factory is added in Step 3 below.

- [ ] **Step 2: Update `PluginSystem/PluginAPI.swift`**

Open the file. Locate the `ThemeAPI` protocol and the `EditorTheme` / `ThemeColors` types. Delete `EditorTheme` and `ThemeColors` entirely. Replace `ThemeAPI` with:

```swift
/// API surface for themes accessible to plugins. Themes are the new
/// schema-rich Theme value; sub-project 2 consolidated three formerly-
/// separate theme-shaped types into this one.
public protocol ThemeAPI: Sendable {
    func register(_ theme: Theme) async throws
    func currentTheme() async -> Theme
    func setTheme(_ themeId: String) async throws
}
```

Update the parent protocol's `themes: ThemeAPI { get }` if needed (no shape change).

- [ ] **Step 3: Update `PluginSystem/PluginAPIBridge.swift`**

Find `private final class ThemeAPIImpl: ThemeAPI`. Update its three methods to take/return `Theme`:

```swift
private final class ThemeAPIImpl: ThemeAPI {
    // The internal storage shape depends on what's already there. The key
    // change is that `theme: EditorTheme` becomes `theme: Theme`, and the
    // dictionary-based lookup uses `Theme.id` (which is `Theme.name`).

    private let lock = NSLock()
    private var registered: [String: Theme] = [:]
    private var current: Theme = .lcarsDark

    func register(_ theme: Theme) async throws {
        lock.lock(); defer { lock.unlock() }
        registered[theme.id] = theme
    }

    func currentTheme() async -> Theme {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func setTheme(_ themeId: String) async throws {
        lock.lock(); defer { lock.unlock() }
        guard let theme = registered[themeId] else {
            throw NSError(domain: "ThemeAPI", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown theme id: \(themeId)"])
        }
        current = theme
    }

    /// Test factory.
    static func makeForTesting() -> ThemeAPIImpl { ThemeAPIImpl() }
}
```

If the existing implementation routes through a state actor or shared store, preserve that shape and just retype the values from `EditorTheme` to `Theme`.

- [ ] **Step 4: Run tests**

Run: `swift test --filter PluginThemeAPITests`
Expected: PASS — two tests green.

- [ ] **Step 5: Build + full test sweep**

Run: `swift build && swiftlint && swift test --parallel`
Expected: builds; zero violations; all green. If the previous `EditorTheme` was referenced elsewhere (e.g., from an external plugin sample), fix those call sites or document the breaking change in the CHANGELOG.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/PluginSystem/PluginAPI.swift \
         Sources/CodeEditorPlugin/PluginSystem/PluginAPIBridge.swift \
         Tests/CodeEditorPluginTests/Theming/PluginThemeAPITests.swift
git commit -m "$(cat <<'EOF'
Theming: consolidate plugin ThemeAPI onto new Theme

Deletes EditorTheme and ThemeColors. ThemeAPI now takes/returns the
new Theme directly, removing the third theme-shaped type from the
package.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: CHANGELOG, DocC sweep, final SwiftLint

**Files:**
- Modify: `CHANGELOG.md` (create if absent)
- Modify: any new public-symbol files lacking DocC docstrings

- [ ] **Step 1: CHANGELOG entry**

Append (or create) `CHANGELOG.md` with:

```markdown
## Unreleased

### Added
- `Theme`, `ThemeFamily`, `ThemeStyle`, and 17 sub-struct value types under
  `CodeEditorPlugin.Theming` modelling Zed v0.2.0 theme JSON.
- `PlatformExtension` value type extending the Zed schema with Liquid Glass
  / shadow / field knobs.
- `ThemeFamily.bundled(_:)`, `Theme.bundled(family:variant:)`,
  `Theme.lcarsDark`, `Theme.fallback(appearance:)` loader API.
- `.codeTheme(_:)` SwiftUI modifier and `EnvironmentValues.codeTheme`
  environment value.
- Bundled `zed-trek.json` (20 variants) under
  `CodeEditorPlugin/Resources/Themes/`. Authored by ajmcclary, vendored
  with attribution from `~/Downloads/zed-trek/themes/zed-trek.json`.

### Removed (breaking)
- `Theme.Colors` and `Theme.Fonts` — replaced by `Theme.style.*`.
- `CodeEditorSwiftUITheme` — covered by `Theme.style.editor.*`.
- `.codeEditorTheme(_:)` modifier — replaced by `.codeTheme(_:)`.
- `EditorTheme` and `ThemeColors` from `PluginSystem/PluginAPI.swift` —
  replaced by `Theme`.

### Default behavior
- Library default theme is now `LCARS Dark` (from the bundled `zed-trek`
  family), not the previous `CodeEditorSwiftUITheme.default`.
```

- [ ] **Step 2: DocC sweep**

For each new public type and method without a docstring, add one. Minimum: a one-sentence summary. The plan includes docstrings inline in the implementation snippets above; ensure they made it into the actual files.

Run a quick check:

```bash
grep -L "^/// " Sources/CodeEditorPlugin/Theming/*.swift
```

Any file printed has at least one undocumented public symbol — open it and add docstrings.

- [ ] **Step 3: Final lint sweep**

Run: `swiftlint --fix`
Run: `swiftlint`
Expected: zero violations.

- [ ] **Step 4: Final test sweep**

Run: `swift build && swift test --parallel`
Expected: builds; all green.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md Sources/CodeEditorPlugin/Theming
git commit -m "$(cat <<'EOF'
Theming: CHANGELOG + DocC + final lint pass

Records the breaking changes and additions from the theme rewrite.
Ensures every public symbol in Theming/ has a docstring.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

After writing all tasks, the following spec requirements have explicit task coverage:

| Spec section | Task(s) |
|---|---|
| Type structure (19 sub-struct files) | 2, 3, 4, 5, 6, 7 |
| Custom Codable strategy (DynamicCodingKey, two-level decode, WarningCollector on userInfo) | 1, 6 |
| Routing rules table (Section 2 of spec) | 6 |
| `PlatformExtension.derived(from:appearance:)` | 5 |
| Loader API (`init(jsonData:)`, `loaded(...)`, `bundled(_:)`, `lcarsDark`, `fallback(_:)`) | 7, 8, 9 |
| Throws-vs-nil semantics | 8, 9 |
| Bundled `zed-trek.json` + Package.swift resources | 9 |
| All bundled-decode tests pass with zero warnings | 9 |
| Snapshot of `LCARS Dark` style | 10 |
| Lenient-decode tests (missing key, malformed color, unknown platform key, absent platform, emphasis-only syntax) | 10 |
| Conformance audit | 10 |
| Roundtrip smoke test | 10 |
| `.codeTheme(_:)` modifier + environment default | 11 |
| Internal adapter `Theme.color(forLegacyToken:)` | 12 |
| Delete old `Theme.swift` + `CodeEditorSwiftUITheme` | 12 |
| Migrate `BaseUIComponents`, builder convenience, `setupDefaultTheme()` | 12 |
| Plugin-API consolidation (delete `EditorTheme`/`ThemeColors`) | 13 |
| CHANGELOG | 14 |
| DocC on all public symbols | 14 |
| Zero SwiftLint violations | every task; explicit final pass in 14 |

**Type-name consistency check.** Field and type names used across tasks match: `Theme`, `Theme.Appearance`, `ThemeFamily`, `ThemeStyle`, `EditorColors`, `ChromeColors`, `ElementStates` (with nested `States`), `BorderColors`, `TextLevels`, `IconLevels`, `StatusPalette` (with nested `Status`), `VCSPalette`, `ScrollbarColors`, `SearchColors`, `PredictiveColors`, `HintColors`, `Player`, `SyntaxStyle`, `TerminalColors`, `PlatformExtension`, `ThemeWarning`, `WarningCollector`, `DynamicCodingKey`, `ZedColorBridge`, `ThemeFallbackPalette`. The internal compatibility method is `Theme.color(forLegacyToken:)` consistently.

**Placeholder scan.** No "TBD" / "TODO" / "implement later" / "fill in details" appear. The places that say "follow the same pattern as TextLevels" reference the spec routing tables and the explicit fields/keys listed in Task 4 — the engineer has every key name and every field name, just types out the boilerplate per file.
