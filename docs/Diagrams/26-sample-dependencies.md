# CodeEditorSample — Package Dependencies & Architecture

The CodeEditorSample executable demonstrates CodeEditorPlugin integration. It lives in `Sources/CodeEditorSample/` and depends on the three framework targets.

## Dependency Graph

```mermaid
flowchart LR
    subgraph "Executable Target"
        Sample[CodeEditorSample]
    end

    subgraph "Library Targets"
        Plugin[CodeEditorPlugin]
        UI[CodeEditorUI]
        Tokens[CodeEditorDesignTokens]
    end

    Sample --> Plugin
    Sample --> UI
    Sample --> Tokens
    Plugin --> Tokens
    UI --> Tokens
    UI --> Plugin
```

## Test Targets

```mermaid
flowchart LR
    subgraph "Test Targets"
        PluginTests[CodeEditorPluginTests]
        TokensTests[CodeEditorDesignTokensTests]
        UITests[CodeEditorUITests]
    end

    subgraph "Source Targets"
        Plugin[CodeEditorPlugin]
        UI[CodeEditorUI]
        Tokens[CodeEditorDesignTokens]
    end

    PluginTests --> Plugin
    TokensTests --> Tokens
    UITests --> UI
```

## Sample App Internal Structure

```mermaid
flowchart TB
    subgraph "App Entry Point"
        App[CodeEditorSampleApp]
        Delegate[AppDelegate]
        RootWindow[RootWindow]
        WindowBody[WindowBody]
        SettingsScene[SettingsScene]
    end

    subgraph "State"
        AppState[AppState]
    end

    subgraph "Documents"
        DocStore[DocumentStore]
        Catalog[SampleCodeCatalog]
    end

    subgraph "KnobPanels"
        Display[DisplayKnobsSection]
        Layout[LayoutKnobsSection]
        Behavior[BehaviorKnobsSection]
        Perf[PerformanceKnobsSection]
    end

    subgraph "Sidebars"
        Settings[SettingsSidebar]
        Inspector[InspectorSidebar]
    end

    subgraph "Switchers"
        Presets[PresetCatalog]
        Languages[LanguageCatalog]
        Themes[ThemeCatalog]
    end

    subgraph "CommandPalette"
        CmdPalette[CommandPaletteCatalog]
    end

    App --> RootWindow
    RootWindow --> AppState
    RootWindow --> WindowBody
    WindowBody --> Settings
    WindowBody --> Inspector
    Settings --> Display
    Settings --> Layout
    Settings --> Behavior
    Settings --> Perf
    Settings --> Presets
    Settings --> Languages
    Settings --> Themes
    AppState --> DocStore
    AppState --> Catalog
    AppState --> CmdPalette
```

## Cross-Platform Support

The sample app (and all library targets) target three Apple platforms:

| Platform | Minimum Version |
|----------|----------------|
| macOS | 26.3+ |
| iOS | 26.3+ |
| 26.3+ |

Platform-specific code uses `#if canImport(AppKit)` / `#if canImport(UIKit)` rather than `#if os()`, following the repo's conventions. The sample app is a single codebase that adapts at compile time — there are no separate platform directories.
