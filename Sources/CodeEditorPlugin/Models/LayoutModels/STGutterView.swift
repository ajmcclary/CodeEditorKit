//  Created by Claude Code
//  Line number gutter view for STTextView

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for displaying line numbers and other gutter information
public class STGutterView: NSView {
    
    weak var textView: STTextView?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Ensure the view clips to its bounds
        self.layer?.masksToBounds = true
    }
    
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let textView = textView else {
            return
        }
        
        // Clear background - only fill the gutter's bounds, not the dirty rect
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        
        // Set up text attributes for line numbers
        let font = NSFont.monospacedSystemFont(ofSize: (textView.font?.pointSize ?? NSFont.systemFontSize) * 0.9, weight: .regular)
        let textColor = NSColor.secondaryLabelColor
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
        
        // Get visible range and calculate line numbers
        let visibleRange = textView.visibleRange()
        let text = textView.string as NSString
        let lineRanges = getLineRanges(for: text, in: visibleRange)
        
        for (lineNumber, lineRange) in lineRanges {
            // Calculate the line rect using layout manager
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                
                let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
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
    
    private func getLineRanges(for text: NSString, in visibleRange: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        var currentLocation = 0
        
        // Count lines before visible range
        while currentLocation < visibleRange.location && currentLocation < text.length {
            let lineRange = text.lineRange(for: NSRange(location: currentLocation, length: 0))
            if lineRange.location + lineRange.length <= visibleRange.location {
                lineNumber += 1
            } else {
                break
            }
            currentLocation = lineRange.location + lineRange.length
        }
        
        // Add visible lines
        currentLocation = visibleRange.location
        let endLocation = min(visibleRange.location + visibleRange.length, text.length)
        
        while currentLocation < endLocation {
            let lineRange = text.lineRange(for: NSRange(location: currentLocation, length: 0))
            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentLocation = lineRange.location + lineRange.length
        }
        
        return lineRanges
    }
}