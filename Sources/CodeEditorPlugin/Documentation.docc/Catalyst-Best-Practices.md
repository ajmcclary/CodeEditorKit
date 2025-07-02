# Catalyst Best Practices

@Metadata {
    @PageKind(article)
    @PageColor(orange)
}

Build excellent Mac apps with Mac Catalyst using CodeEditorPlugin.

## Overview

CodeEditorPlugin provides full support for Mac Catalyst applications, allowing you to build unified macOS and iOS apps with a shared codebase. The plugin automatically adapts to the Catalyst environment while maintaining native-like behavior on both platforms.

## Platform Requirements

- **Mac Catalyst**: 16.0+
- **Xcode**: 15.0+  
- **Swift**: 6.0+

## Platform Detection

### Runtime Checks

```swift
extension CodeEditorView {
    var isCatalyst: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }
    
    func configurePlatformSpecifics() {
        if isCatalyst {
            // Catalyst-specific configuration
            configureCatalystBehavior()
        } else {
            // Regular iOS behavior
            configureIOSBehavior()
        }
    }
}
```

## Window Management

### Scene Configuration

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        #if targetEnvironment(macCatalyst)
        if let windowScene = scene as? UIWindowScene {
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 800, height: 600)
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1920, height: 1080)
            
            // Set window title
            windowScene.title = "Code Editor"
            
            // Configure toolbar
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .visible
                titlebar.toolbar = makeToolbar()
            }
        }
        #endif
    }
}
```

### Multiple Windows

```swift
func openNewWindow() {
    #if targetEnvironment(macCatalyst)
    let activity = NSUserActivity(activityType: "com.example.editor.new")
    
    UIApplication.shared.requestSceneSessionActivation(
        nil,
        userActivity: activity,
        options: nil
    ) { error in
        if let error = error {
            print("Failed to open new window: \(error)")
        }
    }
    #endif
}
```

## Menu Bar Integration

### Custom Menus

```swift
override func buildMenu(with builder: UIMenuBuilder) {
    super.buildMenu(with: builder)
    
    #if targetEnvironment(macCatalyst)
    // Editor menu
    let editorMenu = UIMenu(
        title: "Editor",
        children: [
            UICommand(
                title: "Toggle Line Numbers",
                action: #selector(toggleLineNumbers),
                input: "L",
                modifierFlags: [.command, .shift]
            ),
            UICommand(
                title: "Jump to Line...",
                action: #selector(jumpToLine),
                input: "L",
                modifierFlags: .command
            )
        ]
    )
    
    builder.insertSibling(editorMenu, afterMenu: .edit)
    #endif
}
```

## Toolbar Support

### NSToolbar Integration

```swift
#if targetEnvironment(macCatalyst)
extension EditorViewController: NSToolbarDelegate {
    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "EditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = true
        
        return toolbar
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .toggleSidebar,
            .flexibleSpace,
            .searchField,
            .editorSettings
        ]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        if itemIdentifier == .editorSettings {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Settings"
            item.image = UIImage(systemName: "gear")
            item.action = #selector(showSettings)
            item.target = self
            return item
        }
        
        return nil
    }
}
#endif
```

## Keyboard and Mouse

### Enhanced Keyboard Support

```swift
override var keyCommands: [UIKeyCommand]? {
    var commands = super.keyCommands ?? []
    
    #if targetEnvironment(macCatalyst)
    // Add Mac-specific shortcuts
    commands.append(contentsOf: [
        UIKeyCommand(
            title: "Close Window",
            action: #selector(closeWindow),
            input: "w",
            modifierFlags: .command
        ),
        UIKeyCommand(
            title: "New Tab",
            action: #selector(newTab),
            input: "t",
            modifierFlags: .command
        )
    ])
    #endif
    
    return commands
}
```

### Mouse Support

```swift
#if targetEnvironment(macCatalyst)
override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    for press in presses {
        if press.type == .select && press.clickCount == 2 {
            // Handle double-click
            handleDoubleClick(at: press.location)
            return
        }
    }
    
    super.pressesBegan(presses, with: event)
}
#endif
```

## UI Adaptations

### Platform-Specific UI

```swift
func configureUI() {
    #if targetEnvironment(macCatalyst)
    // Mac-style UI
    navigationController?.setNavigationBarHidden(true, animated: false)
    
    // Use sidebar
    splitViewController?.preferredDisplayMode = .oneBesideSecondary
    splitViewController?.preferredSplitBehavior = .tile
    #else
    // iOS UI
    navigationController?.setNavigationBarHidden(false, animated: false)
    #endif
}
```

### Context Menus

```swift
override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
        var children: [UIMenuElement] = []
        
        #if targetEnvironment(macCatalyst)
        // Mac-style context menu
        children.append(UICommand(title: "Show in Finder", action: #selector(showInFinder)))
        #endif
        
        // Common items
        children.append(contentsOf: [
            UICommand(title: "Copy", action: #selector(copy(_:))),
            UICommand(title: "Paste", action: #selector(paste(_:)))
        ])
        
        return UIMenu(children: children)
    }
}
```

## File Management

### Open/Save Dialogs

```swift
#if targetEnvironment(macCatalyst)
func openDocument() {
    let documentPicker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.text, .sourceCode]
    )
    documentPicker.delegate = self
    documentPicker.allowsMultipleSelection = true
    
    present(documentPicker, animated: true)
}

func saveDocument() {
    let documentPicker = UIDocumentPickerViewController(
        forExporting: [documentURL],
        asCopy: false
    )
    documentPicker.delegate = self
    
    present(documentPicker, animated: true)
}
#endif
```

## Best Practices

1. **Respect Mac Conventions**: Follow Mac UI guidelines
2. **Keyboard First**: Ensure all features are keyboard accessible
3. **Window Management**: Support multiple windows and tabs
4. **Menu Bar**: Provide comprehensive menu bar commands
5. **Performance**: Optimize for Mac hardware capabilities

## Architecture Overview

### Cross-Platform Abstraction Layer

The CodeEditorPlugin uses a sophisticated platform abstraction system:

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

For iOS-style layout with gutter separation:

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

## Feature Matrix

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

### Xcode Beta Warnings

When building with Xcode beta, you may see:
- **Directory not found for Metal toolchain** - Known beta issue, safely ignored
- **Missing SubFrameworks path** - Doesn't affect functionality

**Workarounds:**
```bash
# Build from command line
xcodebuild -workspace CodeEditorSample.xcworkspace \
           -scheme CodeEditorSample \
           -destination 'platform=macOS,variant=Mac Catalyst' \
           build

# Or suppress warnings in scheme
# Other Linker Flags: -Xlinker -w
# Other Swift Flags: -suppress-warnings
```

### Blurry Text on External Displays

```swift
if let window = view.window {
    window.contentScaleFactor = UIScreen.main.scale
}
```

### Context Menu Not Appearing

```swift
// Ensure proper gesture recognizer setup
CrossPlatformCoordinator.shared.configureInputHandling(for: editorView)
```

### Performance with Large Files

```swift
config.performance.useViewportRendering = true
config.performance.viewportExpansion = 100 // Lines above/below viewport
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
8. **Respect Mac Conventions**: Follow Mac UI guidelines
9. **Handle Module Imports**: Ensure workspace file is opened for proper module resolution

## Migration Guide

### From iOS to Catalyst

```swift
// Before (iOS only)
let textView = CodeEditorView()
textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

// After (Catalyst-aware)
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

## Common Pitfalls

1. **Touch Gestures**: Not all iOS gestures make sense on Mac
2. **Navigation**: Consider removing iOS navigation patterns
3. **Tooltips**: Add tooltips for better discoverability
4. **Preferences**: Use Mac-style preferences window
5. **File Access**: Handle sandboxing appropriately
6. **Module Import Issues**: Open workspace file, not project file directly
7. **Build Warnings**: Beta Xcode may show cosmetic warnings

## See Also

- <doc:macOS-Integration>
- <doc:iOS-Integration>
- <doc:Platform-Abstraction>
- <doc:Troubleshooting>