import Foundation
import ObjectiveC

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - CodeEditorView

/// A powerful, cross-platform text view designed specifically for code editing.
///
/// `CodeEditorView` provides advanced features for code editing including:
/// - **Syntax highlighting** with support for 25 concrete programming languages plus plain text
/// - **Code completion** with LSP integration and custom providers
/// - **Line numbers** with customizable gutter display
/// - **Annotations** for displaying TODOs, FIXMEs, and custom markers
/// - **Cross-platform support** for native macOS and iOS / iPadOS
/// - **Modern TextKit2** integration (TextKit2-only since 0.2.0)
/// - **Configurable appearance** with themes and layout options
/// - **Performance optimization** for large files and real-time editing
///
/// ## Basic Usage
///
/// ```swift
/// let editor = CodeEditorView()
/// editor.string = "func hello() {\n    print(\"Hello, World!\")\n}"
/// editor.language = .swift
/// editor.isLineNumbersEnabled = true
/// editor.isCodeCompletionEnabled = true
/// ```
///
/// ## Memory Monitoring
///
/// CodeEditorView supports dependency injection for memory monitoring:
///
/// ```swift
/// // Use default memory monitor (created internally)
/// let editor = CodeEditorView()
/// 
/// // Or inject a shared memory monitor for multiple views
/// let sharedMonitor = MemoryMonitor()
/// let editor1 = CodeEditorView()
/// let editor2 = CodeEditorView()
/// editor1.memoryMonitor = sharedMonitor
/// editor2.memoryMonitor = sharedMonitor
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
/// config.behavior.isAutoIndentEnabled = true
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
///     serverPath: "sourcekit-lsp"  // Will be resolved automatically
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
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
@objc @MainActor
open class CodeEditorView: PlatformTextView, NSTextLayoutManagerDelegate, CodeEditorAPI, CompletionViewControllerDelegate {
    // MARK: - Static Properties

    /// Logger instance for CodeEditorView
    internal static let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorView")

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

    /// Runtime composition root for services that are not configuration values.
    public var runtime = EditorRuntime() {
        didSet {
            guard runtime !== oldValue else { return }
            memoryCoordinator.updateMemoryMonitor(runtime.dependencies.memoryMonitor)
            #if canImport(AppKit)
            lspManager.workspaceRoot = runtime.dependencies.workspaceRoot
            #endif
            applyConfiguration()
        }
    }

    #if canImport(AppKit)
    /// Retains the TextKit2 content manager backing the AppKit text network.
    private var textKit2ContentStorage: NSTextContentStorage?

    /// Retains the TextKit2 layout manager backing the AppKit text network.
    private var textKit2LayoutManager: NSTextLayoutManager?

    override public var textLayoutManager: NSTextLayoutManager? {
        textKit2LayoutManager ?? super.textLayoutManager
    }
    #endif

    /// Explicit feature dependencies used by view models and live editor behavior.
    internal var featureDependencies: EditorFeatureRuntimeDependencies {
        runtime.featureDependencies
    }

    /// Layout coordinator to prevent recursive layout
    internal lazy var layoutCoordinator = LayoutCoordinator(view: self)

    /// Flag to prevent recursive configuration updates
    internal var isApplyingConfiguration = false

    /// The configuration object that controls all aspects of the editor's behavior and appearance
    public var configuration: EditorConfiguration = .default {
        didSet {
            guard !isApplyingConfiguration else { return }

            do {
                try configuration.validateAndThrow()
            } catch {
                Self.logger.error("[CodeEditorPlugin] Rejected invalid configuration: \(error)")
                isApplyingConfiguration = true
                configuration = oldValue
                isApplyingConfiguration = false
                return
            }

            if configuration != oldValue {
                isApplyingConfiguration = true
                applyConfiguration()
                isApplyingConfiguration = false
            }
        }
    }

    /// The syntax highlighting coordinator
    internal let syntaxHighlighter = SyntaxHighlightingCoordinator()

    /// Async syntax highlighter with debouncing
    internal lazy var asyncHighlighter = memoryCoordinator.createAsyncHighlighter()

    /// TextKit2 rendering optimizer for large files
    internal lazy var renderingOptimizer = memoryCoordinator.createRenderingOptimizer()

    /// TextKit2 performance monitor
    internal let performanceMonitor = TextKit2PerformanceMonitor()

    /// LSP manager for language server integration
    #if canImport(AppKit)
    internal lazy var lspManager = memoryCoordinator.createLSPManager(workspaceRoot: runtime.dependencies.workspaceRoot)

    /// LSP content coordinator — batches edit events into `textDocument/didChange`
    /// notifications with ~250 ms debounce. Created by `setupLSPIntegration()`
    /// when a document path and language are available.
    internal var lspContentCoordinator: LSPContentCoordinator?

    /// LSP semantic-token provider retained by the editor so it can be
    /// registered when the range-based highlighting controller is created.
    internal var lspSemanticTokenProvider: LSPSemanticTokenProvider?
    #endif

    /// Code folding engine for managing foldable regions and fold states
    internal let codeFoldingEngine = CodeFoldingEngine()

    /// Search and replace engine. Stored on the view so find-next and find-previous
    /// operate on the same result set created by the latest search.
    public lazy var searchEngine: SearchReplaceEngine = {
        let engine = SearchReplaceEngine()
        engine.attach(to: self)
        return engine
    }()

    /// Adaptive performance mode manager
    internal lazy var adaptivePerformanceMode = AdaptivePerformanceMode(memoryMonitor: memoryMonitor)

    /// Incremental line geometry store — red-black tree of per-line UTF-16
    /// lengths, heights, and cumulative subtree metadata. Supports O(log n)
    /// lookup by offset, line index, and y-position. Built from
    /// `NSTextStorage` using `NSString` line enumeration for UTF-16
    /// correctness.
    internal let lineGeometryStore = LineGeometryStore()

    /// Handler that keeps `lineGeometryStore` in sync with `NSTextStorage`
    /// after text edits. Registered with `textEditEventHub` during setup.
    internal var lineGeometryEditHandler: LineGeometryEditHandler?

    /// Text edit event hub for broadcasting edit notifications to observers.
    /// Consumers (RangeStore sync, highlighting, folding, gutter) subscribe
    /// to receive canonical edit events instead of watching `NSTextStorage`
    /// notifications independently.
    internal let textEditEventHub = TextEditEventHub()

    /// Range-store-backed highlighting pipeline used by opt-in visible-range
    /// invalidation and minimap style data.
    internal var rangeBasedHighlightingController: RangeBasedHighlightingController?

    internal var rangeBasedHighlightingStyleDataSourceForTesting: (any MinimapStyleDataSource)? {
        rangeBasedHighlightingController?.styleDataSource
    }

    /// Memory monitor for tracking and managing memory usage
    /// 
    /// Set this property to provide a custom memory monitor instance or to share
    /// a single monitor across multiple editor views. If not set, the editor uses
    /// the configured `swift-dependencies` factory.
    /// 
    /// When changed, all subsystems that use the memory monitor are automatically updated.
    /// 
    /// ## Example
    /// 
    /// ```swift
    /// // Share a monitor across multiple editors
    /// let sharedMonitor = MemoryMonitor()
    /// sharedMonitor.memoryThresholdMB = 200.0
    /// 
    /// let editor1 = CodeEditorView()
    /// editor1.memoryMonitor = sharedMonitor
    /// 
    /// let editor2 = CodeEditorView() 
    /// editor2.memoryMonitor = sharedMonitor
    /// ```
    public var memoryMonitor: MemoryMonitor {
        get {
            runtime.dependencies.memoryMonitor
        }
        set {
            guard newValue !== runtime.dependencies.memoryMonitor else { return }
            runtime.update(memoryMonitor: newValue)
            memoryCoordinator.updateMemoryMonitor(newValue)
        }
    }

    /// The current programming language used for syntax highlighting and code completion.
    /// 
    /// When the language is changed:
    /// - Syntax highlighting is automatically reapplied with the new language rules
    /// - Code completion trigger characters are updated for the new language
    /// - Any existing highlighting is cleared and regenerated
    /// 
    /// - Note: Changing the language may cause a brief visual update as highlighting is reprocessed
    public var language: Language = .plainText {
        didSet {
            let languageService = featureDependencies.languageDetectionService
            let validation = languageService.validateLanguageChange(from: oldValue, to: language)

            if validation != .noChange {
                applySyntaxHighlighting()
                updateCompletionTriggerCharacters()
            }
        }
    }

    /// Gutter view for line numbers
    internal var gutterViewStorage: GutterView?

    /// Tracks the line count last shown in the gutter so we can skip
    /// invalidating it on intra-line edits. Updated from
    /// `handleTextStorageDidProcessEditing` (see C1 perf fix).
    internal var lastGutterLineCount: Int = -1

    /// Line highlight view
    internal var lineHighlightView: PlatformView?

    /// Weak reference to the container view to avoid fragile superview traversal
    internal weak var containerView: CodeEditorContainerView?

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
    internal lazy var completionManager = memoryCoordinator.createCompletionManager()

    /// Current completion view controller
    internal var completionViewController: (any CompletionViewControllerRepresentable)?

    /// Completion popup window/container
    #if canImport(AppKit)
    internal var completionWindow: NSWindow?
    #else
    internal var completionPopover: PlatformViewController?
    #endif

    /// Whether completion is currently active
    internal var isCompletionActive: Bool = false

    /// Completion trigger characters for the current language
    internal var completionTriggerCharacters: Set<Character> = [".", "(", "[", "<", " "]

    /// Memory management coordinator
    internal lazy var memoryCoordinator = MemoryManagementCoordinator(memoryMonitor: memoryMonitor, editorView: self)

    #if canImport(AppKit)
    override public var string: String {
        get {
            super.string
        }
        set {
            super.string = newValue
            rebuildLineGeometryStoreFromCurrentTextStorage()
        }
    }
    #else
    // swiftlint:disable:next implicitly_unwrapped_optional
    override public var text: String! {
        get {
            super.text
        }
        set {
            super.text = newValue
            rebuildLineGeometryStoreFromCurrentTextStorage()
        }
    }

    // swiftlint:disable:next implicitly_unwrapped_optional
    override public var attributedText: NSAttributedString! {
        get {
            super.attributedText
        }
        set {
            super.attributedText = newValue
            rebuildLineGeometryStoreFromCurrentTextStorage()
        }
    }
    #endif

    // MARK: - Initialization

    #if canImport(AppKit)
    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        let textKit2Network = Self.makeTextKit2Network(frame: frameRect, textContainer: container)
        super.init(frame: frameRect, textContainer: textKit2Network.textContainer)
        textKit2ContentStorage = textKit2Network.contentStorage
        textKit2LayoutManager = textKit2Network.layoutManager
        setupTextView()
    }

    override public init(frame frameRect: NSRect) {
        Self.logger.debug("CodeEditorView init: frame = \(String(describing: frameRect))")
        let textKit2Network = Self.makeTextKit2Network(frame: frameRect, textContainer: nil)
        super.init(frame: frameRect, textContainer: textKit2Network.textContainer)
        textKit2ContentStorage = textKit2Network.contentStorage
        textKit2LayoutManager = textKit2Network.layoutManager
        setupTextView()
    }

    /// Initializes CodeEditorView with a custom memory monitor
    /// - Parameters:
    ///   - frameRect: The frame rectangle for the view
    ///   - memoryMonitor: Custom memory monitor for resource management
    public convenience init(frame frameRect: NSRect, memoryMonitor: MemoryMonitor) {
        self.init(frame: frameRect)
        self.memoryMonitor = memoryMonitor
    }

    /// Initializes CodeEditorView with custom feature dependencies.
    /// - Parameters:
    ///   - frameRect: The frame rectangle for the view
    ///   - featureDependencies: Feature dependencies for editor view models
    ///   - memoryMonitor: Optional custom memory monitor for resource management
    public convenience init(
        frame frameRect: NSRect,
        featureDependencies: EditorFeatureRuntimeDependencies,
        memoryMonitor: MemoryMonitor? = nil
    ) {
        self.init(frame: frameRect)
        runtime.update(featureDependencies: featureDependencies)
        if let memoryMonitor {
            self.memoryMonitor = memoryMonitor
        }
    }

    private static func makeTextKit2Network(
        frame frameRect: NSRect,
        textContainer providedContainer: NSTextContainer?
    ) -> (
        textContainer: NSTextContainer,
        contentStorage: NSTextContentStorage,
        layoutManager: NSTextLayoutManager
    ) {
        let contentStorage = NSTextContentStorage()
        contentStorage.textStorage = NSTextStorage()

        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)

        let textContainer = providedContainer ?? NSTextContainer(size: frameRect.size)
        layoutManager.textContainer = textContainer

        return (textContainer, contentStorage, layoutManager)
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

    /// Initializes CodeEditorView with a custom memory monitor
    /// - Parameters:
    ///   - frameRect: The frame rectangle for the view
    ///   - memoryMonitor: Custom memory monitor for resource management
    public convenience init(frame frameRect: CGRect, memoryMonitor: MemoryMonitor) {
        self.init(frame: frameRect)
        self.memoryMonitor = memoryMonitor
    }

    /// Initializes CodeEditorView with custom feature dependencies.
    /// - Parameters:
    ///   - frameRect: The frame rectangle for the view
    ///   - featureDependencies: Feature dependencies for editor view models
    ///   - memoryMonitor: Optional custom memory monitor for resource management
    public convenience init(
        frame frameRect: CGRect,
        featureDependencies: EditorFeatureRuntimeDependencies,
        memoryMonitor: MemoryMonitor? = nil
    ) {
        self.init(frame: frameRect)
        runtime.update(featureDependencies: featureDependencies)
        if let memoryMonitor {
            self.memoryMonitor = memoryMonitor
        }
    }
    #endif

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }

    override public func removeFromSuperview() {
        // Perform synchronous cleanup before removing from superview
        // The async highlighter will handle its own cleanup in deinit if needed
        asyncHighlighter.cleanup()
        unregisterFromMemoryMonitor()

        // Cancel any pending layout operations
        layoutCoordinator.cancelPendingLayout()

        // Cancel any pending completion requests
        completionManager.cancelCurrentRequest()

        // Clean up code folding - no cleanup method available
        rangeBasedHighlightingController?.detach()
        rangeBasedHighlightingController = nil

        #if canImport(AppKit)
        lspContentCoordinator?.detach()
        lspContentCoordinator = nil
        #endif

        // Clean up syntax highlighting
        Task {
            await syntaxHighlighter.cancelHighlighting()
        }

        // Remove any gutter view
        #if canImport(AppKit)
        gutterViewStorage?.removeFromSuperview()
        #endif

        // Clear delegate to break potential retain cycles
        delegate = nil

        super.removeFromSuperview()
    }

    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)

        // Note: Memory monitor cleanup is now handled in removeFromSuperview
        // to avoid creating tasks in deinit
    }

    // MARK: - Private Methods

    /// Updates memory monitor references in all dependent components
}
