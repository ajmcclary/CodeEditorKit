import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
/// A ruler view that displays line numbers for macOS
@MainActor
class LineNumberRulerView: NSRulerView {
    // MARK: - Properties

    /// The text view this ruler is associated with
    weak var textView: NSTextView?

    /// Font for line numbers
    var font = PlatformFonts.monospacedSystemFont(ofSize: 11, weight: .regular)

    /// Text color for line numbers
    var textColor = PlatformColors.secondaryLabel

    /// Background color
    var backgroundColor = PlatformColors.controlBackground

    /// Right padding for line numbers
    var rightPadding: CGFloat = 8.0

    /// Track last vertical scroll position to avoid unnecessary redraws
    private var lastScrollY: CGFloat = 0

    // MARK: - Initialization

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        self.clientView = scrollView?.documentView
        self.ruleThickness = 50.0 // Increased width to accommodate folding controls
        self.clipsToBounds = true // Prevent drawing outside bounds

        // Observe scroll view changes to ensure line numbers update
        if let scrollView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )

            // Also observe frame changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll(_:)),
                name: NSView.frameDidChangeNotification,
                object: scrollView.contentView
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func scrollViewDidScroll(_: Notification) {
        // Only redraw if we're scrolling vertically
        // Horizontal scrolling shouldn't require line number updates
        guard let scrollView = self.scrollView else {
            setNeedsDisplay(bounds)
            return
        }

        // Check if this is a vertical scroll by comparing the previous and current Y positions
        let currentY = scrollView.contentView.bounds.origin.y
        if !lastScrollY.isEqual(to: currentY) {
            lastScrollY = currentY
            setNeedsDisplay(bounds)
        }
        // If only X changed (horizontal scroll), don't trigger a redraw
    }

    @objc func textDidChange(_: Notification) {
        // Text changed, we need to update line numbers
        setNeedsDisplay(bounds)
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
              let scrollView = self.scrollView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }

        // Get the visible rect of the scroll view's content
        let visibleRect = scrollView.contentView.visibleRect
        let textVisibleRect = textView.visibleRect

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
        let lineRanges = getLineRanges(for: text, in: characterRange)

        // Set up text attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        // Draw each line number
        for (lineNumber, lineRange) in lineRanges {
            let lineString = "\(lineNumber)"

            // Get the rect for this line
            var lineRect = NSRect.zero
            if lineRange.length > 0 {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil, withoutAdditionalLayout: true)
            } else {
                // Handle empty lines or end of text
                if lineRange.location < textLength {
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
                    lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)
                } else if textLength > 0 {
                    // Use the last character's position
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: textLength - 1)
                    lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)
                    // Add line height for the new line
                    lineRect.origin.y += lineRect.height
                }
            }

            // The ruler view needs to align with the text view's coordinate system
            // Adjust the Y position based on the scroll offset
            let scrollOffset = visibleRect.origin.y
            let adjustedY = lineRect.minY - scrollOffset

            // Draw if visible in the current rect
            if adjustedY < rect.maxY && adjustedY + lineRect.height > rect.minY {
                // Draw with right alignment
                let size = lineString.size(withAttributes: attributes)
                let drawingPoint = NSPoint(
                    x: ruleThickness - rightPadding - size.width,
                    y: adjustedY + (lineRect.height - size.height) / 2
                )

                lineString.draw(at: drawingPoint, withAttributes: attributes)

                // Draw folding control if enabled
                if let codeEditor = textView as? CodeEditorView,
                   codeEditor.configuration.display.enableCodeFolding &&
                   codeEditor.configuration.display.showFoldingControls {
                    drawFoldingControl(at: lineNumber, in: NSRect(
                        x: 0,
                        y: adjustedY,
                        width: ruleThickness,
                        height: lineRect.height
                    ))
                }
            }
        }

        // Draw a separator line on the right edge
        PlatformColors.separator.set()
        let separatorRect = NSRect(x: ruleThickness - 1, y: rect.minY, width: 1, height: rect.height)
        separatorRect.fill()
    }

    // MARK: - Helper Methods

    private func getLineRanges(for text: String, in visibleRange: NSRange) -> [(lineNumber: Int, range: NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1

        // If empty text, return single line
        if text.isEmpty {
            return [(1, NSRange(location: 0, length: 0))]
        }

        // Count lines up to visible range
        // swiftlint:disable:next legacy_objc_type
        let nsString = (text as NSString)
        nsString.enumerateSubstrings(in: NSRange(location: 0, length: visibleRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        // Collect visible lines
        nsString.enumerateSubstrings(in: visibleRange, options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            lineRanges.append((lineNumber, range))
            lineNumber += 1
        }

        // If no lines found (e.g., empty line at end), add current line
        if lineRanges.isEmpty && visibleRange.location <= text.count {
            lineRanges.append((lineNumber, visibleRange))
        }

        return lineRanges
    }
}
// MARK: - MacOS Extensions
extension CodeEditorContainerView {
    /// Sets up the macOS-specific views and constraints
    func setupMacOSViews() {
        // Set up the scroll view and text view relationship
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        // Add scroll view first
        addSubview(scrollView)

        // Add minimap on top of scroll view
        addSubview(minimapView, positioned: .above, relativeTo: scrollView)

        // Ensure minimap is properly configured
        minimapView.wantsLayer = true
        minimapView.layer?.zPosition = 1_000
        minimapView.layer?.backgroundColor = MinimapConfiguration.defaultBackgroundColor.cgColor

        // Configure scroll view for line numbers
        scrollView.hasVerticalRuler = configuration.display.isLineNumbersEnabled
        scrollView.rulersVisible = configuration.display.isLineNumbersEnabled

        if configuration.display.isLineNumbersEnabled {
            let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
            rulerView.textView = textView
            rulerView.ruleThickness = configuration.layout.gutterWidth
            scrollView.verticalRulerView = rulerView

            // Ensure ruler view is displayed
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            rulerView.needsDisplay = true

            // Observe text changes to update line numbers
            NotificationCenter.default.addObserver(
                rulerView,
                selector: #selector(rulerView.textDidChange(_:)),
                name: NSText.didChangeNotification,
                object: textView
            )
        }

        // Apply configuration
        configuration.apply(to: textView)
    }

    /// Updates the macOS-specific ruler view with new configuration
    func updateMacOSRuler() {
        guard let scrollView = textView.enclosingScrollView else { return }

        if configuration.display.isLineNumbersEnabled {
            if scrollView.verticalRulerView == nil {
                let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
                rulerView.textView = textView
                scrollView.verticalRulerView = rulerView
            }

            if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
                rulerView.ruleThickness = configuration.layout.gutterWidth
                rulerView.needsDisplay = true
            }

            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true

            // Force ruler view update to ensure line numbers are visible
            scrollView.verticalRulerView?.needsDisplay = true
        } else {
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
            scrollView.verticalRulerView = nil
        }
    }

    /// Layout views using AppKit-specific logic
    func layoutViewsAppKit() {
        // Calculate layout dimensions
        let minimapWidth = configuration.display.showMinimap ? configuration.layout.minimapWidth : 0

        // Position scroll view to fill entire width (ruler view is inside the scroll view)
        scrollView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width - minimapWidth,
            height: bounds.height
        )

        // Position minimap on the right
        if configuration.display.showMinimap {
            // Position minimap on the right edge of the container
            let minimapX = bounds.width - minimapWidth
            minimapView.frame = CGRect(
                x: minimapX,
                y: 0,
                width: minimapWidth,
                height: bounds.height
            )

            minimapView.isHidden = false

            // Force minimap to display
            minimapView.needsDisplay = true

            // Ensure minimap is in the view hierarchy and above scroll view
            if minimapView.superview == nil {
                addSubview(minimapView, positioned: .above, relativeTo: scrollView)
            }

            // Bring to front with higher z-position
            minimapView.layer?.zPosition = 1_000

            // When minimap is shown, we need to handle text view layout differently
            // Get the actual content width (scroll view width minus ruler if present)
            let contentWidth = scrollView.contentView.bounds.width

            // Save current scroll position before any layout changes
            let savedVisibleRect = scrollView.contentView.visibleRect
            let savedScrollPosition = scrollView.contentView.bounds.origin

            if configuration.layout.wrapLines {
                // When word wrap is enabled with minimap
                // Text view should fill the scroll view width and wrap text
                textView.autoresizingMask = [.width, .height]
                textView.isHorizontallyResizable = false

                // Set frame to match scroll view content
                textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: textView.frame.height)

                // Configure text container for word wrap
                textView.textContainer?.containerSize = NSSize(
                    width: contentWidth - textView.textContainerInset.width * 2,
                    height: CGFloat.greatestFiniteMagnitude
                )
                textView.textContainer?.widthTracksTextView = true

                // Layout has already been updated by setting the frame and container size
            } else {
                // When word wrap is disabled with minimap
                // We need to allow horizontal scrolling, so the text view must be horizontally resizable
                textView.autoresizingMask = [.height]

                // Text view MUST be horizontally resizable for horizontal scrolling to work
                textView.isHorizontallyResizable = true

                // Don't set the frame when horizontal scrolling is enabled
                // The text view will size itself based on content when isHorizontallyResizable = true

                // Set text container to unlimited width to allow horizontal scrolling
                textView.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )

                // Text container should NOT track the text view width when we want horizontal scrolling
                textView.textContainer?.widthTracksTextView = false

                // Layout has already been updated by setting the frame and container size
            }

            // Restore scroll position after all layout changes
            // This is critical to prevent scroll position from resetting during layout
            if savedVisibleRect.width > 0 && savedVisibleRect.height > 0 {
                // IMPORTANT: We must restore the scroll position immediately, not async
                // The issue is that TextKit's layout manager might reset the scroll position
                // when it updates the text view's frame during layout

                // Force the scroll view to maintain its position
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setValue(true, forKey: kCATransactionDisableActions)

                // Directly set the bounds origin to restore scroll position
                // This is more reliable than using scroll(to:) which can be overridden
                scrollView.contentView.bounds.origin = savedScrollPosition

                // Also ensure the visible rect is preserved
                scrollView.contentView.setBoundsOrigin(savedScrollPosition)

                CATransaction.commit()

                // Don't call reflectScrolledClipView - it can cause recursion
            }
        } else {
            minimapView.isHidden = true

            // Restore normal behavior when minimap is hidden
            if configuration.layout.wrapLines {
                // When word wrap is enabled without minimap
                textView.autoresizingMask = [.width, .height]
                textView.isHorizontallyResizable = false

                // Configure text container for word wrap
                textView.textContainer?.widthTracksTextView = true

                // The text container size will be managed by the text view itself
                // since widthTracksTextView is true
            } else {
                // When word wrap is disabled without minimap
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

        // Update minimap after layout changes
        updateMinimap()

        // Force ruler view to update after layout changes
        if configuration.display.isLineNumbersEnabled {
            scrollView.verticalRulerView?.needsDisplay = true
            // Also mark the scroll view itself for display update
            scrollView.needsDisplay = true
            // Don't force immediate display - let it happen naturally to avoid layout recursion
            // scrollView.window?.displayIfNeeded()
            // Ensure the ruler view is visible
            scrollView.rulersVisible = true
        }
    }
}

// MARK: - Folding support for macOS
extension LineNumberRulerView {
    /// Draw folding control for a line
    func drawFoldingControl(at lineNumber: Int, in lineRect: NSRect) {
        guard let textView = textView as? CodeEditorView else { return }

        // Check if this line can be folded
        guard textView.isFoldable(at: lineNumber) else { return }

        let controlSize: CGFloat = 12.0
        let controlPadding: CGFloat = 4.0

        // Calculate control position (left side of line numbers)
        let controlRect = NSRect(
            x: controlPadding,
            y: lineRect.minY + (lineRect.height - controlSize) / 2,
            width: controlSize,
            height: controlSize
        )

        // Draw background circle
        let backgroundPath = NSBezierPath(ovalIn: controlRect)
        PlatformColors.tertiaryLabel.withAlphaComponent(0.2).setFill()
        backgroundPath.fill()

        // Draw border
        PlatformColors.tertiaryLabel.setStroke()
        backgroundPath.lineWidth = 0.5
        backgroundPath.stroke()

        // Check if folded
        let isFolded = textView.isFolded(at: lineNumber)

        // Draw the triangle icon
        drawFoldingIcon(in: controlRect.insetBy(dx: controlSize * 0.25, dy: controlSize * 0.25), isFolded: isFolded)
    }

    private func drawFoldingIcon(in rect: NSRect, isFolded: Bool) {
        let path = NSBezierPath()

        PlatformColors.label.setFill()

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

    override func mouseDown(with event: NSEvent) {
        guard let textView = textView as? CodeEditorView,
              textView.configuration.display.enableCodeFolding else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)

        // Check if click is in folding control area
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        let maxX = controlPadding + controlSize

        guard point.x <= maxX else {
            super.mouseDown(with: event)
            return
        }

        // Find which line was clicked
        if let lineNumber = lineNumber(at: point) {
            if textView.isFoldable(at: lineNumber) {
                _ = textView.toggleFold(at: lineNumber)
                needsDisplay = true
            }
        }

        super.mouseDown(with: event)
    }

    private func lineNumber(at point: NSPoint) -> Int? {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return nil
        }

        // Convert point to text view coordinates
        let textPoint = textView.convert(point, from: self)

        // Get character index at point
        let index = layoutManager.characterIndex(for: textPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        // Count lines up to this index
        let text = textView.string
        var lineNumber = 1

        // swiftlint:disable:next legacy_objc_type
        let nsString = (text as NSString)
        nsString.enumerateSubstrings(in: NSRange(location: 0, length: min(index, text.count)), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        return lineNumber
    }
}

#endif
