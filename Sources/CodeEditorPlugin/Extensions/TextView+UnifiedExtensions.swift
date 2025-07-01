import CoreGraphics
import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Unified TextView Extensions

/// Protocol that provides a unified interface for text view operations across platforms
@MainActor
public protocol UnifiedTextViewProtocol {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    var textStorage: NSTextStorage? { get }
    var layoutManager: NSLayoutManager? { get }
    var textContainer: NSTextContainer? { get }
    var textContainerOrigin: NSPoint { get }
    var visibleRect: NSRect { get }
    #else
    // For UIKit, these are non-optional, but we'll handle them differently
    var textStorage: NSTextStorage { get }
    var layoutManager: NSLayoutManager { get }
    var textContainer: NSTextContainer { get }
    var contentOffset: CGPoint { get }
    var bounds: CGRect { get }
    #endif
}

// MARK: - Platform Conformance

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@MainActor
extension NSTextView: UnifiedTextViewProtocol {}
#else
@MainActor
extension UITextView: UnifiedTextViewProtocol {
    // UITextView already has all required properties
}
#endif

// MARK: - Unified Extensions

extension UnifiedTextViewProtocol {
    /// Returns the visible container rectangle in a platform-agnostic way
    var unifiedVisibleContainerRect: CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let origin = textContainerOrigin
        return visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        #else
        return CGRect(origin: contentOffset, size: bounds.size)
        #endif
    }
    
    /// Returns the bounding rectangle for the given text range using layout manager
    func unifiedBoundingRect(for range: NSRange) -> CGRect? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager,
              let textContainer else {
            return nil
        }
        #else
        let layoutManager = self.layoutManager
        let textContainer = self.textContainer
        #endif
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let origin = textContainerOrigin
        return rect.offsetBy(dx: origin.x, dy: origin.y)
        #else
        return rect
        #endif
    }
}

// MARK: - TextView Common Extensions

#if canImport(AppKit) || canImport(UIKit)
extension TextView {
    /// Returns the visible container rectangle
    var visibleContainerRect: CGRect {
        unifiedVisibleContainerRect
    }
    
    /// Returns the bounding rectangle for the given text range using layout manager
    public func boundingRect(for range: NSRange) -> CGRect? {
        unifiedBoundingRect(for: range)
    }
}

// MARK: - TextKit 2 Rendering Attributes

extension TextView {
    /// Apply attributes that do not affect layout, if supported by the text system
    public func setRenderingAttributes(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        // First determine if TextKit 2 is enabled to avoid downgrading
        if #available(macOS 12.0, iOS 16.0, *), let textLayoutManager {
            guard
                let contentManager = textLayoutManager.textContentManager,
                let textRange = NSTextRange(range, provider: contentManager)
            else {
                return
            }

            // Apply rendering attributes
            textLayoutManager.setRenderingAttributes(attributes, for: textRange)
            
            // Force refresh by temporarily changing selection
            let currentSelection = getCurrentSelection()
            setTemporarySelection(range)
            restoreSelection(currentSelection)
            return
        }

        // Fallback to TextKit 1 for macOS
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        layoutManager?.setTemporaryAttributes(attributes, forCharacterRange: range)
        #endif
    }
    
    /// Clear rendering attributes for the specified range
    public func clearRenderingAttributes(for range: NSRange) {
        setRenderingAttributes([:], for: range)
    }
    
    /// Apply syntax highlighting colors with proper TextKit 2 support
    public func applySyntaxHighlighting(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        // Use rendering attributes for non-layout affecting changes like color
        let renderingAttributes = attributes.filter { key, _ in
            // Only apply color and other non-layout affecting attributes as rendering attributes
            key == .foregroundColor || key == .backgroundColor
        }
        
        if !renderingAttributes.isEmpty {
            setRenderingAttributes(renderingAttributes, for: range)
        }
        
        // Apply layout-affecting attributes through the text storage
        let layoutAttributes = attributes.filter { key, _ in
            key != .foregroundColor && key != .backgroundColor
        }
        
        if !layoutAttributes.isEmpty {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textStorage?.addAttributes(layoutAttributes, range: range)
            #else
            textStorage.addAttributes(layoutAttributes, range: range)
            #endif
        }
    }
    
    // MARK: - Private Helpers
    
    private func getCurrentSelection() -> Any {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return self.selectedRanges
        #else
        return self.selectedRange
        #endif
    }
    
    private func setTemporarySelection(_ range: NSRange) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.selectedRanges = [NSValue(range: range)]
        #else
        self.selectedRange = range
        #endif
    }
    
    private func restoreSelection(_ selection: Any) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let ranges = selection as? [NSValue] {
            self.selectedRanges = ranges
        }
        #else
        if let range = selection as? NSRange {
            self.selectedRange = range
        }
        #endif
    }
}
#endif
