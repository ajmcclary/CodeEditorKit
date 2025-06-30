// MARK: - GutterViewRenderer
//
// This file provides a platform-agnostic renderer for the GutterView,
// consolidating all common drawing and calculation logic.

import CoreGraphics
import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Platform-agnostic renderer for drawing line numbers in the gutter
@MainActor
public class GutterViewRenderer {
    // MARK: - Properties
    
    /// The font used for line numbers
    private let font = PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
    
    /// The color used for line numbers
    private let textColor = PlatformColors.secondaryLabel
    
    /// Padding from the right edge of the gutter
    private let rightPadding: CGFloat = 8
    
    // MARK: - Initialization
    
    deinit {
        // Required by SwiftLint
    }
    
    // MARK: - Public Interface
    
    /// Draw line numbers for the given text view in the specified rectangle
    /// - Parameters:
    ///   - rect: The rectangle to draw in
    ///   - context: The Core Graphics context to draw into
    ///   - textView: The text view to draw line numbers for
    ///   - gutterBounds: The bounds of the gutter view
    ///   - fillBackground: Whether to fill the background (UIKit only)
    public func draw(
        in rect: CGRect,
        context: CGContext,
        textView: CodeEditorView,
        gutterBounds: CGRect,
        fillBackground: Bool = false
    ) {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { 
            return 
        }
        
        // Fill background if requested (UIKit needs this)
        if fillBackground {
            context.setFillColor(PlatformColors.controlBackground.cgColor)
            context.fill(rect)
        }
        
        // Get visible text range
        let visibleRect = getVisibleRect(for: textView)
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        
        // Get line ranges for visible area
        let text = textStorage.string
        let lineRanges = getLineRanges(for: text, in: visibleCharacterRange)
        
        // Set up text attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        // Draw each line number
        for (lineNumber, lineRange) in lineRanges {
            drawLineNumber(
                lineNumber,
                for: lineRange,
                layoutManager: layoutManager,
                attributes: attributes,
                gutterBounds: gutterBounds,
                context: context
            )
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get the visible rectangle for the text view
    private func getVisibleRect(for textView: CodeEditorView) -> CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return textView.visibleRect
        #else
        return textView.bounds
        #endif
    }
    
    /// Draw a single line number
    private func drawLineNumber(
        _ lineNumber: Int,
        for lineRange: NSRange,
        layoutManager: NSLayoutManager,
        attributes: [NSAttributedString.Key: Any],
        gutterBounds: CGRect,
        context: CGContext
    ) {
        // Get the rect for this line
        let lineRect = layoutManager.lineFragmentRect(
            forGlyphAt: layoutManager.glyphIndexForCharacter(at: lineRange.location),
            effectiveRange: nil,
            withoutAdditionalLayout: true
        )
        
        // Prepare the line number string
        let lineNumberString = "\(lineNumber)"
        // swiftlint:disable:next legacy_objc_type
        let lineNumberSize = (lineNumberString as NSString).size(withAttributes: attributes)
        
        // Calculate drawing position (right-aligned with padding)
        let drawingPoint = CGPoint(
            x: gutterBounds.width - lineNumberSize.width - rightPadding,
            y: lineRect.minY + (lineRect.height - lineNumberSize.height) / 2
        )
        
        // Save graphics state
        context.saveGState()
        
        // Draw the line number
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // AppKit needs to set the current context
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        // swiftlint:disable:next legacy_objc_type
        (lineNumberString as NSString).draw(at: drawingPoint, withAttributes: attributes)
        #else
        // UIKit already has the context set up
        UIGraphicsPushContext(context)
        // swiftlint:disable:next legacy_objc_type
        (lineNumberString as NSString).draw(at: drawingPoint, withAttributes: attributes)
        UIGraphicsPopContext()
        #endif
        
        // Restore graphics state
        context.restoreGState()
    }
    
    /// Calculate line ranges for the visible text
    internal func getLineRanges(for text: String, in range: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Handle empty range
        guard range.length > 0 || range.location < text.utf16.count else {
            return lineRanges
        }
        
        // Count lines before the visible range
        if range.location > 0 {
            let beforeRange = NSRange(location: 0, length: range.location)
            if let beforeText = text.substring(with: beforeRange) {
                lineNumber += beforeText.components(separatedBy: .newlines).count - 1
            }
        }
        
        // Process visible range
        var currentLocation = range.location
        let endLocation = min(range.location + range.length, text.utf16.count)
        
        while currentLocation < endLocation {
            // Find the end of the current line
            var lineEndLocation = currentLocation
            
            // Search for line ending
            if let substring = text.substring(from: currentLocation) {
                if let lineEndRange = substring.range(of: "\n") {
                    let distance = substring.distance(from: substring.startIndex, to: lineEndRange.lowerBound)
                    lineEndLocation = currentLocation + distance + 1
                } else {
                    // No more line endings, this is the last line
                    lineEndLocation = text.utf16.count
                }
            }
            
            // Create range for this line
            let lineRange = NSRange(location: currentLocation, length: lineEndLocation - currentLocation)
            lineRanges.append((lineNumber, lineRange))
            
            // Move to next line
            lineNumber += 1
            currentLocation = lineEndLocation
            
            // Stop if we've reached the end of the visible range
            if currentLocation >= endLocation {
                break
            }
        }
        
        return lineRanges
    }
}

// MARK: - String Helpers

extension String {
    /// Safe substring extraction using NSRange
    func substring(with range: NSRange) -> String? {
        guard let rangeInString = Range(range, in: self) else { return nil }
        return String(self[rangeInString])
    }
    
    /// Safe substring extraction from a given offset
    func substring(from offset: Int) -> String? {
        guard offset < utf16.count else { return nil }
        let startIndex = index(self.startIndex, offsetBy: offset, limitedBy: endIndex) ?? endIndex
        return String(self[startIndex...])
    }
}
