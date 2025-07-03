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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else {
            return
        }
        #else
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager
        let textStorage = textView.textStorage
        #endif
        
        // Fill background if requested (UIKit needs this)
        if fillBackground {
            context.setFillColor(PlatformColors.controlBackground.cgColor)
            context.fill(rect)
        }
        
        // Get visible text range
        let visibleRect = getVisibleRect(for: textView)
        
        // Guard against invalid rect
        guard visibleRect.width > 0, visibleRect.height > 0 else {
            return
        }
        
        
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
                context: context,
                textView: textView
            )
            
            // Draw folding controls if enabled
            if textView.configuration.display.enableCodeFolding &&
               textView.configuration.display.showFoldingControls {
                drawFoldingControl(
                    for: lineNumber,
                    lineRange: lineRange,
                    layoutManager: layoutManager,
                    gutterBounds: gutterBounds,
                    context: context,
                    textView: textView
                )
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get the visible rectangle for the text view
    private func getVisibleRect(for textView: CodeEditorView) -> CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return UnifiedDrawingCoordinator.calculateVisibleTextRect(for: textView)
        #else
        // For iOS/Catalyst, the visible rect is simply the scrolled area
        return CGRect(
            origin: textView.contentOffset,
            size: textView.bounds.size
        )
        #endif
    }
    
    /// Draw a single line number
    private func drawLineNumber(
        _ lineNumber: Int,
        for lineRange: NSRange,
        layoutManager: NSLayoutManager,
        attributes _: [NSAttributedString.Key: Any],
        gutterBounds: CGRect,
        context _: CGContext,
        textView: CodeEditorView
    ) {
        // Get the rect for this line
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
        let lineRect = layoutManager.lineFragmentRect(
            forGlyphAt: glyphIndex,
            effectiveRange: nil,
            withoutAdditionalLayout: true
        )
        
        // Calculate drawing position
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: align with text baseline
        let fontLineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
        let yPosition = lineRect.minY + (lineRect.height - fontLineHeight) / 2
        #else
        // iOS/Catalyst: Calculate position accounting for text container inset
        let textContainerInset = textView.textContainerInset
        
        // The lineRect.origin.y is in text coordinates (starts at 0)
        // We need to convert to view coordinates accounting for:
        // 1. The text container inset (text starts at y = textContainerInset.top)
        // 2. The scroll offset
        // 3. Center the line number with the text baseline
        
        // When at scroll position 0, the first line of text is at y = textContainerInset.top
        // So we need to add the inset and subtract the scroll
        let baseY = lineRect.origin.y + textContainerInset.top - textView.contentOffset.y
        
        // Adjust for text baseline alignment (similar to macOS)
        // The line number should be vertically centered with the text
        let fontLineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
        let yPosition = baseY + (lineRect.height - fontLineHeight) / 2
        
        #endif
        
        let drawingPoint = CGPoint(
            x: 0, // Will be adjusted by the unified drawing method for right alignment
            y: yPosition
        )
        
        // Save graphics state
        UnifiedDrawingCoordinator.saveGraphicsState()
        
        // Draw using unified drawing method
        UnifiedDrawingCoordinator.drawLineNumber(
            lineNumber,
            at: drawingPoint,
            font: font,
            color: textColor,
            alignment: .right,
            maxWidth: gutterBounds.width - rightPadding
        )
        
        // Restore graphics state
        UnifiedDrawingCoordinator.restoreGraphicsState()
    }
    
    /// Calculate line ranges for the visible text
    internal func getLineRanges(for text: String, in range: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Handle empty range or invalid range
        guard range.location >= 0,
              range.location <= text.utf16.count,
              (range.length > 0 || range.location < text.utf16.count) else {
            return lineRanges
        }
        
        // Clamp range to valid bounds
        let clampedLocation = max(0, min(range.location, text.utf16.count))
        let maxLength = max(0, text.utf16.count - clampedLocation)
        let clampedLength = max(0, min(range.length, maxLength))
        
        let validRange = NSRange(
            location: clampedLocation,
            length: clampedLength
        )
        
        // Count lines before the visible range
        if validRange.location > 0 {
            let beforeRange = NSRange(location: 0, length: validRange.location)
            if let beforeText = text.substring(with: beforeRange) {
                lineNumber += beforeText.components(separatedBy: .newlines).count - 1
            }
        }
        
        // Process visible range
        var currentLocation = validRange.location
        let endLocation = min(validRange.location + validRange.length, text.utf16.count)
        
        // Special case: if we're at the beginning of the text, ensure we include the first line
        if validRange.location == 0 && text.utf16.count > 0 {
            currentLocation = 0
        }
        
        while currentLocation <= endLocation && currentLocation < text.utf16.count {
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
    
    /// Draw folding control (▶️/▼ icon) for foldable lines
    private func drawFoldingControl(
        for lineNumber: Int,
        lineRange: NSRange,
        layoutManager: NSLayoutManager,
        gutterBounds: CGRect,
        context: CGContext,
        textView: CodeEditorView
    ) {
        // Check if this line is foldable
        guard textView.isFoldable(at: lineNumber) else { return }
        
        // Get the rect for this line
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
        let lineRect = layoutManager.lineFragmentRect(
            forGlyphAt: glyphIndex,
            effectiveRange: nil,
            withoutAdditionalLayout: true
        )
        
        // Calculate folding control position
        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Position control to the left of line numbers
        let xPosition = controlPadding
        let yPosition = lineRect.minY + (lineRect.height - controlSize) / 2
        #else
        // iOS/Catalyst: Account for text container inset and scroll offset
        let textContainerInset = textView.textContainerInset
        let baseY = lineRect.origin.y + textContainerInset.top - textView.contentOffset.y
        let xPosition = controlPadding
        let yPosition = baseY + (lineRect.height - controlSize) / 2
        #endif
        
        let controlRect = CGRect(
            x: xPosition,
            y: yPosition,
            width: controlSize,
            height: controlSize
        )
        
        // Skip if control rect is outside visible area
        guard controlRect.intersects(CGRect(origin: .zero, size: gutterBounds.size)) else { return }
        
        // Determine if this line is folded
        let isFolded = textView.isFolded(at: lineNumber)
        
        // Draw folding control
        drawFoldingIcon(
            in: controlRect,
            isFolded: isFolded,
            context: context,
            textView: textView
        )
    }
    
    /// Draw the folding icon (▶️ for folded, ▼ for expanded)
    private func drawFoldingIcon(
        in rect: CGRect,
        isFolded: Bool,
        context: CGContext,
        textView: CodeEditorView
    ) {
        // Save graphics state
        context.saveGState()
        
        // Set up colors
        let iconColor = PlatformColors.secondaryLabel
        let backgroundColor = PlatformColors.controlBackground
        
        // Draw background circle
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: rect)
        
        // Draw border
        context.setStrokeColor(iconColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.strokeEllipse(in: rect)
        
        // Draw icon
        context.setFillColor(iconColor.cgColor)
        
        let iconInset: CGFloat = rect.width * 0.25
        let iconRect = rect.insetBy(dx: iconInset, dy: iconInset)
        
        if isFolded {
            // Draw right-pointing triangle (▶️)
            drawTriangleIcon(in: iconRect, pointing: .right, context: context)
        } else {
            // Draw down-pointing triangle (▼)
            drawTriangleIcon(in: iconRect, pointing: .down, context: context)
        }
        
        // Restore graphics state
        context.restoreGState()
    }
    
    /// Draw a triangle icon pointing in the specified direction
    private func drawTriangleIcon(
        in rect: CGRect,
        pointing direction: TriangleDirection,
        context: CGContext
    ) {
        let path = CGMutablePath()
        
        switch direction {
        case .right:
            // Right-pointing triangle (▶️)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            
        case .down:
            // Down-pointing triangle (▼)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
        
        context.addPath(path)
        context.fillPath()
    }
}

/// Direction for triangle icons
private enum TriangleDirection {
    case right
    case down
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
