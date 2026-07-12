# Design-System Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `CodeEditorDesignTokens` and `CodeEditorTheming` to parity with the evolved CodeEditorPlugin Design System (`colors_and_type.css`): add control-sizing + elevation/focus tokens, add the `on-accent`/`on-danger`/explicit-`glass-tint` roles, and regenerate `zed-trek.json` to 22 themes with AAA-hardened values.

**Architecture:** Static scales land in the DesignTokens layer. The four homeless roles land in `PlatformExtension`; diagnostics reuse native `status.*`/`vcs.modified` keys. A dev-only Python tool **merges** CSS semantic values over the existing JSON (preserving the Zed-only superset keys) and derives the two new LCARS High-Contrast themes from LCARS. TDD throughout; snapshots re-record.

**Tech Stack:** Swift 6.3 / SwiftPM, Swift Testing (`@Suite`/`@Test`/`#expect`) + XCTest, swift-snapshot-testing, Python 3 (codegen, dev-only, not a build target), SwiftLint (strict).

**Spec:** `docs/superpowers/specs/2026-07-12-design-system-sync-design.md`

## Global Constraints

- **Verify command (full gate):** `swift build && swiftlint --fix && swiftlint && swift test --parallel`. Run `swiftlint --fix` before `swiftlint` (strict mode = warnings are errors).
- **Targeted tests:** `swift test --filter <Name>`. Per repo memory, skip full-suite reruns after purely additive steps; run targeted suites between steps, full gate at the end (Task 8).
- **No `print()`** — use `CrossPlatformLogger` (not needed here). **No force-unwrap `!`** — safe-unwrap only. **No new `#if os()`** — use `#if canImport(...)`. All enforced by SwiftLint.
- **`missing_docs` is on** — every new `public` member needs a `///` doc line.
- **`CodeEditorDesignTokens` must not depend on `CodeEditorTheming`** — no `Theme.Appearance` in that target; use a local scheme enum.
- **Color normalization:** hex → uppercase `#RRGGBB`; `rgba(r,g,b,a)` → `#RRGGBBAA` with `AA = round(a*255)` uppercase (matches existing JSON, e.g. `rgba(126,200,222,0.094)` → `#7EC8DE18`).
- **Snapshot re-record:** set `isRecording: true`, run once, revert the flag, commit the regenerated artifact.
- Vendored source of truth: `colors_and_type.css` (copied verbatim from RepoPrompt's `~/Dev/repoprompt/docs/superpowers/specs/2026-07-11-design-tokens-full-sync/tools/colors_and_type.css`, dated 2026-07-11).

---

### Task 0: Vendor CSS + merge-codegen tool

**Files:**
- Create: `docs/superpowers/specs/2026-07-12-design-system-sync/tools/colors_and_type.css` (verbatim copy)
- Create: `docs/superpowers/specs/2026-07-12-design-system-sync/tools/gen_theme_json.py`
- Create: `docs/superpowers/specs/2026-07-12-design-system-sync/tools/zed-trek.generated.json` (script output, committed as a diff aid)

**Interfaces:**
- Produces: `zed-trek.generated.json` — the existing 20 themes with CSS semantic values merged over them + a full `platform` block each, plus 2 appended themes `LCARS High Contrast Dark` / `LCARS High Contrast Light`. Consumed by Task 5.

- [ ] **Step 1: Vendor the CSS.**

Run: `mkdir -p docs/superpowers/specs/2026-07-12-design-system-sync/tools && cp ~/Dev/repoprompt/docs/superpowers/specs/2026-07-11-design-tokens-full-sync/tools/colors_and_type.css docs/superpowers/specs/2026-07-12-design-system-sync/tools/colors_and_type.css`
Then confirm: `grep -c '^\.theme-' docs/superpowers/specs/2026-07-12-design-system-sync/tools/colors_and_type.css`
Expected: `22`

- [ ] **Step 2: Write the codegen script** at `docs/superpowers/specs/2026-07-12-design-system-sync/tools/gen_theme_json.py`:

```python
#!/usr/bin/env python3
"""Merge colors_and_type.css semantic values over the existing zed-trek.json.
Dev-only. Preserves Zed-only superset keys; overwrites the ~50 CSS-defined keys;
adds a platform block; derives the two LCARS High-Contrast themes from LCARS.
Re-run against a newer CSS to re-sync. Not part of any build target."""
import re, json, copy, pathlib

HERE = pathlib.Path(__file__).parent
CSS = (HERE / "colors_and_type.css").read_text()
JSON_SRC = HERE.parent.parent.parent.parent / "Sources/CodeEditorTheming/Resources/Themes/zed-trek.json"
OUT = HERE / "zed-trek.generated.json"

TITLES = {"lcars": "LCARS", "black-alert": "Black Alert", "borg-cube": "Borg Cube",
          "command": "Command", "federation": "Federation", "red-alert": "Red Alert",
          "yellow-alert": "Yellow Alert", "sick-bay": "Sick Bay",
          "mission-control": "Mission Control", "ready-room": "Ready Room",
          "lcars-hc": "LCARS High Contrast"}

FLAT = {
    "bg": "background", "surface": "surface.background", "elevated": "elevated_surface.background",
    "panel": "panel.background", "editor-bg": "editor.background", "editor-fg": "editor.foreground",
    "editor-gutter": "editor.gutter.background", "title-bar": "title_bar.background",
    "toolbar": "toolbar.background", "tab-bar": "tab_bar.background",
    "tab-active": "tab.active_background", "tab-inactive": "tab.inactive_background",
    "status-bar": "status_bar.background", "border": "border", "border-variant": "border.variant",
    "border-focused": "border.focused", "border-selected": "border.selected",
    "text": "text", "text-accent": "text.accent", "text-muted": "text.muted",
    "text-disabled": "text.disabled", "text-placeholder": "text.placeholder",
    "icon": "icon", "icon-accent": "icon.accent", "icon-muted": "icon.muted",
    "element-bg": "element.background", "element-hover": "element.hover",
    "element-active": "element.active", "element-selected": "element.selected",
    "ghost-hover": "ghost_element.hover", "ghost-active": "ghost_element.active",
    "ghost-selected": "ghost_element.selected",
    "active-line": "editor.active_line.background", "highlighted-line": "editor.highlighted_line.background",
    "line-num": "editor.line_number", "active-line-num": "editor.active_line_number",
    "diag-error": "status.error.base", "diag-warning": "status.warning.base",
    "diag-info": "status.info.base", "diag-success": "status.success.base",
    "diag-modified": "vcs.modified.base",
}
SYN = {"syn-keyword": "keyword", "syn-string": "string", "syn-comment": "comment",
       "syn-function": "function", "syn-type": "type", "syn-number": "number",
       "syn-constant": "constant", "syn-property": "property", "syn-variable": "variable",
       "syn-punct": "punctuation", "syn-tag": "tag", "syn-attr": "attribute"}

def norm(v):
    v = v.strip()
    m = re.fullmatch(r"rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)", v)
    if m:
        r, g, b, a = int(m[1]), int(m[2]), int(m[3]), float(m[4])
        return f"#{r:02X}{g:02X}{b:02X}{round(a*255):02X}"
    assert re.fullmatch(r"#[0-9A-Fa-f]{6}", v), f"bad hex {v!r}"
    return v.upper()

def shadow(css):  # "0 10px 36px rgba(0,0,0,0.30)" -> dict
    m = re.fullmatch(r"(\S+)\s+(\S+)\s+(\S+)\s+(rgba\(.*\))", css.strip())
    assert m, f"bad shadow {css!r}"
    px = lambda s: float(s.replace("px", ""))
    return {"color": norm(m[4]), "blur": px(m[3]), "x": px(m[1]), "y": px(m[2])}

def parse_cls(cls):
    if cls.endswith("-light"):
        fam, scheme = cls[:-6], "light"
    elif cls.endswith("-dark"):
        fam, scheme = cls[:-5], "dark"
    elif cls == "lcars-hc":
        fam, scheme = "lcars-hc", "dark"
    else:
        fam, scheme = cls, "dark"
    name = f"{TITLES[fam]} {'Light' if scheme == 'light' else 'Dark'}"
    return scheme, name

def blocks():
    out = {}
    for m in re.finditer(r"\.theme-([a-z0-9-]+)[^{]*\{([^}]*)\}", CSS):
        cls, body = m.group(1), m.group(2)
        vars = {k: v.strip() for k, v in re.findall(r"--([a-z0-9-]+)\s*:\s*([^;]+);", body)}
        out[cls] = vars
    return out

def platform(v):
    return {
        "glass": {"tint": norm(v["glass-tint"]), "opacity": 0.12},
        "shadows": {"popover": shadow(v["shadow-popover"])},
        "field": {"fill": norm(v["element-bg"]), "border": norm(v["border"]),
                  "focused_border": norm(v["border-focused"])},
        "on_accent": norm(v["on-accent"]),
        "on_danger": norm(v["on-danger"]),
    }

def main():
    data = json.loads(JSON_SRC.read_text())
    by_name = {t["name"]: t for t in data["themes"]}
    for cls, v in blocks().items():
        scheme, name = parse_cls(cls)
        if name in by_name:
            theme = by_name[name]
        else:  # new HC theme: clone the LCARS counterpart, then overlay
            src = copy.deepcopy(by_name[f"LCARS {'Light' if scheme == 'light' else 'Dark'}"])
            src["name"], src["appearance"] = name, scheme
            data["themes"].append(src)
            by_name[name] = theme = src
        style = theme["style"]
        for css, key in FLAT.items():
            if css in v:
                style[key] = norm(v[css])
        style["accents"] = [norm(v[f"accent-{i}"]) for i in range(1, 6)]
        style.setdefault("syntax", {})
        for css, sname in SYN.items():
            if css in v:
                style["syntax"].setdefault(sname, {})["color"] = norm(v[css])
        style["platform"] = platform(v)
    OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    # Independent self-check anchors (raw CSS, not the Swift side):
    lc = by_name["LCARS Dark"]["style"]
    assert lc["surface.background"] == "#161F33" and lc["tab.active_background"] == "#111827"
    assert lc["platform"]["on_accent"] == "#05060A"
    assert by_name["LCARS High Contrast Dark"]["style"]["status.error.base"] == "#F37F7F"
    assert len(data["themes"]) == 22, len(data["themes"])
    print("OK: 22 themes emitted")

main()
```

- [ ] **Step 3: Run the script.**

Run: `python3 docs/superpowers/specs/2026-07-12-design-system-sync/tools/gen_theme_json.py`
Expected (stdout): `OK: 22 themes emitted`

- [ ] **Step 4: Spot-check the output against raw CSS (the real guard).**

Run: `python3 -c "import json; d=json.load(open('docs/superpowers/specs/2026-07-12-design-system-sync/tools/zed-trek.generated.json')); t={x['name']:x['style'] for x in d['themes']}; print(t['LCARS Dark']['editor.gutter.background'], t['LCARS Dark']['syntax']['comment']['color'], t['LCARS Light']['accents'][0], t['LCARS High Contrast Light']['background'], t['LCARS High Contrast Dark']['text.placeholder'])"`
Expected: `#0D1018 #939BA9 #9E5A18 #FBF7F1 #99A1AD`

- [ ] **Step 5: Commit.**

```bash
git add docs/superpowers/specs/2026-07-12-design-system-sync/tools/
git commit -m "chore(design): merge-codegen tool + vendored CSS for theme sync"
```

---

### Task 1: `Tokens.Size.Control` — control-sizing scale

**Files:**
- Modify: `Sources/CodeEditorDesignTokens/Size.swift` (append nested enum inside `Tokens.Size`)
- Test: `Tests/CodeEditorDesignTokensTests/SizeTests.swift`

**Interfaces:**
- Produces: `Tokens.Size.Control.{height,heightCompact,heightSmall,row,rowCompact,chip,switchWidth,switchHeight,switchKnob,accentBar,titleBar,tabStrip,statusBar}: Double`.

- [ ] **Step 1: Write the failing test** — append to `SizeTests.swift`:

```swift
@Test("control sizing matches CSS source")
func controlSizes() {
    #expect(Tokens.Size.Control.height == 32)
    #expect(Tokens.Size.Control.heightCompact == 27)
    #expect(Tokens.Size.Control.heightSmall == 24)
    #expect(Tokens.Size.Control.row == 34)
    #expect(Tokens.Size.Control.rowCompact == 28)
    #expect(Tokens.Size.Control.chip == 26)
    #expect(Tokens.Size.Control.switchWidth == 38)
    #expect(Tokens.Size.Control.switchHeight == 22)
    #expect(Tokens.Size.Control.switchKnob == 18)
    #expect(Tokens.Size.Control.accentBar == 2)
    #expect(Tokens.Size.Control.titleBar == 38)
    #expect(Tokens.Size.Control.tabStrip == 36)
    #expect(Tokens.Size.Control.statusBar == 28)
}
```

- [ ] **Step 2: Run to verify it fails.**

Run: `swift test --filter SizeTests`
Expected: build failure — `Tokens.Size.Control` not found.

- [ ] **Step 3: Implement** — add inside the `public enum Size { ... }` body in `Size.swift` (after `Avatar`):

```swift
        /// Control / chrome heights that recur verbatim across surfaces built
        /// on this system. Mirror the control-sizing section of the CSS source.
        public enum Control {
            /// 32pt — default button / control height.
            public static let height: Double = 32
            /// 27pt — compact button / inline control.
            public static let heightCompact: Double = 27
            /// 24pt — chip-height control.
            public static let heightSmall: Double = 24
            /// 34pt — settings / list row.
            public static let row: Double = 34
            /// 28pt — dense list row.
            public static let rowCompact: Double = 28
            /// 26pt — chip / badge pill.
            public static let chip: Double = 26
            /// 38pt — toggle track width.
            public static let switchWidth: Double = 38
            /// 22pt — toggle track height.
            public static let switchHeight: Double = 22
            /// 18pt — toggle knob diameter.
            public static let switchKnob: Double = 18
            /// 2pt — active tab / active row accent bar.
            public static let accentBar: Double = 2
            /// 38pt — macOS title bar.
            public static let titleBar: Double = 38
            /// 36pt — tab strip (28pt compact).
            public static let tabStrip: Double = 36
            /// 28pt — status bar.
            public static let statusBar: Double = 28
        }
```

- [ ] **Step 4: Run to verify it passes.**

Run: `swift test --filter SizeTests`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Sources/CodeEditorDesignTokens/Size.swift Tests/CodeEditorDesignTokensTests/SizeTests.swift
git commit -m "feat(design): add Tokens.Size.Control sizing scale"
```

---

### Task 2: `Tokens.Elevation` — scheme-keyed shadows + focus ring

**Files:**
- Create: `Sources/CodeEditorDesignTokens/Elevation.swift`
- Test: `Tests/CodeEditorDesignTokensTests/ElevationTests.swift`

**Interfaces:**
- Produces: `Tokens.Elevation.Scheme { dark, light }`; `Tokens.Elevation.Shadow { color: Tokens.Color; blur, x, y: Double }`; `Tokens.Elevation.popover/card/window(_ scheme:) -> Shadow`; `Tokens.Elevation.focusRingWidth: Double = 3`; `Tokens.Elevation.focusRing(accent: Tokens.Color) -> Tokens.Color` (accent at alpha 0.28). Consumed by Task 4 (`PlatformExtension.derived`).

- [ ] **Step 1: Write the failing test** at `Tests/CodeEditorDesignTokensTests/ElevationTests.swift`:

```swift
@testable import CodeEditorDesignTokens
import Testing

@Suite("Tokens.Elevation")
struct ElevationTests {
    @Test("card shadow differs by scheme, blur/offset match CSS")
    func cardShadow() {
        #expect(Tokens.Elevation.card(.dark).blur == 12)
        #expect(Tokens.Elevation.card(.dark).y == 4)
        #expect(Tokens.Elevation.card(.dark).color != Tokens.Elevation.card(.light).color)
        #expect(Tokens.Elevation.window(.dark).y == 24)
        #expect(Tokens.Elevation.window(.dark).blur == 80)
        #expect(Tokens.Elevation.popover(.light).blur == 32)
    }

    @Test("focus ring is accent at 28% alpha, 3pt wide")
    func focusRing() {
        #expect(Tokens.Elevation.focusRingWidth == 3)
        let ring = Tokens.Elevation.focusRing(accent: Tokens.Color(hex: 0xFF9933))
        #expect(ring.red == 0xFF && ring.green == 0x99 && ring.blue == 0x33)
        #expect(abs(ring.alpha - 0.28) < 0.0001)
    }
}
```

- [ ] **Step 2: Run to verify it fails.**

Run: `swift test --filter ElevationTests`
Expected: build failure — no `Tokens.Elevation`.

- [ ] **Step 3: Implement** `Sources/CodeEditorDesignTokens/Elevation.swift`:

```swift
import Foundation

extension Tokens {
    /// Elevation tokens. Shadow + focus-ring values are constant per color
    /// scheme (every dark theme shares them; every light theme shares them),
    /// so they live here rather than duplicated across per-theme palettes.
    /// Mirror the `--shadow-*` / `--focus-ring` tokens of the CSS source.
    public enum Elevation {
        /// Color scheme selector, local so this target stays free of any
        /// dependency on `CodeEditorTheming.Theme.Appearance`.
        public enum Scheme: Sendable, Hashable { case dark, light }

        /// One drop-shadow spec: color + blur + offset (x always 0 here).
        public struct Shadow: Sendable, Hashable {
            /// Shadow color (translucent black).
            public let color: Tokens.Color
            /// Gaussian blur radius in points.
            public let blur: Double
            /// Horizontal offset in points.
            public let x: Double
            /// Vertical offset in points.
            public let y: Double

            /// Memberwise builder.
            public init(color: Tokens.Color, blur: Double, x: Double, y: Double) {
                self.color = color
                self.blur = blur
                self.x = x
                self.y = y
            }
        }

        private static func shadow(_ alpha: Double, _ blur: Double, _ y: Double) -> Shadow {
            Shadow(color: Tokens.Color(hex: 0x00_00_00, alpha: alpha), blur: blur, x: 0, y: y)
        }

        /// Popover / menu / command-palette drop shadow.
        public static func popover(_ scheme: Scheme) -> Shadow {
            scheme == .dark ? shadow(0.30, 36, 10) : shadow(0.12, 32, 12)
        }

        /// Card / raised-surface drop shadow.
        public static func card(_ scheme: Scheme) -> Shadow {
            scheme == .dark ? shadow(0.18, 12, 4) : shadow(0.10, 12, 4)
        }

        /// Window-class drop shadow (floating windows, large popovers).
        public static func window(_ scheme: Scheme) -> Shadow {
            scheme == .dark ? shadow(0.55, 80, 24) : shadow(0.18, 70, 24)
        }

        /// Focus-ring stroke width in points.
        public static let focusRingWidth: Double = 3

        /// Focus ring in the live accent at 28% alpha
        /// (CSS `color-mix(in srgb, accent 28%, transparent)`).
        public static func focusRing(accent: Tokens.Color) -> Tokens.Color {
            Tokens.Color(red: accent.red, green: accent.green, blue: accent.blue, alpha: 0.28)
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes.**

Run: `swift test --filter ElevationTests`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Sources/CodeEditorDesignTokens/Elevation.swift Tests/CodeEditorDesignTokensTests/ElevationTests.swift
git commit -m "feat(design): add Tokens.Elevation shadow + focus-ring tokens"
```

---

### Task 3: `Tokens.Typography.Tracking.tight`

**Files:**
- Modify: `Sources/CodeEditorDesignTokens/Typography.swift` (`Tracking` enum)
- Test: `Tests/CodeEditorDesignTokensTests/TypographyTests.swift`

**Interfaces:**
- Produces: `Tokens.Typography.Tracking.tight: Double = -0.01` (em). (`Tokens.Spacing.smMd` already exists — no change.)

- [ ] **Step 1: Write the failing test** — append to `TypographyTests.swift`:

```swift
@Test("tracking-tight matches CSS source")
func trackingTight() {
    #expect(Tokens.Typography.Tracking.tight == -0.01)
    #expect(Tokens.Typography.Tracking.caps == 0.5)
}
```

- [ ] **Step 2: Run to verify it fails.**

Run: `swift test --filter TypographyTests`
Expected: build failure — `Tracking.tight` not found.

- [ ] **Step 3: Implement** — add to the `Tracking` enum in `Typography.swift`:

```swift
            /// -0.01em — tight tracking for large/display text (CSS --tracking-tight).
            public static let tight: Double = -0.01
```

- [ ] **Step 4: Run to verify it passes.**

Run: `swift test --filter TypographyTests`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add Sources/CodeEditorDesignTokens/Typography.swift Tests/CodeEditorDesignTokensTests/TypographyTests.swift
git commit -m "feat(design): add Tokens.Typography.Tracking.tight"
```

---

### Task 4: `PlatformExtension` — `onAccent`/`onDanger` + explicit glass + Elevation-sourced shadow

**Files:**
- Modify: `Sources/CodeEditorTheming/PlatformExtension.swift` (add fields, thread through memberwise init + decoder + encoder)
- Modify: `Sources/CodeEditorTheming/ThemeStyle.swift:284-303` (`PlatformExtension.derived` — add args, source shadow from `Tokens.Elevation`)
- Test: `Tests/CodeEditorPluginTests/Theming/PlatformExtensionTests.swift`

**Interfaces:**
- Consumes: `Tokens.Elevation.popover(_:)`, `Tokens.Elevation.Scheme` (Task 2).
- Produces: `PlatformExtension.onAccent: Tokens.Color`, `PlatformExtension.onDanger: Tokens.Color`; memberwise init `init(glass:shadows:field:onAccent:onDanger:extras:)`; JSON keys `platform.on_accent` / `platform.on_danger` decoded/encoded; explicit `platform.glass.tint` already loads today.

- [ ] **Step 1: Write the failing test** at `Tests/CodeEditorPluginTests/Theming/PlatformExtensionTests.swift`:

```swift
import Foundation
import Testing
@testable import CodeEditorTheming
import CodeEditorDesignTokens

@Suite("PlatformExtension on-accent / on-danger")
struct PlatformExtensionTests {
    @Test("explicit platform.on_accent / on_danger decode")
    func decodesOnRoles() throws {
        let json = """
        {"glass":{"tint":"#FF9933","opacity":0.12},
         "shadows":{"popover":{"color":"#0000004D","blur":36,"x":0,"y":10}},
         "field":{"fill":"#151A24","border":"#2A2030","focused_border":"#FF9933"},
         "on_accent":"#05060A","on_danger":"#05060A"}
        """.data(using: .utf8)!
        let ext = try JSONDecoder().decode(PlatformExtension.self, from: json)
        #expect(ext.onAccent == Tokens.Color(hex: 0x05_06_0A))
        #expect(ext.onDanger == Tokens.Color(hex: 0x05_06_0A))
        #expect(ext.glass.tint == Tokens.Color(hex: 0xFF_99_33))
    }

    @Test("derived() supplies on-role fallbacks per appearance")
    func derivedFallback() {
        let dark = Theme.fallback(appearance: .dark)
        #expect(dark.style.platform.onAccent == Tokens.Color(hex: 0x05_06_0A))
        let light = Theme.fallback(appearance: .light)
        #expect(light.style.platform.onAccent == Tokens.Color(hex: 0xFF_FF_FF))
    }
}
```

- [ ] **Step 2: Run to verify it fails.**

Run: `swift test --filter PlatformExtensionTests`
Expected: build failure — `PlatformExtension` has no member `onAccent`.

- [ ] **Step 3: Add stored fields + memberwise init** in `PlatformExtension.swift`. After the `extras` property (line ~134) add:

```swift
    /// Text/icon color on an `accent-1` fill (primary button). CSS `--on-accent`.
    public let onAccent: Tokens.Color
    /// Text/icon color on a `diag-error` fill (destructive button). CSS `--on-danger`.
    public let onDanger: Tokens.Color
```

Replace the memberwise `init` (lines ~137-142) with:

```swift
    /// Memberwise builder.
    public init(
        glass: Glass, shadows: Shadows, field: Field,
        onAccent: Tokens.Color, onDanger: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.glass = glass
        self.shadows = shadows
        self.field = field
        self.onAccent = onAccent
        self.onDanger = onDanger
        self.extras = extras
    }
```

- [ ] **Step 4: Decode/encode the new keys.** In `PlatformExtension.swift`:

Add to `CodingKeys` (line ~144-146):

```swift
    private enum CodingKeys: String, CodingKey {
        case glass, shadows, field
        case onAccent = "on_accent"
        case onDanger = "on_danger"
    }
```

In `init(from:)`, after `self.field = try container.decode(Field.self, forKey: .field)` (line ~159), add appearance-aware fallbacks (dark → near-black, light → white; matches CSS `--on-accent`):

```swift
        let appearance = (decoder.userInfo[.themeAppearance] as? AppearanceHolder)?.appearance ?? .dark
        let onFallback = appearance == .light
            ? Tokens.Color(hex: 0xFF_FF_FF) : Tokens.Color(hex: 0x05_06_0A)
        if let hex = try container.decodeIfPresent(String.self, forKey: .onAccent),
           let c = ZedColorBridge.parse(hex, path: "platform.on_accent", warnings: warnings) {
            self.onAccent = c
        } else {
            self.onAccent = onFallback
        }
        if let hex = try container.decodeIfPresent(String.self, forKey: .onDanger),
           let c = ZedColorBridge.parse(hex, path: "platform.on_danger", warnings: warnings) {
            self.onDanger = c
        } else {
            self.onDanger = onFallback
        }
```

Add `"on_accent"`, `"on_danger"` to the `known` set (line ~165) so they don't leak into `extras`:

```swift
        let known: Set<String> = ["glass", "shadows", "field", "on_accent", "on_danger"]
```

In `encode(to:)`, after encoding `field` (line ~183), add:

```swift
        try container.encode(ZedColorBridge.encode(onAccent), forKey: .onAccent)
        try container.encode(ZedColorBridge.encode(onDanger), forKey: .onDanger)
```

> Note: `.themeAppearance` / `AppearanceHolder` already exist (used elsewhere in the theming decoders). If `AppearanceHolder.appearance` is non-optional, drop the `?? .dark`.

- [ ] **Step 5: Update `derived()`** in `ThemeStyle.swift` (lines ~284-303) to source the shadow from `Tokens.Elevation` and supply the on-role fallbacks:

```swift
    public static func derived(from style: ThemeStyle, appearance: Theme.Appearance) -> PlatformExtension {
        let bg = style.editor.background
        let glassTint = Tokens.Color(red: bg.red, green: bg.green, blue: bg.blue, alpha: 0.12)
        let scheme: Tokens.Elevation.Scheme = appearance == .dark ? .dark : .light
        let e = Tokens.Elevation.popover(scheme)
        let popover = PlatformExtension.Shadow(
            color: e.color, blur: e.blur, xOffset: e.x, yOffset: e.y
        )
        let field = PlatformExtension.Field(
            fill: style.elements.element.background,
            border: style.borders.base,
            focusedBorder: style.borders.focused
        )
        let onRole = appearance == .light
            ? Tokens.Color(hex: 0xFF_FF_FF) : Tokens.Color(hex: 0x05_06_0A)
        return PlatformExtension(
            glass: PlatformExtension.Glass(tint: glassTint, opacity: 0.12),
            shadows: PlatformExtension.Shadows(popover: popover),
            field: field,
            onAccent: onRole,
            onDanger: onRole
        )
    }
```

- [ ] **Step 6: Run to verify it passes.**

Run: `swift test --filter PlatformExtensionTests`
Expected: PASS. (If other theming tests reference the old `PlatformExtension(...)` init, they surface here as build errors — fix each to pass `onAccent:`/`onDanger:`. There is exactly one production construction site, already updated in Step 5.)

- [ ] **Step 7: Commit.**

```bash
git add Sources/CodeEditorTheming/PlatformExtension.swift Sources/CodeEditorTheming/ThemeStyle.swift Tests/CodeEditorPluginTests/Theming/PlatformExtensionTests.swift
git commit -m "feat(design): PlatformExtension gains on-accent/on-danger; shadow from Tokens.Elevation"
```

---

### Task 5: Regenerate `zed-trek.json` to 22 themes

**Files:**
- Modify: `Sources/CodeEditorTheming/Resources/Themes/zed-trek.json` (replaced from generated output)
- Modify: `Tests/CodeEditorPluginTests/Theming/ZedTrekDecodeTests.swift` (count 20→22, add HC names, signature values)
- Modify: snapshot `Tests/CodeEditorPluginTests/Theming/__Snapshots__/ThemeStyleSnapshotTests/*` (re-record)
- Modify: snapshot `Tests/CodeEditorDesignTokensTests/__Snapshots__/TokensSnapshotTests/tokensSnapshot.1.json` (re-record — new tokens)

**Interfaces:**
- Consumes: `zed-trek.generated.json` (Task 0), `PlatformExtension.onAccent` (Task 4).
- Produces: `ThemeFamily.bundled("zed-trek").themes.count == 22`; themes `LCARS High Contrast Dark` / `LCARS High Contrast Light` resolvable.

- [ ] **Step 1: Update the decode tests first (TDD anchor).** In `ZedTrekDecodeTests.swift`, change the two `#expect(family.themes.count == 20)` to `== 22`, update the test titles `20`→`22`, append the two HC names to the expected-names set, and add a signature suite:

```swift
@Test("22 themes with LCARS High Contrast present")
func highContrastPresent() throws {
    let family = try ThemeFamily.bundled("zed-trek")
    #expect(family.themes.count == 22)
    let names = Set(family.themes.map(\.name))
    #expect(names.contains("LCARS High Contrast Dark"))
    #expect(names.contains("LCARS High Contrast Light"))
}

@Test("hardened CSS signature values are present")
func signatureValues() throws {
    let family = try ThemeFamily.bundled("zed-trek")
    func style(_ n: String) -> ThemeStyle { family.theme(named: n)!.style }
    let lcarsDark = style("LCARS Dark")
    #expect(lcarsDark.chrome.surface == Tokens.Color(hex: 0x16_1F_33))
    #expect(lcarsDark.platform.onAccent == Tokens.Color(hex: 0x05_06_0A))
    #expect(lcarsDark.syntax["comment"]?.color == Tokens.Color(hex: 0x93_9B_A9))
    let hcDark = style("LCARS High Contrast Dark")
    #expect(hcDark.background == Tokens.Color(hex: 0x05_06_0A))
    #expect(hcDark.accents.first == Tokens.Color(hex: 0xFF_99_33))
    #expect(hcDark.status.error.base == Tokens.Color(hex: 0xF3_7F_7F))
    #expect(hcDark.text.placeholder == Tokens.Color(hex: 0x99_A1_AD))
    let hcLight = style("LCARS High Contrast Light")
    #expect(hcLight.background == Tokens.Color(hex: 0xFB_F7_F1))
}
```

> Verify the exact accessor names against the structs before running (spec's inventory): `chrome.surface`, `platform.onAccent`, `syntax[...]?.color`, `background`, `accents`, `status.error.base`, `text.placeholder`. If `theme(named:)` returns optional, keep the `!`-free style — use `#require`: `let dark = try #require(family.theme(named: "LCARS Dark"))`. Do NOT use force-unwrap (`!`) in committed code; the snippet above uses `!` for brevity — replace with `try #require(...)` per the `force_unwrapping` rule.

- [ ] **Step 2: Run to verify it fails.**

Run: `swift test --filter ZedTrekDecodeTests`
Expected: FAIL — count is 20, HC names absent.

- [ ] **Step 3: Replace the bundled JSON** with the generated file:

```bash
cp docs/superpowers/specs/2026-07-12-design-system-sync/tools/zed-trek.generated.json Sources/CodeEditorTheming/Resources/Themes/zed-trek.json
```

- [ ] **Step 4: Run to verify decode tests pass.**

Run: `swift test --filter ZedTrekDecodeTests`
Expected: PASS. If a signature `#expect` fails, the codegen key mapping is wrong for that key — fix `FLAT`/`SYN` in `gen_theme_json.py`, re-run Task 0 Step 3, re-copy, re-test (do NOT edit the JSON by hand).

- [ ] **Step 5: Re-record the theming snapshot.** Set `isRecording: true` in `ThemeStyleSnapshotTests`, run `swift test --filter ThemeStyleSnapshotTests`, revert the flag.

Run: `swift test --filter ThemeStyleSnapshotTests`
Expected: after re-record, PASS on the second (verify) run.

- [ ] **Step 6: Re-record the tokens snapshot** (new `Size.Control`/`Elevation`/`Tracking.tight` change the serialized token set if `TokensSnapshotTests` enumerates them). Set `isRecording: true`, run `swift test --filter TokensSnapshotTests`, revert.

Run: `swift test --filter TokensSnapshotTests`
Expected: PASS on the verify run. (If `TokensSnapshotTests` does not include the new tokens, no snapshot change occurs — that's fine, leave it.)

- [ ] **Step 7: Commit.**

```bash
git add Sources/CodeEditorTheming/Resources/Themes/zed-trek.json Tests/CodeEditorPluginTests/Theming/ZedTrekDecodeTests.swift Tests/CodeEditorPluginTests/Theming/__Snapshots__ Tests/CodeEditorDesignTokensTests/__Snapshots__
git commit -m "feat(design): regenerate zed-trek.json to 22 themes (HC pair + hardened values)"
```

---

### Task 6: Update theme-count references 20 → 22

**Files:**
- Modify: `Sources/CodeEditorSample/Switchers/ThemeCatalog.swift:7` (comment)
- Modify: `docs/FeatureMatrix.md:49`
- Modify: `CLAUDE.md` (if it states a theme/variant count — grep first)
- Modify: `docs/Diagrams/**` (if any diagram states 20 variants — grep first)

**Interfaces:** none (docs/comments only).

- [ ] **Step 1: Find every live reference** (exclude historical plans, which are point-in-time):

Run: `grep -rniE '20[^0-9]{0,20}(theme|variant)|(theme|variant)[^0-9]{0,20}20' Sources/ docs/FeatureMatrix.md docs/Diagrams/ CLAUDE.md README.md 2>/dev/null | grep -v 'docs/superpowers/plans'`
Expected: `ThemeCatalog.swift:7`, `docs/FeatureMatrix.md:49`, plus any diagram/CLAUDE hit.

- [ ] **Step 2: Update each hit** `20 → 22` in prose (e.g. `ThemeCatalog.swift:7` "20 `zed-trek` variants" → "22", `FeatureMatrix.md:49` "20 variants" → "22 variants"). Do not touch `docs/superpowers/plans/*` (historical).

- [ ] **Step 3: Verify no live `20`-variant claim remains.**

Run: `grep -rniE '20[^0-9]{0,20}(theme|variant)|(theme|variant)[^0-9]{0,20}20' Sources/ docs/FeatureMatrix.md docs/Diagrams/ CLAUDE.md README.md 2>/dev/null | grep -v 'docs/superpowers/plans'`
Expected: no output.

- [ ] **Step 4: Commit.**

```bash
git add -A
git commit -m "docs(design): update bundled theme count 20 -> 22"
```

---

### Task 7: Minimal wiring — bridge accessors for the new roles

**Files:**
- Modify: `Sources/CodeEditorTheming/Bridges/Tokens.Color+SwiftUI.swift` OR a new `Sources/CodeEditorTheming/Bridges/ThemeStyle+Roles.swift` (convenience accessors)
- Test: `Tests/CodeEditorPluginTests/Theming/PlatformExtensionTests.swift` (extend)

**Interfaces:**
- Consumes: `PlatformExtension.onAccent`/`onDanger` (Task 4).
- Produces: `ThemeStyle.onAccent`/`ThemeStyle.onDanger`/`ThemeStyle.glassTint: Tokens.Color` convenience accessors (thin pass-throughs to `platform`), so consumers read roles off `style` without reaching into `platform`.

- [ ] **Step 1: Write the failing test** — append to `PlatformExtensionTests.swift`:

```swift
@Test("ThemeStyle exposes role accessors")
func styleRoleAccessors() {
    let s = Theme.fallback(appearance: .dark).style
    #expect(s.onAccent == s.platform.onAccent)
    #expect(s.onDanger == s.platform.onDanger)
    #expect(s.glassTint == s.platform.glass.tint)
}
```

- [ ] **Step 2: Run to verify it fails.**

Run: `swift test --filter PlatformExtensionTests`
Expected: build failure — `ThemeStyle` has no member `onAccent`.

- [ ] **Step 3: Implement** — create `Sources/CodeEditorTheming/Bridges/ThemeStyle+Roles.swift`:

```swift
import CodeEditorDesignTokens

extension ThemeStyle {
    /// Text/icon color on an accent-1 (primary button) fill.
    public var onAccent: Tokens.Color { platform.onAccent }
    /// Text/icon color on a diag-error (destructive button) fill.
    public var onDanger: Tokens.Color { platform.onDanger }
    /// Liquid-Glass base tint for this theme.
    public var glassTint: Tokens.Color { platform.glass.tint }
}
```

- [ ] **Step 4: Run to verify it passes.**

Run: `swift test --filter PlatformExtensionTests`
Expected: PASS.

> No primary-button consumer in the framework currently reads a hardcoded on-accent literal (this is a framework, not an app; broad application is deferred per the spec). Roles are defined-and-exposed; a follow-up wires them into `CodeEditorUI` controls.

- [ ] **Step 5: Commit.**

```bash
git add Sources/CodeEditorTheming/Bridges/ThemeStyle+Roles.swift Tests/CodeEditorPluginTests/Theming/PlatformExtensionTests.swift
git commit -m "feat(design): expose on-accent/on-danger/glass-tint role accessors on ThemeStyle"
```

---

### Task 8: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Full gate.**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
Expected: build succeeds, lint clean, all tests pass. Address any `missing_docs` on new `public` members and any residual old-init call sites surfaced by the build.

- [ ] **Step 2: Confirm no orphaned snapshot recording flags.**

Run: `grep -rn 'isRecording: true' Tests/`
Expected: no output (all re-record flags reverted).

- [ ] **Step 3: Confirm the codegen is reproducible** (re-run must be a no-op against the committed JSON's semantic keys).

Run: `python3 docs/superpowers/specs/2026-07-12-design-system-sync/tools/gen_theme_json.py && echo OK`
Expected: `OK: 22 themes emitted` then `OK`.

- [ ] **Step 4: Final commit (if any fixups).**

```bash
git add -A && git commit -m "test(design): full gate green after design-system sync" || echo "nothing to commit"
```

---

## Self-Review

**Spec coverage:** §Component 1 (Size.Control, Elevation, Tracking.tight) → Tasks 1-3. §Component 2 (PlatformExtension on-roles + explicit glass + Elevation-sourced shadow; diagnostics via status/vcs) → Task 4 + codegen (Task 0). §Component 3 (merge-codegen, 22 themes, CSS→Zed map, HC derivation, count refs) → Tasks 0, 5, 6. §Component 4 (minimal wiring) → Task 7. §Testing/verification → folded per task + Task 8. `Tokens.Spacing.smMd` spec note "already exists" → confirmed, no task (correct).

**Placeholder scan:** No TBD/TODO/"handle appropriately". Every code step shows full content; every run step has an exact command + expected output.

**Type consistency:** `Tokens.Elevation.Shadow{color,blur,x,y}` (Task 2) is consumed by `derived()` mapping `e.color/e.blur/e.x/e.y` → `PlatformExtension.Shadow(color:blur:xOffset:yOffset:)` (Task 4) — field names differ deliberately across the two Shadow types and the mapping is explicit. `PlatformExtension.init(glass:shadows:field:onAccent:onDanger:extras:)` (Task 4) matches its sole call site in `derived()` (Task 4 Step 5). `onAccent`/`onDanger` names consistent across Tasks 4/5/7. `Tokens.Size.Control.*` names (Task 1) match their test (Task 1 Step 1).

**Known hazards flagged in-task:** the `!`/`#require` force-unwrap rule (Task 5 Step 1 note); `AppearanceHolder.appearance` optionality (Task 4 Step 4 note); accessor-name verification against structs before running (Task 5 Step 1 note); snapshot re-record flag hygiene (Task 8 Step 2).
```
