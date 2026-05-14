# Feature Matrix

What works on the package's declared Apple platforms. Reflects the package as of `0.2.0` (platform floor: macOS / iOS 26.3+, Swift 6.3, strict concurrency, TextKit2-only). Mac Catalyst was retired in 0.2.0.

## Library products

| Product | macOS | iOS / iPadOS | Notes |
|---|:---:|:---:|---|
| `CodeEditorPlugin` | ✅ | ✅ | Core editor framework. The `EdgeInsets` value type is exported as `FrameworkEdgeInsets` to avoid clashing with `SwiftUI.EdgeInsets` on iOS. |
| `CodeEditorUI` | ✅ | ⚠️ | `EditorSidebarShell` is macOS-only by design. `EditorTabStrip`, `EditorStatusBar`, `EditorCommandPalette` are SwiftUI components, but the sample uses the chrome shell only on macOS. |
| `CodeEditorDesignTokens` | ✅ | ✅ | Standalone tokens — depend on this directly if you only need design tokens without the editor. |
| `CodeEditorSample` | ✅ | ✅ | macOS shell uses 3-pane `RootWindow`; iOS uses `IOSRootView` (`NavigationSplitView`). `Settings` scene and command palette are macOS-only. |

`Package.swift` declares macOS and iOS only. visionOS is not a package platform and is not exercised by the sample or CI.

**Mac Catalyst:** not supported. Removed in 0.2.0. Use the native macOS path (AppKit-backed SwiftUI) for Mac, and the iOS path for iPad. Apple Silicon Macs can also run the iOS build directly without Catalyst.

## Editor capabilities

| Capability | macOS | iOS | Where |
|---|:---:|:---:|---|
| TextKit2 layout | ✅ | ✅ | `NSTextLayoutManager` directly; `Sources/CodeEditorPlugin/Text/TextKitBridge.swift` is the TK2-safe accessor funnel |
| Syntax highlighting (25 concrete languages + plain text) | ✅ | ✅ | `Sources/CodeEditorPlugin/Languages/` |
| SwiftSyntax-backed Swift highlighter | ✅ | ✅ | unconditional dependency on `swift-syntax` |
| Range-based highlighting (experimental) | ✅ | ✅ | `Display.useRangeStoreHighlighting` and `Performance.usesRangeBasedHighlighting` toggles |
| Streaming highlighter for large files | ✅ | ✅ | adaptive chunk sizes via `StreamingHighlighter.Configuration` |
| Async / debounced highlighter | ✅ | ✅ | 300 ms debounce by default |
| Code folding | ✅ | ✅ | 250 ms detection debounce; cache evicted on memory pressure |
| Annotations (data-source driven badges) | ✅ | ✅ | `Sources/CodeEditorPlugin/Annotations/`; host apps provide TODO/FIXME/diagnostic markers. |
| Code completion | ✅ | ✅ | single-character trigger guard prevents paste storms |
| LSP integration | ✅ | ⚠️ | macOS has `LSPManager` for local process-backed servers. iOS has the all-platform `LSPClient` / `WebSocketTransport` primitives for remote servers, but no local process manager. |
| Minimap | ✅ | ✅ | `Layout.isMinimapVisible`, `Layout.minimapWidth` |
| Smart editing (auto-bracket, multi-cursor) | ✅ | ✅ | `Features/SmartEditing*` |
| Search / replace engine | ✅ | ✅ | `Features/SearchReplaceEngine.swift` (UI not provided) |
| Performance HUD components | ✅ | ✅ | `Performance/PerformanceViews.swift` |

## Sample app capabilities

| Demo | macOS shell | iOS shell | Notes |
|---|:---:|:---:|---|
| 8 built-in presets (Default / Minimal / Read-only / Markdown / Presentation / macOS / iOS / Platform-Optimized) | ✅ | ✅ | exposed via `PresetCatalog` |
| Theme picker (zed-trek family, 20 variants) | ✅ | ✅ | `ThemeCatalog.bundled("zed-trek")` |
| Language picker (all 25 concrete languages + plain text) | ✅ | ✅ | `LanguageCatalog` |
| Per-section knob panels (Display / Layout / Behavior / Performance / Workspace / Annotations) | ✅ | ✅ | iOS shows the same controls in a NavigationSplitView sidebar |
| `Layout.textContainerInset` sliders | ✅ | ✅ | top / left / bottom / right edge controls |
| Range-store highlighting toggles | ✅ | ✅ | exposes both `Display.useRangeStoreHighlighting` and `Performance.usesRangeBasedHighlighting` |
| Multi-tab in-memory document store | ✅ | ✅ | Framework-level `EditorDocuments` + `EditorDocument`; sample extends with file I/O via `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` |
| Command palette (⌘⇧P) | ✅ | — | macOS-only `EditorCommandPalette` |
| Live configuration inspector (right sidebar) | ✅ | — | bespoke `InspectorSidebar` panel; the framework's `EditorSidebarShell` ships from `CodeEditorUI` but the sample does not consume it yet |
| File open / save | ⚠️ | — | `⌘S` works on macOS for tabs that already have a URL (`EditorDocuments.save(_:)`); Save-As for `Untitled-*` tabs and `⌘O` are deferred. iOS uses neither yet. |
| LSP inspector panel | ✅ | — | `LSPInspectorPanel` ships live state, capability checklist, severity counts, and resolved server path via `LSPSampleCoordinator` (macOS only) |
| Custom completion provider demo | ✅ | — | `DemoCompletionProvider` exercises `SnippetTemplate`, `CompletionProviderUtilities.fuzzyFilter`, and `CompletionRankingModel` (macOS inspector only) |
| Completion inspector panel | ✅ | — | `CompletionInspectorPanel` shows registered providers + recent activity ring via `CompletionSampleCoordinator` (macOS only) |
| Performance inspector panel | ✅ | — | `PerformanceInspectorPanel` shows FPS, memory pressure, adaptive-mode badge, and a Report sheet wrapping the framework's `PerformanceInsightsPanel` + `DetailedPerformanceReportView`. Backed by `PerformanceObservation` + `.performanceObserver(_:)` modifier. macOS only. |
| Folding controls and commands | ✅ | ✅ | gutter controls are framework-level; macOS also exposes fold commands through the command palette |
| Annotations demo | ✅ | ✅ | TODO / FIXME / WARNING / ERROR knobs and breakpoint toggles feed `AnnotationsHub` |
| Search / replace UI | ✅ | — | macOS sample ships `FindReplaceOverlay`; iOS keeps the engine available without sample UI |
| Theme builder | — | — | **deferred** |
| Font-family picker | — | — | **deferred** |

## Distribution

| Item | Status |
|---|---|
| MIT license | ✅ `LICENSE` at repo root |
| Canonical repo URL | ✅ `https://github.com/ajmcclary/CodeEditorPlugin.git` |
| Tagged release | ⚠️ No git tags are published on `origin` yet; SwiftPM consumers should track `main` |
| GitHub Actions CI | ✅ `swift-build-test`, `ios-build`, `lint` workflows |
| Strict-concurrency clean build | ✅ `swift build` produces no warnings under `StrictConcurrency` |
| Public `@unchecked Sendable` documented | ✅ all 16 sites carry safety comments |
| Swift 6 strict concurrency | ✅ `.swiftLanguageMode(.v6)` + `.enableExperimentalFeature("StrictConcurrency")` |

## See also

- [`docs/GettingStarted.md`](GettingStarted.md) — install + quick integration
- [`docs/Concurrency/swift6.md`](Concurrency/swift6.md) — concurrency model
- [`docs/Performance/`](Performance/) — performance subsystem reference
- [`docs/LSP/integration.md`](LSP/integration.md) — language server setup
