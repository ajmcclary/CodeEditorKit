// FOLDING · CONCEPT B — "OUTLINE"
// Triptych.  Editor on the left, a structural Outline tree on the right
// that mirrors the FoldStoreElement registry verbatim: id, depth, kind,
// isCollapsed.  Selecting a row in the outline scrolls and highlights
// the editor.  Bulk actions live above the outline:
//   Fold All · Unfold All · Fold to Level 1/2/3 · Toggle Comments
// The outline doubles as a navigation tree — folded regions still show
// their headers so jumping between code areas works whether or not
// they're collapsed.

const FoldB = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Overline, Kbd } = window;
  const { useState } = React;

  const KIND = {
    function: { color: "var(--syn-function)", label: "func"   },
    type:     { color: "var(--syn-type)",     label: "type"   },
    region:   { color: "var(--accent-2)",     label: "region" },
    comment:  { color: "var(--syn-comment)",  label: "doc"    },
    block:    { color: "var(--text-muted)",   label: "block"  },
  };

  // Flat tree of FoldStoreElements.  Parents come before children;
  // depth = nesting level.  isCollapsed initial state lives here.
  const TREE = [
    { id: "f-imports",  kind: "region",   depth: 0, lines: 3,  l1:  1, l2:  3,  name: "Imports",                       collapsed: false },
    { id: "f-comment",  kind: "comment",  depth: 0, lines: 6,  l1:  4, l2:  9,  name: "Documentation block",           collapsed: true },
    { id: "f-struct",   kind: "type",     depth: 0, lines: 32, l1: 11, l2: 42,  name: "struct Annotation",             collapsed: false },
    { id: "f-init",     kind: "function", depth: 1, lines: 9,  l1: 17, l2: 25,  name: "init(range:content:id:kind:)",  collapsed: true },
    { id: "f-rk",       kind: "function", depth: 1, lines: 3,  l1: 28, l2: 30,  name: "var resolvedKind",              collapsed: false },
    { id: "f-ext",      kind: "region",   depth: 0, lines: 8,  l1: 44, l2: 51,  name: "extension Annotation",          collapsed: true },
    { id: "f-codable",  kind: "function", depth: 1, lines: 5,  l1: 46, l2: 50,  name: "func encode(to:)",              collapsed: false },
    { id: "f-mark",     kind: "block",    depth: 0, lines: 1,  l1: 52, l2: 52,  name: "// MARK: – AnnotationView wiring", collapsed: false },
    { id: "f-install",  kind: "function", depth: 0, lines: 5,  l1: 53, l2: 57,  name: "func installBadge(on:)",        collapsed: false },
  ];

  // Editor: compact, just enough to communicate the fold state coming
  // out of the right-pane outline.
  const SRC = [
    { n:  1, c: <><Tk.K>import</Tk.K> CodeEditorCommon</> },
    { n:  4, fold: "f-comment", c: <><Tk.C>/// Represents an inline annotation in the editor.</Tk.C></> },
    { n: 11, fold: "f-struct",  c: <><Tk.K>public struct</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Sendable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 12, c: <>{"    "}<Tk.K>public let</Tk.K> id<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T></> },
    { n: 13, c: <>{"    "}<Tk.K>public let</Tk.K> range<Tk.Pn>:</Tk.Pn> <Tk.T>NSRange</Tk.T></> },
    { n: 14, c: <>{"    "}<Tk.K>public let</Tk.K> content<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T></> },
    { n: 17, fold: "f-init",    c: <>{"    "}<Tk.K>public init</Tk.K>(range<Tk.Pn>:</Tk.Pn> <Tk.T>NSRange</Tk.T><Tk.Pn>,</Tk.Pn> …) <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 28, fold: "f-rk",      c: <>{"    "}<Tk.K>public var</Tk.K> resolvedKind<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationKind</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 29, c: <>{"        "}kind <Tk.Pn>??</Tk.Pn> <Tk.T>AnnotationKind</Tk.T>.<Tk.F>infer</Tk.F>(from: content)</> },
    { n: 30, c: <>{"    "}<Tk.Pn>{"}"}</Tk.Pn></> },
    { n: 31, c: <Tk.Pn>{"}"}</Tk.Pn> },
    { n: 44, fold: "f-ext",     c: <><Tk.K>extension</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Identifiable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 52, fold: "f-mark",    c: <><Tk.C>{"// MARK: – AnnotationView wiring"}</Tk.C></> },
    { n: 53, fold: "f-install", c: <><Tk.K>private func</Tk.K> <Tk.F>installBadge</Tk.F>(on view<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationView</Tk.T>) <Tk.Pn>{"{"}</Tk.Pn></> },
    { n: 54, c: <>{"    "}view.<Tk.F>apply</Tk.F>(theme: store.theme)</> },
    { n: 55, c: <>{"    "}view.<Tk.F>setNeedsLayout</Tk.F>()</> },
    { n: 57, c: <Tk.Pn>{"}"}</Tk.Pn> },
  ];

  function Editor({ folds, selected, setSelected }) {
    return (
      <div style={{
        flex: 1, minWidth: 0,
        background: "var(--editor-bg)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{
          height: 30, flexShrink: 0, display: "flex", alignItems: "center", gap: 8,
          padding: "0 14px",
          borderBottom: "0.5px solid var(--border-variant)",
          background: "var(--toolbar)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
        }}>
          <span>Annotation.swift</span>
          <span style={{ flex: 1 }}/>
          <Kbd>⌥⌘←</Kbd>collapse <Kbd>⌥⌘→</Kbd>expand
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "8px 0" }}>
          {SRC.map(l => {
            const f = l.fold;
            const collapsed = f && folds[f];
            const node = f ? TREE.find(t => t.id === f) : null;
            const k = node ? KIND[node.kind] : null;
            const isSel = selected === f;
            return (
              <div key={l.n} style={{
                display: "grid",
                gridTemplateColumns: "44px 14px 1fr",
                alignItems: "center", minHeight: 22,
                background: isSel ? "color-mix(in srgb, var(--accent-1) 12%, transparent)"
                  : collapsed ? `color-mix(in srgb, ${k.color} 7%, transparent)` : "transparent",
                borderLeft: isSel ? "2px solid var(--accent-1)" : "2px solid transparent",
              }}>
                <span style={{
                  textAlign: "right", paddingRight: 8,
                  font: "12px var(--font-mono)",
                  color: collapsed ? k.color : "var(--line-num)",
                  fontWeight: collapsed ? 600 : 400,
                }}>{l.n}</span>
                <span style={{
                  display: "flex", alignItems: "center", justifyContent: "center",
                  color: k?.color, transform: collapsed ? "rotate(-90deg)" : "none",
                  transition: "transform 150ms var(--ease-spring-snappy)",
                }}>{f ? <Ic.ChevD size={10}/> : null}</span>
                <code onClick={() => f && setSelected(f)} style={{
                  whiteSpace: "pre", color: "var(--editor-fg)",
                  font: "12px/1.55 var(--font-mono)",
                  paddingRight: 8, cursor: f ? "pointer" : "default",
                }}>
                  {l.c}
                  {collapsed ? (
                    <span style={{
                      display: "inline-flex", alignItems: "center", gap: 4,
                      marginLeft: 6,
                      padding: "1px 7px", borderRadius: 999,
                      background: `color-mix(in srgb, ${k.color} 20%, transparent)`,
                      boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${k.color} 55%, transparent)`,
                      color: k.color,
                      font: "500 10.5px var(--font-mono)",
                    }}><Ic.Ellipsis size={11}/> {node.lines} lines</span>
                  ) : null}
                </code>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  function Outline({ folds, toggle, foldAll, unfoldAll, foldLevel, selected, setSelected }) {
    return (
      <div style={{
        width: 312, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px" }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}>
            <span style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>Outline</span>
            <span style={{ font: "500 11px var(--font-mono)", color: "var(--text-muted)", marginLeft: 4 }}>
              {TREE.length} folds · depth 2
            </span>
          </div>
          <div style={{ marginTop: 10, display: "flex", flexWrap: "wrap", gap: 4 }}>
            <Pill size="sm" onClick={foldAll} icon={<Ic.Folded size={11}/>}>Fold All</Pill>
            <Pill size="sm" onClick={unfoldAll} icon={<Ic.ChevD size={11}/>}>Unfold All</Pill>
            <Pill size="sm" onClick={() => foldLevel(1)}>L1</Pill>
            <Pill size="sm" onClick={() => foldLevel(2)}>L2</Pill>
            <Pill size="sm" icon={<Ic.Note size={11}/>}>Fold Comments</Pill>
          </div>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "0 4px 8px" }}>
          {TREE.map(node => {
            const k = KIND[node.kind];
            const collapsed = !!folds[node.id];
            const isSel = selected === node.id;
            return (
              <div key={node.id} onClick={() => setSelected(node.id)}
                style={{
                  display: "grid",
                  gridTemplateColumns: `${10 + node.depth * 14}px 16px 1fr auto auto`,
                  alignItems: "center", gap: 6,
                  padding: "6px 8px", borderRadius: 5,
                  background: isSel ? "var(--element-selected)" : "transparent",
                  margin: "0 4px 1px",
                  cursor: "pointer",
                  boxShadow: isSel ? "inset 2px 0 0 0 var(--accent-1)" : "none",
                }}>
                <span style={{
                  height: 12, marginLeft: 8,
                  borderLeft: node.depth > 0 ? "1px solid var(--border-variant)" : "none",
                }}/>
                <button onClick={(e) => { e.stopPropagation(); toggle(node.id); }} style={{
                  border: "none", background: "transparent", cursor: "pointer", padding: 0,
                  width: 14, height: 14,
                  color: k.color,
                  transform: collapsed ? "rotate(-90deg)" : "none",
                  transition: "transform 150ms var(--ease-spring-snappy)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                }}><Ic.ChevD size={10}/></button>
                <div style={{ minWidth: 0 }}>
                  <div style={{
                    display: "flex", alignItems: "center", gap: 5,
                    font: "500 12px var(--font-sans)", color: "var(--text)",
                    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                  }}>
                    <span style={{
                      font: "600 9.5px var(--font-mono)", letterSpacing: 0.4,
                      color: k.color, textTransform: "uppercase",
                    }}>{k.label}</span>
                    <span style={{
                      overflow: "hidden", textOverflow: "ellipsis",
                    }}>{node.name}</span>
                  </div>
                  <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                    L{node.l1}–L{node.l2} · {node.lines} lines · id <span style={{ color: "var(--text-disabled)" }}>{node.id}</span>
                  </div>
                </div>
                <span style={{
                  font: "10px var(--font-mono)",
                  color: collapsed ? "var(--accent-1)" : "var(--text-disabled)",
                  letterSpacing: 0.4, textTransform: "uppercase",
                }}>{collapsed ? "folded" : "open"}</span>
              </div>
            );
          })}
        </div>
        <div style={{
          padding: 10, margin: 8, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
          display: "grid", gridTemplateColumns: "1fr auto", rowGap: 2,
        }}>
          <Overline>FOLD STORE</Overline><span/>
          <span>provider</span><span style={{ color: "var(--text)" }}>BraceFoldingProvider</span>
          <span>document length</span><span style={{ color: "var(--text)" }}>1,842 chars</span>
          <span>active runs</span><span style={{ color: "var(--text)" }}>{TREE.length}</span>
          <span>collapsed</span><span style={{ color: "var(--accent-1)" }}>{Object.values(folds).filter(Boolean).length}</span>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const initial = Object.fromEntries(TREE.filter(t => t.collapsed).map(t => [t.id, true]));
    const [folds, setFolds] = useState(initial);
    const [selected, setSelected] = useState("f-init");
    const toggle = (id) => setFolds(s => ({ ...s, [id]: !s[id] }));
    const foldAll = () => setFolds(Object.fromEntries(TREE.map(t => [t.id, true])));
    const unfoldAll = () => setFolds({});
    const foldLevel = (lvl) => setFolds(Object.fromEntries(TREE.filter(t => t.depth >= lvl).map(t => [t.id, true])));
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Folding · Outline" subtitle="CodeEditorFolding"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <Editor folds={folds} selected={selected} setSelected={setSelected}/>
          <Outline folds={folds} toggle={toggle} foldAll={foldAll} unfoldAll={unfoldAll}
            foldLevel={foldLevel} selected={selected} setSelected={setSelected}/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>fold provider: BraceFoldingProvider</span>
          <span>·</span>
          <span>LineFoldStorage backed by RangeStore</span>
          <span style={{ flex: 1 }}/>
          <span>9 folds · {Object.values(folds).filter(Boolean).length} collapsed</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.FoldB = FoldB;
