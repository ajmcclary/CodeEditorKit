// _shared/chrome.jsx
// Subsystem-agnostic building blocks for the CodeEditorPlugin concept set:
// WindowFrame + TitleBar (native macOS chrome), Lucide-style icon set, and
// the atomic controls every concept reaches for (Switch, Slider, Stepper,
// ValueBadge, Pill, KbdHint, TabBar, Toggle group, Card, Row primitives).
//
// Reads every color from the design-system CSS variables in
// colors_and_type.css.  No subsystem-specific data lives here — that goes
// in the per-subsystem concept-*.jsx files.

const { useState, useMemo, useEffect, useRef } = React;

// ============================================================
// Lucide-style icons (1.7px stroke, current-color).  Names map onto the
// SF Symbols substitutions enumerated in the design system guide.
// ============================================================
const Ic = {
  // chrome / nav
  ChevR:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m9 18 6-6-6-6"/></svg>,
  ChevL:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>,
  ChevD:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m6 9 6 6 6-6"/></svg>,
  ChevU:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m6 15 6-6 6 6"/></svg>,
  X:        (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>,
  Plus:     (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>,
  Minus:    (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M5 12h14"/></svg>,
  Check:    (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5"/></svg>,
  Search:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>,
  Cmd:      (p) => <svg width={p.size||12} height={p.size||12} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6a3 3 0 1 1 3 3h-3zM9 6a3 3 0 1 0-3 3h3zM15 18a3 3 0 1 0 3-3h-3zM9 18a3 3 0 1 1-3-3h3zM9 9h6v6H9z"/></svg>,
  Rotate:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg>,
  Eye:      (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>,
  Filter:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M22 3H2l8 9.5V20l4 2v-9.5z"/></svg>,
  Sparkles: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/></svg>,
  Dot:      (p) => <svg width={p.size||8} height={p.size||8} viewBox="0 0 8 8"><circle cx="4" cy="4" r={p.r||3} fill="currentColor"/></svg>,
  Pin:      (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 17v5"/><path d="M9 10.76V6h6v4.76a2 2 0 0 0 .59 1.42l2.41 2.41A1 1 0 0 1 17.29 16H6.71a1 1 0 0 1-.71-1.41l2.41-2.41A2 2 0 0 0 9 10.76z"/></svg>,

  // diagnostics / annotations (SF Symbol equivalents)
  Info:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>,
  Note:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6M9 13h6M9 17h4"/></svg>,
  Todo:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg>,
  Wrench:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M14.7 6.3a4 4 0 0 0-5.7 5.7L3 18l3 3 6-6a4 4 0 0 0 5.7-5.7l-2.4 2.4-2.5-.6-.6-2.5z"/></svg>,
  Warning:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M10.3 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.7 3.86a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></svg>,
  Error:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6M9 9l6 6"/></svg>,

  // completion / code symbols
  Func:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M9 17V7a2 2 0 0 1 2-2h2"/><path d="M5 12h8"/></svg>,
  Var:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M5 7h14M9 17h6M10 7l-2 10M14 7l2 10"/></svg>,
  Type:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M7 8h10M12 8v9"/></svg>,
  Mod:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l7-4a2 2 0 0 0 1-1.7z"/></svg>,
  Keyword:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M15 3h6v6M14 10l7-7M10 21H4v-6M4 21l7-7"/></svg>,
  Snippet:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M16 18 22 12 16 6M8 6 2 12 8 18"/></svg>,
  Prop:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/></svg>,
  String:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M7 9V7l-2 2M17 9V7l-2 2M7 13v2l-2-2M17 13v2l-2-2"/></svg>,

  // folding
  Folded:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M5 7h14M5 12h14M5 17h14"/></svg>,
  Ellipsis: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="currentColor"><circle cx="6" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="18" cy="12" r="1.4"/></svg>,
  Braces:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M8 3H7a2 2 0 0 0-2 2v4c0 1-1 2-2 2 1 0 2 1 2 2v4a2 2 0 0 0 2 2h1M16 3h1a2 2 0 0 1 2 2v4c0 1 1 2 2 2-1 0-2 1-2 2v4a2 2 0 0 1-2 2h-1"/></svg>,

  // LSP / server
  Server:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="3" width="20" height="6" rx="1"/><rect x="2" y="15" width="20" height="6" rx="1"/><path d="M6 6h.01M6 18h.01"/></svg>,
  Plug:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M9 2v6M15 2v6M6 8h12v3a6 6 0 0 1-12 0z"/><path d="M12 17v5"/></svg>,
  Bolt:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="m13 2-9 14h7l-1 6 9-14h-7z"/></svg>,
  Lock:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>,
  Globe:   (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/></svg>,
  Activity:(p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12h4l3-9 4 18 3-9h4"/></svg>,

  // smart editing
  Cursor:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M9 4v16M3 9h6M3 15h6M15 4l6 8-6 8"/></svg>,
  Indent:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 8h18M3 12h12M3 16h18M3 20h18M9 4l-4 4 4 4"/></svg>,
  Expand:  (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M15 3h6v6M14 10l7-7M9 21H3v-6M10 14l-7 7"/></svg>,

  // syntax / theme
  Palette: (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><path d="M12 2a10 10 0 0 0 0 20 1.5 1.5 0 0 0 1.1-2.5 1.5 1.5 0 0 1 1.1-2.5h1.6a4.2 4.2 0 0 0 4.2-4.2 8 8 0 0 0-8-10.8z"/></svg>,
  Sun:     (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>,
  Moon:    (p) => <svg width={p.size||14} height={p.size||14} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>,

  Grip:    (p) => <svg width={p.size||10} height={p.size||10} viewBox="0 0 24 24" fill="currentColor"><circle cx="9" cy="6" r="1.4"/><circle cx="15" cy="6" r="1.4"/><circle cx="9" cy="12" r="1.4"/><circle cx="15" cy="12" r="1.4"/><circle cx="9" cy="18" r="1.4"/><circle cx="15" cy="18" r="1.4"/></svg>,
};

// ============================================================
// macOS window frame — native chrome only.  TitleBar paints traffic
// lights + a centred title; the right slot is reserved for per-concept
// chrome (segmented control, status pip, etc.).
// ============================================================
function WindowFrame({ width = 880, height = 660, theme = "lcars-dark", children, style }) {
  return (
    <div className={`theme-${theme}`} style={{
      width, height,
      borderRadius: 14, overflow: "hidden",
      background: "var(--surface)",
      color: "var(--text)",
      font: "13px/1.4 var(--font-sans)",
      boxShadow: "0 24px 64px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(255,255,255,0.05)",
      display: "flex", flexDirection: "column",
      position: "relative",
      ...style,
    }}>
      {children}
    </div>
  );
}

function TitleBar({ title, subtitle = "CodeEditorSample", right }) {
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
          {title}{subtitle ? <span style={{ color: "var(--text-muted)" }}> — {subtitle}</span> : null}
        </span>
      </div>
      <div style={{ flex: 1 }}/>
      {right}
    </div>
  );
}

// ============================================================
// Atoms
// ============================================================
function Switch({ on, accent = "var(--accent-1)", onClick }) {
  return (
    <button onClick={onClick} style={{
      width: 30, height: 18, borderRadius: 9, border: "none", padding: 0, cursor: "pointer",
      background: on ? accent : "var(--element-bg)",
      boxShadow: on ? `inset 0 0 0 0.5px ${accent}` : "inset 0 0 0 0.5px var(--border)",
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
    </button>
  );
}

function Slider({ pct, accent = "var(--accent-1)", ticks = 0, width = "100%", onClick }) {
  return (
    <div onClick={onClick} style={{ width, position: "relative", height: 16, cursor: onClick ? "pointer" : "default" }}>
      <div style={{
        position: "absolute", left: 0, right: 0, top: 6,
        height: 4, borderRadius: 2,
        background: "var(--element-bg)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
      }}/>
      <div style={{
        position: "absolute", left: 0, top: 6,
        width: `${pct * 100}%`, height: 4, borderRadius: 2,
        background: accent,
      }}/>
      {ticks > 0 && Array.from({ length: ticks + 1 }).map((_, i) => {
        const p = i / ticks;
        return <div key={i} style={{
          position: "absolute", left: `calc(${p*100}% - 0.5px)`, top: 4,
          width: 1, height: 8, background: "var(--border-variant)", opacity: 0.6,
        }}/>;
      })}
      <div style={{
        position: "absolute", left: `calc(${pct * 100}% - 7px)`, top: 1,
        width: 14, height: 14, borderRadius: "50%",
        background: "#fff",
        boxShadow: `0 0 0 0.5px ${accent}, 0 2px 6px rgba(0,0,0,0.45)`,
      }}/>
    </div>
  );
}

function ValueBadge({ value, unit, accent = "var(--accent-1)", muted }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "baseline", gap: 2,
      padding: "2px 8px", borderRadius: 6,
      background: muted ? "var(--element-bg)" : `color-mix(in srgb, ${accent} 16%, transparent)`,
      boxShadow: `inset 0 0 0 0.5px ${muted ? "var(--border-variant)" : `color-mix(in srgb, ${accent} 40%, transparent)`}`,
      font: "600 11px var(--font-mono)",
      color: muted ? "var(--text-muted)" : accent,
      minWidth: 38, justifyContent: "center", whiteSpace: "nowrap",
    }}>
      {value}{unit && <span style={{ opacity: 0.7, marginLeft: 1, fontSize: 9 }}>{unit}</span>}
    </div>
  );
}

function Stepper({ value, unit, onPlus, onMinus, min = 0 }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "stretch", height: 22, borderRadius: 6,
      boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
      background: "var(--element-bg)", overflow: "hidden",
      font: "500 11px var(--font-mono)",
    }}>
      <button onClick={onMinus} style={btnStep}><Ic.Minus/></button>
      <div style={{
        padding: "0 10px", display: "flex", alignItems: "center",
        color: "var(--text)", minWidth: 50, justifyContent: "center",
      }}>{value}{unit && <span style={{ color: "var(--text-muted)", marginLeft: 2 }}>{unit}</span>}</div>
      <button onClick={onPlus} style={{ ...btnStep, borderLeft: "0.5px solid var(--border-variant)", borderRight: "none" }}><Ic.Plus/></button>
    </div>
  );
}
const btnStep = {
  width: 22, display: "flex", alignItems: "center", justifyContent: "center",
  background: "transparent", border: "none", borderRight: "0.5px solid var(--border-variant)",
  color: "var(--text-muted)", cursor: "pointer",
};

// Pill / chip used for filters, toggles, presets.
function Pill({ children, active, accent = "var(--accent-1)", onClick, icon, size = "md" }) {
  const h = size === "sm" ? 20 : 22;
  return (
    <button onClick={onClick} style={{
      display: "inline-flex", alignItems: "center", gap: 5,
      height: h, padding: size === "sm" ? "0 7px" : "0 9px",
      borderRadius: h / 2,
      background: active ? `color-mix(in srgb, ${accent} 18%, transparent)` : "var(--element-bg)",
      boxShadow: active ? `inset 0 0 0 0.5px ${accent}` : "inset 0 0 0 0.5px var(--border-variant)",
      color: active ? accent : "var(--text)",
      font: `${active ? 600 : 500} ${size === "sm" ? 10 : 11}px var(--font-sans)`,
      cursor: "pointer", whiteSpace: "nowrap",
      border: "none",
    }}>
      {icon ? <span style={{ display: "flex" }}>{icon}</span> : null}
      {children}
    </button>
  );
}

// Keyboard hint key (used everywhere from kbd shortcuts to “⌘P” marks).
function Kbd({ children, accent }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", height: 16, padding: "0 5px",
      borderRadius: 4, background: "var(--element-active)",
      font: "500 10px var(--font-mono)",
      color: accent || "var(--text-muted)",
      letterSpacing: 0.4,
    }}>{children}</span>
  );
}

// Segmented control — single-row tab bar.
function Segmented({ items, value, onChange, accent = "var(--accent-1)" }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center",
      padding: 2, borderRadius: 7,
      background: "var(--element-bg)",
      boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
      gap: 2,
    }}>
      {items.map(it => {
        const active = it.value === value;
        return (
          <button key={it.value} onClick={() => onChange && onChange(it.value)} style={{
            border: "none", cursor: "pointer",
            height: 22, padding: "0 10px", borderRadius: 5,
            display: "inline-flex", alignItems: "center", gap: 5,
            background: active ? "var(--surface)" : "transparent",
            boxShadow: active ? "0 0 0 0.5px var(--border-variant), 0 1px 2px rgba(0,0,0,0.18)" : "none",
            color: active ? "var(--text)" : "var(--text-muted)",
            font: `${active ? 600 : 500} 11px var(--font-sans)`,
          }}>
            {it.icon}{it.label}
          </button>
        );
      })}
    </div>
  );
}

// Severity dot — used by annotation/diagnostic surfaces.
function SevDot({ kind = "info", size = 8 }) {
  const c = SEV_COLOR[kind] || "var(--diag-info)";
  return <span style={{
    width: size, height: size, borderRadius: "50%",
    background: c, flexShrink: 0,
    boxShadow: `0 0 0 2px color-mix(in srgb, ${c} 22%, transparent)`,
  }}/>;
}
const SEV_COLOR = {
  error:   "var(--diag-error)",
  warning: "var(--diag-warning)",
  info:    "var(--diag-info)",
  success: "var(--diag-success)",
  todo:    "var(--diag-info)",
  note:    "var(--text-muted)",
  fixme:   "var(--diag-warning)",
};

// Section header overline used in left rails / panels.
function Overline({ children, color }) {
  return (
    <div style={{
      font: "700 10px var(--font-sans)",
      letterSpacing: "0.6px", textTransform: "uppercase",
      color: color || "var(--text-muted)",
    }}>{children}</div>
  );
}

// Status pill (LSP / connection states).
function StatusPill({ state, label }) {
  const c = STATUS_COLOR[state] || "var(--text-muted)";
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 6,
      padding: "2px 8px", borderRadius: 999,
      background: `color-mix(in srgb, ${c} 14%, transparent)`,
      boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${c} 50%, transparent)`,
      font: "600 10px var(--font-sans)",
      color: c, letterSpacing: 0.3, textTransform: "uppercase",
    }}>
      <span style={{
        width: 6, height: 6, borderRadius: "50%", background: c,
        boxShadow: state === "initialized" ? `0 0 8px ${c}` : "none",
      }}/>
      {label || state}
    </span>
  );
}
const STATUS_COLOR = {
  disconnected: "var(--text-muted)",
  connecting:   "var(--status-warning)",
  initializing: "var(--status-warning)",
  initialized:  "var(--status-success)",
  shuttingDown: "var(--status-caution)",
  error:        "var(--status-error)",
};

// Theme toggle stripe (light/dark side-by-side controls).
function LightDarkSplit({ theme, onChange, themes }) {
  const list = themes || [{ value: "lcars-dark", label: "Dark", icon: <Ic.Moon size={11}/> }, { value: "lcars-light", label: "Light", icon: <Ic.Sun size={11}/> }];
  return (
    <Segmented items={list} value={theme} onChange={onChange}/>
  );
}

// Common card surface (rounded, hairline, surface background).
function Card({ children, style, hairline = true }) {
  return (
    <div style={{
      background: "var(--surface)",
      borderRadius: 10,
      boxShadow: hairline ? "inset 0 0 0 0.5px var(--border-variant)" : "none",
      overflow: "hidden",
      ...style,
    }}>{children}</div>
  );
}

// Row primitive: label left, control right.
function Row({ label, hint, right, accent = "var(--accent-1)", indent = 0 }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 12,
      padding: `8px ${14 + indent}px 8px ${14 + indent}px`,
      minHeight: 34,
    }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: "500 12.5px var(--font-sans)", color: "var(--text)" }}>{label}</div>
        {hint && <div style={{ font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 1 }}>{hint}</div>}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>{right}</div>
    </div>
  );
}

// Inline mini code line — used everywhere we render fake source.
// children should be the highlighted spans.
function CodeLine({ n, active, indicator, children, fontSize = 12, accent }) {
  return (
    <div style={{
      display: "grid",
      gridTemplateColumns: "32px 16px 1fr",
      alignItems: "center", minHeight: fontSize * 1.5,
      background: active ? `color-mix(in srgb, ${accent || "var(--accent-1)"} 14%, transparent)` : "transparent",
      borderLeft: active ? `2px solid ${accent || "var(--accent-1)"}` : "2px solid transparent",
    }}>
      <span style={{
        textAlign: "right", padding: "0 8px 0 0",
        color: active ? "var(--active-line-num)" : "var(--line-num)",
        font: `${active ? 600 : 400} ${Math.max(9, fontSize - 3)}px var(--font-mono)`,
        userSelect: "none",
      }}>{n}</span>
      <span style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>{indicator}</span>
      <code style={{
        whiteSpace: "pre", color: "var(--editor-fg)",
        font: `${fontSize}px/1.5 var(--font-mono)`,
        paddingRight: 8, overflow: "hidden",
      }}>{children || "\u00a0"}</code>
    </div>
  );
}

// Tiny coloured token spans.
const Tk = {
  K: (p) => <span style={{ color: "var(--syn-keyword)", fontWeight: 600 }}>{p.children}</span>,
  T: (p) => <span style={{ color: "var(--syn-type)", fontWeight: 600 }}>{p.children}</span>,
  F: (p) => <span style={{ color: "var(--syn-function)", fontWeight: 600 }}>{p.children}</span>,
  S: (p) => <span style={{ color: "var(--syn-string)" }}>{p.children}</span>,
  N: (p) => <span style={{ color: "var(--syn-number)" }}>{p.children}</span>,
  C: (p) => <span style={{ color: "var(--syn-comment)", fontStyle: "italic" }}>{p.children}</span>,
  P: (p) => <span style={{ color: "var(--syn-property)" }}>{p.children}</span>,
  V: (p) => <span style={{ color: "var(--syn-variable)" }}>{p.children}</span>,
  Pn: (p) => <span style={{ color: "var(--syn-punct)" }}>{p.children}</span>,
  At: (p) => <span style={{ color: "var(--syn-attr)" }}>{p.children}</span>,
};

// Theme switcher used by all three concept patterns — top-right of the
// title bar.  Keeps "light + dark mode for every concept" obvious.
function ThemeSwitch({ theme, setTheme }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 4, paddingRight: 4 }}>
      <button onClick={() => setTheme("lcars-light")} title="Light" style={themeBtn(theme === "lcars-light")}>
        <Ic.Sun size={12}/>
      </button>
      <button onClick={() => setTheme("lcars-dark")} title="Dark" style={themeBtn(theme === "lcars-dark")}>
        <Ic.Moon size={12}/>
      </button>
    </div>
  );
}
function themeBtn(active) {
  return {
    width: 22, height: 22, borderRadius: 5, border: "none", cursor: "pointer",
    display: "flex", alignItems: "center", justifyContent: "center",
    background: active ? "var(--element-selected)" : "transparent",
    color: active ? "var(--accent-1)" : "var(--text-muted)",
  };
}

Object.assign(window, {
  Ic, Tk,
  WindowFrame, TitleBar, ThemeSwitch,
  Switch, Slider, ValueBadge, Stepper,
  Pill, Kbd, Segmented, SevDot, Overline, StatusPill, LightDarkSplit,
  Card, Row, CodeLine,
});
