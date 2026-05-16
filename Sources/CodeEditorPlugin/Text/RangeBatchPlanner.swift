import CoreGraphics
import Foundation

// MARK: - RangeBatchPlanner

/// Slices large documents into processing batches and computes viewport
/// ranges. Owns the heuristics that bias batches toward line boundaries
/// and estimate per-batch processing time.
internal enum RangeBatchPlanner {
    /// Information about a batch range for processing large text efficiently.
    struct BatchRange {
        let range: NSRange
        let batchIndex: Int
        let isLastBatch: Bool
        let estimatedProcessingTime: TimeInterval
    }

    /// Slice a document into batches of at most `batchSize` UTF-16 units.
    /// When `preferLineBoundaries` is true and `text` is provided, batches
    /// snap back to the last newline within their target span.
    static func plan(
        totalLength: Int,
        batchSize: Int,
        preferLineBoundaries: Bool = true,
        text: String? = nil
    ) -> [BatchRange] {
        guard totalLength > 0, batchSize > 0 else { return [] }

        var batches: [BatchRange] = []
        var currentLocation = 0
        var batchIndex = 0

        while currentLocation < totalLength {
            let remainingLength = totalLength - currentLocation
            var batchLength = min(batchSize, remainingLength)

            if preferLineBoundaries, batchLength < remainingLength, let text {
                batchLength = adjustBatchLengthToLineBoundary(
                    text: text,
                    startLocation: currentLocation,
                    targetLength: batchLength
                )
            }

            let range = NSRange(location: currentLocation, length: batchLength)
            let isLastBatch = NSMaxRange(range) >= totalLength
            let estimatedTime = estimateProcessingTime(for: batchLength)

            batches.append(BatchRange(
                range: range,
                batchIndex: batchIndex,
                isLastBatch: isLastBatch,
                estimatedProcessingTime: estimatedTime
            ))

            currentLocation += batchLength
            batchIndex += 1
        }

        return batches
    }

    /// Process UTF-16 ranges in ascending order, mapping each through `operation`.
    static func batchProcess<T>(
        ranges: [NSRange],
        in string: String,
        operation: (NSRange, String) -> T
    ) -> [T] {
        ranges.sorted { $0.location < $1.location }.map { operation($0, string) }
    }

    /// UTF-16 range visible in a viewport given line metrics.
    static func visibleRanges(
        in viewport: CGRect,
        lineHeight: CGFloat,
        totalLines: Int,
        string: String
    ) -> [NSRange] {
        guard lineHeight > 0, totalLines > 0 else { return [] }

        let firstVisibleLine = max(0, Int(viewport.minY / lineHeight))
        let lastVisibleLine = min(totalLines - 1, Int(viewport.maxY / lineHeight) + 1)
        let ranges = LineRangeIndex.lineRanges(in: string)
        guard firstVisibleLine < ranges.count else { return [] }

        let endLine = min(lastVisibleLine, ranges.count - 1)
        guard firstVisibleLine <= endLine else { return [] }
        let visible = ranges[firstVisibleLine...endLine]
        guard let first = visible.first, let last = visible.last else { return [] }

        return [NSRange(location: first.location, length: NSMaxRange(last) - first.location)]
    }

    // MARK: - Private Heuristics

    private static func adjustBatchLengthToLineBoundary(
        text: String,
        startLocation: Int,
        targetLength: Int
    ) -> Int {
        let textLength = UTF16RangeConverter.utf16Length(of: text)
        let endLocation = min(startLocation + targetLength, textLength)
        let searchRange = NSRange(location: startLocation, length: endLocation - startLocation)

        if let searchText = UTF16RangeConverter.substring(inUTF16Range: searchRange, from: text),
           let lastNewlineRange = searchText.range(of: "\n", options: .backwards) {
            let prefixThroughNewline = searchText[..<lastNewlineRange.upperBound]
            return UTF16RangeConverter.utf16Length(of: String(prefixThroughNewline))
        }

        return targetLength
    }

    private static func estimateProcessingTime(for length: Int) -> TimeInterval {
        // Simple heuristic: 1ms per 1000 characters.
        Double(length) / 1_000.0 * 0.001
    }
}
