// SMARTEDITING · CONCEPT A — "MOMENTS"
// All four visible smart-editing moments shown in a single editor view.
//   • Multi-cursor caret stack — N cursors (TextCursor.id) painted on the
//     same column across a vertical run of lines; selection lengths
//     consistent thanks to MultiCursorEditor.handleInput broadcast.
//   • Bracket-pair flash — AutoBracketingEngine just inserted `(` `)`
//     after `init`; the matched closing brace pulses for ~250 ms.
//   • Indent guides — SmartIndentationEngine has computed the indent
//     level for every line; a hover tooltip shows the active level.
//   • Selection-expansion HUD — SmartSelectionExpander hit Word → Line →
//     Scope; the current scope is displayed as a small pill at the
//     bottom of the editor with the next-stop hint.

const SmA = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Kbd } = window;
  const { useState } = React;

  // Source.  The 'cursor' positions are explicit column anchors that the
  // multi-cursor demo paints.  selectionStart/End describe the active
  // SmartSelectionExpander state — currently 'scope', expanded from the
  // word 'kind' up to the enclosing { … } block.
  const LINES = [
    { n: 11, c: <><Tk.K>public struct</Tk.K> <Tk.T>Annotation</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>Sendable</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></>,        depth: 0 },
    { n: 12, c: <>{"    "}<Tk.K>public let</Tk.K> id<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T></>,                                                  depth: 1, cursors: [16] },
    { n: 13, c: <>{"    "}<Tk.K>public let</Tk.K> range<Tk.Pn>:</Tk.Pn> <Tk.T>NSRange</Tk.T></>,                                              depth: 1, cursors: [16] },
    { n: 14, c: <>{"    "}<Tk.K>public let</Tk.K> content<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T></>,                                             depth: 1, cursors: [16] },
    { n: 15, c: <>{"    "}<Tk.K>public let</Tk.K> kind<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationKind</Tk.T><Tk.Pn>?</Tk.Pn></>,                        depth: 1, cursors: [16], scope: { start: 4, end: 41 } },
    { n: 16, c: " ",                                                                                                                          depth: 1 },
    { n: 17, c: <>{"    "}<Tk.K>public init</Tk.K>(range<Tk.Pn>:</Tk.Pn> <Tk.T>NSRange</Tk.T><Tk.Pn>,</Tk.Pn> content<Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T><Tk.Pn>,</Tk.Pn> kind<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationKind</Tk.T><Tk.Pn>?</Tk.Pn>) <Tk.Pn>{"{"}</Tk.Pn></>, depth: 1, flash: 24 },
    { n: 18, c: <>{"        "}<Tk.K>self</Tk.K>.id <Tk.Pn>=</Tk.Pn> <Tk.T>UUID</Tk.T>().<Tk.F>uuidString</Tk.F></>,                            depth: 2 },
    { n: 19, c: <>{"        "}<Tk.K>self</Tk.K>.range <Tk.Pn>=</Tk.Pn> range</>,                                                              depth: 2 },
    { n: 20, c: <>{"        "}<Tk.K>self</Tk.K>.content <Tk.Pn>=</Tk.Pn> content</>,                                                          depth: 2 },
    { n: 21, c: <>{"        "}<Tk.K>self</Tk.K>.kind <Tk.Pn>=</Tk.Pn> kind</>,                                                                depth: 2 },
    { n: 22, c: <>{"    "}<Tk.Pn>{"}"}</Tk.Pn></>,                                                                                            depth: 1 },
    { n: 23, c: <Tk.Pn>{"}"}</Tk.Pn>,                                                                                                          depth: 0 },
  ];

  // Bracket-pair flash for line 17 column 24.  The just-typed `(`
  // matches its auto-inserted `)` 38 columns later.  We render a soft
  // ring around both, with a tiny "pair" tag on the closing one.
  function BracketFlash() {
    return (
      <style>{`
        @keyframes pulse-ring {
          0%   { box-shadow: 0 0 0 0 color-mix(in srgb, var(--accent-1) 70%, transparent); }
          70%  { box-shadow: 0 0 0 6px color-mix(in srgb, var(--accent-1) 0%, transparent); }
          100% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--accent-1) 0%, transparent); }
        }
        .sm-bracket {
          display: inline-block;
          padding: 0 2px;
          border-radius: 3px;
          background: color-mix(in srgb, var(--accent-1) 22%, transparent);
          box-shadow: 0 0 0 0 color-mix(in srgb, var(--accent-1) 70%, transparent);
          animation: pulse-ring 1.4s ease-out infinite;
          color: var(--accent-1);
          font-weight: 700;
        }
        @keyframes blink { 50% { opacity: 0 } }
        .sm-caret {
          display: inline-block;
          width: 2px; height: 14px;
          background: var(--accent-1);
          vertical-align: -2px;
          animation: blink 1s steps(2) infinite;
          box-shadow: 0 0 6px var(--accent-1);
        }
      `}</style>
    );
  }

  // A line with indent guides + cursors + optional bracket flash.
  function CodeLine({ l }) {
    const ind = Array.from({ length: l.depth }).map((_, i) => i);
    const sel = l.scope;
    return (
      <div style={{
        display: "grid", gridTemplateColumns: "44px 1fr",
        alignItems: "center", minHeight: 22,
        position: "relative",
        background: l.cursors ? "color-mix(in srgb, var(--accent-1) 7%, transparent)" : "transparent",
      }}>
        <span style={{
          textAlign: "right", paddingRight: 8,
          font: "12px var(--font-mono)",
          color: l.cursors ? "var(--active-line-num)" : "var(--line-num)",
          fontWeight: l.cursors ? 600 : 400,
        }}>{l.n}</span>
        <div style={{ position: "relative" }}>
          {/* indent guides */}
          {ind.map(i => (
            <div key={i} style={{
              position: "absolute", left: 8 + i * 4 * 7, top: 0, bottom: 0,
              borderLeft: i === 1 ? "1px solid color-mix(in srgb, var(--accent-2) 65%, transparent)"
                : "1px dashed color-mix(in srgb, var(--text-muted) 35%, transparent)",
            }}/>
          ))}
          <code style={{
            position: "relative",
            whiteSpace: "pre", color: "var(--editor-fg)",
            font: "12.5px/1.55 var(--font-mono)",
            paddingRight: 8,
          }}>
            {/* Selection overlay for the scope-expansion HUD */}
            {sel ? (
              <span style={{
                position: "absolute",
                left: sel.start * 7.5, width: (sel.end - sel.start) * 7.5,
                top: 0, bottom: 0,
                background: "color-mix(in srgb, var(--accent-1) 22%, transparent)",
                boxShadow: "inset 0 0 0 0.5px color-mix(in srgb, var(--accent-1) 50%, transparent)",
                borderRadius: 3,
              }}/>
            ) : null}
            <span style={{ position: "relative", zIndex: 1 }}>{l.c}</span>
            {/* Multi-cursor — paint at column 16 (after `public let `) */}
            {l.cursors ? l.cursors.map((col, i) => (
              <span key={i} className="sm-caret" style={{
                position: "absolute", left: col * 7.5 + 4, top: 4, zIndex: 2,
              }}/>
            )) : null}
            {/* Bracket flash — line 17 has both `(` (col 18) and `)` after kind?` */}
            {l.flash ? (
              <>
                <span className="sm-bracket" style={{
                  position: "absolute", top: 0, left: 18 * 7.5, zIndex: 2,
                }}>(</span>
                <span className="sm-bracket" style={{
                  position: "absolute", top: 0, left: l.flash * 6.85 + 220, zIndex: 2,
                }}>)</span>
              </>
            ) : null}
          </code>
        </div>
      </div>
    );
  }

  // Multi-cursor side legend.
  function MultiCursorBadge() {
    return (
      <div style={{
        position: "absolute", top: 80, right: 12, zIndex: 5,
        padding: "8px 12px", borderRadius: 8,
        background: "var(--elevated)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
        width: 232,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{
            width: 18, height: 18, borderRadius: 4,
            background: "color-mix(in srgb, var(--accent-1) 22%, transparent)",
            color: "var(--accent-1)",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}><Ic.Cursor size={11}/></span>
          <span style={{ font: "700 10px var(--font-sans)", letterSpacing: 0.5, textTransform: "uppercase",
            color: "var(--accent-1)" }}>MULTI-CURSOR · 4</span>
          <span style={{ flex: 1 }}/>
          <Kbd>⎋</Kbd>
        </div>
        <div style={{ font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 6, lineHeight: 1.4 }}>
          source: <span style={{ color: "var(--text)" }}>addCursorsAtOccurrences</span><br/>
          term: <span style={{ color: "var(--text)" }}>"let "</span> · L12–L15
        </div>
        <div style={{
          marginTop: 8, paddingTop: 8,
          borderTop: "0.5px solid var(--border-variant)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
          display: "flex", gap: 6, flexWrap: "wrap",
        }}>
          <Kbd>⌃⇧L</Kbd>add at occurrences <Kbd>⌥click</Kbd>add caret
        </div>
      </div>
    );
  }

  // Indent-guide tooltip.
  function IndentTip() {
    return (
      <div style={{
        position: "absolute", left: 92, top: 252, zIndex: 5,
        padding: "5px 9px", borderRadius: 6,
        background: "var(--elevated)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
        font: "11px var(--font-mono)", color: "var(--text-muted)",
        display: "flex", alignItems: "center", gap: 6,
      }}>
        <Ic.Indent size={12}/>
        indent <span style={{ color: "var(--accent-2)", fontWeight: 600 }}>level 2</span>
        · width <span style={{ color: "var(--text)" }}>4 sp</span>
        · spaces
      </div>
    );
  }

  // Selection-expansion HUD — anchored bottom-left of editor.
  function ScopeHUD() {
    return (
      <div style={{
        position: "absolute", left: 14, bottom: 38, zIndex: 5,
        padding: 10, borderRadius: 10,
        background: "var(--elevated)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 8px 20px rgba(0,0,0,0.30)",
        display: "flex", alignItems: "center", gap: 12,
        minWidth: 364,
      }}>
        <div style={{
          width: 28, height: 28, borderRadius: 7,
          background: "color-mix(in srgb, var(--accent-1) 22%, transparent)",
          color: "var(--accent-1)",
          display: "flex", alignItems: "center", justifyContent: "center",
        }}><Ic.Expand size={14}/></div>
        <div style={{ flex: 1 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <span style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
              color: "var(--text-muted)" }}>EXPAND SELECTION</span>
            <Kbd>⌃⇧]</Kbd>
          </div>
          <div style={{
            marginTop: 4, display: "flex", alignItems: "center", gap: 5,
            font: "11.5px var(--font-mono)", color: "var(--text-muted)",
          }}>
            <Pill size="sm">Word</Pill>
            <Ic.ChevR size={10}/>
            <Pill size="sm">Line</Pill>
            <Ic.ChevR size={10}/>
            <Pill size="sm" active>Scope</Pill>
            <Ic.ChevR size={10}/>
            <span style={{ color: "var(--text-disabled)" }}>All</span>
          </div>
        </div>
      </div>
    );
  }

  // Top-right pulse — "auto-bracket inserted" feedback flag.
  function FlashBadge() {
    return (
      <div style={{
        position: "absolute", top: 12, right: 12, zIndex: 5,
        padding: "5px 10px", borderRadius: 999,
        background: "var(--elevated)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
        display: "flex", alignItems: "center", gap: 6,
        font: "11px var(--font-mono)", color: "var(--text-muted)",
      }}>
        <span style={{ width: 8, height: 8, borderRadius: "50%",
          background: "var(--accent-1)",
          boxShadow: "0 0 8px var(--accent-1)",
          animation: "pulse-ring 1.4s ease-out infinite",
        }}/>
        AutoBracketingEngine · paired <span style={{ color: "var(--text)" }}>(</span>·<span style={{ color: "var(--text)" }}>)</span>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Annotation.swift" subtitle="CodeEditorSmartEditing"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{
          height: 28, flexShrink: 0,
          display: "flex", alignItems: "center", gap: 8, padding: "0 12px",
          background: "var(--toolbar)",
          borderBottom: "0.5px solid var(--border-variant)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
        }}>
          <span>SmartEditingEngine attached at phase</span>
          <span style={{ color: "var(--accent-1)", font: "11px var(--font-mono)" }}>.behavior</span>
          <span style={{ flex: 1 }}/>
          <Pill size="sm" active>Bracketing</Pill>
          <Pill size="sm" active>Multi-cursor</Pill>
          <Pill size="sm" active>Indent</Pill>
          <Pill size="sm" active>Expand</Pill>
        </div>
        <div style={{ flex: 1, minHeight: 0, background: "var(--editor-bg)",
          position: "relative", overflow: "hidden", padding: "8px 0" }}>
          <BracketFlash/>
          {LINES.map(l => <CodeLine key={l.n} l={l}/>)}
          <MultiCursorBadge/>
          <IndentTip/>
          <ScopeHUD/>
          <FlashBadge/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>cursors: <span style={{ color: "var(--accent-1)" }}>4</span></span>
          <span>·</span>
          <span>scope: <span style={{ color: "var(--text)" }}>{"{ … }"}</span></span>
          <span>·</span>
          <span>insertSpaces: 4</span>
          <span style={{ flex: 1 }}/>
          <span>delegate phase: .behavior</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.SmA = SmA;
