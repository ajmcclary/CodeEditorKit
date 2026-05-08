import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Unified range handling utilities for consistent range operations across the codebase
public enum RangeUtilities {
    // MARK: - Performance Cache

    /// Actor-based cache for thread-safe range operation caching
    /// This replaces the previous cache that was removed for concurrency compliance
    private static let cache = RangeCacheActor()
    // MARK: - Range Conversion

    /// Convert NSRange to NSTextRange
    public static func convert(_ nsRange: NSRange, in textContentManager: NSTextContentManager) -> NSTextRange? {
        let documentRange = textContentManager.documentRange

        let startLocation = textContentManager.location(documentRange.location, offsetBy: nsRange.location)
        guard let startLocation else { return nil }

        let endLocation = textContentManager.location(startLocation, offsetBy: nsRange.length)
        guard let endLocation else { return nil }

        return NSTextRange(location: startLocation, end: endLocation)
    }

    /// Convert NSTextRange to NSRange
    public static func convert(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) -> NSRange? {
        let documentRange = textContentManager.documentRange

        let startOffset = textContentManager.offset(from: documentRange.location, to: textRange.location)
        let length = textContentManager.offset(from: textRange.location, to: textRange.endLocation)

        guard startOffset != NSNotFound, length != NSNotFound else { return nil }

        return NSRange(location: startOffset, length: length)
    }

    /// Convert Swift Range to NSRange
    public static func convert(_ range: Range<String.Index>, in string: String) -> NSRange {
        NSRange(range, in: string)
    }

    /// Convert NSRange to Swift Range
    public static func convert(_ nsRange: NSRange, in string: String) -> Range<String.Index>? {
        Range(nsRange, in: string)
    }

    // MARK: - Range Validation

    /// Validate that a range is within bounds of a string
    public static func validate(_ range: NSRange, in string: String) -> Bool {
        range.location >= 0 &&
        range.length >= 0 &&
        NSMaxRange(range) <= string.count
    }

    /// Validate and clamp a range to string bounds
    public static func clamp(_ range: NSRange, to string: String) -> NSRange {
        let maxLocation = string.count
        let clampedLocation = min(max(0, range.location), maxLocation)
        let maxLength = maxLocation - clampedLocation
        let clampedLength = min(max(0, range.length), maxLength)

        return NSRange(location: clampedLocation, length: clampedLength)
    }

    /// Check if a range is empty
    public static func isEmpty(_ range: NSRange) -> Bool {
        range.length == 0
    }

    // MARK: - Range Operations

    /// Merge overlapping or adjacent ranges
    public static func merge(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }

        // Sort ranges by location
        let sorted = ranges.sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        var current = sorted[0]

        for index in 1..<sorted.count {
            let next = sorted[index]

            // Check if ranges overlap or are adjacent
            if NSMaxRange(current) >= next.location {
                // Merge ranges
                let newEnd = max(NSMaxRange(current), NSMaxRange(next))
                current = NSRange(location: current.location, length: newEnd - current.location)
            } else {
                // No overlap, add current and move to next
                merged.append(current)
                current = next
            }
        }

        merged.append(current)
        return merged
    }

    /// Find intersection of two ranges
    public static func intersect(_ range1: NSRange, _ range2: NSRange) -> NSRange? {
        let intersection = NSIntersectionRange(range1, range2)
        return intersection.length > 0 ? intersection : nil
    }

    /// Check if two ranges overlap
    public static func overlaps(_ range1: NSRange, _ range2: NSRange) -> Bool {
        NSIntersectionRange(range1, range2).length > 0
    }

    /// Check if range1 contains range2
    public static func contains(_ range1: NSRange, _ range2: NSRange) -> Bool {
        range2.location >= range1.location && NSMaxRange(range2) <= NSMaxRange(range1)
    }

    /// Subtract range2 from range1, returning remaining ranges
    public static func subtract(_ range2: NSRange, from range1: NSRange) -> [NSRange] {
        // No intersection, return original
        guard let intersection = intersect(range1, range2) else {
            return [range1]
        }

        // Complete overlap, return empty
        if NSEqualRanges(intersection, range1) {
            return []
        }

        var result: [NSRange] = []

        // Add part before intersection
        if intersection.location > range1.location {
            result.append(NSRange(
                location: range1.location,
                length: intersection.location - range1.location
            ))
        }

        // Add part after intersection
        let intersectionEnd = NSMaxRange(intersection)
        let range1End = NSMaxRange(range1)
        if intersectionEnd < range1End {
            result.append(NSRange(
                location: intersectionEnd,
                length: range1End - intersectionEnd
            ))
        }

        return result
    }

    // MARK: - Range Adjustment

    /// Adjust ranges after text insertion
    public static func adjustRangesForInsertion(
        _ ranges: [NSRange],
        insertionPoint: Int,
        insertionLength: Int
    ) -> [NSRange] {
        ranges.map { range in
            if range.location >= insertionPoint {
                // Range is after insertion point, shift it
                return NSRange(location: range.location + insertionLength, length: range.length)
            } else if NSLocationInRange(insertionPoint, range) {
                // Insertion is within range, expand it
                return NSRange(location: range.location, length: range.length + insertionLength)
            } else {
                // Range is before insertion point, no change
                return range
            }
        }
    }

    /// Adjust ranges after text deletion
    public static func adjustRangesForDeletion(
        _ ranges: [NSRange],
        deletionRange: NSRange
    ) -> [NSRange] {
        var adjusted: [NSRange] = []

        for range in ranges {
            // Check various overlap scenarios
            if NSMaxRange(range) <= deletionRange.location {
                // Range is completely before deletion
                adjusted.append(range)
            } else if range.location >= NSMaxRange(deletionRange) {
                // Range is completely after deletion
                adjusted.append(NSRange(
                    location: range.location - deletionRange.length,
                    length: range.length
                ))
            } else if contains(deletionRange, range) {
                // Range is completely within deletion, remove it
                continue
            } else if contains(range, deletionRange) {
                // Deletion is within range, shrink it
                let newLength = range.length - deletionRange.length
                // Ensure length is never negative
                if newLength > 0 {
                    adjusted.append(NSRange(
                        location: range.location,
                        length: newLength
                    ))
                }
            } else {
                // Partial overlap, adjust accordingly
                let intersection = NSIntersectionRange(range, deletionRange)
                if intersection.location == range.location {
                    // Overlap at start
                    let newLength = range.length - intersection.length
                    // Ensure length is never negative
                    if newLength > 0 {
                        adjusted.append(NSRange(
                            location: deletionRange.location,
                            length: newLength
                        ))
                    }
                } else {
                    // Overlap at end
                    let newLength = range.location + range.length - NSMaxRange(deletionRange)
                    // Ensure length is never negative
                    if newLength > 0 {
                        adjusted.append(NSRange(
                            location: range.location,
                            length: newLength
                        ))
                    }
                }
            }
        }

        return adjusted
    }

    // MARK: - Line-based Operations

    /// Get line range containing the given character index
    public static func lineRange(containing index: Int, in string: String) -> NSRange {
        // Use Swift's native line enumeration
        var lineStart = 0

        string.enumerateSubstrings(in: string.startIndex..<string.endIndex, options: [.byLines, .substringNotRequired]) { _, range, _, stop in
            let nsRange = NSRange(range, in: string)

            if index >= nsRange.location && index < NSMaxRange(nsRange) {
                lineStart = nsRange.location
                stop = true
            } else if index < nsRange.location {
                stop = true
            } else {
                lineStart = NSMaxRange(nsRange)
            }
        }

        // Find the end of the line containing the index
        if index <= string.count {
            var lineEnd = lineStart
            let searchStart = string.index(string.startIndex, offsetBy: max(0, lineStart))

            for char in string[searchStart...] {
                if char == "\n" {
                    lineEnd += 1
                    break
                }
                lineEnd += 1
            }

            return NSRange(location: lineStart, length: lineEnd - lineStart)
        }

        return NSRange(location: lineStart, length: 0)
    }

    /// Get all line ranges in a string
    /// Get line ranges with performance optimizations
    public static func lineRanges(in string: String) -> [NSRange] {
        // Optimized: pre-allocate array with estimated capacity
        var ranges: [NSRange] = []
        ranges.reserveCapacity(string.count / 50) // Estimate lines

        string.enumerateSubstrings(
            in: string.startIndex..<string.endIndex,
            options: [.byLines, .substringNotRequired]
        ) { _, range, _, _ in
            ranges.append(NSRange(range, in: string))
        }

        return ranges
    }

    /// Get all line ranges in a string with caching (async version)
    /// This version provides caching for expensive operations
    public static func lineRangesAsync(in string: String) async -> [NSRange] {
        // Check cache first
        let cached = await cache.getCachedLineRanges(for: string)
        if !cached.isEmpty {
            return cached
        }

        // Compute ranges
        let ranges = lineRanges(in: string)

        // Cache the result
        await cache.cacheLineRanges(ranges, for: string)

        return ranges
    }

    /// Get line number for a given character index (0-based) - optimized version
    public static func lineNumber(for index: Int, in string: String) -> Int {
        guard index >= 0 && index <= string.count else { return 0 }

        // Optimized: count newlines directly without creating substring or array
        var lineCount = 0
        var currentIndex = string.startIndex
        let targetIndex = string.index(string.startIndex, offsetBy: min(index, string.count))

        while currentIndex < targetIndex {
            if string[currentIndex] == "\n" {
                lineCount += 1
            }
            currentIndex = string.index(after: currentIndex)
        }

        return lineCount
    }

    /// Get character index for start of line (0-based line number)
    public static func startOfLine(_ lineNumber: Int, in string: String) -> Int? {
        let lines = lineRanges(in: string)
        guard lineNumber >= 0 && lineNumber < lines.count else { return nil }
        return lines[lineNumber].location
    }

    // MARK: - Word-based Operations

    /// Get word range at the given character index
    public static func wordRange(at index: Int, in string: String) -> NSRange? {
        guard index >= 0 && index <= string.count else { return nil }

        // Convert to String.Index
        guard let stringIndex = string.index(string.startIndex, offsetBy: index, limitedBy: string.endIndex) else {
            return nil
        }

        // Find the start of the word
        var start = stringIndex
        while start > string.startIndex {
            let prevIndex = string.index(before: start)
            let char = string[prevIndex]
            if char.isLetter || char.isNumber || char == "_" {
                start = prevIndex
            } else {
                break
            }
        }

        // Find the end of the word
        var end = stringIndex
        while end < string.endIndex {
            let char = string[end]
            if char.isLetter || char.isNumber || char == "_" {
                end = string.index(after: end)
            } else {
                break
            }
        }

        // If we're not in a word, expand to include the current character
        if start == end && stringIndex < string.endIndex {
            let char = string[stringIndex]
            if char.isLetter || char.isNumber || char == "_" {
                end = string.index(after: stringIndex)
            }
        }

        return NSRange(start..<end, in: string)
    }

    // MARK: - Performance Optimizations

    /// Batch process range operations for efficiency
    public static func batchProcess<T>(
        ranges: [NSRange],
        in string: String,
        operation: (NSRange, String) -> T
    ) -> [T] {
        // Sort ranges to process in order
        let sorted = ranges.sorted { $0.location < $1.location }

        return sorted.map { range in
            operation(range, string)
        }
    }

    /// Find visible ranges for viewport optimization
    public static func visibleRanges(
        in viewport: CGRect,
        lineHeight: CGFloat,
        totalLines: Int,
        string: String
    ) -> [NSRange] {
        let firstVisibleLine = max(0, Int(viewport.minY / lineHeight))
        let lastVisibleLine = min(totalLines - 1, Int(viewport.maxY / lineHeight) + 1)

        let lineRanges = self.lineRanges(in: string)

        guard firstVisibleLine < lineRanges.count else { return [] }

        let endLine = min(lastVisibleLine, lineRanges.count - 1)
        let visibleLineRanges = Array(lineRanges[firstVisibleLine...endLine])

        // Merge into a single range if continuous
        if let first = visibleLineRanges.first, let last = visibleLineRanges.last {
            return [
                NSRange(
                    location: first.location,
                    length: NSMaxRange(last) - first.location
                )
            ]
        }

        return []
    }

    // MARK: - Cache Management

    /// Clear all cached range data
    /// Useful for memory management or when text changes significantly
    public static func clearCache() {
        Task {
            await cache.clearCache()
        }
    }

    /// Clear cached data for a specific string
    /// Useful when text content changes
    public static func clearCache(for string: String) {
        Task {
            await cache.clearCache(for: string)
        }
    }
}

// MARK: - Extensions for Convenience

extension NSRange {
    /// Check if this range is valid for the given string
    public func isValid(for string: String) -> Bool {
        RangeUtilities.validate(self, in: string)
    }

    /// Clamp this range to the bounds of the given string
    public func clamped(to string: String) -> NSRange {
        RangeUtilities.clamp(self, to: string)
    }

    /// Get the line range containing this range
    public func lineRange(in string: String) -> NSRange {
        RangeUtilities.lineRange(containing: self.location, in: string)
    }
}

extension Array where Element == NSRange {
    /// Merge overlapping or adjacent ranges
    public func merged() -> [NSRange] {
        RangeUtilities.merge(self)
    }

    /// Adjust all ranges for text insertion
    public func adjustedForInsertion(at point: Int, length: Int) -> [NSRange] {
        RangeUtilities.adjustRangesForInsertion(self, insertionPoint: point, insertionLength: length)
    }

    /// Adjust all ranges for text deletion
    public func adjustedForDeletion(_ deletionRange: NSRange) -> [NSRange] {
        RangeUtilities.adjustRangesForDeletion(self, deletionRange: deletionRange)
    }
}

// MARK: - Range Cache Actor

/// Thread-safe actor for caching expensive range operations
actor RangeCacheActor {
    private var lineRangesCache: [String: [NSRange]] = [:]
    private var lineNumberCache: [String: Int] = [:]
    private var wordRangeCache: [String: NSRange?] = [:]

    // Cache limits to prevent memory growth
    private let maxCacheSize = 50
    private var cacheAccessOrder: [String] = []

    /// Cache line ranges for a string
    func cacheLineRanges(_ ranges: [NSRange], for string: String) {
        let key = createCacheKey(for: string)
        lineRangesCache[key] = ranges
        updateAccessOrder(key: key)
        enforceMemoryLimits()
    }

    /// Get cached line ranges for a string
    func getCachedLineRanges(for string: String) -> [NSRange] {
        let key = createCacheKey(for: string)
        if let ranges = lineRangesCache[key] {
            updateAccessOrder(key: key)
            return ranges
        }
        return []
    }

    /// Cache line number for a character index in a string
    func cacheLineNumber(_ lineNumber: Int, for index: Int, in string: String) {
        let key = "\(createCacheKey(for: string)):\(index)"
        lineNumberCache[key] = lineNumber
        updateAccessOrder(key: key)
        enforceMemoryLimits()
    }

    /// Get cached line number for a character index in a string
    func getCachedLineNumber(for index: Int, in string: String) -> Int? {
        let key = "\(createCacheKey(for: string)):\(index)"
        if let lineNumber = lineNumberCache[key] {
            updateAccessOrder(key: key)
            return lineNumber
        }
        return nil
    }

    /// Cache word range for a character index in a string
    func cacheWordRange(_ range: NSRange?, for index: Int, in string: String) {
        let key = "\(createCacheKey(for: string)):word:\(index)"
        wordRangeCache[key] = range
        updateAccessOrder(key: key)
        enforceMemoryLimits()
    }

    /// Get cached word range for a character index in a string
    func getCachedWordRange(for index: Int, in string: String) -> NSRange?? {
        let key = "\(createCacheKey(for: string)):word:\(index)"
        if wordRangeCache.keys.contains(key) {
            updateAccessOrder(key: key)
            return wordRangeCache[key]
        }
        return nil
    }

    /// Clear all caches
    func clearCache() {
        lineRangesCache.removeAll()
        lineNumberCache.removeAll()
        wordRangeCache.removeAll()
        cacheAccessOrder.removeAll()
    }

    /// Clear cache for a specific string
    func clearCache(for string: String) {
        let keyPrefix = createCacheKey(for: string)

        // Remove from line ranges cache
        lineRangesCache.removeValue(forKey: keyPrefix)

        // Remove from line number cache
        lineNumberCache = lineNumberCache.filter { !$0.key.hasPrefix(keyPrefix) }

        // Remove from word range cache
        wordRangeCache = wordRangeCache.filter { !$0.key.hasPrefix(keyPrefix) }

        // Clean up access order
        cacheAccessOrder.removeAll { key in
            key.hasPrefix(keyPrefix)
        }
    }

    // MARK: - Private Methods

    private func createCacheKey(for string: String) -> String {
        // Create a cache key that's efficient but reasonably unique
        var hasher = Hasher()
        hasher.combine(string)
        let hash = hasher.finalize()
        return "\(hash):\(string.count)"
    }

    private func updateAccessOrder(key: String) {
        // Remove key if it exists
        cacheAccessOrder.removeAll { $0 == key }
        // Add to front (most recently used)
        cacheAccessOrder.insert(key, at: 0)
    }

    private func enforceMemoryLimits() {
        guard cacheAccessOrder.count > maxCacheSize else { return }

        // Remove least recently used items
        let keysToRemove = cacheAccessOrder.suffix(cacheAccessOrder.count - maxCacheSize)

        for key in keysToRemove {
            lineRangesCache.removeValue(forKey: key)
            lineNumberCache.removeValue(forKey: key)
            wordRangeCache.removeValue(forKey: key)
        }

        cacheAccessOrder = Array(cacheAccessOrder.prefix(maxCacheSize))
    }
}
