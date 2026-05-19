// FOLDING · CONCEPT C — "ATLAS"
// Single-page treatment.  Folding becomes a document-wide visualization:
// the entire file is rendered as a fold-density Atlas — a wide
// "topo map" where every fold region paints a horizontal slab whose
// width = lines folded and colour = kind.  Above the map: per-kind
// stats and bulk actions.  Below the map: the provider registry from
// FoldingProviderRegistry.swift with per-language hit counts.
// Posture: librarian / archaeologist view of a large file's structure.

const FoldC = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Overline, Kbd, Segmented } = window;
  const { useState } = React;

  const KIND = {
    function: { color: "var(--syn-function)", label: "Function" },
    type:     { color: "var(--syn-type)",     label: "Type"     },
    region:   { color: "var(--accent-2)",     label: "Region"   },
    comment:  { color: "var(--syn-comment)",  label: "Comment"  },
    block:    { color: "var(--text-muted)",   label: "Block"    },
  };

  // Larger synthetic file (212 lines) so the atlas has texture.
  const FOLDS = [
    { id: "f-imports",  kind: "region",   depth: 0, l1:   1, l2:   8,  name: "Imports + MARK" },
    { id: "f-doc",      kind: "comment",  depth: 0, l1:  10, l2:  18,  name: "Doc comment" },
    { id: "f-ann",      kind: "type",     depth: 0, l1:  21, l2:  64,  name: "struct Annotation" },
    { id: "f-ann-init", kind: "function", depth: 1, l1:  30, l2:  41,  name: "init(range:content:id:kind:)" },
    { id: "f-ann-rk",   kind: "function", depth: 1, l1:  43, l2:  50,  name: "var resolvedKind" },
    { id: "f-ann-enc",  kind: "function", depth: 1, l1:  52, l2:  60,  name: "func encode(to:)" },
    { id: "f-kind",     kind: "type",     depth: 0, l1:  68, l2:  118, name: "enum AnnotationKind" },
    { id: "f-kind-col", kind: "function", depth: 1, l1:  75, l2:  92,  name: "color(in: theme)" },
    { id: "f-kind-icn", kind: "function", depth: 1, l1:  94, l2: 102,  name: "iconName" },
    { id: "f-kind-inf", kind: "function", depth: 1, l1: 105, l2: 116,  name: "infer(from:)" },
    { id: "f-line",     kind: "region",   depth: 0, l1: 121, l2: 130,  name: "protocol LineAnnotation" },
    { id: "f-msg",      kind: "type",     depth: 0, l1: 133, l2: 170,  name: "class MessageLineAnnotation" },
    { id: "f-msg-init", kind: "function", depth: 1, l1: 142, l2: 156,  name: "init(id:message:kind:location:)" },
    { id: "f-mark",     kind: "block",    depth: 0, l1: 173, l2: 173,  name: "// MARK: – AnnotationView" },
    { id: "f-view",     kind: "type",     depth: 0, l1: 175, l2: 212,  name: "class AnnotationView" },
    { id: "f-view-set", kind: "function", depth: 1, l1: 182, l2: 200,  name: "func setup()" },
  ];
  const TOTAL_LINES = 212;
  const PROVIDERS = [
    { name: "BraceFoldingProvider",       langs: ["Swift", "JS", "TS", "C", "C++", "Java", "Go", "Rust", "CSS", "JSON", "PHP"], hits: 14 },
    { name: "IndentationFoldingProvider", langs: ["Python", "YAML"],          hits: 0 },
    { name: "MarkdownFoldingProvider",    langs: ["Markdown"],                 hits: 0 },
    { name: "XMLFoldingProvider",         langs: ["XML", "HTML"],              hits: 0 },
    { name: "HeuristicFoldProvider",      langs: ["C#", "Kotlin", "Dart"],     hits: 0 },
    { name: "DockerfileFoldingProvider",  langs: ["Dockerfile"],               hits: 0 },
    { name: "TomlFoldingProvider",        langs: ["TOML"],                     hits: 0 },
    { name: "LuaFoldingProvider",         langs: ["Lua"],                      hits: 0 },
    { name: "ShellFoldingProvider",       langs: ["Shell"],                    hits: 0 },
    { name: "SQLFoldingProvider",         langs: ["SQL"],                      hits: 0 },
    { name: "RubyFoldingProvider",        langs: ["Ruby"],                     hits: 0 },
  ];

  function Atlas({ folds, toggle, hover, setHover }) {
    return (
      <div style={{
        background: "var(--editor-bg)",
        borderRadius: 10,
        boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        overflow: "hidden",
      }}>
        {/* line ruler */}
        <div style={{
          height: 18,
          display: "grid",
          gridTemplateColumns: "repeat(10, 1fr)",
          alignItems: "center",
          background: "var(--toolbar)",
          borderBottom: "0.5px solid var(--border-variant)",
          font: "9.5px var(--font-mono)", color: "var(--text-muted)",
          paddingLeft: 6,
        }}>
          {Array.from({ length: 10 }).map((_, i) => (
            <span key={i} style={{ borderLeft: i ? "0.5px dashed var(--border-variant)" : "none", paddingLeft: 4 }}>
              {Math.round(TOTAL_LINES * i / 10) || 1}
            </span>
          ))}
        </div>
        {/* depth 0 lane */}
        {[0, 1].map(depth => (
          <div key={depth} style={{
            position: "relative", height: depth === 0 ? 30 : 22,
            background: depth === 0 ? "color-mix(in srgb, var(--bg) 50%, var(--editor-bg))" : "var(--editor-bg)",
            borderTop: depth ? "0.5px dashed var(--border-variant)" : "none",
          }}>
            <div style={{
              position: "absolute", left: 4, top: 4,
              font: "700 9px var(--font-sans)", letterSpacing: 0.5, textTransform: "uppercase",
              color: "var(--text-muted)",
            }}>D{depth}</div>
            {FOLDS.filter(f => f.depth === depth).map(f => {
              const left = (f.l1 / TOTAL_LINES) * 100;
              const width = ((f.l2 - f.l1 + 1) / TOTAL_LINES) * 100;
              const k = KIND[f.kind];
              const collapsed = !!folds[f.id];
              const isHover = hover === f.id;
              return (
                <div key={f.id}
                  onMouseEnter={() => setHover(f.id)}
                  onMouseLeave={() => setHover(null)}
                  onClick={() => toggle(f.id)}
                  style={{
                    position: "absolute",
                    left: `${left}%`, width: `calc(${width}% - 1px)`,
                    top: depth === 0 ? 12 : 6, bottom: 4,
                    minWidth: 6,
                    background: collapsed
                      ? `repeating-linear-gradient(45deg, ${k.color}, ${k.color} 3px, color-mix(in srgb, ${k.color} 55%, transparent) 3px, color-mix(in srgb, ${k.color} 55%, transparent) 6px)`
                      : `color-mix(in srgb, ${k.color} 50%, transparent)`,
                    boxShadow: isHover
                      ? `inset 0 0 0 1px ${k.color}, 0 0 0 2px color-mix(in srgb, ${k.color} 35%, transparent)`
                      : `inset 0 0 0 0.5px color-mix(in srgb, ${k.color} 65%, transparent)`,
                    borderRadius: 3, cursor: "pointer",
                    transition: "box-shadow 150ms var(--ease-spring-snappy)",
                  }}/>
              );
            })}
          </div>
        ))}
      </div>
    );
  }

  function HoverCard({ id }) {
    const f = FOLDS.find(x => x.id === id);
    if (!f) return null;
    const k = KIND[f.kind];
    return (
      <div style={{
        marginTop: 8,
        padding: 10, borderRadius: 8,
        background: "var(--surface)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        display: "flex", alignItems: "center", gap: 12,
      }}>
        <div style={{
          width: 28, height: 28, borderRadius: 6,
          background: `color-mix(in srgb, ${k.color} 22%, transparent)`,
          color: k.color, display: "flex", alignItems: "center", justifyContent: "center",
        }}><Ic.Braces size={15}/></div>
        <div style={{ flex: 1 }}>
          <div style={{
            font: "600 13px var(--font-mono)", color: "var(--text)",
          }}>{f.name}</div>
          <div style={{ font: "11px var(--font-mono)", color: "var(--text-muted)" }}>
            L{f.l1}–L{f.l2} · {f.l2 - f.l1 + 1} lines · depth {f.depth} · kind <span style={{ color: k.color }}>{k.label}</span>
          </div>
        </div>
        <div style={{ display: "flex", gap: 6 }}>
          <Pill size="sm">Reveal</Pill>
          <Pill size="sm" active accent={k.color}>Toggle Fold</Pill>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [folds, setFolds] = useState({ "f-doc": true, "f-ann-init": true, "f-kind-icn": true });
    const [hover, setHover] = useState("f-ann");
    const [mode, setMode] = useState("kind");
    const toggle = (id) => setFolds(s => ({ ...s, [id]: !s[id] }));
    const foldAll = () => setFolds(Object.fromEntries(FOLDS.map(f => [f.id, true])));
    const unfoldAll = () => setFolds({});

    const byKind = Object.entries(KIND).map(([k, v]) => ({
      k, v, n: FOLDS.filter(f => f.kind === k).length,
      coll: FOLDS.filter(f => f.kind === k && folds[f.id]).length,
      lines: FOLDS.filter(f => f.kind === k).reduce((s, f) => s + (f.l2 - f.l1 + 1), 0),
    })).filter(b => b.n > 0);

    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Folding · Atlas" subtitle="CodeEditorFolding · Annotation.swift"
          right={
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Segmented items={[
                { value: "kind",  label: "By Kind"  },
                { value: "depth", label: "By Depth" },
                { value: "hits",  label: "By Reads" },
              ]} value={mode} onChange={setMode}/>
              <ThemeSwitch theme={theme} setTheme={setTheme}/>
            </div>
          }/>
        <div style={{
          flex: 1, minHeight: 0, overflowY: "auto", background: "var(--bg)",
          padding: 16,
        }}>
          {/* Header strip */}
          <div style={{
            display: "flex", alignItems: "baseline", gap: 14,
            marginBottom: 10,
          }}>
            <span style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>
              Atlas
            </span>
            <span style={{ font: "12px var(--font-mono)", color: "var(--text-muted)" }}>
              212 lines · 16 fold regions · 2 collapsed (~17 lines hidden)
            </span>
            <span style={{ flex: 1 }}/>
            <Pill size="sm" onClick={foldAll} icon={<Ic.Folded size={11}/>}>Fold All</Pill>
            <Pill size="sm" onClick={unfoldAll}>Unfold All</Pill>
            <Pill size="sm">Fold Comments</Pill>
            <Pill size="sm">Fold Functions</Pill>
          </div>

          <Atlas folds={folds} toggle={toggle} hover={hover} setHover={setHover}/>
          <HoverCard id={hover}/>

          {/* By-kind tally */}
          <div style={{
            marginTop: 16, display: "grid",
            gridTemplateColumns: "repeat(4, 1fr)", gap: 8,
          }}>
            {byKind.map(b => (
              <div key={b.k} style={{
                padding: 10, borderRadius: 8,
                background: "var(--surface)",
                boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${b.v.color} 40%, transparent)`,
              }}>
                <div style={{
                  font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
                  color: b.v.color,
                }}>{b.v.label}</div>
                <div style={{
                  display: "flex", alignItems: "baseline", gap: 5, marginTop: 2,
                }}>
                  <span style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)" }}>{b.n}</span>
                  <span style={{ font: "11px var(--font-mono)", color: "var(--text-muted)" }}>folds</span>
                </div>
                <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)", marginTop: 2 }}>
                  {b.lines} lines · {b.coll} collapsed
                </div>
              </div>
            ))}
          </div>

          {/* Provider registry */}
          <div style={{
            marginTop: 18, padding: 12, borderRadius: 10,
            background: "var(--surface)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Overline>FoldingProviderRegistry</Overline>
              <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                · {PROVIDERS.length} providers · 25 languages
              </span>
            </div>
            <div style={{
              marginTop: 8, display: "grid",
              gridTemplateColumns: "repeat(2, 1fr)", rowGap: 6, columnGap: 14,
            }}>
              {PROVIDERS.map(p => (
                <div key={p.name} style={{
                  display: "flex", alignItems: "center", gap: 8,
                  padding: "5px 8px", borderRadius: 5,
                  background: p.hits ? "color-mix(in srgb, var(--accent-1) 8%, transparent)" : "transparent",
                  boxShadow: p.hits ? "inset 0 0 0 0.5px color-mix(in srgb, var(--accent-1) 35%, transparent)" : "none",
                }}>
                  <span style={{
                    width: 6, height: 6, borderRadius: "50%",
                    background: p.hits ? "var(--accent-1)" : "var(--text-disabled)",
                    boxShadow: p.hits ? "0 0 6px var(--accent-1)" : "none",
                  }}/>
                  <span style={{ font: "500 12px var(--font-mono)", color: "var(--text)", flex: 1 }}>{p.name}</span>
                  <span style={{
                    font: "10.5px var(--font-sans)", color: "var(--text-muted)",
                    maxWidth: 220, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
                  }}>{p.langs.join(" · ")}</span>
                  <span style={{
                    font: "600 11px var(--font-mono)",
                    color: p.hits ? "var(--accent-1)" : "var(--text-disabled)",
                    minWidth: 28, textAlign: "right",
                  }}>{p.hits}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.FoldC = FoldC;
