// LSP · CONCEPT C — "COMMAND DECK"
// LCARS / starship console treatment.  No editor.  No three-pane chrome.
// One full-bleed scrolling page that reads like an ops dashboard:
//   • Top    · command bar (servers, requests, capabilities, traces)
//   • Strip  · health bar — six server pips spread across the width with
//              accent-coded states, RTT and queued counters
//   • Cards  · per-language deep cards.  Each card is a slab carrying
//              transport, capabilities matrix, RTT histogram, and the
//              last few log lines.
//   • Floor  · global timeline of recent requests (ribbon view)

const LspC = (() => {
  const { Ic, WindowFrame, TitleBar, ThemeSwitch, Pill, Kbd, Overline, StatusPill } = window;
  const { useState } = React;

  const SERVERS = [
    { id: "swift",  name: "sourcekit-lsp",                state: "initialized",  transport: "local", lang: "Swift",      rtt: 14, docs: 4, queued: 0, accent: "var(--accent-1)" },
    { id: "ts",     name: "typescript-language-server",   state: "initialized",  transport: "local", lang: "TypeScript", rtt: 22, docs: 7, queued: 0, accent: "var(--syn-type)" },
    { id: "py",     name: "pylsp",                        state: "initialized",  transport: "local", lang: "Python",     rtt: 19, docs: 2, queued: 1, accent: "var(--accent-3)" },
    { id: "rust",   name: "rust-analyzer · ws",           state: "initializing", transport: "ws",    lang: "Rust",       rtt: null, docs: 0, queued: 0, accent: "var(--status-warning)" },
    { id: "go",     name: "gopls",                        state: "error",        transport: "local", lang: "Go",         rtt: null, docs: 0, queued: 0, accent: "var(--status-error)" },
    { id: "json",   name: "vscode-json-languageserver",   state: "disconnected", transport: "local", lang: "JSON",       rtt: null, docs: 0, queued: 0, accent: "var(--text-disabled)" },
  ];

  const TIMELINE = [
    // 30 events; lane = server, t = age ms (most recent at right).
    ...Array.from({ length: 30 }).map((_, i) => ({
      t: 100 - i * 3,
      server: ["swift","ts","py","rust","go"][i % 5],
      method: ["textDocument/completion","textDocument/hover","textDocument/didChange","textDocument/semanticTokens/full/delta","textDocument/codeAction","textDocument/definition"][i % 6],
      ms: 8 + (i * 7) % 40,
      ok: !(i % 11 === 0),
    })),
  ];

  const ACTIVE_CAPS = ["completion", "hover", "definition", "documentSymbol", "semanticTokens", "codeAction", "signatureHelp", "diagnostics"];
  const ALL_CAPS = [...ACTIVE_CAPS, "references", "rename", "formatting", "workspaceSymbol"];

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
          display: "flex", alignItems: "center", gap: 8,
          height: 32, padding: "0 12px", borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-focused), 0 0 0 3px color-mix(in srgb, var(--border-focused) 16%, transparent)",
        }}>
          <span style={{ color: "var(--accent-1)" }}><Ic.Cmd size={14}/></span>
          <input placeholder="server:rust state:initializing  ·  restart server  ·  open trace  ·  ⌘K" readOnly style={{
            flex: 1, background: "transparent", border: "none", outline: "none",
            color: "var(--text-placeholder)", font: "13px var(--font-sans)",
          }}/>
          <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>6 servers · 1,142 traces (24h)</span>
          <Kbd>⌘K</Kbd>
        </div>
        <Pill icon={<Ic.Plus size={11}/>}>Register</Pill>
      </div>
    );
  }

  function HealthStrip() {
    const up = SERVERS.filter(s => s.state === "initialized").length;
    const queued = SERVERS.reduce((a, s) => a + s.queued, 0);
    return (
      <div style={{
        padding: "10px 16px",
        background: "var(--toolbar)",
        borderBottom: "0.5px solid var(--border-variant)",
        display: "flex", alignItems: "center", gap: 14,
      }}>
        <div>
          <Overline color="var(--accent-1)">FLEET HEALTH</Overline>
          <div style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2,
            marginTop: 2 }}>
            <span style={{ color: "var(--status-success)" }}>{up}</span>
            <span style={{ font: "500 16px var(--font-mono)", color: "var(--text-muted)" }}> / {SERVERS.length}</span>
            <span style={{ font: "500 12px var(--font-mono)", color: "var(--text-muted)", marginLeft: 6 }}>nominal</span>
          </div>
        </div>
        <div style={{ width: 1, height: 32, background: "var(--border-variant)" }}/>
        {SERVERS.map(s => (
          <div key={s.id} style={{
            display: "flex", alignItems: "center", gap: 5,
            padding: "3px 9px", borderRadius: 999,
            background: `color-mix(in srgb, ${s.accent} 10%, transparent)`,
            boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${s.accent} 35%, transparent)`,
          }}>
            <span style={{
              width: 6, height: 6, borderRadius: "50%", background: s.accent,
              boxShadow: s.state === "initialized" ? `0 0 6px ${s.accent}` : "none",
            }}/>
            <span style={{ font: "600 11px var(--font-sans)", color: s.accent }}>{s.lang}</span>
            <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>
              {s.rtt ? `${s.rtt}ms` : s.state === "error" ? "ERR" : s.state === "initializing" ? "…" : "off"}
            </span>
          </div>
        ))}
        <span style={{ flex: 1 }}/>
        <div style={{ textAlign: "right" }}>
          <Overline>QUEUED REQUESTS</Overline>
          <div style={{ font: "600 18px var(--font-mono)", color: queued ? "var(--accent-1)" : "var(--text-muted)", marginTop: 2 }}>{queued}</div>
        </div>
      </div>
    );
  }

  function RTTSparkline({ accent }) {
    // Deterministic sparkline; depicts a smooth-ish recent RTT trace.
    const pts = [12, 16, 14, 19, 13, 18, 22, 17, 14, 12, 15, 18, 16, 14, 13, 14];
    const W = 84, H = 30, max = 28, min = 8;
    const x = (i) => (i * W) / (pts.length - 1);
    const y = (v) => H - ((v - min) * H) / (max - min);
    const path = pts.map((v, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
    return (
      <svg width={W} height={H} style={{ display: "block" }}>
        <path d={`${path} L${W},${H} L0,${H} Z`} fill={accent} fillOpacity="0.18"/>
        <path d={path} fill="none" stroke={accent} strokeWidth="1.5"/>
      </svg>
    );
  }

  function ServerCard({ s }) {
    return (
      <div style={{
        padding: 12, borderRadius: 10,
        background: `color-mix(in srgb, ${s.accent} 5%, var(--surface))`,
        boxShadow: `inset 0 0 0 0.5px color-mix(in srgb, ${s.accent} 35%, transparent)`,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{
            width: 26, height: 26, borderRadius: 6,
            display: "flex", alignItems: "center", justifyContent: "center",
            background: `color-mix(in srgb, ${s.accent} 20%, transparent)`,
            color: s.accent,
          }}>{s.transport === "ws" ? <Ic.Globe size={13}/> : <Ic.Server size={13}/>}</span>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: "600 13px var(--font-sans)", color: "var(--text)",
              whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
              {s.lang}
            </div>
            <div style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)",
              whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{s.name}</div>
          </div>
          <StatusPill state={s.state}/>
        </div>

        {s.state === "initialized" && (
          <div style={{
            display: "grid", gridTemplateColumns: "1fr 84px", gap: 8, alignItems: "center",
            marginTop: 10,
          }}>
            <div style={{ display: "grid", gridTemplateColumns: "auto 1fr", rowGap: 3, columnGap: 8,
              font: "11px var(--font-mono)", color: "var(--text-muted)" }}>
              <span>rtt</span><span style={{ color: s.accent, fontWeight: 600 }}>{s.rtt} ms</span>
              <span>docs</span><span style={{ color: "var(--text)" }}>{s.docs}</span>
              <span>queue</span><span style={{ color: s.queued ? "var(--accent-1)" : "var(--text)" }}>{s.queued}</span>
            </div>
            <RTTSparkline accent={s.accent}/>
          </div>
        )}
        {s.state === "error" && (
          <div style={{
            marginTop: 10, padding: "6px 8px", borderRadius: 6,
            background: "color-mix(in srgb, var(--status-error) 10%, transparent)",
            font: "11px var(--font-mono)", color: "var(--status-error)",
          }}>exit 1 · workspace folder not found</div>
        )}
        {s.state === "initializing" && (
          <div style={{
            marginTop: 10, padding: "6px 8px", borderRadius: 6,
            background: "color-mix(in srgb, var(--status-warning) 10%, transparent)",
            font: "11px var(--font-mono)", color: "var(--status-warning)",
            display: "flex", alignItems: "center", gap: 6,
          }}>
            <div style={{ width: 10, height: 10, borderRadius: "50%",
              border: "1.5px solid var(--status-warning)", borderTopColor: "transparent",
              animation: "spin 0.8s linear infinite" }}/>
            negotiating · TLS 1.3 · cert pinned
            <style>{`@keyframes spin { to { transform: rotate(360deg) } }`}</style>
          </div>
        )}
        {/* Capability dots */}
        <div style={{ marginTop: 10 }}>
          <Overline>capabilities · {ACTIVE_CAPS.length}/{ALL_CAPS.length}</Overline>
          <div style={{ marginTop: 4, display: "flex", flexWrap: "wrap", gap: 3 }}>
            {ALL_CAPS.map(c => {
              const on = s.state === "initialized" && ACTIVE_CAPS.includes(c);
              return (
                <span key={c} title={c} style={{
                  font: "10px var(--font-mono)",
                  padding: "1px 5px", borderRadius: 3,
                  background: on ? `color-mix(in srgb, ${s.accent} 22%, transparent)` : "var(--element-bg)",
                  boxShadow: on ? `inset 0 0 0 0.5px ${s.accent}` : "inset 0 0 0 0.5px var(--border-variant)",
                  color: on ? s.accent : "var(--text-disabled)",
                }}>{c}</span>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  function Timeline() {
    return (
      <div style={{
        margin: "0 16px 12px", padding: 12, borderRadius: 10,
        background: "var(--surface)",
        boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Overline>REQUEST TIMELINE · 30 s</Overline>
          <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-muted)" }}>· {TIMELINE.length} events</span>
          <span style={{ flex: 1 }}/>
          <span style={{ font: "11px var(--font-mono)", color: "var(--text-muted)" }}>median RTT <span style={{ color: "var(--text)" }}>18 ms</span></span>
        </div>
        {/* Per-server lanes */}
        <div style={{ marginTop: 8 }}>
          {SERVERS.filter(s => s.state !== "disconnected").map(s => (
            <div key={s.id} style={{
              position: "relative", height: 18, marginBottom: 4,
              borderRadius: 3,
              background: "color-mix(in srgb, var(--bg) 50%, transparent)",
            }}>
              <span style={{
                position: "absolute", left: 8, top: 1, font: "10px var(--font-mono)",
                color: s.accent, fontWeight: 600,
              }}>{s.lang}</span>
              {TIMELINE.filter(e => e.server === s.id).map((e, i) => (
                <span key={i} title={`${e.method} · ${e.ms}ms`} style={{
                  position: "absolute",
                  left: `${e.t}%`,
                  top: 3, height: 12,
                  width: 6,
                  background: e.ok ? s.accent : "var(--status-error)",
                  borderRadius: 1,
                  opacity: 0.85 - (i * 0.02),
                }}/>
              ))}
            </div>
          ))}
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="LSP · Command Deck" subtitle="Operations console"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <CommandBar/>
        <HealthStrip/>
        <div style={{
          flex: 1, minHeight: 0, overflowY: "auto", background: "var(--bg)",
          paddingTop: 12, paddingBottom: 4,
        }}>
          <div style={{
            margin: "0 16px 14px",
            display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10,
          }}>
            {SERVERS.map(s => <ServerCard key={s.id} s={s}/>)}
          </div>
          <Timeline/>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.LspC = LspC;
