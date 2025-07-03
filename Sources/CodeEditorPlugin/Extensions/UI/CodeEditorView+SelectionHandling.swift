import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Selection Handling Without Auto-Scroll

@MainActor
extension CodeEditorView {
    #if canImport(UIKit)
    
    // MARK: - UITextView Method Overrides
    
    /// Override the UITextView's selectedTextRange setter to respect autoScrollToCursor
    override open var selectedTextRange: UITextRange? {
        get {
            return super.selectedTextRange
        }
        set {
            print("🎯 selectedTextRange override called, autoScrollToCursor: \(configuration.behavior.autoScrollToCursor)")
            
            // Only prevent scrolling if autoScrollToCursor is false
            if !configuration.behavior.autoScrollToCursor && newValue != nil {
                // Save current scroll position
                let savedContentOffset = contentOffset
                let savedScrollEnabled = isScrollEnabled
                
                print("🎯 Preventing auto-scroll. Current offset: \(savedContentOffset)")
                
                // Temporarily disable scrolling
                isScrollEnabled = false
                
                // Set the selection
                super.selectedTextRange = newValue
                
                // Restore scroll settings
                isScrollEnabled = savedScrollEnabled
                
                // Restore scroll position if it changed
                if contentOffset != savedContentOffset {
                    print("🎯 Scroll position changed! Restoring from \(contentOffset) to \(savedContentOffset)")
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
            return super.selectedRange
        }
        set {
            print("🎯 selectedRange override called with range: \(newValue), autoScrollToCursor: \(configuration.behavior.autoScrollToCursor)")
            
            // Only prevent scrolling if autoScrollToCursor is false
            if !configuration.behavior.autoScrollToCursor {
                // Save current scroll position
                let savedContentOffset = contentOffset
                let savedScrollEnabled = isScrollEnabled
                
                print("🎯 Preventing auto-scroll. Current offset: \(savedContentOffset)")
                
                // Temporarily disable scrolling
                isScrollEnabled = false
                
                // Set the selection
                super.selectedRange = newValue
                
                // Restore scroll settings
                isScrollEnabled = savedScrollEnabled
                
                // Restore scroll position if it changed
                if contentOffset != savedContentOffset {
                    print("🎯 Scroll position changed! Restoring from \(contentOffset) to \(savedContentOffset)")
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
        
        print("🔒 setSelectedTextRangeWithoutScrolling: autoScrollToCursor = \(configuration.behavior.autoScrollToCursor)")
        
        // Save current scroll position
        let savedContentOffset = contentOffset
        let savedScrollEnabled = isScrollEnabled
        
        print("🔒 Before: contentOffset = \(savedContentOffset)")
        
        // Temporarily disable scrolling to prevent automatic scroll
        isScrollEnabled = false
        
        // Set the selection
        selectedTextRange = textRange
        
        // Restore scroll settings
        isScrollEnabled = savedScrollEnabled
        
        // Restore the scroll position if it changed
        if contentOffset != savedContentOffset {
            print("🔒 Scroll position changed! Restoring from \(contentOffset) to \(savedContentOffset)")
            setContentOffset(savedContentOffset, animated: false)
        }
        
        print("🔒 After: contentOffset = \(contentOffset)")
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
        print("🚫 scrollRectToVisible called with rect: \(rect), autoScrollToCursor: \(configuration.behavior.autoScrollToCursor)")
        
        // Only allow scrolling if autoScrollToCursor is true
        if configuration.behavior.autoScrollToCursor {
            super.scrollRectToVisible(rect, animated: animated)
        } else {
            print("🚫 Blocking scrollRectToVisible because autoScrollToCursor is false")
        }
    }
    #endif
}