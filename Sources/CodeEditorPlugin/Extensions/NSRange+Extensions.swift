#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSRange {
    /// A value indicating that a requested item couldn't be found or doesn't exist.
    static let notFound = NSRange(location: NSNotFound, length: 0)

    /// A Boolean value indicating whether the range is empty.
    ///
    /// Range is empty when its length is equal 0
    var isEmpty: Bool {
        length == 0
    }

    init(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) {
        let offset = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.location)
        let length = textContentManager.offset(from: textRange.location, to: textRange.endLocation)
        self.init(location: offset, length: length)
    }

    init(_ textLocation: NSTextLocation, in textContentManager: NSTextContentManager) {
        let offset = textContentManager.offset(from: textContentManager.documentRange.location, to: textLocation)
        self.init(location: offset, length: 0)
    }

    /// Creates a new value object containing the specified Foundation range structure.
    var nsValue: NSValue {
        NSValue(range: self)
    }

    /// Apply a range mutation to this range
    func apply(_ mutation: RangeMutation) -> NSRange? {
        let mutationRange = mutation.range
        let delta = mutation.delta

        // If mutation is before this range, shift the range
        if mutationRange.upperBound <= location {
            return NSRange(location: location + delta, length: length)
        }

        // If mutation is after this range, no change
        if mutationRange.location >= upperBound {
            return self
        }

        // If mutation overlaps with this range, it's more complex
        // For now, return nil to indicate the range is invalidated
        return nil
    }

    /// Returns a range clamped to the given limiting range
    func clamped(to limit: NSRange) -> NSRange {
        let start = max(location, limit.location)
        let end = min(upperBound, limit.upperBound)

        if start > end {
            return NSRange(location: limit.location, length: 0)
        }

        return NSRange(location: start, length: end - start)
    }
}

// MARK: - Enhanced Range Conversion

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
extension NSRange {
    /// Initialize NSRange from NSTextRange using provider
    init(_ textRange: NSTextRange, provider: NSTextElementProvider) {
        let docLocation = provider.documentRange.location

        let start = provider.offset?(from: docLocation, to: textRange.location) ?? NSNotFound
        if start == NSNotFound {
            self.init(location: start, length: 0)
            return
        }

        let end = provider.offset?(from: docLocation, to: textRange.endLocation) ?? NSNotFound
        if end == NSNotFound {
            self.init(location: NSNotFound, length: 0)
            return
        }

        self.init(start..<end)
    }

    /// Initialize NSRange from NSTextRange using UTF16TextLocation
    public init?(_ textRange: NSTextRange) {
        guard
            let start = textRange.location as? UTF16TextLocation,
            let end = textRange.endLocation as? UTF16TextLocation
        else {
            return nil
        }

        self.init(start.value..<end.value)
    }
}
