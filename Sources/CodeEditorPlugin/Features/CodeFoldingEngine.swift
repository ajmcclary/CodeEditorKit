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

    // MARK: - Region Detection

    /// Update foldable regions based on current text
    internal func updateFoldableRegions() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self else { return }

            await self.detectFoldableRegions()
        }
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

        // Build hierarchy
        let hierarchicalRegions = buildHierarchy(from: validRegions)

        // Update regions, preserving fold state
        updateRegions(hierarchicalRegions)
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
