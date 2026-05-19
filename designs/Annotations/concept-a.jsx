// ANNOTATIONS · CONCEPT A — "INLINE"
// The in-editor presentation only.  No side rail, no problem panel.
// Annotations live where the code lives:
//   • gutter glyphs at imageScale(.small), tinted by AnnotationKind.color(in:theme)
//   • inline message bubbles trailing the line for warnings/errors
//   • hover/expanded popover that mirrors AnnotationView.popup on macOS
//   • dense vs sparse toggle (badges only ↔ bubbles trailing every line)
// AnnotationKind taxonomy mirrors AnnotationKind.swift exactly:
// info / note / todo / fixme / warning / error, with the same SF Symbols.

const AnnA = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Segmented, Pill, SevDot, Kbd } = window;
  const { useState } = React;

  // 1:1 with AnnotationKind enum.
  const KINDS = {
    info:    { label: "INFO",    icon: <Ic.Info size={11}/>,    color: "var(--diag-info)"    },
    note:    { label: "NOTE",    icon: <Ic.Info size={11}/>,    color: "var(--diag-info)"    },
    todo:    { label: "TODO",    icon: <Ic.Todo size={11}/>,    color: "var(--diag-info)"    },
    fixme:   { label: "FIXME",   icon: <Ic.Wrench size={11}/>,  color: "var(--diag-warning)" },
    warning: { label: "WARNING", icon: <Ic.Warning size={11}/>, color: "var(--diag-warning)" },
    error:   { label: "ERROR",   icon: <Ic.Error size={11}/>,   color: "var(--diag-error)"   },
  };

  // Sample document.  Every line that carries an annotation lists its
  // kind + message exactly as a `MessageLineAnnotation.message` would.
  // Lines are intentionally dense at 20–32 so the gutter has work to do.
  const LINES = [
    { n: 18, code: <><Tk.K>func</Tk.K> <Tk.F>encode</Tk.F>(<Tk.V>to</Tk.V> encoder: <Tk.T>any</Tk.T> <Tk.T>Encoder</Tk.T>) <Tk.K>throws</Tk.K> <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 19, code: <>{"    "}<Tk.K>var</Tk.K> container = encoder.<Tk.F>container</Tk.F>(keyedBy: <Tk.T>CodingKeys</Tk.T>.<Tk.K>self</Tk.K>)</>, ann: { kind: "warning", message: "Initialization can be replaced by 'let' to enforce immutability." } },
    { n: 20, code: <>{"    "}<Tk.K>try</Tk.K> container.<Tk.F>encode</Tk.F>(text, forKey: .text)</> },
    { n: 21, code: <>{"    "}<Tk.K>try</Tk.K> container.<Tk.F>encode</Tk.F>(kind.rawValue, forKey: .kind)</>, ann: { kind: "error", message: "Value of optional type 'AnnotationKind?' must be unwrapped to a value of type 'AnnotationKind'." } },
    { n: 22, code: <>{"    "}<Tk.K>try</Tk.K> container.<Tk.F>encodeIfPresent</Tk.F>(id, forKey: .id)</> },
    { n: 23, code: <>{"}"}</> },
    { n: 24, code: " " },
    { n: 25, code: <><Tk.C>{"// TODO: surface AttributedString runs once SFSafeSymbols catches up."}</Tk.C></>, ann: { kind: "todo", message: "Track on PROJ-241. Currently rendering plain string." } },
    { n: 26, code: <><Tk.K>extension</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Identifiable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 27, code: <>{"    "}<Tk.K>public var</Tk.K> resolvedKind: <Tk.T>AnnotationKind</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>, ann: { kind: "fixme", message: "Resolve recursion when content begins with 'TODO: error in …'." } },
    { n: 28, code: <>{"        "}kind <Tk.Pn>??</Tk.Pn> <Tk.T>AnnotationKind</Tk.T>.<Tk.F>infer</Tk.F>(from: content)</> },
    { n: 29, code: <>{"    "}<Tk.Pn>{"}"}</Tk.Pn></> },
    { n: 30, code: <>{"}"}</> },
    { n: 31, code: " " },
    { n: 32, code: <><Tk.K>private func</Tk.K> <Tk.F>inferKind</Tk.F>(<Tk.V>from</Tk.V> raw: <Tk.T>String</Tk.T>) <Tk.Pn>{"-> "}</Tk.Pn><Tk.T>AnnotationKind</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>, ann: { kind: "note", message: "Inference happens in AnnotationKind.infer(from:) — this wrapper is for legacy callers." } },
    { n: 33, code: <>{"    "}<Tk.T>AnnotationKind</Tk.T>.<Tk.F>infer</Tk.F>(from: raw)</> },
    { n: 34, code: <>{"}"}</> },
    { n: 35, code: " " },
    { n: 36, code: <><Tk.K>let</Tk.K> badge <Tk.Pn>=</Tk.Pn> <Tk.T>AnnotationView</Tk.T>(annotation: ann, frame: rect)</>, ann: { kind: "info", message: "AnnotationView reads theme.style.status.* — apply(theme:) is equality-gated." } },
    { n: 37, code: <>{"    "}.<Tk.F>apply</Tk.F>(theme: store.theme)</> },
  ];

  // Hover popover for the open annotation.
  function Popover({ kind, message, line }) {
    const k = KINDS[kind];
    return (
      <div style={{
        position: "absolute", top: 26, right: 22, zIndex: 5,
        width: 312,
        background: "var(--elevated)",
        borderRadius: 10,
        boxShadow: "inset 0 0 0 0.5px var(--border), 0 10px 36px rgba(0,0,0,0.45)",
        padding: 10,
        backdropFilter: "blur(10px)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{
            width: 18, height: 18, borderRadius: 4,
            background: k.color, color: "#fff",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>{k.icon}</span>
          <span style={{ font: "700 10px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase", color: k.color }}>{k.label}</span>
          <span style={{ flex: 1 }}/>
          <span style={{ font: "11px var(--font-mono)", color: "var(--text-muted)" }}>Line {line}</span>
        </div>
        <div style={{ font: "12.5px/1.45 var(--font-sans)", color: "var(--text)", marginTop: 6, marginBottom: 8 }}>{message}</div>
        <div style={{
          display: "flex", gap: 6, paddingTop: 6,
          borderTop: "0.5px solid var(--border-variant)",
        }}>
          <button style={btn}>Quick Fix</button>
          <button style={btn}>Reveal in Issues</button>
          <span style={{ flex: 1 }}/>
          <Kbd>⌥⏎</Kbd>
        </div>
      </div>
    );
  }
  const btn = {
    background: "var(--element-bg)", border: "none",
    boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
    color: "var(--text)", padding: "4px 9px", borderRadius: 5,
    font: "500 11px var(--font-sans)", cursor: "pointer",
  };

  // The gutter glyph that mirrors AnnotationView's circular badge in
  // CodeEditorAnnotations.  Background = AnnotationKind.color(in:theme),
  // icon white at 70% scale.
  function Glyph({ kind }) {
    const k = KINDS[kind];
    return (
      <div title={k.label} style={{
        width: 14, height: 14, borderRadius: "50%",
        background: k.color, color: "#fff",
        display: "flex", alignItems: "center", justifyContent: "center",
        boxShadow: `0 0 0 2px color-mix(in srgb, ${k.color} 25%, transparent)`,
      }}>{k.icon}</div>
    );
  }

  function Editor({ density, openLine, setOpen }) {
    return (
      <div style={{
        flex: 1, minHeight: 0, position: "relative",
        background: "var(--editor-bg)", overflow: "hidden",
      }}>
        <div style={{ padding: "10px 0" }}>
          {LINES.map(l => {
            const k = l.ann?.kind;
            const isOpen = l.n === openLine;
            return (
              <div key={l.n} onClick={() => k && setOpen(isOpen ? null : l.n)} style={{
                display: "grid",
                gridTemplateColumns: "44px 22px 1fr auto",
                alignItems: "center",
                minHeight: 20,
                background: isOpen ? `color-mix(in srgb, ${KINDS[k].color} 8%, transparent)` : "transparent",
                cursor: k ? "pointer" : "default",
                borderLeft: isOpen ? `2px solid ${KINDS[k].color}` : "2px solid transparent",
              }}>
                <span style={{
                  textAlign: "right", padding: "0 8px 0 0",
                  font: "12px var(--font-mono)",
                  color: k ? KINDS[k].color : "var(--line-num)",
                  fontWeight: k ? 600 : 400,
                  userSelect: "none",
                }}>{l.n}</span>
                <span style={{ display: "flex", justifyContent: "center" }}>
                  {k ? <Glyph kind={k}/> : null}
                </span>
                <code style={{
                  whiteSpace: "pre", color: "var(--editor-fg)",
                  font: "12px/1.55 var(--font-mono)", paddingRight: 8,
                }}>{l.code}</code>
                {/* Trailing bubble — visible in dense mode, or always for errors */}
                {l.ann && (density === "dense" || k === "error") ? (
                  <div style={{
                    marginRight: 10,
                    display: "inline-flex", alignItems: "center", gap: 5,
                    padding: "1px 7px", borderRadius: 9,
                    background: `color-mix(in srgb, ${KINDS[k].color} 14%, transparent)`,
                    boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${KINDS[k].color} 50%, transparent)`,
                    color: KINDS[k].color,
                    font: "500 10.5px var(--font-sans)",
                    maxWidth: 240, whiteSpace: "nowrap",
                    overflow: "hidden", textOverflow: "ellipsis",
                  }}>{KINDS[k].icon}<span style={{
                    overflow: "hidden", textOverflow: "ellipsis", maxWidth: 200,
                  }}>{l.ann.message}</span></div>
                ) : <span/>}
              </div>
            );
          })}
        </div>

        {/* Floating tally — lives on top of editor, anchored top-right */}
        <div style={{
          position: "absolute", top: 10, right: 12, zIndex: 4,
          display: "flex", alignItems: "center", gap: 8,
          padding: "5px 9px", borderRadius: 999,
          background: "var(--elevated)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
        }}>
          {Object.entries(KINDS).map(([k, v]) => {
            const count = LINES.filter(l => l.ann?.kind === k).length;
            if (!count) return null;
            return (
              <span key={k} style={{
                display: "inline-flex", alignItems: "center", gap: 4,
                font: "600 10.5px var(--font-mono)", color: v.color,
              }}>
                <span style={{
                  width: 6, height: 6, borderRadius: "50%", background: v.color,
                  boxShadow: `0 0 6px ${v.color}`,
                }}/>
                {count}
              </span>
            );
          })}
        </div>

        {openLine && (() => {
          const l = LINES.find(x => x.n === openLine);
          return l?.ann ? <Popover kind={l.ann.kind} message={l.ann.message} line={l.n}/> : null;
        })()}
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [density, setDensity] = useState("dense");
    const [openLine, setOpen] = useState(21);
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Annotation.swift" subtitle="CodeEditorAnnotations" right={
          <Segmented
            items={[
              { value: "sparse", label: "Sparse", icon: <Ic.Dot size={6}/> },
              { value: "dense",  label: "Dense",  icon: <Ic.Folded size={11}/> },
            ]}
            value={density}
            onChange={setDensity}
          />
        }/>
        {/* Breadcrumb / scope strip */}
        <div style={{
          height: 28, flexShrink: 0,
          display: "flex", alignItems: "center", gap: 8,
          padding: "0 14px",
          background: "var(--toolbar)",
          borderBottom: "0.5px solid var(--border-variant)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
        }}>
          <span>Sources</span><Ic.ChevR size={10}/>
          <span>CodeEditorAnnotations</span><Ic.ChevR size={10}/>
          <span style={{ color: "var(--text)" }}>Annotation.swift</span>
          <span style={{ flex: 1 }}/>
          <span style={{ font: "10.5px var(--font-mono)" }}>
            <span style={{ color: "var(--diag-error)" }}>● 1</span>{"  "}
            <span style={{ color: "var(--diag-warning)" }}>▲ 2</span>{"  "}
            <span style={{ color: "var(--diag-info)" }}>○ 3</span>
          </span>
          <ThemeSwitch theme={theme} setTheme={setTheme}/>
        </div>
        <Editor density={density} openLine={openLine} setOpen={setOpen}/>
        {/* Status bar */}
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12,
          padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>Ln {openLine || 21}, Col 7</span>
          <span>·</span>
          <span>Swift</span>
          <span>·</span>
          <span>Spaces: 4</span>
          <span style={{ flex: 1 }}/>
          <span style={{ color: "var(--diag-error)" }}>1 error</span>
          <span style={{ color: "var(--diag-warning)" }}>2 warnings</span>
          <span>UTF-8</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.AnnA = AnnA;
