import CoreGraphics
import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - UnifiedDrawingCoordinator

/// A coordinator that abstracts platform-specific drawing operations
/// providing a unified interface for cross-platform drawing
@MainActor
public enum UnifiedDrawingCoordinator {
    // MARK: - Drawing Context
    
    /// Get the current graphics context in a platform-agnostic way
    public static func currentContext() -> CGContext? {
        getCurrentContextPlatformSpecific()
    }
    
    /// Save the graphics state
    public static func saveGraphicsState() {
        saveGraphicsStatePlatformSpecific()
    }
    
    /// Restore the graphics state
    public static func restoreGraphicsState() {
        restoreGraphicsStatePlatformSpecific()
    }
    
    // MARK: - Display Updates
    
    /// Request a display update for a view
    public static func setNeedsDisplay(for view: PlatformView) {
        setNeedsDisplayPlatformSpecific(for: view)
    }
    
    /// Request a display update for a specific rectangle
    public static func setNeedsDisplay(for view: PlatformView, in rect: CGRect) {
        setNeedsDisplayPlatformSpecific(for: view, in: rect)
    }
    
    // MARK: - Coordinate System
    
    /// Convert a point from view coordinates to drawing coordinates
    /// Handles flipped coordinate systems automatically
    public static func convertToDrawingCoordinates(_ point: CGPoint, in view: PlatformView, bounds: CGRect) -> CGPoint {
        convertPointToDrawingCoordinates(point, in: view, bounds: bounds)
    }
    
    /// Convert a rect from view coordinates to drawing coordinates
    public static func convertToDrawingCoordinates(_ rect: CGRect, in view: PlatformView, bounds: CGRect) -> CGRect {
        convertRectToDrawingCoordinates(rect, in: view, bounds: bounds)
    }
    
    // MARK: - Text Drawing
    
    /// Draw a string at the specified point with attributes
    public static func drawString(
        _ string: String,
        at point: CGPoint,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        string.draw(at: point, withAttributes: attributes)
        #else
        string.draw(at: point, withAttributes: attributes)
        #endif
    }
    
    /// Draw an attributed string at the specified point
    public static func drawAttributedString(
        _ attributedString: NSAttributedString,
        at point: CGPoint
    ) {
        attributedString.draw(at: point)
    }
    
    /// Draw a string in a rectangle with attributes
    public static func drawString(
        _ string: String,
        in rect: CGRect,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        string.draw(in: rect, withAttributes: attributes)
    }
    
    // MARK: - Fill and Stroke
    
    /// Fill a rectangle with a color
    public static func fillRect(_ rect: CGRect, with color: PlatformColor) {
        fillRectPlatformSpecific(rect, with: color)
    }
    
    /// Stroke a rectangle with a color
    public static func strokeRect(_ rect: CGRect, with color: PlatformColor, lineWidth: CGFloat = 1.0) {
        strokeRectPlatformSpecific(rect, with: color, lineWidth: lineWidth)
    }
    
    /// Draw a line between two points
    public static func drawLine(from start: CGPoint, to end: CGPoint, color: PlatformColor, lineWidth: CGFloat = 1.0) {
        drawLinePlatformSpecific(from: start, to: end, color: color, lineWidth: lineWidth)
    }
    
    // MARK: - Clipping
    
    /// Clip drawing to a rectangle
    public static func clipToRect(_ rect: CGRect) {
        clipToRectPlatformSpecific(rect)
    }
    
    // MARK: - Focus Ring (macOS only)
    
    /// Draw a focus ring around a rectangle (no-op on iOS)
    public static func drawFocusRing(around rect: CGRect) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSFocusRingPlacement.only.set()
        let path = NSBezierPath(rect: rect)
        path.fill()
        #endif
        // No-op on iOS
    }
    
    // MARK: - Layer Backing
    
    /// Ensure a view is layer-backed for better performance
    public static func ensureLayerBacked(_ view: PlatformView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.wantsLayer = true
        #endif
        // UIView is always layer-backed on iOS
    }
    
    /// Set the background color of a view's layer
    public static func setLayerBackgroundColor(_ color: PlatformColor?, for view: PlatformView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if view.wantsLayer {
            view.layer?.backgroundColor = color?.cgColor
        }
        #else
        view.layer.backgroundColor = color?.cgColor
        #endif
    }
    
    // MARK: - Text Editor Drawing
    
    /// Draw line numbers in the gutter area
    public static func drawLineNumber(
        _ lineNumber: Int,
        at point: CGPoint,
        font: PlatformFont,
        color: PlatformColor,
        alignment: NSTextAlignment = .right,
        maxWidth: CGFloat? = nil
    ) {
        let text = "\(lineNumber)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        var drawPoint = point
        
        if alignment == .right, let maxWidth {
            let textSize = text.size(withAttributes: attributes)
            drawPoint.x = maxWidth - textSize.width
        }
        
        drawString(text, at: drawPoint, withAttributes: attributes)
    }
    
    /// Draw minimap text line with performance optimizations
    public static func drawMinimapLine(
        _ text: String,
        at point: CGPoint,
        font: PlatformFont,
        color: PlatformColor,
        maxWidth: CGFloat
    ) {
        // Truncate text to fit width for performance
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        // Quick check if text fits
        let textSize = text.size(withAttributes: attributes)
        if textSize.width <= maxWidth {
            drawString(text, at: point, withAttributes: attributes)
        } else {
            // Truncate text to fit width
            let avgCharWidth = textSize.width / CGFloat(text.count)
            let maxChars = Int(maxWidth / avgCharWidth)
            if maxChars > 0 {
                let truncated = String(text.prefix(maxChars))
                drawString(truncated, at: point, withAttributes: attributes)
            }
        }
    }
    
    /// Draw viewport indicator for minimap
    public static func drawViewportIndicator(
        in rect: CGRect,
        backgroundColor: PlatformColor,
        borderColor: PlatformColor,
        borderWidth: CGFloat = 1.0
    ) {
        // Fill background
        fillRect(rect, with: backgroundColor)
        
        // Draw border
        strokeRect(rect, with: borderColor, lineWidth: borderWidth)
    }
    
    /// Calculate visible text area for a text view
    public static func calculateVisibleTextRect(for textView: CodeEditorView) -> CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // For macOS, simply return the visible rect
        // The conversion was causing issues in some cases
        return textView.visibleRect
        #else
        return CGRect(
            origin: textView.contentOffset,
            size: textView.bounds.size
        )
        #endif
    }
}

// MARK: - Platform-Specific Helper Methods

extension UnifiedDrawingCoordinator {
    /// Platform-specific implementation for getting current graphics context
    private static func getCurrentContextPlatformSpecific() -> CGContext? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSGraphicsContext.current?.cgContext
        #else
        return UIGraphicsGetCurrentContext()
        #endif
    }
    
    /// Platform-specific implementation for saving graphics state
    private static func saveGraphicsStatePlatformSpecific() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSGraphicsContext.current?.saveGraphicsState()
        #else
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
        }
        #endif
    }
    
    /// Platform-specific implementation for restoring graphics state
    private static func restoreGraphicsStatePlatformSpecific() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSGraphicsContext.current?.restoreGraphicsState()
        #else
        if let context = UIGraphicsGetCurrentContext() {
            context.restoreGState()
        }
        #endif
    }
    
    /// Platform-specific implementation for setting needs display
    private static func setNeedsDisplayPlatformSpecific(for view: PlatformView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.needsDisplay = true
        #else
        view.setNeedsDisplay()
        #endif
    }
    
    /// Platform-specific implementation for setting needs display in rect
    private static func setNeedsDisplayPlatformSpecific(for view: PlatformView, in rect: CGRect) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.setNeedsDisplay(rect)
        #else
        view.setNeedsDisplay(rect)
        #endif
    }
    
    /// Platform-specific implementation for converting point to drawing coordinates
    private static func convertPointToDrawingCoordinates(_ point: CGPoint, in view: PlatformView, bounds: CGRect) -> CGPoint {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // AppKit views may have flipped coordinate systems
        if view.isFlipped {
            return point
        } else {
            return CGPoint(x: point.x, y: bounds.height - point.y)
        }
        #else
        // UIKit always uses top-left origin
        return point
        #endif
    }
    
    /// Platform-specific implementation for converting rect to drawing coordinates
    private static func convertRectToDrawingCoordinates(_ rect: CGRect, in view: PlatformView, bounds: CGRect) -> CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if view.isFlipped {
            return rect
        } else {
            return CGRect(
                x: rect.origin.x,
                y: bounds.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
        }
        #else
        return rect
        #endif
    }
    
    /// Platform-specific implementation for filling rectangle
    private static func fillRectPlatformSpecific(_ rect: CGRect, with color: PlatformColor) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        color.setFill()
        NSBezierPath.fill(rect)
        #else
        color.setFill()
        UIBezierPath(rect: rect).fill()
        #endif
    }
    
    /// Platform-specific implementation for stroking rectangle
    private static func strokeRectPlatformSpecific(_ rect: CGRect, with color: PlatformColor, lineWidth: CGFloat) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
        #else
        color.setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
        #endif
    }
    
    /// Platform-specific implementation for drawing line
    private static func drawLinePlatformSpecific(from start: CGPoint, to end: CGPoint, color: PlatformColor, lineWidth: CGFloat) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        color.setStroke()
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = lineWidth
        path.stroke()
        #else
        color.setStroke()
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        path.lineWidth = lineWidth
        path.stroke()
        #endif
    }
    
    /// Platform-specific implementation for clipping to rectangle
    private static func clipToRectPlatformSpecific(_ rect: CGRect) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSBezierPath(rect: rect).addClip()
        #else
        UIBezierPath(rect: rect).addClip()
        #endif
    }
}

// MARK: - Drawing Context Wrapper

/// A wrapper that provides a consistent drawing context interface across platforms
public struct UnifiedDrawingContext {
    public let cgContext: CGContext
    public let bounds: CGRect
    public let isFlipped: Bool
    
    @MainActor
    init?(for view: PlatformView) {
        guard let context = UnifiedDrawingCoordinator.currentContext() else { return nil }
        self.cgContext = context
        self.bounds = view.bounds
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.isFlipped = view.isFlipped
        #else
        self.isFlipped = true // UIKit is always flipped
        #endif
    }
    
    /// Convert a point to drawing coordinates
    public func convertPoint(_ point: CGPoint) -> CGPoint {
        if isFlipped {
            return point
        } else {
            return CGPoint(x: point.x, y: bounds.height - point.y)
        }
    }
    
    /// Convert a rect to drawing coordinates
    public func convertRect(_ rect: CGRect) -> CGRect {
        if isFlipped {
            return rect
        } else {
            return CGRect(
                x: rect.origin.x,
                y: bounds.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
        }
    }
}
