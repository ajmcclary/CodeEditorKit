#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit

typealias TextView = NSTextView
#elseif os(iOS) || os(visionOS)
import UIKit

typealias TextView = UITextView
#endif

#if os(macOS) || os(iOS) || os(visionOS)
extension TextView {
    /// Returns the visible container rectangle
    var visibleContainerRect: CGRect {
#if os(macOS) && !targetEnvironment(macCatalyst)
        let origin = textContainerOrigin
        return visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
#elseif os(iOS) || os(visionOS)
        return CGRect(origin: contentOffset, size: bounds.size)
#endif
    }

    /// Returns the bounding rectangle for the given text range using layout manager
    public func boundingRect(for range: NSRange) -> CGRect? {
#if os(macOS) && !targetEnvironment(macCatalyst)
        guard let layoutManager,
              let textContainer else {
            return nil
        }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let origin = textContainerOrigin
        return rect.offsetBy(dx: origin.x, dy: origin.y)
#elseif os(iOS) || os(visionOS)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
#endif
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

            // Apply a workaround to force rendering attributes to be applied immediately
#if os(macOS)
            let selection = self.selectedRanges
#else
            let selection = self.selectedRange
#endif

            textLayoutManager.setRenderingAttributes(attributes, for: textRange)

            // Force refresh by temporarily changing selection
#if os(macOS)
            self.selectedRanges = [NSValue(range: range)]
            self.selectedRanges = selection
#else
            self.selectedRange = range
            self.selectedRange = selection
#endif
            return
        }

        // Fallback to TextKit 1 for macOS
#if os(macOS)
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
#if os(macOS)
            textStorage?.addAttributes(layoutAttributes, range: range)
#else
            textStorage.addAttributes(layoutAttributes, range: range)
#endif
        }
    }
}

// MARK: - TextKit Version Detection

extension TextView {
    /// Returns true if TextKit 1 is being used
    var isUsingTextKit1: Bool {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        !isUsingTextKit2
        #else
        // Check if TextKit2 is available on iOS
        if #available(iOS 16.0, *) {
            return textLayoutManager == nil
        } else {
            return true // iOS < 16 uses TextKit 1
        }
        #endif
    }

    /// Returns true if TextKit 2 is supported on the current platform
    var supportsTextKit2: Bool {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            return true
        }
        return false
        #else
        if #available(iOS 16.0, *) {
            return true
        }
        return false
        #endif
    }
    
    /// Returns true if TextKit 2 is currently being used
    var isUsingTextKit2: Bool {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            return textLayoutManager != nil
        }
        return false
        #else
        if #available(iOS 16.0, *) {
            return textLayoutManager != nil
        }
        return false
        #endif
    }
    
    /// Get the text content manager if using TextKit 2
    @available(macOS 12.0, iOS 16.0, *)
    var textContentManager: NSTextContentManager? {
        textLayoutManager?.textContentManager
    }
}

// MARK: - Cross-Platform Text Selection Support

extension TextView {
    /// Get selected text ranges in a cross-platform way
    var selectedTextRanges: [NSRange] {
#if os(macOS)
        return selectedRanges.compactMap { value in
            value.rangeValue
        }
#else
        return [selectedRange]
#endif
    }

    /// Set selected text ranges in a cross-platform way
    func setSelectedTextRanges(_ ranges: [NSRange]) {
#if os(macOS)
        selectedRanges = ranges.map { NSValue(range: $0) }
#else
        if let firstRange = ranges.first {
            selectedRange = firstRange
        }
#endif
    }

    /// Get the primary selected range
    var primarySelectedRange: NSRange {
#if os(macOS)
        return selectedRanges.first?.rangeValue ?? NSRange(location: 0, length: 0)
#else
        return selectedRange
#endif
    }
}

// MARK: - Enhanced Text Manipulation

extension TextView {
    /// Insert text at the current selection with proper TextKit 2 support
    public func insertTextAtSelection(_ text: String) {
        let selectedRange = primarySelectedRange
        
#if os(macOS)
        if let textStorage {
            textStorage.replaceCharacters(in: selectedRange, with: text)
            setSelectedTextRanges([NSRange(location: selectedRange.location + text.count, length: 0)])
        }
#else
        let currentRange = selectedRange
        textStorage.replaceCharacters(in: currentRange, with: text)
        let newLocation = currentRange.location + text.count
        _ = NSRange(location: newLocation, length: 0)
        if let textPosition = position(from: beginningOfDocument, offset: newLocation) {
            selectedTextRange = textRange(from: textPosition, to: textPosition)
        }
#endif
    }

    /// Replace text in range with new text
    public func replaceText(in range: NSRange, with newText: String) {
#if os(macOS)
        textStorage?.replaceCharacters(in: range, with: newText)
#else
        textStorage.replaceCharacters(in: range, with: newText)
#endif
    }

    /// Get text content as string
    public var textContent: String {
#if os(macOS)
        return textStorage?.string ?? ""
#else
        return textStorage.string
#endif
    }

    /// Get the full text range
    public var fullTextRange: NSRange {
        NSRange(location: 0, length: textContent.count)
    }
}

#endif
