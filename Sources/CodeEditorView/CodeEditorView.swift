import CodeEditorAnnotations
import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorLayout
import CodeEditorLSP
import CodeEditorPlatform
import CodeEditorSyntaxHighlighting
import CodeEditorTextModel
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
/// try editor.apply(configuration: config)
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
open class CodeEditorView: PlatformTextView, NSTextLayoutManagerDelegate, CodeEditorAPI, CompletionViewControllerDelegate, @unchecked Sendable {
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

    /// The sole owner of `textView.delegate` for this view.
    ///
    /// Every framework-internal feature that wants delegate hooks (host
    /// proxy, smart editing, iOS scroll forwarding, iOS SwiftUI
    /// coordinator) registers as a `TextViewDelegateParticipant` via
    /// `addDelegateParticipant(_:phase:)`. The `textView.delegate` slot
    /// itself is set to this object during `TextKitSetupHelper.setupTextKit`
    /// and never re-assigned. See the named-commit invariant block in
    /// this file for the structural rule.
    internal let delegateMultiplexer = TextViewDelegateMultiplexer()

    /// Register a participant with the delegate multiplexer.
    ///
    /// - Parameters:
    ///   - participant: An object conforming to `TextViewDelegateParticipant`.
    ///     Held weakly; the caller owns its lifetime.
    ///   - phase: `.gating` for host-style gating (one slot, used by the
    ///     `CodeEditorViewDelegateProxy`); `.behavior` for smart-editing
    ///     interception, scroll forwarding, and SwiftUI coordinator
    ///     state mirroring. Defaults to `.behavior`.
    package func addDelegateParticipant(
        _ participant: any TextViewDelegateParticipant,
        phase: TextViewDelegatePhase = .behavior
    ) {
        delegateMultiplexer.addParticipant(participant, phase: phase)
    }

    /// Remove a participant from the delegate multiplexer. Idempotent —
    /// removing an unregistered participant is a no-op.
    package func removeDelegateParticipant(
        _ participant: any TextViewDelegateParticipant
    ) {
        delegateMultiplexer.removeParticipant(participant)
    }

    /// Event publisher for unified event handling
    public let eventPublisher = EditorEventPublisher()

    /// Compatibility adapters sourced from the runtime's canonical event bus.
    internal var legacyEventBus: EditorEventBus?
    internal var legacyEventObservation: EditorEventObservation?
    internal var notificationCenterEventAdapter: NotificationCenterEventAdapter?

    /// Optional lifecycle injected by package tests or alternate hosts.
    private var sessionOverride: (any EditorSessionLifecycle)?

    /// Runtime composition root for services that are not configuration values.
    public var runtime = EditorRuntime() {
        didSet {
            guard runtime !== oldValue else { return }
            memoryCoordinator.updateMemoryMonitor(runtime.dependencies.memoryMonitor)
            memoryCoordinator.updatePolicy(runtime.dependencies.memoryManagementPolicy)
            #if canImport(AppKit)
            lspManager.workspaceRoot = runtime.dependencies.workspaceRoot
            #endif
            applyConfiguration()
        }
    }

    // Note: We intentionally do **not** stand up a custom NSTextContentStorage/
    // NSTextLayoutManager network here, nor override `textLayoutManager`.
    // NSTextView constructs its own TextKit 2 network when initialized via
    // `super.init(frame:)`, and key-input plumbing (NSTextInputContext →
    // `insertText:replacementRange:` → `shouldChangeTextIn` delegate) only
    // wires through that internally-owned network. A previous refactor
    // (fc96866) replaced it with a hand-rolled network; the result was that
    // `keyDown` still fired but `shouldChangeTextIn` never did, so the
    // editor accepted clicks and selections but rejected typed input. If
    // you ever need access to the live managers, read them via the standard
    // accessors (`self.textLayoutManager`, `self.textContentStorage`).
    //
    // Critically, **do not read `self.textStorage` directly** anywhere in
    // setup or steady-state code. Reading `NSTextView.textStorage` on a
    // TK2-initialized view triggers Apple's TK1 compatibility shim and
    // clears `textLayoutManager`. The framework funnels every text access
    // through `self.textKitBridge` (lazily-constructed `TextKitBridge`),
    // which routes via `textContentStorage?.textStorage` — the TK2-safe
    // accessor. The same applies to `self.layoutManager`: it returns the
    // TK1 NSLayoutManager and reading it coerces the view to TK1 mode.
    //
    // The load-bearing invariant — `textLayoutManager != nil` after init
    // — is covered by
    // `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`.
    // If that test fails, a new `self.textStorage` or `self.layoutManager`
    // read has been re-introduced somewhere on the setup path. The
    // NSRulerView-based gutter at
    // `Layout/CodeEditorContainerView+AppKitExtensions.swift:drawHashMarksAndLabels(in:)`
    // is a known TK1 island and is not covered by the canary; rewriting
    // that draw path against `NSTextLayoutManager` is its own follow-up.
    //
    // **Delegate ownership invariant.** `textView.delegate` is owned
    // exclusively by `TextViewDelegateMultiplexer`, installed during
    // `TextKitSetupHelper.setupTextKit`. Features that need delegate
    // hooks (host proxy, smart editing, iOS scroll forwarding, iOS
    // SwiftUI coordinator) register via
    // `addDelegateParticipant(_:phase:)` — never by assigning to
    // `textView.delegate` directly. The SwiftLint custom rule
    // `forbidden_text_view_delegate_assignment` enforces this at lint
    // time; `TextKitSetupHelper.swift` is its only exemption. See
    // `docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md`
    // for the full design.

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

    /// Async syntax highlighter with debouncing.
    internal lazy var asyncHighlighter = memoryCoordinator.createAsyncHighlighter() {
        didSet {
            highlightingController.replaceCancellation(with: asyncHighlighter)
        }
    }

    /// Feature controller that owns highlighting attachment and teardown.
    internal lazy var highlightingController = HighlightingController(
        cancellation: asyncHighlighter
    )

    /// Feature controllers composed under the default editor session.
    internal lazy var completionController = EditorCompletionController(
        cancellation: completionManager
    )
    internal lazy var foldingController = EditorFoldingController(
        lifecycle: codeFoldingEngine
    )
    internal lazy var lspDocumentController = LSPDocumentController()
    private lazy var defaultSession = EditorSession(
        features: [
            highlightingController,
            completionController,
            foldingController,
            lspDocumentController
        ]
    )
    package var session: any EditorSessionLifecycle {
        sessionOverride ?? defaultSession
    }

    /// Metrics captured from actual TextKit 2 layout passes.
    public let renderingMetrics = TextKit2RenderingMetrics()

    /// LSP manager for language server integration
    #if canImport(AppKit)
    internal lazy var lspManager = memoryCoordinator.createLSPManager(workspaceRoot: runtime.dependencies.workspaceRoot)

    /// Document-scoped LSP synchronization owned by the session controller.
    internal var lspContentCoordinator: LSPContentCoordinator? {
        lspDocumentController.concreteContentCoordinator
    }

    /// LSP semantic-token provider retained by the editor so it can be
    /// registered when the range-based highlighting controller is created.
    internal var lspSemanticTokenProvider: LSPSemanticTokenProvider? {
        lspDocumentController.semanticTokenProvider
    }
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
    package lazy var adaptivePerformanceMode = AdaptivePerformanceMode(memoryMonitor: memoryMonitor)

    /// Incremental line geometry store — red-black tree of per-line UTF-16
    /// lengths, heights, and cumulative subtree metadata. Supports O(log n)
    /// lookup by offset, line index, and y-position. Built from
    /// `NSTextStorage` using `NSString` line enumeration for UTF-16
    /// correctness.
    internal let lineGeometryStore = LineGeometryStore()

    /// Shared TextKit 2 access surface for this view. Every framework
    /// read/write of the editor's text content must go through this bridge
    /// instead of `self.textStorage`. Reading `NSTextView.textStorage`
    /// directly on a TK2-initialized view triggers Apple's TK1 compatibility
    /// shim and clears `textLayoutManager`; the bridge routes through
    /// `textContentStorage?.textStorage`, which is the TK2-safe accessor.
    ///
    /// See `Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`
    /// for the load-bearing invariant.
    package lazy var textKitBridge = TextKitBridge(textView: self)

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
    internal var rangeBasedHighlightingController: RangeBasedHighlightingController? {
        get { highlightingController.rangeBasedController }
        set { highlightingController.rangeBasedController = newValue }
    }

    internal var rangeBasedHighlightingStyleDataSourceForTesting: (any MinimapStyleDataSource)? {
        highlightingController.styleDataSource
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

            // Built-in keyword provider tracks the current language; the
            // call is idempotent and sweeps any prior-language built-in.
            completionManager.ensureBuiltInProvider(for: language)
        }
    }

    /// Gutter view for line numbers
    internal var gutterViewStorage: GutterView?

    /// Tracks the line count last shown in the gutter so we can skip
    /// invalidating it on intra-line edits. Updated from
    /// `handleTextStorageDidProcessEditing` (see C1 perf fix).
    internal var lastGutterLineCount: Int = -1

    /// Weak back-pointer to the coordinator that mounted this view. Set
    /// during `CodeEditorBaseCoordinator.setupContainer` so host-facing
    /// controller methods (`EditorController.markClean()`) can route
    /// through the coordinator that owns the dirty tracker.
    ///
    /// Typed as `CodeEditorCoordinating` so this target doesn't depend on
    /// the umbrella's SwiftUI slice (which would invert the build-graph
    /// dep direction). The concrete `CodeEditorBaseCoordinator` conforms.
    package weak var coordinator: CodeEditorCoordinating?

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

    /// The data source for providing custom annotations.
    ///
    /// - Important: This is a **weak** reference. The host (typically an
    ///   `@Observable` app model or a SwiftUI host like `EditorController`)
    ///   must retain the data source itself; if no other strong reference
    ///   exists, the data source will deallocate and annotations will
    ///   silently stop appearing.
    public weak var annotationsDataSource: AnnotationsDataSource?

    // MARK: - Completion System

    /// Completion manager for handling multiple completion providers
    package lazy var completionManager = memoryCoordinator.createCompletionManager() {
        didSet {
            completionController.replaceCancellation(with: completionManager)
        }
    }

    /// Current completion view controller
    internal var completionViewController: (any CompletionViewControllerRepresentable)? {
        get { completionController.viewController }
        set { completionController.viewController = newValue }
    }

    /// Completion popup window/container
    #if canImport(AppKit)
    internal var completionWindow: NSWindow? {
        get { completionController.window }
        set { completionController.window = newValue }
    }
    #else
    internal var completionPopover: PlatformViewController? {
        get { completionController.popover }
        set { completionController.popover = newValue }
    }
    #endif

    /// Whether completion is currently active
    internal var isCompletionActive: Bool {
        get { completionController.isActive }
        set { completionController.isActive = newValue }
    }

    /// Completion trigger characters for the current language
    internal var completionTriggerCharacters: Set<Character> {
        get { completionController.triggerCharacters }
        set { completionController.triggerCharacters = newValue }
    }

    /// Memory management coordinator
    internal lazy var memoryCoordinator = MemoryManagementCoordinator(
        memoryMonitor: memoryMonitor,
        policy: runtime.dependencies.memoryManagementPolicy,
        editorView: self
    )

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
    package init(frame frameRect: NSRect, session: any EditorSessionLifecycle) {
        super.init(frame: frameRect)
        sessionOverride = session
        setupTextView()
    }

    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }

    override public init(frame frameRect: NSRect) {
        Self.logger.debug("CodeEditorView init: frame = \(String(describing: frameRect))")
        // Default NSTextView initialization — NSTextView constructs its own
        // TextKit 2 network (NSTextContentStorage + NSTextLayoutManager +
        // NSTextContainer) and wires it into the text-input pipeline so
        // `interpretKeyEvents` → `insertText:` → `shouldChangeTextIn` flows
        // through correctly. A previous refactor (fc96866) tried to construct
        // the network manually and pass the container to `super.init`, which
        // detached input handling from NSTextView's internal references — the
        // editor accepted clicks (selection worked) but rejected typing.
        super.init(frame: frameRect)
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
        runtime.replace(featureDependencies: featureDependencies)
        if let memoryMonitor {
            self.memoryMonitor = memoryMonitor
        }
    }
    #else
    package init(frame frameRect: CGRect, session: any EditorSessionLifecycle) {
        super.init(frame: frameRect, textContainer: nil)
        sessionOverride = session
        setupTextView()
    }

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
        runtime.replace(featureDependencies: featureDependencies)
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
        session.detach()
        unregisterFromMemoryMonitor()

        // Cancel any pending layout operations
        layoutCoordinator.cancelPendingLayout()

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

        // Highlighting tasks cancel when their owning highlighter deinitializes.
        // Memory monitor cleanup is handled in removeFromSuperview to avoid
        // creating tasks from deinit.
    }

    // MARK: - Private Methods

    /// Updates memory monitor references in all dependent components
}
