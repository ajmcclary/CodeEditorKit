import Foundation
import IssueReporting

/// Manages the valid/pending/visible state for a single highlight provider.
///
/// The state machine tracks three IndexSets:
/// - **validSet**: character indices known to have current highlights.
/// - **pendingSet**: indices currently being queried (requested but not yet applied).
/// - **visibleSet**: indices currently in the text view's viewport.
///
/// New ranges to highlight are computed as:
/// ```
/// (document - validSet) ∩ visibleSet - pendingSet
/// ```
@MainActor
internal final class HighlightProviderState {
    // MARK: - State

    private var validSet = IndexSet()
    private var pendingSet = IndexSet()
    private var failedSet = IndexSet()
    private var visibleSet = IndexSet()
    private var documentLength: Int
    private let provider: any RangeHighlightProviding
    private let providerID: Int
    private weak var container: StyledRangeContainer?
    private weak var textView: CodeEditorView?
    private let maxChunk: Int
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "HighlightProviderState")

    private var chunkTask: Task<Void, Never>?

    /// Called on the main actor after a range of highlights has been
    /// written to the container. The range is the full query range
    /// (not individual token ranges). Set by the attribute applier.
    var onRangeHighlighted: (@MainActor (NSRange) -> Void)?

    init(
        provider: any RangeHighlightProviding,
        providerID: Int,
        container: StyledRangeContainer,
        textView: CodeEditorView,
        documentLength: Int,
        maxChunk: Int = 4_096
    ) {
        self.provider = provider
        self.providerID = providerID
        self.container = container
        self.textView = textView
        self.documentLength = documentLength
        self.maxChunk = maxChunk
    }

    // MARK: - Edit handling

    /// Called after text storage processes an edit.
    func storageDidUpdate(range editedRange: NSRange, delta: Int) {
        documentLength += delta

        guard let textView else { return }
        Task { [weak self] in
            guard let self else { return }
            let invalidated = await self.provider.applyEdit(
                textView: textView,
                range: editedRange,
                delta: delta
            )
            self.invalidate(invalidated)
            await self.highlightInvalidRanges()
        }
    }

    // MARK: - Visible region

    /// Update the visible set (e.g. after scrolling).
    func updateVisibleSet(_ newVisible: IndexSet, schedulesHighlighting: Bool = true) {
        visibleSet = newVisible
        guard schedulesHighlighting else { return }
        Task { [weak self] in
            await self?.highlightInvalidRanges()
        }
    }

    // MARK: - Invalidation

    /// Invalidate a set of indices (remove from valid/pending).
    func invalidate(_ indices: IndexSet) {
        validSet.subtract(indices)
        pendingSet.subtract(indices)
        failedSet.subtract(indices)
    }

    /// Compute the next range to highlight using:
    /// `(documentSet - validSet) ∩ visibleSet - pendingSet`
    func nextRange() -> NSRange? {
        let documentIndices = IndexSet(integersIn: 0..<documentLength)
        var invalid = documentIndices.subtracting(validSet)
        invalid.formIntersection(visibleSet)
        invalid.subtract(pendingSet)
        invalid.subtract(failedSet)

        guard let range = invalid.rangeView.first else { return nil }

        let first = range.lowerBound
        let upperBound = min(range.upperBound, first + maxChunk, documentLength)
        let length = upperBound - first
        guard length > 0 else { return nil }

        return NSRange(location: first, length: length)
    }

    /// Start highlighting invalid ranges.
    func highlightInvalidRanges() async {
        chunkTask?.cancel()
        chunkTask = Task { [weak self] in
            guard let self else { return }
            while let range = self.nextRange(), !Task.isCancelled {
                self.pendingSet.insert(integersIn: range.location..<(range.location + range.length))
                await self.queryHighlights(for: range)
            }
        }
    }

    // MARK: - Query

    private func queryHighlights(for range: NSRange) async {
        guard let container, let textView else { return }

        do {
            let highlights = try await provider.queryHighlights(
                textView: textView,
                range: range
            )
            container.applyHighlightResult(providerID: providerID, highlights: highlights, range: range)
            let indices = IndexSet(integersIn: range.location..<(range.location + range.length))
            pendingSet.subtract(indices)
            validSet.formUnion(indices)
            failedSet.subtract(indices)
            onRangeHighlighted?(range)
        } catch {
            let indices = IndexSet(integersIn: range.location..<(range.location + range.length))
            pendingSet.subtract(indices)
            failedSet.formUnion(indices)
            logger.error("Highlight provider failed for range \(range): \(error.localizedDescription)")
            reportIssue("Highlight provider failed for range \(range): \(error.localizedDescription)")
        }
    }

    /// Cancel pending work.
    func cancel() {
        chunkTask?.cancel()
        chunkTask = nil
    }
}
