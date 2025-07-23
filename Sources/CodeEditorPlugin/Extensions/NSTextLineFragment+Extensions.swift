#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSTextLineFragment {
    /// Whether the line fragment is for the extra line fragment at the end of a document.
    ///
    /// The layout manager uses the extra line fragment when the last character in a document causes a line or paragraph break. This extra line fragment has no corresponding glyph.
    var isExtraLineFragment: Bool {
        // textLineFragment.characterRange.isEmpty the extra line fragment at the end of a document.
        characterRange.isEmpty
    }

    /// Returns a text range inside privided textLayoutFragment.
    ///
    /// Returned range is relative to the document range origin.
    /// - Parameter textLayoutFragment: Text layout fragment
    /// - Returns: Text range or nil
    func textRange(in textLayoutFragment: NSTextLayoutFragment) -> NSTextRange? {
        guard let textContentManager = textLayoutFragment.textLayoutManager?.textContentManager else {
            assertionFailure()
            return nil
        }

        guard let startLocation = textContentManager.location(
            textLayoutFragment.rangeInElement.location,
            offsetBy: characterRange.location
        ) else {
            return nil
        }

        let endLocation = textContentManager.location(
            textLayoutFragment.rangeInElement.location,
            offsetBy: characterRange.location + characterRange.length
        )

        return NSTextRange(location: startLocation, end: endLocation)
    }
}

// MARK: - NSTextLineFragment Character Intersection

@available(macOS 12.0, iOS 15.0, *)
extension NSTextLineFragment {
    /// Returns the range of characters that intersect with a given horizontal span
    /// The span has to be within this fragment's coordinate system
    func rangeOfCharacters(intersecting span: Range<CGFloat>) -> NSRange? {
        // Even an empty fragment will respond to locationForCharacter(at: 0)
        let length = max(characterRange.length, 1)

        var start: Int?

        for index in 0..<length {
            let point = locationForCharacter(at: index)

            // We might need to back up unless we happen to be exactly on the boundary
            if span.lowerBound < point.x {
                start = max(index - 1, 0)
                break
            }

            if span.lowerBound == point.x {
                start = index
                break
            }
        }

        guard let start else { return nil }

        // Continuing to look here for an empty fragment doesn't make sense
        if characterRange.length == 0 {
            return NSRange(start..<start)
        }

        var end: Int?

        for index in (start..<length).reversed() {
            let point = locationForCharacter(at: index)

            if span.upperBound >= point.x {
                end = min(index + 1, length)
                break
            }
        }

        guard let end else { return nil }

        return NSRange(start..<end)
    }
}
