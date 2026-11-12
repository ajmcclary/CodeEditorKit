import CodeEditorCommon
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Search and replace engine for the code editor
@MainActor
public final class SearchReplaceEngine: ObservableObject {
    nonisolated private static let logger = CodeEditorLog.logger(category: "SearchReplaceEngine")
    private var logger: CrossPlatformLogger.Logger { Self.logger }

    // MARK: - Published Properties

    @Published public var isSearching = false
    @Published public var currentSearchResults: [SearchResult] = []
    @Published public var currentSearchIndex: Int = -1
    @Published public var searchStatistics = SearchStatistics()

    // MARK: - Search Configuration

    public var searchOptions = SearchOptions()
    private var currentSearchTask: Task<[SearchResult], Never>?
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
        await findAll(pattern: pattern, options: options, selectFirstResult: true)
    }

    /// Find matches, optionally leaving the user’s selection and scroll position intact.
    public func findAll(
        pattern: String,
        options: SearchOptions?,
        selectFirstResult: Bool
    ) async -> [SearchResult] {
        guard let textView else { return [] }

        // Cancel any existing search
        currentSearchTask?.cancel()

        // Use provided options or default
        let searchOptions = options ?? self.searchOptions
        self.searchOptions = searchOptions

        isSearching = true
        defer { isSearching = false }

        guard !pattern.isEmpty else {
            currentSearchResults = []
            currentSearchIndex = -1
            updateStatistics(for: [])
            return []
        }

        #if canImport(AppKit)
        let text = textView.string
        #else
        let text = textView.text ?? ""
        #endif
        // Scan a snapshot off the main actor; a newer search, or cancelling
        // the calling task, cancels this one.
        let query = SearchQuery(pattern: pattern, options: searchOptions)
        let searchTask = Task.detached(priority: .userInitiated) {
            Self.performSearch(query, in: text)
        }
        currentSearchTask = searchTask
        let scanned = await withTaskCancellationHandler {
            await searchTask.value
        } onCancel: {
            searchTask.cancel()
        }
        if currentSearchTask == searchTask { currentSearchTask = nil }

        let results = scanned
        guard !Task.isCancelled, !searchTask.isCancelled,
              self.textView === textView else { return [] }
        // Update results and statistics
        currentSearchResults = results
        currentSearchIndex = results.isEmpty ? -1 : (selectFirstResult ? 0 :
            (results.firstIndex { $0.range.location >= textView.selectedRange.location } ?? results.count - 1))
        updateStatistics(for: results)

        // Highlight results if enabled
        if searchOptions.highlightResults {
            highlightSearchResults(results)
        }

        if selectFirstResult, let firstResult = results.first {
            scrollToResult(firstResult)
        }

        return results
    }

    /// Find next occurrence from current position
    public func findNext(from range: NSRange? = nil) -> SearchResult? {
        guard !currentSearchResults.isEmpty else { return nil }

        let previousIndex = currentSearchIndex
        let startLocation = range?.location ?? textView?.selectedRange.location ?? 0

        // Find next result after current location
        if let nextIndex = currentSearchResults.firstIndex(where: { $0.range.location > startLocation }) {
            currentSearchIndex = nextIndex
            repaintCurrentMatch(previousIndex: previousIndex)
            scrollToResult(currentSearchResults[nextIndex])
            return currentSearchResults[nextIndex]
        }

        // Wrap around to beginning if enabled
        if searchOptions.wrapAround && !currentSearchResults.isEmpty {
            currentSearchIndex = 0
            repaintCurrentMatch(previousIndex: previousIndex)
            scrollToResult(currentSearchResults[0])
            return currentSearchResults[0]
        }

        return nil
    }

    /// Find previous occurrence from current position
    public func findPrevious(from range: NSRange? = nil) -> SearchResult? {
        guard !currentSearchResults.isEmpty else { return nil }

        let previousIndex = currentSearchIndex
        let startLocation = range?.location ?? textView?.selectedRange.location ?? Int.max

        // Find previous result before current location
        if let prevIndex = currentSearchResults.lastIndex(where: { $0.range.location < startLocation }) {
            currentSearchIndex = prevIndex
            repaintCurrentMatch(previousIndex: previousIndex)
            scrollToResult(currentSearchResults[prevIndex])
            return currentSearchResults[prevIndex]
        }

        // Wrap around to end if enabled
        if searchOptions.wrapAround,
           let lastResult = currentSearchResults.last {
            currentSearchIndex = currentSearchResults.count - 1
            repaintCurrentMatch(previousIndex: previousIndex)
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

        // Through the text view's own editing path, so undo, the delegate's
        // gating and the change notification the host listens to all see it.
        guard applyUserEdit(
            replacing: [result.range],
            with: replacement,
            in: textView,
            actionName: "Replace"
        ) else { return false }

        // Update search results
        let lengthDiff = TextRangeUtilities.utf16Length(of: replacement) - result.range.length
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
        let results = await findAll(pattern: pattern, options: searchOptions, selectFirstResult: false)
        guard !results.isEmpty else { return 0 }

        // One user edit: one undo group, one change notification.
        let ranges = results.map(\.range).sorted { $0.location < $1.location }
        guard applyUserEdit(
            replacing: ranges,
            with: replacement,
            in: textView,
            actionName: "Replace All"
        ) else { return 0 }
        let replacementCount = ranges.count

        // Clear search results after replace all
        currentSearchResults = []
        currentSearchIndex = -1

        logger.info("Replaced \(replacementCount) occurrences")

        return replacementCount
    }

    /// Drop all search state and clear in-editor match highlights.
    /// Synchronous — no scanning happens.
    public func clearAll() {
        currentSearchResults = []
        currentSearchIndex = -1
        updateStatistics(for: [])

        guard let textView else { return }
        let bridge = textView.textKitBridge
        let fullRange = TextRangeUtilities.fullRange(in: bridge.documentString)
        bridge.removePersistentAttribute(.backgroundColor, range: fullRange)
    }

    // MARK: - Private Methods

    /// Replaces `ranges` (ascending, non-overlapping) with `replacement` as a
    /// single user edit: the text view's gating and undo registration run
    /// first, the change notification is posted once afterwards, and the
    /// whole edit is one undo step. Returns false when the view refused it.
    private func applyUserEdit(
        replacing ranges: [NSRange],
        with replacement: String,
        in textView: CodeEditorView,
        actionName: String
    ) -> Bool {
        guard !ranges.isEmpty else { return false }
        #if canImport(AppKit)
        guard textView.shouldChangeText(
            inRanges: ranges.map { NSValue(range: $0) },
            replacementStrings: ranges.map { _ in replacement }
        ) else { return false }
        let bridge = textView.textKitBridge
        for range in ranges.reversed() {
            bridge.replaceCharacters(in: range, with: replacement)
        }
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
        return true
        #else
        let undoManager = textView.undoManager
        undoManager?.beginUndoGrouping()
        defer {
            undoManager?.setActionName(actionName)
            undoManager?.endUndoGrouping()
        }
        var applied = false
        for range in ranges.reversed() {
            guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end) else { continue }
            textView.replace(textRange, withText: replacement)
            applied = true
        }
        return applied
        #endif
    }

    /// The Sendable part of `SearchOptions` the scan needs.
    private struct SearchQuery: Sendable {
        let pattern: String
        let caseSensitive: Bool
        let wholeWord: Bool
        let useRegularExpression: Bool
        let searchBackward: Bool

        init(pattern: String, options: SearchOptions) {
            self.pattern = pattern
            caseSensitive = options.caseSensitive
            wholeWord = options.wholeWord
            useRegularExpression = options.useRegularExpression
            searchBackward = options.searchBackward
        }
    }

    /// Scans `text` once. Matches arrive in ascending order, so line numbers
    /// come from one forward walk over the line starts. Returns early (with a
    /// partial result the caller discards) when cancelled.
    nonisolated private static func performSearch(_ query: SearchQuery, in text: String) -> [SearchResult] {
        guard !query.pattern.isEmpty else { return [] }
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        var lines = LineNumberWalker(text: nsText)
        var results: [SearchResult] = []

        func append(_ range: NSRange) {
            guard !query.wholeWord || isWholeWordMatch(range, in: nsText) else { return }
            results.append(SearchResult(
                index: results.count,
                range: range,
                matchedText: nsText.substring(with: range),
                lineNumber: lines.lineNumber(at: range.location),
                context: context(for: range, in: nsText)
            ))
        }

        if query.useRegularExpression {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(
                    pattern: query.pattern,
                    options: query.caseSensitive ? [] : .caseInsensitive
                )
            } catch {
                logger.error("Search failed: \(error.localizedDescription)")
                return []
            }
            var cancelled = false
            regex.enumerateMatches(
                in: text,
                options: [],
                range: NSRange(location: 0, length: nsText.length)
            ) { match, _, stop in
                if Task.isCancelled {
                    cancelled = true
                    stop.pointee = true
                    return
                }
                guard let range = match?.range, range.location != NSNotFound, range.length > 0,
                      NSMaxRange(range) <= nsText.length else { return }
                append(range)
            }
            if cancelled { return [] }
        } else {
            var compareOptions: String.CompareOptions = []
            if !query.caseSensitive {
                compareOptions.insert(.caseInsensitive)
            }
            var searchStart = 0
            while searchStart < nsText.length {
                if results.count.isMultiple(of: 256), Task.isCancelled { return [] }
                let found = nsText.range(
                    of: query.pattern,
                    options: compareOptions,
                    range: NSRange(location: searchStart, length: nsText.length - searchStart)
                )
                guard found.location != NSNotFound, found.length > 0 else { break }
                append(found)
                searchStart = NSMaxRange(found)
            }

            if query.searchBackward {
                results = results.reversed().enumerated().map { index, result in
                    SearchResult(
                        index: index,
                        range: result.range,
                        matchedText: result.matchedText,
                        lineNumber: result.lineNumber,
                        context: result.context
                    )
                }
            }
        }
        return results
    }

    // swiftlint:disable:next legacy_objc_type
    nonisolated private static func isWholeWordMatch(_ range: NSRange, in text: NSString) -> Bool {
        if range.location > 0 {
            let before = text.rangeOfComposedCharacterSequence(at: range.location - 1)
            if let character = text.substring(with: before).first,
               TextRangeUtilities.isIdentifierCharacter(character) {
                return false
            }
        }
        let end = NSMaxRange(range)
        if end < text.length {
            let after = text.rangeOfComposedCharacterSequence(at: end)
            if let character = text.substring(with: after).first,
               TextRangeUtilities.isIdentifierCharacter(character) {
                return false
            }
        }
        return true
    }

    // swiftlint:disable:next legacy_objc_type
    nonisolated private static func context(for range: NSRange, in text: NSString) -> String {
        let contextRadius = 40
        let textLength = text.length

        var contextStart = max(0, range.location - contextRadius)
        var contextEnd = min(textLength, NSMaxRange(range) + contextRadius)
        // Do not split a surrogate pair or composed character at either edge.
        if contextStart > 0 {
            contextStart = text.rangeOfComposedCharacterSequence(at: contextStart).location
        }
        if contextEnd < textLength {
            contextEnd = text.rangeOfComposedCharacterSequence(at: contextEnd).location
        }
        var context = text.substring(with: NSRange(location: contextStart, length: contextEnd - contextStart))

        // Add ellipsis if truncated
        if contextStart > 0 {
            context = "..." + context
        }
        if contextEnd < textLength {
            context += "..."
        }

        return context
    }

    private func highlightSearchResults(_ results: [SearchResult]) {
        guard let textView else { return }
        var runs = results.map { ($0.range, searchOptions.highlightColor as Any) }
        if let currentColor = searchOptions.currentMatchColor,
           results.indices.contains(currentSearchIndex) {
            runs[currentSearchIndex].1 = currentColor
        }
        // One editing transaction for all matches, not one (plus a layout
        // pass) per match.
        textView.textKitBridge.replacePersistentAttribute(.backgroundColor, with: runs)
    }

    private func repaintCurrentMatch(previousIndex: Int) {
        guard let textView else { return }
        guard searchOptions.highlightResults else { return }
        guard searchOptions.currentMatchColor != nil else { return }
        let bridge = textView.textKitBridge

        if currentSearchResults.indices.contains(previousIndex), previousIndex != currentSearchIndex {
            let range = currentSearchResults[previousIndex].range
            bridge.removePersistentAttribute(.backgroundColor, range: range)
            bridge.addPersistentAttributes(
                [.backgroundColor: searchOptions.highlightColor],
                range: range
            )
        }

        if let currentColor = searchOptions.currentMatchColor,
           currentSearchResults.indices.contains(currentSearchIndex) {
            let range = currentSearchResults[currentSearchIndex].range
            bridge.removePersistentAttribute(.backgroundColor, range: range)
            bridge.addPersistentAttributes(
                [.backgroundColor: currentColor],
                range: range
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
        let bridge = textView.textKitBridge

        let flashColor = searchOptions.flashColor

        bridge.addPersistentAttributes([.backgroundColor: flashColor], range: range)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard let self, let textView = self.textView else { return }
            let bridge = textView.textKitBridge
            bridge.removePersistentAttribute(.backgroundColor, range: range)

            guard self.searchOptions.highlightResults else { return }

            let isCurrent = self.currentSearchResults.indices.contains(self.currentSearchIndex)
                && self.currentSearchResults[self.currentSearchIndex].range == range
            let color = isCurrent
                ? (self.searchOptions.currentMatchColor ?? self.searchOptions.highlightColor)
                : self.searchOptions.highlightColor
            bridge.addPersistentAttributes([.backgroundColor: color], range: range)
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
        currentSearchTask?.cancel()
    }
}

// MARK: - Supporting Types

/// Search result information
public struct SearchResult: Sendable {
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
    /// Optional second color for the *active* match. When non-nil,
    /// `SearchReplaceEngine.highlightSearchResults(_:)` paints the
    /// active match (`currentSearchResults[currentSearchIndex]`) with
    /// this color and the other matches with `highlightColor`. When
    /// nil, behavior is identical to prior releases.
    public var currentMatchColor: PlatformColor?

    /// Creates a default search options instance. Hosts mutate fields
    /// on the returned value to opt into case-sensitivity, regex,
    /// whole-word matching, etc.
    public init() {}

    var searchOptions: String.CompareOptions {
        var options: String.CompareOptions = []

        if !caseSensitive {
            options.insert(.caseInsensitive)
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

// MARK: - Line numbers

/// Answers 1-based line numbers for ascending UTF-16 offsets in one forward
/// walk, with `NSString`'s line-terminator semantics (CRLF is one break).
private struct LineNumberWalker {
    // swiftlint:disable:next legacy_objc_type
    private let text: NSString
    private var lineStart = 0
    private var lineEnd: Int
    private var line = 1

    // swiftlint:disable:next legacy_objc_type
    init(text: NSString) {
        self.text = text
        lineEnd = text.length > 0 ? NSMaxRange(text.lineRange(for: NSRange(location: 0, length: 0))) : 0
    }

    mutating func lineNumber(at location: Int) -> Int {
        while lineEnd <= location, lineEnd > lineStart {
            lineStart = lineEnd
            line += 1
            lineEnd = lineStart < text.length
                ? NSMaxRange(text.lineRange(for: NSRange(location: lineStart, length: 0)))
                : lineStart
        }
        return line
    }
}
