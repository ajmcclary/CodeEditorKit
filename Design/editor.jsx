/* Lightweight per-language tokenizer + CodeEditor React component.
   This is a *visual* prototype — not a real editor. It demonstrates how
   every CodeEditorPlugin EditorConfiguration knob would render in the UI:
   line numbers, folding, gutter, annotations (TODO/FIXME/NOTE/WARNING),
   selection highlight, active-line highlight, minimap, completion popover,
   wrap, invisible characters, indent guides, etc. */

const TOKEN_PATTERNS = {
  swift: [
    { type: "comment",  re: /\/\/[^\n]*/y },
    { type: "comment",  re: /\/\*[\s\S]*?\*\//y },
    { type: "string",   re: /"(?:\\.|[^"\\\n])*"/y },
    { type: "number",   re: /\b\d[\d_]*(?:\.\d+)?\b/y },
    { type: "macro",    re: /#\w+/y },
    { type: "keyword",  re: /\b(import|struct|class|enum|protocol|extension|func|var|let|if|else|guard|return|throw|throws|try|await|async|for|while|in|where|public|private|internal|fileprivate|static|self|Self|init|deinit|case|switch|default|do|catch|as|is|nil|true|false)\b/y },
    { type: "type",     re: /\b[A-Z][A-Za-z0-9_]*\b/y },
    { type: "function", re: /\b[a-z_][A-Za-z0-9_]*(?=\s*\()/y },
    { type: "property", re: /\.[A-Za-z_][A-Za-z0-9_]*/y },
    { type: "operator", re: /[=+\-*/%<>!&|^~?:]+/y },
    { type: "punctuation", re: /[(){}\[\],.;]/y },
  ],
  typescript: [
    { type: "comment",  re: /\/\/[^\n]*/y },
    { type: "comment",  re: /\/\*[\s\S]*?\*\//y },
    { type: "string",   re: /"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`/y },
    { type: "number",   re: /\b\d[\d_]*(?:\.\d+)?\b/y },
    { type: "keyword",  re: /\b(import|export|from|interface|type|class|extends|implements|function|const|let|var|if|else|return|for|while|in|of|new|this|public|private|protected|readonly|async|await|true|false|null|undefined)\b/y },
    { type: "type",     re: /\b[A-Z][A-Za-z0-9_]*\b/y },
    { type: "function", re: /\b[a-z_][A-Za-z0-9_]*(?=\s*\()/y },
    { type: "property", re: /\.[A-Za-z_][A-Za-z0-9_]*/y },
    { type: "operator", re: /[=+\-*/%<>!&|^~?:]+/y },
    { type: "punctuation", re: /[(){}\[\],.;]/y },
  ],
  python: [
    { type: "comment",  re: /#[^\n]*/y },
    { type: "string",   re: /"""[\s\S]*?"""|'''[\s\S]*?'''|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'/y },
    { type: "number",   re: /\b\d[\d_]*(?:\.\d+)?\b/y },
    { type: "macro",    re: /@\w+/y },
    { type: "keyword",  re: /\b(import|from|as|def|class|if|elif|else|return|for|while|in|is|not|and|or|with|yield|lambda|pass|break|continue|try|except|finally|raise|True|False|None|self)\b/y },
    { type: "type",     re: /\b[A-Z][A-Za-z0-9_]*\b/y },
    { type: "function", re: /\b[a-z_][A-Za-z0-9_]*(?=\s*\()/y },
    { type: "operator", re: /[=+\-*/%<>!&|^~?:]+/y },
    { type: "punctuation", re: /[(){}\[\],.;:]/y },
  ],
  rust: [
    { type: "comment",  re: /\/\/[^\n]*/y },
    { type: "comment",  re: /\/\*[\s\S]*?\*\//y },
    { type: "string",   re: /"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'/y },
    { type: "number",   re: /\b\d[\d_]*(?:\.\d+)?\b/y },
    { type: "macro",    re: /\b\w+!/y },
    { type: "keyword",  re: /\b(fn|let|mut|pub|struct|enum|impl|trait|use|mod|crate|self|Self|return|if|else|for|while|loop|in|match|as|where|move|async|await|true|false)\b/y },
    { type: "type",     re: /\b[A-Z][A-Za-z0-9_]*\b/y },
    { type: "function", re: /\b[a-z_][A-Za-z0-9_]*(?=\s*[(<])/y },
    { type: "operator", re: /[=+\-*/%<>!&|^~?:]+/y },
    { type: "punctuation", re: /[(){}\[\],.;:]/y },
  ],
  json: [
    { type: "string",   re: /"(?:\\.|[^"\\\n])*"(?=\s*:)/y, asProperty: true },
    { type: "string",   re: /"(?:\\.|[^"\\\n])*"/y },
    { type: "number",   re: /-?\b\d[\d_]*(?:\.\d+)?\b/y },
    { type: "constant", re: /\b(true|false|null)\b/y },
    { type: "punctuation", re: /[{}\[\],:]/y },
  ],
};

function tokenizeLine(line, lang) {
  const patterns = TOKEN_PATTERNS[lang] || [];
  const out = [];
  let i = 0;
  while (i < line.length) {
    let matched = null;
    let matchType = null;
    let matchLen = 0;
    for (const p of patterns) {
      p.re.lastIndex = i;
      const m = p.re.exec(line);
      if (m && m.index === i) {
        matched = m[0];
        matchType = p.asProperty ? "property" : p.type;
        matchLen = m[0].length;
        break;
      }
    }
    if (matched) {
      out.push({ type: matchType, text: matched });
      i += matchLen;
    } else {
      // collect plain text up to next potential token start
      let j = i + 1;
      while (j < line.length && !/[\w."'#@/`\-+*<>=!&|\^~?:(){}\[\],.;]/.test(line[j])) j++;
      out.push({ type: "plain", text: line.slice(i, j) });
      i = j;
    }
  }
  return out;
}

/* ------------------------------------------------------------------ */
/* Annotation badges (TODO/FIXME/NOTE/WARNING/ERROR) — auto-detected. */
/* ------------------------------------------------------------------ */
const ANNOTATION_RE = /\b(TODO|FIXME|NOTE|WARNING|ERROR)\b/;
function detectAnnotation(line) {
  const m = ANNOTATION_RE.exec(line);
  return m ? m[1] : null;
}

const ANNOTATION_STYLE = {
  TODO:    { fg: "#0A84FF", glyph: "✓", label: "todo" },
  FIXME:   { fg: "#FF9F0A", glyph: "!", label: "fixme" },
  NOTE:    { fg: "#5DD8FF", glyph: "i", label: "note" },
  WARNING: { fg: "#FFD60A", glyph: "△", label: "warn" },
  ERROR:   { fg: "#FF453A", glyph: "✕", label: "error" },
};

/* ------------------------------------------------------------------ */
/* Fold detection — naive: any line ending with `{` or `:` (py) opens. */
/* ------------------------------------------------------------------ */
function detectFolds(lines, lang, minLines) {
  const folds = []; // {start, end}
  const opens = [];
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trimEnd();
    if (lang === "python") {
      if (/:\s*$/.test(trimmed) && /^\s*(def|class|if|else|elif|for|while|try|except|with)\b/.test(trimmed)) {
        opens.push({ start: i, indent: lines[i].match(/^\s*/)[0].length });
      } else if (opens.length) {
        const top = opens[opens.length - 1];
        const ind = lines[i].match(/^\s*/)[0].length;
        if (trimmed.length && ind <= top.indent) {
          const open = opens.pop();
          if (i - 1 - open.start + 1 >= minLines) folds.push({ start: open.start, end: i - 1 });
        }
      }
    } else {
      if (/\{\s*$/.test(trimmed)) opens.push({ start: i });
      if (/^\s*\}/.test(trimmed) && opens.length) {
        const open = opens.pop();
        if (i - open.start >= minLines) folds.push({ start: open.start, end: i });
      }
    }
  }
  // close any remaining python opens at end
  while (lang === "python" && opens.length) {
    const open = opens.pop();
    if (lines.length - 1 - open.start >= minLines) folds.push({ start: open.start, end: lines.length - 1 });
  }
  return folds;
}

/* ================================================================== */
/* CodeEditor React component                                          */
/* ================================================================== */

const { useState, useMemo, useRef, useEffect } = React;

function CodeEditor({ config, theme, language, source, fileName, dirty, status }) {
  const lines = useMemo(() => source.split("\n"), [source]);
  const folds = useMemo(
    () => config.display.enableCodeFolding
      ? detectFolds(lines, language, config.display.minimumFoldableLines)
      : [],
    [lines, language, config.display.enableCodeFolding, config.display.minimumFoldableLines]
  );
  const [collapsed, setCollapsed] = useState(new Set());
  const [activeLine, setActiveLine] = useState(0);
  const [showCompletion, setShowCompletion] = useState(false);
  const [hover, setHover] = useState(null);

  // Reset collapsed when folding disabled
  useEffect(() => {
    if (!config.display.enableCodeFolding) setCollapsed(new Set());
  }, [config.display.enableCodeFolding]);

  // Build a quick map: which lines are hidden because they're inside a collapsed fold
  const hiddenLines = useMemo(() => {
    const hidden = new Set();
    for (const f of folds) {
      if (collapsed.has(f.start)) {
        for (let i = f.start + 1; i <= f.end; i++) hidden.add(i);
      }
    }
    return hidden;
  }, [folds, collapsed]);

  const foldStartMap = useMemo(() => {
    const m = new Map();
    folds.forEach(f => m.set(f.start, f));
    return m;
  }, [folds]);

  const lineHeight = Math.round(config.display.fontSize * config.layout.lineHeightMultiple * 1.2);
  const editorBg = theme.bg;

  function toggleFold(start) {
    setCollapsed(prev => {
      const next = new Set(prev);
      if (next.has(start)) next.delete(start); else next.add(start);
      return next;
    });
  }

  // Render visible lines, skipping those hidden by a collapsed fold.
  const renderedLines = [];
  for (let i = 0; i < lines.length; i++) {
    if (hiddenLines.has(i)) continue;
    renderedLines.push({ idx: i, text: lines[i] });
  }

  return (
    <div
      className="ce-root"
      data-theme-mode={theme.appearance}
      style={{
        background: editorBg,
        color: theme.fg,
        fontFamily: "var(--font-mono)",
        fontSize: config.display.fontSize,
        position: "relative",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      {/* Tab strip */}
      <div
        className="ce-tabbar"
        style={{
          display: "flex",
          alignItems: "stretch",
          background: theme.surface,
          borderBottom: `0.5px solid ${theme.appearance === "dark" ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"}`,
          fontFamily: "var(--font-sans)",
          fontSize: 12,
          height: 32,
          flexShrink: 0,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            padding: "0 12px 0 14px",
            background: editorBg,
            color: theme.fg,
            borderRight: `0.5px solid ${theme.appearance === "dark" ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"}`,
            fontWeight: 500,
          }}
        >
          <LangGlyph language={language} color={theme.function} />
          <span>{fileName}</span>
          {dirty && (
            <span style={{
              width: 6, height: 6, borderRadius: "50%",
              background: theme.appearance === "dark" ? "#fff" : "#000",
              opacity: 0.7,
            }} />
          )}
          <span style={{ marginLeft: 4, color: theme.appearance === "dark" ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.35)", fontSize: 14, lineHeight: "14px", cursor: "pointer" }}>×</span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{
          display: "flex", alignItems: "center", gap: 10,
          padding: "0 12px", color: theme.appearance === "dark" ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.5)",
          fontSize: 11, fontFamily: "var(--font-mono)",
        }}>
          <span>UTF-8</span>
          <span>·</span>
          <span>LF</span>
          <span>·</span>
          <span>{LANGUAGES.find(l => l.id === language)?.label || language}</span>
        </div>
      </div>

      {/* Breadcrumb */}
      <div style={{
        display: "flex", alignItems: "center", gap: 6,
        padding: "6px 14px",
        background: editorBg,
        borderBottom: `0.5px solid ${theme.appearance === "dark" ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)"}`,
        color: theme.appearance === "dark" ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.5)",
        fontFamily: "var(--font-sans)", fontSize: 11,
        flexShrink: 0,
      }}>
        <span>Sources</span>
        <span style={{ opacity: 0.5 }}>›</span>
        <span>CodeEditorPlugin</span>
        <span style={{ opacity: 0.5 }}>›</span>
        <span style={{ color: theme.fg }}>{fileName}</span>
      </div>

      {/* Editor body */}
      <div style={{ flex: 1, display: "flex", minHeight: 0, position: "relative" }}>
        <div
          className="ce-scroll"
          style={{
            flex: 1,
            display: "flex",
            overflow: config.layout.wrapLines ? "auto hidden" : "auto",
            position: "relative",
          }}
        >
          {/* Gutter */}
          {config.display.isLineNumbersEnabled && (
            <div
              className="ce-gutter"
              style={{
                width: config.layout.gutterWidth,
                background: theme.gutter,
                color: theme.gutterFg,
                paddingTop: config.layout.textContainerInset?.top ?? 8,
                paddingBottom: config.layout.textContainerInset?.bottom ?? 8,
                fontFamily: "var(--font-mono)",
                fontSize: Math.max(10, config.display.fontSize - 2),
                userSelect: "none",
                flexShrink: 0,
                borderRight: `0.5px solid ${theme.appearance === "dark" ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)"}`,
                position: "sticky",
                left: 0,
                zIndex: 2,
              }}
            >
              {renderedLines.map(({ idx }) => {
                const isActive = idx === activeLine;
                const annotation = config.display.enableAnnotations ? detectAnnotation(lines[idx]) : null;
                const fold = foldStartMap.get(idx);
                return (
                  <div
                    key={idx}
                    className="ce-gutter-line"
                    onClick={() => setActiveLine(idx)}
                    style={{
                      height: lineHeight,
                      lineHeight: `${lineHeight}px`,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "flex-end",
                      gap: 4,
                      padding: `0 ${config.layout.lineNumberPadding}px 0 6px`,
                      color: isActive ? theme.gutterFgActive : theme.gutterFg,
                      fontWeight: isActive ? 600 : 400,
                      fontVariantNumeric: "tabular-nums",
                      cursor: "default",
                    }}
                  >
                    {/* Annotation badge */}
                    {annotation && (
                      <span
                        title={ANNOTATION_STYLE[annotation].label}
                        style={{
                          width: config.layout.annotationBadgeSize,
                          height: config.layout.annotationBadgeSize,
                          borderRadius: 4,
                          background: ANNOTATION_STYLE[annotation].fg,
                          color: theme.appearance === "dark" ? "#000" : "#fff",
                          display: "inline-flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontSize: 9,
                          fontWeight: 700,
                          marginRight: 2,
                          flexShrink: 0,
                        }}
                      >
                        {ANNOTATION_STYLE[annotation].glyph}
                      </span>
                    )}
                    {/* Folding control */}
                    {config.display.showFoldingControls && fold && (
                      <span
                        onClick={(e) => { e.stopPropagation(); toggleFold(idx); }}
                        style={{
                          width: config.layout.foldingControlSize,
                          height: config.layout.foldingControlSize,
                          display: "inline-flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontSize: 9,
                          color: theme.gutterFg,
                          cursor: "pointer",
                          transform: collapsed.has(idx) ? "rotate(-90deg)" : "rotate(0deg)",
                          transition: config.performance.animateCodeFolding ? "transform 200ms cubic-bezier(0.16,1,0.3,1)" : "none",
                          flexShrink: 0,
                        }}
                      >
                        ▾
                      </span>
                    )}
                    <span>{idx + 1}</span>
                  </div>
                );
              })}
            </div>
          )}

          {/* Lines */}
          <div
            className="ce-lines"
            onClick={(e) => {
              const rect = e.currentTarget.getBoundingClientRect();
              const y = e.clientY - rect.top - (config.layout.textContainerInset?.top ?? 8);
              const idx = Math.max(0, Math.min(renderedLines.length - 1, Math.floor(y / lineHeight)));
              if (renderedLines[idx]) setActiveLine(renderedLines[idx].idx);
            }}
            style={{
              flex: 1,
              padding: `${config.layout.textContainerInset?.top ?? 8}px ${config.layout.textContainerInset?.right ?? 8}px ${config.layout.textContainerInset?.bottom ?? 8}px ${config.layout.textContainerInset?.left ?? 12}px`,
              whiteSpace: config.layout.wrapLines ? "pre-wrap" : "pre",
              wordBreak: config.layout.wrapLines ? "break-word" : "normal",
              position: "relative",
              minWidth: 0,
              letterSpacing: config.layout.characterSpacing,
            }}
          >
            {renderedLines.map(({ idx, text }, vis) => {
              const isActive = idx === activeLine;
              const fold = foldStartMap.get(idx);
              const isCollapsed = collapsed.has(idx);
              return (
                <div
                  key={idx}
                  className="ce-line"
                  style={{
                    height: lineHeight,
                    lineHeight: `${lineHeight}px`,
                    background: isActive && config.display.highlightSelectedLine ? theme.activeLine : "transparent",
                    position: "relative",
                  }}
                >
                  {/* Indent guides */}
                  {renderIndentGuides(text, config, theme)}

                  {tokenizeLine(text, language).map((tok, i) => (
                    <Token
                      key={i}
                      tok={tok}
                      theme={theme}
                      showInvisible={config.display.showInvisibleCharacters}
                    />
                  ))}

                  {/* Selection highlight on a contrived range on the active line for demo */}
                  {isActive && vis === 6 && (
                    <span style={{
                      position: "absolute",
                      left: 56, width: 84, top: 2, height: lineHeight - 4,
                      background: theme.selection,
                      borderRadius: 2,
                      pointerEvents: "none",
                      mixBlendMode: theme.appearance === "dark" ? "screen" : "multiply",
                    }} />
                  )}

                  {/* Collapsed fold pill */}
                  {fold && isCollapsed && (
                    <span style={{
                      marginLeft: 8,
                      padding: "0 6px",
                      borderRadius: 4,
                      background: theme.appearance === "dark" ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.07)",
                      color: theme.gutterFg,
                      fontFamily: "var(--font-mono)",
                      fontSize: config.display.fontSize - 2,
                      cursor: "pointer",
                    }}
                    onClick={(e) => { e.stopPropagation(); toggleFold(idx); }}
                    >
                      ⋯ {fold.end - fold.start} lines
                    </span>
                  )}
                </div>
              );
            })}

            {/* Cursor caret on active line */}
            <CaretLayer
              activeLine={activeLine}
              renderedLines={renderedLines}
              lineHeight={lineHeight}
              theme={theme}
              padding={{
                top: config.layout.textContainerInset?.top ?? 8,
                left: config.layout.textContainerInset?.left ?? 12,
              }}
              fontSize={config.display.fontSize}
            />

            {/* Inline completion popover */}
            {config.behavior.enableCodeCompletion && config.behavior.showInlineCompletionSuggestions && (
              <CompletionPopover
                activeLine={activeLine}
                renderedLines={renderedLines}
                lineHeight={lineHeight}
                theme={theme}
                padding={{
                  top: config.layout.textContainerInset?.top ?? 8,
                  left: config.layout.textContainerInset?.left ?? 12,
                }}
                fontSize={config.display.fontSize}
              />
            )}
          </div>
        </div>

        {/* Minimap */}
        {config.display.showMinimap && (
          <Minimap
            lines={lines}
            language={language}
            theme={theme}
            width={config.layout.minimapWidth}
            activeLine={activeLine}
          />
        )}
      </div>

      {/* Status bar */}
      <StatusBar
        theme={theme}
        config={config}
        language={language}
        activeLine={activeLine}
        totalLines={lines.length}
        status={status}
      />
    </div>
  );
}

/* ---------- Token render -------- */
function Token({ tok, theme, showInvisible }) {
  if (tok.type === "plain") {
    if (showInvisible) {
      const visible = tok.text
        .replace(/ /g, "·")
        .replace(/\t/g, "→   ");
      return <span style={{ color: theme.appearance === "dark" ? "rgba(255,255,255,0.18)" : "rgba(0,0,0,0.22)" }}>{visible}</span>;
    }
    return <span>{tok.text}</span>;
  }
  const color = theme[tok.type] || theme.fg;
  const fs = tok.type === "comment" ? "italic" : "normal";
  return <span style={{ color, fontStyle: fs }}>{tok.text}</span>;
}

/* ---------- Indent guides -------- */
function renderIndentGuides(text, config, theme) {
  const m = text.match(/^(\s*)/);
  if (!m) return null;
  const ws = m[1];
  const tabSize = config.layout.tabWidth;
  const spaces = ws.replace(/\t/g, " ".repeat(tabSize)).length;
  const guides = Math.floor(spaces / tabSize);
  if (guides === 0) return null;
  const guideColor = theme.appearance === "dark" ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.07)";
  const ch = config.display.fontSize * 0.6; // approx mono char width
  return (
    <span aria-hidden style={{ position: "absolute", left: 0, top: 0, bottom: 0, pointerEvents: "none" }}>
      {Array.from({ length: guides }).map((_, i) => (
        <span key={i} style={{
          position: "absolute",
          left: (i + 1) * tabSize * ch + 0.5,
          top: 0, bottom: 0, width: 1,
          background: guideColor,
        }} />
      ))}
    </span>
  );
}

/* ---------- Caret -------- */
function CaretLayer({ activeLine, renderedLines, lineHeight, theme, padding, fontSize }) {
  const visIdx = renderedLines.findIndex(r => r.idx === activeLine);
  if (visIdx < 0) return null;
  const text = renderedLines[visIdx].text;
  // approximate caret column at end of trimmed text + a comfortable offset
  const ch = fontSize * 0.6;
  const col = Math.min(text.length, 30);
  return (
    <span
      style={{
        position: "absolute",
        top: padding.top + visIdx * lineHeight + 2,
        left: padding.left + col * ch,
        width: 1.5,
        height: lineHeight - 4,
        background: theme.appearance === "dark" ? "#fff" : "#000",
        animation: "ce-caret-blink 1s step-end infinite",
        pointerEvents: "none",
      }}
    />
  );
}

/* ---------- Completion popover -------- */
function CompletionPopover({ activeLine, renderedLines, lineHeight, theme, padding, fontSize }) {
  const visIdx = renderedLines.findIndex(r => r.idx === activeLine);
  if (visIdx < 0) return null;
  const items = [
    { kind: "func", label: "configure(_:)", detail: "EditorConfiguration", glyph: "ƒ", color: theme.function },
    { kind: "type", label: "EditorConfiguration", detail: "struct", glyph: "T", color: theme.type },
    { kind: "prop", label: "configuration", detail: "var", glyph: "P", color: theme.property },
    { kind: "key",  label: "codeTheme(_:)", detail: "modifier", glyph: "M", color: theme.keyword },
  ];
  const ch = fontSize * 0.6;
  const left = padding.left + 30 * ch + 6;
  const top  = padding.top + visIdx * lineHeight + lineHeight + 4;
  const dark = theme.appearance === "dark";
  return (
    <div style={{
      position: "absolute",
      top, left,
      width: 280,
      background: dark ? "rgba(40,40,42,0.92)" : "rgba(255,255,255,0.95)",
      backdropFilter: "blur(20px) saturate(180%)",
      WebkitBackdropFilter: "blur(20px) saturate(180%)",
      border: `0.5px solid ${dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)"}`,
      borderRadius: 10,
      boxShadow: dark ? "0 8px 30px rgba(0,0,0,0.4)" : "0 8px 24px rgba(0,0,0,0.18)",
      fontFamily: "var(--font-sans)",
      fontSize: 12,
      overflow: "hidden",
      zIndex: 5,
    }}>
      {items.map((it, i) => (
        <div key={i} style={{
          display: "flex", alignItems: "center", gap: 10,
          padding: "6px 10px",
          background: i === 0 ? (dark ? "rgba(10,132,255,0.22)" : "rgba(0,122,255,0.14)") : "transparent",
          color: theme.fg,
        }}>
          <span style={{
            width: 18, height: 18, borderRadius: 4,
            background: it.color + "26",
            color: it.color,
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            fontWeight: 700, fontSize: 10, fontFamily: "var(--font-mono)",
          }}>{it.glyph}</span>
          <span style={{ fontFamily: "var(--font-mono)", fontWeight: 500 }}>{it.label}</span>
          <span style={{ marginLeft: "auto", color: dark ? "rgba(255,255,255,0.45)" : "rgba(0,0,0,0.45)", fontSize: 11 }}>{it.detail}</span>
        </div>
      ))}
      <div style={{
        padding: "5px 10px",
        borderTop: `0.5px solid ${dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"}`,
        color: dark ? "rgba(255,255,255,0.45)" : "rgba(0,0,0,0.5)",
        fontSize: 10,
        display: "flex", gap: 12,
      }}>
        <span>↑↓ navigate</span>
        <span>⏎ accept</span>
        <span style={{ marginLeft: "auto" }}>4 results</span>
      </div>
    </div>
  );
}

/* ---------- Minimap -------- */
function Minimap({ lines, language, theme, width, activeLine }) {
  const dark = theme.appearance === "dark";
  return (
    <div style={{
      width, flexShrink: 0,
      background: dark ? "rgba(0,0,0,0.18)" : "rgba(0,0,0,0.04)",
      borderLeft: `0.5px solid ${dark ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)"}`,
      padding: "8px 8px",
      overflow: "hidden",
      position: "relative",
    }}>
      {lines.slice(0, 80).map((line, i) => {
        const tokens = tokenizeLine(line, language);
        return (
          <div key={i} style={{ display: "flex", gap: 1, height: 3, marginBottom: 1, opacity: i === activeLine ? 1 : 0.7 }}>
            {tokens.slice(0, 30).map((t, j) => {
              const w = Math.min(20, t.text.length * 1.2);
              const c = t.type === "plain" ? "transparent" : (theme[t.type] || theme.fg);
              return <span key={j} style={{ height: 2, width: w, background: c, borderRadius: 0.5 }} />;
            })}
          </div>
        );
      })}
      {/* viewport indicator */}
      <div style={{
        position: "absolute",
        left: 4, right: 4,
        top: Math.max(0, activeLine * 4 - 30),
        height: 80,
        background: dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.06)",
        border: `0.5px solid ${dark ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.12)"}`,
        borderRadius: 4,
        pointerEvents: "none",
      }} />
    </div>
  );
}

/* ---------- Status bar -------- */
function StatusBar({ theme, config, language, activeLine, totalLines, status }) {
  const dark = theme.appearance === "dark";
  const lang = LANGUAGES.find(l => l.id === language);
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 14,
      padding: "0 12px",
      height: 26,
      background: theme.surface,
      borderTop: `0.5px solid ${dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.06)"}`,
      color: dark ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.6)",
      fontFamily: "var(--font-sans)",
      fontSize: 11,
      flexShrink: 0,
    }}>
      <span style={{ display: "inline-flex", alignItems: "center", gap: 5 }}>
        <span style={{ width: 6, height: 6, borderRadius: "50%", background: status === "ready" ? "#30D158" : "#FF9F0A" }} />
        {status === "ready" ? "Ready" : "Indexing…"}
      </span>
      <span>·</span>
      <span>Ln {activeLine + 1}, Col {1}</span>
      <span>·</span>
      <span>{totalLines} lines</span>
      <span>·</span>
      <span>{config.layout.insertSpacesForTabs ? "Spaces" : "Tabs"}: {config.layout.tabWidth}</span>
      <span>·</span>
      <span>{config.layout.wrapLines ? "Wrap" : "No-wrap"}</span>
      <span style={{ marginLeft: "auto" }}>{lang?.label || language}</span>
      <span>·</span>
      <span>{config.performance.useHardwareAcceleration ? "GPU" : "CPU"}</span>
      <span>·</span>
      <span>{Math.round(config.textChangeMs ?? config.performance.textChangeDebounceInterval ?? 100)}ms debounce</span>
    </div>
  );
}

/* ---------- Tiny language glyph in tab -------- */
function LangGlyph({ language, color }) {
  const map = {
    swift: "swift", typescript: "TS", python: "Py", rust: "Rs", json: "{ }",
  };
  return (
    <span style={{
      width: 16, height: 16, borderRadius: 3,
      background: color + "33", color, fontFamily: "var(--font-mono)", fontSize: 9, fontWeight: 700,
      display: "inline-flex", alignItems: "center", justifyContent: "center",
      flexShrink: 0,
    }}>{map[language] || "·"}</span>
  );
}

window.CodeEditor = CodeEditor;
