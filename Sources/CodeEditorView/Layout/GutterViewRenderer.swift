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

    /// Draw line numbers for the given text view in the specified rectangle.
    ///
    /// Walks `NSTextLayoutFragment`s in the viewport range and anchors each
    /// line number against the first non-extra `NSTextLineFragment` of its
    /// fragment, so a wrapped logical line shows its number at the top of
    /// the wrapped block (cell Y and cell height come from the first visual
    /// line, never the multi-visual-line fragment frame).
    /// - Parameters:
    ///   - rect: The rectangle to draw in
    ///   - context: The Core Graphics context to draw into
    ///   - textView: The text view to draw line numbers for
    ///   - gutterBounds: The bounds of the gutter view
    ///   - fillBackground: Whether to fill the background (UIKit needs this)
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
        if fillBackground {
            let fillColor: PlatformColor = themedBackgroundFillColor.cgColor.alpha > 0
                ? themedBackgroundFillColor
                : PlatformColors.controlBackground
            context.setFillColor(fillColor.cgColor)
            context.fill(rect)
        }

        guard let textLayoutManager = textView.textLayoutManager else { return }
        let viewportController = textLayoutManager.textViewportLayoutController
        // In production the viewport layout controller has populated
        // `viewportRange` by the time we draw. In headless tests no viewport
        // layout pass has run, so fall back to the document range.
        let iterationRange = viewportController.viewportRange ?? textLayoutManager.documentRange
        textLayoutManager.ensureLayout(for: iterationRange)

        let font = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let fontLineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
        let bridge = TextKitBridge(textView: textView)

        #if canImport(AppKit)
        let scrollOffsetY = textView.visibleRect.origin.y - textView.textContainerOrigin.y
        let visibleHeight = textView.visibleRect.height
        #else
        let scrollOffsetY = textView.contentOffset.y - textView.textContainerInset.top
        let visibleHeight = textView.bounds.height
        #endif
        let visibleTopY = scrollOffsetY
        let visibleBottomY = scrollOffsetY + visibleHeight

        let foldingEnabled = textView.configuration.display.isCodeFoldingEnabled
            && textView.configuration.display.areFoldingControlsVisible

        textLayoutManager.enumerateTextLayoutFragments(
            from: iterationRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            // Stop once we've passed the visible bottom.
            if fragment.layoutFragmentFrame.minY >= visibleBottomY {
                return false
            }
            // Skip fragments above the visible top (still iterate forward).
            if fragment.layoutFragmentFrame.maxY <= visibleTopY {
                return true
            }
            guard let firstLine = fragment.textLineFragments.first(where: { !$0.isExtraLineFragment }) else {
                return fragment.layoutFragmentFrame.maxY < visibleBottomY
            }
            guard let fragmentRange = bridge.nsRangeFromTextRange(fragment.rangeInElement) else {
                return fragment.layoutFragmentFrame.maxY < visibleBottomY
            }
            let lineNumber = textView.lineGeometryStore.lineIndex(forUtf16Offset: fragmentRange.location) + 1
            let cellY = fragment.layoutFragmentFrame.minY + firstLine.typographicBounds.minY - scrollOffsetY
            let cellHeight = firstLine.typographicBounds.height
            let drawColor: PlatformColor = (lineNumber == activeLineNumber)
                ? themedActiveLineNumberColor
                : themedLineNumberColor

            UnifiedDrawingCoordinator.saveGraphicsState()
            UnifiedDrawingCoordinator.drawLineNumber(
                lineNumber,
                at: CGPoint(x: 0, y: cellY + (cellHeight - fontLineHeight) / 2),
                font: font,
                color: drawColor,
                alignment: .right,
                maxWidth: gutterBounds.width - rightPadding
            )
            UnifiedDrawingCoordinator.restoreGraphicsState()

            if foldingEnabled, textView.isFoldable(at: lineNumber) {
                let controlSize = textView.configuration.layout.foldingControlSize
                let controlPadding = textView.configuration.layout.foldingControlPadding
                let controlRect = CGRect(
                    x: controlPadding,
                    y: cellY + (cellHeight - controlSize) / 2,
                    width: controlSize,
                    height: controlSize
                )
                if controlRect.intersects(CGRect(origin: .zero, size: gutterBounds.size)) {
                    drawFoldingIcon(
                        in: controlRect,
                        isFolded: textView.isFolded(at: lineNumber),
                        context: context,
                        textView: textView
                    )
                }
            }

            return fragment.layoutFragmentFrame.maxY < visibleBottomY
        }
    }

    // MARK: - Private Helpers

    /// Draw the folding icon (▶️ for folded, ▼ for expanded)
    private func drawFoldingIcon(
        in rect: CGRect,
        isFolded: Bool,
        context: CGContext,
        textView _: CodeEditorView
    ) {
        context.saveGState()

        let iconColor = PlatformColors.secondaryLabel
        let backgroundColor = PlatformColors.controlBackground

        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: rect)

        context.setStrokeColor(iconColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.strokeEllipse(in: rect)

        context.setFillColor(iconColor.cgColor)

        let iconInset: CGFloat = rect.width * 0.25
        let iconRect = rect.insetBy(dx: iconInset, dy: iconInset)

        if isFolded {
            drawTriangleIcon(in: iconRect, pointing: .right, context: context)
        } else {
            drawTriangleIcon(in: iconRect, pointing: .down, context: context)
        }

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
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()

        case .down:
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
