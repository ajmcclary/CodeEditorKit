import Foundation

/// A UTF-16 range of characters, expressed as a value type so highlight
/// providers can describe token spans without importing an editor view or
/// Foundation's reference-flavored range types at their call sites.
///
/// Bridges losslessly to and from `NSRange`.
public struct HighlightRange: Sendable, Equatable, Hashable {
    /// UTF-16 offset of the first character in the range.
    public var location: Int

    /// Number of UTF-16 code units in the range.
    public var length: Int

    /// Creates a range from a location and length.
    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }

    /// Creates a range from a Foundation `NSRange`.
    public init(_ nsRange: NSRange) {
        self.location = nsRange.location
        self.length = nsRange.length
    }

    /// The UTF-16 offset one past the last character in the range.
    public var upperBound: Int { location + length }

    /// The equivalent Foundation `NSRange`.
    public var nsRange: NSRange { NSRange(location: location, length: length) }
}
