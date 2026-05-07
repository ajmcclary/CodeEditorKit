import Foundation

/// Adapts existing `CodeFoldingProvider` results into fold storage.
@MainActor
internal final class FoldRegionAdapter {
    private let provider: any CodeFoldingProvider

    init(provider: any CodeFoldingProvider) {
        self.provider = provider
    }

    func buildStorage(from text: String, existingStorage: LineFoldStorage? = nil) async -> LineFoldStorage {
        let regions = await provider.detectFoldableRegions(in: text)
        let collapsedIDs: Set<String> = Set(
            existingStorage?.folds(in: NSRange(location: 0, length: text.utf16.count))
                .filter(\.isCollapsed)
                .map(\.id) ?? []
        )

        var storage = LineFoldStorage(documentLength: text.utf16.count)
        storage.updateFolds(from: regions, collapsedIDs: collapsedIDs)
        return storage
    }

    func applyEdit(to storage: inout LineFoldStorage, editedRange: NSRange, changeInLength: Int) {
        storage.storageUpdated(
            replacedCharactersIn: editedRange.location..<(editedRange.location + editedRange.length),
            withCount: editedRange.length + changeInLength
        )
    }
}
