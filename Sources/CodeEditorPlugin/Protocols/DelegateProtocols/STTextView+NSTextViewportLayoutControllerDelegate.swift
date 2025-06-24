//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md
//  Updated for NSTextView-based implementation


#if canImport(AppKit)
import AppKit
#endif

/// NSTextView-based implementation doesn't use NSTextViewportLayoutController
extension STTextView {
    // The NSTextViewportLayoutController delegate methods are not needed for NSTextView
    // since NSTextView handles its own layout internally
}