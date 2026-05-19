// LSP · CONCEPT B — "WORKBENCH"
// The operator's full panel.  Triptych:
//   Left   · server registry — every LanguageServerConfig the host has
//            registered, with state, transport, uptime, queued requests.
//   Centre · the active server's capabilities matrix + connection card +
//            recent diagnostics.
//   Right  · the live log/trace tail (window/logMessage notifications)
// The chrome is its own window — i.e. this isn't the editor.  Surfaced
// from the editor via ⌘⇧L "Show Language Servers".

const LspB = (() => {
  const { Ic, WindowFrame, TitleBar, ThemeSwitch, StatusPill, Pill, Overline, Kbd, Segmented } = window;
  const { useState } = React;

  const SERVERS = [
    { id: "swift",  name: "sourcekit-lsp",                state: "initialized",  transport: "local",  lang: "Swift",      uptime: "12 m 04 s", path: "/usr/bin/sourcekit-lsp",          docs: 4, rtt: 14, queued: 0 },
    { id: "ts",     name: "typescript-language-server",   state: "initialized",  transport: "local",  lang: "TypeScript", uptime: "12 m 04 s", path: "/usr/local/bin/tsserver",         docs: 7, rtt: 22, queued: 0 },
    { id: "py",     name: "pylsp",                        state: "initialized",  transport: "local",  lang: "Python",     uptime: "12 m 04 s", path: "/opt/homebrew/bin/pylsp",         docs: 2, rtt: 19, queued: 1 },
    { id: "rust",   name: "rust-analyzer (remote)",       state: "initializing", transport: "ws",     lang: "Rust",       uptime: "00 s",      path: "wss://lsp.acme.dev/rust",         docs: 0, rtt: null, queued: 0 },
    { id: "go",     name: "gopls",                        state: "error",        transport: "local",  lang: "Go",         uptime: "—",         path: "/usr/local/bin/gopls",            docs: 0, rtt: null, queued: 0 },
    { id: "json",   name: "vscode-json-languageserver",   state: "disconnected", transport: "local",  lang: "JSON",       uptime: "—",         path: "/usr/local/bin/json-ls",          docs: 0, rtt: null, queued: 0 },
  ];

  const CAPS = [
    { id: "completion",       label: "Completion",          on: true,  detail: "trigger '.' '(' ':' ' ' · resolveProvider" },
    { id: "hover",            label: "Hover",               on: true,  detail: "contentFormat: markdown" },
    { id: "definition",       label: "Go-to Definition",    on: true,  detail: "" },
    { id: "documentSymbol",   label: "Document Symbols",    on: true,  detail: "hierarchical" },
    { id: "semanticTokens",   label: "Semantic Tokens",     on: true,  detail: "range · full · delta" },
    { id: "diagnostics",      label: "Diagnostics (push)",  on: true,  detail: "publishDiagnostics" },
    { id: "rename",           label: "Rename",              on: false, detail: "renameProvider: false" },
    { id: "formatting",       label: "Formatting",          on: false, detail: "" },
    { id: "references",       label: "References",          on: true,  detail: "" },
    { id: "codeAction",       label: "Code Action",         on: true,  detail: "kinds: quickfix · refactor" },
    { id: "signatureHelp",    label: "Signature Help",      on: true,  detail: "trigger '(' ','" },
    { id: "workspaceSymbol",  label: "Workspace Symbols",   on: false, detail: "" },
  ];

  const TRAIL = [
    { t: "12:04:18.040", lvl: "INFO",  msg: "client/initialize → workspace folders: 5",  prov: "sourcekit-lsp" },
    { t: "12:04:18.180", lvl: "INFO",  msg: "textDocument/didOpen Annotation.swift",     prov: "sourcekit-lsp" },
    { t: "12:04:18.210", lvl: "INFO",  msg: "textDocument/publishDiagnostics → 3 items", prov: "sourcekit-lsp" },
    { t: "12:04:18.940", lvl: "INFO",  msg: "textDocument/completion (\"ann\") → 8 in 18 ms", prov: "sourcekit-lsp" },
    { t: "12:04:19.400", lvl: "WARN",  msg: "semanticTokens/full/delta · resultId stale, refetched full", prov: "sourcekit-lsp" },
    { t: "12:04:20.110", lvl: "INFO",  msg: "textDocument/hover Line 21 Col 38",         prov: "sourcekit-lsp" },
    { t: "12:04:20.245", lvl: "INFO",  msg: "ws://lsp.acme.dev/rust · TLS 1.3 negotiated, cert pinned", prov: "rust-analyzer" },
    { t: "12:04:20.305", lvl: "WARN",  msg: "ws://lsp.acme.dev/rust · server taking >2s to respond initialize", prov: "rust-analyzer" },
    { t: "12:04:21.310", lvl: "ERROR", msg: "gopls · process exited 1: workspace folder not found", prov: "gopls" },
    { t: "12:04:22.030", lvl: "INFO",  msg: "textDocument/definition → 1 location",      prov: "typescript-language-server" },
    { t: "12:04:22.120", lvl: "INFO",  msg: "textDocument/codeAction → 4 actions",       prov: "sourcekit-lsp" },
  ];

  const DIAG = [
    { uri: "Annotation.swift",     line: 21, sev: "error",   code: "missing_argument", msg: "Value of optional type 'AnnotationKind?' must be unwrapped." },
    { uri: "Annotation.swift",     line: 27, sev: "warning", code: "nested_recursion", msg: "Resolved kind may recurse when content starts with 'TODO: error in …'." },
    { uri: "AnnotationView.swift", line: 78, sev: "warning", code: "force_unwrap",     msg: "Force-unwrap of NSImage." },
  ];

  function ServerRail({ activeId, setActive }) {
    return (
      <div style={{
        width: 232, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px 6px", display: "flex", alignItems: "center", gap: 6 }}>
          <Overline>LANGUAGE SERVERS</Overline>
          <span style={{ flex: 1 }}/>
          <button style={iconBtn} title="Add"><Ic.Plus size={11}/></button>
        </div>
        <div style={{ padding: "0 6px", display: "flex", flexDirection: "column", gap: 1 }}>
          {SERVERS.map(s => {
            const active = activeId === s.id;
            const stateC = s.state === "initialized" ? "var(--status-success)"
              : s.state === "initializing" ? "var(--status-warning)"
              : s.state === "error" ? "var(--status-error)" : "var(--text-disabled)";
            return (
              <div key={s.id} onClick={() => setActive(s.id)} style={{
                position: "relative",
                display: "grid", gridTemplateColumns: "10px 1fr auto", gap: 8,
                padding: "7px 9px", borderRadius: 6, cursor: "pointer",
                background: active ? "var(--element-selected)" : "transparent",
                boxShadow: active ? "inset 2px 0 0 0 var(--accent-1)" : "none",
              }}>
                <span style={{
                  width: 6, height: 6, borderRadius: "50%", background: stateC,
                  boxShadow: s.state === "initialized" ? `0 0 6px ${stateC}` : "none",
                  alignSelf: "center",
                }}/>
                <div style={{ minWidth: 0 }}>
                  <div style={{
                    font: `${active ? 600 : 500} 12px var(--font-sans)`,
                    color: "var(--text)",
                    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                  }}>{s.lang}</div>
                  <div style={{
                    font: "10.5px var(--font-mono)", color: "var(--text-muted)",
                    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                  }}>{s.name}</div>
                </div>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 1 }}>
                  <span style={{
                    font: "500 9.5px var(--font-sans)", letterSpacing: 0.4, textTransform: "uppercase",
                    color: stateC,
                  }}>{s.state}</span>
                  <span style={{
                    font: "9.5px var(--font-mono)", color: "var(--text-disabled)",
                  }}>{s.transport === "ws" ? <><Ic.Globe size={9}/></> : <><Ic.Server size={9}/></>} {s.docs} docs</span>
                </div>
              </div>
            );
          })}
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{
          margin: 8, padding: 10, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        }}>
          <Overline>HEALTH</Overline>
          <div style={{
            font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 6,
            display: "grid", gridTemplateColumns: "1fr auto", rowGap: 3,
          }}>
            <span>up</span><span style={{ color: "var(--status-success)" }}>3</span>
            <span>negotiating</span><span style={{ color: "var(--status-warning)" }}>1</span>
            <span>errored</span><span style={{ color: "var(--status-error)" }}>1</span>
            <span>off</span><span style={{ color: "var(--text-disabled)" }}>1</span>
          </div>
        </div>
      </div>
    );
  }
  const iconBtn = {
    width: 22, height: 22, border: "none", borderRadius: 5, cursor: "pointer",
    background: "transparent", color: "var(--text-muted)",
    display: "flex", alignItems: "center", justifyContent: "center",
  };

  function ServerDetail({ s }) {
    return (
      <div style={{ flex: 1, minWidth: 0, minHeight: 0, overflowY: "auto", background: "var(--bg)" }}>
        {/* Header card */}
        <div style={{ padding: "14px 16px",
          background: "var(--surface)",
          borderBottom: "0.5px solid var(--border-variant)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span style={{
              width: 30, height: 30, borderRadius: 7,
              background: "color-mix(in srgb, var(--accent-1) 18%, transparent)",
              color: "var(--accent-1)",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}><Ic.Server size={15}/></span>
            <div style={{ flex: 1 }}>
              <div style={{ font: "700 18px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>
                {s.name}
              </div>
              <div style={{ font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 3 }}>
                {s.transport === "ws"
                  ? <span><Ic.Globe size={10}/> {s.path} · WebSocket · TLS 1.2+</span>
                  : <span><Ic.Server size={10}/> {s.path} · Process · stdio</span>}
              </div>
            </div>
            <StatusPill state={s.state}/>
          </div>
          {s.state === "error" ? (
            <div style={{
              marginTop: 10, padding: "8px 10px", borderRadius: 6,
              background: "color-mix(in srgb, var(--status-error) 10%, transparent)",
              boxShadow: "inset 0 0 0 0.5px var(--status-error)",
              display: "flex", alignItems: "center", gap: 8,
              font: "12px var(--font-mono)", color: "var(--status-error)",
            }}><Ic.Error size={13}/> exit code 1 — workspace folder not found</div>
          ) : null}
          <div style={{
            display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8, marginTop: 10,
          }}>
            {[
              { l: "Uptime",        v: s.uptime },
              { l: "Open docs",     v: s.docs },
              { l: "RTT (median)",  v: s.rtt ? `${s.rtt} ms` : "—" },
              { l: "Queued",        v: s.queued },
            ].map(b => (
              <div key={b.l} style={cardBox}>
                <div style={{ font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase", color: "var(--text-muted)" }}>{b.l}</div>
                <div style={{ font: "600 17px var(--font-mono)", color: "var(--text)", marginTop: 2 }}>{b.v}</div>
              </div>
            ))}
          </div>
          <div style={{ display: "flex", gap: 6, marginTop: 10 }}>
            <Pill size="sm" icon={<Ic.Rotate size={11}/>}>{s.state === "error" ? "Retry" : "Restart"}</Pill>
            <Pill size="sm" icon={<Ic.Plug size={11}/>}>Disconnect</Pill>
            <Pill size="sm" icon={<Ic.Bolt size={11}/>}>Reinitialize</Pill>
            <Pill size="sm" icon={<Ic.Eye size={11}/>}>Open Trace</Pill>
            <span style={{ flex: 1 }}/>
            <Pill size="sm" icon={<Ic.Lock size={11}/>}>{s.transport === "ws" ? "Cert pinning" : "Sandboxed"}</Pill>
          </div>
        </div>

        {/* Capabilities grid */}
        <div style={{ padding: "12px 16px" }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
            <Overline>SERVER CAPABILITIES</Overline>
            <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
              · {CAPS.filter(c => c.on).length} / {CAPS.length} active
            </span>
          </div>
          <div style={{
            marginTop: 8,
            display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 6,
          }}>
            {CAPS.map(c => (
              <div key={c.id} style={{
                padding: "6px 9px", borderRadius: 6,
                background: c.on
                  ? "color-mix(in srgb, var(--status-success) 6%, transparent)"
                  : "var(--element-bg)",
                boxShadow: c.on
                  ? "inset 0 0 0 0.5px color-mix(in srgb, var(--status-success) 35%, transparent)"
                  : "inset 0 0 0 0.5px var(--border-variant)",
                display: "grid", gridTemplateColumns: "16px 1fr", gap: 8, alignItems: "center",
              }}>
                <span style={{ color: c.on ? "var(--status-success)" : "var(--text-disabled)",
                  display: "flex", alignItems: "center", justifyContent: "center" }}>
                  {c.on ? <Ic.Check size={11}/> : <Ic.X size={11}/>}
                </span>
                <div style={{ minWidth: 0 }}>
                  <div style={{ font: "500 12px var(--font-sans)", color: c.on ? "var(--text)" : "var(--text-muted)" }}>{c.label}</div>
                  {c.detail ? <div style={{
                    font: "10.5px var(--font-mono)", color: "var(--text-muted)",
                    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                  }}>{c.detail}</div> : null}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Diagnostics tail */}
        <div style={{ padding: "0 16px 16px" }}>
          <Overline>PUBLISH DIAGNOSTICS · {DIAG.length} active</Overline>
          <div style={{
            marginTop: 6,
            borderRadius: 8,
            background: "var(--surface)",
            boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
          }}>
            {DIAG.map((d, i) => (
              <div key={i} style={{
                padding: "8px 10px",
                borderTop: i ? "0.5px solid var(--border-variant)" : "none",
                display: "grid", gridTemplateColumns: "8px 1fr auto auto", gap: 8, alignItems: "center",
              }}>
                <span style={{
                  width: 6, height: 6, borderRadius: "50%",
                  background: d.sev === "error" ? "var(--diag-error)" : "var(--diag-warning)",
                }}/>
                <div style={{ minWidth: 0 }}>
                  <div style={{ font: "12px var(--font-sans)", color: "var(--text)" }}>{d.msg}</div>
                  <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
                    {d.uri}:{d.line}
                  </div>
                </div>
                <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-disabled)" }}>{d.code}</span>
                <Pill size="sm">Reveal</Pill>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }
  const cardBox = {
    padding: "8px 10px", borderRadius: 6,
    background: "var(--bg)",
    boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
  };

  function Trace({ filter, setFilter }) {
    const filtered = filter === "all" ? TRAIL : TRAIL.filter(t => t.lvl === filter.toUpperCase());
    return (
      <div style={{
        width: 288, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "10px 12px 6px", display: "flex", alignItems: "center", gap: 6 }}>
          <Overline>LOG · TRACE</Overline>
          <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)", marginLeft: 4 }}>{TRAIL.length}</span>
          <span style={{ flex: 1 }}/>
          <span style={{
            display: "inline-flex", alignItems: "center", gap: 5,
            font: "11px var(--font-mono)", color: "var(--status-success)",
          }}>
            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--status-success)", boxShadow: "0 0 6px var(--status-success)" }}/>
            live
          </span>
        </div>
        <div style={{
          display: "flex", gap: 4, padding: "4px 10px 8px",
          borderBottom: "0.5px solid var(--border-variant)",
        }}>
          {["all", "info", "warn", "error"].map(f => (
            <Pill key={f} size="sm" active={filter === f} onClick={() => setFilter(f)}>{f.toUpperCase()}</Pill>
          ))}
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "6px 0" }}>
          {filtered.map((t, i) => {
            const c = t.lvl === "WARN" ? "var(--status-warning)" : t.lvl === "ERROR" ? "var(--status-error)" : "var(--text-muted)";
            return (
              <div key={i} style={{ padding: "5px 12px",
                font: "11px var(--font-mono)", color: "var(--text-muted)" }}>
                <div style={{ display: "flex", gap: 6, alignItems: "baseline" }}>
                  <span style={{ color: "var(--text-disabled)" }}>{t.t.slice(8)}</span>
                  <span style={{
                    font: "700 9.5px var(--font-sans)", letterSpacing: 0.6, textTransform: "uppercase",
                    color: c, padding: "0 5px", borderRadius: 3,
                    background: `color-mix(in srgb, ${c} 14%, transparent)`,
                  }}>{t.lvl}</span>
                  <span style={{ color: "var(--text-disabled)" }}>{t.prov}</span>
                </div>
                <div style={{ color: "var(--text)", marginTop: 2, lineHeight: 1.45 }}>{t.msg}</div>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [activeId, setActive] = useState("swift");
    const [filter, setFilter] = useState("all");
    const s = SERVERS.find(s => s.id === activeId);
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Language Servers" subtitle="CodeEditorLSP"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <ServerRail activeId={activeId} setActive={setActive}/>
          <ServerDetail s={s}/>
          <Trace filter={filter} setFilter={setFilter}/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>workspace: ~/Projects/CodeEditorPlugin</span>
          <span>·</span>
          <span>retry policy: <span style={{ color: "var(--text)" }}>exponentialBackoff(maxAttempts: 5)</span></span>
          <span style={{ flex: 1 }}/>
          <span>LSPManager · 6 registered</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.LspB = LspB;
