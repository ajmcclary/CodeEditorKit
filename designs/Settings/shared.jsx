// Shared atoms for all three Settings concepts.
// Icons (Lucide-style inline SVG), window chrome, sample data, and the
// primitive controls (Toggle, Slider, Stepper, ColorChip, Switch).
// Every color is a CSS var from design-system/colors_and_type.css.

const { useState, useMemo } = React;

// ----- Lucide-style icons ----------------------------------------------------
const Ic = {
  Grid: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>,
  Split: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="7" width="18" height="10" rx="1.2"/><path d="M9 7v10M15 7v10"/></svg>,
  Wand: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="m3 21 9-9"/><path d="M12.5 6.5 17 11"/><path d="M15 4 14 2M21 7l-2-1M19 11l2-1M17 3l-1 2"/></svg>,
  Gauge: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 13V8"/><path d="M3 12a9 9 0 0 1 17.5-3"/><path d="M3 12a9 9 0 0 0 9 9 9 9 0 0 0 6.4-2.6"/><circle cx="12" cy="13" r="1"/></svg>,
  Folder: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M4 5.5A1.5 1.5 0 0 1 5.5 4h3.4a2 2 0 0 1 1.6.8L11.7 6h6.8A1.5 1.5 0 0 1 20 7.5v10A1.5 1.5 0 0 1 18.5 19h-13A1.5 1.5 0 0 1 4 17.5z"/></svg>,
  Alert: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M21 11.5a8.4 8.4 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.4 8.4 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.4 8.4 0 0 1 3.8-.9h.5a8.5 8.5 0 0 1 8 8z"/><path d="M12 8v4M12 16h.01"/></svg>,
  Palette: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><path d="M12 2a10 10 0 0 0 0 20 1.5 1.5 0 0 0 1.1-2.5 1.5 1.5 0 0 1 1.1-2.5h1.6a4.2 4.2 0 0 0 4.2-4.2 8 8 0 0 0-8-10.8z"/></svg>,
  Search: (p) => <svg width={p.size||16} height={p.size||16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>,
  ChevR: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m9 18 6-6-6-6"/></svg>,
  ChevD: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m6 9 6 6 6-6"/></svg>,
  Rotate: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg>,
  Sparkles: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/></svg>,
  Plus: (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>,
  Minus: (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M5 12h14"/></svg>,
  Check: (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5"/></svg>,
  Cmd: (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6a3 3 0 1 1 3 3h-3zM9 6a3 3 0 1 0-3 3h3zM15 18a3 3 0 1 0 3-3h-3zM9 18a3 3 0 1 1-3-3h3zM9 9h6v6H9z"/></svg>,
  Eye: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>,
  Trash: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>,
  Folded: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="m7 14 5-5 5 5"/></svg>,
  Dot: (p) => <svg width={p.size||8} height={p.size||8} viewBox="0 0 8 8"><circle cx="4" cy="4" r="3" fill="currentColor"/></svg>,
};

// ----- macOS window frame ----------------------------------------------------
function WindowFrame({ width=880, height=660, children, theme="lcars-dark" }) {
  return (
    <div className={`theme-${theme}`} style={{
      width, height, borderRadius: 14, overflow: "hidden",
      background: "var(--surface)",
      color: "var(--text)",
      font: "13px/1.4 var(--font-sans)",
      boxShadow: "0 24px 64px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(255,255,255,0.05)",
      display: "flex", flexDirection: "column",
      position: "relative",
    }}>
      {children}
    </div>
  );
}

function TitleBar({ title, accent, right }) {
  return (
    <div style={{
      height: 38, flexShrink: 0,
      display: "flex", alignItems: "center", gap: 12, padding: "0 14px",
      background: "var(--title-bar)",
      borderBottom: "0.5px solid var(--border-variant)",
      position: "relative",
    }}>
      <div style={{ display: "flex", gap: 8 }}>
        <span style={{ width: 12, height: 12, borderRadius: "50%", background: "var(--traffic-close)" }}/>
        <span style={{ width: 12, height: 12, borderRadius: "50%", background: "var(--traffic-minimize)" }}/>
        <span style={{ width: 12, height: 12, borderRadius: "50%", background: "var(--traffic-zoom)" }}/>
      </div>
      <div style={{
        position: "absolute", left: 0, right: 0, top: 0, bottom: 0,
        display: "flex", alignItems: "center", justifyContent: "center",
        pointerEvents: "none",
      }}>
        <span style={{ font: "500 12px var(--font-sans)", color: "var(--text)" }}>
          {title} <span style={{ color: "var(--text-muted)" }}>— CodeEditorSample</span>
        </span>
      </div>
      <div style={{ flex: 1 }}/>
      {right}
    </div>
  );
}

// ----- Categories ------------------------------------------------------------
const CATS = [
  { id: "display",     label: "Display",     icon: <Ic.Grid size={15}/>,    accent: "var(--accent-1)", count: 13 },
  { id: "layout",      label: "Layout",      icon: <Ic.Split size={15}/>,   accent: "var(--accent-2)", count: 18 },
  { id: "behavior",    label: "Behavior",    icon: <Ic.Wand size={15}/>,    accent: "var(--accent-3)", count: 16 },
  { id: "performance", label: "Performance", icon: <Ic.Gauge size={15}/>,   accent: "var(--accent-4)", count: 14 },
  { id: "workspace",   label: "Workspace",   icon: <Ic.Folder size={15}/>,  accent: "var(--accent-5)", count: 1 },
  { id: "annotations", label: "Annotations", icon: <Ic.Alert size={15}/>,   accent: "var(--diag-warning)", count: 5 },
  { id: "theme",       label: "Theme",       icon: <Ic.Palette size={15}/>, accent: "var(--text-accent)", count: 20 },
];

const PRESETS = ["Default", "Minimal", "Read-only", "Markdown", "Presentation", "macOS", "iOS", "Platform-Optimized"];

// Display-tab knob state used by all three concepts (so the same data is
// presented under different mental models).
const DISPLAY_STATE = {
  fontSize: 14,            // 9…32, modified
  isSyntaxHighlightingEnabled: true,
  isLineNumbersEnabled: true,
  areAnnotationsEnabled: true,
  isSelectedLineHighlighted: true,
  selectedLineHighlightColor: "#FF9933",
  areInvisibleCharactersVisible: false,
  useRangeStoreHighlighting: true,    // modified
  isCodeFoldingEnabled: true,
  areFoldingControlsVisible: true,
  minimumFoldableLines: 2,            // modified
  isMinimapVisible: true,
  visibleLines: 60,
};

const MODIFIED_KEYS = new Set(["fontSize", "useRangeStoreHighlighting", "minimumFoldableLines"]);

// ----- Atom: macOS-style switch ---------------------------------------------
function Switch({ on, accent="var(--accent-1)" }) {
  return (
    <div style={{
      width: 30, height: 18, borderRadius: 9,
      background: on ? accent : "var(--element-bg)",
      border: on ? `0.5px solid ${accent}` : "0.5px solid var(--border)",
      position: "relative", flexShrink: 0,
      transition: "background var(--dur-fast) var(--ease-spring-snappy)",
    }}>
      <div style={{
        position: "absolute", top: 1.5, left: on ? 13.5 : 1.5,
        width: 14, height: 14, borderRadius: "50%",
        background: on ? "#fff" : "var(--text-muted)",
        boxShadow: "0 1px 2px rgba(0,0,0,0.25)",
        transition: "left var(--dur-fast) var(--ease-spring-snappy)",
      }}/>
    </div>
  );
}

// ----- Atom: slider (premium) -----------------------------------------------
// Renders the track + fill + thumb + integer ticks if ticks=true.
// `pct` controls thumb position (0..1).
function Slider({ pct, accent="var(--accent-1)", ticks=0, height=4, width="100%" }) {
  return (
    <div style={{ width, position: "relative", height: 16 }}>
      <div style={{
        position: "absolute", left: 0, right: 0, top: (16-height)/2,
        height, borderRadius: height/2,
        background: "var(--element-bg)",
        border: "0.5px solid var(--border-variant)",
      }}/>
      <div style={{
        position: "absolute", left: 0, top: (16-height)/2,
        width: `${pct*100}%`, height, borderRadius: height/2,
        background: accent,
      }}/>
      {ticks > 0 && Array.from({length: ticks+1}).map((_, i) => {
        const p = i/ticks;
        return <div key={i} style={{
          position: "absolute", left: `calc(${p*100}% - 0.5px)`, top: 0,
          width: 1, height: 16,
          background: "var(--border-variant)",
          opacity: 0.6,
        }}/>;
      })}
      <div style={{
        position: "absolute", left: `calc(${pct*100}% - 7px)`, top: 1,
        width: 14, height: 14, borderRadius: "50%",
        background: "#fff",
        boxShadow: `0 0 0 0.5px ${accent}, 0 2px 6px rgba(0,0,0,0.45)`,
      }}/>
    </div>
  );
}

// ----- Atom: value badge -----------------------------------------------------
function ValueBadge({ value, unit, accent="var(--accent-1)", muted }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "baseline", gap: 2,
      padding: "2px 8px",
      borderRadius: 6,
      background: muted ? "var(--element-bg)" : `color-mix(in srgb, ${accent} 16%, transparent)`,
      border: `0.5px solid ${muted ? "var(--border-variant)" : `color-mix(in srgb, ${accent} 40%, transparent)`}`,
      font: "600 11px var(--font-mono)",
      color: muted ? "var(--text-muted)" : accent,
      minWidth: 38, justifyContent: "center",
      whiteSpace: "nowrap",
    }}>
      {value}{unit && <span style={{ opacity: 0.7, marginLeft: 1, fontSize: 9 }}>{unit}</span>}
    </div>
  );
}

// ----- Atom: stepper ---------------------------------------------------------
function Stepper({ value, unit }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "stretch",
      height: 22,
      borderRadius: 6,
      border: "0.5px solid var(--border-variant)",
      background: "var(--element-bg)",
      overflow: "hidden",
      font: "500 11px var(--font-mono)",
    }}>
      <button style={{
        width: 22, display: "flex", alignItems: "center", justifyContent: "center",
        background: "transparent", border: "none", color: "var(--text-muted)",
        borderRight: "0.5px solid var(--border-variant)", cursor: "pointer",
      }}><Ic.Minus/></button>
      <div style={{
        padding: "0 10px", display: "flex", alignItems: "center",
        color: "var(--text)", minWidth: 64, justifyContent: "center",
      }}>{value}{unit && <span style={{ color: "var(--text-muted)", marginLeft: 2 }}>{unit}</span>}</div>
      <button style={{
        width: 22, display: "flex", alignItems: "center", justifyContent: "center",
        background: "transparent", border: "none", color: "var(--text-muted)",
        borderLeft: "0.5px solid var(--border-variant)", cursor: "pointer",
      }}><Ic.Plus/></button>
    </div>
  );
}

// ----- Atom: color chip ------------------------------------------------------
function ColorChip({ value }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 6,
      height: 22, padding: "0 8px 0 4px",
      borderRadius: 6,
      border: "0.5px solid var(--border-variant)",
      background: "var(--element-bg)",
      font: "500 11px var(--font-mono)",
      color: "var(--text)",
    }}>
      <span style={{
        width: 14, height: 14, borderRadius: 3,
        background: value,
        boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.25)",
      }}/>
      {value}
    </div>
  );
}

// ----- Atom: modified dot ----------------------------------------------------
function ModDot({ accent="var(--accent-1)" }) {
  return <span title="Modified" style={{
    width: 6, height: 6, borderRadius: "50%",
    background: accent, flexShrink: 0,
    boxShadow: `0 0 0 2px color-mix(in srgb, ${accent} 25%, transparent)`,
  }}/>;
}

Object.assign(window, {
  Ic, WindowFrame, TitleBar, CATS, PRESETS, DISPLAY_STATE, MODIFIED_KEYS,
  Switch, Slider, ValueBadge, Stepper, ColorChip, ModDot,
});
