# CodeEditorSample Workflow

**Sample app operations** - Builds, tests, and runs the `CodeEditorSample` SwiftPM target.

## Description

`CodeEditorSample` is an executable target inside the main package. There is no separate `CodeEditorSample/` package directory, so run every command from `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`.

## Usage

```
@sample-app-workflow
```

## Operations

### 1. Build

```bash
swift build --target CodeEditorSample
```

### 2. Test

```bash
swift test --filter CodeEditorSampleTests
```

### 3. Run

```bash
swift run CodeEditorSample
```

You can also use the project helper:

```bash
./Scripts/run-sample.sh debug
```

## Demo Features

Validate the sample app against the current framework surface:

- Language picker covers all 25 concrete languages plus plain text.
- Theme switching uses the bundled LCARS Dark and Zed-compatible theme family.
- Configuration knobs update nested `EditorConfiguration` values directly.
- Command palette, tab strip, status bar, sidebars, and glass surface come from `CodeEditorUI`.
- Annotation, search, LSP status, and performance panels exercise public APIs.

## Success Criteria

- `swift build --target CodeEditorSample` succeeds.
- `swift test --filter CodeEditorSampleTests` succeeds.
- `swift run CodeEditorSample` launches the demo app.
- No commands assume a separate sample package directory.

## File Locations

- **Sample Sources**: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorSample/`
- **Sample Tests**: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Tests/CodeEditorSampleTests/`
- **Run Helper**: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Scripts/run-sample.sh`

## Related Workflows

- Run `@swift-quality-check` for full validation.
- Run `@cross-platform-test` for platform-specific build checks.
- Run `@documentation-update` after sample-facing API or metric changes.
- Run `@performance-analysis` if the demo exposes rendering or memory issues.
