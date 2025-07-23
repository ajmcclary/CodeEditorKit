import Foundation

/// Cache for line indices to optimize line number calculations
final class LineIndexCache {
    // MARK: - Types

    private struct CacheEntry {
        let text: String
        let lineOffsets: [Int] // Character offsets for start of each line
        let lineCount: Int
        let textHash: Int
    }

    // MARK: - Properties

    private var cache: CacheEntry?

    // MARK: - Public Methods

    /// Get line number for a character position
    func lineNumber(at position: Int, in text: String) -> Int {
        let entry = ensureCacheValid(for: text)

        // Binary search for the line containing this position
        var left = 0
        var right = entry.lineOffsets.count - 1

        while left < right {
            let mid = (left + right + 1) / 2
            if entry.lineOffsets[mid] <= position {
                left = mid
            } else {
                right = mid - 1
            }
        }

        return left + 1 // Convert to 1-based line numbers
    }

    /// Get line number for a String.Index position
    func lineNumber(at position: String.Index, in text: String) -> Int {
        let offset = text.distance(from: text.startIndex, to: position)
        return lineNumber(at: offset, in: text)
    }

    /// Get the character range for a line number (1-based)
    func lineRangeNSRange(for lineNumber: Int, in text: String) -> NSRange? {
        guard lineNumber > 0 else { return nil }

        let entry = ensureCacheValid(for: text)
        guard lineNumber <= entry.lineCount else { return nil }

        let lineIndex = lineNumber - 1 // Convert to 0-based
        let startOffset = entry.lineOffsets[lineIndex]

        let endOffset: Int
        if lineIndex + 1 < entry.lineOffsets.count {
            // Not the last line - end at the start of the next line
            endOffset = entry.lineOffsets[lineIndex + 1]
        } else {
            // Last line - end at the end of the text
            endOffset = text.count
        }

        return NSRange(location: startOffset, length: endOffset - startOffset)
    }

    /// Get the String.Index range for a line number (1-based)
    func lineRange(for lineNumber: Int, in text: String) -> Range<String.Index>? {
        guard let nsRange = lineRangeNSRange(for: lineNumber, in: text),
              let range = Range(nsRange, in: text) else { return nil }
        return range
    }

    /// Get total number of lines in the text
    func lineCount(in text: String) -> Int {
        let entry = ensureCacheValid(for: text)
        return entry.lineCount
    }

    /// Get all line offsets (for batch operations)
    func lineOffsets(in text: String) -> [Int] {
        let entry = ensureCacheValid(for: text)
        return entry.lineOffsets
    }

    /// Clear the cache
    func invalidate() {
        cache = nil
    }

    /// Pre-warm cache for visible content on file load
    /// This reduces first-run performance variation by building the cache proactively
    func preWarmCache(for text: String, visibleRange: NSRange) {
        // Build cache for visible range + buffer to handle immediate scrolling
        let bufferSize = min(1_000, text.count / 10)
        let warmupRange = NSRange(
            location: max(0, visibleRange.location - bufferSize),
            length: min(
                text.count - visibleRange.location + bufferSize,
                visibleRange.length + (bufferSize * 2)
            )
        )

        // Ensure cache is built
        _ = ensureCacheValid(for: text)

        // Pre-calculate line info for the warmup range to populate internal caches
        _ = visibleLineInfo(in: text, visibleRange: warmupRange)
    }

    // MARK: - Private Methods

    private func ensureCacheValid(for text: String) -> CacheEntry {
        // Check if cache is valid
        if let existingCache = cache,
           existingCache.text.hashValue == text.hashValue,
           existingCache.text == text {
            return existingCache
        }

        // Build new cache
        let entry = buildCache(for: text)
        cache = entry
        return entry
    }

    private func buildCache(for text: String) -> CacheEntry {
        var lineOffsets: [Int] = [0] // First line always starts at offset 0
        var currentOffset = 0

        // Find all newline positions
        for char in text {
            currentOffset += 1
            if char == "\n" {
                lineOffsets.append(currentOffset)
            }
        }

        // Calculate line count
        let lineCount = lineOffsets.count

        return CacheEntry(
            text: text,
            lineOffsets: lineOffsets,
            lineCount: lineCount,
            textHash: text.hashValue
        )
    }
}

/// Optimized line calculations for visible ranges
extension LineIndexCache {
    /// Get line numbers and ranges for a visible character range
    func visibleLineInfo(
        in text: String,
        visibleRange: NSRange
    ) -> [(lineNumber: Int, range: NSRange)] {
        _ = ensureCacheValid(for: text)

        // Find the first line that intersects with the visible range
        let startLine = lineNumber(at: visibleRange.location, in: text)

        // Find the last line that intersects with the visible range
        let endPosition = min(visibleRange.location + visibleRange.length, text.count)
        let endLine = lineNumber(at: max(0, endPosition - 1), in: text)

        // Collect all lines in the range
        var result: [(lineNumber: Int, range: NSRange)] = []

        for lineNum in startLine...endLine {
            if let range = lineRangeNSRange(for: lineNum, in: text) {
                result.append((lineNumber: lineNum, range: range))
            }
        }

        return result
    }
}
