// swiftlint:disable missing_docs
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSTextLayoutFragment {
    package var isExtraLineFragment: Bool {
        textLineFragments.contains(where: \.isExtraLineFragment)
    }

    public func textLineFragment(
        at location: NSTextLocation,
        in textContentManager: NSTextContentManager? = nil
    ) -> NSTextLineFragment? {
        guard let textContentManager = textContentManager ?? textLayoutManager?.textContentManager else {
            assertionFailure()
            return nil
        }

        let searchNSLocation = NSRange(location, in: textContentManager).location
        let fragmentLocation = NSRange(rangeInElement.location, in: textContentManager).location
        return textLineFragments.first { lineFragment in
            let absoluteLineRange = NSRange(
                location: lineFragment.characterRange.location + fragmentLocation,
                length: lineFragment.characterRange.length
            )
            return absoluteLineRange.contains(searchNSLocation)
        }
    }

    public func textLineFragment(at location: CGPoint, in _: NSTextContentManager? = nil) -> NSTextLineFragment? {
        textLineFragments.first { lineFragment in
            CGRect(origin: layoutFragmentFrame.origin, size: lineFragment.typographicBounds.size).contains(location)
        }
    }
}

// MARK: - Enhanced Line Fragment Enumeration

@available(macOS 12.0, iOS 15.0, *)
extension NSTextLayoutFragment {
    /// Enumerate the line fragments making up the layout fragment.
    ///
    /// > Note: Reverse enumeration is more expensive.
    ///
    /// - Parameter provider: used to translate ranges.
    /// - Parameter reverse: perform enumeration in reverse, defaults to false.
    /// - Parameter block: invoked per line fragment with the fragment itself, its bounding rect, its range in the text, and its layout fragment-relative index offset for use with the `locationForCharacter(at:)` API.
    public func enumerateLineFragments(with provider: NSTextElementProvider, reverse: Bool = false, block: (NSTextLineFragment, CGRect, NSRange, Int) -> Bool) {
        let origin = layoutFragmentFrame.origin
        let location = provider.offset?(from: provider.documentRange.location, to: rangeInElement.location) ?? 0

        // Check to ensure our shift will always be valid
        precondition(location >= 0)
        precondition(location != NSNotFound)

        let fragments = reverse ? textLineFragments.reversed() : textLineFragments
        var offset = 0

        for textLineFragment in fragments {
            let bounds = textLineFragment.typographicBounds.offsetBy(dx: origin.x, dy: origin.y)
            let range = NSRange(
                location: textLineFragment.characterRange.location + location,
                length: textLineFragment.characterRange.length
            )

            if block(textLineFragment, bounds, range, offset) == false {
                return
            }

            offset += textLineFragment.characterRange.length
        }
    }

    /// Enumerate the line fragments making up the layout fragment within a specific range.
    ///
    /// > Note: Reverse enumeration is more expensive.
    ///
    /// - Parameter range: restrict the enumeration to line fragments within this range.
    /// - Parameter provider: used to translate ranges.
    /// - Parameter reverse: perform enumeration in reverse, defaults to false.
    /// - Parameter block: invoked per line fragment with the fragment itself, its bounding rect, its range in the text, and its layout fragment-relative index offset for use with the `locationForCharacter(at:)` API.
    public func enumerateLineFragments(
        in range: NSRange,
        with provider: NSTextElementProvider,
        reverse: Bool = false,
        block: (NSTextLineFragment, CGRect, NSRange, Int) -> Bool
    ) {
        enumerateLineFragments(with: provider, reverse: reverse) { lineFragment, frame, elementRange, offset in
            // This enumeration is unconditional, but some line fragments might not be within our range

            if reverse {
                // For reverse enumeration, we could add range checking logic here if needed
            } else {
                if elementRange.upperBound <= range.lowerBound {
                    return true
                }

                if elementRange.lowerBound > range.upperBound {
                    return true
                }
            }

            return block(lineFragment, frame, elementRange, offset)
        }
    }

    /// Enumerate line fragments that intersect with a given rectangle
    public func enumerateLineFragments(
        with provider: NSTextElementProvider,
        intersecting rect: CGRect,
        block: (NSTextLineFragment, CGRect, NSRange) -> Bool
    ) {
        let origin = layoutFragmentFrame.origin
        let location = provider.offset?(from: provider.documentRange.location, to: rangeInElement.location) ?? 0

        // Check to ensure our shift will always be valid
        precondition(location >= 0)
        precondition(location != NSNotFound)

        var locationOffset = location

        for textLineFragment in textLineFragments {
            // We have to shift to compute overlap, and then shift back to compute the span
            let bounds = textLineFragment.typographicBounds.offsetBy(dx: origin.x, dy: origin.y)
            let overlap = bounds.intersection(rect).offsetBy(dx: -origin.x, dy: -origin.y)
            let span: Range<CGFloat> = overlap.minX..<overlap.maxX

            // The locationOffset has to be computed even if we do not overlap
            let offset = locationOffset
            defer {
                locationOffset += textLineFragment.characterRange.length
            }

            guard let localRange = textLineFragment.rangeOfCharacters(intersecting: span) else { continue }

            let range = NSRange(
                location: localRange.location + offset,
                length: localRange.length
            )

            if block(textLineFragment, bounds, range) == false {
                return
            }
        }
    }
}

// swiftlint:enable missing_docs
