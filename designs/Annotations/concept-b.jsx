// ANNOTATIONS · CONCEPT B — "WORKBENCH"
// Triptych for code-review / annotation triage.
//   Left  · file rail — annotation counts per file, scoped to project
//   Center · the editor (same source as concept A) with focused annotation
//   Right · grouped Problems list — filter by kind, sort by severity, jump
// Power-user posture: every annotation in the workspace is in reach without
// leaving the editor.  Mirrors Xcode's Issue Navigator but Inline-aware.

const AnnB = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, SevDot, Kbd } = window;
  const { useState } = React;

  const KINDS = {
    info:    { color: "var(--diag-info)",    icon: <Ic.Info size={10}/>,    label: "Info" },
    note:    { color: "var(--text-muted)",   icon: <Ic.Note size={10}/>,    label: "Note" },
    todo:    { color: "var(--diag-info)",    icon: <Ic.Todo size={10}/>,    label: "Todo" },
    fixme:   { color: "var(--diag-warning)", icon: <Ic.Wrench size={10}/>,  label: "Fixme" },
    warning: { color: "var(--diag-warning)", icon: <Ic.Warning size={10}/>, label: "Warning" },
    error:   { color: "var(--diag-error)",   icon: <Ic.Error size={10}/>,   label: "Error" },
  };

  // The full project's annotations.  Each row is a MessageLineAnnotation.
  const ANNOTATIONS = [
    { file: "Annotation.swift",            line: 21, col: 38, kind: "error",   id: "ANN-001", msg: "Value of optional type 'AnnotationKind?' must be unwrapped to a value of type 'AnnotationKind'.", focus: true },
    { file: "Annotation.swift",            line: 19, col: 17, kind: "warning", id: "ANN-002", msg: "Initialization can be replaced by 'let' to enforce immutability." },
    { file: "Annotation.swift",            line: 27, col: 12, kind: "fixme",   id: "ANN-003", msg: "Resolve recursion when content begins with 'TODO: error in …'." },
    { file: "Annotation.swift",            line: 25, col:  4, kind: "todo",    id: "ANN-004", msg: "Track on PROJ-241. Currently rendering plain string." },
    { file: "Annotation.swift",            line: 32, col: 14, kind: "note",    id: "ANN-005", msg: "Inference happens in AnnotationKind.infer(from:) — this wrapper is for legacy callers." },
    { file: "Annotation.swift",            line: 36, col:  9, kind: "info",    id: "ANN-006", msg: "AnnotationView reads theme.style.status.* — apply(theme:) is equality-gated." },
    { file: "AnnotationView.swift",        line: 78, col: 11, kind: "warning", id: "ANN-007", msg: "Force-unwrap of NSImage. Substitute a UnicodeScalar fallback for missing symbol names." },
    { file: "AnnotationView.swift",        line: 412, col: 9, kind: "warning", id: "ANN-008", msg: "Capture list missing [weak self]. Closure outlives the view's lifecycle." },
    { file: "AnnotationKind.swift",        line: 47, col:  9, kind: "info",    id: "ANN-009", msg: "FIXME kind reads status.warning — schema has no dedicated FIXME entry." },
    { file: "MessageLineAnnotation.swift", line:  6, col:  1, kind: "todo",    id: "ANN-010", msg: "Migrate to NSTextLocation-only location once iOS minimum reaches 17." },
  ];

  // File-tree rollup with counts per kind.  Aggregates from ANNOTATIONS.
  const FILES = (() => {
    const map = new Map();
    for (const a of ANNOTATIONS) {
      if (!map.has(a.file)) map.set(a.file, { name: a.file, by: {}, total: 0 });
      const f = map.get(a.file);
      f.by[a.kind] = (f.by[a.kind] || 0) + 1;
      f.total += 1;
    }
    return Array.from(map.values());
  })();

  function FileRail({ activeFile, setActiveFile }) {
    return (
      <div style={{
        width: 220, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px 8px",
          font: "700 10px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
          color: "var(--text-muted)" }}>
          ANNOTATIONS · 5 FILES
        </div>
        <div style={{ display: "flex", flexDirection: "column", padding: "0 6px" }}>
          {FILES.map(f => {
            const active = f.name === activeFile;
            const worst = f.by.error ? "error" : f.by.warning ? "warning" : f.by.fixme ? "fixme" : "info";
            return (
              <div key={f.name} onClick={() => setActiveFile(f.name)} style={{
                display: "flex", alignItems: "center", gap: 8,
                padding: "7px 8px", borderRadius: 6, cursor: "pointer",
                background: active ? "var(--element-selected)" : "transparent",
              }}>
                <SevDot kind={worst} size={6}/>
                <span style={{
                  flex: 1, minWidth: 0,
                  font: `${active ? 600 : 500} 12px var(--font-sans)`,
                  color: active ? "var(--text)" : "var(--text)",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                }}>{f.name}</span>
                <span style={{
                  font: "500 10px var(--font-mono)",
                  color: "var(--text-disabled)",
                }}>{f.total}</span>
              </div>
            );
          })}
        </div>

        {/* Severity legend pinned at bottom */}
        <div style={{ flex: 1 }}/>
        <div style={{
          padding: 10, margin: 8, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        }}>
          <div style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
            color: "var(--text-muted)", marginBottom: 6 }}>BY KIND</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", rowGap: 4 }}>
            {Object.entries(KINDS).map(([k, v]) => {
              const n = ANNOTATIONS.filter(a => a.kind === k).length;
              return (
                <div key={k} style={{ display: "flex", alignItems: "center", gap: 5,
                  font: "11px var(--font-sans)", color: "var(--text-muted)" }}>
                  <SevDot kind={k} size={6}/>
                  {v.label}
                  <span style={{ marginLeft: "auto", color: "var(--text)", font: "600 11px var(--font-mono)" }}>{n}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // Compact center editor — focused on the active annotation.
  const SRC = [
    { n: 19, code: <>{"  "}<Tk.K>var</Tk.K> container = encoder.<Tk.F>container</Tk.F>(...)</>, kind: "warning" },
    { n: 20, code: <>{"  "}<Tk.K>try</Tk.K> container.<Tk.F>encode</Tk.F>(text, forKey: .text)</> },
    { n: 21, code: <>{"  "}<Tk.K>try</Tk.K> container.<Tk.F>encode</Tk.F>(kind.rawValue, forKey: .kind)</>, kind: "error", active: true },
    { n: 22, code: <>{"  "}<Tk.K>try</Tk.K> container.<Tk.F>encodeIfPresent</Tk.F>(id, forKey: .id)</> },
    { n: 23, code: <Tk.Pn>{"}"}</Tk.Pn> },
    { n: 24, code: " " },
    { n: 25, code: <><Tk.C>{"// TODO: surface AttributedString runs once …"}</Tk.C></>, kind: "todo" },
    { n: 26, code: <><Tk.K>extension</Tk.K> <Tk.T>Annotation</Tk.T>: <Tk.T>Identifiable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 27, code: <>{"  "}<Tk.K>public var</Tk.K> resolvedKind: <Tk.T>AnnotationKind</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>, kind: "fixme" },
    { n: 28, code: <>{"    "}kind ?? <Tk.T>AnnotationKind</Tk.T>.<Tk.F>infer</Tk.F>(from: content)</> },
    { n: 29, code: <>{"  "}<Tk.Pn>{"}"}</Tk.Pn></> },
    { n: 30, code: <Tk.Pn>{"}"}</Tk.Pn> },
  ];

  function Editor() {
    return (
      <div style={{
        flex: 1, minWidth: 0, minHeight: 0,
        background: "var(--editor-bg)", display: "flex", flexDirection: "column",
      }}>
        <div style={{
          height: 30, flexShrink: 0,
          display: "flex", alignItems: "center", gap: 10, padding: "0 12px",
          borderBottom: "0.5px solid var(--border-variant)",
          background: "var(--toolbar)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
        }}>
          <span>Annotation.swift</span>
          <span>·</span><span>encode(to:)</span>
          <span style={{ flex: 1 }}/>
          <Kbd>⌥⏎</Kbd><span>quick fix</span>
        </div>
        <div style={{ flex: 1, overflow: "hidden", padding: "8px 0" }}>
          {SRC.map(l => (
            <div key={l.n} style={{
              display: "grid",
              gridTemplateColumns: "36px 18px 1fr",
              alignItems: "center", minHeight: 19,
              background: l.active ? "color-mix(in srgb, var(--diag-error) 12%, transparent)" : "transparent",
              borderLeft: l.active ? "2px solid var(--diag-error)" : "2px solid transparent",
            }}>
              <span style={{ textAlign: "right", paddingRight: 8,
                font: `${l.active ? 600 : 400} 11px var(--font-mono)`,
                color: l.kind ? KINDS[l.kind].color : "var(--line-num)" }}>{l.n}</span>
              <span style={{ display: "flex", justifyContent: "center" }}>
                {l.kind ? (
                  <span style={{
                    width: 12, height: 12, borderRadius: 3,
                    background: KINDS[l.kind].color, color: "#fff",
                    display: "flex", alignItems: "center", justifyContent: "center",
                  }}>{KINDS[l.kind].icon}</span>
                ) : null}
              </span>
              <code style={{
                whiteSpace: "pre", color: "var(--editor-fg)",
                font: "12px/1.55 var(--font-mono)",
              }}>{l.code}</code>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // Right pane — grouped Problems list.
  function Problems({ filter, setFilter, openId, setOpen }) {
    const filtered = filter === "all" ? ANNOTATIONS : ANNOTATIONS.filter(a => a.kind === filter);
    const groups = ["error", "warning", "fixme", "todo", "note", "info"]
      .map(k => ({ k, rows: filtered.filter(a => a.kind === k) }))
      .filter(g => g.rows.length);

    return (
      <div style={{
        width: 280, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "10px 12px 8px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <span style={{ font: "700 22px/1 var(--font-display)", letterSpacing: -0.2, color: "var(--text)" }}>Issues</span>
            <span style={{ font: "500 11px var(--font-mono)", color: "var(--text-muted)", marginLeft: 4 }}>{ANNOTATIONS.length}</span>
            <span style={{ flex: 1 }}/>
            <button style={iconBtn}><Ic.Filter size={12}/></button>
            <button style={iconBtn}><Ic.Pin size={12}/></button>
          </div>
          {/* Severity filter pills */}
          <div style={{ display: "flex", gap: 4, flexWrap: "wrap", marginTop: 8 }}>
            <Pill size="sm" active={filter === "all"} onClick={() => setFilter("all")}>All</Pill>
            {Object.entries(KINDS).map(([k, v]) => {
              const n = ANNOTATIONS.filter(a => a.kind === k).length;
              if (!n) return null;
              return (
                <Pill key={k} size="sm" active={filter === k} accent={v.color} onClick={() => setFilter(k)}
                  icon={<SevDot kind={k} size={5}/>}>
                  {v.label} {n}
                </Pill>
              );
            })}
          </div>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "0 4px 8px" }}>
          {groups.map(g => (
            <div key={g.k} style={{ marginTop: 4 }}>
              <div style={{
                padding: "4px 10px",
                font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
                color: KINDS[g.k].color,
              }}>{KINDS[g.k].label} · {g.rows.length}</div>
              {g.rows.map(a => (
                <div key={a.id} onClick={() => setOpen(a.id)} style={{
                  margin: "0 4px", padding: "6px 8px", borderRadius: 6,
                  background: openId === a.id ? "var(--element-selected)" : "transparent",
                  cursor: "pointer",
                  display: "flex", gap: 6,
                  borderLeft: openId === a.id ? `2px solid ${KINDS[a.kind].color}` : "2px solid transparent",
                  marginBottom: 1,
                }}>
                  <SevDot kind={a.kind} size={7}/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      font: "500 11.5px var(--font-sans)", color: "var(--text)",
                      lineHeight: 1.35,
                    }}>{a.msg}</div>
                    <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 3 }}>
                      <span style={{
                        font: "10.5px var(--font-mono)", color: "var(--text-muted)",
                      }}>{a.file}:{a.line}:{a.col}</span>
                      <span style={{
                        marginLeft: "auto",
                        font: "10px var(--font-mono)", color: "var(--text-disabled)",
                      }}>{a.id}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
    );
  }
  const iconBtn = {
    width: 22, height: 22, border: "none", borderRadius: 5, cursor: "pointer",
    background: "transparent", color: "var(--text-muted)",
    display: "flex", alignItems: "center", justifyContent: "center",
  };

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [filter, setFilter] = useState("all");
    const [activeFile, setActiveFile] = useState("Annotation.swift");
    const [openId, setOpen] = useState("ANN-001");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Annotations · Workbench" subtitle="CodeEditorAnnotations" right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <FileRail activeFile={activeFile} setActiveFile={setActiveFile}/>
          <Editor/>
          <Problems filter={filter} setFilter={setFilter} openId={openId} setOpen={setOpen}/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12,
          padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span style={{ color: "var(--diag-error)" }}>1 error</span>
          <span style={{ color: "var(--diag-warning)" }}>3 warnings</span>
          <span style={{ color: "var(--diag-info)" }}>6 info / todo / note</span>
          <span style={{ flex: 1 }}/>
          <span>5 files · 10 annotations</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.AnnB = AnnB;
