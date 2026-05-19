// FOLDING · CONCEPT A — "GUTTER"
// The in-editor experience.  Fold chevrons live in a dedicated 14-pt
// column between the line-number gutter and the source.  Collapsed
// regions render as inline pills (kind icon + first signature line +
// `N more`).  Hovering a collapsed pill expands a preview popover that
// shows the folded body verbatim, with a thin accent rail keyed to the
// FoldStoreElement.kind colour (function / type / region / comment /
// block).  Nesting depth is communicated by the chevron's indent.

const FoldA = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Segmented } = window;
  const { useState } = React;

  // Kind palette mirrors FoldingType.  Region / Function / Type get
  // accent variants so depth + kind are both readable; Block / Comment
  // share a muted palette since they're the bulk of folds in real code.
  const KIND = {
    function: { color: "var(--syn-function)", label: "Function" },
    type:     { color: "var(--syn-type)",     label: "Type"     },
    region:   { color: "var(--accent-2)",     label: "Region"   },
    comment:  { color: "var(--syn-comment)",  label: "Comment"  },
    block:    { color: "var(--text-muted)",   label: "Block"    },
  };

  // A faux Annotation.swift snippet with multiple foldable regions.
  // Lines carry one of:
  //   { fold: { id, kind, lines, depth, collapsed, sig } }     fold header
  //   { hidden: true }                                          collapsed-out
  //   plain code
  const LINES = [
    { n:  1, c: <><Tk.K>import</Tk.K> CodeEditorCommon</> },
    { n:  2, c: <><Tk.K>import</Tk.K> Foundation</> },
    { n:  3, c: " " },
    { n:  4, c: <><Tk.C>{"/// Represents an inline annotation in the code editor."}</Tk.C></>,
      fold: { id: "f-comment", kind: "comment", lines: 6, depth: 0, collapsed: true, sig: "/// Represents an inline annotation in the code editor." } },
    { n: 11, c: <><Tk.K>public struct</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Sendable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>,
      fold: { id: "f-struct", kind: "type", lines: 32, depth: 0, collapsed: false, sig: "public struct Annotation: Sendable {" } },
    { n: 12, c: <>{"    "}<Tk.K>public let</Tk.K> id<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T></> },
    { n: 13, c: <>{"    "}<Tk.K>public let</Tk.K> range<Tk.Pn>:</Tk.Pn> <Tk.T>NSRange</Tk.T></> },
    { n: 14, c: <>{"    "}<Tk.K>public let</Tk.K> content<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T></> },
    { n: 15, c: <>{"    "}<Tk.K>public let</Tk.K> kind<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationKind</Tk.T><Tk.Pn>?</Tk.Pn></> },
    { n: 16, c: " " },
    { n: 17, c: <>{"    "}<Tk.K>public init</Tk.K>(</>,
      fold: { id: "f-init", kind: "function", lines: 9, depth: 1, collapsed: true, sig: "public init(range: NSRange, content: String, id: String = UUID().uuidString, kind: AnnotationKind? = nil) {" } },
    { n: 27, c: " " },
    { n: 28, c: <>{"    "}<Tk.K>public var</Tk.K> resolvedKind<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationKind</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>,
      fold: { id: "f-rk", kind: "function", lines: 3, depth: 1, collapsed: false, sig: "public var resolvedKind: AnnotationKind {" } },
    { n: 29, c: <>{"        "}kind <Tk.Pn>??</Tk.Pn> <Tk.T>AnnotationKind</Tk.T>.<Tk.F>infer</Tk.F>(from: content)</> },
    { n: 30, c: <>{"    "}<Tk.Pn>{"}"}</Tk.Pn></> },
    { n: 31, c: <Tk.Pn>{"}"}</Tk.Pn> },
    { n: 32, c: " " },
    { n: 33, c: <><Tk.K>extension</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Identifiable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>,
      fold: { id: "f-ext", kind: "region", lines: 8, depth: 0, collapsed: true, sig: "extension Annotation: Identifiable {" } },
    { n: 42, c: <><Tk.C>{"// MARK: – AnnotationView wiring"}</Tk.C></> },
    { n: 43, c: <><Tk.K>private func</Tk.K> <Tk.F>installBadge</Tk.F>(on view<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationView</Tk.T>) <Tk.Pn>{"{"}</Tk.Pn></>,
      fold: { id: "f-install", kind: "function", lines: 5, depth: 0, collapsed: false, sig: "private func installBadge(on view: AnnotationView) {" } },
    { n: 44, c: <>{"    "}view.<Tk.F>apply</Tk.F>(theme: store.theme)</> },
    { n: 45, c: <>{"    "}view.<Tk.F>setNeedsLayout</Tk.F>()</> },
    { n: 46, c: <>{"    "}view.<Tk.F>setNeedsDisplay</Tk.F>()</> },
    { n: 47, c: <Tk.Pn>{"}"}</Tk.Pn> },
  ];

  // Walk LINES, honoring collapsed folds: collapsed range hides lines
  // between fold.n+1 .. fold.n+fold.lines.  Header rows always render.
  function visibleLines(folds) {
    const out = [];
    let skipUntil = -1;
    for (let i = 0; i < LINES.length; i++) {
      const l = LINES[i];
      if (l.n <= skipUntil) continue;
      out.push(l);
      const f = l.fold && folds[l.fold.id];
      if (f === true || (f === undefined && l.fold?.collapsed)) {
        skipUntil = l.n + l.fold.lines - 1;
      }
    }
    return out;
  }

  // Hover preview for a collapsed pill.
  function FoldPreview({ fold, line }) {
    const k = KIND[fold.kind];
    return (
      <div style={{
        position: "absolute", top: 22, left: 0, right: 0, zIndex: 4,
        marginLeft: 80, marginRight: 24,
        background: "var(--elevated)",
        boxShadow: "inset 0 0 0 0.5px var(--border), 0 12px 36px rgba(0,0,0,0.45)",
        borderRadius: 8,
        overflow: "hidden",
      }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 8,
          padding: "5px 12px",
          background: "color-mix(in srgb, var(--editor-bg) 60%, transparent)",
          borderBottom: "0.5px solid var(--border-variant)",
          font: "11px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span style={{ width: 4, height: 12, borderRadius: 1, background: k.color }}/>
          <span style={{ color: "var(--text)" }}>{k.label}</span>
          <span>·</span>
          <span>L{line}–L{line + fold.lines - 1}</span>
          <span>·</span>
          <span>{fold.lines} lines folded</span>
        </div>
        <div style={{
          background: "var(--editor-bg)", padding: "8px 14px",
          font: "12px/1.6 var(--font-mono)", color: "var(--editor-fg)",
          maxHeight: 120, overflow: "hidden",
        }}>
          {/* render the would-be expansion as a faded sample */}
          {Array.from({ length: Math.min(fold.lines, 5) }).map((_, i) => (
            <div key={i} style={{ opacity: 0.7 - i * 0.08 }}>
              {i === 0 ? fold.sig : `    /* line ${line + i + 1} */`}
            </div>
          ))}
          {fold.lines > 5 && <div style={{ color: "var(--text-disabled)" }}>… {fold.lines - 5} more lines</div>}
        </div>
      </div>
    );
  }

  function FoldPill({ fold, onClick }) {
    const k = KIND[fold.kind];
    return (
      <span onClick={onClick} style={{
        display: "inline-flex", alignItems: "center", gap: 5,
        marginLeft: 4,
        padding: "1px 8px", borderRadius: 999,
        background: `color-mix(in srgb, ${k.color} 20%, transparent)`,
        boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${k.color} 55%, transparent)`,
        color: k.color,
        font: "500 11px var(--font-mono)",
        cursor: "pointer", whiteSpace: "nowrap",
      }}>
        <Ic.Ellipsis size={11}/>
        <span style={{ font: "500 10.5px var(--font-sans)", letterSpacing: 0.4, textTransform: "uppercase" }}>{k.label}</span>
        <span style={{ font: "10.5px var(--font-mono)", opacity: 0.7 }}>· {fold.lines}</span>
      </span>
    );
  }

  function Editor({ folds, toggle, hoverPill, setHoverPill }) {
    const vis = visibleLines(folds);
    return (
      <div style={{ flex: 1, minHeight: 0, position: "relative",
        background: "var(--editor-bg)", overflow: "hidden" }}>
        <div style={{ padding: "10px 0" }}>
          {vis.map((l) => {
            const isFold = !!l.fold;
            const collapsed = isFold && (folds[l.fold.id] === true || (folds[l.fold.id] === undefined && l.fold.collapsed));
            const k = isFold ? KIND[l.fold.kind] : null;
            return (
              <div key={l.n} style={{
                display: "grid",
                gridTemplateColumns: "44px 14px 14px 1fr",
                alignItems: "center", minHeight: 22,
                background: collapsed ? `color-mix(in srgb, ${k.color} 8%, transparent)` : "transparent",
              }}>
                <span style={{
                  textAlign: "right", paddingRight: 8,
                  font: "12px var(--font-mono)",
                  color: collapsed ? k.color : "var(--line-num)",
                  fontWeight: collapsed ? 600 : 400,
                  userSelect: "none",
                }}>{l.n}</span>
                {/* nesting indent */}
                <span style={{
                  height: 16, borderLeft: l.fold && l.fold.depth > 0
                    ? `1px solid color-mix(in srgb, ${k.color} 40%, transparent)`
                    : "1px solid transparent",
                  marginLeft: 6,
                }}/>
                {/* fold chevron */}
                <span style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
                  {isFold ? (
                    <button onClick={() => toggle(l.fold.id, !collapsed)} style={{
                      border: "none", background: "transparent", cursor: "pointer", padding: 0,
                      color: k.color, display: "flex", alignItems: "center", justifyContent: "center",
                      borderRadius: 3, width: 12, height: 12,
                      transition: "transform 150ms var(--ease-spring-snappy)",
                      transform: collapsed ? "rotate(-90deg)" : "rotate(0deg)",
                    }}><Ic.ChevD size={10}/></button>
                  ) : null}
                </span>
                <code style={{
                  whiteSpace: "pre", color: "var(--editor-fg)",
                  font: "12px/1.55 var(--font-mono)",
                  paddingRight: 8,
                  position: "relative",
                }}>
                  {l.c}
                  {collapsed && (
                    <FoldPill fold={l.fold}
                      onClick={() => setHoverPill(hoverPill === l.fold.id ? null : l.fold.id)} />
                  )}
                  {hoverPill === l.fold?.id && collapsed && (
                    <FoldPreview fold={l.fold} line={l.n}/>
                  )}
                </code>
              </div>
            );
          })}
        </div>

        {/* Top-right summary chip */}
        <div style={{
          position: "absolute", top: 10, right: 12, display: "flex", gap: 6,
        }}>
          <div style={{
            display: "flex", alignItems: "center", gap: 6,
            padding: "4px 9px", borderRadius: 999,
            background: "var(--elevated)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
            font: "11px var(--font-mono)", color: "var(--text-muted)",
          }}>
            <Ic.Folded size={12}/>
            <span style={{ color: "var(--text)" }}>{Object.values(folds).filter(v => v).length}</span>
            / 5 folded
          </div>
        </div>
      </div>
    );
  }

  function Toolbar({ folds, setFolds }) {
    return (
      <div style={{
        height: 30, flexShrink: 0,
        display: "flex", alignItems: "center", gap: 8, padding: "0 12px",
        borderBottom: "0.5px solid var(--border-variant)",
        background: "var(--toolbar)",
        font: "11px var(--font-sans)", color: "var(--text-muted)",
      }}>
        <span>Sources</span><Ic.ChevR size={10}/>
        <span>CodeEditorAnnotations</span><Ic.ChevR size={10}/>
        <span style={{ color: "var(--text)" }}>Annotation.swift</span>
        <span style={{ flex: 1 }}/>
        <button onClick={() => setFolds(Object.fromEntries(LINES.filter(l => l.fold).map(l => [l.fold.id, true])))} style={btn}>
          Fold All
        </button>
        <button onClick={() => setFolds({})} style={btn}>
          Unfold All
        </button>
        <span style={{ width: 1, height: 14, background: "var(--border-variant)", margin: "0 4px" }}/>
        <button style={btn}>Fold to Level <span style={{ color: "var(--text)", marginLeft: 4 }}>2</span></button>
      </div>
    );
  }
  const btn = {
    background: "transparent",
    boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
    color: "var(--text)",
    border: "none", height: 22, padding: "0 9px", borderRadius: 5,
    font: "500 11px var(--font-sans)", cursor: "pointer",
    display: "inline-flex", alignItems: "center", gap: 5,
  };

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [folds, setFolds] = useState({ "f-comment": true, "f-init": true, "f-ext": true });
    const [hoverPill, setHoverPill] = useState("f-comment");
    const toggle = (id, v) => setFolds(s => ({ ...s, [id]: v }));
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Annotation.swift" subtitle="CodeEditorFolding"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <Toolbar folds={folds} setFolds={setFolds}/>
        <Editor folds={folds} toggle={toggle} hoverPill={hoverPill} setHoverPill={setHoverPill}/>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>Ln 28, Col 24</span>
          <span>·</span>
          <span>Swift</span>
          <span>·</span>
          <span>folds: <span style={{ color: "var(--text)" }}>5 regions · 2 nested</span></span>
          <span style={{ flex: 1 }}/>
          <span>provider: BraceFoldingProvider</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.FoldA = FoldA;
