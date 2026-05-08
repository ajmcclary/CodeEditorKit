# macOS Integration

Leverage macOS-specific features to create a native editing experience.

## Overview

CodeEditorPlugin provides deep integration with macOS, supporting native features like menus, keyboard shortcuts, Touch Bar, and more. The platform abstraction layer ensures you can write cross-platform code while still accessing macOS-specific features when needed.

## Platform Setup

### Using Platform Types

Always use the platform abstraction types for consistency. As of the 2025 refactoring, all platform detection uses `#if canImport()` patterns for better Catalyst compatibility:

```swift
import CodeEditorPlugin

// Use platform-agnostic types
let backgroundColor = PlatformColors.systemBackground
let textColor = PlatformColors.label
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14)

// Platform capabilities
let capabilities = PlatformCapabilities.shared
if capabilities.supportsHardwareAcceleration {
    // Enable GPU acceleration
}
```

## Menu Bar Integration

### Custom Menus

```swift
extension NSApplication {
    func setupCodeEditorMenus() {
        // Editor menu
        let editorMenu = NSMenu(title: "Editor")
        
        editorMenu.addItem(NSMenuItem(
            title: "Toggle Line Numbers",
            action: #selector(EditorCommands.toggleLineNumbers),
            keyEquivalent: "l"
        ).modifierMask(.command, .option))
        
        editorMenu.addItem(NSMenuItem(
            title: "Jump to Line...",
            action: #selector(EditorCommands.jumpToLine),
            keyEquivalent: "l"
        ).modifierMask(.command))
        
        mainMenu?.addItem(NSMenuItem(title: "Editor", submenu: editorMenu))
    }
}
```

## Keyboard Shortcuts

### System-Wide Shortcuts

```swift
extension CodeEditorView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "d":
                duplicateSelection()
                return true
            case "/":
                toggleComment()
                return true
            case "[":
                if event.modifierFlags.contains(.option) {
                    foldCode()
                    return true
                }
            default:
                break
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
}
```

## Touch Bar Support

```swift
@available(macOS 10.12.2, *)
extension CodeEditorView: NSTouchBarDelegate {
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        
        touchBar.defaultItemIdentifiers = [
            .characterPicker,
            .candidateList,
            .flexibleSpace,
            .otherItemsProxy
        ]
        
        return touchBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .characterPicker:
            return NSCharacterPickerTouchBarItem(identifier: identifier)
        default:
            return nil
        }
    }
}
```

## Window Management

### Multiple Windows

```swift
class EditorWindowManager {
    private var windows: Set<NSWindow> = []
    
    func openNewWindow(with content: String? = nil) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        let editor = CodeEditorView()
        editor.text = content ?? ""
        
        window.contentView = editor
        window.makeKeyAndOrderFront(nil)
        
        windows.insert(window)
    }
}
```

## Services Integration

```swift
extension CodeEditorView {
    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        if sendType == .string && hasSelection {
            return self
        }
        
        if returnType == .string && isEditable {
            return self
        }
        
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }
    
    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        if let selectedText = selectedText {
            pboard.setString(selectedText, forType: .string)
            return true
        }
        return false
    }
}
```

## Toolbar Customization

```swift
extension EditorViewController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        switch itemIdentifier {
        case .editorTheme:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Theme"
            item.toolTip = "Change editor theme"
            
            let menu = NSMenu()
            for theme in ThemeFamily.bundled("zed-trek")?.themes ?? [.lcarsDark] {
                menu.addItem(NSMenuItem(title: theme.name, representedObject: theme))
            }
            
            let popup = NSPopUpButton()
            popup.menu = menu
            popup.target = self
            popup.action = #selector(changeTheme(_:))
            
            item.view = popup
            return item
            
        default:
            return nil
        }
    }
}
```

## Best Practices

1. **Respect System Preferences**: Honor system-wide keyboard shortcuts
2. **Support Dark Mode**: Use semantic colors that adapt
3. **Enable Full Keyboard Access**: Ensure all features are keyboard accessible
4. **Integrate with Services**: Support system services for text manipulation
5. **Window Restoration**: Save and restore window state

## See Also

- [Platform-Abstraction](platform-abstraction.md)
- [UIKit-AppKit-Integration](uikit-appkit.md)
- [Advanced-Patterns](../Internals/advanced-patterns.md)
- [iOS-Integration](ios.md)
- [Catalyst-Best-Practices](catalyst.md)
