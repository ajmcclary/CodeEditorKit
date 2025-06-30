# CodeEditorPlugin

[![Tests](https://img.shields.io/badge/tests-322%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#code-quality-standards)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Mac%20Catalyst-lightgrey)](#requirements)

A powerful, production-ready code editor component for macOS and iOS, built with a modern Swift 6 architecture. CodeEditorPlugin provides world-class performance, extensive customization, and a feature set designed for professional development tools.

Built from the ground up with true cross-platform support in mind, it delivers advanced syntax highlighting, a robust theme system, and seamless native performance on **macOS, iOS, and Mac Catalyst** — not through simple ports, but through a sophisticated platform abstraction layer that respects each platform's unique characteristics.

## ✨ Core Features

- 🚀 **Modern Swift 6 Concurrency:** Built from the ground up with actors for rock-solid thread safety, exceptional performance, and guaranteed responsiveness. This isn't just an update — it's a complete architectural advantage that ensures your editor remains smooth even under heavy load.

- 💻 **True Cross-Platform Architecture:** A sophisticated abstraction layer ensures seamless, native performance on macOS, iOS, and Mac Catalyst. Write your UI code once; our intelligent platform layer handles all the platform-specific details, from touch handling to keyboard shortcuts.

- 🎨 **Advanced Syntax Highlighting:** Best-in-class support for **17 programming languages**, using SwiftSyntax for native Swift AST analysis and high-performance regex engines for other languages. Experience accurate, real-time highlighting that keeps pace with your typing.

- 🔧 **Extensible & Future-Proof:** Features a forward-thinking plugin architecture and Language Server Protocol (LSP) integration for advanced language intelligence. Build on a foundation designed to grow with your needs.

- ✅ **Production-Grade Quality:** Verified with **322 automated tests** (100% passing), ensuring reliability for professional applications. Every commit maintains strict quality standards with **zero linting violations** across 204 files and comprehensive test coverage.

- ⚙️ **Unified Configuration System:** A flexible, nested configuration system with builder patterns and intelligent presets makes customization both simple and powerful. Configure once, apply everywhere.

- 📝 **Rich Editing Experience:** Professional-grade features including line numbers with gutter display, inline `TODO`/`FIXME` annotations with badges, selected line highlighting, invisible character rendering, and smart indentation that understands your code.

- 🎯 **SwiftUI Native:** First-class SwiftUI integration with environment-based configuration, making it as easy to use as any built-in SwiftUI component while maintaining full customization capabilities.

## 📋 Requirements

- **Swift**: 6.0+ (with full actor-based concurrency support)
- **Platforms**:
  - **macOS**: 12.0+ (optimized for macOS 14+)
  - **iOS**: 16.0+ (with proper container architecture)
  - **Mac Catalyst**: 16.0+
- **Xcode**: 16.0+
- **Dependencies**: `swift-syntax` 510.0.0+ (for Swift language support)

## 📦 Installation

### Swift Package Manager

Add CodeEditorPlugin as a dependency to your project.

1. In Xcode: **File → Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/ajmcclary/CodeEditorPlugin.git`
3. Select your preferred version rule.

Or, add it directly to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
]
```

## 🚀 Quick Start

### SwiftUI Integration (Recommended)

The modern SwiftUI API provides the cleanest and most powerful integration.

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
        func greetWorld() {
            print("Hello, CodeEditorPlugin!")
            // TODO: Add more features
        }
        """
    @State private var configuration = EditorConfiguration.default

    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
            .environment(\.codeEditorConfiguration, configuration)
            .frame(minHeight: 400)
            .padding()
    }
}
```

### AppKit/UIKit Integration

For direct framework integration, the plugin provides platform-aware components.

```swift
import CodeEditorPlugin
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

class ViewController: PlatformViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let textView = CodeEditorView()
        textView.text = "// Your code here"
        
        // Apply a standard configuration
        let config = EditorConfiguration.default
        config.apply(to: textView)
        
        // Set language for syntax highlighting
        textView.setLanguage(fileExtension: "swift")
        
        // Add to view hierarchy...
    }
}
```

## 🏗️ Architecture

CodeEditorPlugin features a clean, modern architecture optimized for performance, maintainability, and extensibility. Every architectural decision prioritizes developer productivity and code reliability.

### Feature-Based Structure

The codebase is organized by feature rather than by type, making it intuitive to understand, maintain, and extend. This clean, modular design reduces cognitive load, isolates functionality, and makes the codebase more approachable for new contributors.

- **`Core/`**: Core text editing components including `CodeEditorView` (the main TextKit2-based editor) and `AnnotationsDataSource` (for inline code annotations)
- **`Configuration/`**: The unified configuration system centered around `EditorConfiguration` with its nested structure for display, layout, behavior, and performance settings
- **`SyntaxHighlighting/`**: All highlighting logic managed by `SyntaxHighlightingCoordinator`, supporting both AST-based (Swift) and regex-based (other languages) highlighting
- **`Layout/`**: Cross-platform view components like `GutterView` for line numbers and `CodeEditorContainerView` for proper iOS text containment
- **`Platform/`**: The sophisticated cross-platform abstraction layer that makes true multi-platform support possible
- **`SwiftUI/`**: Native SwiftUI integration including `CodeEditor` view and environment-based configuration support

### Platform Abstraction System

At the heart of CodeEditorPlugin's cross-platform capabilities is a sophisticated abstraction layer that goes beyond simple conditional compilation. This system provides:

- **Unified Type System**: Write once using types like `PlatformColor`, `PlatformFont`, and `PlatformView` — the abstraction layer automatically maps to the correct platform-specific types
- **Capability Detection**: Runtime detection of platform features ensures your code gracefully handles platform differences
- **Semantic APIs**: Platform-appropriate behaviors for gestures, keyboard handling, and UI patterns
- **Zero Compromise**: Each platform gets a truly native experience, not a lowest-common-denominator port

Example of the abstraction in action:
```swift
// This code works identically on macOS, iOS, and Mac Catalyst
let backgroundColor = PlatformColors.systemBackground
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
```

### Actor-Based Concurrency

All intensive operations — text processing, syntax highlighting, range validation — run on dedicated background actors. This Swift 6 architecture ensures:

- **Main Thread Freedom**: The UI always remains responsive, even when processing massive files
- **Thread Safety by Design**: Actor isolation prevents data races at compile time
- **Scalable Performance**: Automatic work distribution across available cores
- **Future-Proof**: Built on Apple's latest concurrency model for long-term stability

## 🔬 Advanced Features & Showcase

CodeEditorPlugin includes sophisticated capabilities that set it apart from basic text editors. Explore these features in the included sample application:

### Performance Monitoring
Real-time insights into rendering performance, memory usage, and processing efficiency. Monitor frame rates, measure syntax highlighting performance, and optimize for your specific use cases.

### Plugin Architecture (Preview)
A glimpse into the future of CodeEditorPlugin — an extensible plugin system that allows you to add custom functionality, language support, and tool integrations without modifying the core codebase.

### Language Server Protocol Integration
Foundational LSP support enables advanced features like intelligent code completion, real-time diagnostics, go-to-definition, and refactoring support. Currently in preview with full support coming soon.

### Advanced Editing Features
- **Smart Indentation**: Context-aware indentation that understands code structure
- **Code Folding**: Collapse and expand code blocks for better navigation
- **Multi-Cursor Support**: Edit in multiple locations simultaneously (coming soon)
- **Incremental Parsing**: Efficient re-parsing of only changed sections

Run the `CodeEditorSample` application to experience these features firsthand and see implementation examples.

## 🎮 Sample Application

The **CodeEditorSample** app serves as both a comprehensive demonstration and a reference implementation. It showcases all features of CodeEditorPlugin in action:

### Live Feature Showcase
- **Interactive Configuration UI**: Real-time manipulation of all 40+ configuration options
- **Multi-Language Support**: Live syntax highlighting for all 17 supported languages
- **Theme System**: Switch between professional themes (Xcode, VS Code Dark, GitHub, Solarized)
- **Performance Monitoring**: Real-time performance metrics and optimization insights
- **Annotation System**: See TODO/FIXME/NOTE comments rendered with interactive badges

### Production Patterns
- **Best Practice Integration**: Copy-paste ready SwiftUI and configuration patterns
- **Cross-Platform Demo**: Experience identical functionality on macOS, iOS, and Mac Catalyst
- **Advanced Architecture**: Explore plugin system, LSP integration, and performance optimization

### Getting Started
```bash
cd CodeEditorSample
swift run CodeEditorSample  # Launch the demo app
swift test               # Run 46 comprehensive tests
```

The sample app maintains the same quality standards as the core plugin with **46 automated tests** (100% passing) and **zero linting violations** across 36 files.

## 🧪 Testing & Quality

CodeEditorPlugin is built to the exacting standards required for production software. Our commitment to quality is demonstrated through:

### Comprehensive Test Coverage
- **322 Total Tests**: 276 core package tests + 46 sample app tests
- **100% Test Pass Rate**: All tests passing with zero failures in final validation
- **Unit & Integration Testing**: From low-level text processing to high-level UI integration
- **Performance Benchmarks**: Automated performance regression detection
- **Memory Leak Detection**: Comprehensive memory management testing with TextKit2 compatibility
- **Platform-Specific Testing**: Ensures consistent behavior across all supported platforms

### Code Quality Standards
- **Zero Linting Violations**: Strict SwiftLint configuration with **0 violations across 204 files**
- **Swift 6 Strict Concurrency**: Complete compliance with Swift's strictest concurrency checking
- **Actor-Based Safety**: All potentially unsafe operations properly isolated to background actors
- **Documentation Coverage**: Comprehensive inline documentation for all public APIs
- **Continuous Quality**: Every commit maintains strict quality standards through automated validation

## 📄 License

CodeEditorPlugin is proprietary software. All rights are reserved. Unauthorized use, copying, distribution, or modification is strictly prohibited without explicit written permission from the owner.

Created by AJ McClary © 2025.

## 🙏 Acknowledgments

- **Apple's TextKit2**: The powerful, modern text engine that enables our advanced editing features
- **SwiftSyntax**: For providing accurate, AST-based Swift syntax highlighting
- **The Swift Community**: For pushing the boundaries of what's possible with Swift