// ANNOTATIONS · CONCEPT C — "STREAM"
// One scrolling page, command-bar driven.  No editor in view; this is the
// project-wide annotation feed.
//   • Top:  command bar that drives filter, kind-scope, file-scope, sort.
//   • Slabs by severity in descending order (errors first), each one a
//     full-width accent-coded card with its row count printed huge.
//   • Each row is a MessageLineAnnotation — file:line:col on the right.
//   • Inline preview: clicking a row expands its source context.

const AnnC = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, SevDot, Kbd } = window;
  const { useState } = React;

  const KINDS = [
    { id: "error",   label: "Errors",   color: "var(--diag-error)",   icon: <Ic.Error size={14}/>,   blurb: "Compilation fails — the document is unbuildable until these clear." },
    { id: "warning", label: "Warnings", color: "var(--diag-warning)", icon: <Ic.Warning size={14}/>, blurb: "Semantic concerns the host wants you to address before merging." },
    { id: "fixme",   label: "Fixme",    color: "var(--diag-warning)", icon: <Ic.Wrench size={14}/>,  blurb: "Author-flagged repairs. Mapped to status.warning — no dedicated FIXME entry." },
    { id: "todo",    label: "Todo",     color: "var(--diag-info)",    icon: <Ic.Todo size={14}/>,    blurb: "Future work. Inferred from content prefix when no kind is supplied." },
    { id: "note",    label: "Notes",    color: "var(--text-muted)",   icon: <Ic.Note size={14}/>,    blurb: "Free-form annotations from the host. Same surface as the others." },
    { id: "info",    label: "Info",     color: "var(--diag-info)",    icon: <Ic.Info size={14}/>,    blurb: "Informational. Often emitted by sourcekit-lsp via publishDiagnostics." },
  ];

  const ANN = [
    { id: "ANN-001", kind: "error",   file: "Annotation.swift",      ln: 21, col: 38, msg: "Value of optional type 'AnnotationKind?' must be unwrapped to a value of type 'AnnotationKind'.", code: <><Tk.K>try</Tk.K> container.<Tk.F>encode</Tk.F>(kind.rawValue, forKey: .kind)</> },
    { id: "ANN-007", kind: "warning", file: "AnnotationView.swift",  ln: 78, col: 11, msg: "Force-unwrap of NSImage. Substitute a UnicodeScalar fallback for missing symbol names." },
    { id: "ANN-002", kind: "warning", file: "Annotation.swift",      ln: 19, col: 17, msg: "Initialization can be replaced by 'let' to enforce immutability." },
    { id: "ANN-008", kind: "warning", file: "AnnotationView.swift",  ln: 412, col: 9, msg: "Capture list missing [weak self]. Closure outlives the view's lifecycle." },
    { id: "ANN-003", kind: "fixme",   file: "Annotation.swift",      ln: 27, col: 12, msg: "Resolve recursion when content begins with 'TODO: error in …'." },
    { id: "ANN-004", kind: "todo",    file: "Annotation.swift",      ln: 25, col:  4, msg: "Track on PROJ-241. Currently rendering plain string." },
    { id: "ANN-010", kind: "todo",    file: "MessageLineAnnotation.swift", ln: 6, col: 1, msg: "Migrate to NSTextLocation-only location once iOS minimum reaches 17." },
    { id: "ANN-005", kind: "note",    file: "Annotation.swift",      ln: 32, col: 14, msg: "Inference happens in AnnotationKind.infer(from:) — this wrapper is for legacy callers." },
    { id: "ANN-006", kind: "info",    file: "Annotation.swift",      ln: 36, col:  9, msg: "AnnotationView reads theme.style.status.* — apply(theme:) is equality-gated." },
    { id: "ANN-009", kind: "info",    file: "AnnotationKind.swift",  ln: 47, col:  9, msg: "FIXME kind reads status.warning — schema has no dedicated FIXME entry." },
  ];

  // --- Command bar -----------------------------------------------------------
  function CommandBar({ scope, setScope, query }) {
    return (
      <div style={{
        padding: "10px 14px",
        background: "var(--title-bar)",
        borderBottom: "0.5px solid var(--border-variant)",
        display: "flex", alignItems: "center", gap: 8,
      }}>
        <div style={{
          flex: 1, display: "flex", alignItems: "center", gap: 8,
          height: 30, padding: "0 12px", borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-focused), 0 0 0 3px color-mix(in srgb, var(--border-focused) 16%, transparent)",
        }}>
          <span style={{ color: "var(--accent-1)" }}><Ic.Cmd size={13}/></span>
          <input placeholder="Filter annotations — message, file, kind, or jump to ANN-…" readOnly
            value={query} style={{
              flex: 1, background: "transparent", border: "none", outline: "none",
              color: "var(--text)", font: "12.5px var(--font-sans)",
            }}/>
          <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>{ANN.length} results</span>
          <Kbd>⌘K</Kbd>
        </div>
      </div>
    );
  }

  // --- Scope strip -----------------------------------------------------------
  function ScopeStrip({ scope, setScope }) {
    return (
      <div style={{
        display: "flex", alignItems: "center", gap: 8,
        padding: "8px 14px 10px",
        borderBottom: "0.5px solid var(--border-variant)",
        background: "var(--toolbar)",
        overflowX: "auto",
      }}>
        <span style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
          color: "var(--text-muted)" }}>SCOPE</span>
        <Pill size="sm" active={scope === "all"} onClick={() => setScope("all")}>Workspace</Pill>
        <Pill size="sm" active={scope === "open"} onClick={() => setScope("open")}>Open buffers · 3</Pill>
        <Pill size="sm" active={scope === "modified"} onClick={() => setScope("modified")}>Modified · 1</Pill>
        <span style={{ width: 1, height: 16, background: "var(--border-variant)", margin: "0 4px" }}/>
        {KINDS.map(k => {
          const n = ANN.filter(a => a.kind === k.id).length;
          if (!n) return null;
          return (
            <Pill key={k.id} size="sm" accent={k.color}
              icon={<SevDot kind={k.id} size={5}/>}>{k.label} {n}</Pill>
          );
        })}
        <span style={{ flex: 1 }}/>
        <span style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)" }}>Sort:</span>
        <Pill size="sm" active>Severity</Pill>
      </div>
    );
  }

  // --- Severity slab ---------------------------------------------------------
  function Slab({ kind, openId, setOpen }) {
    const rows = ANN.filter(a => a.kind === kind.id);
    if (!rows.length) return null;
    return (
      <div style={{
        margin: "14px 16px 0",
        borderRadius: 12,
        background: `color-mix(in srgb, ${kind.color} 6%, var(--surface))`,
        boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${kind.color} 35%, transparent)`,
        overflow: "hidden",
      }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 14,
          padding: "12px 16px",
          background: `linear-gradient(180deg, color-mix(in srgb, ${kind.color} 10%, transparent), transparent)`,
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 9,
            display: "flex", alignItems: "center", justifyContent: "center",
            background: kind.color, color: "#fff",
          }}>{kind.icon}</div>
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
              <span style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>
                {kind.label}
              </span>
              <span style={{ font: "700 13px var(--font-mono)", color: kind.color }}>{rows.length}</span>
            </div>
            <div style={{ font: "11.5px var(--font-sans)", color: "var(--text-muted)", marginTop: 2 }}>{kind.blurb}</div>
          </div>
          <button style={{
            border: "none", cursor: "pointer", background: "transparent",
            color: kind.color, font: "500 11px var(--font-sans)",
            padding: "4px 8px", borderRadius: 5,
          }}>Mute all <Ic.ChevR size={11}/></button>
        </div>
        <div>
          {rows.map(a => (
            <div key={a.id} onClick={() => setOpen(openId === a.id ? null : a.id)} style={{
              padding: "9px 16px 9px 60px",
              cursor: "pointer",
              borderTop: "0.5px solid var(--border-variant)",
              background: openId === a.id ? "color-mix(in srgb, var(--bg) 50%, transparent)" : "transparent",
            }}>
              <div style={{ display: "flex", gap: 12, alignItems: "baseline" }}>
                <span style={{
                  font: "500 12.5px/1.4 var(--font-sans)", color: "var(--text)",
                  flex: 1, minWidth: 0,
                }}>{a.msg}</span>
                <span style={{
                  font: "11px var(--font-mono)", color: "var(--text-muted)", whiteSpace: "nowrap",
                }}>
                  {a.file}<span style={{ color: "var(--text-disabled)" }}>:</span>
                  <span style={{ color: kind.color, fontWeight: 600 }}>{a.ln}</span>
                  <span style={{ color: "var(--text-disabled)" }}>:</span>{a.col}
                </span>
                <span style={{
                  font: "10.5px var(--font-mono)", color: "var(--text-disabled)",
                  minWidth: 64, textAlign: "right",
                }}>{a.id}</span>
              </div>
              {openId === a.id && (
                <div style={{
                  marginTop: 9, marginLeft: -2,
                  background: "var(--editor-bg)",
                  borderRadius: 7,
                  boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
                  padding: "8px 10px 8px 0",
                }}>
                  <div style={{
                    display: "grid", gridTemplateColumns: "44px 1fr",
                    alignItems: "center",
                  }}>
                    <span style={{
                      textAlign: "right", paddingRight: 8,
                      font: "11px var(--font-mono)", color: kind.color, fontWeight: 600,
                    }}>{a.ln}</span>
                    <code style={{
                      whiteSpace: "pre", color: "var(--editor-fg)",
                      font: "12px/1.5 var(--font-mono)",
                    }}>{a.code || <Tk.C>// preview unavailable — open file to inspect</Tk.C>}</code>
                  </div>
                  <div style={{
                    display: "flex", gap: 6, marginTop: 8, paddingLeft: 44,
                  }}>
                    <button style={cBtn(kind.color, true)}>Reveal in Editor</button>
                    <button style={cBtn(kind.color, false)}>Quick Fix</button>
                    <button style={cBtn(kind.color, false)}>Mute kind in this file</button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    );
  }
  const cBtn = (c, primary) => ({
    border: "none", cursor: "pointer",
    padding: "4px 9px", borderRadius: 5,
    background: primary ? c : "transparent",
    boxShadow: primary ? "none" : `inset 0 0 0 0.5px ${c}`,
    color: primary ? "#fff" : c,
    font: `${primary ? 600 : 500} 11px var(--font-sans)`,
  });

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [scope, setScope] = useState("all");
    const [openId, setOpen] = useState("ANN-001");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Diagnostics" subtitle="CodeEditorAnnotations · 10 issues across 5 files"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <CommandBar scope={scope} setScope={setScope} query="kind:error,warning"/>
        <ScopeStrip scope={scope} setScope={setScope}/>
        <div style={{ flex: 1, minHeight: 0, overflowY: "auto", background: "var(--bg)",
          paddingBottom: 20 }}>
          {KINDS.map(k => <Slab key={k.id} kind={k} openId={openId} setOpen={setOpen}/>)}
          <div style={{
            margin: "18px 16px 8px", padding: "12px 16px",
            borderRadius: 10, border: "0.5px dashed var(--border-variant)",
            display: "flex", alignItems: "center", gap: 10,
            font: "11px var(--font-sans)", color: "var(--text-muted)",
          }}>
            <Ic.Info size={13}/>
            Annotations source: <span style={{ color: "var(--text)" }}>local LSP (sourcekit-lsp)</span>{" · "}
            host: <span style={{ color: "var(--text)" }}>CodeEditorSample</span>
            <span style={{ flex: 1 }}/>
            <Kbd>R</Kbd> refresh
            <Kbd>⌘⇧M</Kbd> open
          </div>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.AnnC = AnnC;
