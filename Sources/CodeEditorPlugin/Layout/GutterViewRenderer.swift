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
        // Fill background if requested (UIKit needs this)
        if fillBackground {
            context.setFillColor(PlatformColors.controlBackground.cgColor)
            context.fill(rect)
        }
        
        // Use TextKitLineNumberHelper to get visible line ranges
        let helper = TextKitLineNumberHelper(textView: textView)
        let lineRanges = helper.getVisibleLineRanges()
        
        // Guard against no visible lines
        guard !lineRanges.isEmpty else {
            return
        }
        
        // Use the same font as the text view for proper baseline alignment
        let textViewFont = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // Draw each line number
        for (lineNumber, lineRange) in lineRanges {
            let drawingContext = LineDrawingContext(
                font: textViewFont,
                gutterBounds: gutterBounds,
                textView: textView
            )
            
            drawLineNumber(
                lineNumber,
                for: lineRange,
                context: drawingContext
            )
            
            // Draw folding controls if enabled
            if textView.configuration.display.enableCodeFolding &&
               textView.configuration.display.showFoldingControls {
                drawFoldingControl(
                    for: lineNumber,
                    lineRange: lineRange,
                    helper: helper,
                    gutterBounds: gutterBounds,
                    context: context,
                    textView: textView
                )
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Context for drawing line numbers
    private struct LineDrawingContext {
        let font: PlatformFont
        let gutterBounds: CGRect
        let textView: CodeEditorView
    }
    
    /// Draw a single line number
    private func drawLineNumber(
        _ lineNumber: Int,
        for lineRange: NSRange,
        context: LineDrawingContext
    ) {
        // Calculate Y position directly from line number and actual text layout
        let yPosition = calculateLineNumberYPosition(lineNumber: lineNumber, lineRange: lineRange, font: context.font, textView: context.textView)
        
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
            font: context.font,
            color: textColor,
            alignment: .right,
            maxWidth: context.gutterBounds.width - rightPadding
        )
        
        // Restore graphics state
        UnifiedDrawingCoordinator.restoreGraphicsState()
    }
    
    /// Calculate the Y position for a line number using simplified AppKit-style approach
    private func calculateLineNumberYPosition(lineNumber: Int, lineRange: NSRange, font: PlatformFont, textView: CodeEditorView) -> CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS implementation - unchanged
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return CGFloat(lineNumber - 1) * TextMetricsCalculator.calculateLineHeight(for: font)
        }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let fontLineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
        return lineRect.minY + (lineRect.height - fontLineHeight) / 2
        #else
        // iOS/Catalyst implementation - use TextKit 1 for proper scrolling and color support
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        // Get line fragment rect directly
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        
        // Calculate position in text view coordinate system
        let textViewY = lineRect.minY + textView.textContainerInset.top
        
        // Convert to gutter coordinate system by accounting for scroll offset
        // The gutter is fixed, so we need to subtract the scroll offset to get the correct position
        // For Catalyst, we need to ensure we're getting the actual content offset
        let scrollOffset = textView.contentOffset.y
        let gutterY = textViewY - scrollOffset
        
        // Center the line number vertically within the line
        let lineNumberHeight = font.lineHeight
        let centeredY = gutterY + (lineRect.height - lineNumberHeight) / 2
        
        return centeredY
        #endif
    }
    
    /// Draw folding control (▶️/▼ icon) for foldable lines
    private func drawFoldingControl(
        for lineNumber: Int,
        lineRange: NSRange,
        helper: TextKitLineNumberHelper,
        gutterBounds: CGRect,
        context: CGContext,
        textView: CodeEditorView
    ) {
        // Check if this line is foldable
        guard textView.isFoldable(at: lineNumber) else { return }
        
        // Get the rect for this line using helper
        guard let lineRect = helper.getLineFragmentRect(for: lineRange) else {
            return
        }
        
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
        textView _: CodeEditorView
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
