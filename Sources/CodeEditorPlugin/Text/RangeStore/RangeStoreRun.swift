import Foundation

/// A single contiguous run inside a `RangeStore`.
///
/// A value of `nil` means "no data" — the range is a gap.
/// Non-nil values carry semantics (e.g. a style, a fold region).
internal struct RangeStoreRun<Element: RangeStoreElement>: Sendable, Equatable {
    internal var length: Int
    internal var value: Element?

    /// Creates a gap run (no data) of the given length.
    internal static func empty(length: Int) -> Self {
        .init(length: length, value: nil)
    }
}
