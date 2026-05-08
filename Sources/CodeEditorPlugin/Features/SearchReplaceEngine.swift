import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Search and replace engine for the code editor
@MainActor
public class SearchReplaceEngine: ObservableObject {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "SearchReplaceEngine")

    // MARK: - Published Properties

    @Published public var isSearching = false
    @Published public var currentSearchResults: [SearchResult] = []
    @Published public var currentSearchIndex: Int = -1
    @Published public var searchStatistics = SearchStatistics()

    // MARK: - Search Configuration

    public var searchOptions = SearchOptions()
    private var currentSearchTask: Task<Void, Never>?
    private weak var textView: CodeEditorView?

    // MARK: - Initialization

    public init() {}

    /// Attach to a text view
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
    }

    // MARK: - Search Operations

    /// Find all occurrences of a pattern in the text
    public func findAll(
        pattern: String,
        options: SearchOptions? = nil
    ) async -> [SearchResult] {
        guard let textView else { return [] }

        // Cancel any existing search
        currentSearchTask?.cancel()

        // Use provided options or default
        let searchOptions = options ?? self.searchOptions

        isSearching = true
        defer { isSearching = false }

        #if canImport(AppKit)
        let text = textView.string
        #else
        let text = textView.text ?? ""
        #endif
        let results = await performSearch(
            pattern: pattern,
            in: text,
            options: searchOptions
        )

        // Update results and statistics
        currentSearchResults = results
        currentSearchIndex = results.isEmpty ? -1 : 0
        updateStatistics(for: results)

        // Highlight results if enabled
        if searchOptions.highlightResults {
            highlightSearchResults(results)
        }

        return results
    }

    /// Find next occurrence from current position
    public func findNext(from range: NSRange? = nil) -> SearchResult? {
        guard !currentSearchResults.isEmpty else { return nil }

        let startLocation = range?.location ?? textView?.selectedRange.location ?? 0

        // Find next result after current location
        if let nextIndex = currentSearchResults.firstIndex(where: { $0.range.location > startLocation }) {
            currentSearchIndex = nextIndex
            scrollToResult(currentSearchResults[nextIndex])
            return currentSearchResults[nextIndex]
        }

        // Wrap around to beginning if enabled
        if searchOptions.wrapAround && !currentSearchResults.isEmpty {
            currentSearchIndex = 0
            scrollToResult(currentSearchResults[0])
            return currentSearchResults[0]
        }

        return nil
    }

    /// Find previous occurrence from current position
    public func findPrevious(from range: NSRange? = nil) -> SearchResult? {
        guard !currentSearchResults.isEmpty else { return nil }

        let startLocation = range?.location ?? textView?.selectedRange.location ?? Int.max

        // Find previous result before current location
        if let prevIndex = currentSearchResults.lastIndex(where: { $0.range.location < startLocation }) {
            currentSearchIndex = prevIndex
            scrollToResult(currentSearchResults[prevIndex])
            return currentSearchResults[prevIndex]
        }

        // Wrap around to end if enabled
        if searchOptions.wrapAround,
           let lastResult = currentSearchResults.last {
            currentSearchIndex = currentSearchResults.count - 1
            scrollToResult(lastResult)
            return lastResult
        }

        return nil
    }

    // MARK: - Replace Operations

    /// Replace a single occurrence
    public func replace(
        at index: Int,
        with replacement: String
    ) -> Bool {
        guard let textView,
              index >= 0 && index < currentSearchResults.count else { return false }

        let result = currentSearchResults[index]

        // Perform replacement
        #if canImport(AppKit)
        textView.replaceCharacters(in: result.range, with: replacement)
        #else
        if let text = textView.text,
           let textRange = Range(result.range, in: text) {
            textView.text = text.replacingCharacters(in: textRange, with: replacement)
        }
        #endif

        // Update search results
        let lengthDiff = replacement.count - result.range.length
        updateResultsAfterReplacement(at: index, lengthDifference: lengthDiff)

        return true
    }

    /// Replace all occurrences
    public func replaceAll(
        pattern: String,
        with replacement: String,
        options: SearchOptions? = nil
    ) async -> Int {
        guard let textView else { return 0 }

        let searchOptions = options ?? self.searchOptions

        // Find all occurrences first
        let results = await findAll(pattern: pattern, options: searchOptions)
        guard !results.isEmpty else { return 0 }

        // Sort results in reverse order to maintain correct ranges
        let sortedResults = results.sorted { $0.range.location > $1.range.location }

        var replacementCount = 0

        #if canImport(AppKit)
        guard let textStorage = textView.textStorage else { return 0 }

        // Begin grouped undo
        textStorage.beginEditing()
        defer { textStorage.endEditing() }

        for result in sortedResults {
            textView.replaceCharacters(in: result.range, with: replacement)
            replacementCount += 1
        }
        #else
        // On iOS/Catalyst, textStorage is not optional
        let textStorage = textView.textStorage

        // Use textStorage
        textStorage.beginEditing()
        defer { textStorage.endEditing() }

        for result in sortedResults {
            textStorage.replaceCharacters(in: result.range, with: replacement)
            replacementCount += 1
        }
        #endif

        // Clear search results after replace all
        currentSearchResults = []
        currentSearchIndex = -1

        logger.info("Replaced \(replacementCount) occurrences")

        return replacementCount
    }

    // MARK: - Private Methods

    private func performSearch(
        pattern: String,
        in text: String,
        options: SearchOptions
    ) async -> [SearchResult] {
        var results: [SearchResult] = []

        do {
            if options.useRegularExpression {
                // Regex search
                let regex = try NSRegularExpression(
                    pattern: pattern,
                    options: options.caseSensitive ? [] : .caseInsensitive
                )

                let matches = regex.matches(
                    in: text,
                    options: [],
                    range: NSRange(location: 0, length: text.count)
                )

                results = matches.enumerated().map { index, match in
                    let matchedText = String(text[text.index(text.startIndex, offsetBy: match.range.location)..<text.index(text.startIndex, offsetBy: NSMaxRange(match.range))])
                    return SearchResult(
                        index: index,
                        range: match.range,
                        matchedText: matchedText,
                        lineNumber: lineNumber(for: match.range.location, in: text),
                        context: getContext(for: match.range, in: text)
                    )
                }
            } else {
                // Plain text search
                var searchRange = NSRange(location: 0, length: text.count)
                var index = 0

                while searchRange.location < text.count {
                    guard let swiftSearchRange = Range(searchRange, in: text) else { break }

                    let foundSwiftRange = text.range(
                        of: pattern,
                        options: options.searchOptions,
                        range: swiftSearchRange
                    )

                    let foundRange = foundSwiftRange.map { NSRange($0, in: text) } ?? NSRange(location: NSNotFound, length: 0)

                    if foundRange.location == NSNotFound {
                        break
                    }

                    let matchedText = String(text[text.index(text.startIndex, offsetBy: foundRange.location)..<text.index(text.startIndex, offsetBy: NSMaxRange(foundRange))])
                    results.append(SearchResult(
                        index: index,
                        range: foundRange,
                        matchedText: matchedText,
                        lineNumber: lineNumber(for: foundRange.location, in: text),
                        context: getContext(for: foundRange, in: text)
                    ))

                    searchRange.location = NSMaxRange(foundRange)
                    searchRange.length = text.count - searchRange.location
                    index += 1
                }
            }
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
        }

        return results
    }

    private func lineNumber(for location: Int, in text: String) -> Int {
        let substring = String(text.prefix(location))
        return substring.components(separatedBy: .newlines).count
    }

    private func getContext(for range: NSRange, in text: String) -> String {
        let contextRadius = 40

        let contextStart = max(0, range.location - contextRadius)
        let contextEnd = min(text.count, NSMaxRange(range) + contextRadius)
        let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)

        var context = String(text[text.index(text.startIndex, offsetBy: contextRange.location)..<text.index(text.startIndex, offsetBy: NSMaxRange(contextRange))])

        // Add ellipsis if truncated
        if contextStart > 0 {
            context = "..." + context
        }
        if contextEnd < text.count {
            context += "..."
        }

        return context
    }

    private func highlightSearchResults(_ results: [SearchResult]) {
        guard let textView else { return }

        #if canImport(AppKit)
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textView.string.count)
        #else
        let textStorage = textView.textStorage
        let fullRange = NSRange(location: 0, length: textView.text?.count ?? 0)
        #endif

        // Clear existing highlights
        textStorage.removeAttribute(
            .backgroundColor,
            range: fullRange
        )

        // Apply highlights
        for result in results {
            textStorage.addAttribute(
                .backgroundColor,
                value: searchOptions.highlightColor,
                range: result.range
            )
        }
    }

    private func scrollToResult(_ result: SearchResult) {
        guard let textView else { return }

        textView.selectedRange = result.range

        // Only scroll if autoScrollToCursor is enabled
        if textView.configuration.behavior.autoScrollToCursor {
            textView.scrollRangeToVisible(result.range)
        }

        // Flash the result for visibility
        if searchOptions.flashResult {
            flashRange(result.range)
        }
    }

    private func flashRange(_ range: NSRange) {
        guard let textView else { return }

        #if canImport(AppKit)
        guard let textStorage = textView.textStorage else { return }
        #else
        let textStorage = textView.textStorage
        #endif

        let flashColor = searchOptions.flashColor

        textStorage.addAttribute(
            .backgroundColor,
            value: flashColor,
            range: range
        )

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            textStorage.removeAttribute(
                .backgroundColor,
                range: range
            )

            // Reapply search highlight if needed
            if self?.searchOptions.highlightResults == true {
                textStorage.addAttribute(
                    .backgroundColor,
                    value: self?.searchOptions.highlightColor ?? PlatformColor.yellow.withAlphaComponent(0.3),
                    range: range
                )
            }
        }
    }

    private func updateResultsAfterReplacement(at index: Int, lengthDifference: Int) {
        // Remove replaced result
        let replacedResult = currentSearchResults[index]
        currentSearchResults.remove(at: index)

        // Adjust ranges for subsequent results
        for index in 0..<currentSearchResults.count where currentSearchResults[index].range.location > replacedResult.range.location {
            currentSearchResults[index].range.location += lengthDifference
        }

        // Update current index
        if currentSearchIndex >= index {
            currentSearchIndex = max(0, currentSearchIndex - 1)
        }
    }

    private func updateStatistics(for results: [SearchResult]) {
        searchStatistics.totalMatches = results.count
        searchStatistics.searchTime = Date()

        if !results.isEmpty {
            searchStatistics.linesWithMatches = Set(results.map { $0.lineNumber }).count
            searchStatistics.firstMatchLine = results.first?.lineNumber ?? 0
            searchStatistics.lastMatchLine = results.last?.lineNumber ?? 0
        } else {
            searchStatistics.linesWithMatches = 0
            searchStatistics.firstMatchLine = 0
            searchStatistics.lastMatchLine = 0
        }
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Supporting Types

/// Search result information
public struct SearchResult {
    /// The zero-based index of this search result in the results array
    public let index: Int
    /// The range in the document where this match was found
    public var range: NSRange
    /// The actual text that matched the search query
    public let matchedText: String
    /// The one-based line number where this match was found
    public let lineNumber: Int
    /// The surrounding context text for this match
    public let context: String
}

/// Search options configuration
public struct SearchOptions {
    /// Whether to perform case-sensitive matching
    public var caseSensitive = false
    /// Whether to match whole words only
    public var wholeWord = false
    /// Whether to use regular expression patterns
    public var useRegularExpression = false
    /// Whether to wrap around to the beginning when reaching the end
    public var wrapAround = true
    /// Whether to search backwards from the current position
    public var searchBackward = false
    /// Whether to highlight all search results in the editor
    public var highlightResults = true
    /// Whether to flash the current search result briefly
    public var flashResult = true
    /// The color used to highlight search results
    public var highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
    /// The color used to flash the current search result
    public var flashColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

    var searchOptions: String.CompareOptions {
        var options: String.CompareOptions = []

        if !caseSensitive {
            options.insert(.caseInsensitive)
        }

        if wholeWord {
            options.insert(.anchored)
        }

        if searchBackward {
            options.insert(.backwards)
        }

        return options
    }
}

/// Search statistics
public struct SearchStatistics {
    /// The total number of matches found in the search
    public var totalMatches = 0
    /// The number of lines that contain at least one match
    public var linesWithMatches = 0
    /// The line number of the first match (1-based)
    public var firstMatchLine = 0
    /// The line number of the last match (1-based)
    public var lastMatchLine = 0
    /// The timestamp when the search was performed
    public var searchTime = Date()
}

// MARK: - Extensions

// Extension removed - no longer needed since we use String.CompareOptions directly

extension CodeEditorView {
    /// Get or create search engine
    public var searchEngine: SearchReplaceEngine {
        // This would be stored as an associated object or property
        // For now, creating a new instance
        let engine = SearchReplaceEngine()
        engine.attach(to: self)
        return engine
    }
}
