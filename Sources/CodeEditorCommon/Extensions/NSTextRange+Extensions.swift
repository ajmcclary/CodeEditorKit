// swiftlint:disable missing_docs
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSTextRange {
    convenience init?(_ nsRange: NSRange, in textContentManager: NSTextContentManager) {
        guard let start = textContentManager.location(
            textContentManager.documentRange.location,
            offsetBy: nsRange.location
        ) else {
            return nil
        }
        let end = textContentManager.location(start, offsetBy: nsRange.length)
        self.init(location: start, end: end)
    }

    public func length(in textContentManager: NSTextContentManager) -> Int {
        textContentManager.offset(from: location, to: endLocation)
    }

    /// Returns a copy of this range clamped to the given limiting range.
    public func clamped(to textRange: NSTextRange) -> Self? {
        let beginLocation = {
            if self.location <= textRange.location {
                return textRange.location
            }

            if self.location >= textRange.endLocation {
                return textRange.endLocation
            }

            return self.location
        }()

        let endLocation = {
            if self.endLocation <= textRange.location {
                return textRange.location
            }

            if self.endLocation >= textRange.endLocation {
                return textRange.endLocation
            }

            return self.endLocation
        }()

        return Self(location: beginLocation, end: endLocation)
    }
}

// MARK: - Enhanced Range Conversion

/// UTF16 text location for improved TextKit 2 range handling
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public final class UTF16TextLocation: NSObject, NSTextLocation {
    public let value: Int

    public init(value: Int) {
        self.value = value
    }

    deinit {
        // Required by SwiftLint
    }

    public func compare(_ location: any NSTextLocation) -> ComparisonResult {
        guard let utf16Loc = location as? Self else {
            return .orderedSame
        }

        if value < utf16Loc.value {
            return .orderedAscending
        }

        if value > utf16Loc.value {
            return .orderedDescending
        }

        return .orderedSame
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
@available(watchOS, unavailable)
extension NSTextRange {
    /// Initialize NSTextRange from NSRange using UTF16TextLocation
    public convenience init?(_ range: NSRange) {
        let start = UTF16TextLocation(value: range.lowerBound)
        let end = UTF16TextLocation(value: range.upperBound)

        self.init(location: start, end: end)
    }

    /// Initialize NSTextRange from NSRange using provider
    public convenience init?(_ range: NSRange, provider: NSTextElementProvider) {
        let docLocation = provider.documentRange.location

        guard let start = provider.location?(docLocation, offsetBy: range.location) else {
            return nil
        }

        guard let end = provider.location?(start, offsetBy: range.length) else {
            return nil
        }

        self.init(location: start, end: end)
    }

    /// Convert to NSRange if possible
    public func toNSRange() -> NSRange? {
        NSRange(self)
    }

    /// Convert to NSRange using provider
    public func toNSRange(provider: NSTextElementProvider) -> NSRange {
        NSRange(self, provider: provider)
    }
}

// swiftlint:enable missing_docs
