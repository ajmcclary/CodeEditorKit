import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// Local logger instance for selection handling
private let kLogger = Logger(subsystem: "com.codeeditor.plugin", category: "SelectionHandling")

// MARK: - Selection Handling Without Auto-Scroll

@MainActor
extension CodeEditorView {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    
    // MARK: - NSTextView Method for macOS
    
    /// Sets the selected range without triggering automatic scrolling on macOS
    func setSelectedRangeWithoutScrolling(_ range: NSRange) {
        // Only prevent scrolling if autoScrollToCursor is false
        guard !configuration.behavior.autoScrollToCursor else {
            // If auto-scroll is enabled, use default behavior with explicit scrolling
            setSelectedRange(range)
            scrollRangeToVisible(range)
            return
        }
        
        // Save current visible rect
        let savedVisibleRect = visibleRect
        
        // Set the selected range
        setSelectedRange(range)
        
        // Restore scroll position by scrolling back to saved visible rect
        // This counteracts the automatic scrolling behavior
        scrollToVisible(savedVisibleRect)
    }
    
    #elseif canImport(UIKit)
    
    // MARK: - UITextView Method Overrides
    
    /// Override the UITextView's selectedTextRange setter to respect autoScrollToCursor
    override open var selectedTextRange: UITextRange? {
        get {
            super.selectedTextRange
        }
        set {
            kLogger.debug("🎯 selectedTextRange override called, autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
            
            // Only prevent scrolling if autoScrollToCursor is false
            if !configuration.behavior.autoScrollToCursor && newValue != nil {
                // Save current scroll position
                let savedContentOffset = contentOffset
                let savedScrollEnabled = isScrollEnabled
                
                kLogger.debug("🎯 Preventing auto-scroll. Current offset: \(savedContentOffset.x), \(savedContentOffset.y)")
                
                // Temporarily disable scrolling
                isScrollEnabled = false
                
                // Set the selection
                super.selectedTextRange = newValue
                
                // Restore scroll settings
                isScrollEnabled = savedScrollEnabled
                
                // Restore scroll position if it changed
                if contentOffset != savedContentOffset {
                    kLogger.debug("🎯 Scroll position changed! Restoring from \(self.contentOffset.x), \(self.contentOffset.y) to \(savedContentOffset.x), \(savedContentOffset.y)")
                    setContentOffset(savedContentOffset, animated: false)
                }
            } else {
                // Normal behavior when autoScrollToCursor is true or newValue is nil
                super.selectedTextRange = newValue
            }
        }
    }
    
    /// Override UITextView's selectedRange property to respect autoScrollToCursor
    override open var selectedRange: NSRange {
        get {
            super.selectedRange
        }
        set {
            kLogger.debug("🎯 selectedRange override called with range: \(newValue), autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
            
            // Only prevent scrolling if autoScrollToCursor is false
            if !configuration.behavior.autoScrollToCursor {
                // Save current scroll position
                let savedContentOffset = contentOffset
                let savedScrollEnabled = isScrollEnabled
                
                kLogger.debug("🎯 Preventing auto-scroll. Current offset: \(savedContentOffset.x), \(savedContentOffset.y)")
                
                // Temporarily disable scrolling
                isScrollEnabled = false
                
                // Set the selection
                super.selectedRange = newValue
                
                // Restore scroll settings
                isScrollEnabled = savedScrollEnabled
                
                // Restore scroll position if it changed
                if contentOffset != savedContentOffset {
                    kLogger.debug("🎯 Scroll position changed! Restoring from \(self.contentOffset.x), \(self.contentOffset.y) to \(savedContentOffset.x), \(savedContentOffset.y)")
                    setContentOffset(savedContentOffset, animated: false)
                }
            } else {
                // Normal behavior when autoScrollToCursor is true
                super.selectedRange = newValue
            }
        }
    }
    
    /// Sets the selected text range without triggering automatic scrolling
    /// This is needed because UITextView automatically scrolls when selectedTextRange changes
    func setSelectedTextRangeWithoutScrolling(_ textRange: UITextRange?) {
        // Only prevent scrolling if autoScrollToCursor is false
        guard !configuration.behavior.autoScrollToCursor else {
            // If auto-scroll is enabled, use default behavior
            selectedTextRange = textRange
            return
        }
        
        kLogger.debug("🔒 setSelectedTextRangeWithoutScrolling: autoScrollToCursor = \(self.configuration.behavior.autoScrollToCursor)")
        
        // Save current scroll position
        let savedContentOffset = contentOffset
        let savedScrollEnabled = isScrollEnabled
        
        kLogger.debug("🔒 Before: contentOffset = \(savedContentOffset.x), \(savedContentOffset.y)")
        
        // Temporarily disable scrolling to prevent automatic scroll
        isScrollEnabled = false
        
        // Set the selection
        selectedTextRange = textRange
        
        // Restore scroll settings
        isScrollEnabled = savedScrollEnabled
        
        // Restore the scroll position if it changed
        if contentOffset != savedContentOffset {
            kLogger.debug("🔒 Scroll position changed! Restoring from \(self.contentOffset.x), \(self.contentOffset.y) to \(savedContentOffset.x), \(savedContentOffset.y)")
            setContentOffset(savedContentOffset, animated: false)
        }
        
        kLogger.debug("🔒 After: contentOffset = \(self.contentOffset.x), \(self.contentOffset.y)")
    }
    
    /// Sets the selected range (NSRange) without triggering automatic scrolling
    func setSelectedRangeWithoutScrolling(_ range: NSRange) {
        // Only prevent scrolling if autoScrollToCursor is false
        guard !configuration.behavior.autoScrollToCursor else {
            // If auto-scroll is enabled, use default behavior
            selectedRange = range
            return
        }
        
        // Convert NSRange to UITextRange
        guard let startPosition = position(from: beginningOfDocument, offset: range.location),
              let endPosition = position(from: startPosition, offset: range.length),
              let textRange = self.textRange(from: startPosition, to: endPosition) else {
            return
        }
        
        setSelectedTextRangeWithoutScrolling(textRange)
    }
    
    /// Override scrollRectToVisible to respect autoScrollToCursor configuration
    override open func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        kLogger.debug("🚫 scrollRectToVisible called with rect: \(rect.origin.x), \(rect.origin.y), \(rect.size.width), \(rect.size.height), autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
        
        // Only allow scrolling if autoScrollToCursor is true
        if configuration.behavior.autoScrollToCursor {
            super.scrollRectToVisible(rect, animated: animated)
        } else {
            kLogger.debug("🚫 Blocking scrollRectToVisible because autoScrollToCursor is false")
        }
    }
    #endif
}
