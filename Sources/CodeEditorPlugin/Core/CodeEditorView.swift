#if canImport(UIKit)
import UIKit

public typealias PlatformTextView = UITextView
public typealias PlatformScrollView = UIScrollView
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit

public typealias PlatformTextView = NSTextView
public typealias PlatformScrollView = NSScrollView
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
#endif

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

    /// The syntax highlighting coordinator
    private let syntaxHighlighter = SyntaxHighlightingCoordinator()

    /// Current programming language for syntax highlighting
    public var language: Language = .plainText {
        didSet {
            if language != oldValue {
                applySyntaxHighlighting()
            }
        }
    }

    /// Enable/disable syntax highlighting
    public var isSyntaxHighlightingEnabled: Bool = true {
        didSet {
            if isSyntaxHighlightingEnabled != oldValue {
                if isSyntaxHighlightingEnabled {
                    applySyntaxHighlighting()
                } else {
                    removeSyntaxHighlighting()
                }
            }
        }
    }

    /// Controls whether line numbers are shown
    public var showsLineNumbers: Bool = false {
        didSet {
            if showsLineNumbers != oldValue {
                #if canImport(AppKit)
                updateGutterVisibility()
                #else
                // On iOS, line numbers are handled by the container view
                // This property is kept for API compatibility
                #endif
            }
        }
    }

    /// Controls whether the current line is highlighted
    public var highlightSelectedLine: Bool = false {
        didSet {
            if highlightSelectedLine != oldValue {
                updateSelectedLineHighlight()
            }
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

    /// Controls whether invisible characters are shown
    public var showsInvisibleCharacters: Bool = false {
        didSet {
            if showsInvisibleCharacters != oldValue {
                updateLayoutManagerSettings()
            }
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
        if isSyntaxHighlightingEnabled {
            let editedRange = textStorage.editedRange
            if editedRange.location != NSNotFound {
                applySyntaxHighlighting(in: editedRange)
            }
        }
    }

    private func applySyntaxHighlighting() {
        guard isSyntaxHighlightingEnabled else {
            return
        }
        
        #if canImport(AppKit)
        guard let textStorage else {
            return
        }
        #else
        let textStorage = self.textStorage
        #endif

        let fullRange = NSRange(location: 0, length: textStorage.length)
        applySyntaxHighlighting(in: fullRange)
    }

    private func applySyntaxHighlighting(in range: NSRange) {
        guard range.location != NSNotFound else {
            return
        }
        
        #if canImport(AppKit)
        guard let textStorage else {
            return
        }
        #else
        let textStorage = self.textStorage
        #endif

        let text = textStorage.string
        guard !text.isEmpty else {
            return
        }

        // Ensure range is within bounds
        let safeRange = NSRange(
            location: min(range.location, textStorage.length),
            length: min(range.length, textStorage.length - min(range.location, textStorage.length))
        )

        guard safeRange.length > 0 else {
            return
        }

        // Expand range to include full lines for better highlighting
        guard let range = Range(safeRange, in: text) else { return }
        let lineRange = text.lineRange(for: range)
        let expandedRange = NSRange(lineRange, in: text)

        // Ensure expanded range is also within bounds
        let safeExpandedRange = NSRange(
            location: expandedRange.location,
            length: min(expandedRange.length, textStorage.length - expandedRange.location)
        )

        guard safeExpandedRange.length > 0 else {
            return
        }

        // Get substring for the range
        let substring = String(text[Range(safeExpandedRange, in: text)!])

        // Get highlighted tokens
        let tokens = syntaxHighlighter.highlight(source: substring, language: language)

        // Apply highlighting
        textStorage.beginEditing()

        // Remove existing foreground colors in the range
        textStorage.removeAttribute(.foregroundColor, range: safeExpandedRange)

        // If no tokens, ensure text has a default color
        if tokens.isEmpty {
            #if canImport(AppKit)
            textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.labelColor, range: safeExpandedRange)
            #else
            textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.label, range: safeExpandedRange)
            #endif
        }

        // Apply syntax highlighting
        for token in tokens {
            let adjustedRange = NSRange(
                location: safeExpandedRange.location + token.range.location,
                length: token.range.length
            )

            // Double-check the adjusted range is valid
            guard adjustedRange.location >= 0,
                  adjustedRange.length > 0,
                  adjustedRange.location + adjustedRange.length <= textStorage.length
            else {
                continue
            }

            let color = token.type.adaptiveColor
            textStorage.addAttribute(.foregroundColor, value: color, range: adjustedRange)
        }

        // Ensure all text has a color - fill gaps with default text color
        var coveredRanges: [NSRange] = []
        for token in tokens {
            let adjustedRange = NSRange(
                location: safeExpandedRange.location + token.range.location,
                length: token.range.length
            )
            if adjustedRange.location >= 0,
               adjustedRange.length > 0,
               adjustedRange.location + adjustedRange.length <= textStorage.length {
                coveredRanges.append(adjustedRange)
            }
        }

        // Sort ranges by location
        coveredRanges.sort { $0.location < $1.location }

        // Fill gaps with default text color
        var currentLocation = safeExpandedRange.location
        for range in coveredRanges {
            if currentLocation < range.location {
                let gapRange = NSRange(location: currentLocation, length: range.location - currentLocation)
                #if canImport(AppKit)
                textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.labelColor, range: gapRange)
                #else
                textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.label, range: gapRange)
                #endif
            }
            currentLocation = range.location + range.length
        }

        // Fill any remaining gap at the end
        let endOfRange = safeExpandedRange.location + safeExpandedRange.length
        if currentLocation < endOfRange {
            let gapRange = NSRange(location: currentLocation, length: endOfRange - currentLocation)
            #if canImport(AppKit)
            textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.labelColor, range: gapRange)
            #else
            textStorage.addAttribute(.foregroundColor, value: textColor ?? PlatformColor.label, range: gapRange)
            #endif
        }

        textStorage.endEditing()
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

    private var isUpdatingGutter = false

    private func updateGutterFrame() {
        guard let gutter = _gutterView else {
            return
        }
        guard !isUpdatingGutter else {
            return
        } // Prevent recursion

        isUpdatingGutter = true
        defer { isUpdatingGutter = false }

        // Set the gutter frame to match the text view's visible area
        let gutterWidth: CGFloat = 60
        #if canImport(AppKit)
        gutter.frame = NSRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: bounds.height
        )
        #else
        // For iOS, the gutter should be positioned fixed and not scroll with content
        // It should be tall enough to show all visible line numbers
        gutter.frame = CGRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: bounds.height
        )
        #endif

        // Update text container inset to make room for gutter
        #if canImport(AppKit)
        textContainerInset = NSSize(width: gutterWidth + 8, height: textContainerInset.height)
        #else
        textContainerInset = UIEdgeInsets(top: textContainerInset.top, left: gutterWidth + 8, bottom: textContainerInset.bottom, right: textContainerInset.right)
        #endif

        // Don't update text container size here - let NSTextView handle it

        #if canImport(AppKit)
        gutter.needsDisplay = true
        #else
        gutter.setNeedsDisplay()
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

        // Calculate inline annotation position (right after the annotated text)
        let badgeSize: CGFloat = 20
        let badgePadding: CGFloat = 4
        #if canImport(AppKit)
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

// MARK: - MockTextLineFragment

private enum MockTextLineFragment {
    // Minimal implementation for compatibility with existing annotation system
}
