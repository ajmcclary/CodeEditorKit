/* App shell: macOS-window framed editor + sidebar + Tweaks panel
   that exposes every EditorConfiguration knob from CodeEditorPlugin. */

const { useState: useStateApp, useMemo: useMemoApp, useEffect: useEffectApp } = React;

/* Default tweak values mirror EditorConfiguration's defaults */
const DEFAULTS = /*EDITMODE-BEGIN*/{
  "themeId": "xcodeDark",
  "language": "swift",
  "preset": "default",

  "fontSize": 13,
  "isLineNumbersEnabled": true,
  "highlightSelectedLine": true,
  "enableAnnotations": true,
  "enableSyntaxHighlighting": true,
  "showInvisibleCharacters": false,
  "enableCodeFolding": true,
  "showFoldingControls": true,
  "minimumFoldableLines": 3,
  "showMinimap": true,

  "tabWidth": 4,
  "insertSpacesForTabs": true,
  "wrapLines": false,
  "gutterWidth": 52,
  "lineNumberPadding": 8,
  "lineHeightMultiple": 1.3,
  "characterSpacing": 0,
  "minimapWidth": 100,
  "annotationBadgeSize": 14,

  "isEditable": true,
  "autoIndent": true,
  "enableCodeCompletion": true,
  "showInlineCompletionSuggestions": true,
  "autoCloseBrackets": true,
  "autoCloseQuotes": true,
  "isContinuousSpellCheckingEnabled": false,

  "useHardwareAcceleration": true,
  "smoothScrolling": true,
  "animateCodeFolding": true,
  "renderingUpdateStrategy": "adaptive",
  "textChangeDebounceMs": 100,
  "maxSyntaxHighlightingLength": 500000,

  "platformView": "macOS"
}/*EDITMODE-END*/;

/* Map a preset name → partial overrides, mirroring CodeEditorPlugin presets */
const PRESETS = {
  default: {},
  minimal: {
    isLineNumbersEnabled: false,
    enableAnnotations: false,
    enableCodeFolding: false,
    showFoldingControls: false,
    showMinimap: false,
    enableCodeCompletion: false,
    showInlineCompletionSuggestions: false,
    highlightSelectedLine: false,
  },
  readOnly: {
    isEditable: false,
    enableCodeCompletion: false,
    showInlineCompletionSuggestions: false,
    autoCloseBrackets: false,
    autoCloseQuotes: false,
  },
  markdown: {
    wrapLines: true,
    isLineNumbersEnabled: false,
    enableCodeFolding: false,
    showMinimap: false,
    fontSize: 14,
    lineHeightMultiple: 1.5,
  },
  presentation: {
    fontSize: 18,
    lineHeightMultiple: 1.6,
    isLineNumbersEnabled: false,
    showMinimap: false,
    enableCodeCompletion: false,
    showInlineCompletionSuggestions: false,
    showFoldingControls: false,
    highlightSelectedLine: false,
  },
};

function App({ tweaks, setTweak }) {
  // Apply preset by overlaying onto current tweaks (one-shot when preset changes)
  const lastPreset = React.useRef(tweaks.preset);
  useEffectApp(() => {
    if (lastPreset.current !== tweaks.preset && tweaks.preset !== "default") {
      const overrides = PRESETS[tweaks.preset] || {};
      setTweak(overrides);
    }
    lastPreset.current = tweaks.preset;
  }, [tweaks.preset]);

  const theme = THEMES[tweaks.themeId] || THEMES.xcodeDark;
  const language = tweaks.language;
  const source = SAMPLES[language] || SAMPLES.swift;

  const config = useMemoApp(() => ({
    display: {
      enableSyntaxHighlighting: tweaks.enableSyntaxHighlighting,
      fontSize: tweaks.fontSize,
      isLineNumbersEnabled: tweaks.isLineNumbersEnabled,
      enableAnnotations: tweaks.enableAnnotations,
      highlightSelectedLine: tweaks.highlightSelectedLine,
      showInvisibleCharacters: tweaks.showInvisibleCharacters,
      enableCodeFolding: tweaks.enableCodeFolding,
      showFoldingControls: tweaks.showFoldingControls,
      minimumFoldableLines: tweaks.minimumFoldableLines,
      showMinimap: tweaks.showMinimap,
    },
    layout: {
      tabWidth: tweaks.tabWidth,
      insertSpacesForTabs: tweaks.insertSpacesForTabs,
      wrapLines: tweaks.wrapLines,
      gutterWidth: tweaks.gutterWidth,
      lineNumberPadding: tweaks.lineNumberPadding,
      lineHeightMultiple: tweaks.lineHeightMultiple,
      characterSpacing: tweaks.characterSpacing,
      minimapWidth: tweaks.minimapWidth,
      annotationBadgeSize: tweaks.annotationBadgeSize,
      foldingControlSize: 14,
      foldingControlPadding: 2,
      textContainerInset: { top: 10, right: 12, bottom: 10, left: 8 },
    },
    behavior: {
      isEditable: tweaks.isEditable,
      autoIndent: tweaks.autoIndent,
      enableCodeCompletion: tweaks.enableCodeCompletion,
      showInlineCompletionSuggestions: tweaks.showInlineCompletionSuggestions,
      autoCloseBrackets: tweaks.autoCloseBrackets,
      autoCloseQuotes: tweaks.autoCloseQuotes,
      isContinuousSpellCheckingEnabled: tweaks.isContinuousSpellCheckingEnabled,
    },
    performance: {
      useHardwareAcceleration: tweaks.useHardwareAcceleration,
      smoothScrolling: tweaks.smoothScrolling,
      animateCodeFolding: tweaks.animateCodeFolding,
      renderingUpdateStrategy: tweaks.renderingUpdateStrategy,
      textChangeDebounceInterval: tweaks.textChangeDebounceMs,
      maxSyntaxHighlightingLength: tweaks.maxSyntaxHighlightingLength,
    },
    textChangeMs: tweaks.textChangeDebounceMs,
  }), [tweaks]);

  const fileName = "EditorScreen" + (LANGUAGES.find(l => l.id === language)?.ext || "");

  return (
    <div style={{
      minHeight: "100vh",
      width: "100%",
      background: "#0B0B0D",
      color: "var(--fg1)",
      padding: "32px 28px 60px",
      boxSizing: "border-box",
      fontFamily: "var(--font-sans)",
    }}>
      <Header tweaks={tweaks} setTweak={setTweak} theme={theme} />

      <div data-screen-label="01 macOS Editor" style={{ display: "flex", justifyContent: "center", marginTop: 22 }}>
        <div style={{ width: "min(1280px, 100%)" }}>
          <EditorWindow theme={theme} title={fileName + " — CodeEditorPlugin"}>
            <div style={{ height: 660, display: "flex", background: theme.bg }}>
              <Sidebar theme={theme} fileName={fileName} language={language} setTweak={setTweak} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <CodeEditor
                  config={config}
                  theme={theme}
                  language={language}
                  source={source}
                  fileName={fileName}
                  dirty={true}
                  status="ready"
                />
              </div>
            </div>
          </EditorWindow>

          <ConfigSummary tweaks={tweaks} />
        </div>
      </div>
    </div>
  );
}

/* ----------- Header / brand strip ----------- */
function Header({ tweaks, setTweak, theme }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 16,
      maxWidth: 1280, margin: "0 auto",
    }}>
      <div style={{
        width: 32, height: 32, borderRadius: 7,
        background: "linear-gradient(135deg, #0A84FF, #5E5CE6)",
        display: "flex", alignItems: "center", justifyContent: "center",
        color: "#fff", fontFamily: "var(--font-mono)", fontWeight: 700, fontSize: 14,
      }}>{"<>"}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: "#fff", letterSpacing: -0.2 }}>CodeEditorPlugin</div>
        <div style={{ fontSize: 11, color: "rgba(255,255,255,0.5)", fontFamily: "var(--font-mono)" }}>
          Swift 6 · TextKit 2 · macOS · iOS · Catalyst
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <PresetSwitcher value={tweaks.preset} onChange={(v) => setTweak("preset", v)} />
      <ThemeSwitcher value={tweaks.themeId} onChange={(v) => setTweak("themeId", v)} />
      <LanguageSwitcher value={tweaks.language} onChange={(v) => setTweak("language", v)} />
    </div>
  );
}

function PresetSwitcher({ value, onChange }) {
  const presets = [
    { id: "default", label: "Default" },
    { id: "minimal", label: "Minimal" },
    { id: "readOnly", label: "Read-only" },
    { id: "markdown", label: "Markdown" },
    { id: "presentation", label: "Presentation" },
  ];
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 4,
      padding: 3,
      background: "rgba(255,255,255,0.06)",
      border: "0.5px solid rgba(255,255,255,0.08)",
      borderRadius: 999,
    }}>
      {presets.map(p => (
        <button
          key={p.id}
          onClick={() => onChange(p.id)}
          style={{
            border: 0,
            padding: "5px 11px",
            background: value === p.id ? "rgba(255,255,255,0.12)" : "transparent",
            color: value === p.id ? "#fff" : "rgba(255,255,255,0.7)",
            fontFamily: "var(--font-sans)",
            fontSize: 11, fontWeight: 500,
            borderRadius: 999,
            cursor: "pointer",
          }}
        >{p.label}</button>
      ))}
    </div>
  );
}

function ThemeSwitcher({ value, onChange }) {
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value)}
      style={{
        background: "rgba(255,255,255,0.06)",
        color: "#fff",
        border: "0.5px solid rgba(255,255,255,0.08)",
        borderRadius: 8, padding: "6px 10px",
        fontSize: 11, fontFamily: "var(--font-sans)",
      }}
    >
      {THEME_ORDER.map(id => (
        <option key={id} value={id} style={{ background: "#1c1c1e" }}>{THEMES[id].label}</option>
      ))}
    </select>
  );
}

function LanguageSwitcher({ value, onChange }) {
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value)}
      style={{
        background: "rgba(255,255,255,0.06)",
        color: "#fff",
        border: "0.5px solid rgba(255,255,255,0.08)",
        borderRadius: 8, padding: "6px 10px",
        fontSize: 11, fontFamily: "var(--font-sans)",
      }}
    >
      {LANGUAGES.map(l => (
        <option key={l.id} value={l.id} style={{ background: "#1c1c1e" }}>{l.label}</option>
      ))}
    </select>
  );
}

/* ----------- macOS window shell ----------- */
function EditorWindow({ theme, title, children }) {
  const dark = theme.appearance === "dark";
  const chromeBg = dark ? "#2C2C2E" : "#E8E8E8";
  const chromeFg = dark ? "rgba(255,255,255,0.85)" : "rgba(0,0,0,0.75)";
  const chromeBorder = dark ? "rgba(0,0,0,0.6)" : "rgba(0,0,0,0.18)";
  return (
    <div style={{
      borderRadius: 12,
      overflow: "hidden",
      boxShadow: `0 0 0 0.5px ${chromeBorder}, 0 24px 80px rgba(0,0,0,0.55), 0 6px 20px rgba(0,0,0,0.3)`,
      background: chromeBg,
      fontFamily: "var(--font-sans)",
    }}>
      {/* Title bar */}
      <div style={{
        height: 38, display: "flex", alignItems: "center",
        padding: "0 14px",
        background: chromeBg,
        borderBottom: `0.5px solid ${dark ? "rgba(0,0,0,0.5)" : "rgba(0,0,0,0.12)"}`,
        position: "relative",
      }}>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <span style={{ width: 12, height: 12, borderRadius: "50%", background: "#FF5F57", border: "0.5px solid rgba(0,0,0,0.2)" }} />
          <span style={{ width: 12, height: 12, borderRadius: "50%", background: "#FEBC2E", border: "0.5px solid rgba(0,0,0,0.2)" }} />
          <span style={{ width: 12, height: 12, borderRadius: "50%", background: "#28C840", border: "0.5px solid rgba(0,0,0,0.2)" }} />
        </div>
        <div style={{
          position: "absolute", left: 0, right: 0, textAlign: "center",
          fontSize: 12, fontWeight: 500, color: chromeFg,
          pointerEvents: "none",
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
          padding: "0 120px",
        }}>{title}</div>
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", gap: 6, alignItems: "center", color: chromeFg, fontSize: 11 }}>
          <ToolbarPill dark={dark}>⌘B</ToolbarPill>
          <ToolbarPill dark={dark}>▶</ToolbarPill>
          <ToolbarPill dark={dark}>◧</ToolbarPill>
        </div>
      </div>
      {children}
    </div>
  );
}
function ToolbarPill({ dark, children }) {
  return (
    <span style={{
      minWidth: 26, height: 22, padding: "0 8px",
      display: "inline-flex", alignItems: "center", justifyContent: "center",
      borderRadius: 5,
      background: dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)",
      color: dark ? "rgba(255,255,255,0.7)" : "rgba(0,0,0,0.6)",
      fontSize: 10, fontFamily: "var(--font-mono)",
    }}>{children}</span>
  );
}

/* ----------- Sidebar / file explorer ----------- */
function Sidebar({ theme, fileName, language, setTweak }) {
  const dark = theme.appearance === "dark";
  const sep = dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.06)";
  const tree = [
    { type: "folder", name: "Sources", open: true, indent: 0 },
    { type: "folder", name: "CodeEditorPlugin", open: true, indent: 1 },
    { type: "folder", name: "Configuration", open: true, indent: 2 },
    { type: "file",   name: "EditorConfiguration.swift", indent: 3 },
    { type: "file",   name: "EditorConfiguration+Display.swift", indent: 3 },
    { type: "file",   name: "EditorConfiguration+Layout.swift", indent: 3 },
    { type: "file",   name: "EditorConfiguration+Behavior.swift", indent: 3 },
    { type: "folder", name: "SwiftUI", open: false, indent: 2 },
    { type: "file",   name: "EditorScreen" + (LANGUAGES.find(l => l.id === language)?.ext || ""), indent: 3, active: true },
    { type: "folder", name: "Languages", open: false, indent: 2 },
    { type: "folder", name: "Themes",    open: false, indent: 2 },
    { type: "folder", name: "Tests", open: false, indent: 1 },
  ];
  const items = tree.filter((row, idx) => {
    // hide rows whose ancestor is closed (simple: check immediate parent folder closed)
    let i = idx - 1;
    while (i >= 0) {
      if (tree[i].type === "folder" && tree[i].indent === row.indent - 1) {
        return tree[i].open;
      }
      if (tree[i].indent < row.indent) return true;
      i--;
    }
    return true;
  });

  return (
    <div style={{
      width: 230, flexShrink: 0,
      background: theme.surface,
      borderRight: `0.5px solid ${sep}`,
      display: "flex", flexDirection: "column",
      fontFamily: "var(--font-sans)",
      color: theme.fg,
    }}>
      {/* Sidebar toolbar */}
      <div style={{
        display: "flex", alignItems: "center", gap: 4,
        padding: "8px 10px",
        borderBottom: `0.5px solid ${sep}`,
        height: 38, flexShrink: 0,
      }}>
        <SidebarTab active label="Files" theme={theme} />
        <SidebarTab label="Search" theme={theme} />
        <SidebarTab label="Issues" theme={theme} />
        <div style={{ flex: 1 }} />
        <span style={{ width: 16, height: 16, borderRadius: 3, background: dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.05)", color: theme.fg, fontSize: 11, lineHeight: "16px", textAlign: "center", cursor: "pointer" }}>+</span>
      </div>

      {/* Section header */}
      <div style={{
        padding: "10px 12px 6px", fontSize: 10, fontWeight: 700,
        letterSpacing: 0.6, textTransform: "uppercase",
        color: dark ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.4)",
      }}>
        CodeEditorPlugin
      </div>

      {/* Tree */}
      <div style={{ flex: 1, overflow: "auto", padding: "0 4px 8px" }}>
        {items.map((it, i) => (
          <div
            key={i}
            style={{
              display: "flex", alignItems: "center", gap: 6,
              padding: "3px 8px",
              paddingLeft: 8 + it.indent * 14,
              borderRadius: 4,
              fontSize: 12,
              fontWeight: it.type === "folder" ? 500 : 400,
              color: it.active ? (dark ? "#fff" : "#000") : theme.fg,
              background: it.active ? (dark ? "rgba(10,132,255,0.22)" : "rgba(0,122,255,0.14)") : "transparent",
              cursor: "pointer",
            }}
          >
            <span style={{ width: 10, color: dark ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.4)", fontSize: 9, transform: it.type === "folder" ? (it.open ? "rotate(0deg)" : "rotate(-90deg)") : "none", transition: "transform 150ms" }}>
              {it.type === "folder" ? "▾" : ""}
            </span>
            <span style={{ width: 14, height: 14, fontSize: 11, color: it.type === "folder" ? "#FFD60A" : (dark ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.6)") }}>
              {it.type === "folder" ? "📁" : "📄"}
            </span>
            <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{it.name}</span>
          </div>
        ))}
      </div>

      {/* Quick samples */}
      <div style={{ padding: "8px 12px", borderTop: `0.5px solid ${sep}` }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.6, textTransform: "uppercase", color: dark ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.4)", marginBottom: 6 }}>Sample</div>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
          {LANGUAGES.map(l => (
            <button
              key={l.id}
              onClick={() => setTweak("language", l.id)}
              style={{
                padding: "3px 8px",
                fontSize: 10,
                background: language === l.id ? (dark ? "rgba(10,132,255,0.3)" : "rgba(0,122,255,0.16)") : (dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.04)"),
                color: language === l.id ? (dark ? "#5DD8FF" : "#0066d4") : theme.fg,
                border: 0, borderRadius: 4, cursor: "pointer",
                fontFamily: "var(--font-sans)", fontWeight: 500,
              }}
            >{l.label}</button>
          ))}
        </div>
      </div>
    </div>
  );
}

function SidebarTab({ active, label, theme }) {
  const dark = theme.appearance === "dark";
  return (
    <button style={{
      padding: "4px 8px",
      background: active ? (dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)") : "transparent",
      color: active ? theme.fg : (dark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)"),
      border: 0, borderRadius: 5, fontSize: 11, fontWeight: 500,
      cursor: "pointer",
    }}>{label}</button>
  );
}

/* ----------- Configuration summary card under editor ----------- */
function ConfigSummary({ tweaks }) {
  const lines = [
    `var config = EditorConfiguration()`,
    `config.display.fontSize = ${tweaks.fontSize}`,
    `config.display.isLineNumbersEnabled = ${tweaks.isLineNumbersEnabled}`,
    `config.display.enableCodeFolding = ${tweaks.enableCodeFolding}`,
    `config.display.showFoldingControls = ${tweaks.showFoldingControls}`,
    `config.display.showMinimap = ${tweaks.showMinimap}`,
    `config.layout.tabWidth = ${tweaks.tabWidth}`,
    `config.layout.wrapLines = ${tweaks.wrapLines}`,
    `config.layout.lineHeightMultiple = ${tweaks.lineHeightMultiple}`,
    `config.behavior.autoIndent = ${tweaks.autoIndent}`,
    `config.behavior.enableCodeCompletion = ${tweaks.enableCodeCompletion}`,
    `config.behavior.autoCloseBrackets = ${tweaks.autoCloseBrackets}`,
    `config.performance.useHardwareAcceleration = ${tweaks.useHardwareAcceleration}`,
    `config.performance.renderingUpdateStrategy = .${tweaks.renderingUpdateStrategy}`,
  ];
  return (
    <div style={{
      marginTop: 18,
      background: "rgba(255,255,255,0.04)",
      border: "0.5px solid rgba(255,255,255,0.08)",
      borderRadius: 12,
      overflow: "hidden",
    }}>
      <div style={{
        display: "flex", alignItems: "center", gap: 8,
        padding: "10px 14px",
        borderBottom: "0.5px solid rgba(255,255,255,0.06)",
        fontSize: 12, fontWeight: 600, color: "#fff",
      }}>
        <span style={{ width: 8, height: 8, borderRadius: 2, background: "#5DD8FF" }} />
        Live configuration
        <span style={{ marginLeft: "auto", fontSize: 10, color: "rgba(255,255,255,0.45)", fontFamily: "var(--font-mono)" }}>
          EditorConfiguration.swift
        </span>
      </div>
      <pre style={{
        margin: 0, padding: "12px 16px",
        fontFamily: "var(--font-mono)", fontSize: 12, lineHeight: 1.55,
        color: "rgba(255,255,255,0.85)",
      }}>
        {lines.map((l, i) => {
          const m = l.match(/^(.*?=\s*)(.*)$/);
          if (m) {
            return (
              <div key={i}><span style={{ color: "rgba(255,255,255,0.55)" }}>{m[1]}</span><span style={{ color: "#FC5FA3" }}>{m[2]}</span></div>
            );
          }
          return <div key={i} style={{ color: "#5DD8FF" }}>{l}</div>;
        })}
      </pre>
    </div>
  );
}

/* ----------- Tweaks panel ----------- */
function TweaksPanelContent() {
  return null;
}

function AppWithTweaks() {
  const [tweaks, setTweak] = useTweaks(DEFAULTS);
  // We need to share the same tweaks state with App. Easiest: lift to module scope.
  return null; // not used — App uses its own useTweaks call
}

/* TweaksPanel shows controls for every config knob. */
function CodeEditorTweaks({ tweaks, setTweak }) {
  return (
    <TweaksPanel title="Tweaks · EditorConfiguration" defaultPosition={{ right: 24, bottom: 24 }} width={320}>
      <TweakSection title="Theme & Language">
        <TweakSelect label="Theme"     value={tweaks.themeId}  onChange={(v) => setTweak("themeId", v)}  options={THEME_ORDER.map(id => ({ value: id, label: THEMES[id].label }))} />
        <TweakSelect label="Language"  value={tweaks.language} onChange={(v) => setTweak("language", v)} options={LANGUAGES.map(l => ({ value: l.id, label: l.label }))} />
        <TweakSelect label="Preset"    value={tweaks.preset}   onChange={(v) => setTweak("preset", v)}   options={[
          { value: "default", label: "Default" },
          { value: "minimal", label: "Minimal" },
          { value: "readOnly", label: "Read-only" },
          { value: "markdown", label: "Markdown" },
          { value: "presentation", label: "Presentation" },
        ]} />
      </TweakSection>

      <TweakSection title="Display">
        <TweakSlider label="Font size" value={tweaks.fontSize} onChange={(v) => setTweak("fontSize", v)} min={9} max={24} step={1} />
        <TweakToggle label="Line numbers"               value={tweaks.isLineNumbersEnabled} onChange={(v) => setTweak("isLineNumbersEnabled", v)} />
        <TweakToggle label="Highlight selected line"    value={tweaks.highlightSelectedLine} onChange={(v) => setTweak("highlightSelectedLine", v)} />
        <TweakToggle label="Annotations (TODO/FIXME)"   value={tweaks.enableAnnotations} onChange={(v) => setTweak("enableAnnotations", v)} />
        <TweakToggle label="Syntax highlighting"        value={tweaks.enableSyntaxHighlighting} onChange={(v) => setTweak("enableSyntaxHighlighting", v)} />
        <TweakToggle label="Show invisible characters"  value={tweaks.showInvisibleCharacters} onChange={(v) => setTweak("showInvisibleCharacters", v)} />
        <TweakToggle label="Code folding"               value={tweaks.enableCodeFolding} onChange={(v) => setTweak("enableCodeFolding", v)} />
        <TweakToggle label="Fold gutter controls"       value={tweaks.showFoldingControls} onChange={(v) => setTweak("showFoldingControls", v)} />
        <TweakSlider label="Min foldable lines"         value={tweaks.minimumFoldableLines} onChange={(v) => setTweak("minimumFoldableLines", v)} min={1} max={10} step={1} />
        <TweakToggle label="Minimap"                    value={tweaks.showMinimap} onChange={(v) => setTweak("showMinimap", v)} />
      </TweakSection>

      <TweakSection title="Layout">
        <TweakSlider label="Tab width"          value={tweaks.tabWidth} onChange={(v) => setTweak("tabWidth", v)} min={1} max={8} step={1} />
        <TweakToggle label="Insert spaces for tabs" value={tweaks.insertSpacesForTabs} onChange={(v) => setTweak("insertSpacesForTabs", v)} />
        <TweakToggle label="Wrap lines"          value={tweaks.wrapLines} onChange={(v) => setTweak("wrapLines", v)} />
        <TweakSlider label="Gutter width"        value={tweaks.gutterWidth} onChange={(v) => setTweak("gutterWidth", v)} min={28} max={80} step={2} />
        <TweakSlider label="Line number padding" value={tweaks.lineNumberPadding} onChange={(v) => setTweak("lineNumberPadding", v)} min={2} max={16} step={1} />
        <TweakSlider label="Line height ×"       value={tweaks.lineHeightMultiple} onChange={(v) => setTweak("lineHeightMultiple", v)} min={1} max={2} step={0.05} />
        <TweakSlider label="Char spacing"        value={tweaks.characterSpacing} onChange={(v) => setTweak("characterSpacing", v)} min={-1} max={3} step={0.1} />
        <TweakSlider label="Minimap width"       value={tweaks.minimapWidth} onChange={(v) => setTweak("minimapWidth", v)} min={60} max={180} step={4} />
      </TweakSection>

      <TweakSection title="Behavior">
        <TweakToggle label="Editable"             value={tweaks.isEditable} onChange={(v) => setTweak("isEditable", v)} />
        <TweakToggle label="Auto indent"          value={tweaks.autoIndent} onChange={(v) => setTweak("autoIndent", v)} />
        <TweakToggle label="Code completion"      value={tweaks.enableCodeCompletion} onChange={(v) => setTweak("enableCodeCompletion", v)} />
        <TweakToggle label="Inline suggestions"   value={tweaks.showInlineCompletionSuggestions} onChange={(v) => setTweak("showInlineCompletionSuggestions", v)} />
        <TweakToggle label="Auto-close brackets"  value={tweaks.autoCloseBrackets} onChange={(v) => setTweak("autoCloseBrackets", v)} />
        <TweakToggle label="Auto-close quotes"    value={tweaks.autoCloseQuotes} onChange={(v) => setTweak("autoCloseQuotes", v)} />
        <TweakToggle label="Continuous spell check" value={tweaks.isContinuousSpellCheckingEnabled} onChange={(v) => setTweak("isContinuousSpellCheckingEnabled", v)} />
      </TweakSection>

      <TweakSection title="Performance">
        <TweakToggle label="Hardware acceleration" value={tweaks.useHardwareAcceleration} onChange={(v) => setTweak("useHardwareAcceleration", v)} />
        <TweakToggle label="Smooth scrolling"      value={tweaks.smoothScrolling} onChange={(v) => setTweak("smoothScrolling", v)} />
        <TweakToggle label="Animate folding"       value={tweaks.animateCodeFolding} onChange={(v) => setTweak("animateCodeFolding", v)} />
        <TweakRadio  label="Render strategy" value={tweaks.renderingUpdateStrategy} onChange={(v) => setTweak("renderingUpdateStrategy", v)} options={[
          { value: "immediate", label: "Imm." },
          { value: "batched",   label: "Batched" },
          { value: "adaptive",  label: "Adaptive" },
        ]} />
        <TweakSlider label="Debounce (ms)" value={tweaks.textChangeDebounceMs} onChange={(v) => setTweak("textChangeDebounceMs", v)} min={0} max={500} step={10} />
        <TweakNumber label="Max highlight length" value={tweaks.maxSyntaxHighlightingLength} onChange={(v) => setTweak("maxSyntaxHighlightingLength", v)} min={10000} max={5000000} step={50000} />
      </TweakSection>
    </TweaksPanel>
  );
}

/* Mount: render App + Tweaks. They each call useTweaks(DEFAULTS) which the
   tweaks-panel hook persists via parent postMessage so they stay in sync. */
function Root() {
  const [tweaks, setTweak] = useTweaks(DEFAULTS);
  return (
    <>
      <App tweaks={tweaks} setTweak={setTweak} />
      <CodeEditorTweaks tweaks={tweaks} setTweak={setTweak} />
      <style>{`
        @keyframes ce-caret-blink {
          0%, 49% { opacity: 1; }
          50%, 100% { opacity: 0; }
        }
      `}</style>
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<Root />);
