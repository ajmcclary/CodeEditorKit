// MARK: - GutterViewRenderer
//
// This file provides a platform-agnostic renderer for the GutterView,
// consolidating all common drawing and calculation logic.

import CodeEditorPlatform
import CodeEditorTheming
import CoreGraphics
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Platform-agnostic renderer for drawing line numbers in the gutter
@MainActor
public class GutterViewRenderer {
    // MARK: - Properties

    /// Padding from the right edge of the gutter
    private let rightPadding: CGFloat = 8

    /// Theme-derived inactive line-number color. Defaults to the system
    /// secondary label; refreshed by `apply(theme:)`.
    public private(set) var themedLineNumberColor: PlatformColor = PlatformColors.secondaryLabel

    /// Theme-derived active line-number color. Defaults to the system
    /// label; refreshed by `apply(theme:)`.
    public private(set) var themedActiveLineNumberColor: PlatformColor = PlatformColors.label

    /// Theme-derived gutter background fill (UIKit only). `.clear` until a
    /// theme is applied; the draw path falls back to the system control
    /// background while this remains transparent.
    private var themedBackgroundFillColor: PlatformColor = .clear

    // MARK: - Initialization

    /// Creates a renderer with system-default colors. Themed colors are
    /// installed via `apply(theme:)`; before that call the inactive line
    /// numbers use the system secondary label color.
    public init() {}

    deinit {
        // Required by SwiftLint
    }

    /// Apply a theme to the renderer. The renderer is not a view, so no
    /// `setNeedsDisplay`; the owning `GutterView` triggers redraw via its
    /// `apply(theme:)` override.
    public func apply(theme: Theme) {
        themedLineNumberColor = PlatformColor(tokens: theme.style.editor.lineNumber)
        themedActiveLineNumberColor = PlatformColor(tokens: theme.style.editor.activeLineNumber)
        themedBackgroundFillColor = PlatformColor(tokens: theme.style.editor.gutterBackground)
    }

    /// Resolves the line-number color for a given 1-based line index. Returns
    /// `themedActiveLineNumberColor` when the line matches `activeLineNumber`;
    /// `themedLineNumberColor` otherwise.
    public func color(forLineNumber lineNumber: Int, activeLineNumber: Int?) -> PlatformColor {
        lineNumber == activeLineNumber ? themedActiveLineNumberColor : themedLineNumberColor
    }

    // MARK: - Public Interface

    /// Draw line numbers for the given text view in the specified rectangle
    /// - Parameters:
    ///   - rect: The rectangle to draw in
    ///   - context: The Core Graphics context to draw into
    ///   - textView: The text view to draw line numbers for
    ///   - gutterBounds: The bounds of the gutter view
    ///   - fillBackground: Whether to fill the background (UIKit only)
    ///   - activeLineNumber: 1-based line index containing the caret, or
    ///     `nil` to draw every line in the inactive color.
    public func draw(
        in rect: CGRect,
        context: CGContext,
        textView: CodeEditorView,
        gutterBounds: CGRect,
        fillBackground: Bool = false,
        activeLineNumber: Int? = nil
    ) {
        // Fill background if requested (UIKit needs this). Theme-applied
        // gutters use the editor's gutter background color; otherwise fall
        // back to the system control background.
        if fillBackground {
            let fillColor: PlatformColor
            if themedBackgroundFillColor.cgColor.alpha > 0 {
                fillColor = themedBackgroundFillColor
            } else {
                fillColor = PlatformColors.controlBackground
            }
            context.setFillColor(fillColor.cgColor)
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
                textView: textView,
                helper: helper
            )

            drawLineNumber(
                lineNumber,
                for: lineRange,
                color: color(forLineNumber: lineNumber, activeLineNumber: activeLineNumber),
                context: drawingContext
            )

            // Draw folding controls if enabled
            if textView.configuration.display.isCodeFoldingEnabled &&
               textView.configuration.display.areFoldingControlsVisible {
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
        let helper: TextKitLineNumberHelper
    }

    /// Draw a single line number
    private func drawLineNumber(
        _ lineNumber: Int,
        for lineRange: NSRange,
        color: PlatformColor,
        context: LineDrawingContext
    ) {
        // Calculate Y position directly from line number and actual text layout
        let yPosition = calculateLineNumberYPosition(
            lineNumber: lineNumber,
            lineRange: lineRange,
            font: context.font,
            textView: context.textView,
            helper: context.helper
        )

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
            color: color,
            alignment: .right,
            maxWidth: context.gutterBounds.width - rightPadding
        )

        // Restore graphics state
        UnifiedDrawingCoordinator.restoreGraphicsState()
    }

    /// Calculate the Y position for a line number. Uses the actual TextKit2
    /// layout fragment frame for the line so the gutter follows the
    /// rendered text height (which respects the paragraph style's
    /// `lineHeightMultiple`). The `LineGeometryStore` carries unmeasured
    /// estimates and drifts from the rendered y by ~2pt per line; relying
    /// on it accumulated multi-line misalignment by line ~20.
    private func calculateLineNumberYPosition(
        lineNumber: Int,
        lineRange: NSRange,
        font: PlatformFont,
        textView: CodeEditorView,
        helper: TextKitLineNumberHelper
    ) -> CGFloat {
        let fontLineHeight = TextMetricsCalculator.calculateLineHeight(for: font)

        if let lineRect = helper.getLineFragmentRect(for: lineRange) {
            #if canImport(AppKit)
            // NSRulerView's draw context is synced to the document view's
            // coordinate space, but `layoutFragmentFrame` is in the text
            // container's coords — offset by `textContainerOrigin`.
            return textView.textContainerOrigin.y + lineRect.minY
                + (lineRect.height - fontLineHeight) / 2
            #else
            // iOS: gutter is a sibling view; account for inset + scroll.
            return lineRect.minY + textView.textContainerInset.top
                - textView.contentOffset.y
                + (lineRect.height - fontLineHeight) / 2
            #endif
        }

        // Fallback when TextKit2 hasn't laid out fragments yet.
        let lineIndex = max(0, lineNumber - 1)
        return CGFloat(lineIndex) * fontLineHeight
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

        #if canImport(AppKit)
        // macOS: Position control to the left of line numbers
        let xPosition = controlPadding
        let yPosition = lineRect.minY + (lineRect.height - controlSize) / 2
        #else
        // iOS: Account for text container inset and scroll offset
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
