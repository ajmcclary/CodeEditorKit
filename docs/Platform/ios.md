# iOS Integration

Create touch-optimized code editing experiences for iPhone and iPad.

## Overview

CodeEditorKit provides comprehensive iOS support with touch-optimized interactions, proper keyboard handling, and iPad-specific features. The platform abstraction layer ensures consistent behavior while leveraging iOS-specific capabilities.

## Platform Setup

### Using Platform Types

Always use the platform abstraction types for cross-platform compatibility. Platform detection uses `#if canImport()` patterns throughout the codebase. (Mac Catalyst support was retired in 0.2.0 — the framework targets macOS and iOS / iPadOS only.)

```swift
import CodeEditorKit

// Use platform-agnostic types
let backgroundColor = PlatformColors.systemBackground
let textColor = PlatformColors.label
let codeFont = PlatformFonts.monospacedSystemFont(ofSize: 14)

// Use platform values when building app chrome; editor color comes from Theme.
// Theme.default resolves to the bundled "LCARS Dark" variant of the Zed Trek family.
var config = EditorConfiguration()
config.display.fontSize = 16
config.layout.tabWidth = 4
let theme = Theme.default
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
import CodeEditorKit

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
            config.display.isLineNumbersEnabled = true
            config.display.isMinimapVisible = false // Not recommended on iPhone
            return config
        }()
        
        view.addSubview(containerView)
        // Setup constraints...
    }
}
```

## Large File Handling

iOS devices are memory-constrained relative to the desktop. For multi-megabyte files, use `IOSLargeFileOptimizer` to scale rendering and highlighting down adaptively.

### Optimization modes

| Mode | File size | Behavior |
|---|---|---|
| Normal | < 1 MB | No optimization |
| Large file | 1–10 MB | Disables full-document highlighting; viewport-based only. Reduces undo to 10 levels. Disables spell-checking. |
| Extreme | ≥ 10 MB | All large-file behaviors plus: undo limited to 3 levels, simplified rendering, no text attachments, non-contiguous layout. |

### Setup

```swift
let optimizer = IOSLargeFileOptimizer(
    textView: codeEditorView,
    memoryMonitor: memoryMonitor,
    performanceMonitor: performanceSystem
)

optimizer.optimizationThreshold = 500_000   // bytes — when to kick in
optimizer.maxHighlightingRange = 50_000     // chunk size for viewport highlighting
optimizer.viewportExpansion = 0.3           // expand viewport by 30% for prefetch
optimizer.memoryPressureMode = .aggressive  // .ignore | .adaptive | .aggressive

optimizer.enableOptimizations()
```

The optimizer captures the editor's pre-optimization settings (`maxSyntaxHighlightingLength`, `isSyntaxHighlightingEnabled`, `adaptivePerformanceMode`) and restores them when you call `disableOptimizations()`.

### SwiftUI

Enable the optimizations through the editor configuration (the former `.iOSLargeFileOptimization(_:)` view modifier was removed — it never applied the configuration it computed):

```swift
struct EditorView: View {
    @StateObject private var optimizer: IOSLargeFileOptimizer
    @State private var content = ""

    var configuration: EditorConfiguration {
        var config = EditorConfiguration()
        config.performance.enableIOSOptimizations = content.count > 500_000
        return config
    }

    var body: some View {
        VStack {
            CodeEditor.withConfiguration($content, configuration: configuration)

            if optimizer.isOptimizing {
                Label("Optimized — \(optimizer.currentMode.rawValue)", systemImage: "speedometer")
                    .foregroundStyle(.orange)
            }
        }
    }
}
```

### Memory pressure response

Under memory pressure the optimizer registers a critical-priority cleanup handler with `MemoryMonitor` that clears the syntax-highlighting cache, drops the undo stack, and asks TextKit to release layout caches. Pair it with [Memory monitor](../Performance/memory-monitor.md) to wire that up.

### iOS vs. macOS thresholds

| Setting | iOS | macOS |
|---|---|---|
| Optimization threshold | 1 MB | 10 MB |
| Viewport expansion | 50% | 150% |
| Max highlighting range | 100 KB | 1 MB |
| Memory threshold | 100 MB | 1 GB |

Tune for your target device class — older iPhones benefit from lower thresholds and aggressive mode; iPad Pro can use values closer to macOS.

## Best Practices

1. **Touch targets**: at least 44×44 pt.
2. **Keyboard handling**: always observe `keyboardWillShow`/`keyboardWillHide` and adjust insets.
3. **Memory**: use `IOSLargeFileOptimizer` for files > 500 KB; watch `memoryMonitor.memoryStats`.
4. **State restoration**: persist scroll position and selection.
5. **Accessibility**: support VoiceOver.
6. **Platform types**: use `PlatformColor`, `PlatformFont`, `PlatformColors.label`, etc. — never `UIColor`/`NSColor` directly.
7. **Container view**: use `CodeEditorContainerView` for gutter and minimap support.

## See Also

- [Platform-Abstraction](platform-abstraction.md)
- [SwiftUI-Integration](../SwiftUI/integration.md)
- [UIKit-AppKit-Integration](uikit-appkit.md)
- [macOS-Integration](macos.md)
