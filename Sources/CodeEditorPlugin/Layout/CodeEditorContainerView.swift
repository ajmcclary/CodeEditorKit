import Foundation
import os.log
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

/// A ruler view that displays line numbers for macOS
@MainActor
private class LineNumberRulerView: NSRulerView {
    // MARK: - Properties
    
    /// The text view this ruler is associated with
    weak var textView: NSTextView?
    
    /// Font for line numbers
    var font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    
    /// Text color for line numbers
    var textColor = NSColor.secondaryLabelColor
    
    /// Background color
    var backgroundColor = NSColor.controlBackgroundColor
    
    /// Right padding for line numbers
    var rightPadding: CGFloat = 8.0
    
    // MARK: - Initialization
    
    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        self.clientView = scrollView?.documentView
        self.ruleThickness = 50.0 // Increased width to accommodate folding controls
        self.clipsToBounds = true // Prevent drawing outside bounds
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Drawing
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        // Fill background
        backgroundColor.set()
        rect.fill()
        
        guard let textView = self.clientView as? NSTextView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }
        
        // Get the visible rect in the text view's coordinate system
        let visibleRect = textView.visibleRect
        let textVisibleRect = textView.convert(visibleRect, from: textView.superview)
        
        // Get the range of characters that are visible
        let glyphRange = layoutManager.glyphRange(forBoundingRect: textVisibleRect, in: textContainer)
        var characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        // Ensure the character range doesn't exceed the text length
        let textLength = textStorage.length
        
        // Fix for scrolling to bottom: ensure we never go beyond text bounds
        if characterRange.location >= textLength {
            // If we're beyond the text, show the last line
            characterRange = NSRange(location: max(0, textLength - 1), length: 1)
        } else if characterRange.location + characterRange.length > textLength {
            // Trim the length to not exceed bounds
            characterRange.length = textLength - characterRange.location
        }
        
        // Handle empty text
        if textLength == 0 {
            characterRange = NSRange(location: 0, length: 0)
        }
        
        // Calculate line numbers for the visible range
        let text = textStorage.string
        
        // Debug info
        #if DEBUG
        if characterRange.location == 0 {
            kLogger.debug("📍 At top: range=\(characterRange)")
        }
        if characterRange.location + characterRange.length >= textLength && textLength > 0 {
            kLogger.debug("📍 At bottom: range=\(characterRange), textLength=\(textLength)")
        }
        #endif
        
        let lineRanges = getLineRanges(for: text, in: characterRange)
        
        // Set up text attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        // Draw each line number
        for (lineNumber, lineRange) in lineRanges {
            // Get the rect for this line
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lineGlyphRange.location, effectiveRange: nil, withoutAdditionalLayout: true)
            
            // Convert to ruler coordinates
            let yPosition = convert(NSPoint(x: 0, y: lineRect.minY), from: textView).y
            
            // Draw the line number
            let lineNumberString = "\(lineNumber)"
            let size = lineNumberString.size(withAttributes: attributes)
            
            let drawingPoint = NSPoint(
                x: ruleThickness - size.width - rightPadding,
                y: yPosition + (lineRect.height - size.height) / 2
            )
            
            lineNumberString.draw(at: drawingPoint, withAttributes: attributes)
            
            // Draw folding control if this line is foldable
            if let codeEditorView = textView as? CodeEditorView,
               codeEditorView.configuration.display.enableCodeFolding &&
               codeEditorView.configuration.display.showFoldingControls &&
               codeEditorView.isFoldable(at: lineNumber) {
                drawFoldingControl(
                    for: lineNumber,
                    at: yPosition,
                    lineHeight: lineRect.height,
                    in: codeEditorView
                )
            }
        }
        
        // Draw a separator line on the right edge
        NSColor.separatorColor.set()
        let separatorRect = NSRect(x: ruleThickness - 1, y: rect.minY, width: 1, height: rect.height)
        separatorRect.fill()
    }
    
    // MARK: - Helper Methods
    
    private func getLineRanges(for text: String, in range: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Validate range bounds
        let textLength = text.utf16.count
        guard textLength > 0 else { return lineRanges }
        
        // Clamp range to valid bounds
        let validLocation = max(0, min(range.location, textLength))
        let validLength = min(range.length, textLength - validLocation)
        
        // Handle empty range
        guard validLength > 0 || validLocation < textLength else {
            return lineRanges
        }
        
        // Count lines before the visible range
        if validLocation > 0 {
            // Count newlines in the prefix
            let beforeRange = NSRange(location: 0, length: validLocation)
            if let beforeString = Range(beforeRange, in: text) {
                let substring = text[beforeString]
                lineNumber += substring.components(separatedBy: .newlines).count - 1
            }
        }
        
        // Process visible range
        var currentLocation = validLocation
        let endLocation = min(validLocation + validLength, textLength)
        
        while currentLocation < endLocation {
            // Find the end of the current line
            var lineEndLocation = currentLocation
            
            // Search for line ending
            if currentLocation < textLength {
                // Find next newline from current location
                let searchRange = NSRange(location: currentLocation, length: textLength - currentLocation)
                if let range = Range(searchRange, in: text) {
                    let substring = text[range]
                    if let newlineIndex = substring.firstIndex(where: { $0.isNewline }) {
                        let distance = substring.distance(from: substring.startIndex, to: newlineIndex)
                        lineEndLocation = currentLocation + distance + 1  // +1 to include the newline
                    } else {
                        // No more newlines, this is the last line
                        lineEndLocation = textLength
                    }
                } else {
                    lineEndLocation = textLength
                }
            } else {
                // Already at the end
                lineEndLocation = textLength
            }
            
            // Ensure line end doesn't go beyond text bounds
            lineEndLocation = min(lineEndLocation, textLength)
            
            // Create range for this line (ensure valid length)
            let lineLength = max(0, lineEndLocation - currentLocation)
            
            // Debug check before creating NSRange
            if currentLocation > lineEndLocation {
                kLogger.debug("⚠️ Invalid range detected: currentLocation=\(currentLocation) > lineEndLocation=\(lineEndLocation)")
                // Skip this invalid range
                currentLocation = lineEndLocation
                continue
            }
            
            let lineRange = NSRange(location: currentLocation, length: lineLength)
            lineRanges.append((lineNumber, lineRange))
            
            // Move to next line
            lineNumber += 1
            currentLocation = lineEndLocation
            
            // Stop if we've reached the end of the visible range or text
            if currentLocation >= endLocation || currentLocation >= textLength {
                break
            }
        }
        
        return lineRanges
    }
    
    // MARK: - Width Calculation
    
    func updateWidth(for maxLineNumber: Int) {
        let testString = String(repeating: "9", count: "\(maxLineNumber)".count)
        let size = testString.size(withAttributes: [.font: font])
        
        // Add space for folding controls if enabled
        var baseWidth = size.width + rightPadding * 2
        if let textView = self.clientView as? CodeEditorView,
           textView.configuration.display.enableCodeFolding &&
           textView.configuration.display.showFoldingControls {
            baseWidth += textView.configuration.layout.foldingControlSize + textView.configuration.layout.foldingControlPadding * 2
        }
        
        ruleThickness = baseWidth
    }
    
    // MARK: - Folding Controls
    
    private func drawFoldingControl(for lineNumber: Int, at yPosition: CGFloat, lineHeight: CGFloat, in textView: CodeEditorView) {
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        
        // Position control on the left side
        let xPosition = controlPadding
        let controlY = yPosition + (lineHeight - controlSize) / 2
        
        let controlRect = NSRect(x: xPosition, y: controlY, width: controlSize, height: controlSize)
        
        // Draw background circle
        let backgroundPath = NSBezierPath(ovalIn: controlRect)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.2).setFill()
        backgroundPath.fill()
        
        // Draw border
        NSColor.tertiaryLabelColor.setStroke()
        backgroundPath.lineWidth = 0.5
        backgroundPath.stroke()
        
        // Check if folded
        let isFolded = textView.isFolded(at: lineNumber)
        
        // Draw the triangle icon
        drawFoldingIcon(in: controlRect.insetBy(dx: controlSize * 0.25, dy: controlSize * 0.25), isFolded: isFolded)
    }
    
    private func drawFoldingIcon(in rect: NSRect, isFolded: Bool) {
        let path = NSBezierPath()
        
        NSColor.labelColor.setFill()
        
        if isFolded {
            // Right-pointing triangle (▶️)
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
            path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        } else {
            // Down-pointing triangle (▼)
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
            path.line(to: NSPoint(x: rect.midX, y: rect.maxY))
        }
        
        path.close()
        path.fill()
    }
    
    // MARK: - Click Handling
    
    override func mouseDown(with event: NSEvent) {
        guard let textView = self.clientView as? CodeEditorView else {
            super.mouseDown(with: event)
            return
        }
        
        let localPoint = convert(event.locationInWindow, from: nil)
        
        // Check if click is on a folding control
        if handleFoldingControlClick(at: localPoint, in: textView) {
            return
        }
        
        super.mouseDown(with: event)
    }
    
    private func handleFoldingControlClick(at point: NSPoint, in textView: CodeEditorView) -> Bool {
        guard textView.configuration.display.enableCodeFolding &&
              textView.configuration.display.showFoldingControls else {
            return false
        }
        
        // Find which line was clicked
        guard let lineNumber = findLineNumber(at: point, in: textView) else {
            return false
        }
        
        // Check if this line is foldable
        guard textView.isFoldable(at: lineNumber) else {
            return false
        }
        
        // Check if click is within folding control area
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        
        if point.x <= controlPadding + controlSize {
            // Toggle folding
            _ = textView.toggleFold(at: lineNumber)
            setNeedsDisplay(bounds)
            return true
        }
        
        return false
    }
    
    private func findLineNumber(at point: NSPoint, in textView: NSTextView) -> Int? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return nil
        }
        
        // Convert point to text view coordinates
        let textPoint = convert(point, to: textView)
        
        // Find the character index at this point
        let index = layoutManager.characterIndex(for: textPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if index < textView.string.count {
            // Count lines up to this index
            let text = textView.string
            let substring = String(text.prefix(index))
            return substring.components(separatedBy: .newlines).count
        }
        
        return nil
    }
}

#elseif canImport(UIKit)
import UIKit
#endif

// Local logger instance for container view
private let kLogger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorContainerView")

/// Cross-platform container view that holds the text view, gutter view, and minimap
/// This allows the gutter and minimap to remain fixed while the text view scrolls
@MainActor
public final class CodeEditorContainerView: PlatformView {
    // MARK: - Properties
    
    public let textView: CodeEditorView
    public let gutterView: GutterView
    public let minimapView: MinimapView
    private var minimapDataProvider: MinimapDataProvider?
    private var isApplyingConfiguration = false
    
    #if canImport(UIKit)
    public let contentView: EditorContentView
    private var keyboardObservers: [NSObjectProtocol] = []
    private nonisolated(unsafe) var keyboardObserversForDeinit: [NSObjectProtocol] = []
    private var keyboardHeight: CGFloat = 0
    #else
    public let scrollView: NSScrollView
    #endif
    
    /// Configuration for the editor
    public var configuration: EditorConfiguration = .default {
        didSet {
            // Prevent recursive configuration updates
            if !isApplyingConfiguration {
                applyConfiguration()
            }
        }
    }
    
    // MARK: - Initialization
    
    override public init(frame: CGRect) {
        // Use the provided frame or a reasonable default size
        let initialFrame = frame == .zero ? CGRect(x: 0, y: 0, width: 600, height: 400) : frame
        
        // Create the text view with reasonable initial frame
        textView = CodeEditorView(frame: initialFrame)
        
        // Create the gutter view with initial width
        gutterView = GutterView(frame: CGRect(x: 0, y: 0, width: 40, height: initialFrame.height))
        
        // Create the minimap view with initial width
        minimapView = MinimapView(frame: CGRect(x: initialFrame.width - 100, y: 0, width: 100, height: initialFrame.height))
        
        #if canImport(UIKit)
        // Create the content view for iOS
        contentView = EditorContentView(frame: initialFrame)
        #else
        // Create scroll view for macOS
        scrollView = NSScrollView(frame: initialFrame)
        #endif
        
        super.init(frame: initialFrame)
        
        setupViews()
        setupObservers()
    }
    
    public required init?(coder: NSCoder) {
        // Use reasonable default size for coder init
        let initialFrame = CGRect(x: 0, y: 0, width: 600, height: 400)
        
        // Create the text view with reasonable initial frame
        textView = CodeEditorView(frame: initialFrame)
        
        // Create the gutter view with initial width
        gutterView = GutterView(frame: CGRect(x: 0, y: 0, width: 40, height: initialFrame.height))
        
        // Create the minimap view with initial width
        minimapView = MinimapView(frame: CGRect(x: initialFrame.width - 100, y: 0, width: 100, height: initialFrame.height))
        
        #if canImport(UIKit)
        // Create the content view for iOS
        contentView = EditorContentView(frame: initialFrame)
        #else
        // Create scroll view for macOS
        scrollView = NSScrollView(frame: initialFrame)
        #endif
        
        super.init(coder: coder)
        
        setupViews()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        setupMacOSViews()
        #else
        setupIOSViews()
        #endif
        
        // Common setup for iOS only (macOS uses ruler view)
        #if canImport(UIKit)
        gutterView.textView = textView
        gutterView.observeTextView()          // start listening for changes
        #endif
        
        setupMinimap()
        
        // IMPORTANT: Remove any internal gutter from text view before setting up
        textView.removeGutter()
        
        // Apply initial text container insets
        updateTextContainerInsets()
        
        // Set container background using platform colors
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS uses layer background
        wantsLayer = true
        layer?.backgroundColor = PlatformColors.systemBackground.cgColor
        #else
        backgroundColor = PlatformColors.systemBackground
        #endif
    }
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func setupMacOSViews() {
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .legacy  // Ensure scrollers are visible
        scrollView.backgroundColor = PlatformColors.systemBackground
        
        // Configure text view for scroll view
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        textView.textContainer?.heightTracksTextView = false
        textView.autoresizingMask = [.width, .height]
        
        // Set container width for non-wrapping mode
        if !configuration.layout.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        
        // Set text view as document view
        scrollView.documentView = textView
        
        // Set up line number ruler view
        let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        rulerView.textView = textView
        rulerView.ruleThickness = configuration.layout.gutterWidth
        rulerView.clipsToBounds = true // Ensure ruler doesn't draw outside bounds
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = configuration.display.showLineNumbers
        scrollView.rulersVisible = configuration.display.showLineNumbers
        
        // Add subviews (only scroll view and minimap, not gutter since it's now a ruler)
        addSubview(scrollView)
        addSubview(minimapView)
        
        // Ensure minimap is on top and has opaque background
        minimapView.wantsLayer = true
        minimapView.layer?.backgroundColor = MinimapConfiguration.defaultBackgroundColor.cgColor
        
        // Ensure text view background is transparent where gutter is
        textView.backgroundColor = PlatformColors.clear
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.drawsBackground = false
        #endif
        
        // IMPORTANT: Don't set text container inset here - let updateTextContainerInsets handle it
        // The inset will be set based on whether line numbers are shown
    }
    #endif
    
    #if canImport(UIKit)
    private func setupIOSViews() {
        // Add all views
        addSubview(contentView)
        contentView.addSubview(textView)
        addSubview(gutterView)
        addSubview(minimapView)
        
        // Connect components
        contentView.setTextView(textView)
        
        // Set up input accessory
        if configuration.behavior.isEditable {
            textView.inputAccessoryView = contentView.createInputAccessory()
        }
        
        // Ensure text view scrolls and doesn't resize with keyboard
        textView.alwaysBounceVertical = true
        textView.isScrollEnabled = true
        
        // Ensure text view background is transparent where gutter is
        textView.backgroundColor = PlatformColors.clear
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.drawsBackground = false
        #endif
        
        // Ensure gutter stays on top
        bringSubviewToFront(gutterView)
        
        // Note: The text view's delegate will be set by the SwiftUI Coordinator
        // which will forward scroll events back to us
    }
    #endif
    
    private func setupObservers() {
        #if canImport(UIKit)
        setupKeyboardObservers()
        #endif
    }
    
    private func setupMinimap() {
        // Create data provider
        minimapDataProvider = MinimapDataProvider(textView: textView)
        
        // Set up navigation callback
        minimapView.onNavigate = { [weak self] lineNumber in
            self?.navigateToLine(lineNumber)
        }
        
        // Initially hidden based on configuration
        minimapView.isHidden = !configuration.display.showMinimap
        
        // Set up text change observer to update minimap
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #else
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #endif
        
        // Set up scroll observer to update minimap and handle cursor tracking
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
                self?.handleScrollCursorTracking()
            }
        }
        #else
        // On iOS, set up scroll delegate for minimap updates
        // The textView (UITextView) handles scrolling internally
        // We'll monitor scroll changes through the delegate pattern in setupIOSViews
        #endif
    }
    
    // MARK: - Navigation
    
    private func navigateToLine(_ lineNumber: Int) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS navigation
        let text = textView.string
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber < lines.count else { return }
        
        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        let targetPosition = lineNumber > 0 ? lineStart + 1 : 0
        let targetRange = NSRange(location: targetPosition, length: 0)
        
        if configuration.behavior.autoScrollToCursor {
            // When auto-scroll is enabled, set selection and explicitly scroll
            textView.setSelectedRange(targetRange)
            
            // Use the proper macOS scrolling method
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: targetRange, actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let adjustedRect = CGRect(
                    x: rect.origin.x + textView.textContainerOrigin.x,
                    y: rect.origin.y + textView.textContainerOrigin.y,
                    width: max(rect.width, 1),
                    height: max(rect.height, 20)
                )
                textView.scrollToVisible(adjustedRect)
            }
        } else {
            // When auto-scroll is disabled, use the method that prevents scrolling
            textView.setSelectedRangeWithoutScrolling(targetRange)
        }
        #else
        // iOS navigation
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber < lines.count else { return }
        
        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        if lineNumber > 0 {
            // Add 1 for the newline character
            let targetPosition = lineStart + 1
            if let position = textView.position(from: textView.beginningOfDocument, offset: targetPosition) {
                let textRange = textView.textRange(from: position, to: position)
                
                // Use the new method that respects autoScrollToCursor configuration
                textView.setSelectedTextRangeWithoutScrolling(textRange)
                
                // Only scroll if autoScrollToCursor is enabled
                if configuration.behavior.autoScrollToCursor {
                    let rect = textView.caretRect(for: position)
                    textView.scrollRectToVisible(rect, animated: true)
                }
            }
        } else {
            // First line
            let textRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument)
            
            // Use the new method that respects autoScrollToCursor configuration
            textView.setSelectedTextRangeWithoutScrolling(textRange)
            
            // Only scroll if autoScrollToCursor is enabled
            if configuration.behavior.autoScrollToCursor {
                textView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
            }
        }
        #endif
    }
    
    // MARK: - Cursor Tracking During Scroll
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func handleScrollCursorTracking() {
        // Only auto-scroll to cursor if autoScrollToCursor is enabled
        guard configuration.behavior.autoScrollToCursor else { return }
        
        // Get current cursor position
        let currentSelection = textView.selectedRange
        guard currentSelection.length == 0 else { return } // Only work with cursor, not selections
        
        // Get cursor position information
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        let cursorPosition = currentSelection.location
        let textLength = textView.string.count
        guard cursorPosition < textLength else { return }
        
        // Calculate cursor rect
        let glyphRange = layoutManager.glyphRange(forCharacterRange: currentSelection, actualCharacterRange: nil)
        let cursorRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let adjustedCursorRect = CGRect(
            x: cursorRect.origin.x + textView.textContainerOrigin.x,
            y: cursorRect.origin.y + textView.textContainerOrigin.y,
            width: max(cursorRect.width, 1),
            height: max(cursorRect.height, 20)
        )
        
        // Check if cursor is visible in current view
        let visibleRect = textView.visibleRect
        let isVisible = visibleRect.intersects(adjustedCursorRect)
        
        // If cursor is not visible, scroll to make it visible
        if !isVisible {
            textView.scrollToVisible(adjustedCursorRect)
        }
    }
    #endif
    
    private func updateMinimap() {
        guard configuration.display.showMinimap,
              let dataProvider = minimapDataProvider,
              let data = dataProvider.generateData() else {
            return
        }
        
        minimapView.updateData(data)
    }
    
    // MARK: - Layout
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            super.layout()
            layoutViews()
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
        layoutViews()
    }
    #endif
    
    private func layoutViews() {
        // Calculate layout dimensions
        let gutterWidth = configuration.layout.gutterWidth
        let minimapWidth = configuration.display.showMinimap ? configuration.layout.minimapWidth : 0
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS layout
        
        // Position scroll view to fill entire width (ruler view is inside the scroll view)
        scrollView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width - minimapWidth,
            height: bounds.height
        )
        
        // Position minimap on the right
        if configuration.display.showMinimap {
            minimapView.frame = CGRect(
                x: bounds.width - minimapWidth,
                y: 0,
                width: minimapWidth,
                height: bounds.height
            )
            minimapView.isHidden = false
            
            // When minimap is shown, we need to constrain the text view
            if !configuration.layout.wrapLines {
                // Force the scroll view to update its content view
                scrollView.contentView.frame = scrollView.bounds
                
                // Get the actual content width (scroll view width minus ruler if present)
                let contentWidth = scrollView.contentView.bounds.width
                
                // Remove width from autoresizing mask so text view doesn't expand beyond scroll view
                textView.autoresizingMask = [.height]
                
                // Text view should not be horizontally resizable when minimap is shown
                textView.isHorizontallyResizable = false
                
                // Set a fixed frame for the text view that matches the content width
                textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: textView.frame.height)
                
                // Set text container to match the content width minus gutters
                let textWidth = contentWidth - configuration.layout.gutterWidth - configuration.layout.lineNumberPadding
                textView.textContainer?.containerSize = NSSize(
                    width: textWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
                
                // Ensure the text container tracks the text view width
                textView.textContainer?.widthTracksTextView = true
                
                // Force layout update
                textView.needsDisplay = true
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            minimapView.isHidden = true
            
            // Restore normal behavior when minimap is hidden
            if !configuration.layout.wrapLines {
                // Restore autoresizing mask
                textView.autoresizingMask = [.width, .height]
                
                // Restore horizontal resizability
                textView.isHorizontallyResizable = true
                
                // Restore infinite width
                textView.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
                
                // Text container should not track width when not wrapping
                textView.textContainer?.widthTracksTextView = false
            }
        }
        #else
        // iOS layout
        
        // Position content view to fill the container
        contentView.frame = bounds
        
        // Position gutter on the left - fixed position
        gutterView.frame = CGRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: bounds.height
        )
        
        // Position minimap on the right - fixed position
        if configuration.display.showMinimap {
            minimapView.frame = CGRect(
                x: bounds.width - minimapWidth,
                y: 0,
                width: minimapWidth,
                height: bounds.height
            )
            minimapView.isHidden = false
        } else {
            minimapView.isHidden = true
        }
        
        // Position text view within content view to take remaining space between gutter and minimap
        let textViewWidth = bounds.width - minimapWidth
        textView.frame = CGRect(
            x: 0,  // Text view starts at 0, but has inset for gutter
            y: 0,
            width: textViewWidth,
            height: bounds.height
        )
        
        // Ensure content insets are maintained
        updateContentInsets()
        #endif
        
        // Force gutter to update when layout changes
        gutterView.setNeedsDisplayLineNumbers()
        
        // Update minimap if shown
        if configuration.display.showMinimap {
            updateMinimap()
        }
    }
    
    // MARK: - Text Container Insets
    
    private func updateTextContainerInsets() {
        let padding = configuration.layout.lineNumberPadding
        let gutterWidth = configuration.display.showLineNumbers ? configuration.layout.gutterWidth : 0
        let minimapWidth = configuration.display.showMinimap ? configuration.layout.minimapWidth : 0
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, we need to set inset to account for the ruler view and minimap
        // Note: We don't add right inset for minimap on macOS because the scroll view
        // width is already adjusted. The text view needs to fill the scroll view.
        let currentInsets = textView.textContainerInset
        textView.textContainerInset = NSSize(
            width: gutterWidth + padding,
            height: currentInsets.height
        )
        #else
        // On iOS/Catalyst, update edge insets
        let currentInsets = textView.textContainerEdgeInsets
        let newInsets = EdgeInsets(
            top: currentInsets.top,
            left: gutterWidth + padding,
            bottom: currentInsets.bottom,
            right: minimapWidth + padding
        )
        textView.setTextContainerEdgeInsets(newInsets)
        #endif
    }
    
    // MARK: - Configuration
    
    /// Updates whether line numbers are shown
    public var showsLineNumbers: Bool = false {
        didSet {
            gutterView.isHidden = !showsLineNumbers
            updateTextContainerInsets()
            
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            needsLayout = true
            #else
            setNeedsLayout()
            #endif
        }
    }
    
    public func applyConfiguration() {
        // Prevent re-entrant calls
        guard !isApplyingConfiguration else { return }
        isApplyingConfiguration = true
        defer { isApplyingConfiguration = false }
        
        // Apply configuration to text view, but disable its internal line numbers
        // since we manage the gutter externally
        var textViewConfig = configuration
        textViewConfig.display.showLineNumbers = false
        
        // First remove any existing internal gutter from text view
        textView.removeGutter()
        
        // Then apply the configuration with line numbers disabled
        textView.configuration = textViewConfig
        
        // Update our own properties based on configuration
        showsLineNumbers = configuration.display.showLineNumbers
        
        // Update minimap visibility
        minimapView.isHidden = !configuration.display.showMinimap
        
        // Update scroll view settings on macOS
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        
        // Update ruler visibility and settings
        scrollView.hasVerticalRuler = configuration.display.showLineNumbers
        scrollView.rulersVisible = configuration.display.showLineNumbers
        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.ruleThickness = configuration.layout.gutterWidth
            rulerView.clipsToBounds = true
            rulerView.needsDisplay = true
        }
        // Don't set horizontal resizability here - it will be handled in layoutViews
        // based on minimap visibility
        if !configuration.display.showMinimap {
            textView.isHorizontallyResizable = !configuration.layout.wrapLines
            textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        }
        
        if !configuration.layout.wrapLines && !configuration.display.showMinimap {
            // Only set infinite width if minimap is not shown
            // When minimap is shown, layoutViews will handle the sizing
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        
        #endif
        
        // Update text container insets when configuration changes (for all platforms)
        updateTextContainerInsets()
        
        // Force layout update
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsLayout = true
        layout() // Force immediate layout on macOS
        #else
        setNeedsLayout()
        layoutIfNeeded()
        #endif
        
        // Update minimap if it's now visible
        if configuration.display.showMinimap {
            updateMinimap()
        }
        
        // Force redraw of all subviews
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsDisplay = true
        scrollView.needsDisplay = true
        textView.needsDisplay = true
        #else
        setNeedsDisplay()
        #endif
    }
    
    // MARK: - Platform-Specific Extensions
    
    #if canImport(UIKit)
    // iOS-specific keyboard handling and content insets
    private func setupKeyboardObservers() {
        // Listen for keyboard notifications
        let willShow = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract data from notification before entering Task
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            
            Task { @MainActor in
                self.handleKeyboardWillShow(keyboardFrame: keyboardFrame, duration: duration)
            }
        }
        
        let willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract data from notification before entering Task
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            
            Task { @MainActor in
                self.handleKeyboardWillHide(duration: duration)
            }
        }
        
        keyboardObservers = [willShow, willHide]
        keyboardObserversForDeinit = keyboardObservers
    }
    
    private func handleKeyboardWillShow(keyboardFrame: CGRect?, duration: Double?) {
        guard let keyboardFrame,
              let duration else {
            return
        }
        
        // Convert keyboard frame to our coordinate system
        let convertedFrame = convert(keyboardFrame, from: nil)
        keyboardHeight = bounds.maxY - convertedFrame.minY
        
        // Adjust text view content inset instead of resizing
        UIView.animate(withDuration: duration) {
            self.updateContentInsets()
        }
    }
    
    private func handleKeyboardWillHide(duration: Double?) {
        guard let duration else {
            return
        }
        
        keyboardHeight = 0
        
        UIView.animate(withDuration: duration) {
            self.updateContentInsets()
        }
    }
    
    private func updateContentInsets() {
        // Adjust the text view's content inset to account for keyboard
        // This keeps the content scrollable without compressing the view
        let bottomInset = keyboardHeight > 0 ? keyboardHeight : 0
        
        let contentInsets = EdgeInsets(
            top: 0,
            left: 0,
            bottom: bottomInset,
            right: 0
        )
        
        // Only update if insets have actually changed to prevent unnecessary scroll jumps
        let newInsets = contentInsets.uiEdgeInsets
        if textView.contentInset != newInsets {
            // Save current scroll position
            let savedContentOffset = textView.contentOffset
            
            textView.contentInset = newInsets
            
            // Also adjust the scroll indicator insets
            textView.scrollIndicatorInsets = textView.contentInset
            
            // Restore scroll position if it changed
            if textView.contentOffset != savedContentOffset {
                textView.setContentOffset(savedContentOffset, animated: false)
            }
        }
        
        // Make sure the gutter redraws with proper positioning
        gutterView.setNeedsDisplay()
        
        // If keyboard is showing, ensure we can still scroll to see all content
        if keyboardHeight > 0 {
            // Adjust content size if needed to ensure full scrolling
            let minContentHeight = bounds.height - keyboardHeight + textView.contentSize.height
            if textView.contentSize.height < minContentHeight {
                textView.contentSize = CGSize(width: textView.contentSize.width, height: minContentHeight)
            }
        }
    }
    
    private func cleanupKeyboardObservers() {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObservers.removeAll()
        keyboardObserversForDeinit = keyboardObservers
    }
    #endif
    
    deinit {
        #if canImport(UIKit)
        // Perform cleanup synchronously to avoid capturing self after deinit begins
        keyboardObserversForDeinit.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObserversForDeinit.removeAll()
        #endif
        
        // Remove any selector-based observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIScrollViewDelegate

#if canImport(UIKit)
extension CodeEditorContainerView: UITextViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update minimap when text view scrolls
        updateMinimap()
        
        // Don't move the gutter view - keep it fixed in position
        // The gutter will adjust its drawing based on the text view's scroll offset
        
        // Notify the gutter view to update line numbers
        gutterView.setNeedsDisplayLineNumbers()
        
        // Call the gutter's scroll method directly to activate display link
        gutterView.scrollViewDidScroll(scrollView)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Start updating line numbers when scrolling begins
        // This helps activate the display link earlier for smoother updates
        gutterView.scrollViewWillBeginDragging(scrollView)
    }
    
    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        // Continue updating if decelerating
        if !decelerate {
            // Scrolling has stopped, ensure final update
            gutterView.setNeedsDisplayLineNumbers()
        }
    }
    
    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        // Scrolling has completely stopped
        gutterView.setNeedsDisplayLineNumbers()
    }
}
#endif
