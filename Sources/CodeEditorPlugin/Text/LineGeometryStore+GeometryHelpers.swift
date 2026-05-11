import CoreGraphics
import Foundation

// MARK: - LineGeometryStore + Geometry Helpers

extension LineGeometryStore {
    /// Returns the estimated bounding rectangle for a line, using the
    /// store's y-position and effective height. Width is provided by
    /// the caller (typically the text container width).
    ///
    /// - Parameters:
    ///   - lineIndex: 0-based line index.
    ///   - containerWidth: Width of the text container.
    /// - Returns: A rectangle spanning the full width at the line's
    ///   y-position with the line's effective height, or `.zero` if
    ///   the line index is out of bounds.
    public func estimatedRect(forLineAt lineIndex: Int,
                              containerWidth: CGFloat) -> CGRect {
        guard lineIndex >= 0, lineIndex < lineCount,
              let geom = lineGeometry(at: lineIndex) else {
            return .zero
        }
        let y = yPosition(forLineIndex: lineIndex)
        return CGRect(x: 0, y: y, width: containerWidth, height: geom.effectiveHeight)
    }

    /// Returns the estimated bounding rectangles for all lines
    /// intersecting the given y-range.
    ///
    /// - Parameters:
    ///   - yRange: The vertical range to query.
    ///   - containerWidth: Width of the text container.
    /// - Returns: Array of rectangles, one per line in the range.
    public func estimatedRects(inYRange yRange: ClosedRange<CGFloat>,
                               containerWidth: CGFloat) -> [CGRect] {
        let geoms = lineGeometries(inYRange: yRange)
        return geoms.map { geom in
            let y = yPosition(forLineIndex: lineIndex(forUtf16Offset: geom.utf16Offset))
            return CGRect(x: 0, y: y, width: containerWidth, height: geom.effectiveHeight)
        }
    }

    /// Returns the estimated bounding rectangles for all lines
    /// intersecting the given UTF-16 range.
    ///
    /// - Parameters:
    ///   - utf16Range: The text range to query.
    ///   - containerWidth: Width of the text container.
    /// - Returns: Array of rectangles, one per line in the range.
    public func estimatedRects(in utf16Range: NSRange,
                               containerWidth: CGFloat) -> [CGRect] {
        let geoms = lineGeometries(in: utf16Range)
        return geoms.map { geom in
            let y = yPosition(forLineIndex: lineIndex(forUtf16Offset: geom.utf16Offset))
            return CGRect(x: 0, y: y, width: containerWidth, height: geom.effectiveHeight)
        }
    }

    /// Returns the 0-based line index closest to a given point, using the
    /// store's y-position data. This is a geometry-only lookup — it does
    /// not query TextKit2 for fragment-level precision.
    ///
    /// - Parameter point: A point in the text view's coordinate space.
    /// - Returns: The line index at that y-position.
    public func lineIndex(at point: CGPoint) -> Int {
        lineIndex(forYPosition: point.y)
    }

    /// Returns the visible line range (inclusive) for a given visible rect,
    /// plus optional vertical padding.
    ///
    /// - Parameters:
    ///   - visibleRect: The currently visible rectangle.
    ///   - padding: Extra lines to include above and below (default: 1).
    /// - Returns: A closed range of 0-based line indices.
    public func visibleLineRange(for visibleRect: CGRect,
                                  padding: Int = 1) -> ClosedRange<Int> {
        let top = visibleRect.minY
        let bottom = visibleRect.maxY
        let start = max(0, lineIndex(forYPosition: top) - padding)
        let end = min(lineCount - 1, lineIndex(forYPosition: bottom) + padding)
        return start...end
    }
}
