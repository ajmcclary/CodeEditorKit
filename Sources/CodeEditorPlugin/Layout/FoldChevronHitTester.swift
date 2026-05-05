import CoreGraphics
import Foundation

/// Hit-test geometry for the gutter's fold chevron. The chevron rect is
/// 16 points wide, full line-height tall, anchored at the leading edge of
/// the gutter (left of the line number). Pure-value module so the
/// interaction handler can determine fold-toggle hits without owning any
/// view state.
public enum FoldChevronHitTester {
    /// Returns the chevron's hit rectangle for a single line.
    public static func hitRect(forLineHeight lineHeight: CGFloat, atY y: CGFloat) -> CGRect {
        CGRect(x: 0, y: y, width: 16, height: lineHeight)
    }

    /// Returns the index of the line whose chevron rect contains `point`,
    /// or nil if the point is outside every chevron's rect.
    public static func chevronHit(
        at point: CGPoint,
        lineHeight: CGFloat,
        visibleLineYs: [CGFloat]
    ) -> Int? {
        for (index, y) in visibleLineYs.enumerated()
            where hitRect(forLineHeight: lineHeight, atY: y).contains(point) {
            return index
        }
        return nil
    }
}
