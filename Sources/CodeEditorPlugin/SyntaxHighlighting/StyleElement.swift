import CodeEditorTextModel
import Foundation

/// A value stored in a `RangeStore` for syntax highlighting.
///
/// Contains a capture name (the kind of token, e.g. "keyword")
/// and optional modifiers. Merged by `StyledRangeContainer` when
/// multiple providers produce overlapping results.
internal struct StyleElement: RangeStoreElement, Sendable, Equatable {
    /// The capture name (e.g. "keyword.swift", "string.quoted.double").
    internal var capture: String?

    /// When `true`, this element represents a gap (no style data).
    internal var isEmpty: Bool {
        capture == nil
    }

    internal init(capture: String?) {
        self.capture = capture
    }

    /// Merge with a lower-priority element — keep own capture.
    internal func combineLowerPriority(_: Self) -> Self {
        self
    }

    /// Merge with a higher-priority element — take other's capture.
    internal func combineHigherPriority(_ other: Self) -> Self {
        other.isEmpty ? self : other
    }
}
