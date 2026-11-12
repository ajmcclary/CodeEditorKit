import CodeEditorCommon
import CodeEditorPlatform
import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CodeEditorView Unified Edge Insets

extension CodeEditorView {
    /// The padding between each edge of the view and its text.
    ///
    /// On macOS the four edges are independent even though
    /// `NSTextView.textContainerInset` is one size for both sides: the inset
    /// holds the mean of each pair and `textContainerOrigin` moves the text
    /// by the difference. Code that places something over the text must
    /// therefore start from `textContainerOrigin`, never from
    /// `textContainerInset`.
    public var unifiedTextContainerInsets: FrameworkEdgeInsets {
        #if canImport(AppKit)
        let inset = textContainerInset
        let shift = textContainerOriginShift
        return FrameworkEdgeInsets(
            top: inset.height + shift.y,
            left: inset.width + shift.x,
            bottom: inset.height - shift.y,
            right: inset.width - shift.x
        )
        #else
        return FrameworkEdgeInsets(uiEdgeInsets: textContainerInset)
        #endif
    }

    /// Set the padding between each edge of the view and its text. Negative
    /// values are treated as zero.
    public func setUnifiedTextContainerInsets(_ insets: FrameworkEdgeInsets) {
        #if canImport(AppKit)
        let top = max(0, insets.top)
        let left = max(0, insets.left)
        let bottom = max(0, insets.bottom)
        let right = max(0, insets.right)
        // Compared with a tolerance: the stored form is a mean and a
        // difference, which need not add back up to the exact value.
        let current = unifiedTextContainerInsets
        let isUnchanged = abs(current.top - top) < 0.01 && abs(current.left - left) < 0.01
            && abs(current.bottom - bottom) < 0.01 && abs(current.right - right) < 0.01
        guard !isUnchanged else { return }

        // The shift goes first: setting the inset makes AppKit recompute the
        // origin, and it must read the new shift when it does.
        textContainerOriginShift = CGPoint(x: (left - right) / 2, y: (top - bottom) / 2)
        textContainerInset = NSSize(width: (left + right) / 2, height: (top + bottom) / 2)
        invalidateTextContainerOrigin()

        // The inset alone changes the sizes derived from it; when only the
        // shift changed nothing else re-places the text already laid out.
        applyWrapWidthFraction()
        textLayoutManager?.textViewportLayoutController.layoutViewport()
        // The line highlight, the annotation views and the gutter's numbers
        // are all placed from the origin.
        needsLayout = true
        needsDisplay = true
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
        #else
        textContainerInset = insets.uiEdgeInsets
        #endif
    }

    #if canImport(AppKit)
    /// The text container's origin in the view's coordinates: AppKit's own
    /// (the symmetric inset) moved by `textContainerOriginShift`.
    ///
    /// AppKit draws, hit-tests and reports character rectangles through this
    /// property, so overriding it is what makes four independent insets
    /// possible. With no shift it returns AppKit's value untouched.
    override open var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin
        let shift = textContainerOriginShift
        guard shift != .zero else { return origin }
        return NSPoint(x: origin.x + shift.x, y: origin.y + shift.y)
    }
    #endif
}
