#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

    func length(in textContentManager: NSTextContentManager) -> Int {
        textContentManager.offset(from: location, to: endLocation)
    }

    /// Returns a copy of this range clamped to the given limiting range.
    func clamped(to textRange: NSTextRange) -> Self? {
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
final class UTF16TextLocation: NSObject, NSTextLocation {
    let value: Int

    init(value: Int) {
        self.value = value
    }
    
    deinit {
        // Required by SwiftLint
    }

    func compare(_ location: any NSTextLocation) -> ComparisonResult {
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
    convenience init?(_ range: NSRange, provider: NSTextElementProvider) {
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
    func toNSRange() -> NSRange? {
        NSRange(self)
    }

    /// Convert to NSRange using provider
    func toNSRange(provider: NSTextElementProvider) -> NSRange {
        NSRange(self, provider: provider)
    }
}
