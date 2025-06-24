//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
@preconcurrency import AppKit
#endif

@MainActor
extension STTextView: @preconcurrency NSTextViewportLayoutControllerDelegate {

    @MainActor
    public func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        let overdrawRect = textPreparedContentRect
        let minY: CGFloat
        let maxY: CGFloat
        let minX: CGFloat
        let maxX: CGFloat

        let visibleRect = textContentView.visibleRect

        if !overdrawRect.isEmpty, overdrawRect.intersects(visibleRect) {
            // Use preparedContentRect for vertical overdraw and ensure visibleRect is included at the minimum,
            // the width is always bounds width for proper line wrapping.
            minX = min(overdrawRect.minX, max(visibleRect.minX, bounds.minX))
            minY = min(overdrawRect.minY, max(visibleRect.minY, bounds.minY))
            maxX = max(overdrawRect.maxX, visibleRect.maxX)
            maxY = max(overdrawRect.maxY, visibleRect.maxY)
        } else {
            // We use visible rect directly if preparedContentRect does not intersect.
            // This can happen if overdraw has not caught up with scrolling yet, such as before the first layout.
            minX = visibleRect.minX
            minY = visibleRect.minY
            maxX = visibleRect.maxX
            maxY = visibleRect.maxY
        }

        let rect = CGRect(x: minX, y: minY, width: maxX, height: maxY - minY)
        logger.debug("viewportBounds \(rect.debugDescription)")
        return rect
    }

    @MainActor
    public func textViewportLayoutControllerWillLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        print("DEBUG: Will layout viewport")
        // TODO: update difference, not all layers
        /// Remove everything except insertion point
        textContentView.subviews.removeAll {
            type(of: $0) != STInsertionPointView.self
        }
    }

    @MainActor
    public func textViewportLayoutController(_ textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
            print("DEBUG: Configuring fragment with frame: \(textLayoutFragment.layoutFragmentFrame)")
            if let stTextLayoutFragment = textLayoutFragment as? STTextLayoutFragment,
               stTextLayoutFragment.showsInvisibleCharacters != showsInvisibleCharacters
            {
                stTextLayoutFragment.showsInvisibleCharacters = showsInvisibleCharacters
            }

            let fragmentView: STTextLayoutFragmentView
            if let cachedFragmentView = fragmentViewMap.object(forKey: textLayoutFragment) {
                cachedFragmentView.layoutFragment = textLayoutFragment
                fragmentView = cachedFragmentView
            } else {
                fragmentView = STTextLayoutFragmentView(layoutFragment: textLayoutFragment, frame: textLayoutFragment.layoutFragmentFrame.pixelAligned)
            }

            // Adjust fragment view frame
            if !fragmentView.frame.isAlmostEqual(to: textLayoutFragment.layoutFragmentFrame.pixelAligned)  {
                fragmentView.frame = textLayoutFragment.layoutFragmentFrame.pixelAligned
                fragmentView.needsLayout = true
                fragmentView.needsDisplay = true
            }

            textContentView.addSubview(fragmentView)
            fragmentViewMap.setObject(fragmentView, forKey: textLayoutFragment)
    }

    @MainActor
    public func textViewportLayoutControllerDidLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        sizeToFit()
        updateSelectedRangeHighlight()
        updateSelectedLineHighlight()
        adjustViewportOffsetIfNeeded()
        layoutGutter()

        if let viewportRange = textViewportLayoutController.viewportRange {
            for events in plugins.events {
                events.didLayoutViewportHandler?(viewportRange)
            }
        }
    }

    private func adjustViewportOffsetIfNeeded() {
        guard let clipView = scrollView?.contentView else {
            return
        }

        func adjustViewportOffset() {
            guard let viewportRange = viewportLayoutController.viewportRange else {
                return
            }

            let viewportLayoutController = textLayoutManager.textViewportLayoutController
            var layoutYPoint: CGFloat = 0
            textLayoutManager.enumerateTextLayoutFragments(from: viewportRange.location, options: [.reverse, .ensuresLayout]) { layoutFragment in
                layoutYPoint = layoutFragment.layoutFragmentFrame.origin.y
                return true // NOTE: should break early (return false)?
            }

            if !layoutYPoint.isZero {
                let adjustmentDelta = bounds.minY - layoutYPoint
                viewportLayoutController.adjustViewport(byVerticalOffset: adjustmentDelta)
                scroll(CGPoint(x: clipView.bounds.minX, y: clipView.bounds.minY + adjustmentDelta))
            }
        }

        let viewportLayoutController = textLayoutManager.textViewportLayoutController
        let contentOffset = clipView.bounds.minY
        if contentOffset < clipView.bounds.height, let viewportRange = viewportLayoutController.viewportRange,
            viewportRange.location > textLayoutManager.documentRange.location
        {
            // Nearing top, see if we need to adjust and make room above.
            adjustViewportOffset()
        } else if let viewportRange = viewportLayoutController.viewportRange, viewportRange.location == textLayoutManager.documentRange.location {
            // At top, see if we need to adjust and reduce space above.
            adjustViewportOffset()
        }
    }
}
