// SMARTEDITING · CONCEPT C — "CHEAT SHEET"
// Single-page reference.  Every smart-editing keystroke and the editor
// moment it produces, laid out as a grid of small demo tiles.  No
// settings, no live editor — this is the "what does this engine *do*"
// answer in a glance.  Each tile is a self-contained micro-mock of the
// before/after state.  Bottom slab: the underlying types
// (SmartEditingEngine / AutoBracketingEngine / MultiCursorEditor /
// SmartIndentationEngine / SmartSelectionExpander) with their public
// surface so a contributor can match keystroke → component → API.

const SmC = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Kbd, Pill, Overline } = window;
  const { useState } = React;

  function Tile({ title, kbd, accent = "var(--accent-1)", children, hint }) {
    return (
      <div style={{
        padding: 12, borderRadius: 10,
        background: "var(--surface)",
        boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${accent} 32%, transparent)`,
        display: "flex", flexDirection: "column", gap: 6,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{
            font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
            color: accent,
          }}>{title}</span>
          <span style={{ flex: 1 }}/>
          {kbd.map((k, i) => <Kbd key={i} accent={accent}>{k}</Kbd>)}
        </div>
        <div style={{
          padding: 10, borderRadius: 7,
          background: "var(--editor-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          font: "11.5px/1.55 var(--font-mono)", color: "var(--editor-fg)",
          position: "relative",
          minHeight: 78,
        }}>{children}</div>
        {hint ? (
          <div style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)" }}>{hint}</div>
        ) : null}
      </div>
    );
  }

  function Caret({ pulse = true }) {
    return (
      <span style={{
        display: "inline-block", width: 2, height: 13,
        background: "var(--accent-1)",
        boxShadow: "0 0 6px var(--accent-1)",
        verticalAlign: "-2px",
        animation: pulse ? "blink 1s steps(2) infinite" : "none",
      }}/>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <style>{`@keyframes blink { 50% { opacity: 0 } }`}</style>
        <TitleBar title="Smart Editing · Reference" subtitle="CodeEditorSmartEditing"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, minHeight: 0, overflowY: "auto", background: "var(--bg)",
          padding: 14 }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginBottom: 12 }}>
            <span style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>
              Smart Editing
            </span>
            <span style={{ font: "12px var(--font-mono)", color: "var(--text-muted)" }}>
              every visible moment, every keystroke
            </span>
            <span style={{ flex: 1 }}/>
            <Pill size="sm" active>macOS</Pill>
            <Pill size="sm">iPadOS</Pill>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 12 }}>
            <Tile title="AUTO-BRACKETING" kbd={["("]}
              accent="var(--accent-1)"
              hint="AutoBracketingEngine.handleOpeningBracket — paired insertion · caret left between">
              <div>store.<Tk.F>insert</Tk.F>(<span style={{
                background: "color-mix(in srgb, var(--accent-1) 22%, transparent)",
                padding: "0 2px", borderRadius: 3,
              }}>ann</span><Caret/><span style={{ color: "var(--accent-1)", fontWeight: 700 }}>)</span></div>
            </Tile>

            <Tile title="AUTO-CLOSE QUOTE" kbd={['"']}
              accent="var(--syn-string)"
              hint="quotes auto-pair unless next char already matches">
              <div>logger.<Tk.F>info</Tk.F>(<span style={{ color: "var(--syn-string)" }}>{`"hi`}</span><Caret/><span style={{ color: "var(--syn-string)" }}>{`"`}</span>)</div>
            </Tile>

            <Tile title="MULTI-CURSOR · OPTION-CLICK" kbd={["⌥", "click"]}
              accent="var(--accent-1)">
              <div>let id = <Caret pulse={false}/></div>
              <div style={{ marginTop: 2 }}>let range = <Caret/></div>
              <div style={{ marginTop: 2 }}>let content = <Caret pulse={false}/></div>
              <div style={{ marginTop: 2 }}>let kind = <Caret pulse={false}/></div>
            </Tile>

            <Tile title="ADD CURSOR AT OCCURRENCES" kbd={["⌃", "⇧", "L"]}
              accent="var(--syn-keyword)"
              hint="MultiCursorEditor.addCursorsAtOccurrences finds every match of the selection">
              <div>
                <span style={{ background: "color-mix(in srgb, var(--syn-keyword) 24%, transparent)",
                  padding: "0 1px", borderRadius: 2 }}>let</span> a = 1
              </div>
              <div>
                <span style={{ background: "color-mix(in srgb, var(--syn-keyword) 24%, transparent)",
                  padding: "0 1px", borderRadius: 2 }}>let</span> b = 2
              </div>
              <div>
                <span style={{ background: "color-mix(in srgb, var(--syn-keyword) 24%, transparent)",
                  padding: "0 1px", borderRadius: 2 }}>let</span> c = 3
              </div>
            </Tile>

            <Tile title="SMART INDENT ON ENTER" kbd={["⏎"]}
              accent="var(--accent-2)"
              hint="SmartIndentationEngine.calculateIndentation — depth + insertSpacesForTabs honoured">
              <div>{"func body() {"}</div>
              <div>{"    "}<Caret/></div>
              <div style={{
                position: "absolute", left: 8 + 4 * 7, top: 32, bottom: 8,
                borderLeft: "1px dashed color-mix(in srgb, var(--accent-2) 65%, transparent)",
              }}/>
            </Tile>

            <Tile title="DEDENT ON CLOSING BRACE" kbd={["}"]}
              accent="var(--accent-2)"
              hint="auto-removes one indent level so the brace aligns with the opener">
              <div>{"    "}store.<Tk.F>insert</Tk.F>(ann)</div>
              <div><Caret/><span style={{ color: "var(--accent-1)", fontWeight: 700 }}>{"}"}</span></div>
            </Tile>

            <Tile title="EXPAND SELECTION" kbd={["⌃", "⇧", "]"]}
              accent="var(--accent-1)"
              hint="word → line → scope → all  (SmartSelectionExpander.SelectionStop)">
              <div>{"    let "}<span style={{
                background: "color-mix(in srgb, var(--accent-1) 28%, transparent)",
                boxShadow: "inset 0 0 0 0.5px color-mix(in srgb, var(--accent-1) 50%, transparent)",
                padding: "0 2px", borderRadius: 3,
              }}>kind</span>{": AnnotationKind?"}</div>
              <div style={{ marginTop: 4, display: "flex", gap: 4, alignItems: "center" }}>
                <Pill size="sm">word</Pill>
                <Ic.ChevR size={10}/>
                <Pill size="sm">line</Pill>
                <Ic.ChevR size={10}/>
                <Pill size="sm" active>scope</Pill>
              </div>
            </Tile>

            <Tile title="SHRINK SELECTION" kbd={["⌃", "⇧", "["]}
              accent="var(--text-muted)"
              hint="inverse of expand — walks the same ladder back down">
              <div style={{
                background: "color-mix(in srgb, var(--accent-1) 16%, transparent)",
                padding: "2px 4px", borderRadius: 4,
                boxShadow: "inset 0 0 0 0.5px color-mix(in srgb, var(--accent-1) 35%, transparent)",
              }}>
                {"public init(range: NSRange, "}<br/>
                {"            content: String,"}<br/>
                {"            kind: AnnotationKind?)"}
              </div>
            </Tile>
          </div>

          {/* Component map slab */}
          <div style={{
            padding: 12, borderRadius: 10,
            background: "var(--surface)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 8, marginBottom: 8 }}>
              <Overline color="var(--accent-1)">COMPONENTS</Overline>
              <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                SmartEditingEngine delegates each domain to a focused type
              </span>
            </div>
            <div style={{
              display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 8,
            }}>
              {[
                { name: "AutoBracketingEngine",  surf: "handleCharacterInsertion · handleOpeningBracket · handleClosingBracket", c: "var(--accent-1)" },
                { name: "MultiCursorEditor",     surf: "addCursor · addCursorsAtOccurrences · clearAllCursors · handleInput",     c: "var(--accent-1)" },
                { name: "SmartIndentationEngine", surf: "calculateIndentation · defaultRules · AutoIndentRule.IndentAction",       c: "var(--accent-2)" },
                { name: "SmartSelectionExpander", surf: "expandToWord · expandToLine · expandToBrackets",                          c: "var(--accent-1)" },
              ].map(c => (
                <div key={c.name} style={{
                  padding: "8px 10px", borderRadius: 7,
                  background: `color-mix(in srgb, ${c.c} 6%, transparent)`,
                  boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${c.c} 35%, transparent)`,
                }}>
                  <div style={{ font: "600 13px var(--font-mono)", color: c.c }}>{c.name}</div>
                  <div style={{
                    font: "10.5px/1.5 var(--font-mono)", color: "var(--text-muted)", marginTop: 2,
                  }}>{c.surf}</div>
                </div>
              ))}
            </div>
            <div style={{
              marginTop: 10, padding: "8px 10px", borderRadius: 7,
              background: "var(--bg)",
              boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
              display: "flex", alignItems: "center", gap: 10,
              font: "11px var(--font-mono)", color: "var(--text-muted)",
            }}>
              <Ic.Plug size={13}/>
              attaches via <span style={{ color: "var(--text)" }}>textView.addDelegateParticipant(self, phase: .behavior)</span>
              <span style={{ flex: 1 }}/>
              shouldChangeTextIn → host first · engine second
            </div>
          </div>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.SmC = SmC;
