// CONCEPT A — "CONSOLE"
// Direct heir to today's NavigationSplitView, but elevated.
// Left rail: 7 categories with accent stripes and counts.
// Right pane: header with section title + modified state + reset.
// Knobs grouped under sub-headings in bordered cards.
// Sliders show large monospaced value badges in the row's accent.
// Modified knobs show a left-margin accent dot with a revert affordance.

const ConA = (() => {
  const { Ic, WindowFrame, TitleBar, CATS, PRESETS, DISPLAY_STATE: S, MODIFIED_KEYS, Switch, Slider, ValueBadge, Stepper, ColorChip, ModDot } = window;

  const ACC = "var(--accent-1)";

  function Rail() {
    return (
      <div style={{
        width: 196, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "14px 14px 8px" }}>
          <div style={{
            font: "700 10px var(--font-sans)",
            letterSpacing: "0.6px", textTransform: "uppercase",
            color: "var(--text-muted)",
          }}>SETTINGS</div>
        </div>
        <div style={{ padding: "0 8px", display: "flex", flexDirection: "column", gap: 1 }}>
          {CATS.map(c => {
            const active = c.id === "display";
            return (
              <div key={c.id} style={{
                position: "relative",
                display: "flex", alignItems: "center", gap: 10,
                padding: "8px 10px",
                borderRadius: 6,
                background: active ? "var(--element-selected)" : "transparent",
                color: active ? "var(--text)" : "var(--text)",
                cursor: "pointer",
              }}>
                {active && <div style={{
                  position: "absolute", left: -8, top: 6, bottom: 6, width: 3,
                  background: c.accent, borderRadius: 2,
                }}/>}
                <span style={{ color: active ? c.accent : "var(--icon-muted)" }}>{c.icon}</span>
                <span style={{
                  flex: 1,
                  font: `${active?600:500} 12px var(--font-sans)`,
                  color: active ? "var(--text)" : "var(--text)",
                }}>{c.label}</span>
                <span style={{
                  font: "500 10px var(--font-mono)",
                  color: active ? c.accent : "var(--text-disabled)",
                }}>{c.count}</span>
              </div>
            );
          })}
        </div>
        <div style={{ flex: 1 }}/>
        {/* Presets affordance pinned at bottom */}
        <div style={{
          margin: 10, padding: "10px 10px",
          borderRadius: 8,
          background: "var(--element-bg)",
          border: "0.5px solid var(--border-variant)",
        }}>
          <div style={{
            display: "flex", alignItems: "center", gap: 6,
            font: "700 10px var(--font-sans)",
            letterSpacing: "0.6px", textTransform: "uppercase",
            color: "var(--text-muted)",
            marginBottom: 6,
          }}>
            <Ic.Sparkles size={11}/> PRESETS
          </div>
          <div style={{
            display: "flex", alignItems: "center", justifyContent: "space-between",
            font: "600 12px var(--font-sans)",
            color: "var(--text)",
          }}>
            <span>Default</span>
            <Ic.ChevR size={11}/>
          </div>
          <div style={{ font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 2 }}>
            8 available
          </div>
        </div>
      </div>
    );
  }

  // Row primitive: label left, control right, optional modified dot.
  function Row({ name, hint, modified, accent=ACC, children }) {
    return (
      <div style={{
        display: "flex", alignItems: "center", gap: 12,
        padding: "9px 14px",
        position: "relative",
        minHeight: 36,
      }}>
        {modified && <div style={{
          position: "absolute", left: 4, top: "50%", transform: "translateY(-50%)",
        }}><ModDot accent={accent}/></div>}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            display: "flex", alignItems: "center", gap: 8,
            font: "500 12.5px var(--font-sans)",
            color: "var(--text)",
          }}>
            {name}
            {modified && (
              <span style={{
                font: "500 10px var(--font-sans)",
                color: accent,
                cursor: "pointer",
              }}>Revert</span>
            )}
          </div>
          {hint && <div style={{
            font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 1,
          }}>{hint}</div>}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {children}
        </div>
      </div>
    );
  }

  function Group({ title, children }) {
    return (
      <div style={{
        margin: "0 16px 14px",
        background: "var(--surface)",
        border: "0.5px solid var(--border-variant)",
        borderRadius: 10,
        overflow: "hidden",
      }}>
        <div style={{
          padding: "9px 14px",
          font: "700 10px var(--font-sans)",
          letterSpacing: "0.6px", textTransform: "uppercase",
          color: "var(--text-muted)",
          background: "color-mix(in srgb, var(--accent-1) 4%, transparent)",
          borderBottom: "0.5px solid var(--border-variant)",
        }}>{title}</div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          {React.Children.map(children, (child, i) => (
            <React.Fragment key={i}>
              {i > 0 && <div style={{ height: "0.5px", background: "var(--border-variant)", margin: "0 14px" }}/>}
              {child}
            </React.Fragment>
          ))}
        </div>
      </div>
    );
  }

  function SliderRow({ name, hint, value, unit, pct, min, max, modified }) {
    return (
      <Row name={name} hint={hint} modified={modified} accent={ACC}>
        <div style={{ width: 168, display: "flex", alignItems: "center" }}>
          <Slider pct={pct} accent={ACC}/>
        </div>
        <ValueBadge value={value} unit={unit} accent={ACC}/>
      </Row>
    );
  }

  function Header() {
    return (
      <div style={{
        padding: "16px 16px 12px",
        background: "var(--surface)",
        borderBottom: "0.5px solid var(--border-variant)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span style={{ color: ACC }}><Ic.Grid size={20}/></span>
          <div style={{ flex: 1 }}>
            <div style={{
              font: "700 22px/1 var(--font-display)",
              letterSpacing: "-0.01em",
              color: "var(--text)",
            }}>Display</div>
            <div style={{
              font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 4,
            }}>13 settings · <span style={{ color: ACC }}>3 modified</span></div>
          </div>
          <button style={{
            display: "inline-flex", alignItems: "center", gap: 6,
            height: 26, padding: "0 10px",
            borderRadius: 6,
            background: "var(--element-bg)",
            border: "0.5px solid var(--border-variant)",
            color: "var(--text-muted)",
            font: "500 11px var(--font-sans)",
            cursor: "pointer",
          }}>
            <Ic.Rotate size={11}/> Reset section
          </button>
        </div>
        {/* Search */}
        <div style={{
          marginTop: 12,
          display: "flex", alignItems: "center", gap: 8,
          height: 28, padding: "0 10px",
          borderRadius: 7,
          background: "var(--element-bg)",
          border: "0.5px solid var(--border-variant)",
        }}>
          <span style={{ color: "var(--text-muted)" }}><Ic.Search size={13}/></span>
          <input placeholder="Search all 73 settings…" readOnly style={{
            flex: 1, background: "transparent", border: "none", outline: "none",
            color: "var(--text-placeholder)",
            font: "12px var(--font-sans)",
          }}/>
          <span style={{
            display: "inline-flex", alignItems: "center", gap: 2,
            padding: "1px 5px", borderRadius: 4,
            background: "var(--element-active)",
            font: "500 10px var(--font-mono)", color: "var(--text-muted)",
          }}>⌘F</span>
        </div>
      </div>
    );
  }

  function Body() {
    return (
      <div style={{
        flex: 1, overflow: "hidden",
        display: "flex", flexDirection: "column",
        background: "var(--bg)",
      }}>
        <Header/>
        <div style={{ flex: 1, overflowY: "auto", padding: "14px 0" }}>
          <Group title="Typography">
            <SliderRow
              name="Font size"
              hint="9–32 pt · integer steps"
              value={S.fontSize} unit="pt" pct={(S.fontSize-9)/(32-9)}
              modified={MODIFIED_KEYS.has("fontSize")}
            />
          </Group>

          <Group title="Highlighting">
            <Row name="Syntax highlighting"><Switch on={S.isSyntaxHighlightingEnabled}/></Row>
            <Row name="Line numbers"><Switch on={S.isLineNumbersEnabled}/></Row>
            <Row name="Show annotations" hint="Inline TODO/FIXME/WARNING markers"><Switch on={S.areAnnotationsEnabled}/></Row>
            <Row name="Highlight selected line"><Switch on={S.isSelectedLineHighlighted}/></Row>
            <Row name="Selected-line color">
              <ColorChip value={S.selectedLineHighlightColor}/>
            </Row>
            <Row name="Show invisible characters"><Switch on={S.areInvisibleCharactersVisible}/></Row>
            <Row name="Use range-store highlighting"
              hint="Experimental · faster for long files"
              modified={MODIFIED_KEYS.has("useRangeStoreHighlighting")}
            ><Switch on={S.useRangeStoreHighlighting}/></Row>
          </Group>

          <Group title="Code Folding">
            <Row name="Enable code folding"><Switch on={S.isCodeFoldingEnabled}/></Row>
            <Row name="Show folding controls"><Switch on={S.areFoldingControlsVisible}/></Row>
            <Row name="Minimum foldable lines"
              modified={MODIFIED_KEYS.has("minimumFoldableLines")}
            >
              <Stepper value={S.minimumFoldableLines}/>
            </Row>
          </Group>

          <Group title="Minimap & Viewport">
            <Row name="Show minimap"><Switch on={S.isMinimapVisible}/></Row>
            <Row name="Visible lines" hint="Viewport size hint">
              <Stepper value={S.visibleLines}/>
            </Row>
          </Group>
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
          <Body/>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ConA = ConA;
