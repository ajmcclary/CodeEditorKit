# CodeEditorPlugin

[![Tests](https://img.shields.io/badge/tests-172%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#code-quality-standards)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Mac%20Catalyst-lightgrey)](#requirements)

A powerful, production-ready code editor component for macOS and iOS, built with a modern Swift 6 architecture. CodeEditorPlugin provides world-class performance, extensive customization, and a feature set designed for professional development tools.

Built from the ground up with true cross-platform support in mind, it delivers advanced syntax highlighting, a robust theme system, and seamless native performance on **macOS, iOS, and Mac Catalyst** — not through simple ports, but through a sophisticated platform abstraction layer that respects each platform's unique characteristics.

## ✨ Core Features

- 🚀 **Modern Swift 6 Concurrency:** Built from the ground up with actors for rock-solid thread safety, exceptional performance, and guaranteed responsiveness. This isn't just an update — it's a complete architectural advantage that ensures your editor remains smooth even under heavy load.

- 💻 **True Cross-Platform Architecture:** A sophisticated abstraction layer ensures seamless, native performance on macOS, iOS, and Mac Catalyst. Write your UI code once; our intelligent platform layer handles all the platform-specific details, from touch handling to keyboard shortcuts.

- 🎨 **Advanced Syntax Highlighting:** Best-in-class support for **17 programming languages**, using SwiftSyntax for native Swift AST analysis and high-performance regex engines for other languages. Experience accurate, real-time highlighting that keeps pace with your typing.

- 🔧 **Extensible & Future-Proof:** Features a forward-thinking plugin architecture and Language Server Protocol (LSP) integration for advanced language intelligence. Build on a foundation designed to grow with your needs, supporting custom language extensions, tool integrations, and advanced IDE features.

- ✅ **Production-Grade Quality:** Verified with **172 automated tests** (106 core + 66 sample app, 100% passing), ensuring reliability for professional applications. Every commit maintains strict quality standards with **zero linting violations** across 37 files and comprehensive test coverage.

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

### Simplified Feature-Based Architecture

The codebase is organized by feature rather than by type, making it intuitive to understand, maintain, and extend. This clean, modular design reduces cognitive load by 74% (from 39 to 10 directories), isolates functionality, and makes the codebase more approachable for new contributors. Each feature is self-contained with its own models, views, and logic, eliminating the need to jump between multiple directories to understand a single feature.

#### Key Components

- **`Core/`** - **The Text Editing Engine**
  - `CodeEditorView`: The main TextKit2-based text view providing core editing functionality with modern text handling
  - `AnnotationsDataSource`: Intelligent inline code annotation system for TODO/FIXME/NOTE detection
  - `CodeEditorViewDelegate`: Comprehensive delegate system for event handling and customization

- **`Configuration/`** - **Unified Configuration System**
  - `EditorConfiguration`: Nested configuration structure with display, layout, behavior, and performance settings
  - Builder pattern with `.with()` methods for immutable updates
  - Five built-in presets: default, minimal, readOnly, markdown, and presentation

- **`SyntaxHighlighting/`** - **Multi-Language Support**
  - `SyntaxHighlightingCoordinator`: Manages language detection and highlighting orchestration
  - `SwiftSyntaxHighlighter`: Native Swift AST analysis using SwiftSyntax for accurate highlighting
  - `RegexSyntaxHighlighter`: High-performance regex engine for 16+ programming languages
  - Viewport-based rendering for optimal performance with large files

- **`Layout/`** - **Cross-Platform UI Components**
  - `GutterView`: Platform-aware line number display with proper scrolling synchronization
  - `CodeEditorContainerView`: iOS-specific container architecture for proper text view containment

- **`Platform/`** - **Sophisticated Abstraction Layer**
  - The foundation that enables true cross-platform support without compromises
  - See dedicated Platform Abstraction System section below

- **`SwiftUI/`** - **Native SwiftUI Integration**
  - `CodeEditor`: Modern SwiftUI view with environment-based configuration
  - Full support for SwiftUI modifiers and data flow patterns

### Platform Abstraction System

At the heart of CodeEditorPlugin's cross-platform capabilities is a sophisticated abstraction layer that goes beyond simple conditional compilation. This system provides true write-once, run-anywhere capability while maintaining platform-specific optimizations and native feel.

#### Unified Type System
Write your UI code once. Our abstraction layer handles the platform-specific details, providing unified types that automatically map to the correct platform implementations:

```swift
// This code works identically on macOS, iOS, and Mac Catalyst
let backgroundColor = PlatformColors.systemBackground  // Adapts to light/dark mode
let textColor = PlatformColors.label                  // Platform-appropriate text color
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
```

#### Runtime Capability Detection
The platform capabilities system ensures your code gracefully adapts to each platform's unique features:

```swift
let capabilities = PlatformCapabilities.shared

// Intelligently enable features based on platform support
if capabilities.supportsTextKit2 {
    // Use advanced TextKit2 features
}

if capabilities.supportsHardwareAcceleration {
    config.performance.useHardwareAcceleration = true
}

// Get platform-optimized configuration
let recommendedConfig = capabilities.recommendedPerformanceConfiguration
```

#### Cross-Platform Input Handling
The `CrossPlatformCoordinator` abstracts away input differences between platforms:

```swift
let coordinator = CrossPlatformCoordinator()

// Unified input handling that works everywhere
coordinator.configureInputHandling(for: textView)
coordinator.handleTouchInput(event: touchEvent)    // iOS
coordinator.handleMouseInput(event: mouseEvent)    // macOS
coordinator.handleKeyboardShortcut(event: keyEvent) // Both
```

#### Zero-Compromise Native Experience
- **macOS**: Full keyboard shortcut support, native menus, hover effects
- **iOS**: Touch-optimized selection, proper keyboard handling, gesture support
- **Mac Catalyst**: Best of both worlds with adaptive UI elements

### Actor-Based Concurrency

All intensive operations leverage Swift 6's actor system for guaranteed thread safety and optimal performance. This modern architecture ensures:

- **Main Thread Freedom**: The UI always remains responsive, even when processing massive files. Background actors handle all heavy lifting.
- **Thread Safety by Design**: Actor isolation prevents data races at compile time, not runtime. Swift 6's strict concurrency checking guarantees correctness.
- **Scalable Performance**: Automatic work distribution across available cores with intelligent task prioritization.
- **Future-Proof Architecture**: Built on Apple's latest concurrency model, ready for Swift's async/await evolution.

## 🔬 Advanced Features

CodeEditorPlugin includes sophisticated capabilities that set it apart from basic text editors. These advanced features are demonstrated in the included sample application's Interactive Showcase.

### Performance Monitoring
Real-time insights into your editor's performance with built-in monitoring tools:
- **Frame Rate Analysis**: Monitor rendering performance to ensure smooth 60fps scrolling
- **Memory Profiling**: Track memory usage and detect potential leaks
- **Syntax Highlighting Metrics**: Measure highlighting performance for optimization
- **Large File Handling**: Optimized for files exceeding 500KB with viewport-based rendering

### Plugin Architecture (Preview)
Experience the future of extensibility with our forward-thinking plugin system:
- **Language Plugins**: Add support for new languages without modifying core code
- **Tool Integration**: Connect external tools and services seamlessly
- **Custom Commands**: Define domain-specific editing commands
- **Theme Extensions**: Create and share custom color schemes and styles

*See the plugin architecture in action in the CodeEditorSample app's Advanced Features section.*

### Language Server Protocol Integration
Foundational LSP support brings IDE-level intelligence to your editor:
- **Intelligent Code Completion**: Context-aware suggestions powered by language servers
- **Real-time Diagnostics**: Instant error and warning detection as you type
- **Go-to-Definition**: Navigate to symbol definitions across your codebase
- **Hover Information**: Rich documentation and type information on hover
- **Refactoring Support**: Safe, automated code transformations

*Currently in preview with expanding language support. Full implementation coming in v2.0.*

### Advanced Editing Capabilities
Professional-grade features that developers expect:
- **Smart Indentation**: Context-aware indentation that understands code structure and syntax
- **Code Folding**: Collapse and expand code blocks for improved navigation in large files
- **Symbol Navigation**: Jump to functions, classes, and other symbols with ease
- **Incremental Parsing**: Efficient re-parsing of only changed sections for optimal performance
- **Multiple Cursors**: Edit in multiple locations simultaneously (coming soon)
- **Search & Replace**: Powerful find and replace with regex support
- **Bracket Matching**: Intelligent matching and navigation for brackets, parentheses, and quotes

### Interactive Showcase
The `CodeEditorSample` application includes an Interactive Showcase where you can:
- Toggle features in real-time to see their impact
- Monitor performance metrics as you edit
- Experiment with different configurations
- Preview upcoming features like the plugin system and LSP integration

```bash
# Launch the Interactive Showcase
cd CodeEditorSample
swift run CodeEditorSample
# Navigate to View → Show Advanced Features
```

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
swift test               # Run 66 comprehensive tests
```

The sample app maintains the same quality standards as the core plugin with **66 automated tests** (100% passing) and **zero linting violations** across 36 files.

## 🧪 Testing & Quality

CodeEditorPlugin is built to the exacting standards required for production software. Our commitment to quality is demonstrated through comprehensive testing and strict code standards.

### Comprehensive Test Coverage
- **172 Total Tests**: 106 tests for the core plugin + 66 tests for the sample app
- **100% Test Pass Rate**: All tests passing with zero failures in final validation
- **Test Categories**:
  - **Core Plugin Tests** (106 tests):
    - `CodeEditorViewTests`: Core text view functionality (33 tests)
    - `SyntaxHighlightingTests`: Language highlighting system (13 tests)
    - `AnnotationTests`: Annotation system functionality (19 tests)
    - `ConfigurationIntegrationTests`: Configuration system (24 tests)
    - `PerformanceConfigurationTests`: Performance benchmarks (11 tests)
    - `ConfigurationTests`: Basic configuration (6 tests)
  - **Sample App Tests** (66 tests):
    - `AnnotationSystemTests`: Comprehensive annotation testing (20 tests)
    - `ConfigurationUITests`: UI-level configuration tests (12 tests)
    - `SampleCodeTests`: Language sample validation (12 tests)
    - `PluginConfigurationTests`: Plugin system tests (11 tests)
    - `SimplifiedIntegrationTests`: End-to-end testing (6 tests)
    - `BasicFunctionalityTests`: Core functionality (4 tests)
    - `QuickIsFlippedTest`: View hierarchy tests (1 test)
- **Platform Coverage**: Tests run on macOS, iOS, and Mac Catalyst
- **Performance Benchmarks**: Automated regression detection for critical paths
- **Memory Safety**: Comprehensive leak detection with TextKit2 validation

### Code Quality Standards
- **Zero Linting Violations**: Strict SwiftLint configuration with **0 violations across 37 files**
- **Swift 6 Strict Concurrency**: Complete compliance with Swift's strictest concurrency checking
- **Actor-Based Safety**: All potentially unsafe operations properly isolated to background actors
- **Documentation Coverage**: Comprehensive inline documentation for all public APIs
- **Continuous Quality**: Every commit maintains these strict standards through automated validation
- **Clean Architecture**: Feature-based organization with clear separation of concerns

## 📄 License

CodeEditorPlugin is proprietary software. All rights are reserved. Unauthorized use, copying, distribution, or modification is strictly prohibited without explicit written permission from the owner.

Created by AJ McClary © 2025.

## 🙏 Acknowledgments

- **Apple's TextKit2**: The powerful, modern text engine that enables our advanced editing features
- **SwiftSyntax**: For providing accurate, AST-based Swift syntax highlighting
- **The Swift Community**: For pushing the boundaries of what's possible with Swift