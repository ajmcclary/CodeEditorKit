import Foundation

/// A value that can be stored in a `RangeStore` as a run's element.
///
/// Conformers provide an `isEmpty` flag so the store can coalesce
/// adjacent empty runs (gaps) automatically.
package protocol RangeStoreElement: Sendable, Equatable {
    /// `true` when this element represents "no data".
    var isEmpty: Bool { get }
}
