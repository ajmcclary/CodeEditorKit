import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Handles user interactions (clicks/taps) in the gutter view
///
/// This class centralizes the logic for handling user interactions in the gutter,
/// including:
/// - Code folding control clicks
/// - Line number clicks for selection
/// - Breakpoint toggling (future)
@MainActor
public final class GutterInteractionHandler {
    // MARK: - Properties
    
    /// Weak reference to the gutter view
    private weak var gutterView: GutterView?
    
    /// Weak reference to the text view
    private weak var textView: CodeEditorView?
    
    /// The size of the folding control hit area
    private let foldingControlSize: CGFloat = 16.0
    
    /// The margin from the right edge for folding controls
    private let foldingControlMargin: CGFloat = 4.0
    
    // MARK: - Initialization
    
    /// Creates a new interaction handler
    /// - Parameters:
    ///   - gutterView: The gutter view to handle interactions for
    ///   - textView: The associated text view
    public init(gutterView: GutterView, textView: CodeEditorView) {
        self.gutterView = gutterView
        self.textView = textView
        setupInteractionHandling()
    }
    
    // MARK: - Setup
    
    /// Sets up platform-specific interaction handling
    private func setupInteractionHandling() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Mouse events are handled by overriding mouseDown in GutterView
        // No additional setup needed here
        #else
        // iOS/Catalyst: Add tap gesture recognizer
        guard let gutterView else { return }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        gutterView.addGestureRecognizer(tapGesture)
        gutterView.isUserInteractionEnabled = true
        #endif
    }
    
    // MARK: - Mouse/Touch Handling
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Handles mouse down events on macOS
    /// - Parameter event: The mouse event
    /// - Returns: Whether the event was handled
    public func handleMouseDown(with event: NSEvent) -> Bool {
        guard let gutterView,
              textView != nil else { return false }
        
        let locationInGutter = gutterView.convert(event.locationInWindow, from: nil)
        return handleInteraction(at: locationInGutter)
    }
    #endif
    
    #if canImport(UIKit)
    /// Handles tap gestures on iOS/Catalyst
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
              let gutterView else { return }
        
        let location = gesture.location(in: gutterView)
        _ = handleInteraction(at: location)
    }
    #endif
    
    // MARK: - Interaction Logic
    
    /// Handles an interaction at the given point in the gutter
    /// - Parameter point: The point in gutter coordinates
    /// - Returns: Whether the interaction was handled
    private func handleInteraction(at point: CGPoint) -> Bool {
        guard let textView,
              gutterView != nil else { return false }
        
        // Check if code folding is enabled
        guard textView.configuration.display.enableCodeFolding,
              textView.configuration.display.showFoldingControls else {
            return false
        }
        
        // Find which line was clicked
        if let lineInfo = findLine(at: point) {
            // Check if the click was on a folding control
            if isFoldingControlHit(at: point, for: lineInfo) {
                toggleFolding(for: lineInfo.lineNumber)
                return true
            }
            
            // Future: Handle other interactions like breakpoints
        }
        
        return false
    }
    
    // MARK: - Line Detection
    
    /// Information about a line at a specific point
    private struct LineInfo {
        let lineNumber: Int
        let lineRect: CGRect
    }
    
    /// Finds the line at the given point
    /// - Parameter point: The point in gutter coordinates
    /// - Returns: Line information if a line was found
    private func findLine(at point: CGPoint) -> LineInfo? {
        guard let textView else { return nil }
        
        // Use TextKitLineNumberHelper to get visible line information
        let helper = TextKitLineNumberHelper(textView: textView)
        let lineRanges = helper.getVisibleLineRanges()
        
        // Find the line that contains the point
        for (lineNumber, lineRange) in lineRanges {
            if let lineRect = getLineRect(for: lineRange) {
                if lineRect.minY <= point.y && point.y <= lineRect.maxY {
                    return LineInfo(lineNumber: lineNumber, lineRect: lineRect)
                }
            }
        }
        
        return nil
    }
    
    /// Gets the rectangle for a line range
    /// - Parameter range: The text range of the line
    /// - Returns: The rectangle in gutter coordinates
    private func getLineRect(for range: NSRange) -> CGRect? {
        guard let textView,
              let gutterView else { return nil }
        
        // Get the rectangle from the text view
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        
        // Convert to gutter coordinates
        lineRect = textView.convert(lineRect, to: gutterView)
        return lineRect
        
        #else
        // iOS: Use text container to get line rectangle
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil, withoutAdditionalLayout: true)
        
        // Adjust for text container offset
        lineRect.origin.x += textView.textContainerInset.left
        lineRect.origin.y += textView.textContainerInset.top
        
        // Convert to gutter coordinates
        lineRect = textView.convert(lineRect, to: gutterView)
        return lineRect
        #endif
    }
    
    // MARK: - Folding Control Hit Testing
    
    /// Checks if a point hits the folding control for a line
    /// - Parameters:
    ///   - point: The point in gutter coordinates
    ///   - lineInfo: Information about the line
    /// - Returns: Whether the folding control was hit
    private func isFoldingControlHit(at point: CGPoint, for lineInfo: LineInfo) -> Bool {
        guard let textView,
              let gutterView else { return false }
        
        // Check if this line is foldable
        guard textView.isFoldable(at: lineInfo.lineNumber) else {
            return false
        }
        
        // Calculate folding control position
        let controlX = gutterView.bounds.width - foldingControlSize - foldingControlMargin
        let controlY = lineInfo.lineRect.midY - foldingControlSize / 2
        let controlRect = CGRect(
            x: controlX,
            y: controlY,
            width: foldingControlSize,
            height: foldingControlSize
        )
        
        // Check if point is within control rect (with some tolerance)
        let hitRect = controlRect.insetBy(dx: -2, dy: -2)
        return hitRect.contains(point)
    }
    
    // MARK: - Folding Actions
    
    /// Toggles folding for the specified line
    /// - Parameter lineNumber: The line number to toggle folding for
    private func toggleFolding(for lineNumber: Int) {
        guard let textView else { return }
        
        // Use the CodeEditorView's folding methods
        _ = textView.toggleFold(at: lineNumber)
        
        // Update the gutter display
        gutterView?.setNeedsDisplayLineNumbers()
        
        // Notify text view of folding change
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.needsDisplay = true
        #else
        textView.setNeedsDisplay()
        #endif
    }
}

// MARK: - GutterView Integration

extension GutterView {
    /// Sets up the interaction handler
    internal func setupInteractionHandler() {
        guard let textView else { return }
        _ = GutterInteractionHandler(gutterView: self, textView: textView)
    }
}
