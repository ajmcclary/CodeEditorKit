import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Helper for unified container view operations across platforms
@MainActor
enum ContainerViewHelper {
    // MARK: - Text Navigation

    /// Navigate to a specific line number in the text view
    static func navigateToLine(_ lineNumber: Int, in textView: CodeEditorView) {
        let text = getText(from: textView)
        let lines = text.components(separatedBy: CharacterSet.newlines)

        guard lineNumber < lines.count else { return }

        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        let targetPosition = lineNumber > 0 ? lineStart + 1 : 0

        performNavigation(to: targetPosition, in: textView)
    }

    // MARK: - Platform-Specific Navigation

    private static func getText(from textView: CodeEditorView) -> String {
        #if canImport(AppKit)
        return textView.string
        #else
        return textView.text ?? ""
        #endif
    }

    private static func performNavigation(to position: Int, in textView: CodeEditorView) {
        #if canImport(AppKit)
        // macOS navigation
        textView.setSelectedRange(NSRange(location: position, length: 0))

        // Only scroll if autoScrollToCursor is enabled
        if textView.configuration.behavior.autoScrollToCursor {
            textView.scrollRangeToVisible(NSRange(location: position, length: 0))
        }
        #else
        // iOS navigation
        if let position = textView.position(from: textView.beginningOfDocument, offset: position) {
            let textRange = textView.textRange(from: position, to: position)

            // Use the new method that respects autoScrollToCursor configuration
            textView.setSelectedTextRangeWithoutScrolling(textRange)

            // Only scroll if autoScrollToCursor is enabled
            if textView.configuration.behavior.autoScrollToCursor {
                let rect = textView.caretRect(for: position)
                textView.scrollRectToVisible(rect, animated: true)
            }
        }
        #endif
    }

    // MARK: - View Configuration

    /// Configure the text view for scrolling behavior
    static func configureTextViewScrolling(_ textView: CodeEditorView, wrapLines: Bool) {
        configurePlatformScrolling(textView, wrapLines: wrapLines)
    }

    private static func configurePlatformScrolling(_ textView: CodeEditorView, wrapLines: Bool) {
        #if canImport(AppKit)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapLines
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.textContainer?.heightTracksTextView = false
        textView.autoresizingMask = [.width, .height]

        // Set container width for non-wrapping mode
        if !wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        #else
        // iOS configuration
        textView.alwaysBounceVertical = true
        textView.isScrollEnabled = true

        // Configure text container for word wrapping
        let textContainer = textView.textContainer
        textContainer.maximumNumberOfLines = 0

        if wrapLines {
            // Enable word wrapping
            textContainer.lineBreakMode = .byWordWrapping
            // Use bounds width for wrapping, but ensure it's valid
            let containerWidth = textView.bounds.width > 0 ? textView.bounds.width : textView.frame.width
            textContainer.size = CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
            textView.alwaysBounceHorizontal = false
            textView.showsHorizontalScrollIndicator = false

            // Ensure width tracks text view for proper wrapping
            textContainer.widthTracksTextView = true
        } else {
            // Disable word wrapping - allow horizontal scrolling
            textContainer.lineBreakMode = .byCharWrapping
            // Use unlimited width to prevent wrapping
            textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            // Don't track text view width when horizontal scrolling is needed
            textContainer.widthTracksTextView = false
            textView.alwaysBounceHorizontal = true
            textView.showsHorizontalScrollIndicator = true

            // Force UITextView to recalculate its content size for horizontal scrolling
            textView.setNeedsLayout()
            textView.layoutIfNeeded()

            // Force content size update without accessing layoutManager
            // This avoids triggering TextKit1 compatibility mode
            textView.invalidateIntrinsicContentSize()
        }
        #endif
    }

    // MARK: - Background Configuration

    /// Set the background color for the container view
    static func setContainerBackground(_ view: PlatformView) {
        #if canImport(AppKit)
        // macOS uses layer background
        view.wantsLayer = true
        view.layer?.backgroundColor = PlatformColors.systemBackground.cgColor
        #else
        view.backgroundColor = PlatformColors.systemBackground
        #endif
    }

    // MARK: - Notification Names

    /// Get the appropriate text change notification name for the platform
    static var textDidChangeNotificationName: Notification.Name {
        #if canImport(AppKit)
        return NSText.didChangeNotification
        #else
        return UITextView.textDidChangeNotification
        #endif
    }

    // MARK: - Frame Calculations

    /// Calculate the visible text rect for the text view
    static func calculateVisibleTextRect(for textView: CodeEditorView, in containerBounds: CGRect) -> CGRect {
        #if canImport(AppKit)
        if let scrollView = textView.enclosingScrollView {
            return scrollView.contentView.visibleRect
        }
        return containerBounds
        #else
        // iOS - textView is itself a scroll view
        return CGRect(
            origin: textView.contentOffset,
            size: textView.bounds.size
        )
        #endif
    }

    // MARK: - Layout Updates

    /// Mark a view as needing layout update
    static func setNeedsLayout(_ view: PlatformView) {
        #if canImport(AppKit)
        view.needsLayout = true
        #else
        view.setNeedsLayout()
        #endif
    }

    // MARK: - Layout Frame Calculations

    /// Calculate the height for gutter and minimap views
    static func calculateSideViewHeight(bounds: CGRect, textView: CodeEditorView) -> CGFloat {
        platformCalculateSideViewHeight(bounds: bounds, textView: textView)
    }

    // MARK: - Text Container Insets

    /// Update text container insets for gutter width
    static func updateTextContainerInsets(textView: CodeEditorView, gutterWidth: CGFloat, padding: CGFloat) {
        let leftInset = gutterWidth + padding
        updatePlatformInsets(textView, leftInset: leftInset)
    }

    private static func updatePlatformInsets(_ textView: CodeEditorView, leftInset: CGFloat) {
        #if canImport(AppKit)
        let currentInsets = textView.textContainerInset
        textView.textContainerInset = NSSize(
            width: leftInset,
            height: currentInsets.height
        )
        #else
        let currentInsets = textView.textContainerEdgeInsets
        let newInsets = EdgeInsets(
            top: currentInsets.top,
            left: leftInset,
            bottom: currentInsets.bottom,
            right: currentInsets.right
        )
        textView.setTextContainerEdgeInsets(newInsets)
        #endif
    }
}

// MARK: - Platform-Specific Extensions

#if canImport(AppKit)
extension ContainerViewHelper {
    static func platformCalculateSideViewHeight(bounds: CGRect, textView _: CodeEditorView) -> CGFloat {
        bounds.height
    }
}
#else
extension ContainerViewHelper {
    static func platformCalculateSideViewHeight(bounds: CGRect, textView: CodeEditorView) -> CGFloat {
        let contentSize = textView.contentSize
        return max(bounds.height, contentSize.height + textView.contentInset.top + textView.contentInset.bottom)
    }
}
#endif
