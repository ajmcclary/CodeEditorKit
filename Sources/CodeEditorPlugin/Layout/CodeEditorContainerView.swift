import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

/// A ruler view that displays line numbers for macOS
@MainActor
private class LineNumberRulerView: NSRulerView {
    // MARK: - Properties
    
    /// The text view this ruler is associated with
    public weak var textView: NSTextView?
    
    /// Font for line numbers
    public var font: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    
    /// Text color for line numbers
    public var textColor: NSColor = NSColor.secondaryLabelColor
    
    /// Background color
    public var backgroundColor: NSColor = NSColor.controlBackgroundColor
    
    /// Right padding for line numbers
    public var rightPadding: CGFloat = 8.0
    
    // MARK: - Initialization
    
    public override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        self.clientView = scrollView?.documentView
        self.ruleThickness = 40.0 // Default width, matches our gutter width
        self.clipsToBounds = true // Prevent drawing outside bounds
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Drawing
    
    public override func drawHashMarksAndLabels(in rect: NSRect) {
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
            print("📍 At top: range=\(characterRange)")
        }
        if characterRange.location + characterRange.length >= textLength && textLength > 0 {
            print("📍 At bottom: range=\(characterRange), textLength=\(textLength)")
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
            // Use NSString for counting newlines - more reliable with NSRange
            let nsString = text as NSString
            var count = 0
            var searchRange = NSRange(location: 0, length: validLocation)
            
            while searchRange.length > 0 && searchRange.location < nsString.length {
                // Ensure search range is valid
                let safeLength = min(searchRange.length, nsString.length - searchRange.location)
                let safeRange = NSRange(location: searchRange.location, length: safeLength)
                
                let newlineRange = nsString.rangeOfCharacter(from: .newlines, options: [], range: safeRange)
                if newlineRange.location != NSNotFound {
                    count += 1
                    let nextStart = newlineRange.location + newlineRange.length
                    if nextStart < validLocation && nextStart < nsString.length {
                        searchRange = NSRange(location: nextStart, length: validLocation - nextStart)
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
            lineNumber += count
        }
        
        // Process visible range
        var currentLocation = validLocation
        let endLocation = min(validLocation + validLength, textLength)
        
        while currentLocation < endLocation {
            // Find the end of the current line
            var lineEndLocation = currentLocation
            
            // Search for line ending
            if currentLocation < textLength {
                // Use NSString for more reliable range operations
                let nsString = text as NSString
                let nsLength = nsString.length
                
                // Ensure we don't exceed NSString bounds
                if currentLocation < nsLength {
                    let searchLength = min(textLength - currentLocation, nsLength - currentLocation)
                    let searchRange = NSRange(location: currentLocation, length: searchLength)
                    
                    let newlineRange = nsString.rangeOfCharacter(from: .newlines, options: [], range: searchRange)
                    
                    if newlineRange.location != NSNotFound {
                        // Found a newline
                        lineEndLocation = min(newlineRange.location + newlineRange.length, textLength)
                    } else {
                        // No more newlines, this is the last line
                        lineEndLocation = textLength
                    }
                } else {
                    // Current location exceeds NSString bounds
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
                print("⚠️ Invalid range detected: currentLocation=\(currentLocation) > lineEndLocation=\(lineEndLocation)")
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
    
    public func updateWidth(for maxLineNumber: Int) {
        let testString = String(repeating: "9", count: "\(maxLineNumber)".count)
        let size = testString.size(withAttributes: [.font: font])
        ruleThickness = size.width + rightPadding * 2
    }
    
}

#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform container view that holds the text view, gutter view, and minimap
/// This allows the gutter and minimap to remain fixed while the text view scrolls
@MainActor
public final class CodeEditorContainerView: PlatformView {
    // MARK: - Properties
    
    public let textView: CodeEditorView
    public let gutterView: GutterView
    public let minimapView: MinimapView
    private var minimapDataProvider: MinimapDataProvider?
    
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
            applyConfiguration()
        }
    }
    
    // MARK: - Initialization
    
    override public init(frame: CGRect) {
        // Create the text view
        textView = CodeEditorView(frame: .zero)
        
        // Create the gutter view
        gutterView = GutterView(frame: .zero)
        
        // Create the minimap view
        minimapView = MinimapView(frame: .zero)
        
        #if canImport(UIKit)
        // Create the content view for iOS
        contentView = EditorContentView(frame: CGRect.zero)
        #else
        // Create scroll view for macOS
        scrollView = NSScrollView(frame: NSRect.zero)
        #endif
        
        super.init(frame: frame)
        
        setupViews()
        setupObservers()
    }
    
    public required init?(coder: NSCoder) {
        // Create the text view
        textView = CodeEditorView(frame: .zero)
        
        // Create the gutter view
        gutterView = GutterView(frame: .zero)
        
        // Create the minimap view
        minimapView = MinimapView(frame: .zero)
        
        #if canImport(UIKit)
        // Create the content view for iOS
        contentView = EditorContentView(frame: CGRect.zero)
        #else
        // Create scroll view for macOS
        scrollView = NSScrollView(frame: NSRect.zero)
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
        
        // Set up scroll delegate for minimap updates
        // CodeEditorView inherits from UIScrollView on iOS
        textView.delegate = self
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
        
        // Set up scroll observer to update minimap
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
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
        if lineNumber > 0 {
            // Add 1 for the newline character
            let targetPosition = lineStart + 1
            textView.setSelectedRange(NSRange(location: targetPosition, length: 0))
            textView.scrollRangeToVisible(NSRange(location: targetPosition, length: 0))
        } else {
            // First line
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
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
                textView.selectedTextRange = textView.textRange(from: position, to: position)
                
                // Scroll to make the line visible
                let rect = textView.caretRect(for: position)
                textView.scrollRectToVisible(rect, animated: true)
            }
        } else {
            // First line
            textView.selectedTextRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument)
            textView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
        }
        #endif
    }
    
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
        
        // Get the text view's content size
        let contentSize = textView.contentSize
        
        // Position content view to fill the container
        contentView.frame = bounds
        
        // Position gutter on the left - it should match content height, not bounds
        gutterView.frame = CGRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: max(bounds.height, contentSize.height + textView.contentInset.top + textView.contentInset.bottom)
        )
        
        // Position minimap on the right
        if configuration.display.showMinimap {
            minimapView.frame = CGRect(
                x: bounds.width - minimapWidth,
                y: 0,
                width: minimapWidth,
                height: max(bounds.height, contentSize.height + textView.contentInset.top + textView.contentInset.bottom)
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
        textView.contentInset = contentInsets.uiEdgeInsets
        
        // Also adjust the scroll indicator insets
        textView.scrollIndicatorInsets = textView.contentInset
        
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
    public func scrollViewDidScroll(_: UIScrollView) {
        // Update minimap when text view scrolls
        updateMinimap()
    }
}
#endif
