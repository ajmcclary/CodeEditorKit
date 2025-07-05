# iOS Integration

@Metadata {
    @PageColor(blue)
}

Create touch-optimized code editing experiences for iPhone and iPad.

## Overview

CodeEditorPlugin provides comprehensive iOS support with touch-optimized interactions, proper keyboard handling, and iPad-specific features. The platform abstraction layer ensures consistent behavior while leveraging iOS-specific capabilities.

## Platform Setup

### Using Platform Types

Always use the platform abstraction types for cross-platform compatibility:

```swift
import CodeEditorPlugin

// Use platform-agnostic types
let backgroundColor = PlatformColors.systemBackground
let textColor = PlatformColors.label
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14)

// Configure editor with platform types
var config = EditorConfiguration()
config.display.backgroundColor = backgroundColor
config.display.textColor = textColor
config.display.font = codeFont
```

## Touch Interactions

### Selection Gestures

```swift
extension CodeEditorView {
    func setupTouchGestures() {
        // Long press for selection
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)
        
        // Double tap for word selection
        let doubleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        // Triple tap for line selection
        let tripleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTripleTap(_:))
        )
        tripleTap.numberOfTapsRequired = 3
        addGestureRecognizer(tripleTap)
    }
}
```

## Keyboard Management

### Keyboard Avoidance

```swift
class KeyboardAwareEditor: UIView {
    private var keyboardHeight: CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        keyboardHeight = keyboardFrame.height
        
        UIView.animate(withDuration: duration) {
            self.contentInset.bottom = self.keyboardHeight
            self.scrollIndicatorInsets.bottom = self.keyboardHeight
        }
    }
}
```

### Custom Input Accessory

```swift
class EditorInputAccessoryView: UIView {
    lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: nil, action: #selector(CodeEditorView.undo)),
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: nil, action: #selector(CodeEditorView.redo)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        ]
        return toolbar
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(toolbar)
        // Setup constraints...
    }
}
```

## iPad Optimization

### Split View Support

```swift
class iPadEditorViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Support split view
        view.backgroundColor = .systemBackground
        
        // Add keyboard shortcuts for iPad
        addKeyCommand(UIKeyCommand(
            title: "New File",
            action: #selector(newFile),
            input: "n",
            modifierFlags: .command
        ))
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Adapt to size class changes
        if traitCollection.horizontalSizeClass == .compact {
            // iPhone or split view
            configureForCompactWidth()
        } else {
            // Full iPad width
            configureForRegularWidth()
        }
    }
}
```

### Pointer Interaction

```swift
@available(iOS 13.4, *)
extension CodeEditorView: UIPointerInteractionDelegate {
    func setupPointerInteraction() {
        let interaction = UIPointerInteraction(delegate: self)
        addInteraction(interaction)
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        // Highlight line numbers on hover
        if isPointInGutter(request.location) {
            return UIPointerRegion(rect: gutterRect)
        }
        return nil
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        return UIPointerStyle(effect: .hover(.highlighted))
    }
}
```

## Context Menus

```swift
extension CodeEditorView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(copy(_:)), #selector(cut(_:)), #selector(paste(_:)):
            return true
        case #selector(toggleComment):
            return true
        case #selector(indentSelection):
            return true
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    @objc func toggleComment() {
        // Implementation
    }
    
    @objc func indentSelection() {
        // Implementation
    }
}
```

## Hardware Keyboard Support

```swift
override var keyCommands: [UIKeyCommand]? {
    return [
        // File operations
        UIKeyCommand(title: "Save", action: #selector(save), input: "s", modifierFlags: .command),
        UIKeyCommand(title: "Open", action: #selector(open), input: "o", modifierFlags: .command),
        
        // Editing
        UIKeyCommand(title: "Find", action: #selector(find), input: "f", modifierFlags: .command),
        UIKeyCommand(title: "Replace", action: #selector(replace), input: "f", modifierFlags: [.command, .shift]),
        
        // Navigation
        UIKeyCommand(title: "Go to Line", action: #selector(goToLine), input: "l", modifierFlags: .command),
        
        // View
        UIKeyCommand(title: "Toggle Line Numbers", action: #selector(toggleLineNumbers), input: "l", modifierFlags: [.command, .shift])
    ]
}
```

## Drag and Drop

```swift
extension CodeEditorView: UIDropDelegate {
    func setupDragAndDrop() {
        dropDelegate = self
        
        // Enable dragging text
        textDragDelegate = self
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.text.identifier])
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: NSString.self) { items in
            if let string = items.first as? String {
                self.insertText(string)
            }
        }
    }
}
```

## Container View Architecture

For iOS, use `CodeEditorContainerView` to get proper gutter separation and minimap support:

```swift
import CodeEditorPlugin

class EditorViewController: UIViewController {
    private var containerView: CodeEditorContainerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create container view (includes gutter and optional minimap)
        containerView = CodeEditorContainerView()
        
        // Access the text view
        let textView = containerView.textView
        textView.language = .swift
        
        // Configure
        containerView.configuration = {
            var config = EditorConfiguration.default
            config.display.showLineNumbers = true
            config.display.showMinimap = false // Not recommended on iPhone
            return config
        }()
        
        view.addSubview(containerView)
        // Setup constraints...
    }
}
```

## Best Practices

1. **Touch Targets**: Ensure touch targets are at least 44x44 points
2. **Keyboard Handling**: Always handle keyboard appearance properly
3. **Memory Management**: Be mindful of memory on older devices
4. **State Restoration**: Save and restore scroll position and selection
5. **Accessibility**: Support VoiceOver and other accessibility features
6. **Platform Types**: Always use `PlatformColor`, `PlatformFont`, etc.
7. **Container View**: Use `CodeEditorContainerView` for proper layout

## See Also

- <doc:Platform-Abstraction>
- <doc:SwiftUI-Integration>
- <doc:UIKit-AppKit-Integration>
- <doc:macOS-Integration>
- <doc:Catalyst-Best-Practices>