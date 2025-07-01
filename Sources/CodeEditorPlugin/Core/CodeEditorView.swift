import Foundation
import ObjectiveC
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// Local logger instance for CodeEditorView
private let kLogger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorView")

// MARK: - CodeEditorView

/// A powerful, cross-platform text view designed specifically for code editing.
///
/// `CodeEditorView` provides advanced features for code editing including:
/// - **Syntax highlighting** with support for 15+ programming languages
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
    // CodeEditorViewProtocol conformance  
    public typealias Color = PlatformColor
    public typealias Font = PlatformFont
    public typealias Delegate = CodeEditorViewDelegate

    // We'll use NSTextView's built-in notifications instead of overriding them

    // MARK: - Properties

    /// Custom delegate for CodeEditorView-specific functionality
    public weak var textDelegate: (any CodeEditorViewDelegate)? {
        get {
            delegateProxy.source
        }
        set {
            delegateProxy.source = newValue
        }
    }

    /// Proxy for delegate calls
    let delegateProxy = CodeEditorViewDelegateProxy(source: nil)
    
    /// Event publisher for unified event handling
    public let eventPublisher = EditorEventPublisher()
    
    /// Layout coordinator to prevent recursive layout
    private lazy var layoutCoordinator = LayoutCoordinator(view: self)
    
    /// Editor configuration
    public var configuration: EditorConfiguration = .default {
        didSet {
            applyConfiguration()
            // Configuration changes can be handled through property observation
        }
    }

    /// The syntax highlighting coordinator
    private let syntaxHighlighter = SyntaxHighlightingCoordinator()
    
    /// Async syntax highlighter with debouncing
    private let asyncHighlighter = AsyncSyntaxHighlighter()
    
    /// TextKit2 rendering optimizer for large files
    private let renderingOptimizer = TextKit2RenderingOptimizer()
    
    /// TextKit2 performance monitor
    private let performanceMonitor = TextKit2PerformanceMonitor()
    
    /// LSP manager for language server integration
    private let lspManager = LSPManager()

    /// Current programming language for syntax highlighting
    public var language: Language = .plainText {
        didSet {
            if language != oldValue {
                applySyntaxHighlighting()
            }
        }
    }

    /// Enable/disable syntax highlighting (convenience property)
    public var isSyntaxHighlightingEnabled: Bool {
        get { configuration.display.enableSyntaxHighlighting }
        set {
            var display = configuration.display
            display.enableSyntaxHighlighting = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether line numbers are shown (convenience property)
    public var showsLineNumbers: Bool {
        get { configuration.display.showLineNumbers }
        set {
            var display = configuration.display
            display.showLineNumbers = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether the current line is highlighted (convenience property)
    public var highlightSelectedLine: Bool {
        get { configuration.display.highlightSelectedLine }
        set {
            var display = configuration.display
            display.highlightSelectedLine = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// The color for highlighting the selected line
    public var selectedLineHighlightColor = PlatformColor.selectedLineHighlight {
        didSet {
            updateSelectedLineHighlight()
        }
    }

    /// Controls whether invisible characters are shown (convenience property)
    public var showsInvisibleCharacters: Bool {
        get { configuration.display.showInvisibleCharacters }
        set {
            var display = configuration.display
            display.showInvisibleCharacters = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Gutter view for line numbers
    private var _gutterView: GutterView?

    /// Line highlight view
    private var lineHighlightView: PlatformView?

    /// Annotations storage
    public private(set) var annotations: [Annotation] = []

    /// Annotation views mapping
    private var annotationViews: [String: PlatformView] = [:]

    /// Annotations data source
    public weak var annotationsDataSource: AnnotationsDataSource?

    // MARK: - Completion System
    
    /// Completion manager for handling multiple completion providers
    private let completionManager = CompletionManager()
    
    /// Current completion view controller
    private var completionViewController: (any CompletionViewControllerProtocol)?
    
    /// Completion popup window/container
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private var completionWindow: NSWindow?
    #else
    private var completionPopover: PlatformViewController?
    #endif
    
    /// Whether completion is currently active
    private var isCompletionActive: Bool = false
    
    /// Whether completion should be enabled
    public var isCompletionEnabled: Bool {
        get { configuration.behavior.enableCodeCompletion }
        set {
            var behavior = configuration.behavior
            behavior.enableCodeCompletion = newValue
            configuration = configuration.with(behavior: behavior)
        }
    }
    
    // MARK: - Improved Boolean Property Aliases (Consistent Naming)
    
    /// Improved alias for isSyntaxHighlightingEnabled (consistent with shows* pattern)
    public var showsSyntaxHighlighting: Bool {
        get { isSyntaxHighlightingEnabled }
        set { isSyntaxHighlightingEnabled = newValue }
    }
    
    /// Improved alias for highlightSelectedLine (consistent with shows* pattern)  
    public var showsSelectedLineHighlight: Bool {
        get { highlightSelectedLine }
        set { highlightSelectedLine = newValue }
    }
    
    /// Improved alias for isCompletionEnabled (consistent with enables* pattern)
    public var enablesCodeCompletion: Bool {
        get { isCompletionEnabled }
        set { isCompletionEnabled = newValue }
    }
    
    /// Completion trigger characters for the current language
    private var completionTriggerCharacters: Set<Character> = [".", "(", "[", "<", " "]

    // MARK: - Coordinate System

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// NSTextView requires flipped coordinates for proper text rendering
    nonisolated override public var isFlipped: Bool {
        true
    }
    #endif

    // MARK: - Initialization

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }

    override public init(frame frameRect: NSRect) {
        // Use default NSTextView initialization - don't create custom text container
        // The custom text container creation was breaking text rendering
        kLogger.debug("CodeEditorView init: frame = \(String(describing: frameRect))")

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
        kLogger.debug("CodeEditorView init: frame = \(String(describing: frameRect))")
        self.init(frame: frameRect, textContainer: nil)
    }
    #endif

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }

    private func setupTextView() {
        kLogger.debug("CodeEditorView setupTextView: Starting setup")
        kLogger.debug("CodeEditorView setupTextView: textStorage = exists")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        kLogger.debug("CodeEditorView setupTextView: layoutManager = \(self.layoutManager != nil ? "exists" : "nil")")
        #else
        kLogger.debug("CodeEditorView setupTextView: layoutManager = exists")
        #endif
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        kLogger.debug("CodeEditorView setupTextView: textContainer = \(self.textContainer != nil ? "exists" : "nil")")
        #else
        kLogger.debug("CodeEditorView setupTextView: textContainer = exists")
        #endif
        kLogger.debug("CodeEditorView setupTextView: textLayoutManager = \(self.textLayoutManager != nil ? "exists" : "nil")")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        kLogger.debug("CodeEditorView setupTextView: textContentStorage = \(self.textContentStorage != nil ? "exists" : "nil")")
        #endif
        
        // Check which TextKit version we're using
        if textLayoutManager != nil {
            kLogger.debug("CodeEditorView setupTextView: Using TextKit2")
        } else {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if layoutManager != nil {
                kLogger.debug("CodeEditorView setupTextView: Using TextKit1 (fallback)")
            } else {
                kLogger.debug("CodeEditorView setupTextView: WARNING - No layout manager detected!")
            }
            #else
            kLogger.debug("CodeEditorView setupTextView: Using TextKit1 (UITextView default)")
            #endif
        }
        
        // Try to ensure we're using TextKit2 if possible
        if textLayoutManager == nil && ModernTextKitHelper.shouldUseTextKit2 {
            kLogger.debug("CodeEditorView setupTextView: Attempting to initialize with TextKit2")
            // Force TextKit2 initialization if needed
            // This is a fallback - normally NSTextView should auto-initialize with TextKit2
        }

        // Set up the text view
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        
        // Enable undo
        allowsUndo = true
        
        // Set up delegate
        delegate = delegateProxy
        #else
        // UITextView configuration
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        
        // Set up delegate
        delegate = delegateProxy
        #endif

        // Set up text storage observation for syntax highlighting
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textStorage
        )
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textStorage
        )
        #endif

        // Set up selection change observation
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextViewDidChangeSelection(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
        #else
        // UITextView doesn't have a direct selection change notification
        // We'll handle this through the delegate instead
        #endif

        // Setup theme
        setupDefaultTheme()

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        ModernTextKitHelper.configureTextView(self)
        ModernTextKitHelper.applyPerformanceOptimizations(to: self)
        #endif
        
        // Ensure TextKit2 is used if available and beneficial
        let usingTextKit2 = ModernTextKitHelper.ensureTextKit2(for: self)
        kLogger.debug("CodeEditorView setupTextView: Using TextKit2: \(usingTextKit2)")

        // Ensure proper sizing and layout
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        if let textContainer = self.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
        #else
        // UITextView doesn't have these properties - it handles scrolling differently
        #endif

        // Make sure we have reasonable size constraints
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: 10_000, height: 10_000)
        #endif

        kLogger.debug("CodeEditorView setupTextView: Final frame = \(String(describing: self.frame))")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        kLogger.debug("CodeEditorView setupTextView: Final container size = \(String(describing: self.textContainer?.containerSize ?? NSSize(width: 0, height: 0)))")
        #else
        kLogger.debug("CodeEditorView setupTextView: Final container size = \(String(describing: self.textContainer.size))")
        #endif

        // Initial syntax highlighting
        applySyntaxHighlighting()
        
        // TODO: Set up completion providers
        // setupCompletionProviders()
        
        // TODO: Set up LSP integration
        // setupLSPIntegration()
        
        // TODO: Set up TextKit2 rendering optimization
        // setupTextKit2Optimization()
        
        // TODO: Register with memory monitor
        // registerWithMemoryMonitor()
    }

    // MARK: - Theme Setup

    private func setupDefaultTheme() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        backgroundColor = PlatformColors.textBackgroundColor
        textColor = PlatformColors.label
        font = PlatformFonts.monospacedSystemFont(ofSize: PlatformFonts.systemFontSize, weight: .regular)
        kLogger.debug("setupDefaultTheme: backgroundColor = \(String(describing: self.backgroundColor)), textColor = \(String(describing: self.textColor))")
        #endif
    }

    // MARK: - Syntax Highlighting

    @objc
    func handleTextStorageDidProcessEditing(_ notification: Notification) {
        guard let textStorage = notification.object as? NSTextStorage,
              textStorage === self.textStorage
        else {
            return
        }

        // Update gutter when text changes
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        _gutterView?.needsDisplay = true
        #else
        _gutterView?.setNeedsDisplay()
        #endif

        // Apply syntax highlighting to the edited range if enabled
        if configuration.display.enableSyntaxHighlighting {
            let editedRange = textStorage.editedRange
            if editedRange.location != NSNotFound {
                applySyntaxHighlighting(in: editedRange)
            }
        }
        
        // Publish text changed event
        let editedRange = textStorage.editedRange
        if editedRange.location != NSNotFound {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            eventPublisher.publish(.textDidChange(string))
            #else
            eventPublisher.publish(.textDidChange(text ?? ""))
            #endif
            
            // TODO: Check for completion triggering
            // checkForCompletionTrigger(at: editedRange)
            
            // TODO: Update LSP document context
            // updateLSPDocumentContext()
        }
    }

    private func applySyntaxHighlighting() {
        kLogger.debug("🎨 applySyntaxHighlighting called - enabled: \(self.isSyntaxHighlightingEnabled), language: \(self.language.name)")
        
        guard isSyntaxHighlightingEnabled else {
            kLogger.debug("❌ Syntax highlighting disabled, cancelling")
            asyncHighlighter.cancelAllHighlighting()
            return
        }
        
        kLogger.debug("✅ Scheduling syntax highlighting for language: \(self.language.name)")
        
        // Use async highlighting with debouncing
        asyncHighlighter.scheduleHighlighting(
            for: self,
            language: language,
            visibleRange: nil
        )
    }

    private func applySyntaxHighlighting(in range: NSRange) {
        guard range.location != NSNotFound else {
            return
        }
        
        guard isSyntaxHighlightingEnabled else {
            return
        }
        
        // For range-based highlighting, schedule with visible range
        asyncHighlighter.scheduleHighlighting(
            for: self,
            language: language,
            visibleRange: range
        )
    }

    private func removeSyntaxHighlighting() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = self.textStorage else { return }
        #else
        let textStorage = self.textStorage
        #endif

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)

        // Restore default text color
        textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColors.label, range: fullRange)
    }

    // MARK: - Code Completion
    
    /// Check if completion should be triggered after text editing
    private func checkForCompletionTrigger(at editedRange: NSRange) {
        guard isCompletionEnabled,
              editedRange.length <= 1 // Only trigger on single character insertion
        else {
            return
        }
        
        // Get current cursor position
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let cursorPosition = selectedRange.location
        let text = string
        #else
        let cursorPosition = selectedRange.location
        let text = self.text ?? ""
        #endif
        
        // Check if we just typed a trigger character
        if cursorPosition > 0 && cursorPosition <= text.count {
            let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
            let typedChar = text[index]
            
            if completionTriggerCharacters.contains(typedChar) {
                // Trigger completion with character trigger
                requestCompletion(triggerKind: .character, triggerCharacter: String(typedChar))
            }
        }
    }
    
    /// Request code completion at the current cursor position
    public func requestCompletion(triggerKind: CompletionTriggerKind = .manual, triggerCharacter: String? = nil) {
        guard isCompletionEnabled else { return }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let cursorPosition = selectedRange.location
        let text = string
        #else
        let cursorPosition = selectedRange.location
        let text = self.text ?? ""
        #endif
        
        // Extract current line text
        let lineRange = currentLineRange(at: cursorPosition)
        let lineText = String(text[lineRange])
        
        // Create completion context
        let context = CompletionContextModel(
            text: text,
            cursorPosition: cursorPosition,
            language: language,
            triggerKind: triggerKind,
            triggerCharacter: triggerCharacter,
            lineText: lineText,
            wordRange: currentWordRange(at: cursorPosition)
        )
        
        // Request completions asynchronously
        Task { @MainActor in
            do {
                let result = try await completionManager.requestCompletions(for: context)
                if !result.items.isEmpty {
                    showCompletionPopup(with: result.items, at: cursorPosition)
                }
            } catch {
                kLogger.error("Completion request failed: \(error)")
            }
        }
    }
    
    /// Show completion popup with the given items
    private func showCompletionPopup(with items: [CompletionItemModel], at position: Int) {
        // Cancel any existing completion
        hideCompletionPopup()
        
        // Get completion view controller from delegate or create default
        let completionVC = textDelegate?.textViewCompletionViewController(self) ?? CompletionViewController()
        
        // Set up completion view controller
        completionViewController = completionVC
        if let modernVC = completionVC as? CompletionViewController {
            modernVC.completionItems = items
            modernVC.delegate = self
        } else {
            // Handle legacy completion view controllers
            // Modern completion items need to be set through the protocol
        }
        
        // Position and show completion popup
        let cursorRect = cursorRectForPosition(position)
        showCompletionWindow(with: completionVC, at: cursorRect)
        
        isCompletionActive = true
    }
    
    /// Get cursor rectangle for positioning completion popup
    private func cursorRectForPosition(_ position: Int) -> CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textContainer = textContainer, let layoutManager = layoutManager else {
            return CGRect(x: 0, y: 0, width: 1, height: 16)
        }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: position, length: 0), actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        #else
        // UITextView cursor positioning
        guard let start = self.position(from: beginningOfDocument, offset: position),
              let end = self.position(from: start, offset: 0),
              let textRange = self.textRange(from: start, to: end) else {
            return CGRect(x: 0, y: 0, width: 1, height: 16)
        }
        return caretRect(for: textRange.start)
        #endif
    }
    
    /// Show completion window/popover at the specified rectangle
    private func showCompletionWindow(with viewController: any CompletionViewControllerProtocol, at rect: CGRect) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Create completion window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = viewController as NSViewController
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = PlatformColors.clear
        window.hasShadow = true
        
        // Position window relative to text view
        if let textWindow = self.window {
            let screenRect = textWindow.convertToScreen(convert(rect, to: nil))
            let windowRect = NSRect(
                x: screenRect.origin.x,
                y: screenRect.origin.y - 200, // Show below cursor
                width: 300,
                height: 200
            )
            window.setFrame(windowRect, display: true)
        }
        
        completionWindow = window
        window.orderFront(nil)
        #else
        // iOS popover presentation
        guard let presentingVC = findViewController() else { return }
        
        let popoverVC = viewController as UIViewController
        popoverVC.modalPresentationStyle = .popover
        
        if let popover = popoverVC.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = rect
            popover.permittedArrowDirections = [.up, .down]
        }
        
        completionPopover = popoverVC
        presentingVC.present(popoverVC, animated: true)
        #endif
    }
    
    /// Hide the completion popup
    public func hideCompletionPopup() {
        guard isCompletionActive else { return }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        completionWindow?.close()
        completionWindow = nil
        #else
        completionPopover?.dismiss(animated: true)
        completionPopover = nil
        #endif
        
        completionViewController = nil
        isCompletionActive = false
    }
    
    /// Handle keyboard input for completion navigation
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func keyDown(with event: NSEvent) {
        // Handle completion navigation
        if isCompletionActive, let completionVC = completionViewController {
            switch event.keyCode {
            case 125: // Down arrow
                if let modernVC = completionVC as? CompletionViewController {
                    modernVC.selectNext()
                    return
                }
            case 126: // Up arrow
                if let modernVC = completionVC as? CompletionViewController {
                    modernVC.selectPrevious()
                    return
                }
            case 36: // Return
                if let modernVC = completionVC as? CompletionViewController {
                    modernVC.insertSelectedItem()
                    return
                }
            case 53: // Escape
                hideCompletionPopup()
                return

            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
    #endif
    
    /// Get current line range at position
    private func currentLineRange(at position: Int) -> Range<String.Index> {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let text = string
        #else
        let text = self.text ?? ""
        #endif
        
        let pos = min(position, text.count)
        let textIndex = text.index(text.startIndex, offsetBy: pos)
        return text.lineRange(for: textIndex..<textIndex)
    }
    
    /// Get current word range at position
    private func currentWordRange(at position: Int) -> NSRange? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let text = string
        #else
        let text = self.text ?? ""
        #endif
        
        guard position <= text.count else { return nil }
        
        let textIndex = text.index(text.startIndex, offsetBy: position)
        let wordRange = text.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted, options: .backwards, range: text.startIndex..<textIndex)
        
        if let range = wordRange {
            let start = text.distance(from: text.startIndex, to: range.upperBound)
            let end = position
            return NSRange(location: start, length: end - start)
        }
        
        return nil
    }
    
    #if canImport(UIKit)
    /// Find the presenting view controller for iOS popover
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    #endif

    // MARK: - Line Numbers and Gutter

    public func updateGutterVisibility() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if showsLineNumbers {
            createGutterIfNeeded()
        } else {
            removeGutter()
        }
        #else
        // On iOS, gutter is handled by the container view
        #endif
    }

    private func createGutterIfNeeded() {
        guard _gutterView == nil else {
            return
        }

        // First update text container inset to make room for gutter
        let gutterWidth = configuration.layout.gutterWidth
        let padding = configuration.layout.lineNumberPadding
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textContainerInset = NSSize(width: gutterWidth + padding, height: textContainerInset.height)
        #else
        textContainerInset = UIEdgeInsets(top: textContainerInset.top, left: gutterWidth + padding, bottom: textContainerInset.bottom, right: textContainerInset.right)
        #endif

        let gutter = GutterView()
        gutter.textView = self
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        gutter.autoresizingMask = NSView.AutoresizingMask.height // Only resize height, not width
        #else
        gutter.autoresizingMask = [.flexibleHeight] // Only resize height, not width
        #endif

        // Add gutter directly to the text view since we might not be in a scroll view
        // Position it below the text content so it doesn't block text
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        addSubview(gutter, positioned: .below, relativeTo: nil)
        #else
        addSubview(gutter)
        sendSubviewToBack(gutter)
        #endif

        _gutterView = gutter
        updateGutterFrame()
    }

    private func removeGutter() {
        _gutterView?.removeFromSuperview()
        _gutterView = nil
        
        // Reset text container inset when gutter is removed
        let padding = configuration.layout.lineNumberPadding
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textContainerInset = NSSize(width: padding, height: textContainerInset.height)
        #else
        textContainerInset = UIEdgeInsets(top: textContainerInset.top, left: padding, bottom: textContainerInset.bottom, right: textContainerInset.right)
        #endif
    }

    private func updateGutterFrame() {
        guard let gutter = _gutterView else {
            return
        }

        layoutCoordinator.performLayout {
            // Use configuration values instead of magic numbers
            let gutterWidth = self.configuration.layout.gutterWidth
            _ = self.configuration.layout.lineNumberPadding
            
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            gutter.frame = NSRect(
                x: 0,
                y: 0,
                width: gutterWidth,
                height: self.bounds.height
            )
            #else
            // For iOS, the gutter should be positioned fixed and not scroll with content
            // It should be tall enough to show all visible line numbers
            gutter.frame = CGRect(
                x: 0,
                y: 0,
                width: gutterWidth,
                height: self.bounds.height
            )
            #endif

            // Text container inset is already set in createGutterIfNeeded
            // No need to update it here

            // Don't update text container size here - let NSTextView handle it

            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            gutter.needsDisplay = true
            #else
            gutter.setNeedsDisplay()
            #endif
        }
    }
    
    // MARK: - Configuration
    
    private func applyConfiguration() {
        // Apply display settings
        if configuration.display.showLineNumbers {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            updateGutterVisibility()
            #endif
        } else {
            removeGutter()
        }
        
        if configuration.display.highlightSelectedLine {
            updateSelectedLineHighlight()
        } else {
            removeLineHighlight()
        }
        
        if configuration.display.enableSyntaxHighlighting {
            applySyntaxHighlighting()
        } else {
            removeSyntaxHighlighting()
        }
        
        updateLayoutManagerSettings()
        
        // Apply behavior settings
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable
        #else
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable
        #endif
        
        // Force layout update
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsLayout = true
        #else
        setNeedsLayout()
        #endif
    }

    // MARK: - Line Highlighting

    @objc
    func handleTextViewDidChangeSelection(_ notification: Notification) {
        updateSelectedLineHighlight()

        // Forward to delegate
        delegateProxy.textViewDidChangeSelection(notification)

        // Post our own notification
        let stNotification = Notification(name: Self.stTextViewDidChangeSelectionNotification, object: self)
        NotificationCenter.default.post(stNotification)
        
        // Publish selection changed event
        eventPublisher.publish(.textSelectionDidChange(selectedRange))
    }

    private func updateSelectedLineHighlight() {
        guard highlightSelectedLine else {
            removeLineHighlight()
            return
        }

        createLineHighlightIfNeeded()
        updateLineHighlightFrame()
    }

    private func createLineHighlightIfNeeded() {
        guard lineHighlightView == nil else {
            return
        }

        let highlight = PlatformView()
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = selectedLineHighlightColor.cgColor
        #else
        highlight.layer.backgroundColor = selectedLineHighlightColor.cgColor
        #endif

        // Add as background overlay
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        addSubview(highlight, positioned: .below, relativeTo: nil)
        #else
        addSubview(highlight)
        sendSubviewToBack(highlight)
        #endif
        lineHighlightView = highlight
    }

    private func removeLineHighlight() {
        lineHighlightView?.removeFromSuperview()
        lineHighlightView = nil
    }

    private func updateLineHighlightFrame() {
        guard let highlightView = lineHighlightView else {
            return
        }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let selectedRange = selectedRange
        #else
        let selectedRange = selectedRange
        #endif
        guard selectedRange.location != NSNotFound else {
            return
        }

        // Get the line range for the selection
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let range = Range(selectedRange, in: string) else { return }
        let stringLineRange = string.lineRange(for: range)
        let lineRange = NSRange(stringLineRange, in: string)
        #else
        guard let text = self.text,
              let range = Range(selectedRange, in: text) else { return }
        let stringLineRange = text.lineRange(for: range)
        let lineRange = NSRange(stringLineRange, in: text)
        #endif

        // Get the rect for the line using TextKit2-compatible approach
        guard let lineRect = calculateLineRect(for: lineRange) else {
            return
        }

        // Adjust frame
        var frame = lineRect
        frame.origin.x = 0
        frame.size.width = bounds.width
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        frame.origin.y += textContainerInset.height
        #else
        frame.origin.y += textContainerInset.top
        #endif

        highlightView.frame = frame
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        highlightView.layer?.backgroundColor = selectedLineHighlightColor.cgColor
        #else
        highlightView.layer.backgroundColor = selectedLineHighlightColor.cgColor
        #endif
    }

    // MARK: - Layout Manager Settings

    private func updateLayoutManagerSettings() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        layoutManager?.showsInvisibleCharacters = showsInvisibleCharacters
        #else
        // UITextView's layout manager doesn't support showsInvisibleCharacters
        #endif
    }

    // MARK: - Annotations Support

    /// Add an annotation to the text view
    public func addAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        updateAnnotationView(for: annotation)
    }

    /// Remove an annotation from the text view
    public func removeAnnotation(withId id: String) {
        annotations.removeAll { $0.id == id }
        annotationViews[id]?.removeFromSuperview()
        annotationViews.removeValue(forKey: id)
    }

    /// Remove all annotations
    public func removeAllAnnotations() {
        annotations.removeAll()
        annotationViews.values.forEach { $0.removeFromSuperview() }
        annotationViews.removeAll()
    }

    /// Get all annotations
    public var allAnnotations: [Annotation] {
        annotations
    }

    private func updateAnnotationView(for annotation: Annotation) {
        kLogger.debug("updateAnnotationView called for annotation: \(annotation.id)")
        kLogger.debug("- annotation range: \(String(describing: annotation.range))")
        kLogger.debug("- annotation content: \(annotation.content)")
        kLogger.debug("- textLayoutManager exists: \(self.textLayoutManager != nil)")
        kLogger.debug("- annotationsDataSource exists: \(self.annotationsDataSource != nil)")
        
        // Remove existing view if any
        if let existingView = annotationViews[annotation.id] {
            kLogger.debug("Removing existing annotation view")
            existingView.removeFromSuperview()
        }

        // Create new annotation view using data source
        guard let dataSource = annotationsDataSource else {
            kLogger.debug("No annotations data source - annotation will not be displayed")
            return
        }

        // Check if we're using TextKit2
        guard let textLayoutManager = textLayoutManager else {
            kLogger.debug("No textLayoutManager (not using TextKit2?) - annotation will not be displayed")
            return
        }
        
        kLogger.debug("Using TextKit2 with textLayoutManager")
        
        // Convert Annotation to CodeEditorViewAnnotation
        let textViewAnnotation = CodeEditorViewAnnotation(
            location: annotation.range.location,
            content: annotation.content,
            id: annotation.id
        )

        // Ensure layout for the annotation range
        textLayoutManager.ensureLayout(for: annotation.range)
        kLogger.debug("ensureLayout completed for range")
        
        // Get text layout fragment for the annotation location
        guard let textLayoutFragment = textLayoutManager.textLayoutFragment(for: annotation.range.location) else {
            kLogger.debug("Could not get textLayoutFragment for location: \(String(describing: annotation.range.location))")
            return
        }
        kLogger.debug("Got textLayoutFragment")
        
        guard let textLineFragment = textLayoutFragment.textLineFragment(at: annotation.range.location) else {
            kLogger.debug("Could not get textLineFragment at location: \(String(describing: annotation.range.location))")
            return
        }
        kLogger.debug("Got textLineFragment")

        // Get the exact text segment frame for the annotation range
        guard let segmentFrame = textLayoutManager.textSegmentFrame(
            in: annotation.range,
            type: .standard
        ) else { 
            kLogger.debug("Could not get textSegmentFrame for range: \(String(describing: annotation.range))")
            return 
        }
        kLogger.debug("Got segmentFrame: \(String(describing: segmentFrame))")

        // Calculate inline annotation position using configuration values
        let badgeSize = configuration.layout.annotationBadgeSize
        let badgePadding = configuration.layout.annotationBadgePadding
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let inlineX = textContainerInset.width + segmentFrame.maxX + badgePadding
        let inlineY = textContainerInset.height + segmentFrame.midY - (badgeSize / 2)
        #else
        let inlineX = textContainerInset.left + segmentFrame.maxX + badgePadding
        let inlineY = textContainerInset.top + segmentFrame.midY - (badgeSize / 2)
        #endif
        
        let proposedFrame = CGRect(
            x: inlineX,
            y: inlineY,
            width: badgeSize,
            height: badgeSize
        ).integral
        
        kLogger.debug("Calculated proposedFrame: \(String(describing: proposedFrame))")
        kLogger.debug("textContainerInset: \(String(describing: self.textContainerInset))")

        // Create annotation view
        if let annotationView = dataSource.textView(
            self,
            viewForLineAnnotation: textViewAnnotation,
            textLineFragment: textLineFragment,
            proposedViewFrame: proposedFrame
        ) {
            kLogger.debug("Successfully created annotation view")
            kLogger.debug("Adding annotation view to subview hierarchy")
            kLogger.debug("Current view bounds: \(String(describing: self.bounds))")
            kLogger.debug("Current view subviews count: \(self.subviews.count)")
            
            addSubview(annotationView)
            annotationViews[annotation.id] = annotationView
            
            kLogger.debug("Added annotation view, new subviews count: \(self.subviews.count)")
            
            // Force view update
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            annotationView.needsDisplay = true
            needsDisplay = true
            #else
            annotationView.setNeedsDisplay()
            setNeedsDisplay()
            #endif
        } else {
            kLogger.debug("Data source returned nil annotation view")
        }
    }
    
    /// Update all annotation views (called during layout)
    private func updateAnnotationViews() {
        kLogger.debug("updateAnnotationViews called, total annotations: \(self.annotations.count)")
        
        for annotation in annotations {
            updateAnnotationView(for: annotation)
        }
    }

    // MARK: - Text Changes

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)

        // Update syntax highlighting for the affected area
        if isSyntaxHighlightingEnabled {
            let range = replacementRange.location != NSNotFound ? replacementRange : selectedRange
            applySyntaxHighlighting(in: range)
        }
    }
    #else
    // UITextView handles text insertion differently - use text did change notifications instead
    #endif

    // MARK: - Layout

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            super.layout()
            updateGutterFrame()
            updateLineHighlightFrame()
            updateAnnotationViews()
        } else {
            // Dispatch to main thread if called from background
            DispatchQueue.main.async { [weak self] in
                self?.layout()
            }
        }
    }
    #else
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateGutterFrame()
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateGutterFrame()
    }
    #endif

    // MARK: - Convenience Methods

    /// Set the programming language for syntax highlighting
    public func setLanguage(fileExtension: String) {
        language = syntaxHighlighter.detectLanguage(from: fileExtension)
    }

    /// Get all supported file extensions for syntax highlighting
    public var supportedFileExtensions: [String] {
        syntaxHighlighter.supportedFileExtensions
    }
    
    /// Get the text content storage for TextKit2 operations
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public var textContentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }
    #else
    public var textContentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }
    #endif

    /// Get the visible range of text in the text view
    public func visibleRange() -> NSRange {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let scrollView = enclosingScrollView {
            let visibleRect = scrollView.contentView.visibleRect
            return textRangeForVisibleRect(visibleRect)
        }

        // Fallback to entire text range
        return NSRange(location: 0, length: string.count)
        #else
        // For iOS, calculate visible range based on content offset and bounds
        let visibleRect = CGRect(origin: contentOffset, size: bounds.size)
        return textRangeForVisibleRect(visibleRect)
        #endif
    }
    
    /// Convert visible rect to text range using TextKit2-compatible approach
    private func textRangeForVisibleRect(_ visibleRect: CGRect) -> NSRange {
        // First try TextKit2 approach if available
        if let textLayoutManager = self.textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager {
            // Use TextKit2's viewport-based enumeration
            var startLocation: NSTextLocation?
            var endLocation: NSTextLocation?
            
            textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location, options: []) { fragment in
                let fragmentFrame = fragment.layoutFragmentFrame
                
                if fragmentFrame.intersects(visibleRect) {
                    if startLocation == nil {
                        startLocation = fragment.rangeInElement.location
                    }
                    endLocation = fragment.rangeInElement.endLocation
                }
                
                // Continue until we've passed the visible rect
                return fragmentFrame.minY <= visibleRect.maxY
            }
            
            if let start = startLocation, let end = endLocation {
                let startOffset = textContentManager.offset(from: textLayoutManager.documentRange.location, to: start)
                let endOffset = textContentManager.offset(from: textLayoutManager.documentRange.location, to: end)
                return NSRange(location: startOffset, length: endOffset - startOffset)
            }
        } else {
            // Fallback to TextKit1 approach only if TextKit2 is not available
            // Note: This access to layoutManager should only happen as a last resort
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            guard let layoutManager = self.layoutManager, let textContainer = self.textContainer else {
                return NSRange(location: 0, length: 0)
            }
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
            return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            #else
            // On iOS/Catalyst, layoutManager and textContainer are not optional
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
            return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            #endif
        }
        
        // Final fallback
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSRange(location: 0, length: string.count)
        #else
        return NSRange(location: 0, length: text?.count ?? 0)
        #endif
    }

    // MARK: - Additional CodeEditorView Methods

    // Removed problematic textContainer override that was blocking text container setup

    public var widthTracksTextView: Bool {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let textContainer = super.textContainer {
                return textContainer.widthTracksTextView
            } else {
                return false
            }
            #else
            return false // UITextView doesn't have this property
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let textContainer = super.textContainer {
                textContainer.widthTracksTextView = newValue
            }
            #endif
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public var isHorizontallyResizable: Bool {
        get {
            super.isHorizontallyResizable
        }
        set {
            super.isHorizontallyResizable = newValue
        }
    }
    #endif

    public var heightTracksTextView: Bool {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let textContainer = super.textContainer {
                return textContainer.heightTracksTextView
            } else {
                return true
            }
            #else
            return true // UITextView doesn't have this property
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let textContainer = super.textContainer {
                textContainer.heightTracksTextView = newValue
            }
            #endif
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public var isVerticallyResizable: Bool {
        get {
            super.isVerticallyResizable
        }
        set {
            super.isVerticallyResizable = newValue
        }
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var text: String? {
        get {
            string
        }
        set {
            string = newValue ?? ""
        }
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var attributedText: NSAttributedString? {
        get {
            textStorage
        }
        set {
            if let newValue = newValue {
                textStorage?.setAttributedString(newValue)
            } else {
                string = ""
            }
        }
    }
    #endif

    public var textSelection: NSRange {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            selectedRange
            #else
            selectedRange
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            setSelectedRange(newValue)
            #else
            selectedRange = newValue
            #endif
        }
    }

    public var gutterView: GutterView? {
        _gutterView
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func toggleRuler(_: Any?) {
        showsLineNumbers.toggle()
    }
    #endif

    public func shouldChangeText(in _: NSTextRange, replacementString _: String?) -> Bool {
        // Convert NSTextRange to NSRange for NSTextView compatibility
        // This is a simplified implementation
        true
    }

    public func replaceCharacters(in _: NSTextRange, with string: String) {
        // Convert NSTextRange to NSRange for NSTextView compatibility
        // This is a simplified implementation
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // For now, replace at current selection
        let selectedRange = selectedRange
        guard let textStorage = textStorage else { return }
        textStorage.replaceCharacters(in: selectedRange, with: string)
        #else
        // For now, replace at current selection
        let selectedRange = selectedRange
        textStorage.replaceCharacters(in: selectedRange, with: string)
        #endif
    }

    /// Custom notification for CodeEditorView selection changes
    public static let stTextViewDidChangeSelectionNotification = Notification
        .Name("CodeEditorViewDidChangeSelectionNotification")

    // MARK: - TextKit Helper Methods
    
    /// Calculate line rect using TextKit2-compatible approach that doesn't force TextKit1
    private func calculateLineRect(for range: NSRange) -> CGRect? {
        // First try TextKit2 approach if available
        if let textLayoutManager = self.textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager {
            // Use TextKit2 APIs
            guard let startLocation = textContentManager.location(textLayoutManager.documentRange.location, offsetBy: range.location),
                  let endLocation = textContentManager.location(startLocation, offsetBy: range.length) else {
                return nil
            }
            
            guard let textRange = NSTextRange(location: startLocation, end: endLocation) else {
                return nil
            }
            return textLayoutManager.textSegmentFrame(in: textRange, type: .standard)
        } else {
            // Fallback to TextKit1 approach only if TextKit2 is not available
            // Note: This access to layoutManager should only happen as a last resort
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            guard let layoutManager = self.layoutManager, let textContainer = self.textContainer else {
                return nil
            }
            #else
            // On iOS/Catalyst, layoutManager and textContainer are not optional
            let layoutManager = self.layoutManager
            let textContainer = self.textContainer
            #endif
            
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        }
    }

    // MARK: - TextKit Version Detection
    
    /// Detects which TextKit version is currently being used and logs warnings for compatibility mode
    public func detectTextKitVersion() -> String {
        #if canImport(UIKit)
        if textLayoutManager != nil {
            kLogger.info("✅ Using TextKit 2 with textLayoutManager")
            return "TextKit 2"
        } else {
            kLogger.warning("⚠️ TextKit 2 not available - using TextKit 1 fallback")
            return "TextKit 1 (fallback)"
        }
        #else
        if textLayoutManager != nil {
            kLogger.info("✅ Using TextKit 2 with textLayoutManager")
            return "TextKit 2"
        } else if responds(to: #selector(getter: NSTextView.layoutManager)) {
            kLogger.warning("❌ TextKit 1 compatibility mode active - this may cause performance issues")
            return "TextKit 1 (compatibility mode)"
        } else {
            kLogger.warning("⚠️ TextKit 2 not available - using TextKit 1 fallback")
            return "TextKit 1 (fallback)"
        }
        #endif
    }
    
    /// Validates that TextKit 2 is being used properly
    public func validateTextKit2Usage() -> Bool {
        let version = detectTextKitVersion()
        let isUsingTextKit2 = version.contains("TextKit 2")
        
        if !isUsingTextKit2 {
            kLogger.warning("TextKit 2 validation failed: \(version)")
        }
        
        return isUsingTextKit2
    }

    // MARK: - NSTextLayoutOrientationProvider

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public nonisolated var layoutOrientation: NSLayoutManager.TextLayoutOrientation {
        // For NSTextView, we'll default to horizontal layout
        .horizontal
    }
    #endif

    // MARK: - NSTextLayoutManagerDelegate

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public nonisolated func textLayoutManager(
        _: NSTextLayoutManager,
        textLayoutFragmentFor _: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        // Create the fragment with default paragraph style
        // The style will be updated later if needed
        TextLayoutFragment(
            textElement: textElement,
            range: textElement.elementRange,
            paragraphStyle: NSParagraphStyle.default
        )
    }
    #endif
    
    // MARK: - CompletionViewControllerDelegate
    
    public func completionViewController(
        _ viewController: some CompletionViewControllerProtocol,
        complete item: any CompletionItem,
        movement: PlatformTextMovement
    ) {
        // Get the insert text based on the item type
        let textToInsert: String
        if let adapter = item as? CompletionItemAdapter {
            textToInsert = adapter.model.insertText
        } else {
            // Fallback - use a default or empty string
            textToInsert = ""
        }
        
        // Insert the completion text if not empty
        if !textToInsert.isEmpty {
            insertText(textToInsert)
        }
        
        // Hide the completion window
        hideCompletionPopup()
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Note: We cannot perform MainActor-isolated cleanup in deinit
        // The cleanup of UI elements will happen automatically when the view is deallocated
        // Subviews are automatically removed from their superview when deallocated
    }
    
}
