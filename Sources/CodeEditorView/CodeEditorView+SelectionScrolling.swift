import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Selection mutation with explicit auto-scroll policy.
@MainActor
extension CodeEditorView {
    #if canImport(AppKit)
    package func setSelectedRangeWithoutScrolling(_ range: NSRange) {
        guard !configuration.behavior.autoScrollToCursor else {
            setSelectedRange(range)
            scrollRangeToVisible(range)
            return
        }
        guard window != nil, superview != nil else {
            setSelectedRange(range)
            return
        }

        let savedVisibleRect = visibleRect
        guard savedVisibleRect.width > 0,
              savedVisibleRect.height > 0,
              savedVisibleRect.origin.x.isFinite,
              savedVisibleRect.origin.y.isFinite else {
            setSelectedRange(range)
            return
        }
        setSelectedRange(range)
        scrollToVisible(savedVisibleRect)
    }
    #elseif canImport(UIKit)
    override open var selectedTextRange: UITextRange? {
        get { super.selectedTextRange }
        set {
            if !configuration.behavior.autoScrollToCursor, newValue != nil {
                preservingScrollPosition {
                    super.selectedTextRange = newValue
                }
            } else {
                super.selectedTextRange = newValue
            }
        }
    }

    override open var selectedRange: NSRange {
        get { super.selectedRange }
        set {
            if configuration.behavior.autoScrollToCursor {
                super.selectedRange = newValue
            } else {
                preservingScrollPosition {
                    super.selectedRange = newValue
                }
            }
        }
    }

    func setSelectedTextRangeWithoutScrolling(_ textRange: UITextRange?) {
        guard !configuration.behavior.autoScrollToCursor else {
            selectedTextRange = textRange
            return
        }
        preservingScrollPosition {
            super.selectedTextRange = textRange
        }
    }

    package func setSelectedRangeWithoutScrolling(_ range: NSRange) {
        guard !configuration.behavior.autoScrollToCursor else {
            selectedRange = range
            return
        }
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let range = textRange(from: start, to: end) else {
            return
        }
        setSelectedTextRangeWithoutScrolling(range)
    }

    override open func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        guard configuration.behavior.autoScrollToCursor else { return }
        super.scrollRectToVisible(rect, animated: animated)
    }

    private func preservingScrollPosition(_ operation: () -> Void) {
        let offset = contentOffset
        let scrolling = isScrollEnabled
        isScrollEnabled = false
        operation()
        isScrollEnabled = scrolling
        if contentOffset != offset {
            setContentOffset(offset, animated: false)
        }
    }
    #endif
}
