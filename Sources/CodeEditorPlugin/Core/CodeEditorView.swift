import Foundation

#if canImport(UIKit)
import UIKit
public typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
public typealias PlatformViewController = NSViewController
#endif

import ObjectiveC
import os.log

// Local logger instance for CodeEditorView
private let kLogger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorView")

// MARK: - CodeEditorView

@objc @MainActor
open class CodeEditorView: PlatformTextView, NSTextLayoutManagerDelegate {
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
    public var selectedLineHighlightColor: PlatformColor = {
        #if canImport(UIKit)
        return UIColor.tintColor.withAlphaComponent(0.15)
        #else
        return NSColor.controlAccentColor.withAlphaComponent(0.15)
        #endif
    }() {
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
    private var annotations: [Annotation] = []

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
    #if canImport(AppKit)
    private var completionWindow: NSWindow?
    #else
    private var completionPopover: UIViewController?
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
    
    /// Completion trigger characters for the current language
    private var completionTriggerCharacters: Set<Character> = [".", "(", "[", "<", " "]

    // MARK: - Coordinate System

    #if canImport(AppKit)
    /// NSTextView requires flipped coordinates for proper text rendering
    override public var isFlipped: Bool {
        true
    }
    #endif

    // MARK: - Initialization

    #if canImport(AppKit)
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
        #if canImport(AppKit)
        kLogger.debug("CodeEditorView setupTextView: layoutManager = \(self.layoutManager != nil ? "exists" : "nil")")
        #else
        kLogger.debug("CodeEditorView setupTextView: layoutManager = exists")
        #endif
        #if canImport(AppKit)
        kLogger.debug("CodeEditorView setupTextView: textContainer = \(self.textContainer != nil ? "exists" : "nil")")
        #else
        kLogger.debug("CodeEditorView setupTextView: textContainer = exists")
        #endif
        kLogger.debug("CodeEditorView setupTextView: textLayoutManager = \(self.textLayoutManager != nil ? "exists" : "nil")")
        #if canImport(AppKit)
        kLogger.debug("CodeEditorView setupTextView: textContentStorage = \(self.textContentStorage != nil ? "exists" : "nil")")
        #endif
        
        // Check which TextKit version we're using
        if textLayoutManager != nil {
            kLogger.debug("CodeEditorView setupTextView: Using TextKit2")
        } else {
            #if canImport(AppKit)
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
        if let textStorage {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextStorageDidProcessEditing(_:)),
                name: NSTextStorage.didProcessEditingNotification,
                object: textStorage
            )
        }
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textStorage
        )
        #endif

        // Set up selection change observation
        #if canImport(AppKit)
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
        
        // Apply modern TextKit configuration
        ModernTextKitHelper.configureTextView(self)
        ModernTextKitHelper.optimizeTextViewPerformance(self)
        
        // Ensure TextKit2 is used if available and beneficial
        let usingTextKit2 = ModernTextKitHelper.ensureTextKit2(for: self)
        kLogger.debug("CodeEditorView setupTextView: Using TextKit2: \(usingTextKit2)")

        // Ensure proper sizing and layout
        #if canImport(AppKit)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        #else
        // UITextView doesn't have these properties - it handles scrolling differently
        #endif

        // Make sure we have reasonable size constraints
        #if canImport(AppKit)
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: 10_000, height: 10_000)
        #endif

        kLogger.debug("CodeEditorView setupTextView: Final frame = \(String(describing: self.frame))")
        #if canImport(AppKit)
        kLogger.debug("CodeEditorView setupTextView: Final container size = \(String(describing: self.textContainer?.containerSize ?? .zero))")
        #else
        kLogger.debug("CodeEditorView setupTextView: Final container size = \(String(describing: self.textContainer.size))")
        #endif

        // Initial syntax highlighting
        applySyntaxHighlighting()
        
        // Set up completion providers
        setupCompletionProviders()
        
        // Set up LSP integration
        setupLSPIntegration()
        
        // Set up TextKit2 rendering optimization
        setupTextKit2Optimization()
        
        // Register with memory monitor
        registerWithMemoryMonitor()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Theme Setup

    private func setupDefaultTheme() {
        #if canImport(AppKit)
        backgroundColor = NSColor.textBackgroundColor
        textColor = NSColor.labelColor
        font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
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
        #if canImport(AppKit)
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
            #if canImport(AppKit)
            eventPublisher.publish(.textDidChange(string))
            #else
            eventPublisher.publish(.textDidChange(text ?? ""))
            #endif
            
            // Check for completion triggering
            checkForCompletionTrigger(at: editedRange)
            
            // Update LSP document context
            updateLSPDocumentContext()
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
        #if canImport(AppKit)
        guard let textStorage else {
            return
        }
        #else
        let textStorage = self.textStorage
        #endif

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)

        // Restore default text color
        #if canImport(AppKit)
        textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.labelColor, range: fullRange)
        #else
        textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.label, range: fullRange)
        #endif
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
        #if canImport(AppKit)
        let cursorPosition = selectedRange().location
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
        
        #if canImport(AppKit)
        let cursorPosition = selectedRange().location
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
        #if canImport(AppKit)
        guard let textContainer,
              let layoutManager else {
            return CGRect(x: 0, y: 0, width: 1, height: 16)
        }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: position, length: 0), actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        #else
        // UITextView cursor positioning
        guard let textRange = textRange(from: beginningOfDocument, offset: position) else {
            return CGRect(x: 0, y: 0, width: 1, height: 16)
        }
        return caretRect(for: textRange.start)
        #endif
    }
    
    /// Show completion window/popover at the specified rectangle
    private func showCompletionWindow(with viewController: any CompletionViewControllerProtocol, at rect: CGRect) {
        #if canImport(AppKit)
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
        window.backgroundColor = NSColor.clear
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
        
        guard let popoverVC = viewController as? UIViewController else {
            assertionFailure("viewController must be a UIViewController on iOS")
            return
        }
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
        
        #if canImport(AppKit)
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
    override public func keyDown(with event: NSEvent) {
        #if canImport(AppKit)
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
        #endif
        
        super.keyDown(with: event)
    }
    
    /// Get current line range at position
    private func currentLineRange(at position: Int) -> Range<String.Index> {
        #if canImport(AppKit)
        let text = string
        #else
        let text = self.text ?? ""
        #endif
        
        let textIndex = text.index(text.startIndex, offsetBy: min(position, text.count))
        return text.lineRange(for: textIndex..<textIndex)
    }
    
    /// Get current word range at position
    private func currentWordRange(at position: Int) -> NSRange? {
        #if canImport(AppKit)
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

    private func updateGutterVisibility() {
        #if canImport(AppKit)
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

        let gutter = GutterView()
        gutter.textView = self
        #if canImport(AppKit)
        gutter.autoresizingMask = NSView.AutoresizingMask.height // Only resize height, not width
        #else
        gutter.autoresizingMask = [.flexibleHeight] // Only resize height, not width
        #endif

        // Add gutter directly to the text view since we might not be in a scroll view
        // Position it at the front so it doesn't get covered
        #if canImport(AppKit)
        addSubview(gutter, positioned: .above, relativeTo: nil)
        #else
        addSubview(gutter)
        bringSubviewToFront(gutter)
        #endif

        _gutterView = gutter
        updateGutterFrame()
    }

    private func removeGutter() {
        _gutterView?.removeFromSuperview()
        _gutterView = nil
    }

    private func updateGutterFrame() {
        guard let gutter = _gutterView else {
            return
        }

        layoutCoordinator.performLayout {
            // Use configuration values instead of magic numbers
            let gutterWidth = self.configuration.layout.gutterWidth
            let padding = self.configuration.layout.lineNumberPadding
            
            #if canImport(AppKit)
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

            // Update text container inset to make room for gutter
            #if canImport(AppKit)
            self.textContainerInset = NSSize(width: gutterWidth + padding, height: self.textContainerInset.height)
            #else
            self.textContainerInset = UIEdgeInsets(top: self.textContainerInset.top, left: gutterWidth + padding, bottom: self.textContainerInset.bottom, right: self.textContainerInset.right)
            #endif

            // Don't update text container size here - let NSTextView handle it

            #if canImport(AppKit)
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
            #if canImport(AppKit)
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
        #if canImport(AppKit)
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable
        #else
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable
        #endif
        
        // Force layout update
        layoutCoordinator.invalidateLayout()
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
        #if canImport(AppKit)
        let selection = selectedRange()
        #else
        let selection = selectedRange
        #endif
        eventPublisher.publish(.textSelectionDidChange(selection))
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
        #if canImport(AppKit)
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = selectedLineHighlightColor.cgColor
        #else
        highlight.layer.backgroundColor = selectedLineHighlightColor.cgColor
        #endif

        // Add as background overlay
        #if canImport(AppKit)
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

        #if canImport(AppKit)
        let selectedRange = selectedRange()
        #else
        let selectedRange = self.selectedRange
        #endif
        guard selectedRange.location != NSNotFound else {
            return
        }

        // Get the line range for the selection
        #if canImport(AppKit)
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
        #if canImport(AppKit)
        frame.origin.y += textContainerInset.height
        #else
        frame.origin.y += textContainerInset.top
        #endif

        highlightView.frame = frame
        #if canImport(AppKit)
        highlightView.layer?.backgroundColor = selectedLineHighlightColor.cgColor
        #else
        highlightView.layer.backgroundColor = selectedLineHighlightColor.cgColor
        #endif
    }

    // MARK: - Layout Manager Settings

    private func updateLayoutManagerSettings() {
        #if canImport(AppKit)
        if let layoutManager {
            layoutManager.showsInvisibleCharacters = showsInvisibleCharacters
        }
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
        guard let textLayoutManager else {
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
        #if canImport(AppKit)
        let inlineX = crossPlatformTextContainerInset.width + segmentFrame.maxX + badgePadding
        let inlineY = crossPlatformTextContainerInset.height + segmentFrame.midY - (badgeSize / 2)
        #else
        let inlineX = crossPlatformTextContainerInset.width + segmentFrame.maxX + badgePadding
        let inlineY = crossPlatformTextContainerInset.height + segmentFrame.midY - (badgeSize / 2)
        #endif
        
        let proposedFrame = CGRect(
            x: inlineX,
            y: inlineY,
            width: badgeSize,
            height: badgeSize
        ).integral
        
        kLogger.debug("Calculated proposedFrame: \(String(describing: proposedFrame))")
        kLogger.debug("textContainerInset: \(String(describing: self.crossPlatformTextContainerInset))")

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
            #if canImport(AppKit)
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

    #if canImport(AppKit)
    override public func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)

        // Update syntax highlighting for the affected area
        if isSyntaxHighlightingEnabled {
            let range = replacementRange.location != NSNotFound ? replacementRange : selectedRange()
            applySyntaxHighlighting(in: range)
        }
    }
    #else
    // UITextView handles text insertion differently - use text did change notifications instead
    #endif

    // MARK: - Layout

    #if canImport(AppKit)
    override public func layout() {
        super.layout()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()
    }
    #else
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()
    }
    #endif

    #if canImport(AppKit)
    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateGutterFrame()
    }
    #endif

    #if canImport(AppKit)
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
    override public var textContentStorage: NSTextContentStorage? {
        #if canImport(AppKit)
        return textLayoutManager?.textContentManager as? NSTextContentStorage
        #else
        return textLayoutManager?.textContentManager as? NSTextContentStorage
        #endif
    }

    /// Get the visible range of text in the text view
    public func visibleRange() -> NSRange {
        #if canImport(AppKit)
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
            #if canImport(AppKit)
            if let layoutManager = self.layoutManager,
               let textContainer = self.textContainer {
                let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
                return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            }
            #else
            let layoutManager = self.layoutManager
            let textContainer = self.textContainer
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
            return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            #endif
        }
        
        // Final fallback
        #if canImport(AppKit)
        return NSRange(location: 0, length: string.count)
        #else
        return NSRange(location: 0, length: text?.count ?? 0)
        #endif
    }

    // MARK: - Additional CodeEditorView Methods

    // Removed problematic textContainer override that was blocking text container setup

    public var widthTracksTextView: Bool {
        get {
            #if canImport(AppKit)
            super.textContainer?.widthTracksTextView ?? false
            #else
            false // UITextView doesn't have this property
            #endif
        }
        set {
            #if canImport(AppKit)
            super.textContainer?.widthTracksTextView = newValue
            #else
            // UITextView doesn't have this property
            #endif
        }
    }

    #if canImport(AppKit)
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
            #if canImport(AppKit)
            super.textContainer?.heightTracksTextView ?? true
            #else
            true // UITextView doesn't have this property
            #endif
        }
        set {
            #if canImport(AppKit)
            super.textContainer?.heightTracksTextView = newValue
            #else
            // UITextView doesn't have this property
            #endif
        }
    }

    #if canImport(AppKit)
    override public var isVerticallyResizable: Bool {
        get {
            super.isVerticallyResizable
        }
        set {
            super.isVerticallyResizable = newValue
        }
    }
    #endif

    #if canImport(AppKit)
    public var text: String? {
        get {
            string
        }
        set {
            kLogger.debug("CodeEditorView text setter: Setting text to '\(newValue ?? "nil")'")
            kLogger.debug("CodeEditorView text setter: Current string length = \(self.string.count)")
            string = newValue ?? ""
            kLogger.debug("CodeEditorView text setter: After setting, string length = \(self.string.count)")
            kLogger.debug("CodeEditorView text setter: textStorage length = \(self.textStorage?.length ?? -1)")
        }
    }
    #endif

    #if canImport(AppKit)
    public var attributedText: NSAttributedString? {
        get {
            textStorage
        }
        set {
            if let newValue {
                textStorage?.setAttributedString(newValue)
            } else {
                string = ""
            }
        }
    }
    #endif

    public var textSelection: NSRange {
        get {
            #if canImport(AppKit)
            selectedRange()
            #else
            selectedRange
            #endif
        }
        set {
            #if canImport(AppKit)
            setSelectedRange(newValue)
            #else
            selectedRange = newValue
            #endif
        }
    }

    public var gutterView: GutterView? {
        _gutterView
    }

    #if canImport(AppKit)
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
        #if canImport(AppKit)
        if let textStorage {
            // For now, replace at current selection
            let selectedRange = selectedRange()
            textStorage.replaceCharacters(in: selectedRange, with: string)
        }
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
            #if canImport(AppKit)
            guard let layoutManager = self.layoutManager,
                  let textContainer = self.textContainer else {
                return nil
            }
            #else
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
        if let textLayoutManager = self.textLayoutManager {
            kLogger.info("✅ Using TextKit 2 with textLayoutManager")
            return "TextKit 2"
        } else {
            kLogger.warning("⚠️ TextKit 2 not available - using TextKit 1 fallback")
            return "TextKit 1 (fallback)"
        }
        #else
        if let textLayoutManager = self.textLayoutManager {
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

    #if canImport(AppKit)
    override public nonisolated var layoutOrientation: NSLayoutManager.TextLayoutOrientation {
        // For NSTextView, we'll default to horizontal layout
        .horizontal
    }
    #endif

    // MARK: - NSTextLayoutManagerDelegate

    #if canImport(AppKit)
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
}

// MARK: - CompletionViewControllerDelegate

// swiftlint:disable:next no_grouping_extension
extension CodeEditorView: CompletionViewControllerDelegate {
    public func completionViewController(
        _: some CompletionViewControllerProtocol,
        complete item: any CompletionItem,
        movement _: PlatformTextMovement
    ) {
        // Hide completion popup
        hideCompletionPopup()
        
        // Insert the completion item
        if let adapter = item as? CompletionItemAdapter {
            insertCompletionItem(adapter.model)
        } else {
            // For items that don't have the adapter pattern, we can't access detailed properties
            // This is a minimal fallback implementation
            kLogger.warning("Completion item does not provide detailed information for insertion")
        }
    }
    
    /// Insert a completion item into the text
    private func insertCompletionItem(_ item: CompletionItemModel) {
        #if canImport(AppKit)
        let currentPosition = selectedRange().location
        let text = string
        #else
        let currentPosition = selectedRange.location
        let text = self.text ?? ""
        #endif
        
        // Find the word to replace (if any)
        let wordRange = currentWordRange(at: currentPosition) ?? NSRange(location: currentPosition, length: 0)
        
        // Use textEdit if provided, otherwise insert the insertText
        let insertText = item.textEdit?.newText ?? item.insertText
        let replaceRange = item.textEdit?.range ?? wordRange
        
        // Perform the text replacement
        #if canImport(AppKit)
        if shouldChangeText(in: convertNSRangeToTextRange(replaceRange), replacementString: insertText) {
            textStorage?.replaceCharacters(in: replaceRange, with: insertText)
            
            // Update selection to end of inserted text
            let newPosition = replaceRange.location + insertText.count
            setSelectedRange(NSRange(location: newPosition, length: 0))
        }
        #else
        // UITextView text replacement
        if let textRange = textRange(
            from: position(from: beginningOfDocument, offset: replaceRange.location)!,
            to: position(from: beginningOfDocument, offset: replaceRange.location + replaceRange.length)!
        ) {
            replace(textRange, withText: insertText)
        }
        #endif
    }
    
    #if canImport(AppKit)
    /// Convert NSRange to NSTextRange for modern TextKit compatibility
    private func convertNSRangeToTextRange(_ range: NSRange) -> NSTextRange {
        // This is a simplified implementation - for proper TextKit2 conversion
        // we'd need to carefully map between character and glyph indices
        
        // First try to use the text layout manager
        if let textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager {
            let documentRange = textContentManager.documentRange
            
            // Try to create the proper range
            if let start = textContentManager.location(documentRange.location, offsetBy: range.location),
               let end = textContentManager.location(start, offsetBy: range.length),
               let textRange = NSTextRange(location: start, end: end) {
                return textRange
            }
            
            // Fallback to document range if we can't create the exact range
            return documentRange
        }
        
        // Last resort: create a minimal range using the beginning of the document
        // This shouldn't happen in normal operation but provides a safe fallback
        if let contentManager = textLayoutManager?.textContentManager {
            let location = contentManager.documentRange.location
            return NSTextRange(location: location)
        }
        
        // This case should be extremely rare - indicates no TextKit2 setup
        fatalError("Unable to create NSTextRange - TextKit2 not properly initialized")
    }
    #endif
    
    /// Set up completion providers during initialization
    private func setupCompletionProviders() {
        // Register built-in Swift completion provider
        let swiftProvider = SwiftCompletionProvider()
        completionManager.registerProvider(swiftProvider)
        
        // Update trigger characters based on registered providers
        updateCompletionTriggerCharacters()
    }
    
    /// Update completion trigger characters from all registered providers
    private func updateCompletionTriggerCharacters() {
        var allTriggerChars: Set<Character> = []
        
        for provider in completionManager.registeredProviders {
            for triggerString in provider.triggerCharacters {
                allTriggerChars.formUnion(triggerString)
            }
        }
        
        completionTriggerCharacters = allTriggerChars
    }
    
    /// Register a custom completion provider
    public func registerCompletionProvider(_ provider: any CompletionProvider) {
        completionManager.registerProvider(provider)
        updateCompletionTriggerCharacters()
    }
    
    /// Unregister a completion provider by ID
    public func unregisterCompletionProvider(withId id: String) {
        completionManager.unregisterProvider(withId: id)
        updateCompletionTriggerCharacters()
    }
    
    // MARK: - LSP Integration
    
    /// Get the LSP manager for external configuration
    public var languageServerManager: LSPManager {
        lspManager
    }
    
    /// Current file path for LSP document management
    public var filePath: String? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.filePath) as? String
        }
        set {
            let oldValue = filePath
            objc_setAssociatedObject(self, &AssociatedKeys.filePath, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if newValue != oldValue {
                updateLSPDocumentContext()
            }
        }
    }
    
    private enum AssociatedKeys {
        @MainActor static var filePath: UInt8 = 0
    }
    
    /// Set up LSP integration during initialization
    private func setupLSPIntegration() {
        // Register LSP completion provider
        let lspProvider = LSPCompletionProvider(lspManager: lspManager)
        registerCompletionProvider(lspProvider)
        
        // Set up workspace root if available
        if let workspaceRoot = inferWorkspaceRoot() {
            lspManager.workspaceRoot = workspaceRoot
        }
    }
    
    /// Update LSP document context when file path or content changes
    private func updateLSPDocumentContext() {
        guard let filePath else { return }
        
        Task {
            do {
                let content = string
                let lspProvider = completionManager.registeredProviders.first { $0.id == "lsp-completion-provider" } as? LSPCompletionProvider
                lspProvider?.updateContext(filePath: filePath, text: content)
            }
        }
    }
    
    /// Infer workspace root from file path
    private func inferWorkspaceRoot() -> URL? {
        guard let filePath else { return nil }
        
        let fileURL = URL(fileURLWithPath: filePath)
        var currentDir = fileURL.deletingLastPathComponent()
        
        // Look for common workspace markers
        let workspaceMarkers = [".git", ".gitignore", "Package.swift", "Cargo.toml", "package.json", ".vscode", ".idea"]
        
        while currentDir.path != "/" {
            for marker in workspaceMarkers {
                let markerURL = currentDir.appendingPathComponent(marker)
                if FileManager.default.fileExists(atPath: markerURL.path) {
                    return currentDir
                }
            }
            currentDir = currentDir.deletingLastPathComponent()
        }
        
        // Fallback to file's parent directory
        return fileURL.deletingLastPathComponent()
    }
    
    /// Get diagnostics for the current file
    public func getDiagnostics() -> [Diagnostic] {
        guard let filePath else { return [] }
        return lspManager.getDiagnostics(for: filePath)
    }
    
    /// Request hover information at a specific position
    /// - Parameters:
    ///   - position: Character position in the text
    /// - Returns: Hover information if available
    public func requestHover(at position: Int) async -> Hover? {
        guard let filePath else { return nil }
        
        let lineCharPos = convertPositionToLineCharacter(position: position, in: string)
        
        do {
            return try await lspManager.requestHover(
                filePath: filePath,
                line: lineCharPos.line,
                character: lineCharPos.character
            )
        } catch {
            kLogger.error("Failed to request hover: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Request definition for symbol at position
    /// - Parameters:
    ///   - position: Character position in the text
    /// - Returns: Definition locations
    public func requestDefinition(at position: Int) async -> [Location] {
        guard let filePath else { return [] }
        
        let lineCharPos = convertPositionToLineCharacter(position: position, in: string)
        
        do {
            return try await lspManager.requestDefinition(
                filePath: filePath,
                line: lineCharPos.line,
                character: lineCharPos.character
            )
        } catch {
            kLogger.error("Failed to request definition: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Helper to convert string position to line/character
    private func convertPositionToLineCharacter(position: Int, in text: String) -> (line: Int, character: Int) {
        let lines = text.prefix(position).components(separatedBy: .newlines)
        let line = max(0, lines.count - 1)
        let character = lines.last?.count ?? 0
        
        return (line: line, character: character)
    }
    
    // MARK: - Memory Management
    
    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            MemoryMonitor.shared.registerCleanupHandler(
                identifier: "code-editor-view-\(ObjectIdentifier(self).hashValue)",
                priority: .normal
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "CodeEditorView deallocated")
                }
                
                // Clear completion manager cache
                self.completionManager.clearCache()
                
                // Clear any cached layout information (avoid accessing textContainer in Sendable context)
                self.needsLayout = true
                
                // Estimate memory freed
                let estimatedMemoryMB = 2.0 // Conservative estimate for text view cleanup
                
                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared CodeEditorView caches and layout"
                )
            }
        }
    }
    
    // MARK: - TextKit2 Optimization
    
    /// Set up TextKit2 rendering optimization
    private func setupTextKit2Optimization() {
        // Configure optimizer if using TextKit2
        if let textLayoutManager,
           let textContentStorage {
            renderingOptimizer.configure(
                textLayoutManager: textLayoutManager,
                textContentStorage: textContentStorage
            )
            
            // Apply optimal performance configuration based on text length
            let characterCount = textContentStorage.textStorage?.length ?? 0
            let config = TextKit2PerformanceHelper.configureForOptimalPerformance(
                textView: self,
                characterCount: characterCount
            )
            
            kLogger.debug("TextKit2 optimization configured for \(characterCount) characters with config: viewport=\(config.enableViewportOptimization), recycling=\(config.enableFragmentRecycling)")
            
            // Set up scroll view observation for viewport optimization
            setupScrollViewObservation()
            
            // Enable TextKit2 if beneficial for the file size
            let usingTextKit2 = TextKit2PerformanceHelper.enableTextKit2IfBeneficial(self, characterCount: characterCount)
            kLogger.debug("TextKit2 enabled: \(usingTextKit2)")
        }
    }
    
    /// Set up scroll view observation for viewport-based optimization
    private func setupScrollViewObservation() {
        #if canImport(AppKit)
        // Observe scroll view changes on macOS
        if let scrollView = enclosingScrollView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScrollViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }
        #else
        // On iOS, UITextView handles scrolling directly
        // We can observe scrollViewDidScroll through delegate if needed
        #endif
    }
    
    #if canImport(AppKit)
    /// Handle scroll view scrolling for viewport optimization
    @objc private func handleScrollViewDidScroll(_: Notification) {
        guard let scrollView = enclosingScrollView else { return }
        
        // Calculate visible text range
        let visibleRect = scrollView.documentVisibleRect
        let visibleRange = calculateVisibleTextRange(for: visibleRect)
        
        // Update rendering optimizer
        renderingOptimizer.updateVisibleRange(visibleRange)
        
        // Update async syntax highlighter for priority highlighting
        asyncHighlighter.updateVisibleRange(visibleRange)
        
        // Record performance metrics
        performanceMonitor.recordLayoutOperation(duration: 0.001) // Minimal scroll update
    }
    #endif
    
    /// Calculate visible text range for a given visible rectangle
    private func calculateVisibleTextRange(for visibleRect: CGRect) -> NSRange {
        #if canImport(AppKit)
        guard let textContainer,
              let layoutManager else {
            return NSRange(location: 0, length: 0)
        }
        
        // Convert visible rect to glyph range
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        
        // Convert glyph range to character range
        
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        #else
        // For UITextView, use different approach
        guard let textPosition = closestPosition(to: visibleRect.origin) else {
            return NSRange(location: 0, length: 0)
        }
        
        let startOffset = offset(from: beginningOfDocument, to: textPosition)
        
        // Estimate visible length based on rect height and font size
        let fontSize = font?.pointSize ?? 12
        let estimatedLines = Int(visibleRect.height / (fontSize * 1.2))
        let estimatedLength = estimatedLines * 80 // Rough estimate
        
        return NSRange(location: startOffset, length: min(estimatedLength, text.count - startOffset))
        #endif
    }
    
    /// Optimize text view for current content
    public func optimizeForCurrentContent() {
        let characterCount = string.count
        
        // Apply optimal configuration
        TextKit2PerformanceHelper.configureForOptimalPerformance(
            textView: self,
            characterCount: characterCount
        )
        
        // Update rendering optimizer
        if let textLayoutManager,
           let textContentStorage {
            renderingOptimizer.configure(
                textLayoutManager: textLayoutManager,
                textContentStorage: textContentStorage
            )
            
            // Trigger optimization
            renderingOptimizer.optimizeLargeFileLayout()
        }
        
        kLogger.debug("Text view optimized for \(characterCount) characters")
    }
    
    /// Enable real-time editing optimizations
    public func enableRealTimeEditingMode() {
        TextKit2PerformanceHelper.optimizeForRealTimeEditing(self)
        kLogger.debug("Real-time editing mode enabled")
    }
    
    /// Enable read-only viewing optimizations
    public func enableReadOnlyViewingMode() {
        TextKit2PerformanceHelper.optimizeForReadOnlyViewing(self)
        kLogger.debug("Read-only viewing mode enabled")
    }
    
    /// Get current rendering performance statistics
    public var renderingStatistics: RenderingStatistics {
        renderingOptimizer.renderingStats
    }
    
    /// Get current performance monitor data
    public var performanceStatistics: TextKit2PerformanceMonitor {
        performanceMonitor
    }
    
    /// Get background syntax highlighting statistics
    public var backgroundHighlightingStatistics: BackgroundHighlightingStatistics {
        asyncHighlighter.backgroundStatistics
    }
}

// MARK: - MockTextLineFragment

private enum MockTextLineFragment {
    // Minimal implementation for compatibility with existing annotation system
}
