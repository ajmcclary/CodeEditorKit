import CodeEditorTextModel
import Foundation

/// A value stored in a `RangeStore` for syntax highlighting.
///
/// Contains a capture name (the kind of token, e.g. "keyword")
/// and optional modifiers. Merged by `StyledRangeContainer` when
/// multiple providers produce overlapping results.
package struct StyleElement: RangeStoreElement, Sendable, Equatable {
    /// The capture name (e.g. "keyword.swift", "string.quoted.double").
    package var capture: String?

    /// When `true`, this element represents a gap (no style data).
    package var isEmpty: Bool {
        capture == nil
    }

    package init(capture: String?) {
        self.capture = capture
    }

    /// Merge with a lower-priority element — keep own capture.
    package func combineLowerPriority(_: Self) -> Self {
        self
    }

    /// Merge with a higher-priority element — take other's capture.
    package func combineHigherPriority(_ other: Self) -> Self {
        other.isEmpty ? self : other
    }
}
