# CodeEditor Sample App

A comprehensive sample application demonstrating the various features and configurations of the CodeEditorPlugin package.

## Overview

This sample app showcases:
- Multiple editor configurations (Full Featured, Minimal, Read-Only, Markdown, Presentation)
- Syntax highlighting for 11+ programming languages
- 5 different color themes
- Custom plugin implementation
- Real-time configuration changes
- Performance optimizations

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
- Swift (using SwiftSyntax)
- JavaScript
- TypeScript
- Python
- Go
- Rust
- C++
- Java
- HTML
- CSS
- JSON

### 3. Color Themes

Includes multiple themes:
- Xcode Default
- VS Code Dark
- GitHub Light
- Solarized Dark
- Minimal
- Presentation

### 4. Editor Features

Configurable options include:
- Line numbers
- Invisible characters
- Line wrapping
- Current line highlighting
- Font size adjustment
- Tab width
- Line spacing
- Hardware acceleration
- Smooth scrolling

### 5. Plugin System

Demonstrates:
- Built-in annotations plugin
- Custom TODO/FIXME highlighting plugin
- Plugin configuration options

## Running the Sample

1. Navigate to the sample directory:
   ```bash
   cd Example/CodeEditorSample
   ```

2. Run the app:
   ```bash
   swift run
   ```

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

### Key Integration Points

1. **STTextView Setup**:
   ```swift
   let textView = STTextView()
   textView.textDelegate = delegate
   textView.showsLineNumbers = true
   textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
   ```

2. **Syntax Highlighting**:
   ```swift
   let highlighter = SyntaxHighlightingCoordinator()
   let language = highlighter.detectLanguage(from: fileExtension)
   let tokens = highlighter.highlight(source: code, language: language)
   ```

3. **Plugin Integration**:
   ```swift
   let plugin = CustomAnnotationPlugin()
   textView.addPlugin(plugin)
   ```

## Customization

### Adding New Languages

1. Add the language to `SampleCode` enum
2. Provide sample code in `SampleCodeProvider`
3. The regex-based highlighter will automatically support it if defined

### Creating Custom Themes

1. Add new case to `ColorTheme` enum
2. Define colors for each syntax element
3. The theme will appear in the theme selector

### Building Custom Plugins

1. Implement the `STPlugin` protocol
2. Create a coordinator for the plugin logic
3. Register event handlers in `setUp`
4. Add the plugin to the text view

## Performance Tips

- Use hardware acceleration for large files
- Enable smooth scrolling for better user experience
- Consider disabling line numbers for very large files
- Use read-only mode when editing is not required

## Troubleshooting

### Build Issues

If you encounter build errors:
1. Ensure you're using Swift 6.0 or later
2. Clean the build folder: `swift package clean`
3. Update dependencies: `swift package update`

### Performance Issues

For better performance:
1. Disable plugins for large files
2. Use minimal theme for reduced rendering
3. Turn off line wrapping for wide content

## License

This sample is part of the CodeEditorPlugin package and follows the same license terms.