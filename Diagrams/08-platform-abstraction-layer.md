# Platform Abstraction Layer

This diagram shows how the CodeEditorPlugin achieves cross-platform compatibility across macOS, iOS, and Mac Catalyst.

```mermaid
classDiagram
    %% Platform Detection
    class PlatformCapabilities {
        +isMacOS: Bool
        +isiOS: Bool
        +isMacCatalyst: Bool
        +hasHoverSupport: Bool
        +hasPreciseScrolling: Bool
        +hasKeyboardShortcuts: Bool
        +hasContextMenus: Bool
        +screenScale: CGFloat
        +detect()
        +supportsFeature(PlatformFeature) Bool
    }

    class PlatformFeature {
        &lt;&lt;enumeration&gt;&gt;
        hover
        rightClick
        keyboardShortcuts
        multipleWindows
        dragAndDrop
        touchBar
        forceTouch
    }

    %% Type Aliases
    class PlatformTypeAliases {
        &lt;&lt;module&gt;&gt;
        PlatformView = NSView or UIView
        PlatformViewController = NSViewController or UIViewController
        PlatformColor = NSColor or UIColor
        PlatformFont = NSFont or UIFont
        PlatformImage = NSImage or UIImage
        PlatformEvent = NSEvent or UIEvent
        PlatformBezierPath = NSBezierPath or UIBezierPath
    }

    %% Cross-Platform Coordinator
    class CrossPlatformCoordinator {
        +currentPlatform: Platform
        +capabilities: PlatformCapabilities
        +eventAdapter: EventAdapter
        +inputAdapter: InputAdapter
        +coordinate(action: PlatformAction)
        +adaptEvent(PlatformEvent) UnifiedEvent
    }

    class Platform {
        &lt;&lt;enumeration&gt;&gt;
        macOS
        iOS
        macCatalyst
    }

    %% Event Handling
    class EventAdapter {
        &lt;&lt;protocol&gt;&gt;
        +adaptMouseEvent(NSEvent) UnifiedEvent
        +adaptTouchEvent(UITouch) UnifiedEvent
        +adaptKeyEvent(PlatformEvent) UnifiedEvent
        +adaptGestureEvent(PlatformGestureRecognizer) UnifiedEvent
    }

    class MacOSEventAdapter {
        +adaptMouseEvent(NSEvent) UnifiedEvent
        +adaptKeyEvent(NSEvent) UnifiedEvent
        +handleRightClick(NSEvent) UnifiedEvent
        +handleScroll(NSEvent) UnifiedEvent
    }

    class iOSEventAdapter {
        +adaptTouchEvent(UITouch) UnifiedEvent
        +adaptGestureEvent(UIGestureRecognizer) UnifiedEvent
        +handleLongPress(UILongPressGestureRecognizer) UnifiedEvent
    }

    %% Input Handling
    class InputAdapter {
        &lt;&lt;protocol&gt;&gt;
        +handleTextInput(String)
        +handleKeyCommand(KeyCommand)
        +handlePaste(String)
        +handleDragDrop(DragInfo)
    }

    class MacOSInputAdapter {
        -keyBindings: [KeyBinding]
        +handleKeyDown(NSEvent)
        +handleFlagsChanged(NSEvent)
        +performDragOperation(NSDraggingInfo)
    }

    class iOSInputAdapter {
        -textInputView: UITextInput
        +insertText(String)
        +deleteBackward()
        +handleKeyCommand(UIKeyCommand)
    }

    %% View Abstractions
    class PlatformTextView {
        &lt;&lt;protocol&gt;&gt;
        +text: String
        +selectedRange: NSRange
        +font: PlatformFont
        +textColor: PlatformColor
        +becomeFirstResponder()
        +resignFirstResponder()
    }

    class MacOSTextView {
        &lt;&lt;NSTextView&gt;&gt;
        +isRichText: Bool
        +isEditable: Bool
        +allowsUndo: Bool
        +textContainer: NSTextContainer
    }

    class iOSTextView {
        &lt;&lt;UITextView&gt;&gt;
        +isEditable: Bool
        +dataDetectorTypes: UIDataDetectorTypes
        +textContainer: NSTextContainer
    }

    %% Graphics Abstractions
    class PlatformGraphicsContext {
        &lt;&lt;protocol&gt;&gt;
        +fillRect(CGRect, color: PlatformColor)
        +strokeRect(CGRect, color: PlatformColor)
        +drawText(String, at: CGPoint)
        +setFont(PlatformFont)
    }

    class MacOSGraphicsContext {
        -nsGraphicsContext: NSGraphicsContext
        +saveGraphicsState()
        +restoreGraphicsState()
        +setNeedsDisplay(CGRect)
    }

    class iOSGraphicsContext {
        -cgContext: CGContext
        +saveGState()
        +restoreGState()
        +setNeedsDisplay()
    }

    %% Menu/Toolbar Abstractions
    class PlatformMenuBuilder {
        &lt;&lt;protocol&gt;&gt;
        +buildEditMenu() PlatformMenu
        +buildViewMenu() PlatformMenu
        +buildFormatMenu() PlatformMenu
    }

    class MacOSMenuBuilder {
        +buildMainMenu() NSMenu
        +buildContextMenu() NSMenu
        +addKeyboardShortcut(NSMenuItem, key: String)
    }

    class iOSMenuBuilder {
        +buildEditMenu() UIMenu
        +buildContextMenu(for: CGPoint) UIMenu
        +buildKeyCommands() [UIKeyCommand]
    }

    %% Relationships
    CrossPlatformCoordinator --> PlatformCapabilities : uses
    CrossPlatformCoordinator --> Platform : manages
    CrossPlatformCoordinator --> EventAdapter : uses
    CrossPlatformCoordinator --> InputAdapter : uses
    
    EventAdapter <|-- MacOSEventAdapter : implements
    EventAdapter <|-- iOSEventAdapter : implements
    
    InputAdapter <|-- MacOSInputAdapter : implements
    InputAdapter <|-- iOSInputAdapter : implements
    
    PlatformTextView <|-- MacOSTextView : implements
    PlatformTextView <|-- iOSTextView : implements
    
    PlatformGraphicsContext <|-- MacOSGraphicsContext : implements
    PlatformGraphicsContext <|-- iOSGraphicsContext : implements
    
    PlatformMenuBuilder <|-- MacOSMenuBuilder : implements
    PlatformMenuBuilder <|-- iOSMenuBuilder : implements
    
    PlatformCapabilities --> PlatformFeature : checks
    
    %% Styling - Dark mode friendly colors
    classDef detection fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef coordinator fill:#6366f120,stroke:#6366f1,stroke-width:2px,color:#fff
    classDef abstraction fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef platform fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef enum fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    
    class PlatformCapabilities detection
    class CrossPlatformCoordinator coordinator
    class EventAdapter abstraction
    class InputAdapter abstraction
    class PlatformTextView abstraction
    class PlatformGraphicsContext abstraction
    class PlatformMenuBuilder abstraction
    class MacOSEventAdapter platform
    class iOSEventAdapter platform
    class MacOSInputAdapter platform
    class iOSInputAdapter platform
    class MacOSTextView platform
    class iOSTextView platform
    class MacOSGraphicsContext platform
    class iOSGraphicsContext platform
    class MacOSMenuBuilder platform
    class iOSMenuBuilder platform
    class PlatformFeature enum
    class Platform enum
```

## Platform-Specific Code Example

```swift
// Platform detection
#if canImport(AppKit)
import AppKit
typealias PlatformView = NSView
typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
typealias PlatformView = UIView
typealias PlatformColor = UIColor
#endif

// Feature detection
if PlatformCapabilities.shared.hasHoverSupport {
    // Enable hover highlighting
}

// Platform-specific behavior
switch CrossPlatformCoordinator.shared.currentPlatform {
case .macOS:
    // macOS-specific implementation
case .iOS:
    // iOS-specific implementation
case .macCatalyst:
    // Catalyst-specific implementation
}
```

## Key Abstraction Principles

1. **Compile-time Type Aliases**: Use `typealias` for platform types
2. **Runtime Feature Detection**: Check capabilities at runtime
3. **Protocol-based Abstractions**: Define common interfaces
4. **Adapter Pattern**: Convert platform-specific events to unified format
5. **Factory Pattern**: Create platform-specific implementations
6. **Conditional Compilation**: Use `#if canImport()` for platform code
7. **Graceful Degradation**: Disable unsupported features cleanly