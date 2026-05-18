import CodeEditorFolding
import CodeEditorLanguages
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Presentation strategy for fold collapse/expand.
///
/// Two implementations are planned:
/// - `AttributeFoldPresentationStrategy` — hides content with attributes (current, active).
/// - `OverlayFoldPresentationStrategy` — draws placeholder overlay (future, behind feature flag).
@MainActor
internal protocol FoldPresentationStrategy: AnyObject {
    /// Collapse a fold region in the text view.
    func collapse(fold: FoldInfo, in textView: CodeEditorView)

    /// Expand a previously collapsed fold region.
    func expand(fold: FoldInfo, in textView: CodeEditorView)
}

// MARK: - Attribute-based strategy (current default)

/// Hides folded content by applying a nearly-invisible paragraph style
/// and font, matching the existing `FoldingOperationsService` behavior.
@MainActor
internal final class AttributeFoldPresentationStrategy: FoldPresentationStrategy {
    private let operationsService = FoldingOperationsService()

    func collapse(fold: FoldInfo, in textView: CodeEditorView) {
        operationsService.attach(to: textView)
        let region = regionFrom(fold: fold)
        var folded = Set<UUID>()
        operationsService.fold(region, foldedRegions: &folded)
    }

    func expand(fold: FoldInfo, in textView: CodeEditorView) {
        operationsService.attach(to: textView)
        let region = regionFrom(fold: fold)
        var folded = Set([region.id])
        operationsService.unfold(region, foldedRegions: &folded)
    }

    private func regionFrom(fold: FoldInfo) -> FoldableRegion {
        var region = FoldableRegion(range: fold.range, title: fold.id, type: fold.kind)
        region.level = fold.depth
        return region
    }
}
