// CONCEPT B — "TRIPTYCH"
// Three columns: category rail | knob cards | live editor preview slab.
// The preview is the star: a mini-editor reflecting every Display knob
// in real time (font size, line numbers, minimap, folding, selected-line
// highlight color, annotations, invisibles).
// Top bar runs a single search across ALL knobs and exposes the 8 presets
// as horizontal chips.

const ConB = (() => {
  const { Ic, WindowFrame, TitleBar, CATS, PRESETS, DISPLAY_STATE: S, MODIFIED_KEYS, Switch, Slider, ValueBadge, Stepper, ColorChip, ModDot } = window;

  const ACC = "var(--accent-1)";

  // --- Left: compact category rail ------------------------------------------
  function Rail() {
    return (
      <div style={{
        width: 56, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
        padding: "10px 0",
        gap: 2,
      }}>
        {CATS.map(c => {
          const active = c.id === "display";
          return (
            <div key={c.id} title={c.label} style={{
              position: "relative",
              display: "flex", alignItems: "center", justifyContent: "center",
              height: 40, margin: "0 8px",
              borderRadius: 8,
              background: active ? "var(--element-selected)" : "transparent",
              color: active ? c.accent : "var(--icon-muted)",
              cursor: "pointer",
            }}>
              {active && <div style={{
                position: "absolute", left: -8, top: 8, bottom: 8, width: 3,
                background: c.accent, borderRadius: 2,
              }}/>}
              {React.cloneElement(c.icon, { size: 18 })}
            </div>
          );
        })}
        <div style={{ flex: 1 }}/>
        <div style={{
          margin: "0 8px",
          height: 40,
          display: "flex", alignItems: "center", justifyContent: "center",
          borderRadius: 8, color: "var(--icon-muted)",
          border: "0.5px dashed var(--border-variant)",
        }}>
          <Ic.Rotate size={14}/>
        </div>
      </div>
    );
  }

  // --- Top bar: search + preset chips ---------------------------------------
  function TopBar() {
    return (
      <div style={{
        padding: "12px 16px 10px",
        background: "var(--surface)",
        borderBottom: "0.5px solid var(--border-variant)",
      }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 8,
          height: 30, padding: "0 12px",
          borderRadius: 8,
          background: "var(--element-bg)",
          border: "0.5px solid var(--border-variant)",
        }}>
          <span style={{ color: "var(--icon-muted)" }}><Ic.Search size={14}/></span>
          <input placeholder="Search all 73 settings — try “tab”, “debounce”, “minimap”…" readOnly style={{
            flex: 1, background: "transparent", border: "none", outline: "none",
            color: "var(--text-placeholder)",
            font: "12.5px var(--font-sans)",
          }}/>
          <span style={{
            font: "500 10px var(--font-mono)", color: "var(--text-muted)",
            padding: "1px 5px", borderRadius: 4, background: "var(--element-active)",
          }}>⌘F</span>
        </div>
        <div style={{
          marginTop: 10, display: "flex", alignItems: "center", gap: 6,
          flexWrap: "wrap",
        }}>
          <span style={{
            font: "700 9.5px var(--font-sans)",
            letterSpacing: "0.6px", textTransform: "uppercase",
            color: "var(--text-muted)",
            marginRight: 2,
          }}>PRESETS</span>
          {PRESETS.map((p, i) => {
            const active = p === "Default";
            return (
              <span key={p} style={{
                display: "inline-flex", alignItems: "center", gap: 5,
                height: 22, padding: "0 9px",
                borderRadius: 11,
                background: active ? "color-mix(in srgb, var(--accent-1) 18%, transparent)" : "var(--element-bg)",
                border: active ? `0.5px solid ${ACC}` : "0.5px solid var(--border-variant)",
                color: active ? ACC : "var(--text)",
                font: `${active?600:500} 11px var(--font-sans)`,
                cursor: "pointer",
              }}>
                {active && <Ic.Check size={9}/>}
                {p}
              </span>
            );
          })}
        </div>
      </div>
    );
  }

  // --- Center: knob list cards ----------------------------------------------
  function Row({ label, hint, modified, children }) {
    return (
      <div style={{
        display: "flex", alignItems: "center", gap: 10,
        padding: "8px 12px",
        background: modified ? "color-mix(in srgb, var(--accent-1) 5%, transparent)" : "transparent",
        borderRadius: 6,
        position: "relative",
      }}>
        {modified && <div style={{
          position: "absolute", left: -2, top: 6, bottom: 6, width: 2,
          background: ACC, borderRadius: 1,
        }}/>}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            display: "flex", alignItems: "center", gap: 6,
            font: "500 12px var(--font-sans)", color: "var(--text)",
          }}>
            {label}
            {modified && <ModDot accent={ACC}/>}
          </div>
          {hint && <div style={{ font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 1 }}>{hint}</div>}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>{children}</div>
      </div>
    );
  }

  function Card({ title, count, children }) {
    return (
      <div style={{
        margin: "10px 12px",
        background: "var(--surface)",
        border: "0.5px solid var(--border-variant)",
        borderRadius: 10,
        padding: "8px 4px 6px",
      }}>
        <div style={{
          padding: "2px 12px 6px",
          display: "flex", alignItems: "baseline", gap: 8,
        }}>
          <span style={{
            font: "700 10px var(--font-sans)",
            letterSpacing: "0.6px", textTransform: "uppercase",
            color: "var(--text-muted)",
          }}>{title}</span>
          <span style={{ font: "10px var(--font-mono)", color: "var(--text-disabled)" }}>{count}</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
          {children}
        </div>
      </div>
    );
  }

  function Center() {
    return (
      <div style={{
        flex: 1, minWidth: 0,
        background: "var(--bg)",
        overflowY: "auto",
        display: "flex", flexDirection: "column",
      }}>
        <Card title="Typography" count={1}>
          <Row label="Font size" hint="9–32 pt" modified>
            <div style={{ width: 130 }}><Slider pct={(S.fontSize-9)/(32-9)} accent={ACC}/></div>
            <ValueBadge value={S.fontSize} unit="pt" accent={ACC}/>
          </Row>
        </Card>
        <Card title="Highlighting" count={7}>
          <Row label="Syntax highlighting"><Switch on={S.isSyntaxHighlightingEnabled}/></Row>
          <Row label="Line numbers"><Switch on={S.isLineNumbersEnabled}/></Row>
          <Row label="Annotations"><Switch on={S.areAnnotationsEnabled}/></Row>
          <Row label="Highlight selected line"><Switch on={S.isSelectedLineHighlighted}/></Row>
          <Row label="Selected-line color"><ColorChip value={S.selectedLineHighlightColor}/></Row>
          <Row label="Invisibles"><Switch on={S.areInvisibleCharactersVisible}/></Row>
          <Row label="Range-store highlighting" hint="Experimental" modified><Switch on={S.useRangeStoreHighlighting}/></Row>
        </Card>
        <Card title="Code Folding" count={3}>
          <Row label="Enable folding"><Switch on={S.isCodeFoldingEnabled}/></Row>
          <Row label="Folding controls"><Switch on={S.areFoldingControlsVisible}/></Row>
          <Row label="Min foldable lines" modified><Stepper value={S.minimumFoldableLines}/></Row>
        </Card>
        <Card title="Minimap & Viewport" count={2}>
          <Row label="Show minimap"><Switch on={S.isMinimapVisible}/></Row>
          <Row label="Visible lines"><Stepper value={S.visibleLines}/></Row>
        </Card>
      </div>
    );
  }

  // --- Right: live preview slab ---------------------------------------------
  function Preview() {
    const lines = [
      { n: 1,  active: false, content: <><span style={{color:"var(--syn-keyword)", fontWeight:600}}>import</span> SwiftUI</> },
      { n: 2,  active: false, content: "" },
      { n: 3,  active: false, content: <><span style={{color:"var(--syn-comment)", fontStyle:"italic"}}>// TODO: animate on appear</span></>, annotation: "TODO" },
      { n: 4,  active: false, content: <><span style={{color:"var(--syn-keyword)", fontWeight:600}}>struct</span> <span style={{color:"var(--syn-type)", fontWeight:600}}>EditorView</span>: <span style={{color:"var(--syn-type)"}}>View</span> {"{"}</> },
      { n: 5,  active: false, content: <>{"  "}<span style={{color:"var(--syn-keyword)", fontWeight:600}}>var</span> body: <span style={{color:"var(--syn-type)"}}>some</span> <span style={{color:"var(--syn-type)"}}>View</span> {"{"}</> },
      { n: 6,  active: false, content: <>{"    "}<span style={{color:"var(--syn-type)"}}>CodeEditor</span>(text: $text)</> },
      { n: 7,  active: true,  content: <>{"      "}.<span style={{color:"var(--syn-function)", fontWeight:600}}>fontSize</span>(<span style={{color:"var(--syn-number)"}}>{S.fontSize}</span>)</> },
      { n: 8,  active: false, content: <>{"      "}.<span style={{color:"var(--syn-function)", fontWeight:600}}>syntaxHighlighting</span>(<span style={{color:"var(--syn-keyword)"}}>true</span>)</>, folded: false },
      { n: 9,  active: false, content: <>{"  "}{"}"}</> },
      { n: 10, active: false, content: "}" },
    ];
    return (
      <div style={{
        width: 312, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
        padding: "10px",
      }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 6,
          font: "700 10px var(--font-sans)",
          letterSpacing: "0.6px", textTransform: "uppercase",
          color: "var(--text-muted)",
          padding: "0 4px 8px",
        }}>
          <span style={{
            width: 6, height: 6, borderRadius: "50%",
            background: "var(--status-success)",
            boxShadow: "0 0 8px var(--status-success)",
          }}/>
          LIVE PREVIEW
          <span style={{ flex: 1 }}/>
          <span style={{ color: "var(--text-disabled)", letterSpacing: 0, textTransform: "none", font: "11px var(--font-mono)" }}>
            EditorView.swift
          </span>
        </div>
        <div style={{
          flex: 1, minHeight: 0,
          background: "var(--editor-bg)",
          border: "0.5px solid var(--border-variant)",
          borderRadius: 8,
          overflow: "hidden",
          display: "flex",
          position: "relative",
        }}>
          <div style={{
            flex: 1, minWidth: 0,
            overflow: "hidden",
            padding: `4px 0`,
          }}>
            {lines.map((line) => (
              <div key={line.n} style={{
                display: "grid",
                gridTemplateColumns: `${S.isLineNumbersEnabled ? "28px" : "0px"} 14px 1fr`,
                alignItems: "center",
                background: line.active && S.isSelectedLineHighlighted
                  ? `color-mix(in srgb, ${S.selectedLineHighlightColor} 14%, transparent)`
                  : "transparent",
                borderLeft: line.active && S.isSelectedLineHighlighted
                  ? `2px solid ${S.selectedLineHighlightColor}`
                  : "2px solid transparent",
                paddingLeft: line.active && S.isSelectedLineHighlighted ? 0 : 0,
                minHeight: S.fontSize * 1.5,
              }}>
                {S.isLineNumbersEnabled && (
                  <span style={{
                    textAlign: "right",
                    padding: "0 8px 0 0",
                    color: line.active ? "var(--active-line-num)" : "var(--line-num)",
                    fontWeight: line.active ? 600 : 400,
                    font: `${Math.max(9, S.fontSize - 3)}px var(--font-mono)`,
                    userSelect: "none",
                  }}>{line.n}</span>
                )}
                <span style={{
                  color: line.annotation ? "var(--diag-warning)" : (S.areFoldingControlsVisible && line.n === 4 ? "var(--text-muted)" : "transparent"),
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: 9,
                }}>
                  {line.annotation
                    ? (S.areAnnotationsEnabled ? <div style={{
                        width: 10, height: 10, borderRadius: 3,
                        background: "var(--diag-warning)",
                        color: "var(--bg)",
                        font: "700 7px var(--font-mono)",
                        display:"flex", alignItems:"center", justifyContent:"center",
                      }}>!</div> : null)
                    : (S.areFoldingControlsVisible && line.n === 4 ? <Ic.ChevD size={9}/> : null)}
                </span>
                <code style={{
                  whiteSpace: "pre",
                  color: "var(--editor-fg)",
                  font: `${S.fontSize}px/1.5 var(--font-mono)`,
                  paddingRight: 8,
                  overflow: "hidden",
                }}>
                  {line.content || "\u00a0"}
                </code>
              </div>
            ))}
          </div>
          {S.isMinimapVisible && (
            <div style={{
              width: 40, flexShrink: 0,
              borderLeft: "0.5px solid var(--border-variant)",
              background: "var(--editor-gutter)",
              padding: "6px 4px",
              display: "flex", flexDirection: "column", gap: 1.5,
            }}>
              {Array.from({length: 14}).map((_, i) => (
                <div key={i} style={{
                  height: 2, borderRadius: 1,
                  background: i === 6
                    ? `color-mix(in srgb, ${S.selectedLineHighlightColor} 60%, transparent)`
                    : `color-mix(in srgb, var(--syn-keyword) ${10 + (i%4)*8}%, transparent)`,
                  width: `${40 + (i*13)%55}%`,
                }}/>
              ))}
            </div>
          )}
        </div>
        {/* Readout of current values */}
        <div style={{
          marginTop: 8, padding: "8px 10px",
          background: "var(--element-bg)",
          border: "0.5px solid var(--border-variant)",
          borderRadius: 8,
          font: "11px var(--font-mono)",
          color: "var(--text-muted)",
          display: "grid", gridTemplateColumns: "1fr 1fr", rowGap: 3, columnGap: 8,
        }}>
          <span>fontSize</span><span style={{color:"var(--text)", textAlign:"right"}}>{S.fontSize}pt</span>
          <span>minimap</span><span style={{color:"var(--text)", textAlign:"right"}}>{S.isMinimapVisible ? "on":"off"}</span>
          <span>line nums</span><span style={{color:"var(--text)", textAlign:"right"}}>{S.isLineNumbersEnabled ? "on":"off"}</span>
          <span>fold ≥</span><span style={{color:"var(--text)", textAlign:"right"}}>{S.minimumFoldableLines}</span>
        </div>
      </div>
    );
  }

  function App() {
    return (
      <WindowFrame width={880} height={660}>
        <TitleBar title="Settings"/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <Rail/>
          <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column" }}>
            <TopBar/>
            <div style={{ flex: 1, minHeight: 0, display: "flex" }}>
              <Center/>
              <Preview/>
            </div>
          </div>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ConB = ConB;
