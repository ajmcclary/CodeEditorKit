import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Engine for managing code folding in the editor
@MainActor
internal class CodeFoldingEngine: ObservableObject, TextEditEventObserving {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "CodeFoldingEngine")

    // MARK: - Published Properties

    @Published internal private(set) var foldableRegions: [FoldableRegion] = []
    @Published internal private(set) var foldedRegions: Set<UUID> = []
    @Published internal private(set) var isProcessing = false

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private var textStorage: NSTextStorage? { textView?.textStorage }
    private let providerRegistry = FoldingProviderRegistry()
    private let operationsService = FoldingOperationsService()
    private var updateTask: Task<Void, Never>?

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
    private let memoryMonitor: MemoryMonitor?
    private static let memoryCleanupIdentifier = "CodeFoldingEngine.foldRegionCache"

    // MARK: - Initialization

    internal init(
        performanceMetrics: ProductionPerformanceMetrics? = nil,
        memoryMonitor: MemoryMonitor? = nil
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

    internal func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard event.editedCharacters else { return }
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
        let changed = operationsService.toggleFold(at: line, regions: foldableRegions, foldedRegions: &foldedRegions)
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

    /// Get foldable region at line
    internal func foldableRegion(at line: Int) -> FoldableRegion? {
        operationsService.foldableRegion(at: line, from: foldableRegions)
    }

    /// Check if line is in a folded region
    internal func isLineFolded(_ line: Int) -> Bool {
        operationsService.isLineFolded(line, regions: foldableRegions, foldedRegions: foldedRegions)
    }

    /// Check if line is the start of a foldable region
    internal func isStartOfFoldableRegion(_ line: Int) -> Bool {
        operationsService.isStartOfFoldableRegion(line, regions: foldableRegions)
    }

    // MARK: - Cache Management

    private func combineHashes(_ hash1: Int, _ hash2: Int) -> Int {
        // Simple hash combination
        var hasher = Hasher()
        hasher.combine(hash1)
        hasher.combine(hash2)
        return hasher.finalize()
    }

    private func maintainCacheSize() {
        let maxCacheSize = 10
        if foldRegionCache.count > maxCacheSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = foldRegionCache.count - maxCacheSize
            let sortedKeys = foldRegionCache.keys.sorted()
            for index in 0..<keysToRemove where index < sortedKeys.count {
                foldRegionCache.removeValue(forKey: sortedKeys[index])
            }
        }
    }

    /// Clear the cache when memory pressure is detected
    internal func clearCache() {
        foldRegionCache.removeAll()
        lastTextHash = 0
        lastLanguage = .plainText
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

        // For small edits, try to update incrementally
        if changeInLength < 100 && editedRange.length < 100 {
            updateTask?.cancel()

            updateTask = Task { [weak self] in
                guard let self else { return }

                await self.incrementalUpdate(editedRange: editedRange, changeInLength: changeInLength)
            }
        } else {
            // For large edits, do full update
            updateFoldableRegions()
        }
    }

    private func incrementalUpdate(editedRange: NSRange, changeInLength: Int) async {
        // Adjust existing regions based on the edit
        let adjustedRegions = foldableRegions.map { region in
            var adjustedRegion = region

            // If edit is before the region, shift it
            if editedRange.location < region.range.location {
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

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let text = textView.textStorage?.string else {
            foldableRegions = []
            return
        }
        #else
        let text = textView.textStorage.string
        #endif

        let startTime = CFAbsoluteTimeGetCurrent()

        // Check cache first
        let currentTextHash = text.hashValue
        let cacheKey = combineHashes(currentTextHash, language.hashValue)

        if currentTextHash == lastTextHash &&
           language == lastLanguage,
           let cachedRegions = foldRegionCache[cacheKey] {
            // Use cached regions
            foldableRegions = cachedRegions
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let documentLength = TextRangeUtilities.utf16Length(of: text)
        let regions = await provider.detectFoldableRegions(in: text)

        // Filter and sort regions
        let validRegions = regions
            .filter { region in
                // Validate region
                region.range.location >= 0 &&
                NSMaxRange(region.range) <= documentLength &&
                region.range.length >= configuration.minimumLineCount
            }
            .sorted { $0.range.location < $1.range.location }

        // Update cache
        lastTextHash = currentTextHash
        lastLanguage = language
        maintainCacheSize()
        foldRegionCache[cacheKey] = validRegions

        // Build hierarchy
        let hierarchicalRegions = buildHierarchy(from: validRegions)

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

    private func buildHierarchy(from regions: [FoldableRegion]) -> [FoldableRegion] {
        var hierarchicalRegions: [FoldableRegion] = []

        for region in regions {
            // Find parent region
            var parent: FoldableRegion?
            var level = 0

            for existing in hierarchicalRegions.reversed() where RangeUtilities.contains(existing.range, region.range) {
                parent = existing
                level = existing.level + 1
                break
            }

            // Create hierarchical region
            var updatedRegion = region
            updatedRegion.level = level
            updatedRegion.parentId = parent?.id

            hierarchicalRegions.append(updatedRegion)
        }

        return hierarchicalRegions
    }

    private func updateRegions(_ newRegions: [FoldableRegion]) {
        // Preserve fold state for regions that still exist
        var newFoldedRegions = Set<UUID>()

        for newRegion in newRegions {
            // Check if this region was previously folded
            if let existingRegion = foldableRegions.first(where: {
                $0.range == newRegion.range && $0.type == newRegion.type
            }), foldedRegions.contains(existingRegion.id) {
                newFoldedRegions.insert(newRegion.id)
            }
        }

        foldableRegions = newRegions
        foldedRegions = newFoldedRegions
    }

    private var collapsedFoldIDs: Set<String> {
        Set(foldedRegions.map(\.uuidString))
    }

    private func syncFoldStorageCollapseStates() {
        for region in foldableRegions {
            foldStorage.setCollapsed(
                foldID: region.id.uuidString,
                collapsed: foldedRegions.contains(region.id)
            )
        }
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}
