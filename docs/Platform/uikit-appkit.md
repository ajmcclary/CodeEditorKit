# UIKit & AppKit Integration

Integrate CodeEditorPlugin with traditional UIKit and AppKit applications.

## Overview

While CodeEditorPlugin provides excellent SwiftUI support, it also offers comprehensive integration with UIKit (iOS) and AppKit (macOS) for traditional view-based applications.

## Basic Integration

### UIKit (iOS)

```swift
import CodeEditorPlugin
import UIKit

class EditorViewController: UIViewController {
    private let editor = CodeEditorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure editor
        editor.text = "// Your Swift code here"
        editor.setLanguage(fileExtension: "swift")
        
        // Apply configuration
        var config = EditorConfiguration.default
        config.display.isLineNumbersEnabled = true
        config.apply(to: editor)
        
        // Add to view hierarchy
        view.addSubview(editor)
        setupConstraints()
    }
    
    private func setupConstraints() {
        editor.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            editor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
```

### AppKit (macOS)

```swift
import CodeEditorPlugin
import AppKit

class EditorViewController: NSViewController {
    private let editor = CodeEditorView()
    
    override func loadView() {
        view = NSView()
        
        // Configure editor
        editor.text = "# Welcome to CodeEditorPlugin"
        editor.setLanguage(fileExtension: "md")
        
        // Apply configuration
        let config = EditorConfiguration.markdown
        config.apply(to: editor)
        
        // Add to view hierarchy
        view.addSubview(editor)
        setupConstraints()
    }
    
    private func setupConstraints() {
        editor.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: view.topAnchor),
            editor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
```

## Delegate Pattern

### Setting Up Delegates

```swift
class EditorViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editor.textDelegate = self
    }
}

extension EditorViewController: CodeEditorViewDelegate {
    func textViewDidChangeText(_ notification: Notification) {
        guard let editor = notification.object as? CodeEditorView else { return }
        // Handle text changes.
        _ = editor.text
        updateSaveButton(enabled: true)
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let editor = notification.object as? CodeEditorView else { return }
        let range = editor.selectedRange
        // Handle selection changes.
        updateStatusBar(with: range)
    }
    
    func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn affectedCharRange: NSTextRange,
        replacementString: String?
    ) -> Bool {
        true
    }
}
```

## Toolbar Integration

### iOS Toolbar

```swift
private func setupToolbar() {
    let toolbar = UIToolbar()
    
    let undoButton = UIBarButtonItem(
        image: UIImage(systemName: "arrow.uturn.backward"),
        style: .plain,
        target: editor,
        action: #selector(CodeEditorView.undo)
    )
    
    let redoButton = UIBarButtonItem(
        image: UIImage(systemName: "arrow.uturn.forward"),
        style: .plain,
        target: editor,
        action: #selector(CodeEditorView.redo)
    )
    
    let findButton = UIBarButtonItem(
        image: UIImage(systemName: "magnifyingglass"),
        style: .plain,
        target: self,
        action: #selector(showFindReplace)
    )
    
    toolbar.items = [
        undoButton,
        redoButton,
        .flexibleSpace(),
        findButton
    ]
    
    // Add toolbar as input accessory
    editor.inputAccessoryView = toolbar
}
```

### macOS Toolbar

```swift
extension EditorViewController: NSToolbarDelegate {
    func setupToolbar() {
        let toolbar = NSToolbar(identifier: "EditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        
        view.window?.toolbar = toolbar
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleLineNumbers, .changeTheme, .flexibleSpace, .search]
    }
    
    @objc func toggleLineNumbers() {
        configuration.display.isLineNumbersEnabled.toggle()
        configuration.apply(to: editor)
    }
}
```

## Menu Integration (macOS)

```swift
extension EditorViewController {
    func setupMenus() {
        // Edit menu
        let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")
        
        let findItem = NSMenuItem(
            title: "Find",
            action: #selector(showFindPanel),
            keyEquivalent: "f"
        )
        editMenu?.submenu?.addItem(findItem)
        
        // View menu
        let viewMenu = NSApp.mainMenu?.item(withTitle: "View")
        
        let themeSubmenu = NSMenu(title: "Theme")
        for theme in ThemeFamily.bundled("zed-trek")?.themes ?? [.lcarsDark] {
            let item = NSMenuItem(
                title: theme.name,
                action: #selector(changeTheme(_:)),
                keyEquivalent: ""
            )
            item.representedObject = theme
            themeSubmenu.addItem(item)
        }
        
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeSubmenu
        viewMenu?.submenu?.addItem(themeItem)
    }
    
    @objc func changeTheme(_ sender: NSMenuItem) {
        if let theme = sender.representedObject as? Theme {
            editor.apply(theme: theme)
        }
    }
}
```

## Context Menus

### iOS Context Menu

```swift
editor.contextMenuProvider = { location in
    let config = UIContextMenuConfiguration(
        identifier: nil,
        previewProvider: nil
    ) { _ in
        let copy = UIAction(
            title: "Copy",
            image: UIImage(systemName: "doc.on.doc")
        ) { _ in
            self.editor.copy(nil)
        }
        
        let paste = UIAction(
            title: "Paste",
            image: UIImage(systemName: "doc.on.clipboard")
        ) { _ in
            self.editor.paste(nil)
        }
        
        return UIMenu(children: [copy, paste])
    }
    
    return config
}
```

### macOS Context Menu

```swift
override func rightMouseDown(with event: NSEvent) {
    let menu = NSMenu()
    
    menu.addItem(NSMenuItem(
        title: "Cut",
        action: #selector(cut(_:)),
        keyEquivalent: "x"
    ))
    
    menu.addItem(NSMenuItem(
        title: "Copy",
        action: #selector(copy(_:)),
        keyEquivalent: "c"
    ))
    
    menu.addItem(NSMenuItem(
        title: "Paste",
        action: #selector(paste(_:)),
        keyEquivalent: "v"
    ))
    
    menu.addItem(.separator())
    
    menu.addItem(NSMenuItem(
        title: "Go to Definition",
        action: #selector(goToDefinition),
        keyEquivalent: ""
    ))
    
    NSMenu.popUpContextMenu(menu, with: event, for: self)
}
```

## Keyboard Shortcuts

### iOS Keyboard Commands

```swift
override var keyCommands: [UIKeyCommand]? {
    [
        UIKeyCommand(
            title: "Save",
            action: #selector(saveDocument),
            input: "s",
            modifierFlags: .command
        ),
        UIKeyCommand(
            title: "Find",
            action: #selector(showFind),
            input: "f",
            modifierFlags: .command
        ),
        UIKeyCommand(
            title: "Increase Font Size",
            action: #selector(increaseFontSize),
            input: "+",
            modifierFlags: .command
        )
    ]
}
```

### macOS Key Events

```swift
override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
        switch event.charactersIgnoringModifiers {
        case "d":
            duplicateLine()
        case "l":
            goToLine()
        case "/":
            toggleComment()
        default:
            super.keyDown(with: event)
        }
    } else {
        super.keyDown(with: event)
    }
}
```

## Split View Integration

### iOS Split View

```swift
class SplitEditorViewController: UIViewController {
    private let leftEditor = CodeEditorView()
    private let rightEditor = CodeEditorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stackView = UIStackView(arrangedSubviews: [leftEditor, rightEditor])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 1
        
        view.addSubview(stackView)
        // Setup constraints...
    }
}
```

### macOS Split View

```swift
class SplitEditorViewController: NSSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let leftItem = NSSplitViewItem(viewController: makeEditorController())
        let rightItem = NSSplitViewItem(viewController: makeEditorController())
        
        splitViewItems = [leftItem, rightItem]
    }
    
    private func makeEditorController() -> NSViewController {
        let controller = NSViewController()
        let editor = CodeEditorView()
        controller.view = editor
        return controller
    }
}
```

## Best Practices

1. **Memory Management**: Use weak references in closures
2. **State Restoration**: Save and restore editor state
3. **Accessibility**: Ensure keyboard navigation works
4. **Performance**: Load large files asynchronously
5. **Error Handling**: Gracefully handle file loading errors

## See Also

- [SwiftUI-Integration](../SwiftUI/integration.md)
- [Configuration-System](../Configuration/system.md)
- [Platform-Abstraction](platform-abstraction.md)
