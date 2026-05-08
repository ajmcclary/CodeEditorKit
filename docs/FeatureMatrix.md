# Feature Matrix

What works on which Apple platform. Reflects the package as of `0.1.0` (platform floor: macOS / iOS / Mac Catalyst 26.3+, Swift 6.3, strict concurrency).

## Library products

| Product | macOS | iOS / iPadOS | Mac Catalyst | visionOS | Notes |
|---|:---:|:---:|:---:|:---:|---|
| `CodeEditorPlugin` | ✅ | ✅ | ✅ | ✅¹ | Core editor framework. The `EdgeInsets` value type is exported as `FrameworkEdgeInsets` to avoid clashing with `SwiftUI.EdgeInsets` on iOS. |
| `CodeEditorUI` | ✅ | ⚠️ | ✅ | ⚠️ | `EditorSidebarShell` is `#if canImport(AppKit)` — macOS / Catalyst only by design. `EditorTabStrip`, `EditorStatusBar`, `EditorCommandPalette` are pure SwiftUI and work cross-platform. |
| `CodeEditorDesignTokens` | ✅ | ✅ | ✅ | ✅ | Standalone tokens — depend on this directly if you only need design tokens without the editor. |
| `CodeEditorSample` | ✅ | ✅ | ✅ | ⚠️ | Multi-platform sample. macOS shell uses 3-pane `RootWindow`; iOS uses `IOSRootView` (`NavigationSplitView`). `Settings` scene and command palette are macOS-only. |

¹ Inherits from iOS conditional compilation; not actively exercised in the sample.

## Editor capabilities

| Capability | macOS | iOS | Catalyst | Where |
|---|:---:|:---:|:---:|---|
| TextKit2 layout | ✅ | ✅ | ✅ | `Sources/CodeEditorPlugin/Text/TextLayoutManager.swift` |
| TextKit1 fallback (Catalyst) | — | — | ✅ | Activated automatically when `isUsingTextKit1` |
| Syntax highlighting (18 languages) | ✅ | ✅ | ✅ | `Sources/CodeEditorPlugin/Languages/` |
| SwiftSyntax-backed Swift highlighter | ✅ | ✅ | ✅ | unconditional dependency on `swift-syntax` |
| Range-based highlighting (experimental) | ✅ | ✅ | ✅ | `Performance.usesRangeBasedHighlighting` toggle |
| Streaming highlighter for large files | ✅ | ✅ | ✅ | adaptive chunk sizes via `StreamingHighlighter.Configuration` |
| Async / debounced highlighter | ✅ | ✅ | ✅ | 300 ms debounce by default |
| Code folding | ✅ | ✅ | ✅ | 250 ms detection debounce; cache evicted on memory pressure |
| Annotations (TODO / FIXME / MARK) | ✅ | ✅ | ✅ | `Sources/CodeEditorPlugin/Annotations/` |
| Code completion | ✅ | ✅ | ✅ | single-character trigger guard prevents paste storms |
| LSP integration | ✅ | ✅ | ✅ | `Sources/CodeEditorPlugin/LSP/` |
| Minimap | ✅ | ✅ | ✅ | `Layout.isMinimapVisible`, `Layout.minimapWidth` |
| Smart editing (auto-bracket, multi-cursor) | ✅ | ✅ | ✅ | `Features/SmartEditing*` |
| Search / replace engine | ✅ | ✅ | ✅ | `Features/SearchReplaceEngine.swift` (UI not provided) |
| Performance HUD components | ✅ | ✅ | ✅ | `Performance/PerformanceViews.swift` |

## Sample app capabilities

| Demo | macOS shell | iOS shell | Notes |
|---|:---:|:---:|---|
| 8 built-in presets (Default / Minimal / Read-only / Markdown / Presentation / macOS / iOS / Catalyst) | ✅ | ✅ | exposed via `PresetCatalog` |
| Theme picker (zed-trek family, 20 variants) | ✅ | ✅ | `ThemeCatalog.bundled("zed-trek")` |
| Language picker (all 18) | ✅ | ✅ | `LanguageCatalog` |
| Per-section knob panels (Display / Layout / Behavior / Performance) | ✅ | ⚠️ | iOS shows the same controls but in a NavigationSplitView sidebar |
| `Layout.textContainerInset` sliders | ✅ | ✅ | top / left / bottom / right edge controls |
| `Performance.usesRangeBasedHighlighting` toggle | ✅ | ✅ | new in 0.1.0 |
| Multi-tab in-memory document store | ✅ | ✅ | `DocumentStore` |
| Command palette (⌘⇧P) | ✅ | — | macOS-only `EditorCommandPalette` |
| Live configuration inspector (right sidebar) | ✅ | — | uses `EditorSidebarShell` (macOS only) |
| File open / save | — | — | **deferred** — see CHANGELOG |
| LSP demo screen | — | — | **deferred** — `LSPManager` is wired in the framework but the sample doesn't connect to a server |
| Custom completion provider demo | — | — | **deferred** |
| Large-file stress test | — | — | **deferred** |
| Performance HUD overlay | — | — | **deferred** — backing types ship in `Performance/PerformanceViews.swift` |
| Folding visualization | — | — | **deferred** |
| Annotations demo | — | — | **deferred** |
| Search / replace UI | — | — | **deferred** — `SearchReplaceEngine` exists; no UI shipped |
| Theme builder | — | — | **deferred** |
| Font-family picker | — | — | **deferred** |

## Distribution

| Item | Status |
|---|---|
| MIT license | ✅ `LICENSE` at repo root |
| Canonical repo URL | ✅ `https://github.com/ajmcclary/CodeEditorPlugin.git` |
| Tagged release | ⚠️ `v0.1.0` planned post-merge (see CHANGELOG) |
| GitHub Actions CI | ✅ `swift-build-test`, `ios-build`, `lint` workflows |
| Strict-concurrency clean build | ✅ `swift build` produces no warnings under `StrictConcurrency` |
| Public `@unchecked Sendable` documented | ✅ all 16 sites carry safety comments |
| Swift 6 strict concurrency | ✅ `.swiftLanguageMode(.v6)` + `.enableExperimentalFeature("StrictConcurrency")` |

## See also

- [`docs/GettingStarted.md`](GettingStarted.md) — install + quick integration
- [`docs/Concurrency/swift6.md`](Concurrency/swift6.md) — concurrency model
- [`docs/Performance/`](Performance/) — performance subsystem reference
- [`docs/LSP/integration.md`](LSP/integration.md) — language server setup
