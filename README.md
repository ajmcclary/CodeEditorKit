# CodeEditorPlugin

A powerful, modern code editor component for macOS and iOS applications built with Swift 6 and Actor-Based Concurrency. CodeEditorPlugin provides syntax highlighting, line numbers, themes, scrolling, and extensive customization options for building modern code editing experiences in Swift applications with full concurrency safety.

## ✨ Features

- 🎨 **Advanced Syntax Highlighting** - Support for 15+ programming languages including Swift, Python, JavaScript, TypeScript, Rust, C/C++, and more
- 🎯 **Professional Line Numbers** - Configurable line number display with custom styling and highlighting
- 🌈 **Rich Theme System** - 6+ built-in themes (Xcode, VS Code Dark, GitHub Light, Solarized, etc.) with custom theme support
- 📜 **Smooth Scrolling** - Proper NSScrollView integration with responsive scrolling for large files
- 📐 **TextKit2 Foundation** - Built on modern TextKit2 for reliability, performance, and future compatibility
- ⚡ **Performance Optimized** - Efficient rendering for large files with background processing
- 🔧 **Highly Configurable** - Extensive customization options for appearance and behavior
- ✏️ **Full Editing Support** - Complete text editing capabilities with undo/redo and find/replace
- 🎯 **Line Highlighting** - Highlight current line with customizable colors and styles
- 👻 **Invisible Characters** - Show spaces, tabs, and line breaks with configurable visibility
- 📏 **Smart Indentation** - Configurable tab width, space/tab preferences, and auto-indentation
- 🔌 **Plugin Architecture** - Extensible plugin system for custom functionality
- 📝 **Inline Annotations** - TODO/FIXME/NOTE/WARNING/ERROR detection with hover popups
- 📱 **Cross-Platform** - macOS, iOS, and Mac Catalyst support
- 🎨 **SwiftUI Integration** - Native SwiftUI wrapper with environment theming
- ⚡ **Reactive Bindings** - Real-time text and selection change callbacks

## 📋 Requirements

- **Swift**: 6.0 or later (with experimental concurrency features)
- **macOS**: 12.0+ / **iOS**: 16.0+ / **Mac Catalyst**: 16.0+
- **Xcode**: 16.0 or later
- **Dependencies**: swift-syntax 510.0.0+ (for Swift language support)

## 📦 Installation

### Swift Package Manager

Add CodeEditorPlugin to your project using Swift Package Manager:

1. In Xcode, select "File" → "Add Package Dependencies..."
2. Enter the repository URL: `https://github.com/ajmcclary/CodeEditorPlugin.git`
3. Select the version you want to use

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
]
```

## 🚀 Quick Start

### SwiftUI Integration (Recommended)

CodeEditorPlugin provides native SwiftUI support with cross-platform compatibility:

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = """
        func greetWorld() {
            print("Hello, World!")
            print("Welcome to CodeEditorPlugin!")
        }
        """
    
    var body: some View {
        VStack {
            CodeEditorSwiftUIView(
                text: $code,
                language: .swift,
                theme: .default,
                showLineNumbers: true,
                highlightSelectedLine: true,
                isEditable: true
            )
            .onTextChange { newText in
                print("Text changed: \(newText.count) characters")
            }
            .onSelectionChange { range in
                print("Selection: \(range)")
            }
            .frame(minHeight: 400)
        }
        .padding()
    }
}
```

#### Cross-Platform Support

The same SwiftUI code works across all platforms:

- **macOS 12.0+** - Uses `NSViewRepresentable` with `NSTextView`
- **iOS 16.0+** - Uses `UIViewRepresentable` with `UITextView`  
- **iPadOS 16.0+** - Full tablet support with touch optimizations
- **Mac Catalyst 16.0+** - iPad apps running natively on macOS

#### Environment Theming

```swift
VStack {
    CodeEditorSwiftUIView(text: $code, language: .swift)
    CodeEditorSwiftUIView(text: $pythonCode, language: .python)
}
.codeEditorTheme(.dark)  // Apply theme to entire hierarchy
```

#### Built-in Language Support

```swift
// Static language constants
CodeEditorSwiftUIView(text: $code, language: .swift)
CodeEditorSwiftUIView(text: $code, language: .python)
CodeEditorSwiftUIView(text: $code, language: .javascript)
CodeEditorSwiftUIView(text: $code, language: .json)

// Or use automatic detection
CodeEditorSwiftUIView(text: $code, language: .plainText)
```

### Legacy SwiftUI Usage (Configuration-Based)

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var text = """
        func greetWorld() {
            print("Hello, World!")
            print("Welcome to CodeEditorPlugin!")
        }
        """
    @State private var configuration = EditorConfiguration()
    
    var body: some View {
        VStack {
            CodeEditorView(
                configuration: configuration,
                text: $text,
                language: "swift"
            )
            .frame(minHeight: 400)
        }
        .padding()
    }
}
```

### AppKit Usage

```swift
import CodeEditorPlugin
import AppKit

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create scroll view (required for proper scrolling)
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        
        // Create text view
        let textView = CodeEditorView()
        textView.text = "// Your code here\nprint(\"Hello, World!\")"
        textView.showsLineNumbers = true
        textView.highlightSelectedLine = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        
        // Configure for scrolling
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Enable syntax highlighting
        textView.language = .swift
        textView.isSyntaxHighlightingEnabled = true
        
        // Embed in scroll view
        scrollView.documentView = textView
        view.addSubview(scrollView)
        
        // Setup constraints...
    }
}
```

## ⚙️ Configuration

### Complete Configuration Reference

CodeEditorPlugin provides extensive configuration through two main APIs:

#### 1. CodeEditorView Properties (Direct Configuration)

```swift
let textView = CodeEditorView()

// Core Properties
textView.text = "Your code here"
textView.language = .swift                    // Language for syntax highlighting
textView.isSyntaxHighlightingEnabled = true  // Enable/disable highlighting

// Display Options
textView.showsLineNumbers = true             // Show line numbers in gutter
textView.highlightSelectedLine = true        // Highlight current line
textView.selectedLineHighlightColor = .blue  // Line highlight color
textView.showsInvisibleCharacters = true     // Show whitespace characters

// Text Editing
textView.isEditable = true                   // Enable/disable editing
textView.isSelectable = true                 // Enable/disable selection
textView.allowsUndo = true                   // Enable undo/redo

// Appearance
textView.font = NSFont.monospacedSystemFont(ofSize: 14)
textView.textColor = .labelColor
textView.backgroundColor = .textBackgroundColor
textView.insertionPointColor = .controlAccentColor

// Text Container
textView.textContainerInset = NSSize(width: 5, height: 5)
textView.textContainer?.lineFragmentPadding = 5.0

// Layout
textView.widthTracksTextView = true          // Word wrap
textView.isHorizontallyResizable = false     // Horizontal sizing
textView.isVerticallyResizable = true        // Vertical sizing

// Annotations
textView.annotationsDataSource = myDataSource // Custom annotations
```

#### 2. EditorConfiguration (SwiftUI/High-Level API)

```swift
var config = EditorConfiguration()

// Display Settings
config.showLineNumbers = true
config.showInvisibleCharacters = false
config.highlightSelectedLine = true
config.wrapLines = false                     // Enable word wrap

// Editor Behavior
config.isEditable = true
config.autoIndent = true                     // Auto-indent new lines (Coming Soon)
config.tabWidth = 4                          // Spaces per tab
config.insertSpacesForTabs = true            // Use spaces instead of tabs (Coming Soon)

// Appearance
config.fontSize = 14.0
config.lineSpacing = 1.2                     // Line height multiplier
config.theme = .vsDark                       // Color theme
config.textContainerInset = NSSize(width: 5, height: 5)
config.lineFragmentPadding = 5.0

// Plugins
config.enableAnnotations = true              // Enable TODO/FIXME detection
config.enableCustomPlugin = false            // Custom plugin support

// Performance
config.useHardwareAcceleration = true        // GPU acceleration
config.smoothScrolling = true                // Smooth scroll animations

// Text Processing
config.isContinuousSpellCheckingEnabled = false
config.isGrammarCheckingEnabled = false
config.isAutomaticQuoteSubstitutionEnabled = false
config.isAutomaticDashSubstitutionEnabled = false
config.isAutomaticTextReplacementEnabled = false
config.isAutomaticSpellingCorrectionEnabled = false
config.isAutomaticTextCompletionEnabled = false
config.isIncrementalSearchingEnabled = true

// Advanced Settings
config.allowsDocumentBackgroundColorChange = false
config.allowsImageEditing = false
config.allowsCharacterPickerTouchBarItem = false
config.isRichText = false
config.importsGraphics = false
config.usesInspectorBar = false
config.usesFindBar = true
config.allowsNonContiguousLayout = true
config.displaysLinkToolTips = true

// Selection
config.insertionPointColor = .controlAccentColor
```

### Available Themes

- `.xcode` - Xcode default light theme
- `.vsDark` - VS Code dark theme  
- `.github` - GitHub light theme
- `.solarizedDark` - Solarized dark theme
- `.minimal` - Minimal light theme
- `.presentation` - High contrast presentation theme

### Configuration Presets

The sample app includes several pre-configured presets:

- **Full Featured** - All features enabled for code editing
- **Minimal** - Basic text editing with minimal UI
- **Read Only** - Syntax highlighted code viewer
- **Markdown** - Optimized for Markdown editing with spell check
- **Presentation** - Large font, high contrast for demos

### Custom Themes

```swift
let customTheme = ColorTheme(
    backgroundColor: NSColor.black,
    textColor: NSColor.white,
    selectedLineColor: NSColor.darkGray,
    // ... customize all colors
)
config.theme = customTheme
```

### Implementation Notes

Most configuration options are fully implemented. The following features are marked as "Coming Soon" and require deeper CodeEditorView integration:

- **autoIndent** - Automatic indentation matching (Configuration option available, delegate implementation coming soon)
- **insertSpacesForTabs** - Tab to spaces conversion (Configuration option available, delegate implementation coming soon)

All other configurations including word wrap, horizontal scrolling, hardware acceleration, and text processing options are fully functional.

## 🎨 SwiftUI API Reference

### CodeEditorSwiftUIView

The modern SwiftUI wrapper provides a clean, reactive API:

```swift
CodeEditorSwiftUIView(
    text: Binding<String>,              // Required: Two-way text binding
    language: Language = .plainText,    // Language for syntax highlighting
    theme: CodeEditorSwiftUITheme = .default,  // Visual theme
    showLineNumbers: Bool = true,       // Show line numbers in gutter
    highlightSelectedLine: Bool = true, // Highlight current line
    isEditable: Bool = true            // Enable text editing
)
```

### Theme System

Built-in themes:

```swift
.default    // System default theme
.dark      // Dark theme optimized for low light
```

Custom themes:

```swift
let customTheme = CodeEditorSwiftUITheme(
    name: "custom",
    backgroundColor: .black,
    textColor: .white,
    lineNumberColor: .gray,
    selectedLineColor: .blue.opacity(0.2)
)

CodeEditorSwiftUIView(text: $code, theme: customTheme)
```

### Event Handling

React to text and selection changes:

```swift
CodeEditorSwiftUIView(text: $code, language: .swift)
    .onTextChange { newText in
        // Called when text changes
        validateCode(newText)
    }
    .onSelectionChange { range in
        // Called when selection changes
        updateStatusBar(range)
    }
```

### Modifiers

Chain modifiers for clean configuration:

```swift
CodeEditorSwiftUIView(text: $code, language: .swift)
    .showLineNumbers(true)
    .highlightSelectedLine(true)
    .editable(true)
    .onTextChange { text in print("Changed: \(text)") }
```

### Environment Integration

Use environment values for theme management:

```swift
@Environment(\.codeEditorTheme) var theme

var body: some View {
    VStack {
        CodeEditorSwiftUIView(text: $code)
        Button("Toggle Theme") {
            // Theme changes apply to entire hierarchy
        }
    }
    .codeEditorTheme(isDark ? .dark : .default)
}
```

### Language Detection

Automatic language detection based on content and file extensions:

```swift
// Explicit language setting
CodeEditorSwiftUIView(text: $swiftCode, language: .swift)
CodeEditorSwiftUIView(text: $pythonCode, language: .python)
CodeEditorSwiftUIView(text: $jsCode, language: .javascript)
CodeEditorSwiftUIView(text: $jsonData, language: .json)

// Auto-detection (falls back to .plainText)
CodeEditorSwiftUIView(text: $unknownCode, language: .plainText)
```

### Cross-Platform Considerations

The SwiftUI wrapper automatically adapts to the platform:

**macOS:**
- Uses `NSViewRepresentable`
- Full TextKit 2 integration
- Native scroll view support
- Complete keyboard shortcuts

**iOS/iPadOS:**
- Uses `UIViewRepresentable` with `CodeEditorContainerView`
- Touch-optimized interactions
- Fixed gutter architecture prevents line number clipping
- Adaptive layouts for different screen sizes
- Proper keyboard handling with content insets
- Support for external keyboards

**Mac Catalyst:**
- Hybrid approach optimized for macOS
- Touch and mouse input support
- Native window management

## 🎨 Syntax Highlighting

### Supported Languages

- **Swift** (with SwiftSyntax integration)
- **Python** 
- **JavaScript/TypeScript**
- **Rust**
- **C/C++**
- **HTML/CSS**
- **JSON**
- **Markdown**
- **Ruby**
- **Shell/Bash**
- **Go**
- **Java**
- **PHP**
- **SQL**
- **XML**

### Language Detection

```swift
// Auto-detect from file extension
textView.setLanguage(fileExtension: "swift")
textView.setLanguage(fileExtension: "py")
textView.setLanguage(fileExtension: "js")

// Or set directly
textView.language = .swift
textView.language = .python
textView.language = .javascript
```

## 📱 Example Application

Check out the comprehensive example application in `CodeEditorSample/` that demonstrates:

- ✅ **Full-featured code editor** with syntax highlighting and scrolling
- ✅ **Multiple themes** with real-time theme switching
- ✅ **Configuration management** with import/export
- ✅ **All editor features** (line numbers, invisible characters, line highlighting)
- ✅ **Inline annotations** with hover popups for TODO/FIXME/NOTE/WARNING/ERROR comments
- ✅ **SwiftUI integration demo** with cross-platform examples
- ✅ **Multiple editor instances** and layouts
- ✅ **Preset configurations** (minimal, read-only, markdown, presentation)
- ✅ **Interactive feature tour** and documentation
- ✅ **Performance testing** with large files and annotation systems

### Running the Example

```bash
cd CodeEditorSample
swift run CodeEditorSample
```

## 🏗️ Architecture

CodeEditorPlugin is built with a clean, modular architecture fully optimized for Swift 6 Actor-Based Concurrency:

### Core Components

- **CodeEditorView** - Enhanced NSTextView/UITextView subclass with modern TextKit2 integration
- **CodeEditorContainerView (iOS)** - Container architecture for proper iOS gutter display
- **Syntax Highlighting** - Multi-strategy highlighting system (SwiftSyntax + Regex-based)
- **Theme System** - Comprehensive theming with color management
- **Plugin Architecture** - Extensible system for custom functionality
- **SwiftUI Integration** - Native cross-platform SwiftUI wrappers with environment theming
- **Performance Layer** - Actor-based background processing and viewport optimization

### Simplified Directory Structure

```
Sources/CodeEditorPlugin/
├── Core/                   # Core text editing (CodeEditorView, delegates)
├── SyntaxHighlighting/     # All highlighting logic unified
├── TextProcessing/         # Actor-based text processing & validation
├── RangeProcessing/        # Actor-based range validation
├── Layout/                 # Layout and view components
│   ├── GutterView.swift    # Line numbers (cross-platform)
│   ├── CodeEditorContainerView.swift # iOS container architecture
│   └── Fragments/          # Text layout fragments
├── Models/                 # Data models (including annotations)
├── Extensions/             # All extensions (flattened)
├── SwiftUI/                # SwiftUI integration components
├── Completion/             # Code completion
├── Platform/               # Platform-specific code
└── CodeEditorPlugin.swift  # Main module file
```

### Actor-Based Concurrency Architecture

- **RangeValidator** - Core validation actor for thread-safe text processing
- **SinglePhaseRangeValidator** - Actor for single-phase validation operations
- **ThreePhaseRangeValidator** - Actor for complex three-phase validation workflows
- **BackgroundProcessor** - Actor for async text processing operations
- **HybridSyncAsyncValueProvider** - Thread-safe provider with actor isolation support

### Key Design Patterns

- **Protocol-Oriented Design** - CodeEditorViewProtocol, CodeEditorViewDelegate with Sendable conformance
- **Actor-Based Concurrency** - Full Swift 6 actor architecture for all validation and processing
- **Type Aliases** - Clean public API (CodeEditorTextView → CodeEditorView, CodeEditorDelegate → CodeEditorViewDelegate)
- **Versioned Content System** - Thread-safe change tracking with actor-isolated validation
- **Isolation Parameters** - Advanced actor communication patterns for cross-actor operations
- **@Sendable Closures** - Complete thread-safety in all async operations

### Recent Improvements

- ✅ **Swift 6 Actor-Based Concurrency** - Full migration to actors for thread-safe validation and processing
- ✅ **Simplified Directory Structure** - Reduced from 39 to 10 directories with feature-based organization
- ✅ **Swift 6 Compliance** - Complete concurrency safety with Sendable conformance
- ✅ **Proper Scrolling** - NSScrollView integration for smooth scrolling
- ✅ **iOS Container Architecture** - Fixed line number display issues with proper container view separation
- ✅ **Protocol Conformance** - Complete CodeEditorViewDelegate implementation
- ✅ **Code Quality** - SwiftLint/SwiftFormat integration with 0 violations across 102 files
- ✅ **Test Coverage** - Comprehensive test suite with 172 passing tests
- ✅ **Annotation System** - Complete inline annotations with hover popups for code comments
- ✅ **SwiftUI Integration** - Cross-platform SwiftUI wrapper with environment theming
- ✅ **Performance** - Optimized for large files with actor-based background processing

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Main project tests
swift test

# Example project tests  
cd CodeEditorSample
swift test
```

**Test Results**: 172 tests passing across both projects (106 main + 66 sample) with comprehensive configuration, annotation system testing and performance benchmarks.

## 🔧 Development

### Project Structure Benefits

- **Feature-based organization** - Related code stays together
- **Reduced complexity** - From 39 to 10 directories (74% reduction)
- **Easier navigation** - Less nesting, clearer structure
- **Better maintainability** - Components that work together are in the same directory

### Code Quality

The project maintains high code quality standards:

```bash
# Format code
swiftformat --swiftversion 6.0 .

# Lint code  
swiftlint --fix && swiftlint

# Build and test
swift build && swift test
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Ensure all tests pass and code is properly formatted
4. Submit a pull request

## 📄 License

CodeEditorPlugin is available under the MIT license. See the LICENSE file for more info.

## 🙏 Acknowledgments

- Inspired by STTextView by Marcin Krzyzanowski
- Built on Apple's TextKit2 framework
- Syntax highlighting patterns from various open-source projects
- Swift 6 concurrency patterns from Apple's documentation