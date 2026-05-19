// SYNTAXHIGHLIGHTING · CONCEPT C — "SPEC DECK"
// One scrolling page.  Treats the theme as a published specification
// rather than a UI: every TokenType (and its dotted children) is a row
// with name · description · light swatch · dark swatch · contrast
// reading · sample expression rendered in both modes. Below that, the
// LanguageRegistry surface — 25 languages + plain text, grouped by
// backing highlighter.  Reads like an Apple developer doc page.

const ShC = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Kbd, Overline, Segmented } = window;
  const { useState } = React;

  // Same taxonomy as concept A, with sample expressions per token.
  const ROWS = [
    { name: "keyword",              desc: "Language keywords (if, for, return)",          dark: "#AE7CE9", light: "#AE2EE3", sample: "return",        contrast: { d: 7.9, l: 6.1 } },
    { name: "keyword.control",      desc: "Control-flow subclass",                         dark: "#C098F1", light: "#9019C8", sample: "if value > 0",  contrast: { d: 7.2, l: 7.4 } },
    { name: "keyword.declaration",  desc: "Declaration keywords (class, struct, func)",    dark: "#9F66D7", light: "#7A12B0", sample: "public func",   contrast: { d: 8.6, l: 9.1 } },
    { name: "identifier",           desc: "Plain identifiers",                             dark: "#F2F2F7", light: "#000000", sample: "annotation",    contrast: { d: 17,  l: 21  } },
    { name: "string",               desc: "String literals",                               dark: "#FA6364", light: "#C41A17", sample: '"hello"',       contrast: { d: 6.4, l: 6.4 } },
    { name: "number",               desc: "Numeric literals",                              dark: "#DBB842", light: "#216DD9", sample: "0xFF · 3.14",   contrast: { d: 9.2, l: 5.0 } },
    { name: "comment",              desc: "Code comments",                                 dark: "#6B7787", light: "#6B7787", sample: "// note",       contrast: { d: 4.7, l: 4.4 }, italic: true },
    { name: "comment.documentation", desc: "Doc comments — /// or /** */",                 dark: "#8C99AB", light: "#445063", sample: "/// API doc",   contrast: { d: 6.7, l: 7.6 }, italic: true },
    { name: "type",                 desc: "Type names",                                    dark: "#8FD6D6", light: "#007575", sample: "AnnotationKind",contrast: { d: 12, l: 6.4 } },
    { name: "type.builtin",         desc: "Built-in types (Int, String)",                  dark: "#A1E4E4", light: "#005A5A", sample: "Int · String",  contrast: { d: 13, l: 8.1 } },
    { name: "function",             desc: "Function definitions",                          dark: "#669EE6", light: "#007575", sample: "register(_:)",  contrast: { d: 7.8, l: 6.4 } },
    { name: "function.call",        desc: "Function invocations",                          dark: "#80B5F0", light: "#005A92", sample: "encode(.kind)", contrast: { d: 9.0, l: 7.4 } },
    { name: "property",             desc: "Property accesses",                             dark: "#D69921", light: "#805900", sample: ".kind",         contrast: { d: 7.0, l: 6.5 } },
    { name: "operator",             desc: "+ − × ÷ % == !=",                              dark: "#B3B3C2", light: "#666666", sample: "->",            contrast: { d: 9.2, l: 5.7 } },
    { name: "punctuation",          desc: "Brackets, commas, dots",                        dark: "#999AA6", light: "#808080", sample: "{ } ,",         contrast: { d: 5.9, l: 4.6 } },
    { name: "preprocessor",         desc: "@available · #if · @MainActor",                 dark: "#BF8AE3", light: "#A14AA3", sample: "@MainActor",    contrast: { d: 8.8, l: 6.0 } },
  ];

  function Swatch({ side, color, sample, italic, contrast }) {
    const isDark = side === "dark";
    return (
      <div style={{
        background: isDark ? "#0F1218" : "#FBFBFC",
        color: isDark ? "#E4E5EA" : "#1A1A1F",
        padding: "8px 10px", borderRadius: 7,
        boxShadow: `inset 0 0 0 0.5px ${isDark ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.08)"}`,
        display: "grid", gridTemplateColumns: "24px 1fr auto", gap: 8, alignItems: "center",
      }}>
        <span style={{
          width: 20, height: 20, borderRadius: 4, background: color,
          boxShadow: `inset 0 0 0 0.5px ${isDark ? "rgba(0,0,0,0.4)" : "rgba(0,0,0,0.15)"}`,
        }}/>
        <code style={{
          font: `${italic ? "italic " : ""}500 12.5px var(--font-mono)`,
          color: color,
          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
        }}>{sample}</code>
        <span style={{
          font: "10px var(--font-mono)",
          color: isDark ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.5)",
          textAlign: "right",
        }}>
          {color.toUpperCase()}
          <br/>
          <span style={{ color: contrast >= 7 ? "var(--status-success)" : contrast >= 4.5 ? "var(--status-warning)" : "var(--status-error)" }}>
            {contrast.toFixed(1)} : 1
          </span>
        </span>
      </div>
    );
  }

  function Row({ r }) {
    const depth = r.name.includes(".") ? 1 : 0;
    return (
      <div style={{
        display: "grid",
        gridTemplateColumns: `${4 + depth * 16}px 200px 1fr 1fr`,
        gap: 10, alignItems: "center",
        padding: "9px 14px",
        borderTop: "0.5px solid var(--border-variant)",
      }}>
        <span style={{ height: 14,
          borderLeft: depth > 0 ? "1px solid var(--border-variant)" : "none" }}/>
        <div style={{ minWidth: 0 }}>
          <code style={{
            font: "600 13px var(--font-mono)", color: "var(--accent-1)",
            whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", display: "block",
          }}>{r.name}</code>
          <div style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)" }}>{r.desc}</div>
        </div>
        <Swatch side="dark"  color={r.dark}  sample={r.sample} italic={r.italic} contrast={r.contrast.d}/>
        <Swatch side="light" color={r.light} sample={r.sample} italic={r.italic} contrast={r.contrast.l}/>
      </div>
    );
  }

  const LANGS = [
    "Swift","TypeScript","JavaScript","C","C++","Java","Go","Rust","CSS","JSON",
    "PHP","C#","Kotlin","Dart","Dockerfile","TOML","Lua","Python","YAML","Markdown",
    "XML","HTML","Shell","SQL","Ruby","Plain Text",
  ];

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Theme Spec" subtitle="CodeEditorSyntaxHighlighting · LCARS"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, minHeight: 0, overflowY: "auto", background: "var(--bg)" }}>

          {/* Hero / metadata */}
          <div style={{ padding: "20px 16px 18px",
            background: "linear-gradient(180deg, color-mix(in srgb, var(--accent-1) 6%, transparent), transparent)" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Overline color="var(--accent-1)">SYNTAX THEME · SPECIFICATION</Overline>
              <span style={{ flex: 1 }}/>
              <Pill size="sm">Export Zed JSON</Pill>
              <Pill size="sm" active>Copy as Swift</Pill>
            </div>
            <div style={{
              display: "flex", alignItems: "baseline", gap: 14, marginTop: 6,
            }}>
              <span style={{ font: "700 28px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.3 }}>LCARS</span>
              <span style={{ font: "300 28px/1 var(--font-display)", color: "var(--text-muted)" }}>·</span>
              <span style={{ font: "500 14px var(--font-sans)", color: "var(--text-muted)" }}>dark + light</span>
              <span style={{ flex: 1 }}/>
              <span style={{ font: "11px var(--font-mono)", color: "var(--text-muted)" }}>
                schema · zed.dev/v0.2.0 · 16 tokens · 4 dotted children · plus 5 status / diag entries
              </span>
            </div>
            <div style={{
              marginTop: 10, display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8,
            }}>
              {[
                { l: "Editor BG · dark",  v: "#0F1218" },
                { l: "Editor FG · dark",  v: "#E4E5EA" },
                { l: "Editor BG · light", v: "#FBFBFC" },
                { l: "Editor FG · light", v: "#1A1A1F" },
              ].map(b => (
                <div key={b.l} style={{
                  padding: "6px 9px", borderRadius: 7,
                  background: "var(--surface)",
                  boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
                  display: "grid", gridTemplateColumns: "20px 1fr", gap: 8, alignItems: "center",
                }}>
                  <span style={{
                    width: 16, height: 16, borderRadius: 4, background: b.v,
                    boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.2)",
                  }}/>
                  <div>
                    <div style={{ font: "9.5px var(--font-sans)", letterSpacing: 0.5, textTransform: "uppercase",
                      color: "var(--text-muted)", fontWeight: 700 }}>{b.l}</div>
                    <div style={{ font: "11px var(--font-mono)", color: "var(--text)" }}>{b.v}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Token table */}
          <div style={{
            margin: "0 14px",
            background: "var(--surface)",
            borderRadius: 10,
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
            overflow: "hidden",
          }}>
            <div style={{
              display: "grid",
              gridTemplateColumns: `4px 200px 1fr 1fr`,
              gap: 10, padding: "8px 14px",
              background: "color-mix(in srgb, var(--accent-1) 5%, transparent)",
              borderBottom: "0.5px solid var(--border-variant)",
              font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
              color: "var(--text-muted)",
            }}>
              <span/>
              <span>TOKEN · DESCRIPTION</span>
              <span style={{ display: "flex", alignItems: "center", gap: 5 }}><Ic.Moon size={11}/>DARK</span>
              <span style={{ display: "flex", alignItems: "center", gap: 5 }}><Ic.Sun size={11}/>LIGHT</span>
            </div>
            {ROWS.map(r => <Row key={r.name} r={r}/>)}
          </div>

          {/* Language Registry slab */}
          <div style={{
            margin: "16px 14px",
            padding: 14, borderRadius: 10,
            background: "var(--surface)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
              <Overline color="var(--accent-1)">LANGUAGE REGISTRY</Overline>
              <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                · 25 languages + plain text · 3 highlighter backends
              </span>
            </div>
            <div style={{ marginTop: 10, display: "flex", flexWrap: "wrap", gap: 6 }}>
              {LANGS.map(l => (
                <span key={l} style={{
                  font: "500 11px var(--font-mono)", color: "var(--text)",
                  padding: "3px 8px", borderRadius: 6,
                  background: l === "Swift" ? "color-mix(in srgb, var(--accent-1) 18%, transparent)" : "var(--element-bg)",
                  boxShadow: l === "Swift" ? "inset 0 0 0 0.5px var(--accent-1)" : "inset 0 0 0 0.5px var(--border-variant)",
                  color: l === "Swift" ? "var(--accent-1)" : "var(--text)",
                }}>
                  {l}{l === "Swift" ? <span style={{ marginLeft: 6, font: "9.5px var(--font-sans)", letterSpacing: 0.4, textTransform: "uppercase" }}>SwiftSyntax</span> : null}
                </span>
              ))}
            </div>
            <div style={{
              marginTop: 12, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8,
            }}>
              {[
                { name: "SwiftSyntaxHighlighter", note: "Compiler-grade tree-sitter–free parsing", c: "var(--accent-1)" },
                { name: "RegexSyntaxHighlighter", note: "Descriptor-based; 24 of the 26 languages", c: "var(--accent-2)" },
                { name: "PlainTextHighlighter",   note: "No-op; preserves text colour from theme.editor.foreground", c: "var(--text-muted)" },
              ].map(b => (
                <div key={b.name} style={{
                  padding: "8px 10px", borderRadius: 7,
                  background: `color-mix(in srgb, ${b.c} 7%, transparent)`,
                  boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${b.c} 35%, transparent)`,
                }}>
                  <div style={{ font: "600 12px var(--font-mono)", color: b.c }}>{b.name}</div>
                  <div style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)", marginTop: 2 }}>{b.note}</div>
                </div>
              ))}
            </div>
          </div>

          <div style={{
            margin: "0 14px 18px", padding: "10px 14px",
            border: "0.5px dashed var(--border-variant)", borderRadius: 8,
            display: "flex", alignItems: "center", gap: 8,
            font: "11px var(--font-sans)", color: "var(--text-muted)",
          }}>
            <Ic.Info size={13}/>
            Theme resolution: <code style={{ color: "var(--text)" }}>Theme.color(forToken:)</code> walks dotted names from most specific to least specific, falling back to <code style={{ color: "var(--text)" }}>style.editor.foreground</code> as the final default.
            <span style={{ flex: 1 }}/>
            <Kbd>⌘E</Kbd>
            <span>open editor</span>
          </div>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ShC = ShC;
