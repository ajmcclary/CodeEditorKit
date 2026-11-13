import CodeEditorCommon
import CodeEditorFolding
import CodeEditorInstrumentation
import CodeEditorLanguages
import CodeEditorTextModel
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Engine for managing code folding in the editor
@MainActor
internal class CodeFoldingEngine: ObservableObject, TextEditEventObserving {
    private let logger = CodeEditorLog.logger(category: "CodeFoldingEngine")

    // MARK: - Published Properties

    @Published internal private(set) var foldableRegions: [FoldableRegion] = [] {
        didSet { lineIndex = nil }
    }
    @Published internal private(set) var foldedRegions: Set<UUID> = []
    @Published internal private(set) var isProcessing = false

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private let providerRegistry = FoldingProviderRegistry()
    private let operationsService = FoldingOperationsService()
    private var updateTask: Task<Void, Never>?

    /// 1-based start/end lines of `foldableRegions`, built in one pass and
    /// reused until the regions or the text change.
    private var lineIndex: FoldLineIndex?

    // MARK: - New architecture (Phase 5)

    /// Range-store-backed fold metadata, separate from text attributes.
    private var foldStorage = LineFoldStorage(documentLength: 0)

    /// Presentation strategy for collapse/expand visuals.
    private var presentationStrategy: any FoldPresentationStrategy = AttributeFoldPresentationStrategy()

    /// Returns folds from the range-store-backed storage for the given range.
    internal func folds(in range: NSRange) -> [FoldInfo] {
        foldStorage.folds(in: range)
    }

    /// Update fold storage after a text edit.
    internal func syncFoldStorage(editedRange: NSRange, changeInLength: Int) {
        foldStorage.storageUpdated(
            replacedCharactersIn: editedRange.location..<(editedRange.location + editedRange.length),
            withCount: editedRange.length + changeInLength
        )
    }

    // MARK: - Caching

    private var foldRegionCache: [Int: [FoldableRegion]] = [:] // Hash -> Regions
    /// FIFO insertion order for `foldRegionCache`. Eviction pops from
    /// the front so the oldest entry is dropped first. The previous
    /// implementation sorted hash keys, which evicted the lowest hash
    /// rather than the oldest insertion — effectively random eviction.
    private var foldRegionCacheOrder: [Int] = []
    private var lastTextHash: Int = 0
    private var lastLanguage: Language = .plainText

    // MARK: - Configuration

    internal var configuration = CodeFoldingConfiguration()

    // Performance metrics for production monitoring
    private let performanceMetrics: ProductionPerformanceMetrics

    /// Debounce window for fold-region detection. Re-runs are coalesced so
    /// rapid keystrokes don't trigger N detection passes. Mirrors the
    /// `AsyncSyntaxHighlighter` 300 ms cadence — fold detection is cheaper
    /// than highlighting but still wasteful on every keystroke.
    private static let detectionDebounceNanoseconds: UInt64 = 250_000_000

    /// Optional memory monitor for cache-pressure cleanup (perf C6).
    private let memoryMonitor: (any MemoryMonitoring)?
    private static let memoryCleanupIdentifier = "CodeFoldingEngine.foldRegionCache"

    // MARK: - Initialization

    internal init(
        performanceMetrics: ProductionPerformanceMetrics? = nil,
        memoryMonitor: (any MemoryMonitoring)? = nil
    ) {
        self.performanceMetrics = performanceMetrics ?? CodeEditorDependencies.makeProductionPerformanceMetrics()
        self.memoryMonitor = memoryMonitor
        registerMemoryCleanup()
        // Providers are now initialized in FoldingProviderRegistry
    }

    private func registerMemoryCleanup() {
        guard let memoryMonitor else { return }
        memoryMonitor.registerCleanupHandler(
            identifier: Self.memoryCleanupIdentifier,
            priority: .normal
        ) { [weak self] in
            guard let self else { return CleanupResult(memoryFreedMB: 0.0) }
            let approxFreedMB = Double(self.foldRegionCache.count) * 0.001
            self.clearCache()
            return CleanupResult(memoryFreedMB: approxFreedMB)
        }
    }

    /// Attach to a text view
    internal func attach(to textView: CodeEditorView) {
        if self.textView !== textView {
            self.textView?.textEditEventHub.removeObserver(self)
        }
        self.textView = textView
        operationsService.attach(to: textView)
        textView.textEditEventHub.addObserver(self)
        updateFoldableRegions()
    }

    /// Cancels pending detection and releases edit observation for the view.
    internal func detach() {
        updateTask?.cancel()
        updateTask = nil
        textView?.textEditEventHub.removeObserver(self)
        operationsService.detach()
        textView = nil
    }

    internal func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard event.editedCharacters else { return }
        lineIndex = nil
        syncFoldStorage(editedRange: event.editedRange, changeInLength: event.changeInLength)
        updateFoldableRegions(in: event.editedRange, changeInLength: event.changeInLength)
    }

    // MARK: - Provider Management

    /// Register a folding provider for a language
    internal func registerProvider(_ provider: CodeFoldingProvider, for language: Language) {
        providerRegistry.registerProvider(provider, for: language)
    }

    // MARK: - Folding Operations

    /// Toggle fold at line
    /// - Returns: `true` if fold state was changed, `false` if no foldable region exists
    internal func toggleFold(at line: Int) -> Bool {
        guard let region = foldableRegion(at: line) else { return false }
        let changed = operationsService.toggleFold(region, foldedRegions: &foldedRegions, configuration: configuration)
        if changed {
            foldStorage.setCollapsed(
                foldID: region.id.uuidString,
                collapsed: foldedRegions.contains(region.id)
            )
        }
        return changed
    }

    /// Fold a specific region
    /// - Returns: `true` if the region was folded, `false` if it was already folded or textView is nil
    @discardableResult
    internal func fold(_ region: FoldableRegion) -> Bool {
        let changed = operationsService.fold(region, foldedRegions: &foldedRegions, configuration: configuration)
        if changed {
            foldStorage.setCollapsed(foldID: region.id.uuidString, collapsed: true)
        }
        return changed
    }

    /// Unfold a specific region
    /// - Returns: `true` if the region was unfolded, `false` if it wasn't folded or textView is nil
    @discardableResult
    internal func unfold(_ region: FoldableRegion) -> Bool {
        let changed = operationsService.unfold(region, foldedRegions: &foldedRegions, configuration: configuration)
        if changed {
            foldStorage.setCollapsed(foldID: region.id.uuidString, collapsed: false)
        }
        return changed
    }

    /// Fold several regions, updating fold storage once for all of them.
    internal func fold(_ regions: [FoldableRegion]) {
        for region in regions {
            operationsService.fold(region, foldedRegions: &foldedRegions, configuration: configuration)
        }
        syncFoldStorageCollapseStates()
    }

    /// Fold all regions
    internal func foldAll() {
        operationsService.foldAll(regions: foldableRegions, foldedRegions: &foldedRegions, configuration: configuration)
        syncFoldStorageCollapseStates()
    }

    /// Unfold all regions
    internal func unfoldAll() {
        operationsService.unfoldAll(regions: foldableRegions, foldedRegions: &foldedRegions, configuration: configuration)
        syncFoldStorageCollapseStates()
    }

    /// Fold all regions at a specific level
    internal func foldLevel(_ level: Int) {
        operationsService.foldLevel(level, regions: foldableRegions, foldedRegions: &foldedRegions, configuration: configuration)
        syncFoldStorageCollapseStates()
    }

    /// The region for a 1-based line: the innermost region that starts on
    /// the line, else the innermost region that contains it.
    internal func foldableRegion(at line: Int) -> FoldableRegion? {
        let index = currentLineIndex()
        if let starting = index.regionsStarting(onLine: line).first {
            return foldableRegions[starting]
        }
        return index.innermostRegion(containingLine: line).map { foldableRegions[$0] }
    }

    /// Whether a 1-based line lies in a folded region.
    internal func isLineFolded(_ line: Int) -> Bool {
        guard !foldedRegions.isEmpty else { return false }
        let index = currentLineIndex()
        return foldableRegions.indices.contains { regionIndex in
            foldedRegions.contains(foldableRegions[regionIndex].id)
                && index.region(regionIndex, containsLine: line)
        }
    }

    /// Whether a region starts on a 1-based line (where the gutter draws a chevron).
    internal func isStartOfFoldableRegion(_ line: Int) -> Bool {
        !currentLineIndex().regionsStarting(onLine: line).isEmpty
    }

    private func currentLineIndex() -> FoldLineIndex {
        if let lineIndex { return lineIndex }
        let text = textView?.textKitBridge.documentString ?? ""
        let index = FoldLineIndex(regions: foldableRegions, text: text)
        lineIndex = index
        return index
    }

    // MARK: - Line-Span Helper

    /// Number of lines `range` spans in `text`. A length-zero range (or
    /// one whose clamped slice contains no newlines) maps to 1; each
    /// additional newline inside the slice contributes one line.
    /// Internal-static so tests in `@testable` builds can pin the
    /// matrix without going through the full engine pipeline.
    nonisolated internal static func lineSpan(of range: NSRange, in text: String) -> Int {
        guard range.length > 0 else { return 1 }
        let textLength = TextRangeUtilities.utf16Length(of: text)
        let clampedStart = max(0, min(range.location, textLength))
        let clampedEnd = max(clampedStart, min(NSMaxRange(range), textLength))
        guard clampedEnd > clampedStart else { return 1 }
        let scanRange = NSRange(location: clampedStart, length: clampedEnd - clampedStart)
        guard let substring = TextRangeUtilities.substring(inUTF16Range: scanRange, from: text) else {
            return 1
        }
        // Count `\n` code units, so CRLF ("\r\n" is one Character) counts too.
        let newlineCount = substring.utf16.reduce(0) { $1 == 0x0A ? $0 + 1 : $0 }
        return newlineCount + 1
    }

    // MARK: - Cache Management

    nonisolated private static func combineHashes(_ hash1: Int, _ hash2: Int) -> Int {
        // Simple hash combination
        var hasher = Hasher()
        hasher.combine(hash1)
        hasher.combine(hash2)
        return hasher.finalize()
    }

    private static let maxFoldRegionCacheSize = 10

    private func maintainCacheSize() {
        while foldRegionCache.count > Self.maxFoldRegionCacheSize,
              !foldRegionCacheOrder.isEmpty {
            let oldestKey = foldRegionCacheOrder.removeFirst()
            foldRegionCache.removeValue(forKey: oldestKey)
        }
    }

    /// Record `cacheKey` as the most recently inserted entry so a
    /// subsequent `maintainCacheSize()` evicts older entries first.
    /// Re-inserting an existing key moves it to the end (so a "hot"
    /// entry doesn't get dropped as if it were old).
    private func recordCacheInsertion(_ cacheKey: Int) {
        foldRegionCacheOrder.removeAll { $0 == cacheKey }
        foldRegionCacheOrder.append(cacheKey)
    }

    /// Clear the cache when memory pressure is detected
    internal func clearCache() {
        foldRegionCache.removeAll()
        foldRegionCacheOrder.removeAll()
        lastTextHash = 0
        lastLanguage = .plainText
    }

    // MARK: - Internal Test Seam

    /// Snapshot of cache keys in insertion order. Tests use this to
    /// verify FIFO eviction without exercising the full debounced
    /// detection pipeline.
    internal var foldRegionCacheKeysInInsertionOrderForTesting: [Int] {
        foldRegionCacheOrder
    }

    /// Mirror of the production cache-write sequence used in
    /// `detectFoldableRegions`: maintain the size cap, write the
    /// entry, then record insertion order.
    internal func setCachedFoldRegionsForTesting(
        _ regions: [FoldableRegion],
        forKey key: Int
    ) {
        maintainCacheSize()
        foldRegionCache[key] = regions
        recordCacheInsertion(key)
    }

    // MARK: - Region Detection

    /// Update foldable regions based on current text.
    ///
    /// Perf C5: detection is debounced — rapid keystrokes coalesce into a
    /// single detection pass after `detectionDebounceNanoseconds`. Explicit
    /// folding actions (toggleFold, foldAll, etc.) don't go through this
    /// path so user interactions stay snappy.
    internal func updateFoldableRegions() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: Self.detectionDebounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.detectFoldableRegions()
        }
    }

    /// Update foldable regions incrementally for a specific range
    internal func updateFoldableRegions(in editedRange: NSRange, changeInLength: Int) {
        guard configuration.enableIncrementalUpdates else {
            // Fall back to full update
            updateFoldableRegions()
            return
        }

        // Shift the existing regions now so they (and their fold state) keep
        // following the text, then re-detect after the debounce: the shift
        // is only a stopgap, it cannot find new regions or drop dead ones.
        incrementalUpdate(editedRange: editedRange, changeInLength: changeInLength)
        updateFoldableRegions()
    }

    private func incrementalUpdate(editedRange: NSRange, changeInLength: Int) {
        // Adjust existing regions based on the edit
        let adjustedRegions = foldableRegions.map { region in
            var adjustedRegion = region

            // If edit is before the region — or an insertion right at its
            // start, which re-detection finds after the inserted text — shift it
            if editedRange.location < region.range.location
                || (editedRange.length == 0 && editedRange.location == region.range.location) {
                adjustedRegion.range.location += changeInLength
            }
            // If edit is within the region, adjust length
            else if editedRange.location >= region.range.location &&
                    editedRange.location < NSMaxRange(region.range) {
                adjustedRegion.range.length += changeInLength
            }

            return adjustedRegion
        }

        // Filter out invalid regions
        foldableRegions = adjustedRegions.filter { region in
            region.range.location >= 0 && region.range.length > 0
        }
        foldStorage.updateFolds(from: foldableRegions, collapsedIDs: collapsedFoldIDs)

        // Clear cache as text has changed
        lastTextHash = 0
    }

    /// Documents longer than this (UTF-16 units) get no fold regions: even a
    /// linear scan of them per typing pause is not worth it.
    internal static let maximumDetectionLength = 4_000_000

    private enum DetectionOutcome: Sendable {
        case cached([FoldableRegion])
        case detected(regions: [FoldableRegion], textHash: Int, cacheKey: Int)
    }

    /// Detects regions on a snapshot of the text off the main actor, and
    /// applies them only if the text has not changed meanwhile (a newer
    /// detection is then already scheduled by the edit that changed it).
    private func detectFoldableRegions() async {
        guard let textView else {
            foldableRegions = []
            return
        }

        let language = textView.language
        guard let provider = providerRegistry.provider(for: language) else {
            foldableRegions = []
            return
        }

        // Read through the TK2-safe accessor; `textView.textStorage` triggers
        // Apple's TK1 compatibility shim.
        let documentLength = textView.textKitBridge.documentLength
        guard documentLength > 0 else {
            foldableRegions = []
            return
        }
        guard documentLength <= Self.maximumDetectionLength else {
            updateRegions([])
            foldStorage = LineFoldStorage(documentLength: documentLength)
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let generation = textView.textChangeEventGeneration
        // An immutable copy: the storage's own string is mutable and edited
        // on the main actor while the detection runs.
        // swiftlint:disable:next legacy_objc_type
        let snapshot = String(NSString(string: textView.textKitBridge.documentString))
        let minimumLineCount = configuration.minimumLineCount
        let previousTextHash = lastTextHash
        let previousLanguage = lastLanguage
        let cache = foldRegionCache

        isProcessing = true
        defer { isProcessing = false }

        let detection = Task.detached(priority: .utility) { () -> DetectionOutcome in
            var text = snapshot
            text.makeContiguousUTF8()
            let textHash = text.hashValue
            let cacheKey = Self.combineHashes(textHash, language.hashValue)
            if textHash == previousTextHash, language == previousLanguage, let cached = cache[cacheKey] {
                return .cached(cached)
            }
            let regions = await provider.detectFoldableRegions(in: text)
            let length = text.utf16.count
            let valid = regions
                .filter { region in
                    // `minimumLineCount` is a line count; NSRange.length is
                    // UTF-16 units, so compare line spans.
                    region.range.location >= 0
                        && NSMaxRange(region.range) <= length
                        && Self.lineSpan(of: region.range, in: text) >= minimumLineCount
                }
                .sorted { $0.range.location < $1.range.location }
            return .detected(regions: valid, textHash: textHash, cacheKey: cacheKey)
        }
        let outcome = await withTaskCancellationHandler {
            await detection.value
        } onCancel: {
            detection.cancel()
        }

        guard !Task.isCancelled,
              self.textView === textView,
              textView.textChangeEventGeneration == generation else { return }

        let validRegions: [FoldableRegion]
        switch outcome {
        case .cached(let regions):
            foldableRegions = regions
            return

        case let .detected(regions, textHash, cacheKey):
            validRegions = regions
            lastTextHash = textHash
            lastLanguage = language
            maintainCacheSize()
            foldRegionCache[cacheKey] = validRegions
            recordCacheInsertion(cacheKey)
        }

        // Build hierarchy
        let hierarchicalRegions = Self.buildHierarchy(from: validRegions)

        // Update regions, preserving fold state
        updateRegions(hierarchicalRegions)

        // Populate range-store-backed fold storage.
        foldStorage = LineFoldStorage(documentLength: documentLength)
        foldStorage.updateFolds(from: hierarchicalRegions, collapsedIDs: collapsedFoldIDs)

        // Track performance metrics
        let endTime = CFAbsoluteTimeGetCurrent()
        await performanceMetrics.trackCodeFolding(
            duration: endTime - startTime,
            regionCount: hierarchicalRegions.count,
            fileSize: documentLength
        )
    }

    /// Levels and parents for regions sorted by location, from a stack of the
    /// enclosing regions: O(regions) for nested or disjoint regions (what the
    /// providers produce), where the previous scan of every earlier region
    /// was O(regions²).
    private static func buildHierarchy(from regions: [FoldableRegion]) -> [FoldableRegion] {
        var hierarchicalRegions: [FoldableRegion] = []
        hierarchicalRegions.reserveCapacity(regions.count)
        var enclosing: [FoldableRegion] = []

        for region in regions {
            while let candidate = enclosing.last, !TextRangeUtilities.contains(candidate.range, region.range) {
                enclosing.removeLast()
            }
            let parent = enclosing.last

            var updatedRegion = region
            updatedRegion.level = parent.map { $0.level + 1 } ?? 0
            updatedRegion.parentId = parent?.id

            hierarchicalRegions.append(updatedRegion)
            enclosing.append(updatedRegion)
        }

        return hierarchicalRegions
    }

    private func updateRegions(_ newRegions: [FoldableRegion]) {
        // Preserve fold state for regions that still exist. The existing
        // regions were shifted with every edit, so a region that only moved
        // still has the same range as its re-detected self. The range alone
        // identifies it: providers may classify the same braces differently
        // after an unrelated edit (BraceFoldingProvider looks at the whole
        // prefix for "//").
        var newFoldedRegions = Set<UUID>()
        var matchedFoldedIDs = Set<UUID>()
        // Two folded regions with one range: keep the first (same region).
        let foldedPairs = foldableRegions
            .filter { foldedRegions.contains($0.id) }
            .map { (FoldRegionKey(range: $0.range), $0) }
        let foldedByRange = Dictionary(foldedPairs) { first, _ in first }

        for newRegion in newRegions {
            if let existing = foldedByRange[FoldRegionKey(range: newRegion.range)] {
                newFoldedRegions.insert(newRegion.id)
                matchedFoldedIDs.insert(existing.id)
            }
        }

        // A folded region that no longer exists must not leave its text hidden
        // under a chevron that now reads "expanded".
        let droppedFolds = foldableRegions.filter {
            foldedRegions.contains($0.id) && !matchedFoldedIDs.contains($0.id)
        }
        for region in droppedFolds {
            operationsService.revealContent(of: region, configuration: configuration)
        }

        foldableRegions = newRegions
        foldedRegions = newFoldedRegions
    }

    private var collapsedFoldIDs: Set<String> {
        Set(foldedRegions.map(\.uuidString))
    }

    private func syncFoldStorageCollapseStates() {
        foldStorage.setCollapsed(
            foldableRegions.map { ($0.id.uuidString, foldedRegions.contains($0.id)) }
        )
    }

    deinit {
        updateTask?.cancel()
    }
}

// MARK: - Fold line index

private struct FoldRegionKey: Hashable {
    let location: Int
    let length: Int

    init(range: NSRange) {
        location = range.location
        length = range.length
    }
}

/// 1-based start and end lines of a set of regions, computed with one forward
/// walk over the text (lines end at each `\n` code unit, so CRLF counts once).
private struct FoldLineIndex {
    private var startLines: [Int] = []
    private var endLines: [Int] = []
    /// Region indices by start line, innermost (latest start, then shortest) first.
    private var byStartLine: [Int: [Int]] = [:]
    private var lengths: [Int] = []

    init(regions: [FoldableRegion], text: String) {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        let length = nsText.length
        var offsets: [(offset: Int, region: Int, isEnd: Bool)] = []
        offsets.reserveCapacity(regions.count * 2)
        for (index, region) in regions.enumerated() {
            let start = max(0, min(region.range.location, length))
            let end = max(start, min(NSMaxRange(region.range) - (region.range.length > 0 ? 1 : 0), length))
            offsets.append((start, index, false))
            offsets.append((end, index, true))
        }
        offsets.sort { $0.offset < $1.offset }

        startLines = Array(repeating: 1, count: regions.count)
        endLines = Array(repeating: 1, count: regions.count)
        lengths = regions.map(\.range.length)
        var line = 1
        var position = 0
        for entry in offsets {
            while position < entry.offset {
                let newline = nsText.range(
                    of: "\n",
                    options: .literal,
                    range: NSRange(location: position, length: entry.offset - position)
                )
                guard newline.location != NSNotFound else {
                    position = entry.offset
                    break
                }
                line += 1
                position = newline.location + 1
            }
            if entry.isEnd {
                endLines[entry.region] = line
            } else {
                startLines[entry.region] = line
            }
        }
        for index in regions.indices {
            byStartLine[startLines[index], default: []].append(index)
        }
        for (line, indices) in byStartLine {
            byStartLine[line] = indices.sorted { lhs, rhs in
                let lhsStart = regions[lhs].range.location
                let rhsStart = regions[rhs].range.location
                return lhsStart != rhsStart ? lhsStart > rhsStart : lengths[lhs] < lengths[rhs]
            }
        }
    }

    func regionsStarting(onLine line: Int) -> [Int] {
        byStartLine[line] ?? []
    }

    func region(_ index: Int, containsLine line: Int) -> Bool {
        startLines.indices.contains(index) && line >= startLines[index] && line <= endLines[index]
    }

    func innermostRegion(containingLine line: Int) -> Int? {
        startLines.indices
            .filter { region($0, containsLine: line) }
            .min { lhs, rhs in
                let lhsSpan = endLines[lhs] - startLines[lhs]
                let rhsSpan = endLines[rhs] - startLines[rhs]
                return lhsSpan != rhsSpan ? lhsSpan < rhsSpan : lengths[lhs] < lengths[rhs]
            }
    }
}
