import CodeEditorLanguages
import CodeEditorTextModel
import Foundation

/// Fold metadata stored in a `RangeStore`.
///
/// Each run represents a fold at a given character range with a stable
/// identifier and collapse state. Adjacent empty runs (no fold) are
/// automatically coalesced by `RangeStore`.
package struct FoldStoreElement: RangeStoreElement, Sendable, Equatable {
    /// Stable identifier preserved across recalculations.
    package var id: String?

    /// Nesting depth (0 = top-level).
    package var depth: Int

    /// Whether the fold is currently collapsed.
    package var isCollapsed: Bool

    /// The fold type (function, block, comment, etc.).
    package var kind: FoldingType

    /// `true` when this element carries no fold data.
    package var isEmpty: Bool { id == nil }

    package init(id: String?, depth: Int, isCollapsed: Bool, kind: FoldingType) {
        self.id = id
        self.depth = depth
        self.isCollapsed = isCollapsed
        self.kind = kind
    }

    /// An empty element (gap between folds).
    package static var empty: Self {
        Self(id: nil, depth: 0, isCollapsed: false, kind: .region)
    }
}
