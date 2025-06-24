//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md
//
//  Refactored to inherit from NSTextView instead of NSScrollView
//  Plugin system removed and features integrated directly

#if canImport(UIKit)
import UIKit
public typealias PlatformTextView = UITextView
public typealias PlatformScrollView = UIScrollView
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit  
public typealias PlatformTextView = NSTextView
public typealias PlatformScrollView = NSScrollView
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#endif

@objc @MainActor open class STTextView: PlatformTextView {
    // STTextViewProtocol conformance
    public typealias GutterView = STGutterView
    public typealias Color = NSColor
    public typealias Font = NSFont
    public typealias Delegate = STTextViewDelegate

    // We'll use NSTextView's built-in notifications instead of overriding them

    // MARK: - Properties

    /// Custom delegate for STTextView-specific functionality
    public weak var textDelegate: (any STTextViewDelegate)? {
        set {
            delegateProxy.source = newValue
        }
        get {
            delegateProxy.source
        }
    }

    /// Proxy for delegate calls
    internal let delegateProxy = STTextViewDelegateProxy(source: nil)

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
                updateGutterVisibility()
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
    private var _gutterView: STGutterView?

    /// Line highlight view
    private var lineHighlightView: NSView?

    /// Annotations storage
    private var annotations: [STAnnotation] = []

    /// Annotation views mapping
    private var annotationViews: [String: NSView] = [:]

    /// Annotations data source
    public weak var annotationsDataSource: STAnnotationsDataSource?

    // MARK: - Coordinate System
    
    /// NSTextView requires flipped coordinates for proper text rendering
    public override var isFlipped: Bool {
        return true
    }
    
    // MARK: - Initialization

    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }

    public override init(frame frameRect: NSRect) {
        // Use default NSTextView initialization - don't create custom text container
        // The custom text container creation was breaking text rendering
        print("STTextView init: frame = \(frameRect)")
        
        super.init(frame: frameRect)
        setupTextView()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }

    private func setupTextView() {
        print("STTextView setupTextView: Starting setup")
        print("STTextView setupTextView: textStorage = \(textStorage != nil ? "exists" : "nil")")
        print("STTextView setupTextView: layoutManager = \(layoutManager != nil ? "exists" : "nil")")
        print("STTextView setupTextView: textContainer = \(textContainer != nil ? "exists" : "nil")")
        
        // Set up the text view
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        
        // Enable undo
        allowsUndo = true
        
        // Set up delegate
        delegate = delegateProxy
        
        // Set up text storage observation for syntax highlighting
        if let textStorage = textStorage {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextStorageDidProcessEditing(_:)),
                name: NSTextStorage.didProcessEditingNotification,
                object: textStorage
            )
        }
        
        // Set up selection change observation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextViewDidChangeSelection(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
        
        // Setup theme
        setupDefaultTheme()
        
        // Ensure proper sizing and layout
        isVerticallyResizable = true
        isHorizontallyResizable = false
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        
        // Make sure we have reasonable size constraints
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: 10000, height: 10000)
        
        print("STTextView setupTextView: Final frame = \(frame)")
        print("STTextView setupTextView: Final container size = \(textContainer?.containerSize ?? .zero)")
        
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

    @objc func handleTextStorageDidProcessEditing(_ notification: Notification) {
        guard let textStorage = notification.object as? NSTextStorage,
              textStorage === self.textStorage else { return }
        
        // Update gutter when text changes
        _gutterView?.needsDisplay = true
        
        // Apply syntax highlighting to the edited range if enabled
        if isSyntaxHighlightingEnabled {
            let editedRange = textStorage.editedRange
            if editedRange.location != NSNotFound {
                applySyntaxHighlighting(in: editedRange)
            }
        }
    }

    private func applySyntaxHighlighting() {
        guard isSyntaxHighlightingEnabled,
              let textStorage = textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        applySyntaxHighlighting(in: fullRange)
    }

    private func applySyntaxHighlighting(in range: NSRange) {
        guard let textStorage = textStorage,
              range.location != NSNotFound else { return }
        
        let text = textStorage.string
        guard !text.isEmpty else { return }
        
        // Ensure range is within bounds
        let safeRange = NSRange(
            location: min(range.location, textStorage.length),
            length: min(range.length, textStorage.length - min(range.location, textStorage.length))
        )
        
        guard safeRange.length > 0 else { return }
        
        // Expand range to include full lines for better highlighting
        let expandedRange = (text as NSString).lineRange(for: safeRange)
        
        // Ensure expanded range is also within bounds
        let safeExpandedRange = NSRange(
            location: expandedRange.location,
            length: min(expandedRange.length, textStorage.length - expandedRange.location)
        )
        
        guard safeExpandedRange.length > 0 else { return }
        
        // Get substring for the range
        let substring = (text as NSString).substring(with: safeExpandedRange)
        
        // Get highlighted tokens
        let tokens = syntaxHighlighter.highlight(source: substring, language: language)
        
        // Apply highlighting
        textStorage.beginEditing()
        
        // Remove existing foreground colors in the range
        textStorage.removeAttribute(.foregroundColor, range: safeExpandedRange)
        
        // If no tokens, ensure text has a default color
        if tokens.isEmpty {
            textStorage.addAttribute(.foregroundColor, value: textColor ?? NSColor.labelColor, range: safeExpandedRange)
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
                  adjustedRange.location + adjustedRange.length <= textStorage.length else { continue }
            
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
            if adjustedRange.location >= 0 &&
               adjustedRange.length > 0 &&
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
                textStorage.addAttribute(.foregroundColor, value: textColor ?? NSColor.labelColor, range: gapRange)
            }
            currentLocation = range.location + range.length
        }
        
        // Fill any remaining gap at the end
        let endOfRange = safeExpandedRange.location + safeExpandedRange.length
        if currentLocation < endOfRange {
            let gapRange = NSRange(location: currentLocation, length: endOfRange - currentLocation)
            textStorage.addAttribute(.foregroundColor, value: textColor ?? NSColor.labelColor, range: gapRange)
        }
        
        textStorage.endEditing()
    }

    private func removeSyntaxHighlighting() {
        guard let textStorage = textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        
        // Restore default text color
        textStorage.addAttribute(.foregroundColor, value: textColor ?? NSColor.labelColor, range: fullRange)
    }

    // MARK: - Line Numbers and Gutter

    private func updateGutterVisibility() {
        if showsLineNumbers {
            createGutterIfNeeded()
        } else {
            removeGutter()
        }
    }

    private func createGutterIfNeeded() {
        guard _gutterView == nil else { return }
        
        let gutter = STGutterView()
        gutter.textView = self
        gutter.autoresizingMask = [.height]  // Only resize height, not width
        
        // Add gutter directly to the text view since we might not be in a scroll view
        // Position it at the front so it doesn't get covered
        addSubview(gutter, positioned: .above, relativeTo: nil)
        
        _gutterView = gutter
        updateGutterFrame()
    }

    private func removeGutter() {
        _gutterView?.removeFromSuperview()
        _gutterView = nil
    }

    private var isUpdatingGutter = false
    
    private func updateGutterFrame() {
        guard let gutter = _gutterView else { return }
        guard !isUpdatingGutter else { return } // Prevent recursion
        
        isUpdatingGutter = true
        defer { isUpdatingGutter = false }
        
        // Set the gutter frame to match the text view's visible area
        let gutterWidth: CGFloat = 60
        gutter.frame = NSRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: bounds.height
        )
        
        // Update text container inset to make room for gutter
        textContainerInset = NSSize(width: gutterWidth + 8, height: textContainerInset.height)
        
        // Don't update text container size here - let NSTextView handle it
        
        gutter.needsDisplay = true
    }

    // MARK: - Line Highlighting

    @objc func handleTextViewDidChangeSelection(_ notification: Notification) {
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
        guard lineHighlightView == nil else { return }
        
        let highlight = NSView()
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = selectedLineHighlightColor.cgColor
        
        // Add as background overlay
        addSubview(highlight, positioned: .below, relativeTo: nil)
        lineHighlightView = highlight
    }

    private func removeLineHighlight() {
        lineHighlightView?.removeFromSuperview()
        lineHighlightView = nil
    }

    private func updateLineHighlightFrame() {
        guard let highlightView = lineHighlightView else { return }
        
        let selectedRange = self.selectedRange()
        let layoutManager = self.layoutManager
        let textContainer = self.textContainer
        
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }
        
        // Get the line range for the selection
        let lineRange = (string as NSString).lineRange(for: selectedRange)
        
        // Get the rect for the line
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Adjust frame
        var frame = lineRect
        frame.origin.x = 0
        frame.size.width = bounds.width
        frame.origin.y += textContainerInset.height
        
        highlightView.frame = frame
        highlightView.layer?.backgroundColor = selectedLineHighlightColor.cgColor
    }

    // MARK: - Layout Manager Settings

    private func updateLayoutManagerSettings() {
        if let layoutManager = layoutManager {
            layoutManager.showsInvisibleCharacters = showsInvisibleCharacters
        }
    }

    // MARK: - Annotations Support

    /// Add an annotation to the text view
    public func addAnnotation(_ annotation: STAnnotation) {
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
    public var allAnnotations: [STAnnotation] {
        return annotations
    }

    private func updateAnnotationView(for annotation: STAnnotation) {
        // Remove existing view if any
        annotationViews[annotation.id]?.removeFromSuperview()
        
        // Create new annotation view using data source
        guard annotationsDataSource != nil else { return }
        
        // Convert NSTextRange to location for compatibility
        let location = annotation.range.location
        
        // Calculate frame for annotation
        _ = calculateAnnotationFrame(for: location)
        
        // Skip creating annotation view for now - this needs more work
        // TODO: Implement proper annotation system without plugin dependencies
        /*
        if let annotationView = dataSource.textView(self, viewForLineAnnotation: annotation, textLineFragment: mockFragment, proposedViewFrame: annotationFrame) {
            addSubview(annotationView)
            annotationViews[annotation.id] = annotationView
        }
        */
    }

    private func calculateAnnotationFrame(for location: NSTextLocation) -> CGRect {
        // Simple frame calculation - can be enhanced
        return CGRect(x: bounds.maxX - 200, y: 0, width: 200, height: 20)
    }

    // MARK: - Text Changes

    public override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        
        // Update syntax highlighting for the affected area
        if isSyntaxHighlightingEnabled {
            let range = replacementRange.location != NSNotFound ? replacementRange : selectedRange()
            applySyntaxHighlighting(in: range)
        }
    }

    // MARK: - Layout

    public override func layout() {
        super.layout()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()
    }
    
    public override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateGutterFrame()
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateGutterFrame()
    }

    private func updateAnnotationViews() {
        // Update all annotation view positions
        for annotation in annotations {
            updateAnnotationView(for: annotation)
        }
    }

    // MARK: - Convenience Methods

    /// Set the programming language for syntax highlighting
    public func setLanguage(fileExtension: String) {
        language = syntaxHighlighter.detectLanguage(from: fileExtension)
    }

    /// Get all supported file extensions for syntax highlighting
    public var supportedFileExtensions: [String] {
        return syntaxHighlighter.supportedFileExtensions
    }
    
    /// Get the visible range of text in the text view
    public func visibleRange() -> NSRange {
        if let scrollView = enclosingScrollView {
            let visibleRect = scrollView.contentView.visibleRect
            
            // Convert visible rect to text range
            if let layoutManager = layoutManager,
               let textContainer = textContainer {
                
                let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
                return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            }
        }
        
        // Fallback to entire text range
        return NSRange(location: 0, length: string.count)
    }
}

// MARK: - Mock Text Line Fragment for Compatibility

private class MockTextLineFragment {
    // Minimal implementation for compatibility with existing annotation system
}

// MARK: - Additional STTextView Methods

extension STTextView {
    
    // Removed problematic textContainer override that was blocking text container setup
    
    public var widthTracksTextView: Bool {
        get {
            return super.textContainer?.widthTracksTextView ?? false
        }
        set {
            super.textContainer?.widthTracksTextView = newValue
        }
    }
    
    public override var isHorizontallyResizable: Bool {
        get {
            return super.isHorizontallyResizable
        }
        set {
            super.isHorizontallyResizable = newValue
        }
    }
    
    public var heightTracksTextView: Bool {
        get {
            return super.textContainer?.heightTracksTextView ?? true
        }
        set {
            super.textContainer?.heightTracksTextView = newValue
        }
    }
    
    public override var isVerticallyResizable: Bool {
        get {
            return super.isVerticallyResizable
        }
        set {
            super.isVerticallyResizable = newValue
        }
    }
    
    public var text: String? {
        get {
            return string
        }
        set {
            print("STTextView text setter: Setting text to '\(newValue ?? "nil")'")
            print("STTextView text setter: Current string length = \(string.count)")
            string = newValue ?? ""
            print("STTextView text setter: After setting, string length = \(string.count)")
            print("STTextView text setter: textStorage length = \(textStorage?.length ?? -1)")
        }
    }
    
    public var attributedText: NSAttributedString? {
        get {
            return textStorage
        }
        set {
            if let newValue = newValue {
                textStorage?.setAttributedString(newValue)
            } else {
                string = ""
            }
        }
    }
    
    public var textSelection: NSRange {
        get {
            return selectedRange()
        }
        set {
            setSelectedRange(newValue)
        }
    }
    
    public var gutterView: STGutterView? {
        return _gutterView
    }
    
    public override func toggleRuler(_ sender: Any?) {
        showsLineNumbers.toggle()
    }
    
    public func shouldChangeText(in affectedTextRange: NSTextRange, replacementString: String?) -> Bool {
        // Convert NSTextRange to NSRange for NSTextView compatibility
        // This is a simplified implementation
        return true
    }
    
    public func replaceCharacters(in range: NSTextRange, with string: String) {
        // Convert NSTextRange to NSRange for NSTextView compatibility
        // This is a simplified implementation
        if let textStorage = textStorage {
            // For now, replace at current selection
            let selectedRange = self.selectedRange()
            textStorage.replaceCharacters(in: selectedRange, with: string)
        }
    }
    
    /// Custom notification for STTextView selection changes
    public static let stTextViewDidChangeSelectionNotification = NSNotification.Name("STTextViewDidChangeSelectionNotification")
}