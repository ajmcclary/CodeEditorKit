// COMPLETION · CONCEPT A — "POPOVER"
// The in-editor popover, anchored at the caret.  Exactly what
// CompletionViewController draws: a list of CompletionItems with kind
// icons, match-highlighted text (OptimizedFuzzyMatcher.MatchResult
// .matchedRanges), and a detail/type signature on the right.  Hovering
// or arrowing into a row reveals the secondary documentation panel
// trailing the popover.  Includes loading + empty states the
// CompletionPopupState models.

const ComA = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Segmented, Pill, Kbd } = window;
  const { useState } = React;

  // Mirrors CompletionItemKind (LSP-aligned).
  const KIND = {
    type:     { letter: "T", icon: <Ic.Type size={10}/>,    color: "var(--syn-type)"     },
    function: { letter: "ƒ", icon: <Ic.Func size={10}/>,    color: "var(--syn-function)" },
    method:   { letter: "ƒ", icon: <Ic.Func size={10}/>,    color: "var(--syn-function)" },
    property: { letter: "p", icon: <Ic.Prop size={10}/>,    color: "var(--syn-property)" },
    variable: { letter: "v", icon: <Ic.Var size={10}/>,     color: "var(--syn-variable)" },
    keyword:  { letter: "K", icon: <Ic.Keyword size={10}/>, color: "var(--syn-keyword)"  },
    snippet:  { letter: "{}", icon: <Ic.Snippet size={10}/>,color: "var(--accent-2)"     },
    module:   { letter: "M", icon: <Ic.Mod size={10}/>,     color: "var(--accent-3)"     },
  };

  // Pre-computed matched ranges for prefix "ann" (lowercase positions
  // into each item.text) — what OptimizedFuzzyMatcher.MatchResult
  // .matchedRanges would yield.
  const ITEMS = [
    { text: "Annotation",            kind: "type",     detail: ": Sendable",                  score: 198, provider: "lsp",       ranges: [[0,3]], doc: { sig: "public struct Annotation: Sendable", body: "Represents an inline annotation in the code editor. Annotations are visual markers that appear inline with code to highlight TODOs, warnings, errors, or custom notes." } },
    { text: "AnnotationKind",        kind: "type",     detail: ": RawRepresentable<String>",  score: 190, provider: "lsp",       ranges: [[0,3]] },
    { text: "AnnotationView",        kind: "type",     detail: ": PlatformView",              score: 176, provider: "lsp",       ranges: [[0,3]] },
    { text: "areAnnotationsEnabled", kind: "property", detail: "Bool",                        score: 142, provider: "lsp",       ranges: [[3,5],[5,6]] },
    { text: "addAnnotation(_:)",     kind: "method",   detail: "(Annotation) -> Void",        score: 138, provider: "lsp",       ranges: [[0,1],[3,6]] },
    { text: "annotations",           kind: "property", detail: "[Annotation]",                score: 130, provider: "lsp",       ranges: [[0,3]] },
    { text: "annotation",            kind: "variable", detail: "any LineAnnotation",          score: 120, provider: "lsp",       ranges: [[0,3]] },
    { text: "annotationsContentView", kind: "property", detail: "AnnotationsContentView",     score: 110, provider: "lsp",       ranges: [[0,3]] },
    { text: "annotate",              kind: "snippet",  detail: "let annotation = Annotation(…)",       score: 92,  provider: "snippets",  ranges: [[0,3]] },
    { text: "annotations",           kind: "keyword",  detail: "search term",                 score: 70,  provider: "keywords",  ranges: [[0,3]] },
  ];

  function MatchText({ text, ranges }) {
    // Build a sequence of spans: regular for non-matched chars,
    // accent-bold for matched runs.
    const parts = [];
    let i = 0;
    for (const [s, e] of ranges) {
      if (s > i) parts.push({ s: text.slice(i, s), m: false });
      parts.push({ s: text.slice(s, e), m: true });
      i = e;
    }
    if (i < text.length) parts.push({ s: text.slice(i), m: false });
    return (
      <span>
        {parts.map((p, k) => (
          <span key={k} style={{
            color: p.m ? "var(--accent-1)" : "var(--text)",
            fontWeight: p.m ? 700 : 500,
            textDecoration: p.m ? "underline" : "none",
            textUnderlineOffset: 2,
            textDecorationColor: p.m ? "color-mix(in srgb, var(--accent-1) 60%, transparent)" : undefined,
          }}>{p.s}</span>
        ))}
      </span>
    );
  }

  function ItemRow({ item, active }) {
    const k = KIND[item.kind];
    return (
      <div style={{
        display: "grid",
        gridTemplateColumns: "22px 1fr auto auto",
        alignItems: "center", gap: 8,
        padding: "5px 9px",
        background: active ? `color-mix(in srgb, ${k.color} 18%, transparent)` : "transparent",
        borderRadius: 5,
        boxShadow: active ? `inset 0 0 0 0.5px color-mix(in srgb, ${k.color} 35%, transparent)` : "none",
      }}>
        <span style={{
          width: 18, height: 18, borderRadius: 4,
          background: `color-mix(in srgb, ${k.color} 22%, transparent)`,
          color: k.color,
          display: "flex", alignItems: "center", justifyContent: "center",
          font: "700 9.5px var(--font-mono)",
        }}>{k.letter}</span>
        <code style={{ font: "13px var(--font-mono)", whiteSpace: "nowrap",
          overflow: "hidden", textOverflow: "ellipsis" }}>
          <MatchText text={item.text} ranges={item.ranges}/>
        </code>
        <code style={{
          font: "11px var(--font-mono)", color: "var(--text-muted)", textAlign: "right",
          maxWidth: 168, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
        }}>{item.detail}</code>
        <span style={{
          font: "10px var(--font-mono)", color: "var(--text-disabled)",
          minWidth: 22, textAlign: "right",
        }}>{item.score}</span>
      </div>
    );
  }

  // Editor strip the popover anchors to.
  function EditorStrip() {
    return (
      <div style={{
        flex: 1, minHeight: 0,
        background: "var(--editor-bg)", padding: "12px 0",
        position: "relative",
      }}>
        {[
          { n: 41, c: <><Tk.K>func</Tk.K> <Tk.F>register</Tk.F>(<Tk.V>_</Tk.V> store: <Tk.T>AnnotationStore</Tk.T>) <Tk.Pn>{"{"}</Tk.Pn></> },
          { n: 42, c: <>{"    "}store.<Tk.F>removeAll</Tk.F>()</> },
          { n: 43, c: <>{"    "}<Tk.K>let</Tk.K> ann <Tk.Pn>=</Tk.Pn> <Tk.T>Ann</Tk.T></>, caret: true },
          { n: 44, c: <>{"    "}store.<Tk.F>insert</Tk.F>(ann)</> },
          { n: 45, c: <Tk.Pn>{"}"}</Tk.Pn> },
        ].map(l => (
          <div key={l.n} style={{
            display: "grid", gridTemplateColumns: "44px 1fr", alignItems: "center",
            minHeight: 20,
            background: l.caret ? "color-mix(in srgb, var(--accent-1) 8%, transparent)" : "transparent",
          }}>
            <span style={{
              textAlign: "right", paddingRight: 8,
              font: "12px var(--font-mono)", color: l.caret ? "var(--active-line-num)" : "var(--line-num)",
            }}>{l.n}</span>
            <code style={{
              whiteSpace: "pre", color: "var(--editor-fg)",
              font: "13px/1.55 var(--font-mono)",
            }}>
              {l.c}
              {l.caret ? (
                <>
                  <span style={{
                    display: "inline-block", width: 2, height: 16, verticalAlign: "-3px",
                    background: "var(--accent-1)",
                    animation: "blink 1s steps(2) infinite",
                  }}/>
                </>
              ) : null}
            </code>
          </div>
        ))}
        <style>{`@keyframes blink { 50% { opacity: 0 } }`}</style>
      </div>
    );
  }

  function Empty() {
    return (
      <div style={{ padding: "28px 16px", textAlign: "center" }}>
        <div style={{
          width: 36, height: 36, borderRadius: "50%",
          margin: "0 auto", background: "var(--element-bg)",
          display: "flex", alignItems: "center", justifyContent: "center",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          color: "var(--text-muted)",
        }}><Ic.Search size={16}/></div>
        <div style={{ marginTop: 10, font: "600 13px var(--font-sans)", color: "var(--text)" }}>No completions</div>
        <div style={{ font: "11.5px var(--font-sans)", color: "var(--text-muted)", marginTop: 2 }}>
          Three providers ran. None of them produced a match for "<code style={{ font: "11px var(--font-mono)", color: "var(--text)" }}>fmpngo</code>".
        </div>
      </div>
    );
  }

  function Loading() {
    return (
      <div style={{ padding: "20px 14px 18px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{
            width: 12, height: 12, borderRadius: "50%",
            border: "1.5px solid var(--accent-1)",
            borderTopColor: "transparent",
            animation: "spin 0.8s linear infinite",
          }}/>
          <span style={{ font: "500 11.5px var(--font-sans)", color: "var(--text-muted)" }}>
            Querying providers… <span style={{ color: "var(--text)" }}>sourcekit-lsp</span> · keywords · snippets
          </span>
        </div>
        {/* Skeleton rows */}
        <div style={{ marginTop: 10 }}>
          {[0,1,2,3].map(i => (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 8, padding: "5px 4px",
            }}>
              <div style={{ width: 18, height: 18, borderRadius: 4, background: "var(--element-bg)" }}/>
              <div style={{ height: 10, borderRadius: 3, background: "var(--element-bg)", flex: 1, opacity: 1 - i * 0.18 }}/>
              <div style={{ height: 10, width: 60, borderRadius: 3, background: "var(--element-bg)", opacity: 0.5 }}/>
            </div>
          ))}
        </div>
        <style>{`@keyframes spin { to { transform: rotate(360deg) } }`}</style>
      </div>
    );
  }

  function Popover({ state, sel, setSel }) {
    const showDocs = state === "ok" && ITEMS[sel]?.doc;
    return (
      <div style={{
        position: "absolute", top: 56, left: 102, zIndex: 5,
        display: "flex", gap: 10,
      }}>
        <div style={{
          width: 340,
          background: "var(--elevated)",
          borderRadius: 9,
          boxShadow: "inset 0 0 0 0.5px var(--border), 0 12px 36px rgba(0,0,0,0.45)",
          backdropFilter: "blur(10px)",
          overflow: "hidden",
        }}>
          {/* Tiny header — fuzzy state */}
          <div style={{
            display: "flex", alignItems: "center", gap: 6,
            padding: "5px 10px",
            background: "color-mix(in srgb, var(--accent-1) 7%, transparent)",
            borderBottom: "0.5px solid var(--border-variant)",
            font: "11px var(--font-mono)", color: "var(--text-muted)",
          }}>
            <span>prefix:</span><span style={{ color: "var(--accent-1)", fontWeight: 600 }}>"ann"</span>
            <span style={{ opacity: 0.6 }}>·</span>
            <span>{ITEMS.length} of 24</span>
            <span style={{ flex: 1 }}/>
            <Kbd>↑↓</Kbd><Kbd>⏎</Kbd>
          </div>
          {state === "loading" && <Loading/>}
          {state === "empty"   && <Empty/>}
          {state === "ok" && (
            <div style={{ padding: "4px", maxHeight: 312, overflowY: "auto" }}>
              {ITEMS.map((it, i) => (
                <div key={i} onMouseEnter={() => setSel(i)}>
                  <ItemRow item={it} active={i === sel}/>
                </div>
              ))}
            </div>
          )}
        </div>
        {/* Documentation panel — only shown when an item is selected */}
        {showDocs && (
          <div style={{
            width: 296,
            background: "var(--elevated)",
            borderRadius: 9,
            boxShadow: "inset 0 0 0 0.5px var(--border), 0 12px 36px rgba(0,0,0,0.45)",
            backdropFilter: "blur(10px)",
            padding: 12,
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <span style={{
                font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
                color: KIND[ITEMS[sel].kind].color,
              }}>{ITEMS[sel].kind}</span>
              <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-disabled)" }}>
                · CodeEditorAnnotations
              </span>
            </div>
            <div style={{
              marginTop: 6, padding: "6px 8px",
              background: "var(--editor-bg)",
              borderRadius: 5,
              boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
              font: "12px/1.4 var(--font-mono)", color: "var(--editor-fg)",
            }}>
              <Tk.K>public struct</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Sendable</Tk.T>
            </div>
            <div style={{
              marginTop: 8, font: "12px/1.45 var(--font-sans)", color: "var(--text-muted)",
            }}>{ITEMS[sel].doc.body}</div>
            <div style={{
              marginTop: 10, paddingTop: 8,
              borderTop: "0.5px solid var(--border-variant)",
              display: "flex", alignItems: "center", gap: 6,
            }}>
              <button style={cta}>Insert</button>
              <span style={{ flex: 1 }}/>
              <Kbd>F1</Kbd><span style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)" }}>quick help</span>
            </div>
          </div>
        )}
      </div>
    );
  }
  const cta = {
    background: "var(--accent-1)", border: "none", color: "#fff",
    padding: "4px 12px", borderRadius: 5,
    font: "600 11.5px var(--font-sans)", cursor: "pointer",
  };

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [state, setState] = useState("ok");
    const [sel, setSel] = useState(0);
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Annotation.swift" subtitle="CodeEditorCompletion · CompletionViewController"
          right={
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Segmented
                items={[
                  { value: "ok",      label: "Results"  },
                  { value: "loading", label: "Loading"  },
                  { value: "empty",   label: "Empty"    },
                ]}
                value={state}
                onChange={setState}
              />
              <ThemeSwitch theme={theme} setTheme={setTheme}/>
            </div>
          }/>
        <EditorStrip/>
        <Popover state={state} sel={sel} setSel={setSel}/>
        <div style={{
          height: 22, flexShrink: 0,
          display: "flex", alignItems: "center", gap: 12,
          padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>Ln 43, Col 19</span>
          <span>·</span>
          <span>Swift</span>
          <span style={{ flex: 1 }}/>
          <span>fuzzy: <span style={{ color: "var(--text)" }}>OptimizedFuzzyMatcher</span></span>
          <span>debounce: <span style={{ color: "var(--text)" }}>120 ms</span></span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ComA = ComA;
