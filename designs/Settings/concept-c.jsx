// CONCEPT C — "COMMAND DECK"
// Raycast / modern Xcode energy.  Single scrolling page; a prominent
// command-bar at top drives search and navigation. A narrow jump-link
// rail on the left tracks scroll position. Each section header is a
// colourful overline + icon + accent-stripe slab, so the user can
// orient with peripheral vision.
// A floating "Modified (3)" pill exposes a popover that lists every
// dirty knob with per-row Revert.

const ConC = (() => {
  const { Ic, WindowFrame, TitleBar, CATS, PRESETS, DISPLAY_STATE: S, MODIFIED_KEYS, Switch, Slider, ValueBadge, Stepper, ColorChip, ModDot } = window;

  // --- Command bar at top ---------------------------------------------------
  function CommandBar() {
    return (
      <div style={{
        padding: "12px 16px",
        background: "var(--title-bar)",
        borderBottom: "0.5px solid var(--border-variant)",
        display: "flex", alignItems: "center", gap: 10,
      }}>
        <div style={{
          flex: 1,
          display: "flex", alignItems: "center", gap: 10,
          height: 34, padding: "0 14px",
          borderRadius: 10,
          background: "var(--element-bg)",
          border: "0.5px solid var(--border-focused)",
          boxShadow: "0 0 0 3px color-mix(in srgb, var(--border-focused) 16%, transparent)",
        }}>
          <span style={{ color: "var(--accent-1)" }}><Ic.Cmd size={14}/></span>
          <input placeholder="Jump to a setting, apply a preset, switch theme…" readOnly style={{
            flex: 1, background: "transparent", border: "none", outline: "none",
            color: "var(--text-placeholder)",
            font: "13px var(--font-sans)",
          }}/>
          <span style={{
            font: "500 10px var(--font-mono)", color: "var(--text-muted)",
            padding: "2px 6px", borderRadius: 4,
            background: "var(--element-active)",
          }}>/</span>
        </div>
        <button style={{
          display: "inline-flex", alignItems: "center", gap: 6,
          height: 34, padding: "0 12px",
          borderRadius: 8,
          background: "var(--element-bg)",
          border: "0.5px solid var(--border-variant)",
          color: "var(--text)",
          font: "500 12px var(--font-sans)",
          cursor: "pointer",
        }}>
          <Ic.Sparkles size={13}/> Presets
          <span style={{
            font: "500 10px var(--font-mono)", color: "var(--text-muted)",
            marginLeft: 2,
          }}>8</span>
        </button>
        <button style={{
          display: "inline-flex", alignItems: "center", gap: 6,
          height: 34, padding: "0 12px",
          borderRadius: 8,
          background: "color-mix(in srgb, var(--accent-1) 16%, transparent)",
          border: "0.5px solid color-mix(in srgb, var(--accent-1) 50%, transparent)",
          color: "var(--accent-1)",
          font: "600 12px var(--font-sans)",
          cursor: "pointer",
        }}>
          <ModDot accent="var(--accent-1)"/>
          3 modified
        </button>
      </div>
    );
  }

  // --- Jump-link rail -------------------------------------------------------
  function JumpRail() {
    return (
      <div style={{
        width: 152, flexShrink: 0,
        padding: "16px 8px",
        background: "var(--bg)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column", gap: 1,
      }}>
        <div style={{
          padding: "0 10px 6px",
          font: "700 9.5px var(--font-sans)",
          letterSpacing: "0.6px", textTransform: "uppercase",
          color: "var(--text-muted)",
        }}>ON THIS PAGE</div>
        {CATS.map(c => {
          const active = c.id === "display";
          return (
            <div key={c.id} style={{
              display: "flex", alignItems: "center", gap: 8,
              padding: "5px 10px",
              borderRadius: 6,
              color: active ? "var(--text)" : "var(--text-muted)",
              font: `${active?600:500} 11.5px var(--font-sans)`,
              cursor: "pointer",
              position: "relative",
            }}>
              <span style={{
                width: 4, height: 12, borderRadius: 2,
                background: active ? c.accent : "transparent",
              }}/>
              <span style={{ flex: 1 }}>{c.label}</span>
              {active && <Ic.ChevR size={10}/>}
            </div>
          );
        })}
        <div style={{ flex: 1 }}/>
        <div style={{
          padding: "8px 10px",
          font: "10.5px var(--font-sans)",
          color: "var(--text-disabled)",
          borderTop: "0.5px solid var(--border-variant)",
          marginTop: 8,
        }}>
          73 settings total
        </div>
      </div>
    );
  }

  // --- Section header (big, accent-coded) -----------------------------------
  function SectionHead({ cat, modifiedCount }) {
    return (
      <div style={{
        display: "flex", alignItems: "center", gap: 14,
        padding: "20px 24px 14px",
        position: "sticky", top: 0,
        background: "linear-gradient(180deg, var(--bg) 70%, transparent)",
        zIndex: 2,
      }}>
        <div style={{
          width: 36, height: 36,
          display: "flex", alignItems: "center", justifyContent: "center",
          borderRadius: 9,
          background: `color-mix(in srgb, ${cat.accent} 14%, transparent)`,
          color: cat.accent,
          border: `0.5px solid color-mix(in srgb, ${cat.accent} 40%, transparent)`,
        }}>{React.cloneElement(cat.icon, { size: 18 })}</div>
        <div style={{ flex: 1 }}>
          <div style={{
            font: "700 9.5px var(--font-sans)",
            letterSpacing: "0.7px", textTransform: "uppercase",
            color: cat.accent,
          }}>SECTION 01 · {cat.count} SETTINGS</div>
          <div style={{
            font: "700 24px/1 var(--font-display)",
            letterSpacing: "-0.01em",
            color: "var(--text)",
            marginTop: 2,
          }}>{cat.label}</div>
        </div>
        {modifiedCount > 0 && (
          <button style={{
            display: "inline-flex", alignItems: "center", gap: 6,
            height: 24, padding: "0 9px",
            borderRadius: 6,
            background: "transparent",
            border: "0.5px solid var(--border-variant)",
            color: "var(--text-muted)",
            font: "500 11px var(--font-sans)",
            cursor: "pointer",
          }}>
            <Ic.Rotate size={11}/> Reset section
          </button>
        )}
      </div>
    );
  }

  // --- Row primitive --------------------------------------------------------
  function Row({ label, hint, modified, accent, children }) {
    return (
      <div style={{
        display: "flex", alignItems: "center", gap: 12,
        padding: "10px 24px",
        borderTop: "0.5px solid var(--border-variant)",
        minHeight: 38,
      }}>
        <div style={{ width: 8, display: "flex", justifyContent: "center" }}>
          {modified && <ModDot accent={accent}/>}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            font: "500 12.5px var(--font-sans)",
            color: "var(--text)",
            display: "flex", alignItems: "center", gap: 8,
          }}>
            {label}
            {modified && <span style={{
              font: "500 10px var(--font-sans)", color: accent,
              cursor: "pointer",
            }}>↺ Revert</span>}
          </div>
          {hint && <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)", marginTop: 1 }}>{hint}</div>}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>{children}</div>
      </div>
    );
  }

  // --- Subgroup overline ----------------------------------------------------
  function SubGroup({ title }) {
    return (
      <div style={{
        padding: "16px 24px 4px",
        font: "700 9.5px var(--font-sans)",
        letterSpacing: "0.6px", textTransform: "uppercase",
        color: "var(--text-muted)",
      }}>{title}</div>
    );
  }

  // --- Display section content ----------------------------------------------
  function DisplaySection() {
    const cat = CATS[0];
    const acc = cat.accent;
    return (
      <div>
        <SectionHead cat={cat} modifiedCount={3}/>
        <SubGroup title="Typography"/>
        <Row label="Font size" hint="9 ↔ 32 pt" modified accent={acc}>
          <div style={{ width: 200 }}><Slider pct={(S.fontSize-9)/(32-9)} accent={acc}/></div>
          <ValueBadge value={S.fontSize} unit="pt" accent={acc}/>
        </Row>

        <SubGroup title="Highlighting"/>
        <Row label="Syntax highlighting" accent={acc}><Switch on={S.isSyntaxHighlightingEnabled} accent={acc}/></Row>
        <Row label="Line numbers" accent={acc}><Switch on={S.isLineNumbersEnabled} accent={acc}/></Row>
        <Row label="Show annotations" hint="Inline TODO / FIXME / WARNING" accent={acc}>
          <Switch on={S.areAnnotationsEnabled} accent={acc}/>
        </Row>
        <Row label="Highlight selected line" accent={acc}><Switch on={S.isSelectedLineHighlighted} accent={acc}/></Row>
        <Row label="Selected-line color" accent={acc}>
          <ColorChip value={S.selectedLineHighlightColor}/>
        </Row>
        <Row label="Show invisible characters" accent={acc}><Switch on={S.areInvisibleCharactersVisible} accent={acc}/></Row>
        <Row label="Range-store highlighting" hint="experimental · faster for long files" modified accent={acc}>
          <Switch on={S.useRangeStoreHighlighting} accent={acc}/>
        </Row>

        <SubGroup title="Code Folding"/>
        <Row label="Enable code folding" accent={acc}><Switch on={S.isCodeFoldingEnabled} accent={acc}/></Row>
        <Row label="Show folding controls" accent={acc}><Switch on={S.areFoldingControlsVisible} accent={acc}/></Row>
        <Row label="Minimum foldable lines" modified accent={acc}>
          <Stepper value={S.minimumFoldableLines}/>
        </Row>
      </div>
    );
  }

  // Peek of the next section so users know there's more below.
  function LayoutPeek() {
    const cat = CATS[1];
    return (
      <div style={{ opacity: 0.55 }}>
        <SectionHead cat={cat} modifiedCount={0}/>
        <Row label="Tab width" accent={cat.accent}>
          <div style={{ width: 200 }}><Slider pct={0.4} accent={cat.accent} ticks={7}/></div>
          <ValueBadge value={4} unit="" accent={cat.accent}/>
        </Row>
      </div>
    );
  }

  function App() {
    return (
      <WindowFrame width={880} height={660}>
        <TitleBar title="Settings"/>
        <CommandBar/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <JumpRail/>
          <div style={{ flex: 1, minWidth: 0, overflowY: "auto", background: "var(--bg)" }}>
            <DisplaySection/>
            <LayoutPeek/>
          </div>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ConC = ConC;
