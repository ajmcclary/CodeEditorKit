# CodeEditorSample

[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#quality)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Files](https://img.shields.io/badge/files-43-blue)](#structure)

A comprehensive sample application demonstrating all features of CodeEditorPlugin. Use this to explore capabilities, test configurations, and copy production-ready integration patterns.

## 🚀 Quick Start

```bash
# Run the sample app
swift run

# Run tests
swift test

# Full quality check
swiftlint && swift build && swift test
```

## ✨ What's Demonstrated

### Core Features
- **17 Language Syntax Highlighting**: Live switching between all supported languages
- **Theme System**: Xcode, VS Code Dark, GitHub, and Solarized themes
- **Configuration Options**: Interactive UI for all settings
- **Code Folding**: Visual indicators (▶️/▼) with click-to-fold
- **Annotations**: TODO/FIXME/NOTE badges inline
- **Performance Monitoring**: Real-time metrics display

### Platform Support
- **macOS**: Native window with full keyboard shortcuts
- **iOS/iPadOS**: Touch-optimized with proper keyboard handling  
- **Mac Catalyst**: Adaptive UI combining best of both platforms

### Integration Examples
- SwiftUI environment-based configuration
- Programmatic configuration with builders
- Theme creation and switching
- Language detection from file extensions
- Memory monitoring integration

## 📁 Project Structure

```
CodeEditorSample/
├── Sources/
│   ├── Models/           # Configuration and data models
│   ├── Views/            # SwiftUI views and UI components
│   ├── Services/         # Business logic and coordinators
│   ├── Platform/         # Platform-specific implementations
│   └── Resources/        # Sample code files
└── Tests/               # Sample-specific tests
```

## 💻 Key Integration Patterns

### SwiftUI Setup

```swift
import CodeEditorPlugin
import SwiftUI

struct EditorView: View {
    @State private var code = "// Your code"
    @State private var config = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .codeTheme(.xcode)
            .environment(\.codeEditorConfiguration, config)
    }
}
```

### Configuration Management

```swift
// Using presets
let config = EditorConfiguration.minimal

// Custom configuration
var config = EditorConfiguration()
config.display.showLineNumbers = true
config.display.fontSize = 14
config.layout.tabWidth = 4
config.behavior.autoIndent = true

// Apply to editor
config.apply(to: editorView)
```

### Theme Implementation

```swift
enum ColorTheme: String, CaseIterable {
    case xcode, vsDark, github, solarized
    
    var backgroundColor: PlatformColor {
        switch self {
        case .xcode: 
            return PlatformColor(hex: "#FFFFFF", dark: "#1F1F24")
        case .vsDark: 
            return PlatformColor(hex: "#1E1E1E")
        // ... other themes
        }
    }
}
```

## 🧪 Testing

The sample includes focused tests validating integration patterns:

```bash
# Run all tests
swift test

# Run specific test
swift test --filter ConfigurationUITests
```

## 📋 Requirements

- **Swift**: 6.0+
- **Platforms**: macOS 12.0+, iOS 16.0+, Mac Catalyst 16.0+
- **Xcode**: 16.0+

## 📚 Learning Resources

- **Integration Examples**: See `Views/` for SwiftUI patterns
- **Configuration**: Study `Models/EditorConfiguration.swift`
- **Platform Support**: Check `Platform/` for cross-platform code
- **Sample Code**: Browse `Resources/` for language examples

## 🎉 Ready to Build?

This sample provides everything needed to integrate CodeEditorPlugin into your applications. Explore the features, study the patterns, and create powerful code editing experiences!