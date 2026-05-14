# CodeEditorSample

Demo application target for the `CodeEditorPlugin` framework. It exercises the
public APIs from a SwiftUI host so you can see the editor, gutter, annotations,
LSP wiring, completion, and performance instrumentation in one place.

## Running the sample

`CodeEditorSample` is an **executable target inside the package**, not a
standalone directory or workspace. There is no `Package.swift` here and
`swift build` from this directory will fail.

From the package root (`CodeEditorPlugin/`):

```bash
# Debug run (default)
swift run CodeEditorSample

# Or use the helper script
./Scripts/run-sample.sh           # debug
./Scripts/run-sample.sh release   # optimized
```

Build only:

```bash
swift build --target CodeEditorSample
```

## What's inside

- `App/` — `CodeEditorSampleApp`, `AppState`, runtime wiring (LSP coordinator,
  diagnostics bridge, completion telemetry, performance polling).
- `Documents/` — Sample-side document model (`DocumentStore`, `TabModel`). The
  framework does not yet ship an `EditorDocument` recipe; this is the host's
  workaround.
- `EditorActions/`, `Sidebars/`, `KnobPanels/`, `Switchers/`,
  `CommandPalette/` — UI chrome that drives the editor.
- `iOS/` — Conditionally-compiled iOS variants of the chrome.
- `Resources/` — Bundled sample assets.

## Platform notes

- macOS gets the full inspector experience (LSP, completion, performance).
- iOS builds compile but several inspector panels are deliberately macOS-only;
  the iOS UI surfaces what's available without crashing on missing chrome.
