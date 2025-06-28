# Mac Catalyst Support Guide

This guide provides comprehensive documentation for using CodeEditorPlugin with Mac Catalyst, including platform-specific considerations, implementation details, and best practices.

## Overview

CodeEditorPlugin provides full support for Mac Catalyst applications, allowing you to build unified macOS and iOS apps with a shared codebase. The plugin automatically adapts to the Catalyst environment while maintaining native-like behavior on both platforms.

## Platform Requirements

- **Mac Catalyst**: 16.0+
- **Xcode**: 15.0+
- **Swift**: 6.0+

## Architecture Overview

### Cross-Platform Abstraction Layer

The CodeEditorPlugin uses a sophisticated platform abstraction system that ensures seamless operation across iOS, macOS, and Mac Catalyst:

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// macOS-specific code
#elseif canImport(UIKit)
// iOS and Catalyst code
#endif
```

### Key Components

1. **Platform Type Aliases** (`PlatformImports.swift`)
   - `PlatformView` → `UIView` on Catalyst
   - `PlatformColor` → `UIColor` on Catalyst
   - `PlatformFont` → `UIFont` on Catalyst

2. **Platform Capabilities** (`PlatformCapabilities.swift`)
   - Runtime detection of available features
   - Catalyst-specific optimizations
   - Memory and performance recommendations

3. **Cross-Platform Coordinator** (`CrossPlatformCoordinator.swift`)
   - Unified input handling
   - Context menu abstraction
   - Feature availability matrix

## Implementation Guide

### Basic Setup

```swift
import CodeEditorPlugin
#if canImport(UIKit)
import UIKit
#endif

class CatalystViewController: PlatformViewController {
    private var editorView: CodeEditorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create editor view
        editorView = CodeEditorView()
        
        // Configure for Catalyst
        configureCatalystEditor()
        
        // Add to view hierarchy
        view.addSubview(editorView)
        setupConstraints()
    }
    
    private func configureCatalystEditor() {
        // Apply Catalyst-optimized configuration
        var config = PlatformCapabilities.shared.recommendedConfiguration()
        
        // Catalyst-specific adjustments
        config.display.fontSize = 14.0 // Slightly larger for desktop
        config.layout.gutterWidth = 50.0 // Wider gutter for mouse targets
        config.behavior.enableCodeCompletion = true
        
        // Apply configuration
        config.apply(to: editorView)
    }
}
```

### Container View Usage

For iOS-style layout with gutter separation, use `CodeEditorContainerView`:

```swift
class CatalystEditorViewController: PlatformViewController {
    private var containerView: CodeEditorContainerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create container view (includes gutter and minimap)
        containerView = CodeEditorContainerView()
        
        // Access the text view
        let textView = containerView.textView
        textView.language = .swift
        
        // Configure
        containerView.configuration = {
            var config = EditorConfiguration.default
            config.display.showLineNumbers = true
            config.display.showMinimap = false // Minimap not recommended on Catalyst
            return config
        }()
        
        view.addSubview(containerView)
        setupConstraints()
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import CodeEditorPlugin

struct CatalystContentView: View {
    @State private var code = "// Your Swift code here"
    @State private var configuration = EditorConfiguration.default
    
    var body: some View {
        CodeEditorSwiftUIView(
            text: $code,
            language: .swift,
            configuration: catalystOptimizedConfig()
        )
        .frame(minHeight: 400)
    }
    
    private func catalystOptimizedConfig() -> EditorConfiguration {
        var config = configuration
        
        // Catalyst optimizations
        config.display.fontSize = 14.0
        config.layout.lineSpacing = 1.3
        config.performance.useHardwareAcceleration = true
        
        return config
    }
}
```

## Platform-Specific Features

### Context Menus

The new action-based context menu system provides native menus on Catalyst:

```swift
// Context menus work seamlessly on Catalyst
let menu = CrossPlatformCoordinator.shared.createContextMenu(
    for: selectedRange,
    in: editorView
)

// The menu is automatically a UIMenu on Catalyst
// with native macOS-style presentation
```

### Input Handling

Catalyst supports both touch and mouse input. The plugin automatically adapts:

```swift
// The CrossPlatformCoordinator handles input differences
coordinator.configureInputHandling(for: editorView)

// Mouse events are supported on Catalyst
if PlatformCapabilities.shared.supportsMouseInput {
    // Enable hover effects, right-click menus, etc.
}
```

### Keyboard Shortcuts

Enhanced keyboard support on Catalyst:

```swift
// Standard keyboard shortcuts work automatically
// Cmd+C, Cmd+V, Cmd+X, etc.

// Add custom shortcuts
override var keyCommands: [UIKeyCommand]? {
    return [
        UIKeyCommand(
            title: "Toggle Line Numbers",
            action: #selector(toggleLineNumbers),
            input: "L",
            modifierFlags: .command
        )
    ]
}
```

## Feature Matrix for Catalyst

| Feature | iOS | macOS | Catalyst | Notes |
|---------|-----|-------|----------|-------|
| Syntax Highlighting | ✅ | ✅ | ✅ | Full support with SwiftSyntax |
| Line Numbers | ✅ | ✅ | ✅ | Via CodeEditorContainerView |
| Code Completion | ✅ | ✅ | ✅ | Full support |
| Minimap | ❌ | ✅ | ⚠️ | Available but not recommended |
| Context Menus | ✅ | ✅ | ✅ | Native UIMenu presentation |
| Multi-cursor | ⚠️ | ✅ | ⚠️ | Limited support |
| Hardware Acceleration | ✅ | ✅ | ✅ | Automatically enabled |
| Touch Input | ✅ | ⚠️ | ✅ | Full support |
| Mouse Input | ⚠️ | ✅ | ✅ | Full support |
| Keyboard Shortcuts | ⚠️ | ✅ | ✅ | Enhanced on Catalyst |
| Annotations | ✅ | ✅ | ✅ | Hover popups work with mouse |

## Performance Optimization

### Recommended Configuration

```swift
func catalystOptimizedConfiguration() -> EditorConfiguration {
    var config = EditorConfiguration.default
    
    // Display optimizations
    config.display.fontSize = 14.0 // Desktop-appropriate size
    config.display.showLineNumbers = true
    config.display.showMinimap = false // Save screen space
    config.display.highlightSelectedLine = true
    
    // Layout optimizations
    config.layout.lineSpacing = 1.3 // Better readability
    config.layout.gutterWidth = 50.0 // Wider for mouse targets
    config.layout.tabWidth = 4
    
    // Behavior optimizations
    config.behavior.autoIndent = true
    config.behavior.enableCodeCompletion = true
    config.behavior.continuousSpellCheckingEnabled = false
    
    // Performance optimizations
    config.performance.useHardwareAcceleration = true
    config.performance.maxSyntaxHighlightingLength = 2_000_000 // 2MB
    config.performance.smoothScrolling = true
    
    return config
}
```

### Memory Considerations

```swift
// Check available memory
let memoryConfig = PlatformCapabilities.shared.recommendedMemoryConfiguration

// Apply memory-aware settings
if memoryConfig.availableMemory < 4_000_000_000 { // 4GB
    config.performance.maxFileSize = 5_000_000 // 5MB limit
    config.performance.maxSyntaxHighlightingLength = 1_000_000 // 1MB
}
```

## Common Issues and Solutions

### Issue: Blurry Text on External Displays

**Solution**: Enable high-resolution rendering:

```swift
if let window = view.window {
    window.contentScaleFactor = UIScreen.main.scale
}
```

### Issue: Context Menu Not Appearing

**Solution**: Ensure proper gesture recognizer setup:

```swift
// The CrossPlatformCoordinator handles this automatically
CrossPlatformCoordinator.shared.configureInputHandling(for: editorView)
```

### Issue: Performance with Large Files

**Solution**: Use viewport-based rendering:

```swift
config.performance.useViewportRendering = true
config.performance.viewportExpansion = 100 // Lines above/below viewport
```

### Issue: Keyboard Shortcuts Conflict

**Solution**: Check for system conflicts:

```swift
override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    // Filter out conflicting actions
    if action == #selector(paste(_:)) {
        return editorView.isEditable
    }
    return super.canPerformAction(action, withSender: sender)
}
```

## Testing Catalyst Apps

### Unit Testing

```swift
import XCTest
@testable import YourCatalystApp

class CatalystEditorTests: XCTestCase {
    func testCatalystConfiguration() {
        let config = catalystOptimizedConfiguration()
        
        // Verify Catalyst-specific settings
        XCTAssertEqual(config.display.fontSize, 14.0)
        XCTAssertEqual(config.layout.gutterWidth, 50.0)
        XCTAssertFalse(config.display.showMinimap)
    }
    
    func testContextMenuOnCatalyst() {
        #if targetEnvironment(macCatalyst)
        let menu = createTestContextMenu()
        XCTAssertTrue(menu is UIMenu)
        #endif
    }
}
```

### UI Testing

```swift
import XCTest

class CatalystUITests: XCTestCase {
    func testRightClickContextMenu() throws {
        #if targetEnvironment(macCatalyst)
        let app = XCUIApplication()
        app.launch()
        
        let editor = app.textViews["codeEditor"]
        editor.rightClick()
        
        // Verify context menu appears
        XCTAssertTrue(app.menus["Edit"].exists)
        #endif
    }
}
```

## Best Practices

1. **Use Container View**: Always use `CodeEditorContainerView` for proper gutter separation
2. **Optimize for Desktop**: Adjust font sizes and spacing for desktop viewing distances
3. **Enable Mouse Features**: Take advantage of hover states and right-click menus
4. **Keyboard First**: Implement comprehensive keyboard shortcuts
5. **Test on Device**: Always test on actual Mac hardware, not just simulator
6. **Memory Awareness**: Catalyst apps share memory with other Mac apps
7. **Window Management**: Support multiple windows and proper state restoration

## Migration Guide

### From iOS to Catalyst

```swift
// Before (iOS only)
let textView = CodeEditorView()
textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

// After (Catalyst-aware with platform abstractions)
let textView = CodeEditorView()
let fontSize: CGFloat = {
    #if targetEnvironment(macCatalyst)
    return 14.0 // Larger for desktop
    #else
    return 12.0 // Original iOS size
    #endif
}()
textView.font = PlatformFonts.monospacedSystemFont(ofSize: fontSize, weight: .regular)
```

### From macOS to Catalyst

```swift
// Before (macOS only)
let textView = CodeEditorView()
textView.isAutomaticQuoteSubstitutionEnabled = false

// After (Catalyst-aware)
let textView = CodeEditorView()
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
textView.isAutomaticQuoteSubstitutionEnabled = false
#else
// UITextView properties
textView.smartQuotesType = .no
#endif
```

## Advanced Topics

### Custom Tool Palette

```swift
class CatalystToolPaletteViewController: PlatformViewController {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        // Add custom menu items
        let editorMenu = UIMenu(
            title: "Editor",
            children: [
                UICommand(
                    title: "Toggle Line Numbers",
                    action: #selector(toggleLineNumbers)
                ),
                UICommand(
                    title: "Change Theme",
                    action: #selector(changeTheme)
                )
            ]
        )
        
        builder.insertSibling(editorMenu, afterMenu: .view)
    }
}
```

### Window Scene Support

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // Configure for Catalyst
        #if targetEnvironment(macCatalyst)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .visible
            titlebar.toolbar = createEditorToolbar()
        }
        
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 800, height: 600)
        #endif
    }
}
```

## Conclusion

CodeEditorPlugin provides comprehensive Mac Catalyst support with automatic platform adaptation. By following this guide and using the provided configurations, you can create a native-feeling code editor that works seamlessly across iOS, iPadOS, and macOS through Catalyst.

For additional support or to report Catalyst-specific issues, please visit the [GitHub repository](https://github.com/CodeEditorPlugin/CodeEditorPlugin).