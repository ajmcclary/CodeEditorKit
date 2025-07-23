# Advanced Patterns

@Metadata {
    @PageKind(article)
    @PageColor(purple)
}

Learn advanced integration patterns and best practices for CodeEditorPlugin.

## Overview

This guide covers advanced patterns for building sophisticated applications with CodeEditorPlugin, including multi-window support, collaborative editing preparation, and performance optimization techniques.

## Multi-Window Support (macOS)

### Window Management

```swift
class EditorWindowController: NSWindowController {
    private var editors: [NSWindow: CodeEditorView] = [:]
    
    func createNewWindow(with content: String? = nil) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        let editor = CodeEditorView()
        editor.text = content ?? ""
        
        window.contentView = editor
        window.title = "Untitled"
        
        editors[window] = editor
        return window
    }
    
    func synchronizeWindows(for document: Document) {
        for (window, editor) in editors {
            if window.representedURL == document.url {
                editor.text = document.content
            }
        }
    }
}
```

### Tab Support

```swift
@available(macOS 12.0, *)
class TabbedEditorController: NSViewController {
    @IBOutlet weak var tabView: NSTabView!
    
    func addTab(for file: URL) {
        let editor = CodeEditorView()
        editor.text = try String(contentsOf: file)
        editor.setLanguage(from: file.pathExtension)
        
        let tabItem = NSTabViewItem(viewController: wrapEditor(editor))
        tabItem.label = file.lastPathComponent
        
        tabView.addTabViewItem(tabItem)
        tabView.selectTabViewItem(tabItem)
    }
}
```

## Document-Based Architecture

### Document Model

```swift
class CodeDocument: NSDocument {
    var content = ""
    var language: Language?
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateController(
            withIdentifier: "EditorWindowController"
        ) as! EditorWindowController
        
        controller.editor.text = content
        controller.editor.language = language
        
        addWindowController(controller)
    }
    
    override func data(ofType typeName: String) throws -> Data {
        content.data(using: .utf8) ?? Data()
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        content = String(data: data, encoding: .utf8) ?? ""
        language = Language.detect(from: typeName)
    }
}
```

## State Management

### Redux-Style State

```swift
struct EditorState {
    var documents: [DocumentID: Document]
    var activeDocument: DocumentID?
    var configuration: EditorConfiguration
    var searchQuery: String?
}

enum EditorAction {
    case openDocument(Document)
    case closeDocument(DocumentID)
    case updateContent(DocumentID, String)
    case updateConfiguration(EditorConfiguration)
    case search(String)
}

class EditorStore: ObservableObject {
    @Published private(set) var state = EditorState()
    
    func dispatch(_ action: EditorAction) {
        state = reducer(state: state, action: action)
    }
    
    private func reducer(state: EditorState, action: EditorAction) -> EditorState {
        var newState = state
        
        switch action {
        case .openDocument(let doc):
            newState.documents[doc.id] = doc
            newState.activeDocument = doc.id
            
        case .closeDocument(let id):
            newState.documents[id] = nil
            if newState.activeDocument == id {
                newState.activeDocument = newState.documents.keys.first
            }
            
        case .updateContent(let id, let content):
            newState.documents[id]?.content = content
            
        case .updateConfiguration(let config):
            newState.configuration = config
            
        case .search(let query):
            newState.searchQuery = query
        }
        
        return newState
    }
}
```

## Collaborative Editing (Preparation)


## Performance Patterns

### Virtual Scrolling

```swift
class VirtualScrollingCoordinator {
    private let viewportHeight: CGFloat
    private let lineHeight: CGFloat
    private var visibleRange: NSRange?
    
    func updateVisibleRange(scrollOffset: CGFloat) {
        let startLine = Int(scrollOffset / lineHeight)
        let visibleLines = Int(viewportHeight / lineHeight) + 2 // Buffer
        
        visibleRange = NSRange(
            location: startLine,
            length: visibleLines
        )
        
        renderVisibleContent()
    }
    
    private func renderVisibleContent() {
        guard let range = visibleRange else { return }
        
        // Only render visible lines
        for line in range.location..<NSMaxRange(range) {
            renderLine(line)
        }
    }
}
```

### Incremental Parsing

```swift
actor IncrementalParser {
    private var ast: SyntaxTree?
    private var lastParsedText: String = ""
    
    func parse(_ text: String, changes: [TextChange]) async -> SyntaxTree {
        if ast == nil {
            // Full parse on first run
            return await fullParse(text)
        }
        
        // Incremental parse for changes
        var tree = ast!
        
        for change in changes {
            tree = await applyChange(tree, change: change)
        }
        
        ast = tree
        lastParsedText = text
        return tree
    }
}
```

## Plugin Development Patterns

### Plugin Host

```swift
class PluginHost {
    private var plugins: [PluginIdentifier: Plugin] = [:]
    private let sandbox = PluginSandbox()
    
    func loadPlugin(at url: URL) async throws {
        let bundle = try PluginBundle(url: url)
        let plugin = try bundle.instantiate()
        
        // Initialize in sandbox
        let context = PluginContext(
            editor: editorProxy,
            storage: sandboxedStorage,
            networking: restrictedNetworking
        )
        
        try await plugin.activate(context: context)
        plugins[plugin.identifier] = plugin
    }
    
    func broadcast(_ event: EditorEvent) {
        for plugin in plugins.values {
            Task {
                try? await plugin.handle(event)
            }
        }
    }
}
```

## Custom Rendering

### Custom Line Decorations

```swift
protocol LineDecoration {
    func draw(in rect: CGRect, context: CGContext)
}

class BreakpointDecoration: LineDecoration {
    let color = NSColor.systemRed
    
    func draw(in rect: CGRect, context: CGContext) {
        context.setFillColor(color.cgColor)
        let circle = CGRect(
            x: rect.minX + 4,
            y: rect.midY - 6,
            width: 12,
            height: 12
        )
        context.fillEllipse(in: circle)
    }
}

extension CodeEditorView {
    func addDecoration(_ decoration: LineDecoration, at line: Int) {
        lineDecorations[line] = decoration
        setNeedsDisplay()
    }
}
```

## Testing Patterns

### UI Testing

```swift
class EditorUITests: XCTestCase {
    func testSyntaxHighlighting() {
        let app = XCUIApplication()
        app.launch()
        
        // Type code
        let editor = app.textViews["codeEditor"]
        editor.tap()
        editor.typeText("func hello() { print(\"Hello\") }")
        
        // Verify highlighting
        let highlightedText = editor.value as? String
        XCTAssertTrue(highlightedText?.contains("func") ?? false)
    }
}
```

### Performance Testing

```swift
class PerformanceTests: XCTestCase {
    func testLargeFilePerformance() {
        let editor = CodeEditorView()
        let largeFile = String(repeating: "// Comment\n", count: 10_000)
        
        measure {
            editor.text = largeFile
            editor.language = .swift
            
            // Force syntax highlighting
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }
}
```

## Error Handling

CodeEditorPlugin provides comprehensive error handling:

### Safe Operations

```swift
do {
    // Safe operations that validate input
    try editor.setText(largeText)
    try editor.setLanguage(.python)
    try editor.replaceTextSafe(in: range, with: "new text")
    
    // Async operations with error handling
    let hover = try await editor.requestHover(at: position)
    let completions = try await editor.requestCompletion(at: position)
} catch let error as CodeEditorError {
    print("Editor error: \(error.localizedDescription)")
    
    // Attempt automatic recovery
    if editor.attemptErrorRecovery(from: error) {
        print("Successfully recovered from error")
    }
}
```

### Error Types

```swift
enum CodeEditorError: LocalizedError {
    case invalidRange(NSRange, textLength: Int)
    case invalidPosition(Int, textLength: Int)
    case invalidConfiguration(String)
    case encodingError
    case languageNotSupported(String)
    case fileTooLarge(size: Int, limit: Int)
}
```

## Common Patterns

### Read-Only Code Viewer

```swift
let config = EditorConfigurationBuilder(preset: .readOnly)
    .fontSize(14)
    .theme(.github)
    .language(.swift)
    .build()

editor.configuration = config
```

### Markdown Editor

```swift
let config = EditorConfigurationBuilder()
    .language(.markdown)
    .wrapLines(true)
    .enableSpellCheck(true)
    .showLineNumbers(false)
    .build()
```

### Presentation Mode

```swift
let config = EditorConfigurationBuilder(preset: .presentation)
    .language(.swift)  // Or your preferred language
    .build()

// Or customize further
let customPresentation = EditorConfigurationBuilder(preset: .presentation)
    .fontSize(24)  // Even larger
    .theme(.dark)
    .build()
```

### Diff Viewer

```swift
class DiffViewer {
    let leftEditor = CodeEditorView()
    let rightEditor = CodeEditorView()
    
    func configure() {
        let config = EditorConfigurationBuilder()
            .readOnly()
            .syncScrolling(true)
            .highlightDifferences(true)
            .build()
        
        leftEditor.configuration = config
        rightEditor.configuration = config
    }
}
```

## Theme Customization

### Built-in Themes

```swift
let config = EditorConfigurationBuilder()
    .theme(.dark)    // or .light, .minimal
    .build()
```

### Custom Colors

```swift
editor.backgroundColor = PlatformColor.codeBackground
editor.selectedLineHighlightColor = PlatformColor.selectedLineHighlight
```

### Creating Custom Themes

```swift
struct MyCustomTheme: Theme {
    var backgroundColor: PlatformColor { .black }
    var textColor: PlatformColor { .white }
    var lineNumberColor: PlatformColor { .gray }
    var selectedLineColor: PlatformColor { PlatformColor.blue.withAlphaComponent(0.1) }
    
    // Syntax colors
    var keywordColor: PlatformColor { .purple }
    var stringColor: PlatformColor { .red }
    var commentColor: PlatformColor { .green }
}
```

## Migration Patterns

### From NSTextView/UITextView

```swift
// Old way
let textView = NSTextView()
textView.string = code
textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

// New way
let editor = CodeEditorView()
editor.text = code
editor.configuration = EditorConfigurationBuilder()
    .fontSize(14)
    .language(.swift)
    .build()
```

### From Other Code Editors

```swift
// Migrate from Monaco/CodeMirror patterns
class EditorMigration {
    func migrateFromMonaco(monacoConfig: [String: Any]) -> EditorConfiguration {
        return EditorConfigurationBuilder()
            .fontSize(monacoConfig["fontSize"] as? CGFloat ?? 14)
            .theme(mapMonacoTheme(monacoConfig["theme"] as? String))
            .language(mapMonacoLanguage(monacoConfig["language"] as? String))
            .build()
    }
}
```

## Performance Optimization Patterns

### Large File Handling

```swift
// Automatic optimization for large files
editor.optimizeForLargeFiles()

// Manual configuration
var performance = config.performance
performance.useHardwareAcceleration = true
performance.maxSyntaxHighlightingLength = 100_000
performance.enableViewportRendering = true
```

### Memory-Conscious Configuration

```swift
let memoryOptimizedConfig = EditorConfigurationBuilder()
    .enableViewportRendering()
    .maxSyntaxHighlightingLength(50_000)
    .disableMinimap()
    .reduceAnimations()
    .build()
```

## Best Practices

1. **Start Simple**: Begin with presets and customize as needed
2. **Lazy Loading**: Load content only when needed
3. **Debouncing**: Debounce rapid user actions
4. **Caching**: Cache expensive computations
5. **Background Work**: Use actors for heavy processing
6. **Memory Management**: Monitor and limit memory usage
7. **Error Recovery**: Always implement error handling
8. **Platform Testing**: Test on all target platforms

## See Also

- <doc:Architecture-Overview>
- <doc:Performance-Monitoring>
- <doc:Performance-Optimization-Integration>
- <doc:Plugin-Architecture>
- <doc:Troubleshooting>
- <doc:Configuration-System>