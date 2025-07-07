import Foundation
import ObjectiveC
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - CodeEditorView

/// A powerful, cross-platform text view designed specifically for code editing.
///
/// `CodeEditorView` provides advanced features for code editing including:
/// - **Syntax highlighting** with support for 17+ programming languages
/// - **Code completion** with LSP integration and custom providers
/// - **Line numbers** with customizable gutter display
/// - **Annotations** for displaying TODOs, FIXMEs, and custom markers
/// - **Cross-platform support** for iOS, macOS, and Mac Catalyst
/// - **Modern TextKit2** integration with fallback to TextKit1
/// - **Configurable appearance** with themes and layout options
/// - **Performance optimization** for large files and real-time editing
///
/// ## Basic Usage
///
/// ```swift
/// let editor = CodeEditorView()
/// editor.string = "func hello() {\n    logger.debug(\"Hello, World!\")\n}"
/// editor.language = .swift
/// editor.showsLineNumbers = true
/// editor.enablesCodeCompletion = true
/// ```
///
/// ## Configuration
///
/// Use `EditorConfiguration` for comprehensive customization:
///
/// ```swift
/// var config = EditorConfiguration()
/// config.display.fontSize = 16
/// config.display.syntaxHighlighting = true
/// config.layout.tabWidth = 4
/// config.behavior.autoIndent = true
/// config.apply(to: editor)
/// ```
///
/// ## SwiftUI Integration
///
/// For SwiftUI apps, use `CodeEditor`:
///
/// ```swift
/// struct ContentView: View {
///     @State private var code = "// Your code here"
///     
///     var body: some View {
///         CodeEditor(text: $code, language: .swift)
///             .showsLineNumbers(true)
///             .enablesCodeCompletion(true)
///     }
/// }
/// ```
///
/// ## Language Server Protocol Support
///
/// Connect to language servers for advanced features:
///
/// ```swift
/// // Configure LSP for Swift
/// try await editor.languageServerManager.configureLanguageServer(
///     for: .swift,
///     serverPath: "/usr/bin/sourcekit-lsp"
/// )
/// 
/// // Request hover information
/// let hover = try await editor.requestHoverSafe(at: cursorPosition)
/// ```
///
/// ## Performance Considerations
///
/// - Files larger than 500KB disable syntax highlighting by default
/// - Hardware acceleration is enabled automatically when available
/// - Use `EditorConfiguration.Performance` to customize limits
/// - Consider read-only mode for display-only scenarios
///
/// ## Error Handling
///
/// Most methods provide both safe (throwing) and non-throwing variants:
///
/// ```swift
/// // Non-throwing (returns nil on error)
/// let hover = await editor.requestHover(at: position)
/// 
/// // Throwing (provides detailed error information)
/// do {
///     let hover = try await editor.requestHoverSafe(at: position)
/// } catch let error as CodeEditorError {
///     logger.error("Error: \(error.localizedDescription)")
/// }
/// ```
@objc @MainActor
open class CodeEditorView: PlatformTextView, NSTextLayoutManagerDelegate, CodeEditorAPI, CompletionViewControllerDelegate {
    // MARK: - Static Properties
    
    /// Logger instance for CodeEditorView
    internal static let logger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorView")
    
    // This file contains the core class definition with all stored properties.
    // All methods have been moved to focused extension files:
    //
    // - CodeEditorView+Core.swift - Computed properties and type definitions
    // - CodeEditorView+Setup.swift - Initialization and setup methods
    // - CodeEditorView+SyntaxHighlighting.swift - Syntax highlighting methods
    // - CodeEditorView+Completion.swift - Code completion functionality
    // - CodeEditorView+LineNumbers.swift - Line numbers and gutter management
    // - CodeEditorView+Configuration.swift - Configuration application and line highlighting
    // - CodeEditorView+Annotations.swift - Annotation support
    // - CodeEditorView+Layout.swift - Layout methods and paragraph style
    // - CodeEditorView+TextKit.swift - TextKit related methods
    // - CodeEditorView+Performance.swift - Performance optimization and memory management
    // - CodeEditorView+CodeFolding.swift - Code folding API
    // - CodeEditorView+PlatformSpecific.swift - Platform-specific methods
    
    // MARK: - Stored Properties
    
    /// Proxy for delegate calls
    internal let delegateProxy = CodeEditorViewDelegateProxy(source: nil)
    
    /// Event publisher for unified event handling
    public let eventPublisher = EditorEventPublisher()
    
    /// Layout coordinator to prevent recursive layout
    internal lazy var layoutCoordinator = LayoutCoordinator(view: self)
    
    /// The configuration object that controls all aspects of the editor's behavior and appearance
    public var configuration: EditorConfiguration = .default {
        didSet {
            applyConfiguration()
        }
    }
    
    /// The syntax highlighting coordinator
    internal let syntaxHighlighter = SyntaxHighlightingCoordinator()
    
    /// Async syntax highlighter with debouncing
    internal let asyncHighlighter = AsyncSyntaxHighlighter()
    
    /// TextKit2 rendering optimizer for large files
    internal let renderingOptimizer = TextKit2RenderingOptimizer()
    
    /// TextKit2 performance monitor
    internal let performanceMonitor = TextKit2PerformanceMonitor()
    
    /// LSP manager for language server integration
    internal let lspManager = LSPManager()
    
    /// Code folding engine for managing foldable regions and fold states
    public let codeFoldingEngine = CodeFoldingEngine()
    
    /// Line index cache for optimized line number calculations
    internal let lineIndexCache = LineIndexCache()
    
    /// The current programming language used for syntax highlighting and code completion
    public var language: Language = .plainText {
        didSet {
            if language != oldValue {
                applySyntaxHighlighting()
                updateCompletionTriggerCharacters()
            }
        }
    }
    
    /// Gutter view for line numbers
    internal var gutterViewStorage: GutterView?
    
    /// Line highlight view
    internal var lineHighlightView: PlatformView?
    
    /// The current annotations displayed in the editor
    public private(set) var annotations: [Annotation] = []
    
    // Internal methods for modifying annotations from extensions
    internal func updateAnnotations(_ newAnnotations: [Annotation]) {
        annotations = newAnnotations
    }
    
    internal func appendAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
    }
    
    internal func removeAnnotation(where predicate: (Annotation) -> Bool) {
        annotations.removeAll(where: predicate)
    }
    
    internal func clearAnnotations() {
        annotations.removeAll()
    }
    
    /// Annotation views mapping
    internal var annotationViews: [String: PlatformView] = [:]
    
    /// The data source for providing custom annotations
    public weak var annotationsDataSource: AnnotationsDataSource?
    
    // MARK: - Completion System
    
    /// Completion manager for handling multiple completion providers
    internal let completionManager = CompletionManager()
    
    /// Current completion view controller
    internal var completionViewController: (any CompletionViewControllerRepresentable)?
    
    /// Completion popup window/container
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    internal var completionWindow: NSWindow?
    #else
    internal var completionPopover: PlatformViewController?
    #endif
    
    /// Whether completion is currently active
    internal var isCompletionActive: Bool = false
    
    /// Completion trigger characters for the current language
    internal var completionTriggerCharacters: Set<Character> = [".", "(", "[", "<", " "]
    
    // MARK: - Initialization
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    override public init(frame frameRect: NSRect) {
        // Use default NSTextView initialization - don't create custom text container
        // The custom text container creation was breaking text rendering
        Self.logger.debug("CodeEditorView init: frame = \(String(describing: frameRect))")
        
        // Use default NSTextView initialization
        // NSTextView should automatically use TextKit2 on supported systems
        super.init(frame: frameRect)
        setupTextView()
    }
    #else
    override public init(frame frameRect: CGRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    public convenience init(frame frameRect: CGRect) {
        // Use default UITextView initialization
        Self.logger.debug("CodeEditorView init: frame = \(String(describing: frameRect))")
        self.init(frame: frameRect, textContainer: nil)
    }
    #endif
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Unregister from memory monitor (schedule on main actor)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            var hasher = Hasher()
            hasher.combine(ObjectIdentifier(self))
            let identifier = "CodeEditorView_\(hasher.finalize())"
            Task { @MainActor in
                MemoryMonitor.shared.unregisterCleanupHandler(identifier: identifier)
            }
        }
        
        // Note: We cannot perform MainActor-isolated cleanup in deinit
        // The cleanup of UI elements will happen automatically when the view is deallocated
        // Subviews are automatically removed from their superview when deallocated
    }
}
