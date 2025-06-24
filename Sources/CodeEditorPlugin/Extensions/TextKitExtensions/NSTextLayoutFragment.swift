#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#elseif os(iOS) || os(visionOS)
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif

extension NSTextLayoutFragment {
    package var isExtraLineFragment: Bool {
        textLineFragments.contains(where: \.isExtraLineFragment)
    }

    func textLineFragment(
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

    func textLineFragment(at location: CGPoint, in _: NSTextContentManager? = nil) -> NSTextLineFragment? {
        textLineFragments.first { lineFragment in
            CGRect(origin: layoutFragmentFrame.origin, size: lineFragment.typographicBounds.size).contains(location)
        }
    }
}
