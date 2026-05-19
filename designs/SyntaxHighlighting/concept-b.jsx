// SYNTAXHIGHLIGHTING · CONCEPT B — "LANGUAGE WORKBENCH"
// Triptych around the LanguageRegistry, not the theme.  Mirrors how a
// host developer thinks about syntax highlighting at integration time:
// "I add a language to the registry; I want to see what gets coloured
// and how, and whether the highlighter is keeping up."
//   Left   · LanguageRegistry — 25 languages + plain text, grouped by
//            backing highlighter (SwiftSyntax / Regex / PlainText).
//            Selecting a language switches the centre + the right pane.
//   Centre · live editor preview rendering source in the selected
//            language against LCARS Dark, with the
//            BackgroundSyntaxHighlighter status pinned at top.
//   Right  · per-token histogram for the open document (counts coming
//            out of SmartTokenCache) + cache / coordinator readouts.

const ShB = (() => {
  const { Ic, Tk, WindowFrame, TitleBar, ThemeSwitch, Pill, Overline, Kbd, StatusPill } = window;
  const { useState } = React;

  // Group registry by which SyntaxHighlighter implementation provides
  // it.  Counts deliberately don't sum to 26 — these are realistic
  // illustrative numbers, not the full Language.allCases catalogue.
  const REGISTRY = [
    { group: "SwiftSyntaxHighlighter", count: 1, langs: [
      { id: "swift", name: "Swift",       ext: "swift",  tokens: 18, primary: true },
    ]},
    { group: "RegexSyntaxHighlighter (brace-style)", count: 11, langs: [
      { id: "ts",   name: "TypeScript", ext: "ts",     tokens: 14 },
      { id: "js",   name: "JavaScript", ext: "js",     tokens: 14 },
      { id: "c",    name: "C",          ext: "c",      tokens: 12 },
      { id: "cpp",  name: "C++",        ext: "cpp",    tokens: 13 },
      { id: "java", name: "Java",       ext: "java",   tokens: 13 },
      { id: "rs",   name: "Rust",       ext: "rs",     tokens: 16 },
      { id: "go",   name: "Go",         ext: "go",     tokens: 12 },
      { id: "css",  name: "CSS",        ext: "css",    tokens: 10 },
      { id: "json", name: "JSON",       ext: "json",   tokens: 8 },
      { id: "php",  name: "PHP",        ext: "php",    tokens: 14 },
      { id: "cs",   name: "C#",         ext: "cs",     tokens: 14 },
    ]},
    { group: "RegexSyntaxHighlighter (indent / spec)", count: 11, langs: [
      { id: "py",   name: "Python",     ext: "py",     tokens: 13 },
      { id: "rb",   name: "Ruby",       ext: "rb",     tokens: 13 },
      { id: "yaml", name: "YAML",       ext: "yaml",   tokens: 7  },
      { id: "toml", name: "TOML",       ext: "toml",   tokens: 7  },
      { id: "md",   name: "Markdown",   ext: "md",     tokens: 10 },
      { id: "html", name: "HTML",       ext: "html",   tokens: 9  },
      { id: "xml",  name: "XML",        ext: "xml",    tokens: 6  },
      { id: "sh",   name: "Shell",      ext: "sh",     tokens: 11 },
      { id: "sql",  name: "SQL",        ext: "sql",    tokens: 9  },
      { id: "lua",  name: "Lua",        ext: "lua",    tokens: 11 },
      { id: "dock", name: "Dockerfile", ext: "Dock",   tokens: 6  },
    ]},
    { group: "PlainTextHighlighter", count: 1, langs: [
      { id: "txt", name: "Plain Text", ext: "txt",    tokens: 0 },
    ]},
  ];

  // Histogram counts for the active document.
  const HIST_BY_LANG = {
    swift: [
      { k: "keyword",     n: 184, c: "var(--syn-keyword)"  },
      { k: "identifier",  n: 412, c: "var(--text)" },
      { k: "string",      n:  46, c: "var(--syn-string)"   },
      { k: "number",      n:  31, c: "var(--syn-number)"   },
      { k: "comment",     n:  78, c: "var(--syn-comment)"  },
      { k: "type",        n: 126, c: "var(--syn-type)"     },
      { k: "function",    n: 187, c: "var(--syn-function)" },
      { k: "property",    n:  92, c: "var(--syn-property)" },
      { k: "operator",    n: 211, c: "var(--text-muted)"   },
      { k: "punctuation", n: 638, c: "var(--syn-punct)"    },
      { k: "preprocessor", n: 14, c: "var(--accent-3)"     },
    ],
  };

  function Rail({ active, setActive }) {
    return (
      <div style={{
        width: 232, flexShrink: 0,
        background: "var(--panel)",
        borderRight: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "12px 14px 6px" }}>
          <div style={{ font: "700 22px/1 var(--font-display)", color: "var(--text)", letterSpacing: -0.2 }}>
            Languages
          </div>
          <div style={{ font: "11px var(--font-sans)", color: "var(--text-muted)", marginTop: 2 }}>
            LanguageRegistry · 25 + plain
          </div>
        </div>
        <div style={{ flex: 1, overflowY: "auto" }}>
          {REGISTRY.map(g => (
            <div key={g.group} style={{ padding: "8px 8px 0" }}>
              <div style={{ padding: "4px 8px", display: "flex", alignItems: "baseline", gap: 6 }}>
                <Overline>{g.group}</Overline>
                <span style={{ flex: 1 }}/>
                <span style={{ font: "10.5px var(--font-mono)", color: "var(--text-disabled)" }}>{g.count}</span>
              </div>
              {g.langs.map(l => {
                const sel = active === l.id;
                return (
                  <div key={l.id} onClick={() => setActive(l.id)} style={{
                    margin: "1px 2px",
                    padding: "5px 9px",
                    borderRadius: 5, cursor: "pointer",
                    background: sel ? "var(--element-selected)" : "transparent",
                    boxShadow: sel ? "inset 2px 0 0 0 var(--accent-1)" : "none",
                    display: "grid", gridTemplateColumns: "24px 1fr auto auto", gap: 8, alignItems: "center",
                  }}>
                    <span style={{
                      width: 20, height: 20, borderRadius: 4,
                      background: "color-mix(in srgb, var(--accent-1) 14%, transparent)",
                      color: l.primary ? "var(--accent-1)" : "var(--text-muted)",
                      display: "flex", alignItems: "center", justifyContent: "center",
                      font: "10px var(--font-mono)", fontWeight: 700,
                    }}>.{l.ext.slice(0, 3)}</span>
                    <span style={{
                      font: `${sel ? 600 : 500} 12px var(--font-sans)`,
                      color: "var(--text)",
                    }}>{l.name}</span>
                    <span style={{ font: "10px var(--font-mono)", color: "var(--text-muted)" }}>{l.tokens}</span>
                    {l.primary ? (
                      <span style={{
                        font: "9.5px var(--font-sans)", letterSpacing: 0.4, textTransform: "uppercase",
                        color: "var(--accent-1)", fontWeight: 600,
                      }}>SwiftSyntax</span>
                    ) : <span/>}
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      </div>
    );
  }

  function Center({ langId }) {
    return (
      <div style={{
        flex: 1, minWidth: 0,
        background: "var(--editor-bg)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{
          height: 30, flexShrink: 0,
          display: "flex", alignItems: "center", gap: 8, padding: "0 14px",
          borderBottom: "0.5px solid var(--border-variant)",
          background: "var(--toolbar)",
          font: "11px var(--font-sans)", color: "var(--text-muted)",
        }}>
          <Ic.Activity size={12}/>
          <span>BackgroundSyntaxHighlighter</span>
          <StatusPill state="initialized" label="idle · cache hit"/>
          <span style={{ flex: 1 }}/>
          <span>actor: BackgroundHighlightingActor</span>
          <span>·</span>
          <span>cache: SmartTokenCache · 96 % hit</span>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: "10px 0" }}>
          {[
            { n:  1, c: <><Tk.Pn>@</Tk.Pn><Tk.At>MainActor</Tk.At></> },
            { n:  2, c: <><Tk.K>public final class</Tk.K> <Tk.T>LSPClient</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.T>ObservableObject</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
            { n:  3, c: <>{"    "}<Tk.C>{"/// Current connection state"}</Tk.C></> },
            { n:  4, c: <>{"    "}<Tk.K>@Published</Tk.K> <Tk.K>public</Tk.K> <Tk.K>private(set)</Tk.K> <Tk.K>var</Tk.K> <Tk.P>connectionState</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.T>ConnectionState</Tk.T> <Tk.Pn>=</Tk.Pn> .<Tk.V>disconnected</Tk.V></> },
            { n:  5, c: <>{"    "}<Tk.C>{"// Active diagnostics by document URI"}</Tk.C></> },
            { n:  6, c: <>{"    "}<Tk.K>public</Tk.K> <Tk.K>var</Tk.K> <Tk.P>diagnostics</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.Pn>[</Tk.Pn><Tk.T>String</Tk.T><Tk.Pn>:</Tk.Pn> <Tk.Pn>[</Tk.Pn><Tk.T>LSPDiagnostic</Tk.T><Tk.Pn>]] =</Tk.Pn> <Tk.Pn>[:]</Tk.Pn></> },
            { n:  7, c: " " },
            { n:  8, c: <>{"    "}<Tk.K>public func</Tk.K> <Tk.F>requestCompletion</Tk.F>(<Tk.P>uri</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.T>String</Tk.T><Tk.Pn>,</Tk.Pn> <Tk.P>position</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.T>Position</Tk.T>) <Tk.K>async throws</Tk.K> <Tk.Pn>{"->"}</Tk.Pn> <Tk.T>CompletionList</Tk.T> <Tk.Pn>{"{"}</Tk.Pn></> },
            { n:  9, c: <>{"        "}<Tk.K>let</Tk.K> <Tk.P>params</Tk.P> <Tk.Pn>=</Tk.Pn> <Tk.F>createCompletionParams</Tk.F>(<Tk.P>uri</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.V>uri</Tk.V><Tk.Pn>,</Tk.Pn> <Tk.P>position</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.V>position</Tk.V>)</> },
            { n: 10, c: <>{"        "}<Tk.K>let</Tk.K> <Tk.P>response</Tk.P> <Tk.Pn>=</Tk.Pn> <Tk.K>try await</Tk.K> <Tk.F>sendRequest</Tk.F>(<Tk.P>method</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.S>"textDocument/completion"</Tk.S><Tk.Pn>,</Tk.Pn> <Tk.P>params</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.V>params</Tk.V>)</> },
            { n: 11, c: <>{"        "}<Tk.K>return</Tk.K> <Tk.K>try</Tk.K> <Tk.F>parseCompletionResponse</Tk.F>(<Tk.V>response</Tk.V>)</> },
            { n: 12, c: <>{"    "}<Tk.Pn>{"}"}</Tk.Pn></> },
            { n: 13, c: " " },
            { n: 14, c: <>{"    "}<Tk.K>public let</Tk.K> <Tk.P>maxAttempts</Tk.P><Tk.Pn>:</Tk.Pn> <Tk.T>Int</Tk.T> <Tk.Pn>=</Tk.Pn> <Tk.N>5</Tk.N></> },
            { n: 15, c: <Tk.Pn>{"}"}</Tk.Pn> },
          ].map(l => (
            <div key={l.n} style={{
              display: "grid", gridTemplateColumns: "44px 1fr",
              alignItems: "center", minHeight: 21,
            }}>
              <span style={{
                textAlign: "right", paddingRight: 8,
                font: "12px var(--font-mono)", color: "var(--line-num)",
              }}>{l.n}</span>
              <code style={{
                whiteSpace: "pre", color: "var(--editor-fg)",
                font: "12.5px/1.55 var(--font-mono)",
              }}>{l.c}</code>
            </div>
          ))}
        </div>
      </div>
    );
  }

  function Histogram() {
    const data = HIST_BY_LANG.swift;
    const max = Math.max(...data.map(d => d.n));
    return (
      <div style={{
        width: 264, flexShrink: 0,
        background: "var(--panel)",
        borderLeft: "0.5px solid var(--border-variant)",
        display: "flex", flexDirection: "column",
      }}>
        <div style={{ padding: "14px 14px 6px" }}>
          <Overline>TOKEN HISTOGRAM</Overline>
          <div style={{ font: "11px var(--font-mono)", color: "var(--text-muted)", marginTop: 4 }}>
            LSPClient.swift · 2,019 tokens
          </div>
        </div>
        <div style={{ padding: "4px 14px 14px", display: "flex", flexDirection: "column", gap: 4 }}>
          {data.map(d => (
            <div key={d.k} style={{ display: "grid", gridTemplateColumns: "82px 1fr 36px", gap: 6, alignItems: "center" }}>
              <code style={{ font: "11px var(--font-mono)", color: "var(--text)" }}>{d.k}</code>
              <div style={{ height: 8, borderRadius: 2, background: "var(--element-bg)",
                boxShadow: "inset 0 0 0 0.5px var(--border-variant)" }}>
                <div style={{
                  width: `${(d.n / max) * 100}%`, height: "100%", borderRadius: 2,
                  background: d.c,
                }}/>
              </div>
              <span style={{ font: "11px var(--font-mono)", color: "var(--text-muted)", textAlign: "right" }}>{d.n}</span>
            </div>
          ))}
        </div>
        <div style={{
          margin: "0 14px 12px", padding: 10, borderRadius: 8,
          background: "var(--element-bg)",
          boxShadow: "inset 0 0 0 0.5px var(--border-variant)",
        }}>
          <Overline>HIGHLIGHTER</Overline>
          <div style={{
            marginTop: 6, display: "grid", gridTemplateColumns: "1fr auto", rowGap: 4,
            font: "11px var(--font-mono)", color: "var(--text-muted)",
          }}>
            <span>backend</span><span style={{ color: "var(--accent-1)" }}>SwiftSyntaxHighlighter</span>
            <span>incremental</span><span style={{ color: "var(--text)" }}>yes</span>
            <span>last full</span><span style={{ color: "var(--text)" }}>3.4 ms</span>
            <span>last delta</span><span style={{ color: "var(--text)" }}>0.7 ms</span>
            <span>cache hit</span><span style={{ color: "var(--status-success)" }}>96 %</span>
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ padding: 12, borderTop: "0.5px solid var(--border-variant)",
          display: "flex", flexDirection: "column", gap: 6 }}>
          <Pill icon={<Ic.Palette size={11}/>}>Open Theme Editor</Pill>
          <Pill icon={<Ic.Rotate size={11}/>}>Re-highlight document</Pill>
        </div>
      </div>
    );
  }

  function App() {
    const [theme, setTheme] = useState("lcars-dark");
    const [active, setActive] = useState("swift");
    return (
      <WindowFrame width={880} height={660} theme={theme}>
        <TitleBar title="Syntax · Language Workbench" subtitle="CodeEditorSyntaxHighlighting"
          right={<ThemeSwitch theme={theme} setTheme={setTheme}/>}/>
        <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
          <Rail active={active} setActive={setActive}/>
          <Center langId={active}/>
          <Histogram/>
        </div>
        <div style={{
          height: 22, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, padding: "0 12px",
          background: "var(--status-bar)",
          borderTop: "0.5px solid var(--border-variant)",
          font: "10.5px var(--font-mono)", color: "var(--text-muted)",
        }}>
          <span>coordinator: SyntaxHighlightingCoordinator · ViewportSyntaxCoordinator</span>
          <span style={{ flex: 1 }}/>
          <span>theme.color(forToken:) · hierarchical fallback</span>
        </div>
      </WindowFrame>
    );
  }

  return { App };
})();

window.ShB = ShB;
