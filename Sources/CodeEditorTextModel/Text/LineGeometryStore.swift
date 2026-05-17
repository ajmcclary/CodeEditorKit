import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - LineGeometry

/// Per-line geometry data stored in the tree.
///
/// `utf16Offset` is removed — line position is derived from subtree
/// metadata during tree traversal (O(log n)). Use
/// `LineGeometryStore.utf16Offset(forLineIndex:)` for the start offset
/// of any line.
public struct LineGeometry: Equatable, Sendable {
    /// Length of this line in UTF-16 code units (including the line terminator).
    public let utf16Length: Int

    /// Length of the line terminator: 1 for `\n` or `\r`, 2 for `\r\n`, 0 for
    /// the final line when the document does not end with a terminator.
    public let lineEndingLength: Int

    /// Estimated height from font metrics (always available).
    public let estimatedHeight: CGFloat

    /// Measured height from a layout pass (`nil` until first layout).
    public var measuredHeight: CGFloat?

    /// Whether this line is currently folded (collapsed).
    public var isFolded: Bool

    /// The effective height used for y-position calculations.
    public var effectiveHeight: CGFloat {
        if isFolded { return 0 }
        return measuredHeight ?? estimatedHeight
    }

    public init(
        utf16Length: Int,
        lineEndingLength: Int,
        estimatedHeight: CGFloat,
        measuredHeight: CGFloat? = nil,
        isFolded: Bool = false
    ) {
        self.utf16Length = utf16Length
        self.lineEndingLength = lineEndingLength
        self.estimatedHeight = estimatedHeight
        self.measuredHeight = measuredHeight
        self.isFolded = isFolded
    }
}

// MARK: - LineGeometryStore

/// Public facade over `LineGeometryTree`. Stores per-line geometry with
/// O(log n) lookup by UTF-16 offset, line index, and y-position. Supports
/// incremental updates so edits never require a full rebuild.
///
/// The tree mechanics (rotations, fixups, validation) and `NSTextStorage`
/// parsing live in `LineGeometryTree` and `LineGeometryBuilder` respectively;
/// this type is a thin coordinator the UI calls into.
///
/// - Important: All offsets are UTF-16 code unit offsets, matching `NSRange`
///   and TextKit conventions.
///
/// - Note: This is a `@MainActor` class, not an `actor`. Text edit events,
///   TextKit geometry, gutter updates, and folding state are UI-adjacent.
///   Async actor calls would spread through hot synchronous rendering paths.
@MainActor
public final class LineGeometryStore {
    // MARK: - Stored Properties

    private let tree: LineGeometryTree

    /// Number of lines in the store.
    public var lineCount: Int { tree.lineCount }

    /// Total UTF-16 length of all lines.
    public var totalUtf16Length: Int { tree.totalUtf16Length }

    /// Total height of all lines (respects fold state).
    public var totalHeight: CGFloat { tree.totalHeight }

    /// Default estimated line height used when no font is provided.
    public let defaultEstimatedHeight: CGFloat

    // MARK: - Initialization

    /// Creates a new empty line geometry store.
    /// - Parameter defaultEstimatedHeight: Default line height used until
    ///   measured heights are provided via `updateMeasuredHeight`.
    public init(defaultEstimatedHeight: CGFloat = 17.0) {
        self.defaultEstimatedHeight = defaultEstimatedHeight
        self.tree = LineGeometryTree()
    }

    // MARK: - Build

    /// Build the store from an `NSTextStorage` using `NSString` line
    /// enumeration for UTF-16 correctness.
    public func build(from textStorage: NSTextStorage) {
        let geometries = LineGeometryBuilder.geometries(
            from: textStorage,
            defaultEstimatedHeight: defaultEstimatedHeight
        )
        tree.replaceAll(geometries, defaultEstimatedHeight: defaultEstimatedHeight)
    }

    // MARK: - Lookup

    /// Returns the 0-based line index containing the given UTF-16 offset.
    /// O(log n).
    public func lineIndex(forUtf16Offset offset: Int) -> Int {
        tree.lineIndex(forUtf16Offset: offset)
    }

    /// Returns the UTF-16 start offset for the given 0-based line index.
    /// O(log n).
    public func utf16Offset(forLineIndex lineIndex: Int) -> Int {
        tree.utf16Offset(forLineIndex: lineIndex)
    }

    /// Returns the `LineGeometry` for the given 0-based line index, or `nil`
    /// if the index is out of bounds.
    public func lineGeometry(at lineIndex: Int) -> LineGeometry? {
        tree.lineGeometry(at: lineIndex)
    }

    /// Returns the `LineGeometry` containing the given UTF-16 offset.
    public func lineGeometry(atUtf16Offset offset: Int) -> LineGeometry? {
        tree.lineGeometry(atUtf16Offset: offset)
    }

    /// Returns the 0-based line index at the given y-position. O(log n).
    public func lineIndex(forYPosition y: CGFloat) -> Int {
        tree.lineIndex(forYPosition: y)
    }

    /// Returns the y-position of the start of the given line. O(log n).
    public func yPosition(forLineIndex lineIndex: Int) -> CGFloat {
        tree.yPosition(forLineIndex: lineIndex)
    }

    // MARK: - Height Updates

    /// Update the measured height for a line. Propagates subtree height
    /// changes upward. O(log n).
    public func updateMeasuredHeight(_ height: CGFloat, forLineAt lineIndex: Int) {
        tree.updateMeasuredHeight(height, forLineAt: lineIndex)
    }

    /// Set estimated heights for all lines using the given font metrics.
    /// O(n) — use sparingly, typically only on font changes.
    public func setEstimatedHeight(_ height: CGFloat) {
        tree.setEstimatedHeight(height)
    }

    // MARK: - Fold State

    /// Set the fold state for a line. Collapsed lines have effective height 0.
    /// O(log n).
    public func setFolded(_ folded: Bool, forLineAt lineIndex: Int) {
        tree.setFolded(folded, forLineAt: lineIndex)
    }

    // MARK: - Incremental Updates

    /// Insert one or more `LineGeometry` values at a line index.
    /// O(m log n) for m inserted lines.
    public func insertLines(_ lines: [LineGeometry], at lineIndex: Int) {
        tree.insertLines(lines, at: lineIndex)
    }

    /// Remove a range of lines. O(m log n) for m removed lines. Safe to call
    /// on an empty store — no-op when `lineCount == 0` or when `range` lies
    /// entirely outside `[0, lineCount)`.
    public func removeLines(in range: ClosedRange<Int>) {
        tree.removeLines(in: range)
    }

    /// Replace a single line's geometry. Preserves fold state unless
    /// explicitly changed. O(log n).
    public func replaceLine(at lineIndex: Int, with geometry: LineGeometry) {
        tree.replaceLine(at: lineIndex, with: geometry)
    }

    // MARK: - Reset / Validation

    /// Clear all data and return to initial empty state.
    public func reset() {
        tree.reset()
    }

    /// Validate red-black tree invariants. Returns `true` if valid. For use
    /// in debug builds and tests.
    public func validateTree() -> Bool {
        tree.validateTree()
    }
}

// MARK: - Iteration

extension LineGeometryStore {
    /// Returns an array of `LineGeometry` values for lines intersecting the
    /// given UTF-16 range.
    public func lineGeometries(in utf16Range: NSRange) -> [LineGeometry] {
        guard lineCount > 0 else { return [] }
        let startIndex = lineIndex(forUtf16Offset: utf16Range.location)
        let endOffset = utf16Range.location + utf16Range.length
        let endIndex = lineIndex(forUtf16Offset: max(0, endOffset - 1))
        guard startIndex <= endIndex else { return [] }
        var result: [LineGeometry] = []
        for idx in startIndex...endIndex {
            if let geom = lineGeometry(at: idx) {
                result.append(geom)
            }
        }
        return result
    }

    /// Returns an array of `LineGeometry` values for lines intersecting the
    /// given y-position range.
    public func lineGeometries(inYRange yRange: ClosedRange<CGFloat>) -> [LineGeometry] {
        guard lineCount > 0 else { return [] }
        let startIndex = lineIndex(forYPosition: yRange.lowerBound)
        let endIndex = lineIndex(forYPosition: yRange.upperBound)
        guard startIndex <= endIndex else { return [] }
        var result: [LineGeometry] = []
        for idx in startIndex...endIndex {
            if let geom = lineGeometry(at: idx) {
                result.append(geom)
            }
        }
        return result
    }

    /// Returns an array of all `LineGeometry` values in order.
    public var allLineGeometries: [LineGeometry] {
        var result: [LineGeometry] = []
        for idx in 0..<lineCount {
            if let geom = lineGeometry(at: idx) {
                result.append(geom)
            }
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension LineGeometryStore: CustomStringConvertible {
    nonisolated public var description: String {
        "LineGeometryStore"
    }
}
