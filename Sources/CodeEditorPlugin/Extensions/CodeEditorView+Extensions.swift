// Sources/CodeEditorPlugin/Extensions/CodeEditorView+Extensions.swift
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-platform Editing Actions

/// Cross-platform editing actions for CodeEditorView
@MainActor
extension CodeEditorView {
    /// Perform a cut operation (copy selection and delete it)
    func performCut() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        cut(nil)
        #else
        // Use the built-in cut method which handles pasteboard securely
        cut(nil)
        #endif
    }
    
    /// Perform a copy operation (copy selection to pasteboard)
    func performCopy() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        copy(nil)
        #else
        // Use the built-in copy method which handles pasteboard securely
        copy(nil)
        #endif
    }
    
    /// Perform a paste operation (insert pasteboard content at cursor)
    func performPaste() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        paste(nil)
        #else
        // Use the built-in paste method which handles pasteboard securely
        paste(nil)
        #endif
    }
    
    /// Select all text in the editor
    func performSelectAll() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        selectAll(nil)
        #else
        selectAll(nil)
        #endif
    }
    
    /// Delete the current selection or character before cursor
    func performDelete() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        deleteBackward(nil)
        #else
        deleteBackward()
        #endif
    }
    
    /// Check if cut operation is available (has selection and is editable)
    var canCut: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return isEditable && selectedRange().length > 0
        #else
        return isEditable && selectedRange.length > 0
        #endif
    }
    
    /// Check if copy operation is available (has selection)
    var canCopy: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return selectedRange().length > 0
        #else
        return selectedRange.length > 0
        #endif
    }
    
    /// Check if paste operation is available (is editable and pasteboard has content)
    var canPaste: Bool {
        guard isEditable else { return false }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSPasteboard.general.string(forType: .string) != nil
        #else
        // On iOS 16+, checking pasteboard content triggers authorization prompts
        // Since we can't reliably check without prompting, assume paste is available when editable
        // The actual paste operation will handle any authorization if needed
        return true
        #endif
    }
}

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
        
        // Ensure the view is properly set up before accessing geometry
        guard window != nil, superview != nil else {
            // If view is not in a window, just set the range without scroll management
            setSelectedRange(range)
            return
        }
        
        // Save current visible rect
        let savedVisibleRect = visibleRect
        
        // Validate the visible rect to avoid invalid geometry
        guard savedVisibleRect.width > 0 && savedVisibleRect.height > 0 &&
              !savedVisibleRect.origin.x.isNaN && !savedVisibleRect.origin.y.isNaN &&
              !savedVisibleRect.origin.x.isInfinite && !savedVisibleRect.origin.y.isInfinite else {
            // If visible rect is invalid, just set the range
            setSelectedRange(range)
            return
        }
        
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
            CrossPlatformLogger.logger().debug("🎯 selectedTextRange override called, autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
            
            // Only prevent scrolling if autoScrollToCursor is false
            if !configuration.behavior.autoScrollToCursor && newValue != nil {
                // Save current scroll position
                let savedContentOffset = contentOffset
                let savedScrollEnabled = isScrollEnabled
                
                CrossPlatformLogger.logger().debug("🎯 Preventing auto-scroll. Current offset: \(savedContentOffset.x), \(savedContentOffset.y)")
                
                // Temporarily disable scrolling
                isScrollEnabled = false
                
                // Set the selection
                super.selectedTextRange = newValue
                
                // Restore scroll settings
                isScrollEnabled = savedScrollEnabled
                
                // Restore scroll position if it changed
                if contentOffset != savedContentOffset {
                    CrossPlatformLogger.logger().debug("🎯 Scroll position changed! Restoring from \(self.contentOffset.x), \(self.contentOffset.y) to \(savedContentOffset.x), \(savedContentOffset.y)")
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
            CrossPlatformLogger.logger().debug("🎯 selectedRange override called with range: \(newValue), autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
            
            // Only prevent scrolling if autoScrollToCursor is false
            if !configuration.behavior.autoScrollToCursor {
                // Save current scroll position
                let savedContentOffset = contentOffset
                let savedScrollEnabled = isScrollEnabled
                
                CrossPlatformLogger.logger().debug("🎯 Preventing auto-scroll. Current offset: \(savedContentOffset.x), \(savedContentOffset.y)")
                
                // Temporarily disable scrolling
                isScrollEnabled = false
                
                // Set the selection
                super.selectedRange = newValue
                
                // Restore scroll settings
                isScrollEnabled = savedScrollEnabled
                
                // Restore scroll position if it changed
                if contentOffset != savedContentOffset {
                    CrossPlatformLogger.logger().debug("🎯 Scroll position changed! Restoring from \(self.contentOffset.x), \(self.contentOffset.y) to \(savedContentOffset.x), \(savedContentOffset.y)")
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
        
        CrossPlatformLogger.logger().debug("🔒 setSelectedTextRangeWithoutScrolling: autoScrollToCursor = \(self.configuration.behavior.autoScrollToCursor)")
        
        // Save current scroll position
        let savedContentOffset = contentOffset
        let savedScrollEnabled = isScrollEnabled
        
        CrossPlatformLogger.logger().debug("🔒 Before: contentOffset = \(savedContentOffset.x), \(savedContentOffset.y)")
        
        // Temporarily disable scrolling to prevent automatic scroll
        isScrollEnabled = false
        
        // Set the selection
        selectedTextRange = textRange
        
        // Restore scroll settings
        isScrollEnabled = savedScrollEnabled
        
        // Restore the scroll position if it changed
        if contentOffset != savedContentOffset {
            CrossPlatformLogger.logger().debug("🔒 Scroll position changed! Restoring from \(self.contentOffset.x), \(self.contentOffset.y) to \(savedContentOffset.x), \(savedContentOffset.y)")
            setContentOffset(savedContentOffset, animated: false)
        }
        
        CrossPlatformLogger.logger().debug("🔒 After: contentOffset = \(self.contentOffset.x), \(self.contentOffset.y)")
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
        CrossPlatformLogger.logger().debug("🚫 scrollRectToVisible called with rect: \(rect.origin.x), \(rect.origin.y), \(rect.size.width), \(rect.size.height), autoScrollToCursor: \(self.configuration.behavior.autoScrollToCursor)")
        
        // Only allow scrolling if autoScrollToCursor is true
        if configuration.behavior.autoScrollToCursor {
            super.scrollRectToVisible(rect, animated: animated)
        } else {
            CrossPlatformLogger.logger().debug("🚫 Blocking scrollRectToVisible because autoScrollToCursor is false")
        }
    }
    #endif
}
