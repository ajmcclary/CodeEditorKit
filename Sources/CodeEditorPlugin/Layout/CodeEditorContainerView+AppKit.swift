import Foundation
import os.log
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
            kAppKitContainerLogger.debug("📍 At top: range=\(characterRange)")
        }
        if characterRange.location + characterRange.length >= textLength && textLength > 0 {
            kAppKitContainerLogger.debug("📍 At bottom: range=\(characterRange), textLength=\(textLength)")
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
            
            // Draw if visible
            if lineRect.minY < textVisibleRect.maxY && lineRect.maxY > textVisibleRect.minY {
                let drawingRect = NSRect(
                    x: 0,
                    y: lineRect.minY,
                    width: ruleThickness - rightPadding,
                    height: lineRect.height
                )
                
                // Draw with right alignment
                let size = lineString.size(withAttributes: attributes)
                let drawingPoint = NSPoint(
                    x: ruleThickness - rightPadding - size.width,
                    y: drawingRect.minY + (drawingRect.height - size.height) / 2
                )
                
                lineString.draw(at: drawingPoint, withAttributes: attributes)
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
        guard let scrollView = textView.enclosingScrollView else { return }
        
        // Configure scroll view
        scrollView.hasVerticalRuler = configuration.display.showLineNumbers
        scrollView.rulersVisible = configuration.display.showLineNumbers
        
        if configuration.display.showLineNumbers {
            let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
            rulerView.textView = textView
            rulerView.ruleThickness = configuration.layout.gutterWidth
            scrollView.verticalRulerView = rulerView
        }
        
        // Apply configuration
        configuration.apply(to: textView)
    }
    
    /// Updates the macOS-specific ruler view with new configuration
    func updateMacOSRuler() {
        guard let scrollView = textView.enclosingScrollView else { return }
        
        if configuration.display.showLineNumbers {
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
        } else {
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
            scrollView.verticalRulerView = nil
        }
    }
}
// MARK: - Folding support for macOS
extension LineNumberRulerView {
    /// Draw folding control for a line
    func drawFoldingControl(at _: Int, in _: NSRect) {
        // TODO: Implement when folding API is available in CodeEditorView
        /*
        guard let textView = textView as? CodeEditorView else { return }
        
        // Check if this line can be folded
        guard textView.canFold(at: lineNumber) else { return }
        
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        
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
        */
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
        // TODO: Implement when folding API is available in CodeEditorView
        /*
        if let lineNumber = lineNumber(at: point) {
            if textView.canFold(at: lineNumber) {
                if textView.isFolded(at: lineNumber) {
                    textView.unfold(at: lineNumber)
                } else {
                    textView.fold(at: lineNumber)
                }
                needsDisplay = true
            }
        }
        */
        
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
// Private logger instance
private let kAppKitContainerLogger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorContainerView.AppKit")
#endif
