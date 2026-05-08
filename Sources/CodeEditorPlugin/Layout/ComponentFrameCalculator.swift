import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Component Frame Calculator

/// Calculates frames for editor components (gutter, minimap, text view, scroll view)
@MainActor
public enum ComponentFrameCalculator {
    // MARK: - Layout Constants

    /// Ratio of minimap width to container width (15%)
    public static let minimapWidthRatio: CGFloat = 0.15

    /// Ratio of gutter width to container width (8%)
    public static let gutterWidthRatio: CGFloat = 0.08

    /// Minimum text view width to ensure readability
    public static let minimumTextViewWidth: CGFloat = 200

    // MARK: - Frame Calculations

    /// Calculates the gutter frame based on container bounds and configuration
    /// - Parameters:
    ///   - containerBounds: The bounds of the container
    ///   - configuration: The editor configuration
    ///   - constraints: Layout constraints to apply
    ///   - lineCount: Number of lines in the document
    ///   - gutterSizingService: Service for calculating gutter dimensions
    /// - Returns: The calculated gutter frame
    public static func calculateGutterFrame(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: EditorLayoutService.LayoutConstraints,
        lineCount: Int,
        gutterSizingService: GutterSizingService
    ) -> CGRect {
        guard configuration.display.isLineNumbersEnabled else {
            return .zero
        }

        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)
        let sizingResult = gutterSizingService.calculateOptimalWidth(
            lineCount: lineCount,
            font: font,
            configuration: configuration
        )

        let width = max(
            constraints.minimumGutterWidth,
            min(constraints.maximumGutterWidth, sizingResult.recommendedWidth)
        )

        return CGRect(
            x: containerBounds.minX,
            y: containerBounds.minY,
            width: width,
            height: containerBounds.height
        )
    }

    /// Calculates the minimap frame based on container bounds and configuration
    /// - Parameters:
    ///   - containerBounds: The bounds of the container
    ///   - configuration: The editor configuration
    ///   - constraints: Layout constraints to apply
    ///   - gutterFrame: The calculated gutter frame
    /// - Returns: The calculated minimap frame
    public static func calculateMinimapFrame(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: EditorLayoutService.LayoutConstraints,
        gutterFrame: CGRect
    ) -> CGRect {
        guard configuration.display.isMinimapVisible else {
            return .zero
        }

        let availableWidth = containerBounds.width - gutterFrame.width
        let proposedWidth = availableWidth * minimapWidthRatio

        let width = max(
            constraints.minimumMinimapWidth,
            min(constraints.maximumMinimapWidth, proposedWidth)
        )

        return CGRect(
            x: containerBounds.maxX - width,
            y: containerBounds.minY,
            width: width,
            height: containerBounds.height
        )
    }

    /// Calculates the text view frame based on container bounds and other component frames
    /// - Parameters:
    ///   - containerBounds: The bounds of the container
    ///   - gutterFrame: The calculated gutter frame
    ///   - minimapFrame: The calculated minimap frame
    /// - Returns: The calculated text view frame
    public static func calculateTextViewFrame(
        containerBounds: CGRect,
        gutterFrame: CGRect,
        minimapFrame: CGRect
    ) -> CGRect {
        let leftMargin = gutterFrame.width
        let rightMargin = minimapFrame.width

        let x = containerBounds.minX + leftMargin
        let width = containerBounds.width - leftMargin - rightMargin

        return CGRect(
            x: x,
            y: containerBounds.minY,
            width: max(minimumTextViewWidth, width),
            height: containerBounds.height
        )
    }

    /// Calculates the scroll view frame (encompasses the text view)
    /// - Parameter textViewFrame: The calculated text view frame
    /// - Returns: The calculated scroll view frame
    public static func calculateScrollViewFrame(textViewFrame: CGRect) -> CGRect {
        // Scroll view encompasses the text view
        textViewFrame
    }

    /// Calculates text padding based on configuration
    /// - Parameter configuration: The editor configuration
    /// - Returns: Edge insets for text padding
    public static func calculateTextPadding(
        configuration: EditorConfiguration
    ) -> EditorLayoutService.EdgeInsets {
        let basePadding: CGFloat = 8.0
        let scaleFactor = configuration.display.fontSize / 14.0 // Scale with font size

        let adjustedPadding = basePadding * scaleFactor

        return EditorLayoutService.EdgeInsets(
            top: adjustedPadding,
            left: adjustedPadding,
            bottom: adjustedPadding,
            right: adjustedPadding
        )
    }

    /// Applies safe area constraints to bounds
    /// - Parameters:
    ///   - bounds: The original bounds
    ///   - constraints: Layout constraints containing safe area insets
    /// - Returns: Adjusted bounds with safe area applied
    public static func applyConstraints(
        _ bounds: CGRect,
        constraints: EditorLayoutService.LayoutConstraints
    ) -> CGRect {
        CGRect(
            x: bounds.minX + constraints.safeAreaInsets.left,
            y: bounds.minY + constraints.safeAreaInsets.top,
            width: bounds.width - constraints.safeAreaInsets.left - constraints.safeAreaInsets.right,
            height: bounds.height - constraints.safeAreaInsets.top - constraints.safeAreaInsets.bottom
        )
    }
}
