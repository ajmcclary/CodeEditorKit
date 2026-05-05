/* Sample code snippets per supported language. Used to demo syntax
   highlighting + folding + annotations. Kept short for prototype clarity. */

const SAMPLES = {
  swift: `import SwiftUI
import CodeEditorPlugin

// MARK: - Editor

/// Hosts a CodeEditor and forwards configuration via SwiftUI environment.
struct EditorScreen: View {
    @State private var source: String = defaultSource
    @State private var language: CodeLanguage = .swift

    var body: some View {
        CodeEditor(text: $source)
            .codeLanguage(language)
            .codeTheme(.xcode)
            .lineNumbers(true)
            .highlightSelectedLine(true)
            .tabWidth(4)
            .enableCodeFolding(true)
            // TODO: surface presets in the toolbar
            .frame(minWidth: 480, minHeight: 320)
    }

    private static var defaultSource: String {
        "print(\\"Hello, AJ.\\")"
    }
}

// FIXME: wire LSP completion provider when running on macOS.
func attachLSP(to editor: CodeEditorView) async throws {
    let url = URL(string: "wss://lsp.example.com/swift")!
    let cfg = RemoteLSPConfiguration(serverURL: url, authentication: .bearerToken(token))
    editor.configuration.lsp.servers["swift"] = .remote(cfg)
}`,

  typescript: `// CodeEditorPlugin TypeScript demo
import { CodeEditor, EditorConfiguration } from "code-editor-plugin";

interface EditorProps {
  source: string;
  language?: "swift" | "typescript" | "python";
  readOnly?: boolean;
}

// TODO: memoize the configuration object across renders.
export function buildConfig(props: EditorProps): EditorConfiguration {
  const config: EditorConfiguration = {
    display: { fontSize: 14, isLineNumbersEnabled: true, enableCodeFolding: true },
    layout:  { tabWidth: 2, wrapLines: false, lineHeightMultiple: 1.3 },
    behavior: { autoIndent: true, autoCloseBrackets: true, isEditable: !props.readOnly },
    performance: { useHardwareAcceleration: true, smoothScrolling: true },
  };
  return config;
}

const triggers = new Set([".", ":", "/", "<", " "]);
function shouldComplete(ch: string): boolean {
  return triggers.has(ch);
}`,

  python: `# CodeEditorPlugin — Python sample
from dataclasses import dataclass
from typing import Optional

@dataclass
class EditorConfig:
    font_size: int = 14
    tab_width: int = 4
    wrap_lines: bool = False
    auto_indent: bool = True

# NOTE: presets mirror the Swift API surface
def minimal() -> EditorConfig:
    return EditorConfig(font_size=13, tab_width=2)

def read_only() -> EditorConfig:
    cfg = EditorConfig()
    return cfg  # WARNING: caller must flip is_editable=False

def apply(editor, cfg: EditorConfig) -> None:
    editor.font_size = cfg.font_size
    editor.tab_width = cfg.tab_width`,

  rust: `// Rust sample for CodeEditorPlugin
use std::collections::HashSet;

pub struct EditorConfig {
    pub font_size: f32,
    pub tab_width: usize,
    pub wrap_lines: bool,
}

impl Default for EditorConfig {
    fn default() -> Self {
        Self { font_size: 14.0, tab_width: 4, wrap_lines: false }
    }
}

pub fn trigger_set() -> HashSet<char> {
    let mut s = HashSet::new();
    for c in [':', '.', '/', '<', '"', '\\''] { s.insert(c); }
    s
}`,

  json: `{
  "display": {
    "fontSize": 14,
    "isLineNumbersEnabled": true,
    "enableCodeFolding": true,
    "showFoldingControls": true,
    "highlightSelectedLine": true,
    "showMinimap": false
  },
  "layout": {
    "tabWidth": 4,
    "insertSpacesForTabs": true,
    "wrapLines": false,
    "lineHeightMultiple": 1.2,
    "gutterWidth": 50
  },
  "behavior": {
    "isEditable": true,
    "autoIndent": true,
    "enableCodeCompletion": true,
    "autoCloseBrackets": true,
    "autoCloseQuotes": true
  },
  "performance": {
    "useHardwareAcceleration": true,
    "smoothScrolling": true,
    "renderingUpdateStrategy": "adaptive"
  }
}`,
};

const LANGUAGES = [
  { id: "swift",      label: "Swift",      ext: ".swift" },
  { id: "typescript", label: "TypeScript", ext: ".ts" },
  { id: "python",     label: "Python",     ext: ".py" },
  { id: "rust",       label: "Rust",       ext: ".rs" },
  { id: "json",       label: "JSON",       ext: ".json" },
];

window.SAMPLES = SAMPLES;
window.LANGUAGES = LANGUAGES;
