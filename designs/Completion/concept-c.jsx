// COMPLETION · CONCEPT C — "COMMAND DECK"
// A full-screen palette in the Raycast tradition.  Triggered by ⌘⇧Space
// (or programmatically by CompletionManager.requestCompletion when the
// host opts in).  The popover model is dropped: completion takes over
// the window briefly, then collapses on commit/dismiss.
//   • One giant search row at the top, prefix shown verbatim.
//   • Two-column body: full-bleed result list left, generous detail right.
//   • Result rows are tall: kind icon, fuzzy-highlighted name, signature,
//     keyboard hint to insert.  No score badges — the order is the score.
//   • Detail pane shows full documentation, signature, examples.
//   • Footer is the keymap.  ↑↓ navigate, ⏎ insert, ⌘⏎ insert + move,
//     ⌥⏎ apply snippet, ⎋ close.

const ComC = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Kbd, Pill } = window;
  const { useState } = React;

  const KIND = {
    type:     { letter: "T",  label: "Type",     color: "var(--syn-type)" },
    method:   { letter: "ƒ",  label: "Method",   color: "var(--syn-function)" },
    function: { letter: "ƒ",  label: "Function", color: "var(--syn-function)" },
    property: { letter: "p",  label: "Property", color: "var(--syn-property)" },
    variable: { letter: "v",  label: "Variable", color: "var(--syn-variable)" },
    keyword:  { letter: "K",  label: "Keyword",  color: "var(--syn-keyword)" },
    snippet:  { letter: "{}", label: "Snippet",  color: "var(--accent-2)" },
  };

  const ITEMS = [
    { text: "Annotation",            kind: "type",     detail: "struct, Sendable",                            provider: "LSP",      ranges: [[0,3]],
      sig: "public struct Annotation: Sendable",
      doc: "Represents an inline annotation in the code editor. Annotations are visual markers that appear inline with code to highlight TODOs, warnings, errors, or custom notes.",
      ex: "let ann = Annotation(\n  range: NSRange(location: 100, length: 4),\n  content: \"TODO: error handling\",\n  kind: .todo\n)" },
    { text: "AnnotationKind",        kind: "type",     detail: "enum : RawRepresentable<String>",             provider: "LSP",      ranges: [[0,3]],
      sig: "public enum AnnotationKind: String, CaseIterable, Sendable",
      doc: "Unified annotation type enumeration with associated display properties. Cases: info, note, todo, fixme, warning, error.",
      ex: ".info | .note | .todo | .fixme\n.warning | .error" },
    { text: "AnnotationView",        kind: "type",     detail: "class : PlatformView",                        provider: "LSP",      ranges: [[0,3]],
      sig: "public class AnnotationView: PlatformView, AnnotationViewProtocol",
      doc: "Cross-platform view for displaying annotation badges with hover/tap popups.",
      ex: "let v = AnnotationView(annotation: ann, frame: r)\nv.apply(theme: store.theme)" },
    { text: "areAnnotationsEnabled", kind: "property", detail: "var areAnnotationsEnabled: Bool",             provider: "LSP",      ranges: [[3,5],[5,6]],
      sig: "public var areAnnotationsEnabled: Bool { get set }",
      doc: "Whether the editor renders annotation badges. Bound via the Display settings tab.",
      ex: "editor.areAnnotationsEnabled = true" },
    { text: "addAnnotation(_:)",     kind: "method",   detail: "(Annotation) -> Void",                        provider: "LSP",      ranges: [[0,1],[3,6]],
      sig: "public func addAnnotation(_ annotation: Annotation)",
      doc: "Adds an annotation to the receiver. The badge view is instantiated lazily on first layout.",
      ex: "editor.addAnnotation(ann)" },
    { text: "annotations",           kind: "property", detail: "var annotations: [Annotation]",               provider: "LSP",      ranges: [[0,3]],
      sig: "public var annotations: [Annotation] { get set }",
      doc: "Snapshot of every annotation attached to the editor. Mutating this property is equivalent to remove-all + add.",
      ex: "editor.annotations = []" },
    { text: "annotate",              kind: "snippet",  detail: "Annotate selected expression",                provider: "Snippets", ranges: [[0,3]],
      sig: "$1: AnnotationKind\nlet annotation = Annotation(range: $0, content: $2, kind: $1)",
      doc: "Wraps the current selection in an Annotation literal. Tab stops at kind → message → range." },
    { text: "annotation",            kind: "keyword",  detail: "Swift attribute",                              provider: "Keywords", ranges: [[0,3]],
      sig: "@<attribute>",
      doc: "Swift built-in attribute. Surfaced by LanguageKeywordCompletionProvider." },
  ];

  function MatchText({ text, ranges, big }) {
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
          color: p.m ? "var(--accent-1)" : "var(--text)",
          fontWeight: p.m ? 700 : 500,
        }}>{p.s}</span>
      ))}</span>
    );
  }

  function SearchRow() {
    return (
      <div style={{
        padding: "16px 22px 12px",
        background: "var(--title-bar)",
        borderBottom: "0.5px solid var(--border-variant)",
        display: "flex", alignItems: "center", gap: 14,
      }}>
        <span style={{
          width: 30, height: 30, borderRadius: "50%",
          display: "flex", alignItems: "center", justifyContent: "center",
          background: "color-mix(in srgb, var(--accent-1) 16%, transparent)",
          color: "var(--accent-1)",
        }}><Ic.Sparkles size={15}/></span>
        <div style={{ flex: 1, display: "flex", alignItems: "baseline", gap: 0 }}>
          <span style={{
            font: "300 28px var(--font-display)", letterSpacing: -0.5,
            color: "var(--text-muted)",
          }}>ann</span>
          <span style={{
            display: "inline-block", width: 3, height: 28, marginLeft: 4,
            background: "var(--accent-1)",
            animation: "blink 1s steps(2) infinite",
            transform: "translateY(4px)",
          }}/>
        </div>
        <span style={{
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
          padding: "3px 8px", borderRadius: 4,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        }}>completion mode · Annotation.swift:43</span>
        <Kbd>⎋</Kbd>
        <style>{`@keyframes blink { 50% { opacity: 0 } }`}</style>
      </div>
    );
  }

  function ResultRow({ item, active, onClick }) {
    const k = KIND[item.kind];
    return (
      <div onClick={onClick} style={{
        display: "grid",
        gridTemplateColumns: "32px 1fr auto",
        alignItems: "center", gap: 12,
        padding: "10px 16px",
        cursor: "pointer",
        background: active ? "color-mix(in srgb, var(--accent-1) 14%, transparent)" : "transparent",
        boxShadow: active ? "inset 4px 0 0 0 var(--accent-1)" : "none",
      }}>
        <span style={{
          width: 28, height: 28, borderRadius: 6,
          background: `color-mix(in srgb, ${k.color} 22%, transparent)`,
          color: k.color, fontWeight: 700,
          display: "flex", alignItems: "center", justifyContent: "center",
          font: "13px var(--font-mono)",
        }}>{k.letter}</span>
        <div style={{ minWidth: 0 }}>
          <code style={{
            font: "15px var(--font-mono)", display: "block",
            whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
          }}>
            <MatchText text={item.text} ranges={item.ranges}/>
          </code>
          <code style={{
            font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 1,
            display: "block", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
          }}>{item.detail}</code>
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 3 }}>
          <span style={{
            font: "600 9.5px var(--font-sans)", letterSpacing: 0.5, textTransform: "uppercase",
            color: "var(--text-muted)",
          }}>{k.label}</span>
          <span style={{
            font: "10px var(--font-mono)", color: "var(--text-disabled)",
            padding: "1px 5px", borderRadius: 3,
            background: "var(--element-bg)",
          }}>{item.provider}</span>
        </div>
      </div>
    );
  }

  function Results({ sel, setSel }) {
    return (
      <div style={{
        flex: 1, minWidth: 0,
        background: "var(--bg)",
        overflowY: "auto",
      }}>
        <div style={{
          padding: "10px 16px",
          font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
          color: "var(--text-muted)",
        }}>BEST MATCH</div>
        {ITEMS.slice(0, 1).map((it, i) => (
          <ResultRow key={i} item={it} active={sel === i} onClick={() => setSel(i)}/>
        ))}
        <div style={{
          padding: "10px 16px",
          font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
          color: "var(--text-muted)",
        }}>SYMBOLS · {ITEMS.length - 1}</div>
        {ITEMS.slice(1).map((it, i) => (
          <ResultRow key={i + 1} item={it} active={sel === i + 1} onClick={() => setSel(i + 1)}/>
        ))}
      </div>
    );
  }

  function Detail({ item }) {
    const k = KIND[item.kind];
    return (
      <div style={{
        width: 348, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "18px 18px 12px",
          borderBottom: "0.5px solid var(--border-variant)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <span style={{
              font: "700 9.5px var(--font-sans)", letterSpacing: 0.7, textTransform: "uppercase",
              color: k.color,
            }}>{k.label}</span>
            <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>· {item.provider}</span>
          </div>
          <div style={{
            font: "700 22px/1.1 var(--font-mono)",
            color: "var(--text)", marginTop: 8, letterSpacing: -0.2, wordBreak: "break-word",
          }}>{item.text}</div>
        </div>
        <div style={{ flex: 1, minHeight: 0, overflowY: "auto" }}>
          <div style={{ padding: "12px 18px" }}>
            <div style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
              color: "var(--text-muted)", marginBottom: 6 }}>SIGNATURE</div>
            <div style={{
              padding: "8px 10px", borderRadius: 6,
              background: "var(--editor-bg)",
              boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
              font: "12px/1.45 var(--font-mono)", color: "var(--editor-fg)",
              whiteSpace: "pre-wrap",
            }}>{item.sig}</div>
          </div>
          <div style={{ padding: "0 18px 12px" }}>
            <div style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
              color: "var(--text-muted)", marginBottom: 6 }}>DOCUMENTATION</div>
            <div style={{ font: "12.5px/1.5 var(--font-sans)", color: "var(--text)" }}>{item.doc}</div>
          </div>
          {item.ex ? (
            <div style={{ padding: "0 18px 16px" }}>
              <div style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
                color: "var(--text-muted)", marginBottom: 6 }}>EXAMPLE</div>
              <div style={{
                padding: "8px 10px", borderRadius: 6,
                background: "var(--editor-bg)",
                boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
                font: "12px/1.5 var(--font-mono)", color: "var(--editor-fg)",
                whiteSpace: "pre-wrap",
              }}>{item.ex}</div>
            </div>
          ) : null}
        </div>
        <div style={{
          padding: 12, borderTop: "0.5px solid var(--border-variant)",
          display: "flex", alignItems: "center", gap: 8,
        }}>
          <button style={{
            flex: 1,
            background: "var(--accent-1)", border: "none", color: "#fff",
            height: 32, borderRadius: 6,
            font: "600 12px var(--font-sans)", cursor: "pointer",
          }}>Insert <span style={{ opacity: 0.7, marginLeft: 4 }}>⏎</span></button>
          <button style={{
            background: "transparent", border: "none",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
            color: "var(--text)", height: 32, padding: "0 12px", borderRadius: 6,
            font: "500 12px var(--font-sans)", cursor: "pointer",
          }}>Insert + Newline <span style={{ opacity: 0.7, marginLeft: 4 }}>⌘⏎</span></button>
        </div>
      </div>
    );
  }

  function Footer() {
    return (
      <div style={{
        height: 32, flexShrink: 0,
        display: "flex", alignItems: "center", gap: 14, padding: "0 18px",
        background: "var(--status-bar)",
        borderTop: "0.5px solid var(--border-variant)",
        font: "11px var(--font-sans)", color: "var(--text-muted)",
      }}>
        <span style={{ display: "flex", alignItems: "center", gap: 4 }}><Kbd>↑↓</Kbd>navigate</span>
        <span style={{ display: "flex", alignItems: "center", gap: 4 }}><Kbd>⏎</Kbd>insert</span>
        <span style={{ display: "flex", alignItems: "center", gap: 4 }}><Kbd>⌥⏎</Kbd>apply snippet</span>
        <span style={{ display: "flex", alignItems: "center", gap: 4 }}><Kbd>F1</Kbd>quick help</span>
        <span style={{ flex: 1 }}/>
        <span>filter: <span style={{ color: "var(--text)", font: "11px var(--font-mono)" }}>kind:type</span></span>
        <Pill size="sm">Toggle providers</Pill>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [sel, setSel] = useState(0);
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Completion" subtitle="Command Deck"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <SearchRow/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <Results sel={sel} setSel={setSel}/>
          <Detail item={ITEMS[sel] || ITEMS[0]}/>
        </div>
        <Footer/>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ComC = ComC;
