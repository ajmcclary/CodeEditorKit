import Foundation

#if canImport(AppKit)
import AppKit

// MARK: - GutterView

/// View for displaying line numbers and other gutter information
public class GutterView: NSView {
    weak var textView: CodeEditorView?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = PlatformColors.controlBackground.cgColor

        // Ensure the view clips to its bounds
        layer?.masksToBounds = true
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView else {
            return
        }

        // Clear background - only fill the gutter's bounds, not the dirty rect
        PlatformColors.controlBackground.setFill()
        bounds.fill()

        // Set up text attributes for line numbers
        let font = PlatformFonts.monospacedSystemFont(
            ofSize: (textView.font?.pointSize ?? PlatformFonts.systemFontSize) * 0.9,
            weight: .regular
        )
        let textColor = PlatformColors.secondaryLabel
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        // Calculate line numbers to draw
        let rightPadding: CGFloat = 8
        let drawingWidth: CGFloat = bounds.width - rightPadding

        // Get ALL text lines, not just visible ones (consistent with iOS implementation)
        let text = textView.string
        let allLineRanges = getAllLineRanges(for: text)

        for (lineNumber, lineRange) in allLineRanges {
            // Skip completely empty ranges (except for final empty line after newline)
            guard lineRange.length > 0 || (lineRange.location == text.count && text.hasSuffix("\n")) else { 
                continue
            }
            
            // Validate range bounds to prevent crashes
            let clampedRange = NSRange(
                location: max(0, min(lineRange.location, text.count)),
                length: min(lineRange.length, text.count - max(0, min(lineRange.location, text.count)))
            )
            guard clampedRange.length >= 0 else { continue }
            
            // Calculate the line rect using TextKit2-compatible approach
            if let lineRect = calculateLineRect(for: clampedRange, in: textView) {
                // Validate the resulting rect
                guard lineRect.height > 0 && !lineRect.origin.y.isNaN && !lineRect.origin.y.isInfinite else { continue }
                
                // Adjust for text container inset and scroll position
                var drawingRect = lineRect
                drawingRect.origin.y += textView.textContainerInset.height
                drawingRect.origin.x = 0
                drawingRect.size.width = drawingWidth

                // Only draw if the line intersects with the dirty rect
                if drawingRect.intersects(dirtyRect) {
                    let lineNumberString = "\(lineNumber)"
                    lineNumberString.draw(in: drawingRect, withAttributes: attributes)
                }
            }
        }
    }

    private func getLineRanges(for text: String, in visibleRange: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1

        // Convert to String.Index for Swift native operations
        let visibleStartIndex = String.Index(utf16Offset: visibleRange.location, in: text)
        let visibleEndIndex = String.Index(
            utf16Offset: visibleRange.location + visibleRange.length,
            in: text
        )

        // Count lines before visible range
        var currentIndex = text.startIndex
        while currentIndex < visibleStartIndex {
            // Find the end of the current line
            let lineEnd = text[currentIndex...].firstIndex(of: "\n") ?? text.endIndex
            if lineEnd <= visibleStartIndex {
                lineNumber += 1
                currentIndex = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            } else {
                break
            }
        }

        // Process visible lines
        currentIndex = visibleStartIndex
        while currentIndex < visibleEndIndex, currentIndex < text.endIndex {
            // Find start of current line
            var lineStart = currentIndex
            if lineStart > text.startIndex {
                // Search backwards for the previous newline
                let searchRange = text.startIndex ..< lineStart
                if let lastNewline = text[searchRange].lastIndex(of: "\n") {
                    lineStart = text.index(after: lastNewline)
                } else {
                    lineStart = text.startIndex
                }
            }

            // Find end of current line
            let lineEnd = text[lineStart...].firstIndex(of: "\n") ?? text.endIndex
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex

            // Convert to NSRange
            let startOffset = text.utf16.distance(from: text.startIndex, to: lineStart)
            let endOffset = text.utf16.distance(from: text.startIndex, to: nextLineStart)
            let lineRange = NSRange(location: startOffset, length: endOffset - startOffset)

            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentIndex = nextLineStart
        }

        return lineRanges
    }
    
    /// Calculate line rect using TextKit2-compatible approach that doesn't force TextKit1
    private func calculateLineRect(for range: NSRange, in textView: CodeEditorView) -> CGRect? {
        // First try TextKit2 approach if available
        if let textLayoutManager = textView.textLayoutManager,
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
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return nil
            }
            
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        }
    }

    private func getAllLineRanges(for text: String) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Handle empty text
        guard !text.isEmpty else {
            return [(1, NSRange(location: 0, length: 0))]
        }
        
        // Enumerate all lines in the text
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            // Find end of current line
            let lineEnd = text[currentIndex...].firstIndex(of: "\n") ?? text.endIndex
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            
            // Convert to NSRange
            let startOffset = text.utf16.distance(from: text.startIndex, to: currentIndex)
            let endOffset = text.utf16.distance(from: text.startIndex, to: nextLineStart)
            let lineRange = NSRange(location: startOffset, length: endOffset - startOffset)
            
            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentIndex = nextLineStart
        }
        
        // Add final empty line if text ends with newline
        if text.hasSuffix("\n") {
            let finalOffset = text.utf16.count
            lineRanges.append((lineNumber, NSRange(location: finalOffset, length: 0)))
        }
        
        return lineRanges
    }

    deinit {
        // Cleanup if needed
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - GutterView (iOS)

/// iOS implementation for displaying line numbers
public class GutterView: UIView {
    weak var textView: CodeEditorView?
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    private var lastContentOffset: CGPoint = .zero
    
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemGray6
        isOpaque = false
        
        // Start display link for smooth updates
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkDidFire() {
        guard let textView else { return }
        
        // Only update if content offset changed
        if textView.contentOffset != lastContentOffset {
            lastContentOffset = textView.contentOffset
            setNeedsDisplay()
        }
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let textView,
              UIGraphicsGetCurrentContext() != nil else {
            return
        }
        
        let textStorage = textView.textStorage
        let layoutManager = textView.layoutManager
        _ = textView.textContainer
        
        let text = textStorage.string
        
        // Use the same font as the text view to ensure line heights match
        let font = textView.font ?? PlatformFonts.monospacedSystemFont(
            ofSize: PlatformFonts.systemFontSize,
            weight: .regular
        )
        
        // Create line number font that's slightly smaller
        let lineNumberFont = PlatformFonts.monospacedSystemFont(
            ofSize: font.pointSize * 0.9,
            weight: .regular
        )
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: PlatformColors.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate what part of the text is visible in the current rect
        // accounting for scroll position
        let scrollOffset = textView.contentOffset.y
        
        let rightPadding: CGFloat = 8
        let drawingWidth = bounds.width - rightPadding
        
        // Get ALL text lines, not just visible ones
        let allLineRanges = getAllLineRanges(for: text)
        
        for (lineNumber, lineRange) in allLineRanges {
            // Skip completely empty ranges
            guard lineRange.length > 0 || (lineRange.location == text.count && text.hasSuffix("\n")) else { 
                continue
            }
            
            // Calculate the rect for this line using proper UITextView coordinate system
            let lineRect: CGRect
            
            if lineRange.length > 0 {
                // Normal line with content - validate range bounds
                let clampedRange = NSRange(
                    location: max(0, min(lineRange.location, text.count)),
                    length: min(lineRange.length, text.count - max(0, min(lineRange.location, text.count)))
                )
                guard clampedRange.length > 0 else { continue }
                
                // Use TextKit2-compatible approach
                if let calculatedRect = calculateLineRect(for: clampedRange, in: textView) {
                    lineRect = calculatedRect
                } else {
                    continue
                }
                
                // Validate the resulting rect
                guard lineRect.height > 0 && !lineRect.origin.y.isNaN && !lineRect.origin.y.isInfinite else { continue }
            } else {
                // Empty line at end (after final newline)
                guard let prevLineRange = allLineRanges.first(where: { $0.0 == lineNumber - 1 })?.1 else { continue }
                let clampedPrevRange = NSRange(
                    location: max(0, min(prevLineRange.location, text.count)),
                    length: min(prevLineRange.length, text.count - max(0, min(prevLineRange.location, text.count)))
                )
                guard clampedPrevRange.length > 0 else { continue }
                
                // Use TextKit2-compatible approach for previous line
                guard let prevRect = calculateLineRect(for: clampedPrevRange, in: textView),
                      prevRect.height > 0 && !prevRect.maxY.isNaN && !prevRect.maxY.isInfinite else { continue }
                
                lineRect = CGRect(x: 0, y: prevRect.maxY, width: max(prevRect.width, 100), height: font.lineHeight)
            }
            
            // Convert to gutter coordinate space
            // The key insight: we need to account for text view's content offset and container insets properly
            var gutterLineRect = lineRect
            
            // Adjust for the text view's content positioning and text container inset
            // Add the text container inset that positions the text within the text view
            gutterLineRect.origin.y += textView.textContainerInset.top
            
            // Then subtract the scroll offset to get the visual position
            gutterLineRect.origin.y -= scrollOffset
            
            // Position in gutter coordinate space
            gutterLineRect.origin.x = 0
            gutterLineRect.size.width = drawingWidth
            
            // For word-wrapped lines, use the actual line height from layout
            // For single lines, ensure minimum height based on font
            if lineRect.height > font.lineHeight * 1.5 {
                // This is likely a wrapped line - use the actual height
                gutterLineRect.size.height = lineRect.height
            } else {
                // Single line - use font line height for consistency
                gutterLineRect.size.height = max(lineRect.height, font.lineHeight)
            }
            
            // Check if this line is visible in the current viewport
            // We need to draw if the line is within the visible bounds of the gutter view
            let visibleBounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
            if gutterLineRect.intersects(visibleBounds) && gutterLineRect.maxY >= 0 {
                let lineNumberString = "\(lineNumber)"
                
                // Center the line number text vertically within the line rect
                var centeredRect = gutterLineRect
                let stringSize = lineNumberString.size(withAttributes: attributes)
                centeredRect.origin.y += (gutterLineRect.height - stringSize.height) / 2
                centeredRect.size.height = stringSize.height
                
                lineNumberString.draw(in: centeredRect, withAttributes: attributes)
            }
        }
    }
    
    public func setNeedsDisplayLineNumbers() {
        setNeedsDisplay()
    }
    
    override public func setNeedsDisplay() {
        super.setNeedsDisplay()
        // Ensure display link is active
        if displayLink?.isPaused == true {
            displayLink?.isPaused = false
        }
    }
    
    private func getAllLineRanges(for text: String) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Handle empty text
        guard !text.isEmpty else {
            return [(1, NSRange(location: 0, length: 0))]
        }
        
        // Enumerate all lines in the text
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            // Find end of current line
            let lineEnd = text[currentIndex...].firstIndex(of: "\n") ?? text.endIndex
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            
            // Convert to NSRange
            let startOffset = text.utf16.distance(from: text.startIndex, to: currentIndex)
            let endOffset = text.utf16.distance(from: text.startIndex, to: nextLineStart)
            let lineRange = NSRange(location: startOffset, length: endOffset - startOffset)
            
            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentIndex = nextLineStart
        }
        
        // Add final empty line if text ends with newline
        if text.hasSuffix("\n") {
            let finalOffset = text.utf16.count
            lineRanges.append((lineNumber, NSRange(location: finalOffset, length: 0)))
        }
        
        return lineRanges
    }

    private func getLineRanges(for text: String, in visibleRange: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Handle empty text
        guard !text.isEmpty else {
            return [(1, NSRange(location: 0, length: 0))]
        }
        
        // Convert to String.Index for Swift native operations
        let visibleStartIndex = text.index(text.startIndex, offsetBy: visibleRange.location, limitedBy: text.endIndex) ?? text.endIndex
        let visibleEndOffset = min(visibleRange.location + visibleRange.length, text.utf16.count)
        let visibleEndIndex = text.index(text.startIndex, offsetBy: visibleEndOffset, limitedBy: text.endIndex) ?? text.endIndex
        
        // Count lines before visible range
        var currentIndex = text.startIndex
        while currentIndex < visibleStartIndex && currentIndex < text.endIndex {
            // Find the end of the current line
            if let lineEnd = text[currentIndex...].firstIndex(of: "\n") {
                if lineEnd < visibleStartIndex {
                    lineNumber += 1
                    currentIndex = text.index(after: lineEnd)
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        // Process visible lines
        currentIndex = visibleStartIndex
        while currentIndex < visibleEndIndex && currentIndex < text.endIndex {
            // Find start of current line
            var lineStart = currentIndex
            if lineStart > text.startIndex {
                // Search backwards for the previous newline
                var searchIndex = text.index(before: lineStart)
                while searchIndex >= text.startIndex {
                    if text[searchIndex] == "\n" {
                        lineStart = text.index(after: searchIndex)
                        break
                    }
                    if searchIndex == text.startIndex {
                        lineStart = text.startIndex
                        break
                    }
                    searchIndex = text.index(before: searchIndex)
                }
            }
            
            // Find end of current line
            let lineEnd = text[lineStart...].firstIndex(of: "\n") ?? text.endIndex
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            
            // Convert to NSRange
            let startOffset = text.utf16.distance(from: text.startIndex, to: lineStart)
            let endOffset = text.utf16.distance(from: text.startIndex, to: nextLineStart)
            let lineRange = NSRange(location: startOffset, length: endOffset - startOffset)
            
            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentIndex = nextLineStart
        }
        
        return lineRanges
    }
    
    /// Calculate line rect using TextKit2-compatible approach that doesn't force TextKit1
    private func calculateLineRect(for range: NSRange, in textView: CodeEditorView) -> CGRect? {
        // First try TextKit2 approach if available
        if let textLayoutManager = textView.textLayoutManager,
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
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound && glyphRange.location < layoutManager.numberOfGlyphs else {
                return nil
            }
            
            return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        }
    }
    
    public func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }
}
#endif
