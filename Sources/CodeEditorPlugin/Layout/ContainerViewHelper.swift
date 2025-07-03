import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Helper for unified container view operations across platforms
@MainActor
enum ContainerViewHelper {
    // MARK: - Text Navigation
    
    /// Navigate to a specific line number in the text view
    static func navigateToLine(_ lineNumber: Int, in textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let text = textView.string
        #else
        let text = textView.text ?? ""
        #endif
        let lines = text.components(separatedBy: CharacterSet.newlines)
        
        guard lineNumber < lines.count else { return }
        
        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        let targetPosition = lineNumber > 0 ? lineStart + 1 : 0
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS navigation
        textView.setSelectedRange(NSRange(location: targetPosition, length: 0))
        
        // Only scroll if autoScrollToCursor is enabled
        if textView.configuration.behavior.autoScrollToCursor {
            textView.scrollRangeToVisible(NSRange(location: targetPosition, length: 0))
        }
        #else
        // iOS navigation
        if let position = textView.position(from: textView.beginningOfDocument, offset: targetPosition) {
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #endif
        
        // Common configuration
        textView.backgroundColor = PlatformColors.clear
    }
    
    // MARK: - Background Configuration
    
    /// Set the background color for the container view
    static func setContainerBackground(_ view: PlatformView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSText.didChangeNotification
        #else
        return UITextView.textDidChangeNotification
        #endif
    }
    
    // MARK: - Frame Calculations
    
    /// Calculate the visible text rect for the text view
    static func calculateVisibleTextRect(for textView: CodeEditorView, in containerBounds: CGRect) -> CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.needsLayout = true
        #else
        view.setNeedsLayout()
        #endif
    }
    
    // MARK: - Layout Frame Calculations
    
    /// Calculate the height for gutter and minimap views
    static func calculateSideViewHeight(bounds: CGRect, textView: CodeEditorView) -> CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return bounds.height
        #else
        let contentSize = textView.contentSize
        return max(bounds.height, contentSize.height + textView.contentInset.top + textView.contentInset.bottom)
        #endif
    }
    
    // MARK: - Text Container Insets
    
    /// Update text container insets for gutter width
    static func updateTextContainerInsets(textView: CodeEditorView, gutterWidth: CGFloat, padding: CGFloat) {
        let leftInset = gutterWidth + padding
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
