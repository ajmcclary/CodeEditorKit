# Theme Rewrite + Bundled Themes

**Date:** 2026-05-05
**Status:** brainstorm complete — pending user review of written spec
**Type:** sub-project spec — sub-project 2 of the [Design System Migration umbrella](2026-05-05-design-system-migration-design.md).
**Scope:** schema, decoder, loader, public SwiftUI surface, plugin-API consolidation. Editor visual restyle and chrome are out of scope.

## Goal

Replace today's `Theme` (a small `Theme.Colors` + `Theme.Fonts` pair) with a Zed v0.2.0-compatible JSON-loadable schema plus a small `platform` extension key that models the things vanilla Zed doesn't (Liquid Glass, shadows, fields). Ship the user's `Zed Trek` family (20 variants) as the only bundled JSON, with `LCARS Dark` as the library default. Consolidate the package's three theme-shaped types into one.

## Context

This is the only breaking-change sub-project in the Design System Migration rollout. Sub-project 1 (`CodeEditorDesignTokens`) has shipped. Sub-projects 3 (editor restyle) and 4 (chrome primitives) depend on the new `Theme` landing here. The package is pre-1.0; no deprecation runway.

### What exists today

The package has **three** theme-shaped types:

| Type | Location | Purpose |
|---|---|---|
| `Theme` (`Theme.Colors`, `Theme.Fonts`) | `Sources/CodeEditorPlugin/SyntaxHighlighting/Theme.swift` | Editor-internal: per-token colors and fonts. |
| `CodeEditorSwiftUITheme` | `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift` | Public SwiftUI face: name + background/text/lineNumber/selectedLine. |
| `EditorTheme` / `ThemeColors` | `Sources/CodeEditorPlugin/PluginSystem/PluginAPI.swift` | Plugin DTO: id/name/colors map. |

All three are replaced by the new `Theme`.

### What's deviating from the umbrella spec

The umbrella sketched five "neutral" bundled themes (Xcode Dark/Light, VS Code Dark, GitHub, Solarized) **plus** the user's Zed Trek family. This sub-project ships **only Zed Trek**. The neutrals are dropped from the rollout entirely; they can be re-added later as their own commit if anyone wants them. See [Scope deviations](#scope-deviations) below.

## Strategy

### Type structure

A flat layout under a new `Sources/CodeEditorPlugin/Theming/` directory. All public, all `Sendable`, `Hashable`, `Codable`.

```swift
public struct ThemeFamily: Hashable, Sendable, Codable {
    public let schema: String?     // "https://zed.dev/schema/themes/v0.2.0.json"
    public let name: String        // "Zed Trek"
    public let author: String?
    public let themes: [Theme]
    public func theme(named: String) -> Theme?
}

public struct Theme: Hashable, Sendable, Codable, Identifiable {
    public enum Appearance: String, Sendable, Codable { case dark, light }
    public var id: String { name }
    public let name: String                 // "LCARS Dark"
    public let appearance: Appearance
    public let style: ThemeStyle
    public let platform: PlatformExtension  // never optional; defaults derived if absent in JSON
}

public struct ThemeStyle: Hashable, Sendable, Codable {
    public let background: Tokens.Color
    public let backgroundAppearance: String?       // "opaque" | "blurred"
    public let surfaceBackground: Tokens.Color
    public let elevatedSurfaceBackground: Tokens.Color
    public let editor: EditorColors
    public let chrome: ChromeColors                // title_bar, tab_bar, tab, status_bar, toolbar, panel
    public let elements: ElementStates             // element.* + ghost_element.*
    public let borders: BorderColors
    public let text: TextLevels
    public let icon: IconLevels
    public let status: StatusPalette               // info/success/warning/error/conflict
    public let vcs: VCSPalette                     // created/modified/deleted/renamed/ignored/hidden/unreachable
    public let scrollbar: ScrollbarColors
    public let search: SearchColors
    public let predictive: PredictiveColors
    public let hint: HintColors
    public let dropTarget: Tokens.Color
    public let players: [Player]
    public let accents: [Tokens.Color]
    public let syntax: [String: SyntaxStyle]       // 28+ Zed token names, keyed verbatim
    public let terminal: TerminalColors?           // future-compat
    public let extras: [String: Tokens.Color]      // unknown dotted keys; preserved on decode
}

public struct PlatformExtension: Hashable, Sendable, Codable {
    public let glass: Glass                        // tint color + opacity
    public let shadows: Shadows                    // popover-class shadow only, for now
    public let field: Field                        // fill, border, focusedBorder
    public let extras: [String: Tokens.Color]      // unknown platform.* keys

    public struct Glass:   Hashable, Sendable, Codable { /* color, opacity */ }
    public struct Shadows: Hashable, Sendable, Codable { /* popover { color, blur, x, y } */ }
    public struct Field:   Hashable, Sendable, Codable { /* fill, border, focusedBorder */ }

    /// Synthesizes a PlatformExtension from a ThemeStyle when the JSON omits the
    /// `platform` key. Glass tint = editor.background at low alpha; popover
    /// shadow = a soft drop tuned to appearance; field colors = derived from
    /// element.* values.
    public static func derived(from style: ThemeStyle, appearance: Theme.Appearance) -> PlatformExtension
}

public struct SyntaxStyle: Hashable, Sendable, Codable {
    public let color: Tokens.Color?                // optional — Zed allows entries with only style/weight
    public let backgroundColor: Tokens.Color?
    public let fontWeight: Int?                    // 100…900
    public let fontStyle: FontStyle?               // .normal, .italic
    public enum FontStyle: String, Sendable, Codable { case normal, italic }
}

public struct Player: Hashable, Sendable, Codable {
    public let cursor: Tokens.Color
    public let selection: Tokens.Color
    public let background: Tokens.Color?
}
```

The 17 sub-structs that hang off `ThemeStyle` (`EditorColors`, `ChromeColors`, `ElementStates`, `BorderColors`, `TextLevels`, `IconLevels`, `StatusPalette`, `VCSPalette`, `ScrollbarColors`, `SearchColors`, `PredictiveColors`, `HintColors`, `TerminalColors`, plus the three nested under `PlatformExtension`) each get their own file. Each has a per-prefix overflow bag so types stay locally complete.

#### File layout

```
Sources/CodeEditorPlugin/Theming/
  Theme.swift                          # Theme, Appearance
  ThemeFamily.swift                    # ThemeFamily, theme(named:)
  ThemeStyle.swift                     # ThemeStyle (top-level Codable)
  EditorColors.swift                   # editor.* sub-struct
  ChromeColors.swift                   # title_bar, tab_bar, tab, status_bar, toolbar, panel
  ElementStates.swift                  # element.* + ghost_element.*
  BorderColors.swift                   # border.*
  TextLevels.swift                     # text.*
  IconLevels.swift                     # icon.*
  StatusPalette.swift                  # info/success/warning/error/conflict
  VCSPalette.swift                     # created/modified/deleted/renamed/ignored/hidden/unreachable
  ScrollbarColors.swift                # scrollbar.*
  SearchColors.swift                   # search.*
  PredictiveColors.swift               # predictive.*
  HintColors.swift                     # hint.*
  PlayerColors.swift                   # players[]
  SyntaxStyle.swift                    # syntax map entry
  TerminalColors.swift                 # terminal.* (reserved, all-optional)
  PlatformExtension.swift              # platform.* — our extension
  Loader/
    ThemeFamily+Loader.swift           # init(jsonData:), init(contentsOf:), bundled(_:), loaded(...)
    ThemeWarning.swift
    WarningCollector.swift
    DynamicCodingKey.swift
  Internal/
    SyntaxColorLookup.swift            # Theme.color(forLegacyToken:) adapter (deleted in sub-project 3)
```

### Custom Codable strategy

Two-level decoding.

**Level 1 — `ThemeStyle.init(from:)`** uses a `DynamicCodingKey` (single-`stringValue` `CodingKey`) so it can read any key name. It decodes the whole `style` object into a flat `[String: Tokens.Color]` for color-valued keys plus separate decode passes for the structured keys (`syntax`, `players`, `accents`, `platform`, `terminal`, `background.appearance`).

**Level 2 — each sub-struct has** `init(flat:warnings:path:)`, a *plain initializer*, not `Codable`. It takes the flat color dictionary, the prefix it owns (e.g., `"text"`), reads each known suffix (`"muted"`, `"placeholder"`, `"accent"`, `""` for the bare key), and routes everything else under that prefix into its own overflow bag.

```swift
struct DynamicCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension TextLevels {
    init(flat: [String: Tokens.Color], warnings: WarningCollector, path: String) {
        self.base        = flat["text"]            ?? warnings.missing(path, "text",            Tokens.Palette.fallbackText)
        self.muted       = flat["text.muted"]      ?? warnings.missing(path, "text.muted",      ...)
        self.placeholder = flat["text.placeholder"] ?? ...
        self.disabled    = flat["text.disabled"]   ?? ...
        self.accent      = flat["text.accent"]     ?? ...
        self.extras      = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("text.") && !Self.knownSuffixes.contains($0.key) }
                .map { ($0.key, $0.value) })
    }
}
```

**Warning collection** rides on `decoder.userInfo`:

```swift
final class WarningCollector: @unchecked Sendable {
    private(set) var warnings: [ThemeWarning] = []
    func missing<T>(_ path: String, _ key: String, _ fallback: T) -> T { ... }
    func malformed(_ path: String, _ key: String, raw: String) { ... }
    func unknownPlatformKey(_ key: String) { ... }
}

extension CodingUserInfoKey {
    static let warnings = CodingUserInfoKey(rawValue: "themeWarnings")!
}
```

`JSONDecoder` is configured with a fresh `WarningCollector`; sub-struct inits append to it; the loader returns `(Theme, [ThemeWarning])` by reading the collector after the decode.

**Color decoding** — a single helper `Tokens.Color(zedHex:)` parses Zed's `"#rrggbb"` and `"#rrggbbaa"` formats. Malformed strings emit a `.malformedColor` warning and substitute palette default.

#### Routing rules in `ThemeStyle.init(from:)`

| JSON key shape | Goes to |
|---|---|
| `background`, `border`, `text`, `icon`, `hint`, `predictive`, `info`, `success`, `warning`, `error`, `conflict`, `created`, `modified`, `deleted`, `renamed`, `ignored`, `hidden`, `unreachable`, `drop_target.background`, `link_text.hover` | corresponding sub-struct's `base` / own field |
| `text.*`, `icon.*`, `editor.*`, `element.*`, `ghost_element.*`, `panel.*`, `scrollbar.*`, `search.*`, `predictive.*`, `hint.*`, status `*.background`/`*.border`, VCS `*.background`/`*.border` | flat-bag passed to matching sub-struct via prefix |
| `syntax` (object) | direct decode → `[String: SyntaxStyle]` |
| `players` (array) | direct decode → `[Player]` |
| `accents` (array) | direct decode → `[Tokens.Color]` |
| `platform` (object, our extension) | direct decode → `PlatformExtension`; absent → `PlatformExtension.derived(from:appearance:)` |
| `terminal` (object) | direct decode → `TerminalColors?` |
| `background.appearance` (string) | string-typed field on `ThemeStyle` |
| anything else with a `.` | global `[String: Tokens.Color]` extras bag on `ThemeStyle` |
| anything else without a `.` | warning, dropped |

**Encoding** mirrors decode in reverse: each sub-struct has `flatten(into:prefix:)`, top-level encode emits a flat object plus the structured maps. Per Q8 in the brainstorm, this exists for `Codable` symmetry but isn't tested or documented as a public contract — encoding is **out of scope** for this sub-project.

### Loader API

```swift
public extension ThemeFamily {
    /// Decode from raw JSON bytes. Throws on parse failure (malformed JSON,
    /// missing required top-level fields). Lenient on individual color keys —
    /// missing or malformed values fall back to Tokens.Palette and accumulate
    /// in the WarningCollector but do not throw.
    init(jsonData data: Data) throws

    /// Decode from a file URL. Reads the file synchronously, then defers to
    /// init(jsonData:). Throws on I/O or parse failure.
    init(contentsOf url: URL) throws

    /// Decode + collect warnings in one call. Same throws as init(jsonData:).
    static func loaded(jsonData: Data) throws -> (ThemeFamily, [ThemeWarning])
    static func loaded(contentsOf url: URL) throws -> (ThemeFamily, [ThemeWarning])

    /// Bundled-resource lookup. Non-throwing; nil if file missing or malformed.
    /// In this rollout, only "zed-trek" resolves.
    static func bundled(_ name: String) -> ThemeFamily?
}

public extension Theme {
    /// Convenience: load a specific variant from a bundled family.
    /// Returns nil if family or variant missing.
    static func bundled(family: String, variant: String) -> Theme?

    /// The library default. Resolves to "LCARS Dark" from the "zed-trek" bundle.
    /// Falls back to Theme.fallback(.dark) if the bundle is somehow absent
    /// (should never happen in normal builds, but guarantees non-optional).
    static var lcarsDark: Theme { get }

    /// Hard-coded minimum theme assembled from Tokens.Palette. Final fallback
    /// when nothing else is available. Never fails.
    static func fallback(appearance: Appearance) -> Theme
}

public struct ThemeWarning: Hashable, Sendable, CustomStringConvertible {
    public enum Kind: String, Sendable {
        case missingKey                // key absent, default substituted
        case malformedColor            // value couldn't parse as #rrggbb[aa]
        case unknownPlatformKey        // landed in PlatformExtension.extras
        case duplicateKey              // shouldn't happen in valid JSON; defensive
    }
    public let kind: Kind
    public let keyPath: String         // "editor.gutter.background", "syntax.keyword.color", "platform.glass.tint"
    public let detail: String?         // raw value if malformed, etc.
}
```

#### Throws vs. nil semantics

| Method | On parse failure | On missing key |
|---|---|---|
| `ThemeFamily(jsonData:)` | throws (`DecodingError`) | warning + default; does not throw |
| `ThemeFamily(contentsOf:)` | throws (I/O or `DecodingError`) | warning + default |
| `ThemeFamily.bundled(_:)` | returns nil | warning + default; does not throw |
| `Theme.bundled(family:variant:)` | returns nil | warning + default |
| `Theme.fallback(_:)` | never fails | n/a (hardcoded) |

**Bundled resource lookup** uses `Bundle.module.url(forResource: "zed-trek", withExtension: "json", subdirectory: "Themes")`. Memoized on first access in a `final class` holder.

**Where do warnings actually surface?**

- **Bundled paths** (`Theme.bundled(...)`, `ThemeFamily.bundled(...)`): warnings are dropped from the public API — the bundle is curated and tested. If the count is non-zero, an aggregate `CrossPlatformLogger` warning is emitted at `.warning` level so a regression doesn't go fully silent.
- **Caller-supplied paths** (`init(jsonData:)`, `init(contentsOf:)`): warnings are inaccessible from these initializers; callers wanting them use `loaded(jsonData:)` / `loaded(contentsOf:)`.

### Public API surface & migration

#### Added

```swift
public extension View {
    /// Apply a Theme to the code editor in this view hierarchy.
    func codeTheme(_ theme: Theme) -> some View
}

public extension EnvironmentValues {
    var codeTheme: Theme { get set }   // default: Theme.lcarsDark
}
```

Plus all the public types defined in the previous sections.

#### Removed

- `Theme.Colors`, `Theme.Fonts`, the old `Theme(colors:fonts:)` initializer.
- `CodeEditorSwiftUITheme` — the new `Theme` covers all of bg/text/lineNumber/selectedLine via `style.editor.background`, `style.editor.foreground`, `style.editor.lineNumber`, `style.editor.activeLine.background`.
- `.codeEditorTheme(_:)` modifier — replaced by `.codeTheme(_:)`.
- `EditorTheme` and `ThemeColors` from `PluginSystem/PluginAPI.swift` (Q1).

#### Unchanged

- `CodeEditor` SwiftUI entry point.
- `EditorConfiguration` and its display/layout/behavior/performance sections.
- `TokenName` and the syntax-highlighting public API. The Zed→`TokenName` mapping is sub-project 3, but sub-project 2 still has to keep the editor running.

#### Keeping the editor running between sub-projects 2 and 3

Per Q6c in the brainstorm, the *full* Zed→`TokenName` bridge belongs in sub-project 3. Sub-project 2 ships a **minimal internal adapter** so the package keeps compiling and the editor keeps rendering syntax highlighting visually identical to today:

```swift
// Theming/Internal/SyntaxColorLookup.swift  — internal, deleted in sub-project 3
extension Theme {
    func color(forLegacyToken token: TokenName) -> PlatformColor? {
        // Direct match: TokenName("keyword") → style.syntax["keyword"]?.color
        // Falls back to style.editor.foreground for unknown names.
    }
}
```

#### Files rewritten or deleted

| File | Change |
|---|---|
| `SyntaxHighlighting/Theme.swift` | **Deleted.** |
| `SwiftUI/CodeEditorTheme+Extensions.swift` | **Rewritten.** New `.codeTheme(_:)` modifier + environment key. |
| `Configuration/EditorConfigurationBuilder+ConvenienceExtensions.swift` | `theme(_:)` builder method retyped. |
| `Core/CodeEditorView+SetupExtensions.swift` | `setupDefaultTheme()` reads `Theme.lcarsDark`. |
| `Layout/BaseUIComponents.swift` | Internal `theme: Theme` protocol property retyped; call sites switched to `color(forLegacyToken:)`. |
| `PluginSystem/PluginAPI.swift` | `EditorTheme`/`ThemeColors` deleted; `ThemeAPI` methods retyped to new `Theme`. |
| `PluginSystem/PluginAPIBridge.swift` | Impl rewired. |
| `SyntaxHighlighting/TokenName.swift` doc-comments | Updated to remove references to deleted `Theme.Colors`/`Theme.Fonts` examples. |

#### Files added

- `Sources/CodeEditorPlugin/Theming/` — the 19 type files listed above.
- `Sources/CodeEditorPlugin/Theming/Loader/` — `ThemeFamily+Loader.swift`, `ThemeWarning.swift`, `WarningCollector.swift`, `DynamicCodingKey.swift`.
- `Sources/CodeEditorPlugin/Theming/Internal/SyntaxColorLookup.swift` — adapter stub.
- `Sources/CodeEditorPlugin/Resources/Themes/zed-trek.json` — vendored from `~/Downloads/zed-trek/themes/zed-trek.json` with attribution comment in the spec/CHANGELOG.

#### Package.swift change

Add `resources: [.process("Resources/Themes")]` to the `CodeEditorPlugin` target. The umbrella spec already accounts for this addition at this stage.

## Tests

Located under `Tests/CodeEditorPluginTests/Theming/`. Uses `swift-snapshot-testing` and `swift-custom-dump` (already package deps).

### Decoder correctness

| Test | Asserts |
|---|---|
| `LoadsBundledZedTrekFamily` | `ThemeFamily.bundled("zed-trek")` returns 20 themes; names match the known list; zero warnings. |
| `LoadsLCARSDarkFromBundle` | `Theme.lcarsDark` resolves; `appearance == .dark`; `name == "LCARS Dark"`; non-trivial color values. |
| `Snapshot_LCARSDark_StyleStructure` | CustomDump snapshot of decoded `Theme.style` for `LCARS Dark`. Catches accidental schema-shape changes. |
| `DecodesAllZedTrekVariants_NoWarnings` | All 20 variants decode with empty `[ThemeWarning]`. |

### Lenient behavior

| Test | Asserts |
|---|---|
| `MissingEditorGutter_FallsBackToPaletteAndWarns` | Synthetic JSON missing `editor.gutter.background` → palette default substituted; warnings contain `.missingKey` for that path. |
| `MalformedHexColor_FallsBackAndWarns` | `"text.muted": "not-a-color"` → palette default + `.malformedColor` warning with raw value in `detail`. |
| `UnknownPlatformKey_LandsInExtras` | `"platform": { "weird_key": "#ff0000" }` → ends up in `PlatformExtension.extras["weird_key"]` **and** emits `.unknownPlatformKey` warning. |
| `AbsentPlatformKey_DerivesDefaults` | JSON without `platform` → `Theme.platform` populated by `PlatformExtension.derived(from:appearance:)`; non-trivial values. |
| `EmphasisSyntaxEntry_NoColorJustStyle` | `"syntax": { "emphasis": { "font_style": "italic" } }` → `SyntaxStyle.color == nil`, `fontStyle == .italic`. No warning. |

### Roundtrip

| Test | Asserts |
|---|---|
| `EncodeDecodeEquivalence_OnBundledThemes` | For every bundled variant, `JSONEncoder().encode(theme)` decodes back to a `Theme` equal under `expectNoDifference`. No assertion on byte-for-byte JSON. |

### Loader API

| Test | Asserts |
|---|---|
| `BundledFamilyLookup_Hit` | `ThemeFamily.bundled("zed-trek") != nil`. |
| `BundledFamilyLookup_Miss` | `ThemeFamily.bundled("nonexistent") == nil`. |
| `BundledThemeVariantLookup_Hit` | `Theme.bundled(family: "zed-trek", variant: "LCARS Dark") != nil`. |
| `BundledThemeVariantLookup_FamilyMiss` | `Theme.bundled(family: "x", variant: "y") == nil`. |
| `BundledThemeVariantLookup_VariantMiss` | `Theme.bundled(family: "zed-trek", variant: "Bogus") == nil`. |
| `Fallback_Dark_HasUsableValues` | `Theme.fallback(.dark)` has non-clear `style.editor.background`, populated `style.editor.foreground`. |
| `Fallback_Light_HasUsableValues` | Same for `.light`. |
| `LoadFromURL_ParseError_Throws` | `ThemeFamily(contentsOf:)` on malformed JSON throws `DecodingError`. |
| `LoadFromURL_FileMissing_Throws` | I/O error propagates. |

### Conformance

| Test | Asserts |
|---|---|
| `AllPublicTypesAreSendable` | Reflection-based audit (same pattern as `CodeEditorDesignTokensTests`): every public type in `Theming/` conforms to `Sendable`, `Hashable`, `Codable`. |

### SwiftUI modifier

| Test | Asserts |
|---|---|
| `CodeThemeModifier_SetsEnvironment` | A child view reads `\.codeTheme` after `.codeTheme(myTheme)` and gets `myTheme`. |
| `EnvironmentDefault_IsLcarsDark` | Without any modifier, `\.codeTheme` returns `Theme.lcarsDark`. |

### Plugin-API consolidation

| Test | Asserts |
|---|---|
| `PluginThemeAPI_RegisterThenSet` | `pluginAPI.themes.register(theme)` followed by `setTheme(theme.id)` ends with `currentTheme().id == theme.id`. |
| `PluginThemeAPI_SetUnknown_Throws` | `setTheme("nope")` throws. |

### Explicitly *not* tested in this sub-project

- Visual rendering (sub-project 3).
- Zed→`TokenName` mapping completeness (sub-project 3).
- Performance (the JSON is small; `Bundle.module` lookup is O(1); no perf concern at this layer).

## Acceptance criteria

- [ ] `swift build` succeeds with no warnings.
- [ ] `swift test --filter Theming` passes; new snapshots pass on second run.
- [ ] `swiftlint` reports zero violations across `Theming/` and the touched files outside it.
- [ ] `Sources/CodeEditorPlugin/Theming/` contains the 19 type files + 4 loader files + 1 internal adapter file.
- [ ] `Resources/Themes/zed-trek.json` is vendored; `Package.swift` processes the directory.
- [ ] Old `Theme.swift`, `CodeEditorSwiftUITheme`, `EditorTheme`, `ThemeColors` are deleted (no compat shims).
- [ ] `.codeTheme(_:)` modifier exists; `.codeEditorTheme(_:)` is gone.
- [ ] Default theme (no modifier applied) is `LCARS Dark`.
- [ ] All bundled-decode tests pass with zero `ThemeWarning`s.
- [ ] DocC comments on every public symbol in the new types.
- [ ] CHANGELOG entry recording: removed `CodeEditorSwiftUITheme`, removed `Theme.Colors`/`Theme.Fonts`, removed `EditorTheme`/`ThemeColors`, added `Theme`/`ThemeFamily`/`ThemeStyle`/etc., new `.codeTheme(_:)` modifier, default = `LCARS Dark`, vendored `zed-trek.json`.

## Scope deviations

Recorded explicitly so future readers can distinguish deliberate decisions from oversight:

1. **Bundled themes:** umbrella named five neutral defaults (Xcode Dark/Light, VS Code Dark, GitHub, Solarized) plus Zed Trek; this sub-project ships **only Zed Trek**. The neutrals are dropped from the rollout entirely.
2. **Default theme:** umbrella's open question listed `xcode-dark` vs. `Federation Dark`; settled as **`LCARS Dark`**.
3. **`PlatformExtension`:** umbrella was silent on optionality; settled as **non-optional, with `PlatformExtension.derived(from:appearance:)` for absent JSON `platform` keys**.
4. **Plugin-API consolidation:** umbrella didn't mention it; **in scope** here — `EditorTheme`/`ThemeColors` removed, `ThemeAPI` methods retyped.

## Out of scope (explicit)

- Editor visual restyle — sub-project 3.
- Full Zed→`TokenName` mapping — sub-project 3. (Sub-project 2 ships only the minimal `color(forLegacyToken:)` adapter.)
- Chrome consumption (title bar, tab strip, status bar, etc.) — sub-project 4.
- Theme hot-reload from a watched directory — possibly sub-project 5; not now.
- Theme editing UI / saving themes back to JSON — encoder exists for `Codable` symmetry but is not exposed as a tested public contract.
- Adding `xcode-dark` / `xcode-light` / `vs-dark` / `github` / `solarized` JSONs — separate follow-up if/when desired.
- Async/background loading APIs — synchronous loading is fine for the file sizes involved (~1 MB).

## Open questions deferred to sub-project 3

- Some Zed token names (e.g., `embedded`, `link_text`, `link_uri`, `variant`, `predictive`, `boolean.special`) don't have a current `TokenName` analog. Decide per-token: extend `TokenName` or accept a fallback color.

## Recommended commit slicing

For the implementation plan to expand on:

1. Add `ThemeWarning`, `WarningCollector`, `DynamicCodingKey`, `ThemeFamily`, `Theme` skeleton (no decoding yet) — compiles.
2. Add `ThemeStyle` and the 17 sub-struct types with their flat-init constructors — still no top-level decoder.
3. Add the top-level `ThemeStyle.init(from:)` routing logic + encoder mirror.
4. Add `PlatformExtension` with `derived(from:appearance:)` factory.
5. Add `SyntaxStyle`, `Player`, `TerminalColors`.
6. Wire `Bundle.module` resource lookup; add `ThemeFamily.bundled(_:)`, `Theme.bundled(family:variant:)`, `Theme.lcarsDark`.
7. Vendor `zed-trek.json`; update `Package.swift`.
8. Add tests: bundled decode, snapshot of `LCARS Dark`, lenient-fallback tests on synthetic JSONs, conformance audit.
9. Replace `CodeEditorSwiftUITheme` and the `.codeEditorTheme(_:)` modifier; delete the old `Theme.swift`; add `Theme.color(forLegacyToken:)` adapter; switch `BaseUIComponents` and other internal call sites.
10. Update `setupDefaultTheme()` and the configuration builder convenience to use the new `Theme`.
11. Plugin-API consolidation: delete `EditorTheme`/`ThemeColors`; rewire `ThemeAPI`/`PluginAPIBridge`.
12. Tests: SwiftUI modifier, plugin-API.
13. CHANGELOG + DocC pass; final SwiftLint sweep.

## References

- Umbrella spec: [`docs/superpowers/specs/2026-05-05-design-system-migration-design.md`](2026-05-05-design-system-migration-design.md).
- Zed v0.2.0 schema: `https://zed.dev/schema/themes/v0.2.0.json`.
- Vendored source: `~/Downloads/zed-trek/themes/zed-trek.json` — Zed Trek family (20 variants), authored by ajmcclary.
- Sub-project 1 spec (shipped): same umbrella, Sub-project 1 section.
- Existing files being replaced: `Sources/CodeEditorPlugin/SyntaxHighlighting/Theme.swift`, `Sources/CodeEditorPlugin/SwiftUI/CodeEditorTheme+Extensions.swift`, `Sources/CodeEditorPlugin/PluginSystem/PluginAPI.swift` (`EditorTheme`/`ThemeColors`).
