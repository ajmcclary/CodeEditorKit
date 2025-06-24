# CodeEditor Sample App

A comprehensive macOS application demonstrating all features of the CodeEditorPlugin package. This sample app provides a complete code editing experience with syntax highlighting, themes, and extensive customization options.

## Overview

This sample app showcases:
- Full-featured code editor with syntax highlighting for 15+ languages
- 6 built-in color themes with real-time switching
- Line numbers, invisible characters, and line highlighting
- Configuration import/export functionality
- Multiple editor instances with different configurations
- Interactive feature tour for new users

## Features

### 1. Configuration Presets

The app includes several pre-configured editor setups:

- **Full Featured**: All features enabled for professional code editing
- **Minimal**: Basic text editing with a clean interface
- **Read Only**: Syntax-highlighted code viewer (non-editable)
- **Markdown**: Optimized for Markdown editing with line wrapping
- **Presentation**: Large fonts and high contrast for demos

### 2. Language Support

Demonstrates syntax highlighting for:
- Swift
- JavaScript/TypeScript
- Python
- Go
- Rust
- C/C++
- Java
- HTML/CSS
- JSON
- Ruby
- Shell/Bash
- Markdown
- YAML
- And more...

### 3. Color Themes

Includes multiple themes:
- Xcode Default
- VS Code Dark
- GitHub Light
- Solarized Dark
- Minimal
- Presentation

### 4. Editor Features

Real-time configurable options:
- **Line Numbers**: Toggle line number display
- **Invisible Characters**: Show/hide spaces, tabs, and line breaks
- **Line Wrapping**: Wrap long lines vs horizontal scrolling
- **Current Line Highlighting**: Highlight the line containing the cursor
- **Font Size**: Adjustable from 10pt to 24pt
- **Tab Width**: Configure spaces per tab (2, 4, or 8)
- **Tab/Space Conversion**: Use tabs or spaces for indentation
- **Line Spacing**: Adjust vertical spacing between lines
- **Editable/Read-only Mode**: Toggle editing capabilities

### 5. Additional Features

- **Configuration Import/Export**: Save and load editor configurations as JSON
- **Status Bar**: Shows cursor position, selection info, and document statistics
- **Menu Commands**: Keyboard shortcuts for common actions
- **Feature Tour**: Interactive introduction to all features
- **Multiple Windows**: Open multiple editor instances

## Running the Sample

1. Navigate to the sample directory:
   ```bash
   cd Example/CodeEditorSample
   ```

2. Run the app:
   ```bash
   swift run CodeEditorSample
   ```

The app will launch as a native macOS application with its own window and menu bar.

## Architecture

### Main Components

- **CodeEditorSampleApp.swift**: Main app entry point with menu commands
- **ContentView.swift**: Split view layout with toolbar and status bar
- **CodeEditorView.swift**: NSViewRepresentable wrapper for STTextView
- **EditorConfigurationView.swift**: Configuration sidebar
- **EditorConfiguration.swift**: Configuration model and presets
- **SampleCodeProvider.swift**: Sample code for each language
- **ThemeProvider.swift**: Color theme definitions
- **CustomAnnotationPlugin.swift**: Example custom plugin

### Key Features

1. **SwiftUI Integration**:
   The app uses a custom NSViewRepresentable wrapper to integrate STTextView with SwiftUI:
   ```swift
   CodeEditorView(
       configuration: configuration,
       text: $text,
       language: "swift"
   )
   ```

2. **Real-time Configuration Updates**:
   All settings update the editor in real-time without requiring a restart.

3. **Theme System**:
   Themes define colors for background, text, keywords, strings, comments, and more.

4. **Status Bar**:
   Shows line/column position, selection range, and total line count.

## Customization

### Adding New Languages

1. Add the language to `SampleCode` enum
2. Provide sample code in `SampleCodeProvider`
3. The regex-based highlighter will automatically support it if defined

### Creating Custom Themes

1. Add new case to `ColorTheme` enum
2. Define colors for each syntax element
3. The theme will appear in the theme selector

### Keyboard Shortcuts

- **⌘⇧L**: Toggle line numbers
- **⌘⇧I**: Toggle invisible characters
- **⌘+**: Increase font size
- **⌘-**: Decrease font size
- **⌘0**: Reset font size

## Requirements

- macOS 14.0 or later
- Swift 6.0 or later
- Xcode 16.0 or later

## Troubleshooting

### Common Issues

1. **Text not visible**: Ensure the theme has proper contrast between text and background colors
2. **Performance with large files**: Disable line numbers and syntax highlighting for files over 10MB
3. **Build errors**: Clean build folder with `swift package clean` and rebuild

## License

This sample is part of the CodeEditorPlugin package and follows the same license terms.