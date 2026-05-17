import Foundation

/// A single contiguous run inside a `RangeStore`.
///
/// A value of `nil` means "no data" — the range is a gap.
/// Non-nil values carry semantics (e.g. a style, a fold region).
package struct RangeStoreRun<Element: RangeStoreElement>: Sendable, Equatable {
    package var length: Int
    package var value: Element?

    package init(length: Int, value: Element?) {
        self.length = length
        self.value = value
    }

    /// Creates a gap run (no data) of the given length.
    package static func empty(length: Int) -> Self {
        .init(length: length, value: nil)
    }
}
