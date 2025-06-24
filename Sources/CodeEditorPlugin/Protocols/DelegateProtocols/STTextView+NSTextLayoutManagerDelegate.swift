//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

@preconcurrency import AppKit

extension STTextView: NSTextLayoutManagerDelegate {

    nonisolated public func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        // Create the fragment with default paragraph style
        // The style will be updated later if needed
        return STTextLayoutFragment(
            textElement: textElement,
            range: textElement.elementRange,
            paragraphStyle: NSParagraphStyle.default
        )
    }
}
