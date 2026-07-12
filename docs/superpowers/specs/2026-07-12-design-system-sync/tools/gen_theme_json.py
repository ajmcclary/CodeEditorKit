#!/usr/bin/env python3
"""Merge colors_and_type.css semantic values over the existing zed-trek.json.
Dev-only. Preserves Zed-only superset keys; overwrites the ~50 CSS-defined keys;
adds a platform block; derives the two LCARS High-Contrast themes from LCARS.
Re-run against a newer CSS to re-sync. Not part of any build target."""
import re, json, copy, pathlib

HERE = pathlib.Path(__file__).parent
# Strip /* ... */ comments first: the header comment lists `.theme-*` class
# names as prose, which would otherwise be matched as (malformed) blocks.
CSS = re.sub(r"/\*.*?\*/", "", (HERE / "colors_and_type.css").read_text(), flags=re.S)
JSON_SRC = HERE.parents[4] / "Sources/CodeEditorTheming/Resources/Themes/zed-trek.json"
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
