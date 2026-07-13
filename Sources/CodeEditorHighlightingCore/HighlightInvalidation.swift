import Foundation

/// The set of document regions a provider considers stale after an edit.
///
/// Returned from ``HighlightRangeProviding/invalidate(for:in:)``. The editor
/// re-queries only the intersection of these regions with the visible
/// viewport, so a provider may safely over-report (e.g. ``everything(length:)``)
/// without forcing a full off-screen repaint.
public struct HighlightInvalidation: Sendable, Equatable {
    /// The stale UTF-16 regions, in no particular order.
    public var ranges: [HighlightRange]

    /// Creates an invalidation result from explicit ranges.
    public init(ranges: [HighlightRange]) {
        self.ranges = ranges
    }

    /// An empty result — nothing needs re-highlighting.
    public static let none = HighlightInvalidation(ranges: [])

    /// A result covering a single range.
    public static func range(_ range: HighlightRange) -> HighlightInvalidation {
        HighlightInvalidation(ranges: [range])
    }

    /// A result covering the whole document `[0, length)`.
    ///
    /// Returns ``none`` when `length` is not positive.
    public static func everything(length: Int) -> HighlightInvalidation {
        length > 0
            ? HighlightInvalidation(ranges: [HighlightRange(location: 0, length: length)])
            : .none
    }

    /// Whether the result invalidates no characters.
    public var isEmpty: Bool { ranges.allSatisfy { $0.length == 0 } }
}
