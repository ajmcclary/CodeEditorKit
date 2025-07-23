import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Engine for managing code folding in the editor
@MainActor
internal class CodeFoldingEngine: ObservableObject {
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

    // MARK: - Caching

    private var foldRegionCache: [Int: [FoldableRegion]] = [:] // Hash -> Regions
    private var lastTextHash: Int = 0
    private var lastLanguage: Language = .plainText

    // MARK: - Configuration

    internal var configuration = CodeFoldingConfiguration()

    // MARK: - Initialization

    internal init() {
        // Providers are now initialized in FoldingProviderRegistry
    }

    /// Attach to a text view
    internal func attach(to textView: CodeEditorView) {
        self.textView = textView
        operationsService.attach(to: textView)
        updateFoldableRegions()
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
        operationsService.toggleFold(at: line, regions: foldableRegions, foldedRegions: &foldedRegions)
    }

    /// Fold a specific region
    /// - Returns: `true` if the region was folded, `false` if it was already folded or textView is nil
    @discardableResult
    internal func fold(_ region: FoldableRegion) -> Bool {
        operationsService.fold(region, foldedRegions: &foldedRegions, configuration: configuration)
    }

    /// Unfold a specific region
    /// - Returns: `true` if the region was unfolded, `false` if it wasn't folded or textView is nil
    @discardableResult
    internal func unfold(_ region: FoldableRegion) -> Bool {
        operationsService.unfold(region, foldedRegions: &foldedRegions, configuration: configuration)
    }

    /// Fold all regions
    internal func foldAll() {
        operationsService.foldAll(regions: foldableRegions, foldedRegions: &foldedRegions, configuration: configuration)
    }

    /// Unfold all regions
    internal func unfoldAll() {
        operationsService.unfoldAll(regions: foldableRegions, foldedRegions: &foldedRegions, configuration: configuration)
    }

    /// Fold all regions at a specific level
    internal func foldLevel(_ level: Int) {
        operationsService.foldLevel(level, regions: foldableRegions, foldedRegions: &foldedRegions, configuration: configuration)
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

    /// Update foldable regions based on current text
    internal func updateFoldableRegions() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self else { return }

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

        let regions = await provider.detectFoldableRegions(in: text)

        // Filter and sort regions
        let validRegions = regions
            .filter { region in
                // Validate region
                region.range.location >= 0 &&
                NSMaxRange(region.range) <= text.count &&
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

        // Track performance metrics
        let endTime = CFAbsoluteTimeGetCurrent()
        await ProductionPerformanceMetrics.shared.trackCodeFolding(
            duration: endTime - startTime,
            regionCount: hierarchicalRegions.count,
            fileSize: text.count
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

    deinit {
        // Cleanup is handled automatically by ARC
    }
}
