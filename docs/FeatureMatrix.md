# Feature Matrix

What works on the package's declared Apple platforms. Reflects the current `Package.swift` layout: macOS / iOS 26.0+, Swift 6.3, strict concurrency, TextKit2-only, and a split target graph with a small umbrella product. Mac Catalyst was retired in 0.2.0.

## Library products

| Product | macOS | iOS / iPadOS | Notes |
|---|:---:|:---:|---|
| `CodeEditorKit` | ✅ | ✅ | Umbrella framework. It re-exports the common editor entry points (`CodeEditorCommon`, `CodeEditorConfiguration`, `CodeEditorLanguages`, `CodeEditorSwiftUI`, `DesignKitThemes`, `CodeEditorView`) while building the feature targets it depends on. |
| `CodeEditorView` | ✅ | ✅ | Lower-level TextKit2 editor surface, layout coordination, in-document search, folding presentation, document store, and view-coupled LSP/symbol adapters. |
| `CodeEditorSwiftUI` | ✅ | ✅ | Declarative `CodeEditor` wrapper, SwiftUI environment values, controller bridge, active-document binding, and modifier APIs. |
| `CodeEditorUI` | ✅ | ⚠️ | Optional SwiftUI chrome. `EditorSidebarShell` is macOS-oriented by design; `EditorTabStrip`, `EditorStatusBar`, and `EditorCommandPalette` are portable SwiftUI components, but the sample uses the full chrome shell only on macOS. |
| `CodeEditorDiagnostics` | ✅ | ✅ | Performance monitoring, memory monitoring, adaptive performance mode, production metrics, and SwiftUI performance views. |
| `CodeEditorLSP` | ✅ | ✅ | LSP wire types, client, manager, transports, retry/path configuration, and remote WebSocket support. Local process-backed servers are macOS-only. |
| `CodeEditorLayout` | ✅ | ✅ | Reusable layout primitives and chrome internals: completion cells, fold chevrons, glass surfaces, layout providers, minimap style data, and event bus. |
| `CodeEditorSearch` | ✅ | ✅ | Opt-in project-wide file-search protocols plus the portable search adapter. The in-document search/replace engine lives in `CodeEditorView`. |
| `CodeEditorWorkspace` | ✅ | ✅ | Opt-in workspace file-tree protocols. The concrete `MacOSWorkspaceFileManager` is AppKit-conditional; protocol surfaces remain portable. |
| `CodeEditorSample` | ✅ | ✅ | macOS shell uses 3-pane `RootWindow`; iOS uses `IOSRootView` (`NavigationSplitView`). `Settings` scene and command palette are macOS-only. |

`Package.swift` declares macOS and iOS only. visionOS is not a package platform and is not exercised by the sample or CI.

**Mac Catalyst:** not supported. Removed in 0.2.0. Use the native macOS path (AppKit-backed SwiftUI) for Mac, and the iOS path for iPad. Apple Silicon Macs can also run the iOS build directly without Catalyst.

## Editor capabilities

| Capability | macOS | iOS | Where |
|---|:---:|:---:|---|
| TextKit2 layout | ✅ | ✅ | `NSTextLayoutManager` directly; `Sources/CodeEditorView/Text/TextKitBridge.swift` is the TK2-safe accessor funnel |
| Syntax highlighting (25 concrete languages + plain text) | ✅ | ✅ | `Sources/CodeEditorLanguages/` |
| SwiftSyntax-backed Swift highlighter | ✅ | ✅ | unconditional dependency on `swift-syntax` |
| Range-based highlighting (experimental) | ✅ | ✅ | `Display.useRangeStoreHighlighting` and `Performance.usesRangeBasedHighlighting` toggles |
| Streaming highlighter for large files | ✅ | ✅ | adaptive chunk sizes via `StreamingHighlighter.Configuration` |
| Async / debounced highlighter | ✅ | ✅ | 300 ms debounce by default |
| Code folding | ✅ | ✅ | 250 ms detection debounce; cache evicted on memory pressure |
| Annotations (data-source driven badges) | ✅ | ✅ | Data/view chrome in `Sources/CodeEditorAnnotations/`; the `AnnotationsDataSource` protocol remains view-coupled in `Sources/CodeEditorView/Annotations/`. Host apps provide TODO/FIXME/diagnostic markers. |
| Code completion | ✅ | ✅ | single-character trigger guard prevents paste storms |
| LSP integration | ✅ | ⚠️ | `CodeEditorLSP` has all-platform protocol/client/transport primitives. macOS can launch local process-backed servers; iOS uses remote/WebSocket-style integrations. |
| Minimap | ✅ | ✅ | `Layout.isMinimapVisible`, `Layout.minimapWidth` |
| Smart editing (auto-bracket, multi-cursor) | ✅ | ✅ | `Sources/CodeEditorSmartEditing/` |
| Search / replace engine | ✅ | ✅ | `Sources/CodeEditorView/Search/SearchReplaceEngine.swift` (UI not provided) |
| Performance HUD components | ✅ | ✅ | `Sources/CodeEditorDiagnostics/PerformanceViews.swift` |

## Sample app capabilities

| Demo | macOS shell | iOS shell | Notes |
|---|:---:|:---:|---|
| 8 built-in presets (Default / Minimal / Read-only / Markdown / Presentation / macOS / iOS / Platform-Optimized) | ✅ | ✅ | exposed via `PresetCatalog` |
| Theme picker (zed-trek family, 22 variants) | ✅ | ✅ | `ThemeCatalog.all` / `ThemeCatalog.theme(named:)` in the sample, backed by `ThemeFamily.bundled("zed-trek")` |
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
| Canonical repo URL | ✅ `https://github.com/ajmcclary/CodeEditorKit.git` |
| Tagged release | ⚠️ No git tags are published on `origin` yet; SwiftPM consumers should track `main` |
| GitHub Actions CI | ✅ `swift-build-test`, `ios-build`, `lint` workflows |
| Strict-concurrency clean build | ✅ `swift build` produces no warnings under `StrictConcurrency` |
| Public / internal `@unchecked Sendable` documented | ✅ all 34 sites under `Sources/` carry safety comments |
| Swift 6 strict concurrency | ✅ `.swiftLanguageMode(.v6)` + `.enableExperimentalFeature("StrictConcurrency")` |

## See also

- [`docs/GettingStarted.md`](GettingStarted.md) — install + quick integration
- [`docs/Concurrency/swift6.md`](Concurrency/swift6.md) — concurrency model
- [`docs/Performance/`](Performance/) — performance subsystem reference
- [`docs/LSP/integration.md`](LSP/integration.md) — language server setup
