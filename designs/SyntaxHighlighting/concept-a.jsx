// SYNTAXHIGHLIGHTING · CONCEPT A — "THEME EDITOR"
// Token-color editor.  Triptych:
//   Left   · token-name tree — TokenType / TokenName, hierarchical
//            (keyword.control, keyword.declaration, etc.).  Selecting
//            a node loads its colour into the inspector.
//   Centre · live code sample with every token kind, rendered against
//            the currently-active theme.  Side-by-side light/dark
//            split so the editor can confirm contrast in both modes
//            at once.
//   Right  · inspector — RGB / hex / contrast / font-weight + italic
//            toggle for the selected TokenName.

const ShA = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Kbd, Overline, Segmented, Switch } = window;
  const { useState } = React;

  // Token taxonomy.  Top-level entries are TokenType cases; nested
  // entries are TokenName children (Theme.color(forToken:) does dotted
  // hierarchical fallback to the parent).
  const TREE = [
    { id: "keyword",      name: "keyword",      desc: "Language keywords",         dark: "#AE7CE9", light: "#AE2EE3", children: [
      { id: "keyword.control",     name: "keyword.control",     desc: "if · for · while · return", dark: "#C098F1", light: "#9019C8" },
      { id: "keyword.declaration", name: "keyword.declaration", desc: "class · struct · func",     dark: "#9F66D7", light: "#7A12B0" },
    ]},
    { id: "identifier",   name: "identifier",   desc: "Plain identifiers",          dark: "#F2F2F7", light: "#000000" },
    { id: "string",       name: "string",       desc: "String literals",            dark: "#FA6364", light: "#C41A17", children: [
      { id: "string.interpolation", name: "string.interpolation", desc: "Interpolated expressions", dark: "#FF9F9F", light: "#A91714" },
    ]},
    { id: "number",       name: "number",       desc: "Numeric literals",           dark: "#DBB842", light: "#216DD9" },
    { id: "comment",      name: "comment",      desc: "Code comments",              dark: "#6B7787", light: "#6B7787", children: [
      { id: "comment.documentation", name: "comment.documentation", desc: "/// /** … */",          dark: "#8C99AB", light: "#445063" },
    ]},
    { id: "type",         name: "type",         desc: "Type names",                 dark: "#8FD6D6", light: "#007575", children: [
      { id: "type.builtin", name: "type.builtin", desc: "Int · String · Bool",      dark: "#A1E4E4", light: "#005A5A" },
    ]},
    { id: "function",     name: "function",     desc: "Function names",             dark: "#669EE6", light: "#007575", children: [
      { id: "function.call",        name: "function.call",        desc: "Invocations",             dark: "#80B5F0", light: "#005A92" },
    ]},
    { id: "property",     name: "property",     desc: "Property names",             dark: "#D69921", light: "#805900" },
    { id: "operator",     name: "operator",     desc: "+ − × ÷",                    dark: "#B3B3C2", light: "#666666" },
    { id: "punctuation",  name: "punctuation",  desc: "Brackets, commas, dots",     dark: "#999AA6", light: "#808080" },
    { id: "preprocessor", name: "preprocessor", desc: "@available · #if",           dark: "#BF8AE3", light: "#A14AA3" },
  ];

  function flat(node) {
    return [node, ...(node.children || []).flatMap(flat)];
  }
  function findById(id) {
    for (const n of TREE) {
      for (const c of flat(n)) if (c.id === id) return c;
    }
    return TREE[0];
  }

  function Tree({ selId, setSel }) {
    return (
      <div style={{
        width: 232, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px 8px" }}>
          <Overline>TOKEN TAXONOMY</Overline>
          <div style={{
            display: "flex", alignItems: "center", gap: 6,
            marginTop: 8, height: 26, padding: "0 10px",
            borderRadius: 6, background: "var(--element-bg)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          }}>
            <Ic.Search size={12}/>
            <input placeholder="filter token-names…" readOnly style={{
              flex: 1, background: "transparent", border: "none", outline: "none",
              color: "var(--text-placeholder)", font: "12px var(--font-sans)",
            }}/>
          </div>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "0 4px 8px" }}>
          {TREE.flatMap(n => flat(n).map((c, i) => {
            const depth = c.name.includes(".") ? 1 : 0;
            const active = selId === c.id;
            return (
              <div key={c.id} onClick={() => setSel(c.id)} style={{
                display: "grid",
                gridTemplateColumns: `${10 + depth * 14}px 16px 1fr auto`,
                alignItems: "center", gap: 6,
                padding: "5px 8px", borderRadius: 5,
                margin: "0 4px 1px",
                cursor: "pointer",
                background: active ? "var(--element-selected)" : "transparent",
                boxShadow: active ? "inset 2px 0 0 0 var(--accent-1)" : "none",
              }}>
                <span style={{ height: 12, marginLeft: 8,
                  borderLeft: depth > 0 ? "1px solid var(--border-variant)" : "none" }}/>
                <span style={{
                  width: 12, height: 12, borderRadius: 3, background: c.dark,
                  boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.18)",
                }}/>
                <code style={{
                  font: "12px var(--font-mono)", color: "var(--text)",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                }}>{c.name}</code>
                <span style={{ font: "9.5px var(--font-mono)", color: "var(--text-disabled)" }}>{c.dark.toUpperCase()}</span>
              </div>
            );
          }))}
        </div>
        <div style={{
          margin: 8, padding: 10, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        }}>
          <Overline>INHERITANCE</Overline>
          <div style={{ font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 6, lineHeight: 1.45 }}>
            <code style={{ color: "var(--accent-1)" }}>keyword.control</code> falls back to <code style={{ color: "var(--text)" }}>keyword</code>, then to <code style={{ color: "var(--text)" }}>editor.foreground</code>.
          </div>
        </div>
      </div>
    );
  }

  // The side-by-side sample.  Light surface, dark surface, identical
  // source — uses the dark/light colour from each node.
  function Sample({ side }) {
    const isDark = side === "dark";
    const c = (id) => findById(id)[isDark ? "dark" : "light"];
    return (
      <div style={{
        flex: 1, display: "flex", flexDirection: "column", minWidth: 0,
        background: isDark ? "#0F1218" : "#FBFBFC",
        color: isDark ? "#E4E5EA" : "#1A1A1F",
      }}>
        <div style={{
          height: 24, padding: "0 12px",
          display: "flex", alignItems: "center", gap: 6,
          background: isDark ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.04)",
          borderBottom: `0.5px solid ${isDark ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.10)"}`,
          font: "10.5px var(--font-mono)",
          color: isDark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)",
        }}>
          {isDark ? <Ic.Moon size={11}/> : <Ic.Sun size={11}/>}
          {isDark ? "LCARS Dark · editor preview" : "LCARS Light · editor preview"}
        </div>
        <div style={{ flex: 1, padding: "10px 12px", overflow: "hidden", font: "12px/1.55 var(--font-mono)" }}>
          <div><span style={{ color: c("preprocessor") }}>@MainActor</span></div>
          <div><span style={{ color: c("keyword.declaration") }}>public final class</span>{" "}<span style={{ color: c("type") }}>LSPClient</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("type") }}>ObservableObject</span>{" "}<span style={{ color: c("punctuation") }}>{"{"}</span></div>
          <div>{"    "}<span style={{ color: c("comment.documentation") }}>/// Current connection state</span></div>
          <div>{"    "}<span style={{ color: c("keyword") }}>@Published</span>{" "}<span style={{ color: c("keyword.declaration") }}>public</span>{" "}<span style={{ color: c("keyword.declaration") }}>private</span><span style={{ color: c("punctuation") }}>(</span><span style={{ color: c("keyword") }}>set</span><span style={{ color: c("punctuation") }}>)</span>{" "}<span style={{ color: c("keyword.declaration") }}>var</span>{" "}<span style={{ color: c("property") }}>connectionState</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("type.builtin") }}>ConnectionState</span>{" "}<span style={{ color: c("operator") }}>=</span>{" "}<span style={{ color: c("identifier") }}>.disconnected</span></div>
          <div>{"    "}<span style={{ color: c("comment") }}>{"// Active diagnostics by document URI"}</span></div>
          <div>{"    "}<span style={{ color: c("keyword.declaration") }}>public</span>{" "}<span style={{ color: c("keyword.declaration") }}>var</span>{" "}<span style={{ color: c("property") }}>diagnostics</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("punctuation") }}>[</span><span style={{ color: c("type.builtin") }}>String</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("punctuation") }}>[</span><span style={{ color: c("type") }}>LSPDiagnostic</span><span style={{ color: c("punctuation") }}>]] =</span>{" "}<span style={{ color: c("punctuation") }}>[:]</span></div>
          <div>{" "}</div>
          <div>{"    "}<span style={{ color: c("keyword.declaration") }}>public func</span>{" "}<span style={{ color: c("function") }}>requestCompletion</span><span style={{ color: c("punctuation") }}>(</span></div>
          <div>{"        "}<span style={{ color: c("property") }}>uri</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("type.builtin") }}>String</span><span style={{ color: c("punctuation") }}>,</span></div>
          <div>{"        "}<span style={{ color: c("property") }}>position</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("type") }}>Position</span></div>
          <div>{"    "}<span style={{ color: c("punctuation") }}>)</span>{" "}<span style={{ color: c("keyword") }}>async throws</span>{" "}<span style={{ color: c("operator") }}>{"->"}</span>{" "}<span style={{ color: c("type") }}>CompletionList</span>{" "}<span style={{ color: c("punctuation") }}>{"{"}</span></div>
          <div>{"        "}<span style={{ color: c("keyword") }}>let</span>{" "}<span style={{ color: c("property") }}>params</span>{" "}<span style={{ color: c("operator") }}>=</span>{" "}<span style={{ color: c("function.call") }}>createCompletionParams</span><span style={{ color: c("punctuation") }}>(</span><span style={{ color: c("property") }}>uri</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("identifier") }}>uri</span><span style={{ color: c("punctuation") }}>,</span>{" "}<span style={{ color: c("property") }}>position</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("identifier") }}>position</span><span style={{ color: c("punctuation") }}>)</span></div>
          <div>{"        "}<span style={{ color: c("keyword") }}>let</span>{" "}<span style={{ color: c("property") }}>response</span>{" "}<span style={{ color: c("operator") }}>=</span>{" "}<span style={{ color: c("keyword") }}>try await</span>{" "}<span style={{ color: c("function.call") }}>sendRequest</span><span style={{ color: c("punctuation") }}>(</span><span style={{ color: c("property") }}>method</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("string") }}>"textDocument/completion"</span><span style={{ color: c("punctuation") }}>,</span>{" "}<span style={{ color: c("property") }}>params</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("identifier") }}>params</span><span style={{ color: c("punctuation") }}>)</span></div>
          <div>{"        "}<span style={{ color: c("keyword") }}>return</span>{" "}<span style={{ color: c("keyword") }}>try</span>{" "}<span style={{ color: c("function.call") }}>parseCompletionResponse</span><span style={{ color: c("punctuation") }}>(</span><span style={{ color: c("identifier") }}>response</span><span style={{ color: c("punctuation") }}>)</span></div>
          <div>{"    "}<span style={{ color: c("punctuation") }}>{"}"}</span></div>
          <div>{"    "}<span style={{ color: c("comment") }}>{"// Numeric retry-policy below"}</span></div>
          <div>{"    "}<span style={{ color: c("keyword.declaration") }}>public</span>{" "}<span style={{ color: c("keyword.declaration") }}>let</span>{" "}<span style={{ color: c("property") }}>maxAttempts</span><span style={{ color: c("punctuation") }}>:</span>{" "}<span style={{ color: c("type.builtin") }}>Int</span>{" "}<span style={{ color: c("operator") }}>=</span>{" "}<span style={{ color: c("number") }}>5</span></div>
          <div><span style={{ color: c("punctuation") }}>{"}"}</span></div>
        </div>
      </div>
    );
  }

  function Inspector({ sel, italic, setItalic, bold, setBold }) {
    return (
      <div style={{
        width: 232, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "14px 14px" }}>
          <Overline>SELECTED TOKEN</Overline>
          <div style={{
            font: "600 13px var(--font-mono)", color: "var(--accent-1)", marginTop: 4,
          }}>{sel.name}</div>
          <div style={{ font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 2 }}>{sel.desc}</div>
        </div>

        {/* Dark swatch */}
        {[
          { label: "DARK",  v: sel.dark,  bg: "#0F1218", fg: "#E4E5EA", icon: <Ic.Moon size={11}/> },
          { label: "LIGHT", v: sel.light, bg: "#FBFBFC", fg: "#1A1A1F", icon: <Ic.Sun size={11}/> },
        ].map(s => (
          <div key={s.label} style={{
            margin: "0 14px 10px", borderRadius: 7, overflow: "hidden",
            background: s.bg, color: s.fg,
            boxShadow: "0 0 0 0.5px var(--border-variant)",
          }}>
            <div style={{
              display: "flex", alignItems: "center", gap: 6, padding: "4px 8px",
              font: "10.5px var(--font-mono)",
              borderBottom: `0.5px solid ${s.label === "DARK" ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.08)"}`,
              color: s.label === "DARK" ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)",
            }}>{s.icon} {s.label}</div>
            <div style={{ display: "flex", alignItems: "center", gap: 8, padding: 8 }}>
              <span style={{
                width: 24, height: 24, borderRadius: 5, background: s.v,
                boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.18)",
              }}/>
              <div style={{ flex: 1 }}>
                <div style={{ font: "600 12px var(--font-mono)" }}>{s.v.toUpperCase()}</div>
                <div style={{ font: "10.5px var(--font-mono)", color: s.label === "DARK" ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)" }}>
                  contrast {s.label === "DARK" ? "8.4" : "5.1"}
                </div>
              </div>
            </div>
          </div>
        ))}

        <div style={{ padding: "0 14px" }}>
          <Overline>STYLE</Overline>
          <div style={{ marginTop: 6, display: "flex", flexDirection: "column", gap: 6 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ flex: 1, font: "12px var(--font-sans)", color: "var(--text)" }}>Bold</span>
              <Switch on={bold} onClick={() => setBold(!bold)}/>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ flex: 1, font: "12px var(--font-sans)", color: "var(--text)" }}>Italic</span>
              <Switch on={italic} onClick={() => setItalic(!italic)}/>
            </div>
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ padding: 12, borderTop: "0.5px solid var(--border-variant)",
          display: "flex", flexDirection: "column", gap: 6 }}>
          <Pill icon={<Ic.Palette size={11}/>}>Bind to theme.style.syntax.{sel.name}</Pill>
          <Pill icon={<Ic.Rotate size={11}/>}>Reset to LCARS default</Pill>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [selId, setSel] = useState("keyword.declaration");
    const sel = findById(selId);
    const [italic, setItalic] = useState(selId === "comment" || selId.startsWith("comment"));
    const [bold, setBold] = useState(selId === "keyword.declaration");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Theme Editor" subtitle="CodeEditorSyntaxHighlighting · LCARS"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <Tree selId={selId} setSel={setSel}/>
          <div style={{ flex: 1, minWidth: 0, display: "flex" }}>
            <Sample side="dark"/>
            <div style={{ width: 0.5, background: "var(--border-variant)" }}/>
            <Sample side="light"/>
          </div>
          <Inspector sel={sel} italic={italic} setItalic={setItalic} bold={bold} setBold={setBold}/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>theme: <span style={{ color: "var(--text)" }}>lcars-dark · lcars-light</span></span>
          <span>·</span>
          <span>fallback: editor.foreground</span>
          <span style={{ flex: 1 }}/>
          <span>13 TokenType cases · 4 dotted children</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ShA = ShA;
