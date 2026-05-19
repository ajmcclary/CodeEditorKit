// COMPLETION · CONCEPT B — "PROVIDER WORKBENCH"
// A debug-friendly view that makes CompletionManager's provider
// architecture visible.  Triptych:
//   Left   · provider rail — LSPCompletionProvider, LanguageKeywordCompletionProvider,
//            SwiftUIClosureCompletionProvider, snippets — each with active dot,
//            duration, and match count
//   Centre · merged + ranked result list with full match highlighting,
//            CompletionRankingModel score breakdown badges, and the
//            CompletionItem.priority field
//   Right  · documentation panel with signature, body, and Insert
// Intended posture: a power user inspecting why ranking is what it is,
// or a contributor debugging a provider.  Less ergonomic for fast typing,
// dramatically more useful when something is wrong.

const ComB = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Kbd, Overline } = window;
  const { useState } = React;

  const KIND_LABEL = {
    type:     { letter: "T",  color: "var(--syn-type)"     },
    method:   { letter: "ƒ",  color: "var(--syn-function)" },
    function: { letter: "ƒ",  color: "var(--syn-function)" },
    property: { letter: "p",  color: "var(--syn-property)" },
    variable: { letter: "v",  color: "var(--syn-variable)" },
    keyword:  { letter: "K",  color: "var(--syn-keyword)"  },
    snippet:  { letter: "{}", color: "var(--accent-2)"     },
  };

  // Providers, in the order CompletionManager runs them.
  const PROVIDERS = [
    { id: "lsp",      label: "LSP",                 sub: "sourcekit-lsp · @initialized",  count: 8, duration: 18, color: "var(--accent-1)", active: true },
    { id: "keywords", label: "Language Keywords",   sub: "Swift · 113 keywords",          count: 1, duration: 1,  color: "var(--accent-3)", active: true },
    { id: "swiftui",  label: "SwiftUI Closures",    sub: "ViewBuilder · 42 patterns",      count: 0, duration: 2,  color: "var(--accent-2)", active: true },
    { id: "snippets", label: "Snippets",            sub: "User · 8 entries",              count: 1, duration: 0,  color: "var(--accent-4)", active: true },
  ];

  // CompletionRankingModel-style row.  bonuses captures the score
  // contributions: firstChar / consecutive / separator / camelCase / priority.
  const ITEMS = [
    { provider: "lsp",      text: "Annotation",            kind: "type",     detail: "struct, Sendable",            priority: 95, score: 198, ranges: [[0,3]], bonuses: { firstChar: 10, camel: 0, sep: 0, prio: 95, lspMatch: 88 } },
    { provider: "lsp",      text: "AnnotationKind",        kind: "type",     detail: "enum",                        priority: 92, score: 190, ranges: [[0,3]], bonuses: { firstChar: 10, camel: 25, sep: 0, prio: 92, lspMatch: 63 } },
    { provider: "lsp",      text: "AnnotationView",        kind: "type",     detail: "class : PlatformView",        priority: 88, score: 176, ranges: [[0,3]], bonuses: { firstChar: 10, camel: 25, sep: 0, prio: 88, lspMatch: 53 } },
    { provider: "lsp",      text: "areAnnotationsEnabled", kind: "property", detail: "Bool",                        priority: 65, score: 142, ranges: [[3,5],[5,6]], bonuses: { firstChar: 0, camel: 50, sep: 0, prio: 65, lspMatch: 27 } },
    { provider: "lsp",      text: "addAnnotation(_:)",     kind: "method",   detail: "(Annotation) -> Void",        priority: 60, score: 138, ranges: [[0,1],[3,6]], bonuses: { firstChar: 10, camel: 25, sep: 0, prio: 60, lspMatch: 43 } },
    { provider: "lsp",      text: "annotations",           kind: "property", detail: "[Annotation]",                priority: 50, score: 130, ranges: [[0,3]], bonuses: { firstChar: 10, camel: 0, sep: 0, prio: 50, lspMatch: 70 } },
    { provider: "snippets", text: "annotate",              kind: "snippet",  detail: "Annotate selected expression", priority: 30, score: 92,  ranges: [[0,3]], bonuses: { firstChar: 10, camel: 0, sep: 0, prio: 30, lspMatch: 0 } },
    { provider: "keywords", text: "annotation",            kind: "keyword",  detail: "Swift attribute",             priority: 20, score: 70,  ranges: [[0,3]], bonuses: { firstChar: 10, camel: 0, sep: 0, prio: 20, lspMatch: 0 } },
  ];

  function MatchText({ text, ranges, c = "var(--accent-1)" }) {
    const parts = []; let i = 0;
    for (const [s, e] of ranges) {
      if (s > i) parts.push({ s: text.slice(i, s), m: false });
      parts.push({ s: text.slice(s, e), m: true });
      i = e;
    }
    if (i < text.length) parts.push({ s: text.slice(i), m: false });
    return (
      <span>{parts.map((p, k) => (
        <span key={k} style={{
          color: p.m ? c : "var(--text)",
          fontWeight: p.m ? 700 : 500,
          textDecoration: p.m ? "underline" : "none",
          textUnderlineOffset: 2,
          textDecorationColor: p.m ? `color-mix(in srgb, ${c} 60%, transparent)` : undefined,
        }}>{p.s}</span>
      ))}</span>
    );
  }

  function ProviderRail({ activeProv, setActiveProv }) {
    return (
      <div style={{
        width: 220, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px 8px",
          display: "flex", alignItems: "center", gap: 6 }}>
          <Overline>PROVIDERS</Overline>
          <span style={{ flex: 1 }}/>
          <span style={{ font: "11px var(--font-mono)", color: "var(--text-disabled)" }}>4 · 21 ms</span>
        </div>
        <div style={{ padding: "0 6px", display: "flex", flexDirection: "column", gap: 1 }}>
          <div onClick={() => setActiveProv("all")} style={provRow("all", activeProv === "all", "var(--text)")}>
            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--text-muted)" }}/>
            <span style={{ flex: 1, font: `${activeProv === "all" ? 600 : 500} 12px var(--font-sans)` }}>All providers</span>
            <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-disabled)" }}>{ITEMS.length}</span>
          </div>
          {PROVIDERS.map(p => (
            <div key={p.id} onClick={() => setActiveProv(p.id)} style={provRow(p.id, activeProv === p.id, p.color)}>
              <span style={{
                width: 6, height: 6, borderRadius: "50%",
                background: p.active ? p.color : "var(--text-disabled)",
                boxShadow: p.active ? `0 0 6px ${p.color}` : "none",
              }}/>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  font: `${activeProv === p.id ? 600 : 500} 12px var(--font-sans)`,
                  color: "var(--text)",
                }}>{p.label}</div>
                <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                  {p.sub}
                </div>
              </div>
              <span style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 1 }}>
                <span style={{
                  font: "600 10px var(--font-mono)", color: p.count ? p.color : "var(--text-disabled)",
                }}>{p.count}</span>
                <span style={{ font: "9.5px var(--font-mono)", color: "var(--text-disabled)" }}>
                  {p.duration}ms
                </span>
              </span>
            </div>
          ))}
        </div>

        <div style={{ flex: 1 }}/>
        <div style={{ padding: 10, margin: 8, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)" }}>
          <Overline>FUZZY MATCHER</Overline>
          <div style={{
            font: "11px var(--font-mono)", color: "var(--text-muted)",
            marginTop: 6, display: "grid", gridTemplateColumns: "1fr auto", rowGap: 3,
          }}>
            <span>firstChar bonus</span><span style={{ color: "var(--text)" }}>+10</span>
            <span>consecutive</span><span style={{ color: "var(--text)" }}>+15</span>
            <span>camelCase</span><span style={{ color: "var(--text)" }}>+25</span>
            <span>separator</span><span style={{ color: "var(--text)" }}>+20</span>
            <span>gap penalty</span><span style={{ color: "var(--text)" }}>−3</span>
          </div>
        </div>
      </div>
    );
  }
  const provRow = (id, active, c) => ({
    display: "flex", alignItems: "center", gap: 8,
    padding: "6px 8px", borderRadius: 6, cursor: "pointer",
    background: active ? "var(--element-selected)" : "transparent",
    position: "relative",
    boxShadow: active ? `inset 2px 0 0 0 ${c}` : "none",
  });

  function ResultsList({ sel, setSel, activeProv }) {
    const filtered = activeProv === "all" ? ITEMS : ITEMS.filter(i => i.provider === activeProv);
    return (
      <div style={{
        flex: 1, minWidth: 0, minHeight: 0,
        background: "var(--bg)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{
          padding: "12px 14px 10px",
          borderBottom: "0.5px solid var(--border-variant)",
          background: "var(--surface)",
        }}>
          <div style={{
            display: "flex", alignItems: "center", gap: 8,
            padding: "0 10px", height: 30, borderRadius: 7,
            background: "var(--element-bg)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          }}>
            <span style={{ color: "var(--text-muted)" }}><Ic.Search size={13}/></span>
            <span style={{ font: "13px var(--font-mono)", color: "var(--text)" }}>ann</span>
            <span style={{
              width: 2, height: 14, background: "var(--accent-1)",
              animation: "blink 1s steps(2) infinite",
            }}/>
            <span style={{ flex: 1 }}/>
            <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
              {filtered.length} matches · top score 198
            </span>
          </div>
          <style>{`@keyframes blink { 50% { opacity: 0 } }`}</style>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 8 }}>
            <Overline>SORT BY</Overline>
            <Pill size="sm" active>Score</Pill>
            <Pill size="sm">Priority</Pill>
            <Pill size="sm">Alphabetical</Pill>
            <span style={{ flex: 1 }}/>
            <span style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)" }}>
              parallel ≥ <span style={{ color: "var(--text)", font: "10.5px var(--font-mono)" }}>50 candidates</span>
            </span>
          </div>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "6px 6px 12px" }}>
          {filtered.map((it, i) => {
            const k = KIND_LABEL[it.kind];
            const active = i === sel;
            const prov = PROVIDERS.find(p => p.id === it.provider);
            return (
              <div key={i} onClick={() => setSel(i)} style={{
                display: "grid",
                gridTemplateColumns: "22px 1fr auto auto",
                alignItems: "center", gap: 10,
                padding: "7px 10px",
                borderRadius: 6,
                background: active ? "color-mix(in srgb, var(--accent-1) 14%, transparent)" : "transparent",
                boxShadow: active ? "inset 0 0 0 0.5px color-mix(in srgb, var(--accent-1) 35%, transparent)" : "none",
                cursor: "pointer",
              }}>
                <span style={{
                  width: 18, height: 18, borderRadius: 4,
                  background: `color-mix(in srgb, ${k.color} 22%, transparent)`,
                  color: k.color,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  font: "700 9.5px var(--font-mono)",
                }}>{k.letter}</span>
                <div style={{ minWidth: 0 }}>
                  <code style={{ font: "13px var(--font-mono)", display: "block",
                    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                    <MatchText text={it.text} ranges={it.ranges}/>
                  </code>
                  <code style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                    {it.detail}
                  </code>
                </div>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 2 }}>
                  <span style={{
                    font: "600 10px var(--font-mono)", color: prov?.color,
                    padding: "1px 6px", borderRadius: 4,
                    background: `color-mix(in srgb, ${prov?.color} 18%, transparent)`,
                  }}>{prov?.label}</span>
                  <span style={{ font: "10px var(--font-mono)", color: "var(--text-disabled)" }}>
                    priority {it.priority}
                  </span>
                </div>
                <div style={{
                  font: "700 14px var(--font-mono)", color: active ? "var(--accent-1)" : "var(--text)",
                  minWidth: 36, textAlign: "right",
                }}>{it.score}</div>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  function DocPanel({ item }) {
    const k = KIND_LABEL[item.kind];
    const prov = PROVIDERS.find(p => p.id === item.provider);
    return (
      <div style={{
        width: 270, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "14px 14px 0" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <span style={{
              width: 22, height: 22, borderRadius: 5,
              background: `color-mix(in srgb, ${k.color} 22%, transparent)`,
              color: k.color, fontWeight: 700, font: "11px var(--font-mono)",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>{k.letter}</span>
            <span style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
              color: k.color }}>{item.kind}</span>
            <span style={{ flex: 1 }}/>
            <span style={{ font: "10px var(--font-mono)", color: prov?.color }}>{prov?.label}</span>
          </div>
          <div style={{ font: "700 16px var(--font-mono)", color: "var(--text)", marginTop: 8,
            wordBreak: "break-word" }}>{item.text}</div>
          <div style={{
            font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 4,
          }}>{item.detail}</div>
          <div style={{
            marginTop: 10, padding: "6px 8px",
            background: "var(--editor-bg)",
            borderRadius: 5,
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
            font: "11.5px/1.45 var(--font-mono)", color: "var(--editor-fg)",
          }}>
            <Tk.K>public</Tk.K> <Tk.K>struct</Tk.K> <Tk.T>{item.text}</Tk.T>{item.detail.startsWith(":") ? <> <Tk.Pn>{item.detail}</Tk.Pn></> : null}
          </div>
        </div>
        {/* Ranking breakdown */}
        <div style={{ padding: "12px 14px" }}>
          <Overline>RANKING</Overline>
          <div style={{
            marginTop: 6, display: "grid", gridTemplateColumns: "1fr auto", rowGap: 4,
            font: "11px var(--font-mono)", color: "var(--text-muted)",
          }}>
            <span>fuzzy match</span><span style={{ color: "var(--text)" }}>+{item.bonuses.lspMatch || 0}</span>
            {item.bonuses.firstChar ? <><span>first-char bonus</span><span style={{ color: "var(--text)" }}>+{item.bonuses.firstChar}</span></> : null}
            {item.bonuses.camel ? <><span>camelCase</span><span style={{ color: "var(--text)" }}>+{item.bonuses.camel}</span></> : null}
            <span>priority</span><span style={{ color: "var(--text)" }}>+{item.bonuses.prio}</span>
            <span style={{ paddingTop: 4,
              borderTop: "0.5px solid var(--border-variant)",
              gridColumn: "1 / -1",
              display: "grid", gridTemplateColumns: "1fr auto",
            }}>
              <span style={{ color: "var(--text)", fontWeight: 600 }}>total</span>
              <span style={{ color: "var(--accent-1)", fontWeight: 700 }}>{item.score}</span>
            </span>
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ padding: 12, borderTop: "0.5px solid var(--border-variant)" }}>
          <button style={{
            width: "100%",
            background: "var(--accent-1)", color: "#fff", border: "none",
            height: 30, borderRadius: 6,
            font: "600 12px var(--font-sans)", cursor: "pointer",
          }}>Insert</button>
          <div style={{
            display: "flex", alignItems: "center", justifyContent: "center", gap: 4,
            marginTop: 6, font: "10.5px var(--font-sans)", color: "var(--text-muted)",
          }}>
            <Kbd>⏎</Kbd> commit · <Kbd>⎋</Kbd> dismiss
          </div>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [sel, setSel] = useState(0);
    const [activeProv, setActiveProv] = useState("all");
    const filtered = activeProv === "all" ? ITEMS : ITEMS.filter(i => i.provider === activeProv);
    const item = filtered[sel] || filtered[0];
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Completion · Workbench" subtitle="CompletionManager debug"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <ProviderRail activeProv={activeProv} setActiveProv={setActiveProv}/>
          <ResultsList sel={sel} setSel={setSel} activeProv={activeProv}/>
          <DocPanel item={item}/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>prefix: <span style={{ color: "var(--accent-1)" }}>"ann"</span></span>
          <span>·</span>
          <span>language: Swift</span>
          <span style={{ flex: 1 }}/>
          <span>broadcaster: 3 listeners</span>
          <span>debounce: 120 ms</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ComB = ComB;
