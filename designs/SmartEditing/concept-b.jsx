// SMARTEDITING · CONCEPT B — "WORKBENCH"
// Settings + live preview triptych.  The exact `SmartEditingConfiguration`
// is exposed as a knob list on the left.  The centre is a mini editor
// that responds live to every knob — toggle Multi-Cursor and a second
// caret appears, change Tab Width and indent guides reflow, change the
// SelectionStop list and the HUD updates its breadcrumbs. The right
// pane is the bracket-pair registry — the six SmartEditingBracketPair
// entries the engine ships with, each editable.

const SmB = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Switch, Slider, Stepper, ValueBadge, Pill, Overline, Kbd, Segmented } = window;
  const { useState } = React;

  // Default SmartEditingConfiguration.
  const DEFAULTS = {
    autoInsertBrackets: true,
    autoInsertQuotes:   true,
    wrapSelection:      true,
    enableMultiCursor:  true,
    isAutoIndentEnabled: true,
    insertSpacesForTabs: true,
    tabWidth:           4,
    detectIndentation:  true,
    enableSmartSelection: true,
    expandStops: ["word", "line", "scope", "all"],
    modifier: "option",
  };
  const STOPS = ["word", "line", "scope", "all"];

  const BRACKETS = [
    { open: "(", close: ")", isQuote: false },
    { open: "[", close: "]", isQuote: false },
    { open: "{", close: "}", isQuote: false },
    { open: '"', close: '"', isQuote: true  },
    { open: "'", close: "'", isQuote: true  },
    { open: "`", close: "`", isQuote: true  },
  ];

  function KnobRow({ label, hint, children }) {
    return (
      <div style={{ display: "flex", alignItems: "center", gap: 10,
        padding: "8px 14px", minHeight: 32 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: "500 12.5px var(--font-sans)", color: "var(--text)" }}>{label}</div>
          {hint ? <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>{hint}</div> : null}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>{children}</div>
      </div>
    );
  }

  function Group({ title, count, children }) {
    return (
      <div style={{
        margin: "0 12px 12px",
        background: "var(--surface)",
        borderRadius: 10,
        boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        overflow: "hidden",
      }}>
        <div style={{
          padding: "7px 14px",
          background: "color-mix(in srgb, var(--accent-1) 4%, transparent)",
          borderBottom: "0.5px solid var(--border-variant)",
          display: "flex", alignItems: "baseline", gap: 8,
        }}>
          <Overline>{title}</Overline>
          <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-disabled)" }}>{count}</span>
        </div>
        <div>{React.Children.map(children, (c, i) => (
          <React.Fragment key={i}>
            {i > 0 && <div style={{ height: 0.5, background: "var(--border-variant)", margin: "0 14px" }}/>}
            {c}
          </React.Fragment>
        ))}</div>
      </div>
    );
  }

  function KnobColumn({ cfg, setCfg }) {
    const set = (k, v) => setCfg(s => ({ ...s, [k]: v }));
    return (
      <div style={{
        width: 280, flexShrink: 0,
        background: "var(--bg)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
        overflowY: "auto",
      }}>
        <div style={{ padding: "12px 14px" }}>
          <div style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>
            Smart Editing
          </div>
          <div style={{ font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 4 }}>
            SmartEditingConfiguration · live preview →
          </div>
        </div>

        <Group title="AUTO-BRACKETING" count="3">
          <KnobRow label="Auto-insert brackets" hint="( ) [ ] { }">
            <Switch on={cfg.autoInsertBrackets} onClick={() => set("autoInsertBrackets", !cfg.autoInsertBrackets)}/>
          </KnobRow>
          <KnobRow label="Auto-insert quotes" hint='" " ′ ′ ` `'>
            <Switch on={cfg.autoInsertQuotes} onClick={() => set("autoInsertQuotes", !cfg.autoInsertQuotes)}/>
          </KnobRow>
          <KnobRow label="Wrap selection" hint="surround selected text">
            <Switch on={cfg.wrapSelection} onClick={() => set("wrapSelection", !cfg.wrapSelection)}/>
          </KnobRow>
        </Group>

        <Group title="MULTI-CURSOR" count="2">
          <KnobRow label="Enable multi-cursor">
            <Switch on={cfg.enableMultiCursor} onClick={() => set("enableMultiCursor", !cfg.enableMultiCursor)}/>
          </KnobRow>
          <KnobRow label="Modifier" hint="held for ⌥click + caret">
            <Segmented items={[
              { value: "option",  label: "⌥ Option" },
              { value: "control", label: "⌃ Ctrl"   },
            ]} value={cfg.modifier} onChange={v => set("modifier", v)}/>
          </KnobRow>
        </Group>

        <Group title="INDENTATION" count="4">
          <KnobRow label="Smart indent on Enter">
            <Switch on={cfg.isAutoIndentEnabled} onClick={() => set("isAutoIndentEnabled", !cfg.isAutoIndentEnabled)}/>
          </KnobRow>
          <KnobRow label="Insert spaces for tabs">
            <Switch on={cfg.insertSpacesForTabs} onClick={() => set("insertSpacesForTabs", !cfg.insertSpacesForTabs)}/>
          </KnobRow>
          <KnobRow label="Tab width">
            <Stepper value={cfg.tabWidth} unit="sp"
              onMinus={() => set("tabWidth", Math.max(1, cfg.tabWidth - 1))}
              onPlus={() =>  set("tabWidth", Math.min(8, cfg.tabWidth + 1))}/>
          </KnobRow>
          <KnobRow label="Detect indentation" hint="from existing content">
            <Switch on={cfg.detectIndentation} onClick={() => set("detectIndentation", !cfg.detectIndentation)}/>
          </KnobRow>
        </Group>

        <Group title="SELECTION EXPANSION" count="2">
          <KnobRow label="Enable expand-selection">
            <Switch on={cfg.enableSmartSelection} onClick={() => set("enableSmartSelection", !cfg.enableSmartSelection)}/>
          </KnobRow>
          <KnobRow label="Stops" hint="ordered expansion ladder">
            <div style={{ display: "flex", gap: 3 }}>
              {STOPS.map(s => (
                <Pill key={s} size="sm" active={cfg.expandStops.includes(s)}
                  onClick={() => set("expandStops",
                    cfg.expandStops.includes(s)
                      ? cfg.expandStops.filter(x => x !== s)
                      : [...cfg.expandStops, s])}>
                  {s}
                </Pill>
              ))}
            </div>
          </KnobRow>
        </Group>
      </div>
    );
  }

  function Preview({ cfg, brackets }) {
    // Live preview lines.  Re-render as cfg changes.
    const indent = (n) => cfg.insertSpacesForTabs ? " ".repeat(cfg.tabWidth * n) : "\t".repeat(n);
    const LINES = [
      { n: 41, c: <><Tk.K>func</Tk.K> <Tk.F>register</Tk.F>(<Tk.V>_</Tk.V> store<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationStore</Tk.T>) <Tk.Pn>{"{"}</Tk.Pn></>, depth: 0 },
      { n: 42, c: <>{indent(1)}store.<Tk.F>removeAll</Tk.F>()</>,            depth: 1, cursors: cfg.enableMultiCursor ? [4 + cfg.tabWidth] : [] },
      { n: 43, c: <>{indent(1)}<Tk.K>let</Tk.K> ann <Tk.Pn>=</Tk.Pn> <Tk.T>Annotation</Tk.T>(<Tk.V>range</Tk.V>: r, kind: .warning)</>, depth: 1, flash: cfg.autoInsertBrackets, cursors: cfg.enableMultiCursor ? [4 + cfg.tabWidth] : [] },
      { n: 44, c: <>{indent(1)}store.<Tk.F>insert</Tk.F>(ann)</>,            depth: 1, cursors: cfg.enableMultiCursor ? [4 + cfg.tabWidth] : [] },
      { n: 45, c: <Tk.Pn>{"}"}</Tk.Pn>,                                       depth: 0 },
    ];
    return (
      <div style={{
        flex: 1, minWidth: 0, minHeight: 0, position: "relative",
        background: "var(--editor-bg)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{
          height: 28, flexShrink: 0,
          display: "flex", alignItems: "center", gap: 6, padding: "0 12px",
          borderBottom: "0.5px solid var(--border-variant)",
          background: "var(--toolbar)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
        }}>
          <span style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--status-success)",
            boxShadow: "0 0 6px var(--status-success)" }}/>
          LIVE PREVIEW
          <span style={{ flex: 1 }}/>
          <span style={{ font: "11px var(--font-mono)" }}>Annotation.swift · L41</span>
        </div>
        <div style={{ flex: 1, padding: "12px 0", position: "relative", overflow: "hidden" }}>
          {LINES.map((l) => (
            <div key={l.n} style={{
              display: "grid", gridTemplateColumns: "44px 1fr",
              alignItems: "center", minHeight: 22,
              background: l.cursors?.length ? "color-mix(in srgb, var(--accent-1) 7%, transparent)" : "transparent",
              position: "relative",
            }}>
              <span style={{
                textAlign: "right", paddingRight: 8,
                font: "12px var(--font-mono)",
                color: l.cursors?.length ? "var(--active-line-num)" : "var(--line-num)",
              }}>{l.n}</span>
              <div style={{ position: "relative" }}>
                {Array.from({ length: l.depth }).map((_, i) => (
                  <div key={i} style={{
                    position: "absolute", left: 8 + i * cfg.tabWidth * 7, top: 0, bottom: 0,
                    borderLeft: "1px dashed color-mix(in srgb, var(--accent-2) 50%, transparent)",
                  }}/>
                ))}
                <code style={{
                  position: "relative",
                  whiteSpace: "pre", color: "var(--editor-fg)",
                  font: "12.5px/1.55 var(--font-mono)", paddingRight: 8,
                }}>{l.c}
                  {l.cursors?.length ? l.cursors.map((col, i) => (
                    <span key={i} style={{
                      display: "inline-block", position: "absolute",
                      left: col * 7.5 + 4, top: 4,
                      width: 2, height: 14, background: "var(--accent-1)",
                      animation: "blink 1s steps(2) infinite",
                    }}/>
                  )) : null}
                </code>
              </div>
            </div>
          ))}
          <style>{`@keyframes blink { 50% { opacity: 0 } }`}</style>

          {/* HUD reflects the cfg.expandStops list */}
          {cfg.enableSmartSelection && (
            <div style={{
              position: "absolute", left: 14, bottom: 14,
              padding: "6px 10px", borderRadius: 8,
              background: "var(--elevated)",
              boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
              display: "flex", alignItems: "center", gap: 6,
              font: "11px var(--font-mono)", color: "var(--text-muted)",
            }}>
              <Ic.Expand size={12}/>
              EXPAND
              {cfg.expandStops.map((s, i) => (
                <React.Fragment key={s}>
                  {i > 0 ? <Ic.ChevR size={10}/> : null}
                  <span style={{
                    padding: "1px 6px", borderRadius: 4,
                    background: "color-mix(in srgb, var(--accent-1) 14%, transparent)",
                    color: "var(--accent-1)",
                    font: "10px var(--font-sans)", textTransform: "uppercase", letterSpacing: 0.4,
                  }}>{s}</span>
                </React.Fragment>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  function BracketRegistry() {
    return (
      <div style={{
        width: 218, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px 6px",
          display: "flex", alignItems: "center", gap: 6 }}>
          <Overline>BRACKET PAIRS</Overline>
          <span style={{ flex: 1 }}/>
          <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-disabled)" }}>{BRACKETS.length}</span>
        </div>
        <div style={{ padding: "0 6px", display: "flex", flexDirection: "column", gap: 2 }}>
          {BRACKETS.map((b, i) => (
            <div key={i} style={{
              display: "grid", gridTemplateColumns: "36px 36px 1fr 16px", gap: 4, alignItems: "center",
              padding: "6px 8px", borderRadius: 6,
              background: "var(--element-bg)",
              boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
            }}>
              <span style={{
                textAlign: "center", font: "600 13px var(--font-mono)",
                color: "var(--accent-1)",
                padding: "1px 0", borderRadius: 4,
                background: "color-mix(in srgb, var(--accent-1) 14%, transparent)",
              }}>{b.open}</span>
              <span style={{
                textAlign: "center", font: "600 13px var(--font-mono)",
                color: "var(--accent-1)",
                padding: "1px 0", borderRadius: 4,
                background: "color-mix(in srgb, var(--accent-1) 14%, transparent)",
              }}>{b.close}</span>
              <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                {b.isQuote ? "quote" : "bracket"}
              </span>
              <button style={{
                background: "transparent", border: "none", cursor: "pointer",
                color: "var(--text-muted)", padding: 0, width: 16, height: 16,
              }}><Ic.X size={11}/></button>
            </div>
          ))}
          <button style={{
            margin: "6px 2px 0", height: 26, borderRadius: 6,
            background: "transparent",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
            color: "var(--text)", border: "none", cursor: "pointer",
            font: "500 11px var(--font-sans)",
            display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
          }}>
            <Ic.Plus size={11}/> Add pair
          </button>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{
          margin: 8, padding: 10, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        }}>
          <Overline>KEYS</Overline>
          <div style={{ marginTop: 6, font: "11px var(--font-sans)", color: "var(--text-muted)",
            display: "grid", gridTemplateColumns: "auto 1fr", rowGap: 4, columnGap: 6 }}>
            <Kbd>⌥click</Kbd><span>add cursor</span>
            <Kbd>⌃⇧L</Kbd><span>cursor at every match</span>
            <Kbd>⎋</Kbd><span>clearAllCursors</span>
            <Kbd>⌃⇧]</Kbd><span>expand selection</span>
            <Kbd>⌃⇧[</Kbd><span>shrink selection</span>
          </div>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [cfg, setCfg] = useState(DEFAULTS);
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Smart Editing" subtitle="CodeEditorSmartEditing · live preview"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <KnobColumn cfg={cfg} setCfg={setCfg}/>
          <Preview cfg={cfg}/>
          <BracketRegistry/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>engine: SmartEditingEngine @ <span style={{ color: "var(--text)" }}>.behavior</span></span>
          <span>·</span>
          <span>spaces: {cfg.insertSpacesForTabs ? cfg.tabWidth : "TAB"}</span>
          <span style={{ flex: 1 }}/>
          <span>preview reflects current configuration</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.SmB = SmB;
