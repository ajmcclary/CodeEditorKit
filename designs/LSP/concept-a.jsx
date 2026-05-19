// LSP · CONCEPT A — "STATUS"
// The casual-operator view.  An editor that happens to talk to language
// servers.  The status bar carries one pip per LSP-managed language; the
// active server's pip is amber (.initializing), green (.initialized),
// or red (.error).  Clicking the pip opens a slim popover anchored to
// the status bar showing connection state, capabilities, and last
// activity. Everything else lives in the editor.

const LspA = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, StatusPill, Pill, Kbd } = window;
  const { useState } = React;

  // Each server's runtime state.  LSPClient.ConnectionState verbatim.
  const SERVERS = [
    { id: "swift",  name: "sourcekit-lsp",         lang: "Swift",      state: "initialized",  uptime: "12 m",   rtt: 14, docs: 4, transport: "local",  path: "/usr/bin/sourcekit-lsp" },
    { id: "ts",     name: "typescript-language-server", lang: "TypeScript", state: "initialized", uptime: "12 m", rtt: 22, docs: 7, transport: "local",  path: "/usr/local/bin/tsserver" },
    { id: "py",     name: "pylsp",                 lang: "Python",     state: "initialized",  uptime: "12 m",   rtt: 19, docs: 2, transport: "local",  path: "/opt/homebrew/bin/pylsp" },
    { id: "rust",   name: "rust-analyzer · remote", lang: "Rust",      state: "initializing", uptime: "00 s",   rtt: null, docs: 0, transport: "ws",     path: "wss://lsp.acme.dev/rust" },
    { id: "go",     name: "gopls",                 lang: "Go",         state: "error",        uptime: "—",      rtt: null, docs: 0, transport: "local",  path: "/usr/local/bin/gopls", reason: "exit code 1 · 'workspace folder not found'" },
  ];

  const CAPS = [
    { id: "completion",     label: "Completion",          on: true,  detail: "trigger '.': true · resolveProvider" },
    { id: "hover",          label: "Hover",                on: true,  detail: "contentFormat: markdown" },
    { id: "definition",     label: "Go-to Definition",     on: true,  detail: "definitionProvider" },
    { id: "documentSymbol", label: "Document Symbols",     on: true,  detail: "hierarchicalDocumentSymbolSupport" },
    { id: "semantic",       label: "Semantic Tokens",      on: true,  detail: "range · full · delta" },
    { id: "rename",         label: "Rename",               on: false, detail: "renameProvider: false" },
    { id: "formatting",     label: "Formatting",           on: false, detail: "documentFormattingProvider: false" },
  ];

  // Recent log lines for the active server.
  const TRAIL = [
    { t: "+0.04", lvl: "INFO",  msg: "Initialized with 5 workspace folders" },
    { t: "+0.18", lvl: "INFO",  msg: "textDocument/didOpen Annotation.swift" },
    { t: "+0.21", lvl: "INFO",  msg: "publishDiagnostics → 3 items" },
    { t: "+0.94", lvl: "INFO",  msg: "textDocument/completion (ann) → 8 items in 18 ms" },
    { t: "+1.40", lvl: "WARN",  msg: "semanticTokens/full/delta · resultId stale, refetched full" },
    { t: "+1.42", lvl: "INFO",  msg: "publishDiagnostics → 0 items" },
  ];

  function ServerPip({ s, active, onClick }) {
    const color = s.state === "initialized" ? "var(--status-success)"
      : s.state === "initializing" || s.state === "connecting" ? "var(--status-warning)"
      : s.state === "error" ? "var(--status-error)" : "var(--text-muted)";
    return (
      <button onClick={onClick} title={`${s.name} · ${s.state}`} style={{
        display: "inline-flex", alignItems: "center", gap: 4,
        height: 18, padding: "0 7px",
        borderRadius: 9, border: "none", cursor: "pointer",
        background: active ? "var(--element-selected)" : "transparent",
        color: "var(--text-muted)",
        font: "10.5px var(--font-mono)",
      }}>
        <span style={{
          width: 6, height: 6, borderRadius: "50%", background: color,
          boxShadow: s.state === "initialized" ? `0 0 6px ${color}` : "none",
        }}/>
        {s.lang}
      </button>
    );
  }

  function Popover({ s, onClose }) {
    return (
      <div style={{
        position: "absolute", bottom: 26, left: 76, zIndex: 5,
        width: 480,
        background: "var(--elevated)",
        borderRadius: 10,
        boxShadow: "inset 0 0 0 0.5px var(--border), 0 12px 36px rgba(0,0,0,0.45)",
        backdropFilter: "blur(10px)",
        overflow: "hidden",
      }}>
        {/* Header */}
        <div style={{ padding: "10px 12px",
          borderBottom: "0.5px solid var(--border-variant)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span style={{
              width: 28, height: 28, borderRadius: 6,
              background: "color-mix(in srgb, var(--accent-1) 18%, transparent)",
              color: "var(--accent-1)",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}><Ic.Server size={14}/></span>
            <div style={{ flex: 1 }}>
              <div style={{ font: "600 13px var(--font-sans)", color: "var(--text)" }}>
                {s.name}
              </div>
              <div style={{ font: "11px var(--font-mono)", color: "var(--text-muted)" }}>
                {s.transport === "ws"
                  ? <><Ic.Globe size={10}/> {s.path}</>
                  : <><Ic.Server size={10}/> {s.path}</>}
              </div>
            </div>
            <StatusPill state={s.state}/>
            <button onClick={onClose} style={iconBtn}><Ic.X size={12}/></button>
          </div>
          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(4, 1fr)",
            marginTop: 10, gap: 8,
          }}>
            {[
              { l: "Language", v: s.lang },
              { l: "Transport", v: s.transport === "ws" ? "WebSocket" : "Process" },
              { l: "RTT", v: s.rtt ? `${s.rtt} ms` : "—" },
              { l: "Docs", v: s.docs ?? "—" },
            ].map(b => (
              <div key={b.l} style={{
                padding: "6px 8px", borderRadius: 6,
                background: "color-mix(in srgb, var(--bg) 70%, transparent)",
                boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
              }}>
                <div style={{
                  font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
                  color: "var(--text-muted)",
                }}>{b.l}</div>
                <div style={{ font: "600 13px var(--font-mono)", color: "var(--text)", marginTop: 1 }}>{b.v}</div>
              </div>
            ))}
          </div>
        </div>

        {s.state === "error" && (
          <div style={{
            padding: "8px 12px",
            background: "color-mix(in srgb, var(--status-error) 10%, transparent)",
            borderBottom: "0.5px solid var(--border-variant)",
            display: "flex", alignItems: "center", gap: 8,
            font: "12px var(--font-mono)", color: "var(--status-error)",
          }}>
            <Ic.Error size={13}/> {s.reason}
          </div>
        )}

        {/* Capabilities */}
        <div style={{ padding: "10px 12px" }}>
          <div style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
            color: "var(--text-muted)", marginBottom: 6 }}>CAPABILITIES</div>
          <div style={{
            display: "grid", gridTemplateColumns: "1fr 1fr", rowGap: 4, columnGap: 10,
          }}>
            {CAPS.map(c => (
              <div key={c.id} style={{
                display: "flex", alignItems: "center", gap: 6,
                font: "12px var(--font-sans)", color: c.on ? "var(--text)" : "var(--text-disabled)",
              }}>
                {c.on ? (
                  <span style={{ color: "var(--status-success)" }}><Ic.Check size={11}/></span>
                ) : (
                  <span style={{ color: "var(--text-disabled)" }}><Ic.X size={11}/></span>
                )}
                <span style={{ flex: 1 }}>{c.label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Footer actions */}
        <div style={{
          display: "flex", alignItems: "center", gap: 8,
          padding: "8px 12px",
          background: "color-mix(in srgb, var(--bg) 50%, transparent)",
          borderTop: "0.5px solid var(--border-variant)",
        }}>
          <Pill size="sm" icon={<Ic.Rotate size={11}/>}>{s.state === "error" ? "Retry" : "Restart"}</Pill>
          <Pill size="sm" icon={<Ic.Eye size={11}/>}>Open Trace</Pill>
          <Pill size="sm" icon={<Ic.Activity size={11}/>}>Diagnostics</Pill>
          <span style={{ flex: 1 }}/>
          <span style={{ font: "10.5px var(--font-sans)", color: "var(--text-muted)" }}>uptime <span style={{ color: "var(--text)" }}>{s.uptime}</span></span>
        </div>
      </div>
    );
  }
  const iconBtn = {
    width: 22, height: 22, border: "none", borderRadius: 5, cursor: "pointer",
    background: "transparent", color: "var(--text-muted)",
    display: "flex", alignItems: "center", justifyContent: "center",
  };

  function Editor() {
    return (
      <div style={{ flex: 1, minHeight: 0, background: "var(--editor-bg)",
        padding: "12px 0", position: "relative" }}>
        {[
          { n: 41, c: <><Tk.K>func</Tk.K> <Tk.F>register</Tk.F>(<Tk.V>_</Tk.V> store<Tk.Pn>:</Tk.Pn> <Tk.T>AnnotationStore</Tk.T>) <Tk.Pn>{"{"}</Tk.Pn></> },
          { n: 42, c: <>{"    "}store.<Tk.F>removeAll</Tk.F>()</> },
          { n: 43, c: <>{"    "}<Tk.K>let</Tk.K> ann <Tk.Pn>=</Tk.Pn> <Tk.T>Annotation</Tk.T>(<Tk.V>range</Tk.V>: r, <Tk.V>content</Tk.V>: c, <Tk.V>kind</Tk.V>: .warning)</> },
          { n: 44, c: <>{"    "}store.<Tk.F>insert</Tk.F>(ann)</> },
          { n: 45, c: <Tk.Pn>{"}"}</Tk.Pn> },
          { n: 46, c: " " },
          { n: 47, c: <><Tk.C>{"// Server-driven semantic tokens — RingBuffer-backed delta sync"}</Tk.C></> },
          { n: 48, c: <><Tk.K>extension</Tk.K> <Tk.T>LSPClient</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
          { n: 49, c: <>{"    "}<Tk.K>func</Tk.K> <Tk.F>requestSemanticTokens</Tk.F>(<Tk.V>uri</Tk.V><Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T>) <Tk.K>async throws</Tk.K> <Tk.Pn>{"->"}</Tk.Pn> <Tk.T>SemanticTokens</Tk.T><Tk.Pn>?</Tk.Pn> <Tk.Pn>{"{"}</Tk.Pn> … <Tk.Pn>{"}"}</Tk.Pn></> },
          { n: 50, c: <Tk.Pn>{"}"}</Tk.Pn> },
        ].map(l => (
          <div key={l.n} style={{
            display: "grid", gridTemplateColumns: "44px 1fr", alignItems: "center", minHeight: 21,
          }}>
            <span style={{
              textAlign: "right", paddingRight: 8,
              font: "12px var(--font-mono)", color: "var(--line-num)",
            }}>{l.n}</span>
            <code style={{
              whiteSpace: "pre", color: "var(--editor-fg)",
              font: "12px/1.55 var(--font-mono)",
            }}>{l.c}</code>
          </div>
        ))}

        {/* Floating activity strip */}
        <div style={{
          position: "absolute", top: 10, right: 12,
          display: "flex", alignItems: "center", gap: 6,
          padding: "5px 10px", borderRadius: 999,
          background: "var(--elevated)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant), 0 4px 12px rgba(0,0,0,0.25)",
          font: "11px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <Ic.Activity size={12}/>
          textDocument/completion · <span style={{ color: "var(--accent-1)" }}>18 ms</span>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [openId, setOpen] = useState("swift");
    const sActive = SERVERS.find(s => s.id === openId);
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Annotation.swift" subtitle="CodeEditorLSP"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <Editor/>
        {openId && <Popover s={sActive} onClose={() => setOpen(null)}/>}
        <div style={{
          height: 26, flexShrink: 0, display: "flex", alignItems: "center", gap: 4, padding: "0 8px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span style={{ marginRight: 4 }}><Ic.Server size={11}/></span>
          {SERVERS.map(s => (
            <ServerPip key={s.id} s={s} active={openId === s.id}
              onClick={() => setOpen(openId === s.id ? null : s.id)}/>
          ))}
          <span style={{ flex: 1 }}/>
          <span>{TRAIL[TRAIL.length - 1].lvl}</span>
          <span style={{ color: "var(--text)" }}>{TRAIL[TRAIL.length - 1].msg}</span>
          <span>·</span>
          <span>{TRAIL[TRAIL.length - 1].t} s</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.LspA = LspA;
